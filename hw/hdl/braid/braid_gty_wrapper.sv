/**
 * BRAID GTY wrapper — shell-side integration of the raw-GT PHY
 *
 * Presents the same 256-bit AXI4-Stream pair aurora_module presents, so the
 * dynamic_top / user_wrapper / user_logic templates carry the same wires. What
 * changed in Task 2b is the DOMAIN those wires live in.
 *
 * ==========================================================================
 * THE STREAMS ARE NO LONGER IN aclk.
 *
 *   s_braid_tx  is in the tx_clk domain (txusrclk, 257.8125 MHz, local)
 *   m_braid_rx  is in the rx_clk domain (rxusrclk, RECOVERED from the peer)
 *
 * Both clocks are exported so the vFPGA can run the protocol core directly on
 * them. Wiring either stream to aclk logic without a crossing is a silent
 * data-corruption bug that no tool will flag, because an AXI4S interface object
 * carries no clock of its own.
 * ==========================================================================
 *
 * Why: the two fabric CDC FIFOs that used to sit here cost ~25 ns per crossing,
 * and there were four of them on a measured round trip. They existed only so
 * the vFPGA could stay in aclk and the templates stay untouched. Exporting the
 * clocks instead costs four partition pins -- dynamic_top already receives
 * dclk, aclk and uclk, so this is a precedented crossing, not a new one.
 *
 * Only channel_up / lane_up are still synchronised into aclk, because the CSR
 * block that reads them is the one thing that must keep working when the GT has
 * no clock at all.
 */

module braid_gty_wrapper #(
    // Build-time near-end PMA loopback. A bitstream built with this set loops
    // the card's own TX back into its RX, so one card can prove its whole
    // GT + framing + protocol path with no cable and no peer. Kept even though
    // loopback_sel now does the same thing at runtime: an image that cannot be
    // talked out of loopback is a useful thing to have when the CSR path itself
    // is what you are debugging.
    parameter int LOOPBACK = 0
) (
    input  logic                init_clk,     // 100 MHz free-running (dclk)
    input  logic                sys_reset,    // active high, sync to init_clk
    input  logic                aclk,
    input  logic                aresetn,

    // QSFP1 reference clock and one serial lane
    input  logic                gt_refclk_p,
    input  logic                gt_refclk_n,
    input  logic                gt_rxp_in,
    input  logic                gt_rxn_in,
    output logic                gt_txp_out,
    output logic                gt_txn_out,

    // GT user clocks and their resets, exported to the vFPGA. See the header:
    // the streams below belong to these, not to aclk.
    output logic                tx_clk,
    output logic                rx_clk,
    output logic                tx_rstn,
    output logic                rx_rstn,

    // 32-bit protocol words carried in the low bits of a 256-bit AXI4-Stream.
    // m_braid_rx.tdata[32] is the PHY error flag (8B/10B disparity or
    // not-in-table); braid_link_rx folds it into frame validity.
    AXI4S.m                     m_braid_rx,   // rx_clk domain
    AXI4S.s                     s_braid_tx,   // tx_clk domain

    // GT loopback select (aclk domain, quasi-static). See braid_phy_gty.
    input  logic [2:0]          loopback_sel,

    output logic                channel_up,   // aclk domain
    output logic [3:0]          lane_up       // aclk domain
);

    // ------------------------------------------------------------ refclk
    logic gt_refclk;
    IBUFDS_GTE4 #(
        .REFCLK_EN_TX_PATH  (1'b0),
        .REFCLK_HROW_CK_SEL (2'b00),
        .REFCLK_ICNTL_RX    (2'b00)
    ) inst_refclk_buf (
        .I     (gt_refclk_p),
        .IB    (gt_refclk_n),
        .CEB   (1'b0),
        .O     (gt_refclk),
        .ODIV2 ()
    );

    // ------------------------------------------------------- PHY signals
    logic        user_clk, rx_clk_i, link_up;
    logic [3:0]  phy_dbg;
    logic [31:0] phy_tx_data, phy_rx_data;
    logic        phy_tx_valid, phy_tx_last, phy_tx_ready;
    logic [23:0] phy_tx_hdr, phy_tx_cks;
    logic [1:0]  phy_tx_type;
    logic        phy_rx_valid, phy_rx_eof, phy_rx_err, phy_rx_sof;
    logic [1:0]  phy_rx_type;
    logic [23:0] phy_rx_hdr, phy_rx_cks;

    // A build-time loopback image ignores the runtime select entirely, so it
    // cannot be talked out of loopback by software.
    logic [2:0]  lb_sel_sync, lb_sel_eff;

    xpm_cdc_array_single #(.DEST_SYNC_FF(4), .SRC_INPUT_REG(1), .WIDTH(3))
        inst_lb_cdc (.src_clk(aclk), .src_in(loopback_sel),
                     .dest_clk(init_clk), .dest_out(lb_sel_sync));

    assign lb_sel_eff = (LOOPBACK != 0) ? 3'b010 : lb_sel_sync;

    braid_phy_gty inst_phy (
        .freerun_clk  (init_clk),
        .rstn         (~sys_reset),
        .loopback_sel (lb_sel_eff),
        .user_clk     (user_clk),
        .rx_clk       (rx_clk_i),
        .link_up      (link_up),
        .phy_dbg      (phy_dbg),
        .phy_tx_data  (phy_tx_data),
        .phy_tx_valid (phy_tx_valid),
        .phy_tx_last  (phy_tx_last),
        .phy_tx_ready (phy_tx_ready),
        .phy_tx_hdr   (phy_tx_hdr),
        .phy_tx_cks   (phy_tx_cks),
        .phy_tx_type  (phy_tx_type),
        .phy_rx_data  (phy_rx_data),
        .phy_rx_valid (phy_rx_valid),
        .phy_rx_eof   (phy_rx_eof),
        .phy_rx_err   (phy_rx_err),
        .phy_rx_hdr   (phy_rx_hdr),
        .phy_rx_sof   (phy_rx_sof),
        .phy_rx_type  (phy_rx_type),
        .phy_rx_cks   (phy_rx_cks),
        .gt_refclk    (gt_refclk),
        .gt_rxp       (gt_rxp_in),
        .gt_rxn       (gt_rxn_in),
        .gt_txp       (gt_txp_out),
        .gt_txn       (gt_txn_out)
    );

    assign tx_clk = user_clk;
    assign rx_clk = rx_clk_i;

    // Resets for the exported domains. Async assert, synchronous release in the
    // destination domain -- the vFPGA must not be released from reset on a clock
    // edge that does not exist yet.
    xpm_cdc_async_rst #(
        .DEST_SYNC_FF(4), .RST_ACTIVE_HIGH(0)
    ) inst_tx_rstn_cdc (
        .src_arst  (aresetn),
        .dest_clk  (user_clk),
        .dest_arst (tx_rstn)
    );

    xpm_cdc_async_rst #(
        .DEST_SYNC_FF(4), .RST_ACTIVE_HIGH(0)
    ) inst_rx_rstn_cdc (
        .src_arst  (aresetn),
        .dest_clk  (rx_clk_i),
        .dest_arst (rx_rstn)
    );

    // ------------------------------------------------- status into aclk
    xpm_cdc_single #(.DEST_SYNC_FF(4), .SRC_INPUT_REG(0))
        inst_linkup_cdc (.src_clk(user_clk), .src_in(link_up),
                         .dest_clk(aclk), .dest_out(channel_up));

    // Only one lane exists, so a per-lane status would just repeat channel_up.
    // These four wires already reach the host, so carry the PHY diagnostics on
    // them instead -- no new plumbing through the shell or the templates.
    // See braid_phy_gty.phy_dbg for the bit meanings.
    xpm_cdc_array_single #(.DEST_SYNC_FF(4), .SRC_INPUT_REG(0), .WIDTH(4))
        inst_dbg_cdc (.src_clk(user_clk), .src_in(phy_dbg),
                      .dest_clk(aclk), .dest_out(lane_up));

    // ------------------------------------------- streams, no CDC anywhere
    // This is the entire point of Task 2b. Both used to run through a
    // packet-mode axis_data_fifo; both are now wire.
    assign phy_tx_data      = s_braid_tx.tdata[31:0];
    assign phy_tx_hdr       = s_braid_tx.tdata[55:32];
    assign phy_tx_cks       = s_braid_tx.tdata[79:56];
    assign phy_tx_type      = s_braid_tx.tdata[81:80];
    assign phy_tx_valid     = s_braid_tx.tvalid;
    assign phy_tx_last      = s_braid_tx.tlast;
    assign s_braid_tx.tready = phy_tx_ready;

    // [31:0] data  [32] err  [56:33] hdr  [80:57] cks  [82:81] type  [83] sof
    // 84 bits used of 256. braid_phy_shim must split it at exactly these
    // offsets -- the RX side carries an err bit that the TX side does not, so
    // the two layouts are NOT the same and cannot share constants.
    assign m_braid_rx.tdata  = {172'b0, phy_rx_sof, phy_rx_type, phy_rx_cks,
                                phy_rx_hdr, phy_rx_err, phy_rx_data};
    assign m_braid_rx.tvalid = phy_rx_valid;
    // NOT AXI4-Stream semantics. tlast is an independent end-of-frame STROBE
    // that arrives on a cycle where tvalid is LOW, because the framer no longer
    // holds a word back to align it with the final beat -- that hold was a
    // cycle of latency on every syndrome. Nothing downstream treats this pair
    // as a real AXIS stream; braid_phy_shim splits it straight back apart.
    assign m_braid_rx.tlast  = phy_rx_eof;
    assign m_braid_rx.tkeep  = '1;
    // m_braid_rx.tready is ignored, exactly as the RX FIFO's ready was: there is
    // no useful response to backpressure on a real-time syndrome stream, and
    // stalling cannot un-miss a deadline. Frames lost this way are caught by the
    // checksum and the round counter and reported as errors or gaps.

endmodule
