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

module network_module #(
    parameter integer   N_STGS = 2
) (
    input  wire         init_clk,
    input  wire         sys_reset,

    // Shell network clock. Used only on Versal, where the DCMAC block design
    // consumes a clock and crosses to its own AXIS domain internally; the
    // UltraScale+ CMAC branch derives rclk from the transceiver instead and
    // leaves these unconnected.
    input  wire         nclk,
    input  wire         nresetn,

    output wire         rclk,
    output wire         rresetn,

    input  wire         gt_refclk_p,
    input  wire         gt_refclk_n,

    input  wire [3:0]   gt_rxp_in,
    input  wire [3:0]   gt_rxn_in,
    output wire [3:0]   gt_txp_out,
    output wire [3:0]   gt_txn_out,

    // Network streams
    AXI4S.m             m_axis_net_rx,
    AXI4S.s             s_axis_net_tx,

    // MAC bring-up status, rclk domain. Layout differs per arch; see the two
    // branches below. Zero-padded upwards so the width is stable.
    output wire [7:0]   mac_status,

    // Debug register port into the MAC, rclk domain. Single outstanding
    // request (see reg_port_ccross.sv). On Versal it reaches the DCMAC's
    // registers and a segment monitor (dcmac_debug.sv); the CMAC branch has
    // nothing behind it and fails every request.
    input  wire         mac_reg_req,
    input  wire         mac_reg_wr,
    input  wire [31:0]  mac_reg_addr,
    input  wire [31:0]  mac_reg_wdata,
    output wire         mac_reg_rsp,
    output wire [31:0]  mac_reg_rdata,
    output wire [1:0]   mac_reg_resp
);

`ifdef FPGA_ARCH_VERSAL

// ===========================================================================
// Versal: 200G DCMAC
//
// The block design owns both clock generation and clock-domain crossing, so
// Coyote's network domain *is* nclk and network_top's early crossing degrades
// to a pass-through. Frame padding lives in dcmac_axis_wrapper because the
// HLS padding IP the CMAC branch uses is not available on stack-bypassing
// builds.
// ===========================================================================

wire        dcmac_rst_done;
wire [4:0]  dcmac_rst_state;
wire        dcmac_gt_rst_done_tx;
wire        dcmac_gt_rst_done_rx;

assign rclk = nclk;

// Hold the network path in reset until the block design's reset FSM reaches
// ST_DONE, so nothing is offered to the MAC before it can carry it. This is
// the DCMAC analogue of the CMAC branch gating rresetn on core_tx_reset.
assign rresetn = nresetn & dcmac_rst_done;

assign mac_status = {dcmac_gt_rst_done_rx, dcmac_gt_rst_done_tx, dcmac_rst_done, dcmac_rst_state};

dcmac_axis_wrapper inst_dcmac_wrapper (
    .nclk               (nclk),
    .nresetn            (nresetn),

    .gt_ref_clk_p       (gt_refclk_p),
    .gt_ref_clk_n       (gt_refclk_n),
    .gt_rxp_in          (gt_rxp_in),
    .gt_rxn_in          (gt_rxn_in),
    .gt_txp_out         (gt_txp_out),
    .gt_txn_out         (gt_txn_out),

    .m_rx_axis          (m_axis_net_rx),
    .s_tx_axis          (s_axis_net_tx),

    .usr_clk            (),
    .dcmac_rst_done     (dcmac_rst_done),
    .dcmac_rst_state    (dcmac_rst_state),
    .gt_rst_done_tx     (dcmac_gt_rst_done_tx),
    .gt_rst_done_rx     (dcmac_gt_rst_done_rx),

    .reg_req            (mac_reg_req),
    .reg_wr             (mac_reg_wr),
    .reg_addr           (mac_reg_addr),
    .reg_wdata          (mac_reg_wdata),
    .reg_rsp            (mac_reg_rsp),
    .reg_rdata          (mac_reg_rdata),
    .reg_resp           (mac_reg_resp)
);

`else

// ===========================================================================
// UltraScale+: 100G CMAC
// ===========================================================================

wire network_init_done;
//wire user_rx_reset;
wire user_tx_reset;
reg core_reset_tmp = 1'b0;
reg core_reset = 1'b0;

// Network reset
always @(posedge rclk) begin 
      //core_reset_tmp <= !(user_tx_reset | user_rx_reset);
      core_reset_tmp <= !(user_tx_reset);
      core_reset     <= core_reset_tmp;
end
assign network_init_done = core_reset;

BUFG bufg_aresetn(
    .I(network_init_done),
    .O(rresetn)
);

/*
 * RX
 */
AXI4S #(.AXI4S_DATA_BITS(AXI_NET_BITS)) rx_axis_cmac (.aclk(rclk), .aresetn(rresetn));
AXI4S #(.AXI4S_DATA_BITS(AXI_NET_BITS)) rx_axis (.aclk(rclk), .aresetn(rresetn));

logic [31:0] wr_cnt;
logic prog_full;

/*
 * TX
 */
AXI4S #(.AXI4S_DATA_BITS(AXI_NET_BITS)) tx_axis_cmac (.aclk(rclk), .aresetn(rresetn));
AXI4S #(.AXI4S_DATA_BITS(AXI_NET_BITS)) tx_axis (.aclk(rclk), .aresetn(rresetn));
AXI4S #(.AXI4S_DATA_BITS(AXI_NET_BITS)) axis_tx_pkg_to_fifo (.aclk(rclk), .aresetn(rresetn));
AXI4S #(.AXI4S_DATA_BITS(AXI_NET_BITS)) axis_tx_padding_to_fifo (.aclk(rclk), .aresetn(rresetn));

// Slice
axis_reg_array #(.N_STAGES(2)) inst_reg_rx (.aclk(rclk), .aresetn(rresetn), .s_axis(rx_axis_cmac), .m_axis(rx_axis));
axis_reg_array #(.N_STAGES(2)) inst_reg_tx (.aclk(rclk), .aresetn(rresetn), .s_axis(tx_axis), .m_axis(tx_axis_cmac));


// CMAC
cmac_axis_wrapper cmac_wrapper_inst (
    .init_clk(init_clk),
    .sys_reset(sys_reset),

    .gt_ref_clk_p(gt_refclk_p),
    .gt_ref_clk_n(gt_refclk_n),
    .gt_rxp_in(gt_rxp_in),
    .gt_rxn_in(gt_rxn_in),
    .gt_txp_out(gt_txp_out),
    .gt_txn_out(gt_txn_out),
    
    .m_rx_axis(rx_axis_cmac),
    .s_tx_axis(tx_axis_cmac),

    .usr_clk(rclk),
    .tx_rst(user_tx_reset)
    //.rx_rst(user_rx_reset)
);

// RX Clock crossing (same clock)
axis_data_fifo_512_cc_rx rx_crossing (
  .s_axis_aresetn(rresetn),
  .s_axis_aclk(rclk),
  .s_axis_tvalid(rx_axis.tvalid),
  .s_axis_tready(rx_axis.tready),
  .s_axis_tdata(rx_axis.tdata),
  .s_axis_tkeep(rx_axis.tkeep),
  .s_axis_tlast(rx_axis.tlast),
  //.m_axis_aclk(rclk),
  .m_axis_tvalid(m_axis_net_rx.tvalid),
  .m_axis_tready(m_axis_net_rx.tready),
  .m_axis_tdata(m_axis_net_rx.tdata),
  .m_axis_tkeep(m_axis_net_rx.tkeep),
  .m_axis_tlast(m_axis_net_rx.tlast),
  .axis_wr_data_count(wr_cnt),
  .prog_full(prog_full)
);

// TX
// Pad Ethernet frames to at least 64B
// Packet FIFO, makes sure that whole packet is passed in a single burst to the CMAC
axis_data_fifo_512_cc_tx tx_crossing (
  .s_axis_aresetn(rresetn),
  .s_axis_aclk(rclk),
  .s_axis_tvalid(axis_tx_pkg_to_fifo.tvalid),
  .s_axis_tready(axis_tx_pkg_to_fifo.tready),
  .s_axis_tdata(axis_tx_pkg_to_fifo.tdata),
  .s_axis_tkeep(axis_tx_pkg_to_fifo.tkeep),
  .s_axis_tlast(axis_tx_pkg_to_fifo.tlast),
  //.m_axis_aclk(rclk),
  .m_axis_tvalid(tx_axis.tvalid),
  .m_axis_tready(tx_axis.tready),
  .m_axis_tdata(tx_axis.tdata),
  .m_axis_tkeep(tx_axis.tkeep),
  .m_axis_tlast(tx_axis.tlast)
);

axis_pkg_fifo_512 axis_pkg_fifo_512 (
  .s_axis_aresetn(rresetn),
  .s_axis_aclk(rclk),
  .s_axis_tvalid(axis_tx_padding_to_fifo.tvalid),
  .s_axis_tready(axis_tx_padding_to_fifo.tready),
  .s_axis_tdata(axis_tx_padding_to_fifo.tdata),
  .s_axis_tkeep(axis_tx_padding_to_fifo.tkeep),
  .s_axis_tlast(axis_tx_padding_to_fifo.tlast),
  .m_axis_tvalid(axis_tx_pkg_to_fifo.tvalid),
  .m_axis_tready(axis_tx_pkg_to_fifo.tready),
  .m_axis_tdata(axis_tx_pkg_to_fifo.tdata),
  .m_axis_tkeep(axis_tx_pkg_to_fifo.tkeep),
  .m_axis_tlast(axis_tx_pkg_to_fifo.tlast)
);

ethernet_frame_padding_512_ip ethernet_frame_padding_inst (
  .ap_clk(rclk),
  .ap_rst_n(rresetn),
  .m_axis_TVALID(axis_tx_padding_to_fifo.tvalid),
  .m_axis_TREADY(axis_tx_padding_to_fifo.tready),
  .m_axis_TDATA(axis_tx_padding_to_fifo.tdata),
  .m_axis_TKEEP(axis_tx_padding_to_fifo.tkeep),
  .m_axis_TLAST(axis_tx_padding_to_fifo.tlast),
  .s_axis_TVALID(s_axis_net_tx.tvalid),
  .s_axis_TREADY(s_axis_net_tx.tready),
  .s_axis_TDATA(s_axis_net_tx.tdata),
  .s_axis_TKEEP(s_axis_net_tx.tkeep),
  .s_axis_TLAST(s_axis_net_tx.tlast)
);

// The CMAC branch has no equivalent of the DCMAC reset FSM state, so only the
// bottom bit is meaningful: it reports that the MAC has come out of reset.
assign mac_status = {7'b0, network_init_done};

// No debug registers behind the CMAC: answer every request with SLVERR on the
// next cycle, so a requester never waits on a response that cannot come.
reg mac_reg_rsp_q = 1'b0;
always @(posedge rclk) begin
    mac_reg_rsp_q <= mac_reg_req;
end
assign mac_reg_rsp   = mac_reg_rsp_q;
assign mac_reg_rdata = 32'h0;
assign mac_reg_resp  = 2'b10;

`endif

endmodule

`default_nettype wire
