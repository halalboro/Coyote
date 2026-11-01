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
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
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

module axi_stripe_rd (
    input  logic                        aclk,
    input  logic                        aresetn,
    
    input  logic[AXI_ADDR_BITS-1:0]     s_axi_araddr,
    input  logic[1:0]		            s_axi_arburst,
    input  logic[3:0]		            s_axi_arcache,
    input  logic[AXI_ID_BITS-1:0]       s_axi_arid,
    input  logic[7:0]		            s_axi_arlen,
    input  logic[0:0]		            s_axi_arlock,
    input  logic[2:0]		            s_axi_arprot,
    input  logic[3:0]		            s_axi_arqos,
    input  logic[3:0]		            s_axi_arregion,
    input  logic[2:0]		            s_axi_arsize,
    output logic			            s_axi_arready,
    input  logic			            s_axi_arvalid,

    output  logic[AXI_ADDR_BITS-1:0]    m_axi_araddr,
    output  logic[1:0]		            m_axi_arburst,
    output  logic[3:0]		            m_axi_arcache,
    output  logic[AXI_ID_BITS-1:0]      m_axi_arid,
    output  logic[7:0]		            m_axi_arlen,
    output  logic[0:0]		            m_axi_arlock,
    output  logic[2:0]		            m_axi_arprot,
    output  logic[3:0]		            m_axi_arqos,
    output  logic[3:0]		            m_axi_arregion,
    output  logic[2:0]		            m_axi_arsize,
    input   logic			            m_axi_arready,
    output  logic			            m_axi_arvalid,

    output logic[AXI_DATA_BITS-1:0]     s_axi_rdata,
    output logic[AXI_ID_BITS-1:0]       s_axi_rid,
    output logic                        s_axi_rlast,
    output logic[1:0]                   s_axi_rresp,
    input  logic                        s_axi_rready,
    output logic                        s_axi_rvalid,

    input  logic[AXI_DATA_BITS-1:0]     m_axi_rdata,
    input  logic[AXI_ID_BITS-1:0]       m_axi_rid,
    input  logic                        m_axi_rlast,
    input  logic[1:0]                   m_axi_rresp,
    output logic                        m_axi_rready,
    input  logic                        m_axi_rvalid
);

localparam integer FRAG_LOG_BITS = $clog2(STRIPE_FRAG_SIZE);
localparam integer BEAT_LOG_BITS = $clog2(AXI_DATA_BITS/8);

// Each channel gets its own AXI ID (the channel number), so the interconnect can keep requests to all channels in flight
// (it holds back a request whose ID is still outstanding at another slave). Responses of different channels can then come
// back in any order, so each channel has its own data buffer, drained in request order. A request is only issued if its
// channel's buffer has room for all of its beats, so the read data channel is never back-pressured (no deadlock).
localparam integer RD_BUFF_DEPTH = 512;
localparam integer CRED_BITS = $clog2(RD_BUFF_DEPTH) + 1;
localparam integer N_SEQ = 64;

// FSM
typedef enum logic[0:0] {ST_IDLE, ST_PARSE} state_t;
logic[0:0] state_C, state_N;

logic [AXI_ADDR_BITS-1:0] araddr_C, araddr_N;
logic [1:0] arburst_C, arburst_N;
logic [3:0] arcache_C, arcache_N;
logic [AXI_ID_BITS-1:0] arid_C, arid_N;
logic [7:0] arlen_C, arlen_N;
logic [0:0] arlock_C, arlock_N;
logic [2:0] arprot_C, arprot_N;
logic [3:0] arqos_C, arqos_N;
logic [3:0] arregion_C, arregion_N;
logic [2:0] arsize_C, arsize_N;

logic [AXI_ADDR_BITS-1:0] paddr_C, paddr_N;
logic [N_STRIPE_CHAN_BITS-1:0] pchan_C, pchan_N;
logic [7:0] plen_C, plen_N;
logic done_C, done_N;

logic [7:0] clen;
logic [7:0] slen;

logic [AXI_ADDR_BITS-1:0] araddr_remapped;

logic [AXI_ADDR_BITS-1:0] lsb_mask;
assign lsb_mask = (1 << FRAG_LOG_BITS) - 1;

logic [AXI_ADDR_BITS-1:0] msb_mask;
assign msb_mask = (~lsb_mask) << N_STRIPE_CHAN_BITS;

// Request order: channel, last part of the original request, original ID
typedef struct packed {
    logic [N_STRIPE_CHAN_BITS-1:0] chan;
    logic last;
    logic [AXI_ID_BITS-1:0] id;
} rd_seq_t;

metaIntf #(.STYPE(rd_seq_t)) seq_snk ();
metaIntf #(.STYPE(rd_seq_t)) seq_src ();

// Channel buffers
typedef struct packed {
    logic [AXI_DATA_BITS-1:0] data;
    logic [1:0] resp;
    logic last;
} rd_beat_t;

logic [N_STRIPE_CHAN-1:0] buff_wr;
logic [N_STRIPE_CHAN-1:0] buff_rd;
logic [N_STRIPE_CHAN-1:0] buff_valid;
logic [N_STRIPE_CHAN-1:0] buff_rst_busy;
rd_beat_t [N_STRIPE_CHAN-1:0] buff_dout;
rd_beat_t buff_din;

logic [N_STRIPE_CHAN-1:0][CRED_BITS-1:0] cred_C;
logic cred_ok;
logic ar_hs;
logic r_hs;
rd_beat_t r_head;

// REG
always_ff @(posedge aclk) begin
    if (aresetn == 1'b0) begin
        state_C <= ST_IDLE;

        araddr_C <= 'X;
        arburst_C <= 'X;
        arcache_C <= 'X;
        arid_C <= 'X;
        arlen_C <= 'X;
        arlock_C <= 'X;
        arprot_C <= 'X;
        arqos_C <= 'X;
        arregion_C <= 'X;
        arsize_C <= 'X;

        paddr_C <= 'X;
        pchan_C <= 'X;
        plen_C <= 'X;
        done_C <= 1'b0;
    end else begin
        state_C <= state_N;

        araddr_C <= araddr_N;
        arburst_C <= arburst_N;
        arcache_C <= arcache_N;
        arid_C <= arid_N;
        arlen_C <= arlen_N;
        arlock_C <= arlock_N;
        arprot_C <= arprot_N;
        arqos_C <= arqos_N;
        arregion_C <= arregion_N;
        arsize_C <= arsize_N;

        paddr_C <= paddr_N;
        pchan_C <= pchan_N;
        plen_C <= plen_N;
        done_C <= done_N;
    end
end

// NSL
always_comb begin
    unique case (state_C)
        ST_IDLE:
            state_N = s_axi_arvalid ? ST_PARSE : ST_IDLE;

        ST_PARSE:
            state_N = (done_C & ar_hs) ? ST_IDLE : ST_PARSE;
    endcase
end

// DP
always_comb begin
    araddr_N = araddr_C;
    arburst_N = arburst_C;
    arcache_N = arcache_C;
    arid_N = arid_C;
    arlen_N = arlen_C;
    arlock_N = arlock_C;
    arprot_N = arprot_C;
    arqos_N = arqos_C;
    arregion_N = arregion_C;
    arsize_N = arsize_C;

    paddr_N = paddr_C;
    pchan_N = pchan_C;
    plen_N = plen_C;
    done_N = done_C;

    araddr_remapped = 'X;

    slen = ((STRIPE_FRAG_SIZE >> BEAT_LOG_BITS) - (((s_axi_araddr - MEM_OFFSET) & lsb_mask) >> BEAT_LOG_BITS)) - 1;
    clen = ((STRIPE_FRAG_SIZE >> BEAT_LOG_BITS) - ((araddr_C & lsb_mask) >> BEAT_LOG_BITS)) - 1;

    s_axi_arready = 1'b0;

    unique case (state_C)
        ST_IDLE: begin
            if (s_axi_arvalid) begin
                s_axi_arready = 1'b1;

                arburst_N = s_axi_arburst;
                arcache_N = s_axi_arcache;
                arid_N = s_axi_arid;
                arlock_N = s_axi_arlock;
                arprot_N = s_axi_arprot;
                arqos_N = s_axi_arqos;
                arregion_N = s_axi_arregion;
                arsize_N = s_axi_arsize;

                araddr_remapped = s_axi_araddr - MEM_OFFSET;

                pchan_N = araddr_remapped[FRAG_LOG_BITS+:N_STRIPE_CHAN_BITS];
                paddr_N = (araddr_remapped[FRAG_LOG_BITS+:N_STRIPE_CHAN_BITS] << MC_SIZE) | (araddr_remapped & lsb_mask) | ((araddr_remapped & msb_mask) >> N_STRIPE_CHAN_BITS) + MEM_OFFSET;
                araddr_N = ((araddr_remapped >> FRAG_LOG_BITS) << FRAG_LOG_BITS) + STRIPE_FRAG_SIZE;           
                
                if (slen < s_axi_arlen) begin
                    plen_N = slen;
                    arlen_N = s_axi_arlen - slen - 1;
                    done_N = 1'b0;
                end else begin
                    plen_N = s_axi_arlen;
                    arlen_N = 0;
                    done_N = 1'b1;
                end
            end
        end

        ST_PARSE: begin
            if (ar_hs & ~done_C) begin
                araddr_remapped = araddr_C;

                pchan_N = araddr_remapped[FRAG_LOG_BITS+:N_STRIPE_CHAN_BITS];
                paddr_N = (araddr_remapped[FRAG_LOG_BITS+:N_STRIPE_CHAN_BITS] << MC_SIZE) | (araddr_remapped & lsb_mask) | ((araddr_remapped & msb_mask) >> N_STRIPE_CHAN_BITS) + MEM_OFFSET;
                araddr_N = ((araddr_remapped >> FRAG_LOG_BITS) << FRAG_LOG_BITS) + STRIPE_FRAG_SIZE; 

                if (clen < arlen_C) begin
                    plen_N = clen;
                    arlen_N = arlen_C - clen - 1;
                    done_N = 1'b0;
                end else begin
                    plen_N = arlen_C;
                    arlen_N = 0;
                    done_N = 1'b1;
                end
            end
        end        
    endcase
end

// AR
assign cred_ok = (cred_C[pchan_C] >= {1'b0, plen_C} + 1) && ~buff_rst_busy[pchan_C];

assign m_axi_arvalid = (state_C == ST_PARSE) && cred_ok && seq_snk.ready;
assign ar_hs = m_axi_arvalid & m_axi_arready;

assign m_axi_araddr = paddr_C;
assign m_axi_arburst = arburst_C;
assign m_axi_arcache = arcache_C;
assign m_axi_arid = pchan_C;
assign m_axi_arlen = plen_C;
assign m_axi_arlock = arlock_C;
assign m_axi_arprot = arprot_C;
assign m_axi_arqos = arqos_C;
assign m_axi_arregion = arregion_C;
assign m_axi_arsize = arsize_C;

// SEQ
queue_meta #(.QDEPTH(N_SEQ)) inst_seq_que (.aclk(aclk), .aresetn(aresetn), .s_meta(seq_snk), .m_meta(seq_src));

assign seq_snk.valid = ar_hs;
assign seq_snk.data.chan = pchan_C;
assign seq_snk.data.last = done_C;
assign seq_snk.data.id = arid_C;

// Credits, returned as the beats leave the buffers
always_ff @(posedge aclk) begin
    if (aresetn == 1'b0) begin
        for (int i = 0; i < N_STRIPE_CHAN; i++)
            cred_C[i] <= RD_BUFF_DEPTH;
    end else begin
        for (int i = 0; i < N_STRIPE_CHAN; i++)
            cred_C[i] <= cred_C[i] - ((ar_hs && (pchan_C == i)) ? ({1'b0, plen_C} + 1) : 0) + buff_rd[i];
    end
end

// R in
assign m_axi_rready = 1'b1;

assign buff_din.data = m_axi_rdata;
assign buff_din.resp = m_axi_rresp;
assign buff_din.last = m_axi_rlast;

for (genvar i = 0; i < N_STRIPE_CHAN; i++) begin
    assign buff_wr[i] = m_axi_rvalid && (m_axi_rid[N_STRIPE_CHAN_BITS-1:0] == i);
    assign buff_rd[i] = r_hs && (seq_src.data.chan == i);

    xpm_fifo_sync #(
        .FIFO_MEMORY_TYPE("block"),
        .FIFO_WRITE_DEPTH(RD_BUFF_DEPTH),
        .WRITE_DATA_WIDTH($bits(rd_beat_t)),
        .READ_DATA_WIDTH($bits(rd_beat_t)),
        .READ_MODE("fwft"),
        .FIFO_READ_LATENCY(0),
        .USE_ADV_FEATURES("1000"),
        .DOUT_RESET_VALUE("0"),
        .ECC_MODE("no_ecc"),
        .FULL_RESET_VALUE(0),
        .WAKEUP_TIME(0)
    ) inst_buff (
        .wr_clk(aclk),
        .rst(~aresetn),
        .wr_en(buff_wr[i]),
        .din(buff_din),
        .rd_en(buff_rd[i]),
        .dout(buff_dout[i]),
        .data_valid(buff_valid[i]),
        .wr_rst_busy(buff_rst_busy[i]),
        .rd_rst_busy(),
        .full(),
        .empty(),
        .almost_full(),
        .almost_empty(),
        .prog_full(),
        .prog_empty(),
        .wr_data_count(),
        .rd_data_count(),
        .overflow(),
        .underflow(),
        .wr_ack(),
        .sleep(1'b0),
        .injectsbiterr(1'b0),
        .injectdbiterr(1'b0),
        .sbiterr(),
        .dbiterr()
    );
end

// R out, in request order
assign r_head = buff_dout[seq_src.data.chan];

assign s_axi_rvalid = seq_src.valid && buff_valid[seq_src.data.chan];
assign s_axi_rdata = r_head.data;
assign s_axi_rresp = r_head.resp;
assign s_axi_rlast = r_head.last & seq_src.data.last;
assign s_axi_rid = seq_src.data.id;

assign r_hs = s_axi_rvalid & s_axi_rready;
assign seq_src.ready = r_hs & r_head.last;

endmodule
