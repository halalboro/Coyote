/**
 * This file is part of the Coyote <https://github.com/fpgasystems/Coyote>
 *
 * MIT Licence
 * Copyright (c) 2021-2025, Systems Group, ETH Zurich
 * All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:

 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.

 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

`timescale 1ns / 1ps

import lynxTypes::*;

/**
 * @brief Host DMA for Zynq-based platforms (one per host channel)
 *
 * Takes the place of xdma_wrapper + the XDMA descriptor bypass on PCIe platforms: requests (paddr, len, last)
 * from the shell are turned into AXI DataMover commands, which read/write host (PS DDR) memory through
 * the PS slave ports. The behaviour seen by the shell matches the XDMA bypass:
 *  - H2C (reads):  the stream carries tlast only at the end of a request with last = 1 (XDMA EOP bit)
 *  - C2H (writes): the request length determines the transfer; the tlast of the incoming stream is ignored
 *  - rsp.done pulses once for every completed request with last = 1 (XDMA completion bit)
 *
 * Every S2MM command is issued with EOF set and its tlast regenerated from the request length,
 * so the DataMover never sees a tlast that does not line up with the end of a command.
 *
 * Cache coherency: the AXI cache and protection attributes are overriden, so that transactions are
 * snooped by the APU caches when routed through the coherent (HPC) ports of the PS. The Coyote driver
 * maps user buffers once and never syncs caches explicitly, so non-coherent ports would corrupt data.
 * See AR# 69446 (Zynq UltraScale+ MPSoC: HPC port cache coherency) for the PS-side requirements.
 */
module zynq_dma_wrapper #(
    parameter integer N_OUTSTANDING_CMD = 16
) (
    input  logic                aclk,
    input  logic                aresetn,

    // Requests from the shell
    dmaIntf.s                   s_dma_rd,
    dmaIntf.s                   s_dma_wr,

    // Data to/from the shell
    AXI4S.m                     m_axis_h2c,
    AXI4S.s                     s_axis_c2h,

    // To the PS (coherent port)
    AXI4.m                      m_axi,

    // Sticky error flags: [0] read (MM2S), [1] write (S2MM)
    output logic [1:0]          dma_err
);

// DataMover command: [103:100] reserved, [99:96] tag, [95:32] address, [31] drr, [30] eof, [29:24] dsa, [23] type, [22:0] btt
localparam integer CMD_BITS = 104;
localparam integer BTT_BITS = 23;

// Write-back, read/write-allocate, non-secure; Linux maps buffers as non-secure, so snoops must be non-secure as well
localparam logic [3:0] AXI_CACHE = 4'b1111;
localparam logic [2:0] AXI_PROT = 3'b010;

// DataMover status: [7] okay, [6] slverr, [5] decerr, [4] interr, [3:0] tag
localparam integer STS_OKAY = 7;

// ================-----------------------------------------------------------------
// H2C (MM2S)
// ================-----------------------------------------------------------------
logic [CMD_BITS-1:0] mm2s_cmd_data;
logic mm2s_cmd_valid;
logic mm2s_cmd_ready;

logic [31:0] mm2s_sts_data;
logic mm2s_sts_valid;

// Outstanding requests, holding the last flag
logic rd_q_rdy_snk;
logic rd_q_val_src;
logic rd_q_data_src;

assign mm2s_cmd_data = {8'h0, {(64-PADDR_BITS){1'b0}}, s_dma_rd.req.paddr, 1'b1, s_dma_rd.req.last, 6'h0, 1'b1, s_dma_rd.req.len[BTT_BITS-1:0]};
assign mm2s_cmd_valid = s_dma_rd.valid & rd_q_rdy_snk;
assign s_dma_rd.ready = mm2s_cmd_ready & rd_q_rdy_snk;

zynq_dma_queue #(
    .DATA_BITS(1),
    .DEPTH(N_OUTSTANDING_CMD)
) inst_rd_q (
    .aclk(aclk),
    .aresetn(aresetn),
    .val_snk(s_dma_rd.valid & s_dma_rd.ready),
    .rdy_snk(rd_q_rdy_snk),
    .data_snk(s_dma_rd.req.last),
    .val_src(rd_q_val_src),
    .rdy_src(mm2s_sts_valid),
    .data_src(rd_q_data_src)
);

// ================-----------------------------------------------------------------
// C2H (S2MM)
// ================-----------------------------------------------------------------
logic [CMD_BITS-1:0] s2mm_cmd_data;
logic s2mm_cmd_valid;
logic s2mm_cmd_ready;

logic [31:0] s2mm_sts_data;
logic s2mm_sts_valid;

// Outstanding requests, holding the last flag
logic wr_q_rdy_snk;
logic wr_q_val_src;
logic wr_q_data_src;

// Outstanding requests, holding the number of beats; used to regenerate tlast
logic [BLEN_BITS:0] wr_beats;
logic beats_q_rdy_snk;
logic beats_q_val_src;
logic [BLEN_BITS:0] beats_q_data_src;
logic [BLEN_BITS:0] beat_cnt;

logic s2mm_tvalid;
logic s2mm_tready;
logic s2mm_tlast;

assign wr_beats = (s_dma_wr.req.len == 0) ? 1 : (s_dma_wr.req.len + (AXI_DATA_BITS/8) - 1) >> BEAT_LOG_BITS;

assign s2mm_cmd_data = {8'h0, {(64-PADDR_BITS){1'b0}}, s_dma_wr.req.paddr, 1'b1, 1'b1, 6'h0, 1'b1, s_dma_wr.req.len[BTT_BITS-1:0]};
assign s2mm_cmd_valid = s_dma_wr.valid & wr_q_rdy_snk & beats_q_rdy_snk;
assign s_dma_wr.ready = s2mm_cmd_ready & wr_q_rdy_snk & beats_q_rdy_snk;

zynq_dma_queue #(
    .DATA_BITS(1),
    .DEPTH(N_OUTSTANDING_CMD)
) inst_wr_q (
    .aclk(aclk),
    .aresetn(aresetn),
    .val_snk(s_dma_wr.valid & s_dma_wr.ready),
    .rdy_snk(wr_q_rdy_snk),
    .data_snk(s_dma_wr.req.last),
    .val_src(wr_q_val_src),
    .rdy_src(s2mm_sts_valid),
    .data_src(wr_q_data_src)
);

zynq_dma_queue #(
    .DATA_BITS(BLEN_BITS+1),
    .DEPTH(N_OUTSTANDING_CMD)
) inst_beats_q (
    .aclk(aclk),
    .aresetn(aresetn),
    .val_snk(s_dma_wr.valid & s_dma_wr.ready),
    .rdy_snk(beats_q_rdy_snk),
    .data_snk(wr_beats),
    .val_src(beats_q_val_src),
    .rdy_src(s2mm_tvalid & s2mm_tready & s2mm_tlast),
    .data_src(beats_q_data_src)
);

// Data is only let through once the corresponding request has been accepted
assign s2mm_tvalid = s_axis_c2h.tvalid & beats_q_val_src;
assign s_axis_c2h.tready = s2mm_tready & beats_q_val_src;
assign s2mm_tlast = (beat_cnt == beats_q_data_src - 1);

always_ff @(posedge aclk) begin
    if (aresetn == 1'b0) begin
        beat_cnt <= 0;
    end
    else begin
        if (s2mm_tvalid & s2mm_tready) begin
            beat_cnt <= s2mm_tlast ? 0 : beat_cnt + 1;
        end
    end
end

// ================-----------------------------------------------------------------
// COMPLETIONS
// ================-----------------------------------------------------------------
always_ff @(posedge aclk) begin
    if (aresetn == 1'b0) begin
        s_dma_rd.rsp.done <= 1'b0;
        s_dma_wr.rsp.done <= 1'b0;
        dma_err <= 2'b00;
    end
    else begin
        s_dma_rd.rsp.done <= mm2s_sts_valid & rd_q_data_src;
        s_dma_wr.rsp.done <= s2mm_sts_valid & wr_q_data_src;

        if (mm2s_sts_valid & ~mm2s_sts_data[STS_OKAY]) dma_err[0] <= 1'b1;
        if (s2mm_sts_valid & ~s2mm_sts_data[STS_OKAY]) dma_err[1] <= 1'b1;
    end
end

// ================-----------------------------------------------------------------
// DATAMOVER
// ================-----------------------------------------------------------------
assign m_axi.arcache = AXI_CACHE;
assign m_axi.arprot = AXI_PROT;
assign m_axi.arlock = 1'b0;
assign m_axi.arqos = 4'b0;
assign m_axi.arregion = 4'b0;
assign m_axi.awcache = AXI_CACHE;
assign m_axi.awprot = AXI_PROT;
assign m_axi.awlock = 1'b0;
assign m_axi.awqos = 4'b0;
assign m_axi.awregion = 4'b0;

axi_datamover_hdma inst_datamover (
    // MM2S
    .m_axi_mm2s_aclk(aclk),
    .m_axi_mm2s_aresetn(aresetn),
    .mm2s_err(),
    .m_axis_mm2s_cmdsts_aclk(aclk),
    .m_axis_mm2s_cmdsts_aresetn(aresetn),
    .s_axis_mm2s_cmd_tvalid(mm2s_cmd_valid),
    .s_axis_mm2s_cmd_tready(mm2s_cmd_ready),
    .s_axis_mm2s_cmd_tdata(mm2s_cmd_data),
    .m_axis_mm2s_sts_tvalid(mm2s_sts_valid),
    .m_axis_mm2s_sts_tready(1'b1),
    .m_axis_mm2s_sts_tdata(mm2s_sts_data),
    .m_axis_mm2s_sts_tkeep(),
    .m_axis_mm2s_sts_tlast(),
    .m_axi_mm2s_arid(m_axi.arid),
    .m_axi_mm2s_araddr(m_axi.araddr),
    .m_axi_mm2s_arlen(m_axi.arlen),
    .m_axi_mm2s_arsize(m_axi.arsize),
    .m_axi_mm2s_arburst(m_axi.arburst),
    .m_axi_mm2s_arprot(),
    .m_axi_mm2s_arcache(),
    .m_axi_mm2s_aruser(),
    .m_axi_mm2s_arvalid(m_axi.arvalid),
    .m_axi_mm2s_arready(m_axi.arready),
    .m_axi_mm2s_rdata(m_axi.rdata),
    .m_axi_mm2s_rresp(m_axi.rresp),
    .m_axi_mm2s_rlast(m_axi.rlast),
    .m_axi_mm2s_rvalid(m_axi.rvalid),
    .m_axi_mm2s_rready(m_axi.rready),
    .m_axis_mm2s_tdata(m_axis_h2c.tdata),
    .m_axis_mm2s_tkeep(m_axis_h2c.tkeep),
    .m_axis_mm2s_tlast(m_axis_h2c.tlast),
    .m_axis_mm2s_tvalid(m_axis_h2c.tvalid),
    .m_axis_mm2s_tready(m_axis_h2c.tready),

    // S2MM
    .m_axi_s2mm_aclk(aclk),
    .m_axi_s2mm_aresetn(aresetn),
    .s2mm_err(),
    .m_axis_s2mm_cmdsts_awclk(aclk),
    .m_axis_s2mm_cmdsts_aresetn(aresetn),
    .s_axis_s2mm_cmd_tvalid(s2mm_cmd_valid),
    .s_axis_s2mm_cmd_tready(s2mm_cmd_ready),
    .s_axis_s2mm_cmd_tdata(s2mm_cmd_data),
    .m_axis_s2mm_sts_tvalid(s2mm_sts_valid),
    .m_axis_s2mm_sts_tready(1'b1),
    .m_axis_s2mm_sts_tdata(s2mm_sts_data),
    .m_axis_s2mm_sts_tkeep(),
    .m_axis_s2mm_sts_tlast(),
    .m_axi_s2mm_awid(m_axi.awid),
    .m_axi_s2mm_awaddr(m_axi.awaddr),
    .m_axi_s2mm_awlen(m_axi.awlen),
    .m_axi_s2mm_awsize(m_axi.awsize),
    .m_axi_s2mm_awburst(m_axi.awburst),
    .m_axi_s2mm_awprot(),
    .m_axi_s2mm_awcache(),
    .m_axi_s2mm_awuser(),
    .m_axi_s2mm_awvalid(m_axi.awvalid),
    .m_axi_s2mm_awready(m_axi.awready),
    .m_axi_s2mm_wdata(m_axi.wdata),
    .m_axi_s2mm_wstrb(m_axi.wstrb),
    .m_axi_s2mm_wlast(m_axi.wlast),
    .m_axi_s2mm_wvalid(m_axi.wvalid),
    .m_axi_s2mm_wready(m_axi.wready),
    .m_axi_s2mm_bresp(m_axi.bresp),
    .m_axi_s2mm_bvalid(m_axi.bvalid),
    .m_axi_s2mm_bready(m_axi.bready),
    .s_axis_s2mm_tdata(s_axis_c2h.tdata),
    .s_axis_s2mm_tkeep(s_axis_c2h.tkeep),
    .s_axis_s2mm_tlast(s2mm_tlast),
    .s_axis_s2mm_tvalid(s2mm_tvalid),
    .s_axis_s2mm_tready(s2mm_tready)
);

endmodule

/**
 * @brief Small FIFO for outstanding DataMover commands; DEPTH must be a power of 2
 */
module zynq_dma_queue #(
    parameter integer DATA_BITS = 1,
    parameter integer DEPTH = 16
) (
    input  logic                    aclk,
    input  logic                    aresetn,

    input  logic                    val_snk,
    output logic                    rdy_snk,
    input  logic [DATA_BITS-1:0]    data_snk,

    output logic                    val_src,
    input  logic                    rdy_src,
    output logic [DATA_BITS-1:0]    data_src
);

localparam integer PTR_BITS = $clog2(DEPTH);

logic [DATA_BITS-1:0] mem [DEPTH];
logic [PTR_BITS-1:0] wr_ptr;
logic [PTR_BITS-1:0] rd_ptr;
logic [PTR_BITS:0] cnt;

logic push;
logic pop;

assign push = val_snk & rdy_snk;
assign pop = val_src & rdy_src;

assign rdy_snk = (cnt != DEPTH);
assign val_src = (cnt != 0);
assign data_src = mem[rd_ptr];

// Kept free of reset, so it maps to LUTRAM
always_ff @(posedge aclk) begin
    if (push) begin
        mem[wr_ptr] <= data_snk;
    end
end

always_ff @(posedge aclk) begin
    if (aresetn == 1'b0) begin
        wr_ptr <= 0;
        rd_ptr <= 0;
        cnt <= 0;
    end
    else begin
        if (push) begin
            wr_ptr <= wr_ptr + 1;
        end
        if (pop) begin
            rd_ptr <= rd_ptr + 1;
        end
        cnt <= cnt + push - pop;
    end
end

endmodule
