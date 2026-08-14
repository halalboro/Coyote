/**
 * BRAID elaboration check — catches what the protocol testbenches cannot
 *
 * WHY THIS EXISTS. A bitgen failed with seven "named port connection does not
 * exist" errors: braid_phy_gty sits between braid_framer and braid_gty_wrapper,
 * and when sidebands were added to the two outer modules it never got them. The
 * pre-build check at the time ran `xvlog` over those files and reported OK --
 * because xvlog PARSES. Port-connection mismatches are an ELABORATION error,
 * and nothing was elaborating the shell hierarchy.
 *
 * tb_braid does not catch it either: it instantiates braid_framer and the link
 * cores directly and never goes through braid_phy_gty or braid_gty_wrapper.
 *
 * So this file elaborates BOTH real hierarchies, top to bottom:
 *   lint_shell_tb -> braid_gty_wrapper -> braid_phy_gty -> braid_framer
 *   lint_user_tb  -> design_user_logic_c0_0 -> vfpga_top.svh -> link cores
 *
 * Everything below is a stub with the right ports and no behaviour. It is not a
 * model of anything and must never be used to check function -- that is what the
 * other three testbenches are for. It answers exactly one question: does the
 * design still connect together.
 */

`timescale 1ns/1ps

// --------------------------------------------------------------- Coyote stubs
package lynxTypes;
    parameter int AXIL_DATA_BITS = 64;
    parameter int N_STRM_AXI     = 1;
endpackage

interface AXI4L;
    logic [63:0] awaddr, araddr, wdata, rdata;
    logic [7:0]  wstrb;
    logic        awvalid, awready, wvalid, wready, bvalid, bready;
    logic        arvalid, arready, rvalid, rready;
    logic [1:0]  bresp, rresp;
    modport s (input awaddr, awvalid, wdata, wstrb, wvalid, bready,
                     araddr, arvalid, rready,
               output awready, wready, bvalid, bresp, rdata, rvalid, rresp, arready);
endinterface

interface AXI4S #(parameter int AXI4S_DATA_BITS = 256);
    logic [AXI4S_DATA_BITS-1:0]   tdata;
    logic [AXI4S_DATA_BITS/8-1:0] tkeep;
    logic tvalid, tready, tlast;
    modport s (input tdata, tkeep, tvalid, tlast, output tready);
    modport m (output tdata, tkeep, tvalid, tlast, input tready);
endinterface

interface AXI4SR;
    logic [511:0] tdata;
    logic tvalid, tready, tlast;
    task tie_off_s(); tready = 1'b0; endtask
    task tie_off_m(); tvalid = 1'b0; tdata = '0; tlast = 1'b0; endtask
    modport s (input tdata, tvalid, tlast, output tready, import tie_off_s);
    modport m (output tdata, tvalid, tlast, input tready, import tie_off_m);
endinterface

interface metaIntf;
    logic valid, ready;
    logic [63:0] data;
    task tie_off_s(); ready = 1'b0; endtask
    task tie_off_m(); valid = 1'b0; data = '0; endtask
    modport s (input valid, data, output ready, import tie_off_s);
    modport m (output valid, data, input ready, import tie_off_m);
endinterface

// ------------------------------------------------------- gtwizard IP stub
// Ports and widths from the real generated wrapper (gtwizard_ultrascale:1.7,
// GTYE4). If braid_phy_gty gains or loses a GT connection, update this too --
// a mismatch here is the same class of error this file exists to catch.
module braid_gty (
    input  wire        gtwiz_userclk_tx_active_in, gtwiz_userclk_rx_active_in,
    input  wire        gtwiz_buffbypass_tx_reset_in, gtwiz_buffbypass_tx_start_user_in,
    output wire        gtwiz_buffbypass_tx_done_out, gtwiz_buffbypass_tx_error_out,
    input  wire        gtwiz_buffbypass_rx_reset_in, gtwiz_buffbypass_rx_start_user_in,
    output wire        gtwiz_buffbypass_rx_done_out, gtwiz_buffbypass_rx_error_out,
    input  wire        gtwiz_reset_clk_freerun_in, gtwiz_reset_all_in,
    input  wire        gtwiz_reset_tx_pll_and_datapath_in, gtwiz_reset_tx_datapath_in,
    input  wire        gtwiz_reset_rx_pll_and_datapath_in, gtwiz_reset_rx_datapath_in,
    output wire        gtwiz_reset_rx_cdr_stable_out,
    output wire        gtwiz_reset_tx_done_out, gtwiz_reset_rx_done_out,
    input  wire [31:0] gtwiz_userdata_tx_in,
    output wire [31:0] gtwiz_userdata_rx_out,
    input  wire        gtrefclk00_in,
    output wire        qpll0outclk_out, qpll0outrefclk_out,
    input  wire        gtyrxn_in, gtyrxp_in,
    input  wire [2:0]  loopback_in,
    output wire [2:0]  rxbufstatus_out,
    input  wire        rxslide_in,
    input  wire        rxusrclk_in, rxusrclk2_in,
    input  wire        txusrclk_in, txusrclk2_in,
    output wire        gtpowergood_out, gtytxn_out, gtytxp_out,
    output wire        rxoutclk_out, rxpmaresetdone_out,
    output wire        txoutclk_out, txpmaresetdone_out, txprgdivresetdone_out
);
endmodule

// --------------------------------------------- the vFPGA top, as generated
import lynxTypes::*;

module design_user_logic_c0_0 (
    AXI4L.s                     axi_ctrl,
    metaIntf.m                  notify,
    metaIntf.m                  sq_rd,
    metaIntf.m                  sq_wr,
    metaIntf.s                  cq_rd,
    metaIntf.s                  cq_wr,
    AXI4SR.s                    axis_host_recv [N_STRM_AXI],
    AXI4SR.m                    axis_host_send [N_STRM_AXI],
    AXI4S.s                     axis_aurora_rx,
    AXI4S.m                     axis_aurora_tx,
    input  wire                 aurora_channel_up,
    input  wire[3:0]            aurora_lane_up,
    input  wire                 braid_tx_clk,
    input  wire                 braid_rx_clk,
    input  wire                 braid_tx_rstn,
    input  wire                 braid_rx_rstn,
    output wire[2:0]            braid_loopback_sel,
    input  wire                 aclk,
    input  wire[0:0]            aresetn
);

`include "vfpga_top.svh"

endmodule

// ------------------------------------------------------------- the two tops
module lint_shell_tb;
    logic init_clk=0, sys_reset=1, aclk=0, aresetn=0;
    logic gt_refclk_p=0, gt_refclk_n=0, gt_rxp_in=0, gt_rxn_in=0;
    wire  gt_txp_out, gt_txn_out;
    wire  tx_clk, rx_clk, tx_rstn, rx_rstn, channel_up;
    wire [3:0] lane_up;
    logic [2:0] loopback_sel = 3'b0;

    AXI4S #(.AXI4S_DATA_BITS(256)) braid_rx (), braid_tx ();

    braid_gty_wrapper #(.LOOPBACK(0)) dut (
        .init_clk(init_clk), .sys_reset(sys_reset), .aclk(aclk), .aresetn(aresetn),
        .gt_refclk_p(gt_refclk_p), .gt_refclk_n(gt_refclk_n),
        .gt_rxp_in(gt_rxp_in), .gt_rxn_in(gt_rxn_in),
        .gt_txp_out(gt_txp_out), .gt_txn_out(gt_txn_out),
        .tx_clk(tx_clk), .rx_clk(rx_clk), .tx_rstn(tx_rstn), .rx_rstn(rx_rstn),
        .m_braid_rx(braid_rx), .s_braid_tx(braid_tx),
        .loopback_sel(loopback_sel),
        .channel_up(channel_up), .lane_up(lane_up)
    );
endmodule

module lint_user_tb;
    logic aclk=0, aresetn=0, braid_tx_clk=0, braid_rx_clk=0;
    logic braid_tx_rstn=0, braid_rx_rstn=0;
    logic aurora_channel_up=0; logic [3:0] aurora_lane_up=0;
    wire [2:0] braid_loopback_sel;

    AXI4L  axi_ctrl();
    metaIntf notify(), sq_rd(), sq_wr(), cq_rd(), cq_wr();
    AXI4SR axis_host_recv[N_STRM_AXI](), axis_host_send[N_STRM_AXI]();
    AXI4S #(.AXI4S_DATA_BITS(256)) axis_aurora_rx(), axis_aurora_tx();

    design_user_logic_c0_0 dut (.*);
endmodule
