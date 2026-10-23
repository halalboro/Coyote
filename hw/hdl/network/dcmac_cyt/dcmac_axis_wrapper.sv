/**
 * This file is part of the Coyote <https://github.com/fpgasystems/Coyote>
 *
 * MIT Licence
 * Copyright (c) 2026, Systems Group, ETH Zurich
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

/**
 * Coyote-side wrapper around the Versal DCMAC block design (200 Gb/s).
 *
 * Counterpart to `cmac_axis_wrapper` on UltraScale+, but the two cannot share
 * a signature: the CMAC wrapper *produces* the network clock (`usr_clk` is the
 * GT `txusrclk2`), whereas the DCMAC block design *consumes* one on `aclk` and
 * does all clock-domain crossing internally, in an async AXIS FIFO per
 * direction. So this module takes `nclk` in and echoes it back out on
 * `usr_clk`, which keeps `network_module`'s two arch branches structurally
 * identical and makes `network_top`'s early crossing a pass-through.
 *
 * Everything below `S_AXIS_0`/`M_AXIS_0` - the GT quads, the DCMAC hard block,
 * the segmented-to-unsegmented converters, the 782/390.625/100 MHz clocks and
 * the reset FSM - lives inside the block design built by `bd_dcmac`
 * (hw/bd/versal/cr_dcmac.tcl). The GT serial and reference clock pins are not
 * constrained by any XDC: they follow from `CONFIG.DCMAC_LOCATION_C0` and the
 * quad it anchors.
 *
 * This wrapper adds only what the block design deliberately leaves out:
 *   - minimum-frame padding on TX (the CMAC path gets this from an HLS IP that
 *     is not available on stack-bypassing builds),
 *   - synchronisation of the block design's bring-up status, which is exposed
 *     in the internally generated 100 MHz sys_clk domain, into `nclk`, and
 *   - a register port (dcmac_debug.sv) onto the DCMAC's own PG369 registers
 *     and a segment-level monitor of the MAC client interface, which is the
 *     only way to see the hard block's counters and PHY/MAC status.
 *
 * The block design's module name embeds the DCMAC index
 * (`dcmac_<index>_versal_axis_wrapper`) and a module name cannot be a
 * parameter in SystemVerilog, so the index is selected by preprocessor macro
 * below. EN_NET_1 picks index 1; only one is ever built, so only the selected
 * name has to resolve.
 *
 * On the V80 the index chooses which pair of QSFP cages is reachable:
 *
 *   index 0 = DCMAC_X1Y1 -> GTM_QUAD_X1Y7 (bank 209) = qsfp0, refclk AR51/AR52
 *   index 1 = DCMAC_X0Y2 -> GTM_QUAD_X0Y9 (bank 111) = qsfp3, refclk AL17/AL16
 *
 * (Each DCMAC site also has a second quad — bank 210 = qsfp1 and bank 112 =
 * qsfp2 respectively — but reaching it needs upstream's dual-QSFP mode, which
 * is hardware-unvalidated and not enabled here.)
 */

`ifdef EN_NET_1
  `define DCMAC_BD_MODULE dcmac_1_versal_axis_wrapper
`else
  `define DCMAC_BD_MODULE dcmac_0_versal_axis_wrapper
`endif
module dcmac_axis_wrapper (
    // Network clock and reset, supplied by Coyote. The block design crosses
    // internally from here to its own 390.625 MHz AXIS domain.
    input  wire                 nclk,
    input  wire                 nresetn,

    // QSFP56 transceivers
    input  wire                 gt_ref_clk_p,
    input  wire                 gt_ref_clk_n,
    input  wire [3:0]           gt_rxp_in,
    input  wire [3:0]           gt_rxn_in,
    output wire [3:0]           gt_txn_out,
    output wire [3:0]           gt_txp_out,

    // 512-bit raw Ethernet, nclk domain
    AXI4S.m                     m_rx_axis,
    AXI4S.s                     s_tx_axis,

    // Echo of nclk, so the caller can treat this like cmac_axis_wrapper
    output wire                 usr_clk,

    // Bring-up status, synchronised into nclk.
    // rst_done gates the network path out of reset; the rest is debug-grade.
    output wire                 dcmac_rst_done,
    output wire [4:0]           dcmac_rst_state,
    output wire                 gt_rst_done_tx,
    output wire                 gt_rst_done_rx,

    // Debug register port, nclk. Single outstanding request; see
    // reg_port_ccross.sv for the contract and dcmac_debug.sv for the map.
    input  wire                 reg_req,
    input  wire                 reg_wr,
    input  wire [31:0]          reg_addr,
    input  wire [31:0]          reg_wdata,
    output wire                 reg_rsp,
    output wire [31:0]          reg_rdata,
    output wire [1:0]           reg_resp
);

assign usr_clk = nclk;

// ---------------------------------------------------------------------------
// TX: pad runt frames before handing them to the MAC
// ---------------------------------------------------------------------------
AXI4S #(.AXI4S_DATA_BITS(AXI_NET_BITS)) axis_tx_padded (.aclk(nclk), .aresetn(nresetn));

eth_frame_padder_512 inst_tx_padder (
    .aclk       (nclk),
    .aresetn    (nresetn),
    .s_axis     (s_tx_axis),
    .m_axis     (axis_tx_padded)
);

// ---------------------------------------------------------------------------
// Block design
//
// Port names are the flattened form of the block design boundary:
// interface ports become <name>_<signal>, so the AXIS pair is S_AXIS_0_* /
// M_AXIS_0_*, the diff_clock_rtl reference clock is qsfp_gt_clk_clk_p/_n, and
// the gt_rtl serial port is qsfp_gt0_grx_p/_n and qsfp_gt0_gtx_p/_n.
// ---------------------------------------------------------------------------
wire [4:0] rst_state_sys;
wire       rst_done_sys;
wire       gt_rst_done_tx_sys;
wire       gt_rst_done_rx_sys;

// Register port into the DCMAC (nclk side of the block design's SmartConnect)
wire [31:0] dcmac_axil_awaddr;
wire        dcmac_axil_awvalid;
wire        dcmac_axil_awready;
wire [31:0] dcmac_axil_wdata;
wire [3:0]  dcmac_axil_wstrb;
wire        dcmac_axil_wvalid;
wire        dcmac_axil_wready;
wire [1:0]  dcmac_axil_bresp;
wire        dcmac_axil_bvalid;
wire        dcmac_axil_bready;
wire [31:0] dcmac_axil_araddr;
wire        dcmac_axil_arvalid;
wire        dcmac_axil_arready;
wire [31:0] dcmac_axil_rdata;
wire [1:0]  dcmac_axil_rresp;
wire        dcmac_axil_rvalid;
wire        dcmac_axil_rready;

// Statistics tick pins (APB3_CLK = mon_apb_clk domain)
wire [5:0]  tx_port_pm_tick;
wire [5:0]  rx_port_pm_tick;
wire        tx_all_channel_mac_pm_tick;
wire        rx_all_channel_mac_pm_tick;

// Monitor taps (mon_dclk domain)
wire        mon_dclk;
wire        mon_apb_clk;
wire        mon_rx_tvalid, mon_tx_tvalid, mon_tx_tready;
wire [3:0]  mon_rx_ena, mon_rx_sop, mon_rx_eop, mon_rx_err;
wire [3:0]  mon_tx_ena, mon_tx_sop, mon_tx_eop, mon_tx_err;
wire [15:0] mon_rx_mty, mon_tx_mty;

// RX error flag carried on the block design's tuser, one bit per byte. The
// Coyote stream has no tuser, so it is observed here and otherwise dropped.
wire [AXI_NET_BITS/8-1:0] rx_tuser;

`DCMAC_BD_MODULE inst_dcmac_bd (
    .aclk               (nclk),
    .aresetn            (nresetn),

    .qsfp_gt_clk_clk_p  (gt_ref_clk_p),
    .qsfp_gt_clk_clk_n  (gt_ref_clk_n),

    .qsfp_gt0_grx_p     (gt_rxp_in),
    .qsfp_gt0_grx_n     (gt_rxn_in),
    .qsfp_gt0_gtx_p     (gt_txp_out),
    .qsfp_gt0_gtx_n     (gt_txn_out),

    .S_AXIS_0_tdata     (axis_tx_padded.tdata),
    .S_AXIS_0_tkeep     (axis_tx_padded.tkeep),
    .S_AXIS_0_tlast     (axis_tx_padded.tlast),
    .S_AXIS_0_tready    (axis_tx_padded.tready),
    .S_AXIS_0_tvalid    (axis_tx_padded.tvalid),

    .M_AXIS_0_tdata     (m_rx_axis.tdata),
    .M_AXIS_0_tkeep     (m_rx_axis.tkeep),
    .M_AXIS_0_tlast     (m_rx_axis.tlast),
    .M_AXIS_0_tready    (m_rx_axis.tready),
    .M_AXIS_0_tvalid    (m_rx_axis.tvalid),

    .M_AXIS_0_tuser     (rx_tuser),

    .rst_state_dbg      (rst_state_sys),
    .rst_done           (rst_done_sys),
    .gt_rst_done_tx     (gt_rst_done_tx_sys),
    .gt_rst_done_rx     (gt_rst_done_rx_sys),

    .s_axi_awaddr       (dcmac_axil_awaddr),
    .s_axi_awprot       (3'b000),
    .s_axi_awvalid      (dcmac_axil_awvalid),
    .s_axi_awready      (dcmac_axil_awready),
    .s_axi_wdata        (dcmac_axil_wdata),
    .s_axi_wstrb        (dcmac_axil_wstrb),
    .s_axi_wvalid       (dcmac_axil_wvalid),
    .s_axi_wready       (dcmac_axil_wready),
    .s_axi_bresp        (dcmac_axil_bresp),
    .s_axi_bvalid       (dcmac_axil_bvalid),
    .s_axi_bready       (dcmac_axil_bready),
    .s_axi_araddr       (dcmac_axil_araddr),
    .s_axi_arprot       (3'b000),
    .s_axi_arvalid      (dcmac_axil_arvalid),
    .s_axi_arready      (dcmac_axil_arready),
    .s_axi_rdata        (dcmac_axil_rdata),
    .s_axi_rresp        (dcmac_axil_rresp),
    .s_axi_rvalid       (dcmac_axil_rvalid),
    .s_axi_rready       (dcmac_axil_rready),

    .tx_port_pm_tick            (tx_port_pm_tick),
    .rx_port_pm_tick            (rx_port_pm_tick),
    .tx_all_channel_mac_pm_tick (tx_all_channel_mac_pm_tick),
    .rx_all_channel_mac_pm_tick (rx_all_channel_mac_pm_tick),

    .mon_dclk           (mon_dclk),
    .mon_apb_clk        (mon_apb_clk),
    .mon_rx_tvalid      (mon_rx_tvalid),
    .mon_rx_ena0 (mon_rx_ena[0]), .mon_rx_ena1 (mon_rx_ena[1]), .mon_rx_ena2 (mon_rx_ena[2]), .mon_rx_ena3 (mon_rx_ena[3]),
    .mon_rx_sop0 (mon_rx_sop[0]), .mon_rx_sop1 (mon_rx_sop[1]), .mon_rx_sop2 (mon_rx_sop[2]), .mon_rx_sop3 (mon_rx_sop[3]),
    .mon_rx_eop0 (mon_rx_eop[0]), .mon_rx_eop1 (mon_rx_eop[1]), .mon_rx_eop2 (mon_rx_eop[2]), .mon_rx_eop3 (mon_rx_eop[3]),
    .mon_rx_err0 (mon_rx_err[0]), .mon_rx_err1 (mon_rx_err[1]), .mon_rx_err2 (mon_rx_err[2]), .mon_rx_err3 (mon_rx_err[3]),
    .mon_rx_mty0 (mon_rx_mty[3:0]), .mon_rx_mty1 (mon_rx_mty[7:4]), .mon_rx_mty2 (mon_rx_mty[11:8]), .mon_rx_mty3 (mon_rx_mty[15:12]),
    .mon_tx_tvalid      (mon_tx_tvalid),
    .mon_tx_tready      (mon_tx_tready),
    .mon_tx_ena0 (mon_tx_ena[0]), .mon_tx_ena1 (mon_tx_ena[1]), .mon_tx_ena2 (mon_tx_ena[2]), .mon_tx_ena3 (mon_tx_ena[3]),
    .mon_tx_sop0 (mon_tx_sop[0]), .mon_tx_sop1 (mon_tx_sop[1]), .mon_tx_sop2 (mon_tx_sop[2]), .mon_tx_sop3 (mon_tx_sop[3]),
    .mon_tx_eop0 (mon_tx_eop[0]), .mon_tx_eop1 (mon_tx_eop[1]), .mon_tx_eop2 (mon_tx_eop[2]), .mon_tx_eop3 (mon_tx_eop[3]),
    .mon_tx_err0 (mon_tx_err[0]), .mon_tx_err1 (mon_tx_err[1]), .mon_tx_err2 (mon_tx_err[2]), .mon_tx_err3 (mon_tx_err[3]),
    .mon_tx_mty0 (mon_tx_mty[3:0]), .mon_tx_mty1 (mon_tx_mty[7:4]), .mon_tx_mty2 (mon_tx_mty[11:8]), .mon_tx_mty3 (mon_tx_mty[15:12])
);

// ---------------------------------------------------------------------------
// Debug port: DCMAC registers + segment monitor
// ---------------------------------------------------------------------------
dcmac_debug inst_dcmac_debug (
    .nclk               (nclk),
    .nresetn            (nresetn),

    .reg_req            (reg_req),
    .reg_wr             (reg_wr),
    .reg_addr           (reg_addr),
    .reg_wdata          (reg_wdata),
    .reg_rsp            (reg_rsp),
    .reg_rdata          (reg_rdata),
    .reg_resp           (reg_resp),

    .m_axil_awaddr      (dcmac_axil_awaddr),
    .m_axil_awvalid     (dcmac_axil_awvalid),
    .m_axil_awready     (dcmac_axil_awready),
    .m_axil_wdata       (dcmac_axil_wdata),
    .m_axil_wstrb       (dcmac_axil_wstrb),
    .m_axil_wvalid      (dcmac_axil_wvalid),
    .m_axil_wready      (dcmac_axil_wready),
    .m_axil_bresp       (dcmac_axil_bresp),
    .m_axil_bvalid      (dcmac_axil_bvalid),
    .m_axil_bready      (dcmac_axil_bready),
    .m_axil_araddr      (dcmac_axil_araddr),
    .m_axil_arvalid     (dcmac_axil_arvalid),
    .m_axil_arready     (dcmac_axil_arready),
    .m_axil_rdata       (dcmac_axil_rdata),
    .m_axil_rresp       (dcmac_axil_rresp),
    .m_axil_rvalid      (dcmac_axil_rvalid),
    .m_axil_rready      (dcmac_axil_rready),

    .apb_clk                    (mon_apb_clk),
    .tx_port_pm_tick            (tx_port_pm_tick),
    .rx_port_pm_tick            (rx_port_pm_tick),
    .tx_all_channel_mac_pm_tick (tx_all_channel_mac_pm_tick),
    .rx_all_channel_mac_pm_tick (rx_all_channel_mac_pm_tick),

    .bd_tx_tvalid       (axis_tx_padded.tvalid),
    .bd_tx_tready       (axis_tx_padded.tready),
    .bd_tx_tlast        (axis_tx_padded.tlast),
    .bd_rx_tvalid       (m_rx_axis.tvalid),
    .bd_rx_tready       (m_rx_axis.tready),
    .bd_rx_tlast        (m_rx_axis.tlast),
    .bd_rx_tuser_any    (|rx_tuser),

    .dclk               (mon_dclk),
    .rx_tvalid          (mon_rx_tvalid),
    .rx_ena             (mon_rx_ena),
    .rx_sop             (mon_rx_sop),
    .rx_eop             (mon_rx_eop),
    .rx_err             (mon_rx_err),
    .rx_mty             (mon_rx_mty),
    .tx_tvalid          (mon_tx_tvalid),
    .tx_tready          (mon_tx_tready),
    .tx_ena             (mon_tx_ena),
    .tx_sop             (mon_tx_sop),
    .tx_eop             (mon_tx_eop),
    .tx_err             (mon_tx_err),
    .tx_mty             (mon_tx_mty)
);

// ---------------------------------------------------------------------------
// Status CDC: sys_clk (100 MHz, internal to the block design) -> nclk
//
// SRC_INPUT_REG = 0 throughout: every one of these is already a flop output in
// the source domain, so re-registering would only add latency. rst_done is a
// single bit and therefore crosses exactly; the debug vectors use
// xpm_cdc_array_single, whose bits are independent and may momentarily
// disagree during a transition. That is acceptable for a status readout and
// is why rst_done is a separate signal rather than a decode of rst_state.
// ---------------------------------------------------------------------------
xpm_cdc_single #(
    .DEST_SYNC_FF   (4),
    .INIT_SYNC_FF   (0),
    .SIM_ASSERT_CHK (1),
    .SRC_INPUT_REG  (0)
) inst_cdc_rst_done (
    .src_clk  (1'b0),
    .src_in   (rst_done_sys),
    .dest_clk (nclk),
    .dest_out (dcmac_rst_done)
);

xpm_cdc_array_single #(
    .DEST_SYNC_FF   (4),
    .INIT_SYNC_FF   (0),
    .SIM_ASSERT_CHK (1),
    .SRC_INPUT_REG  (0),
    .WIDTH          (5)
) inst_cdc_rst_state (
    .src_clk  (1'b0),
    .src_in   (rst_state_sys),
    .dest_clk (nclk),
    .dest_out (dcmac_rst_state)
);

xpm_cdc_array_single #(
    .DEST_SYNC_FF   (4),
    .INIT_SYNC_FF   (0),
    .SIM_ASSERT_CHK (1),
    .SRC_INPUT_REG  (0),
    .WIDTH          (2)
) inst_cdc_gt_done (
    .src_clk  (1'b0),
    .src_in   ({gt_rst_done_rx_sys, gt_rst_done_tx_sys}),
    .dest_clk (nclk),
    .dest_out ({gt_rst_done_rx, gt_rst_done_tx})
);

endmodule

`undef DCMAC_BD_MODULE
