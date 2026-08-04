/**
 * Coyote — Aurora 64B/66B shell-side wrapper
 *
 * Wraps the Xilinx Aurora 64B/66B v13.0 IP (generated as `aurora_loopback_ip`
 * by scripts/ip_inst/aurora_infrastructure.tcl at shell-build time) and presents
 * an aclk-domain AXI4-Stream pair to the rest of the shell. Sits structurally
 * parallel to `network_top` (which wraps CMAC); the two are independent peers,
 * each owning one QSFP cage.
 *
 * Configuration (must match aurora_infrastructure.tcl):
 *   - 4 lanes bonded
 *   - 25.78125 Gbps per lane
 *   - 161.1328125 MHz differential MGT reference clock from QSFP1
 *   - 256-bit AXI4-Stream user interface @ Aurora user_clk_out (~390 MHz)
 *   - Framing mode (no UFC, no flow control)
 *   - SupportLevel=1  (shared logic / QPLL inside the core in Vivado 2023.2)
 *   - drp_mode=Native (native DRP ports, no AXI4-Lite DRP slave)
 *
 * The IP wrapper:
 *   - Takes the differential MGTREFCLK pins directly (`gt_refclk1_p/n`); its
 *     own internal IBUFDS_GTE4 drives the GTY quad. No external buffer.
 *   - Generates `user_clk_out` (~390 MHz) and `sync_clk_out`. We use
 *     `user_clk_out` as the source clock for both axis_data_fifo CDC FIFOs.
 *   - Uses big-endian [0:N-1] bit ordering on tdata/tkeep/lane_up. We bit-
 *     reverse on the boundary so external nets stay little-endian [N-1:0]
 *     (Coyote convention).
 *
 * Init FSM (init_clk @ 100 MHz):
 *   - On sys_reset, hold pma_init and reset_pb both high.
 *   - After ~50 us (5000 init_clk cycles), drop pma_init.
 *   - After ~100 us (10000 init_clk cycles), drop reset_pb.
 *   - Aurora then handles internal block-sync / clock-correction / bonding.
 */

`timescale 1ns / 1ps

import lynxTypes::*;

module aurora_module (
    // System
    input  logic                init_clk,    // 100 MHz from PCIe / sys clock
    input  logic                sys_reset,   // synchronous-to-init_clk, active high
    input  logic                aclk,        // shell user clock
    input  logic                aresetn,     // active-low, sync to aclk

    // QSFP1 GT reference clock (differential, driven straight into the IP)
    input  logic                gt_refclk_p,
    input  logic                gt_refclk_n,

    // QSFP1 GT serial pins (4 lanes)
    input  logic[3:0]           gt_rxp_in,
    input  logic[3:0]           gt_rxn_in,
    output logic[3:0]           gt_txp_out,
    output logic[3:0]           gt_txn_out,

    // User AXI4-Stream — 256-bit, aclk domain
    AXI4S.m                     m_aurora_rx,   // received data -> vFPGA
    AXI4S.s                     s_aurora_tx,   // vFPGA -> transmit

    // Status (aclk domain after synchronizers)
    output logic                channel_up,
    output logic [3:0]          lane_up,
    output logic                hard_err,
    output logic                soft_err,
    output logic                mmcm_not_locked,
    output logic                gt_pll_lock
);

    // ---------------------------------------------------------------------
    // Init FSM (init_clk domain)
    //
    // After sys_reset deasserts, hold pma_init high for ~50 us, then drop.
    // Hold reset_pb high a bit longer (~100 us) so PMA settles before the
    // core comes out of reset. Aurora handles the rest internally.
    // ---------------------------------------------------------------------
    localparam int INIT_CNT_W = 16;
    logic [INIT_CNT_W-1:0] init_cnt;
    logic                  pma_init;
    logic                  reset_pb;

    always_ff @(posedge init_clk) begin
        if (sys_reset) begin
            init_cnt <= '0;
            pma_init <= 1'b1;
            reset_pb <= 1'b1;
        end else begin
            if (init_cnt != {INIT_CNT_W{1'b1}}) begin
                init_cnt <= init_cnt + 1'b1;
            end
            // ~5000 init_clk cycles @ 100 MHz = ~50 us
            if (init_cnt > 16'h1388) pma_init <= 1'b0;
            // ~10000 init_clk cycles @ 100 MHz = ~100 us
            if (init_cnt > 16'h2710) reset_pb <= 1'b0;
        end
    end

    // ---------------------------------------------------------------------
    // Aurora IP-side AXI4-Stream (user_clk_out domain)
    // 256-bit data, 32-bit keep, tlast. RX has no tready (Aurora is push-only
    // on the receive side; the IP cannot be backpressured).
    // ---------------------------------------------------------------------
    wire        user_clk_out;
    wire        sync_clk_out;
    wire        mmcm_not_locked_w;
    wire        channel_up_w;
    wire        hard_err_w;
    wire        soft_err_w;
    wire        gt_pll_lock_w;

    wire [255:0] tx_tdata;
    wire [31:0]  tx_tkeep;
    wire         tx_tlast;
    wire         tx_tvalid;
    wire         tx_tready;

    wire [255:0] rx_tdata;
    wire [31:0]  rx_tkeep;
    wire         rx_tlast;
    wire         rx_tvalid;

    // ---------------------------------------------------------------------
    // Aurora IP uses big-endian [0:N-1] ordering on its tdata/tkeep/lane_up
    // ports. Coyote AXIS is little-endian [N-1:0]. Bit-reverse on the boundary.
    // ---------------------------------------------------------------------
    wire [0:255] ip_tx_tdata;
    wire [0:31]  ip_tx_tkeep;
    wire [0:255] ip_rx_tdata;
    wire [0:31]  ip_rx_tkeep;
    wire [0:3]   ip_lane_up;
    wire [3:0]   lane_up_w;

    genvar gi;
    generate
        for (gi = 0; gi < 256; gi = gi + 1) begin : g_data_rev
            assign ip_tx_tdata[gi]      = tx_tdata[255 - gi];
            assign rx_tdata[255 - gi]   = ip_rx_tdata[gi];
        end
        for (gi = 0; gi < 32; gi = gi + 1) begin : g_keep_rev
            assign ip_tx_tkeep[gi]      = tx_tkeep[31 - gi];
            assign rx_tkeep[31 - gi]    = ip_rx_tkeep[gi];
        end
        for (gi = 0; gi < 4; gi = gi + 1) begin : g_laneup_rev
            assign lane_up_w[gi]        = ip_lane_up[3 - gi];
        end
    endgenerate

    // ---------------------------------------------------------------------
    // Aurora 64B/66B IP instance
    //
    // Port naming convention (PG074, drp_mode=Native, SupportLevel=1):
    //   - AXI4-Stream user side: s_axi_tx_* (slave) and m_axi_rx_*  (master).
    //     Note: "s_axi" / "m_axi" — without the trailing "s" that most other
    //     Xilinx AXIS IPs use. This is an Aurora-specific quirk.
    //   - Clocks generated by the core: user_clk_out, sync_clk_out.
    //   - Reference clock: differential pair `gt_refclk1_p/n`. The IP contains
    //     its own IBUFDS_GTE4 — DO NOT instantiate one externally.
    //   - Native DRP exposes per-lane DRP ports. We do not use runtime DRP,
    //     so the DRP control inputs are left at their generated default zeros.
    //   - QPLL ports: at SupportLevel=1, the core is self-contained. The wrapper
    //     exports gt_qpll*_quad1_out for downstream cores; we leave them open.
    // ---------------------------------------------------------------------
    aurora_loopback_ip inst_aurora (
        // AXI4-Stream TX (slave — from us into IP)
        .s_axi_tx_tdata            (ip_tx_tdata),
        .s_axi_tx_tkeep            (ip_tx_tkeep),
        .s_axi_tx_tlast            (tx_tlast),
        .s_axi_tx_tvalid           (tx_tvalid),
        .s_axi_tx_tready           (tx_tready),
        // AXI4-Stream RX (master — from IP to us; no tready)
        .m_axi_rx_tdata            (ip_rx_tdata),
        .m_axi_rx_tkeep            (ip_rx_tkeep),
        .m_axi_rx_tlast            (rx_tlast),
        .m_axi_rx_tvalid           (rx_tvalid),
        // GT serial pins
        .rxp                       (gt_rxp_in),
        .rxn                       (gt_rxn_in),
        .txp                       (gt_txp_out),
        .txn                       (gt_txn_out),
        // GT reference clock (differential — internal IBUFDS_GTE4)
        .gt_refclk1_p              (gt_refclk_p),
        .gt_refclk1_n              (gt_refclk_n),
        .gt_refclk1_out            (),
        // Status outputs
        .hard_err                  (hard_err_w),
        .soft_err                  (soft_err_w),
        .channel_up                (channel_up_w),
        .lane_up                   (ip_lane_up),
        .mmcm_not_locked_out       (mmcm_not_locked_w),
        .gt_pll_lock               (gt_pll_lock_w),
        // System / control
        .user_clk_out              (user_clk_out),
        .sync_clk_out              (sync_clk_out),
        .reset_pb                  (reset_pb),
        .pma_init                  (pma_init),
        .power_down                (1'b0),
        .loopback                  (3'b000),
        .gt_rxcdrovrden_in         (1'b0),
        .init_clk                  (init_clk),
        // QPLL share-out (unused — open)
        .gt_qpllclk_quad1_out      (),
        .gt_qpllrefclk_quad1_out   (),
        .gt_qpllrefclklost_quad1_out(),
        .gt_qplllock_quad1_out     (),
        // Useful resets / status (left open — not consumed by Coyote)
        .sys_reset_out             (),
        .link_reset_out            (),
        .tx_out_clk                ()
    );

    // ---------------------------------------------------------------------
    // Status synchronization to aclk
    // ---------------------------------------------------------------------
    xpm_cdc_single #(.DEST_SYNC_FF(2), .INIT_SYNC_FF(0), .SIM_ASSERT_CHK(0), .SRC_INPUT_REG(0))
        u_chup_sync (.src_clk(user_clk_out), .src_in(channel_up_w),      .dest_clk(aclk), .dest_out(channel_up));
    xpm_cdc_single #(.DEST_SYNC_FF(2), .INIT_SYNC_FF(0), .SIM_ASSERT_CHK(0), .SRC_INPUT_REG(0))
        u_herr_sync (.src_clk(user_clk_out), .src_in(hard_err_w),        .dest_clk(aclk), .dest_out(hard_err));
    xpm_cdc_single #(.DEST_SYNC_FF(2), .INIT_SYNC_FF(0), .SIM_ASSERT_CHK(0), .SRC_INPUT_REG(0))
        u_serr_sync (.src_clk(user_clk_out), .src_in(soft_err_w),        .dest_clk(aclk), .dest_out(soft_err));
    xpm_cdc_single #(.DEST_SYNC_FF(2), .INIT_SYNC_FF(0), .SIM_ASSERT_CHK(0), .SRC_INPUT_REG(0))
        u_mmcm_sync (.src_clk(user_clk_out), .src_in(mmcm_not_locked_w), .dest_clk(aclk), .dest_out(mmcm_not_locked));
    xpm_cdc_single #(.DEST_SYNC_FF(2), .INIT_SYNC_FF(0), .SIM_ASSERT_CHK(0), .SRC_INPUT_REG(0))
        u_pll_sync  (.src_clk(user_clk_out), .src_in(gt_pll_lock_w),     .dest_clk(aclk), .dest_out(gt_pll_lock));
    xpm_cdc_array_single #(.DEST_SYNC_FF(2), .INIT_SYNC_FF(0), .SIM_ASSERT_CHK(0), .SRC_INPUT_REG(0), .WIDTH(4))
        u_lup_sync  (.src_clk(user_clk_out), .src_in(lane_up_w),         .dest_clk(aclk), .dest_out(lane_up));

    // ---------------------------------------------------------------------
    // Synchronize reset_pb (init_clk domain) into the user_clk_out domain so
    // we can drive the FIFO's user-clk-side aresetn cleanly. The axis_data_fifo
    // IP has its own internal sync, but feeding an asynchronous reset directly
    // is bad form; do it once here and reuse.
    // ---------------------------------------------------------------------
    wire reset_pb_sync_uclk;
    xpm_cdc_async_rst #(
        .DEST_SYNC_FF   (4),
        .INIT_SYNC_FF   (0),
        .RST_ACTIVE_HIGH(1)
    ) u_rst_sync_uclk (
        .src_arst       (reset_pb),
        .dest_clk       (user_clk_out),
        .dest_arst      (reset_pb_sync_uclk)
    );

    // Also produce an aclk-domain "Aurora is alive" reset: when channel_up=0
    // we squelch the RX FIFO and clear the TX FIFO. Optional — for now, just
    // tie FIFOs to their respective ARESETN signals.
    wire user_rstn = ~reset_pb_sync_uclk;

    // ---------------------------------------------------------------------
    // AXI4-Stream CDC: user_clk_out <-> aclk
    // 256-bit data + 32-bit keep + 1-bit last. Generated by aurora_infrastructure.tcl.
    // ---------------------------------------------------------------------
    // TX path: aclk -> user_clk_out
    axis_data_fifo_aurora_tx inst_tx_cdc (
        .s_axis_aclk    (aclk),
        .s_axis_aresetn (aresetn),
        .s_axis_tvalid  (s_aurora_tx.tvalid),
        .s_axis_tready  (s_aurora_tx.tready),
        .s_axis_tdata   (s_aurora_tx.tdata),
        .s_axis_tkeep   (s_aurora_tx.tkeep),
        .s_axis_tlast   (s_aurora_tx.tlast),
        .m_axis_aclk    (user_clk_out),
        .m_axis_tvalid  (tx_tvalid),
        .m_axis_tready  (tx_tready),
        .m_axis_tdata   (tx_tdata),
        .m_axis_tkeep   (tx_tkeep),
        .m_axis_tlast   (tx_tlast)
    );

    // RX path: user_clk_out -> aclk.
    //
    // The Aurora RX side has no backpressure — `s_axis_tready` is an output of
    // the FIFO that we cannot honor toward Aurora. If the FIFO fills, beats are
    // dropped. Depth is 1024 (set in aurora_infrastructure.tcl); for the 1024-
    // beat loopback test the FIFO must drain to aclk faster than it fills from
    // user_clk_out. With user_clk_out ~390 MHz and aclk ~250 MHz, that requires
    // the aclk-side consumer to keep up. The example vFPGA's RX checker accepts
    // every beat unconditionally (tready=1) so this is fine for the test.
    axis_data_fifo_aurora_rx inst_rx_cdc (
        .s_axis_aclk    (user_clk_out),
        .s_axis_aresetn (user_rstn),
        .s_axis_tvalid  (rx_tvalid),
        .s_axis_tready  (),                // unused — Aurora can't be backpressured
        .s_axis_tdata   (rx_tdata),
        .s_axis_tkeep   (rx_tkeep),
        .s_axis_tlast   (rx_tlast),
        .m_axis_aclk    (aclk),
        .m_axis_tvalid  (m_aurora_rx.tvalid),
        .m_axis_tready  (m_aurora_rx.tready),
        .m_axis_tdata   (m_aurora_rx.tdata),
        .m_axis_tkeep   (m_aurora_rx.tkeep),
        .m_axis_tlast   (m_aurora_rx.tlast)
    );

    // Silence unused-net warnings
    wire _unused_sync_clk = sync_clk_out;

endmodule
