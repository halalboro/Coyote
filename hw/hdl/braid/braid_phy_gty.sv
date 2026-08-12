/**
 * BRAID PHY backend — raw GTY (phase B)
 *
 * The transceiver, its clocking and its bring-up FSM. All framing lives in
 * braid_framer, which is instantiated here and is the SAME module the testbench
 * exercises (examples/16_braid/sim/tb_braid.sv). Keep it that way: if the
 * framing is ever copied back into this file, the simulation stops testing what
 * is actually synthesised, which is worse than having no simulation at all.
 *
 * Single GTY lane, 10.3125 Gbps, 8B/10B, 32-bit user datapath at 257.8125 MHz
 * (10.3125 Gbps / 10 bits per char / 4 chars per word). 8B/10B rather than
 * 64B/66B because the 64B/66B gearbox must accumulate 66-bit blocks across
 * 64-bit words, and that buffering is pure latency. The 25% line overhead is
 * free here: even d=25 at 1 us rounds is ~600 Mbps against 10 Gbps.
 *
 * Port names are taken from the ACTUAL generated wrapper
 * (gtwizard_ultrascale:1.7, Vivado 2025.1, GTYE4).
 *
 * UltraScale 8B/10B control mapping (UG578):
 *   TXCTRL2[7:0]  = TXCHARISK        TXCTRL0/1 = dispmode/dispval (unused)
 *   RXCTRL0[15:0] = RXCHARISK        RXCTRL1[15:0] = RXDISPERR
 *   RXCTRL2[7:0]  = RXCHARISCOMMA    RXCTRL3[7:0]  = RXNOTINTABLE
 */

module braid_phy_gty (
    // Free-running clock for the GT reset controller. Must match
    // CONFIG.FREERUN_FREQUENCY in braid_infrastructure.tcl (100 MHz -> dclk).
    input  logic          freerun_clk,
    input  logic          rstn,
    // GT loopback select, UG578 LOOPBACK[2:0]. Quasi-static, already in the
    // freerun_clk domain -- the wrapper synchronises it.
    //   000 normal        001 near-end PCS    010 near-end PMA
    //   100 far-end PCS   110 far-end PMA
    //
    // This is a measurement instrument, not just a bring-up aid. Comparing the
    // RTT under 010 (this card's own PMA reflects it) against 000 with the peer
    // echoing splits the budget into "our GT" and "wire + far card" WITHOUT
    // needing a second bitstream, which is the only way to tell a genuinely slow
    // GT from an optimistic model of everything else.
    input  logic [2:0]    loopback_sel,

    output logic          user_clk,      // TX domain (local)
    output logic          rx_clk,        // RX domain (RECOVERED) -- see below
    output logic          link_up,
    //   [0] rxbyteisaligned (live)
    //   [1] a comma was detected since the link came up
    //   [2] a K-char was seen in lane 0      <- alignment correct
    //   [3] a K-char was seen in lanes 1..3  <- MISALIGNED, check ALIGN_WORD
    output logic [3:0]    phy_dbg,

    // ---- braid_link side: 32-bit words ----
    input  logic [31:0]   phy_tx_data,
    input  logic          phy_tx_valid,
    input  logic          phy_tx_last,
    output logic          phy_tx_ready,
    // Header, checksum and frame type ride in the framer's marker and trailer
    // words rather than in words of their own. Passed straight through; this
    // module does not look at them.
    input  logic [23:0]   phy_tx_hdr,
    input  logic [23:0]   phy_tx_cks,
    input  logic [1:0]    phy_tx_type,
    output logic [31:0]   phy_rx_data,
    output logic          phy_rx_valid,
    output logic          phy_rx_eof,
    output logic          phy_rx_err,
    output logic [23:0]   phy_rx_hdr,
    output logic          phy_rx_sof,
    output logic [1:0]    phy_rx_type,
    output logic [23:0]   phy_rx_cks,

    // ---- GT pins ----
    input  logic          gt_refclk,     // from IBUFDS_GTE4, 156.25 MHz
    input  logic          gt_rxp, gt_rxn,
    output logic          gt_txp, gt_txn
);

    // ---------------------------------------------------------------- GT
    logic        txoutclk, rxoutclk, txusrclk, rxusrclk;
    logic        gtwiz_reset_all;
    logic        tx_done, rx_done, cdr_stable;
    logic        buffbypass_tx_done, buffbypass_tx_error;
    logic        buffbypass_rx_done, buffbypass_rx_error;
    logic        buffbypass_rx_done_s;
    logic        rx_byte_aligned, rx_byte_realign, rx_comma_det;
    logic        txpmaresetdone, rxpmaresetdone, gtpowergood;
    logic [2:0]  rxbufstatus;

    logic [31:0] gt_txdata, gt_rxdata;
    logic [7:0]  gt_txctrl2;
    logic [15:0] gt_rxctrl0, gt_rxctrl1;
    logic [7:0]  gt_rxctrl2, gt_rxctrl3;

    // TXOUTCLK must be buffered before use as the user clock. DIV=0 (divide by
    // 1) because the wizard programs TXOUTCLKSEL for a 257.8125 MHz output at
    // this line rate and datapath width. VERIFY against the wizard's generated
    // example design if the link fails to come up -- this divider is the most
    // version-sensitive line in this file.
    BUFG_GT bufg_tx (.I(txoutclk), .CE(1'b1), .CEMASK(1'b0), .CLR(1'b0),
                     .CLRMASK(1'b0), .DIV(3'd0), .O(txusrclk));

    assign user_clk = txusrclk;

    // With the RX elastic buffer BYPASSED, RXUSRCLK must come from RXOUTCLK --
    // the recovered clock. That is what makes bypass safe without any shared
    // reference between the two ends: the RX datapath is frequency-locked to
    // the incoming data by construction. The cost is that RX fabric logic now
    // lives in its own domain, which is why braid_framer takes two clocks.
    BUFG_GT bufg_rx (.I(rxoutclk), .CE(1'b1), .CEMASK(1'b0), .CLR(1'b0),
                     .CLRMASK(1'b0), .DIV(3'd0), .O(rxusrclk));
    assign rx_clk = rxusrclk;

    // Reset and link state into the recovered-clock domain.
    logic rstn_rx, link_up_rx;
    xpm_cdc_async_rst #(.DEST_SYNC_FF(4), .RST_ACTIVE_HIGH(0))
        inst_rstn_rx (.src_arst(rstn), .dest_clk(rxusrclk), .dest_arst(rstn_rx));
    xpm_cdc_single #(.DEST_SYNC_FF(4), .SRC_INPUT_REG(0))
        inst_lu_rx (.src_clk(txusrclk), .src_in(link_up),
                    .dest_clk(rxusrclk), .dest_out(link_up_rx));

    // RX status back into the TX domain for the bring-up FSM below.
    logic rx_aligned_s, rx_realign_s, rx_comma_s;
    xpm_cdc_single #(.DEST_SYNC_FF(4), .SRC_INPUT_REG(1))
        inst_al_s (.src_clk(rxusrclk), .src_in(rx_byte_aligned),
                   .dest_clk(txusrclk), .dest_out(rx_aligned_s));
    xpm_cdc_single #(.DEST_SYNC_FF(4), .SRC_INPUT_REG(1))
        inst_re_s (.src_clk(rxusrclk), .src_in(rx_byte_realign),
                   .dest_clk(txusrclk), .dest_out(rx_realign_s));
    xpm_cdc_single #(.DEST_SYNC_FF(4), .SRC_INPUT_REG(1))
        inst_cm_s (.src_clk(rxusrclk), .src_in(rx_comma_det),
                   .dest_clk(txusrclk), .dest_out(rx_comma_s));

    // ------------------------------------------------- loopback + GT reset
    //
    // Changing LOOPBACK while the datapath is live leaves the PCS in an
    // undefined state (UG578: the datapath must be reset after a loopback
    // change), so every change pulses gtwiz_reset_all for 256 freerun cycles.
    // lb_q is what actually reaches the GT, so the pin and the reset move
    // together.
    //
    // Declared ABOVE the GT instance on purpose. Below it, Verilog's implicit
    // net rule turns lb_q into an undriven 1-bit wire at the instantiation and
    // the loopback pin silently reads 0 -- the same failure mode that made
    // echo_mode a no-op for a whole build. Vivado errors on the redeclaration,
    // but only because there is an explicit declaration to collide with.
    logic [2:0] lb_q;
    logic [7:0] lb_rst_cnt;

    always_ff @(posedge freerun_clk) begin
        if (!rstn) begin
            lb_q       <= 3'b000;
            lb_rst_cnt <= '0;
        end else begin
            lb_q <= loopback_sel;
            if (lb_q != loopback_sel)      lb_rst_cnt <= 8'hFF;
            else if (lb_rst_cnt != 8'd0)   lb_rst_cnt <= lb_rst_cnt - 8'd1;
        end
    end

    braid_gty inst_gt (
        .gtwiz_userclk_tx_active_in         (txpmaresetdone),
        // Same clock, so the same condition. Using rxpmaresetdone here would
        // gate a TX-derived clock on an RX event.
        .gtwiz_userclk_rx_active_in         (txpmaresetdone),
        .gtwiz_buffbypass_tx_reset_in       (~rstn),
        .gtwiz_buffbypass_tx_start_user_in  (1'b0),
        .gtwiz_buffbypass_tx_done_out       (buffbypass_tx_done),
        .gtwiz_buffbypass_tx_error_out      (buffbypass_tx_error),
        .gtwiz_buffbypass_rx_reset_in       (~rstn),
        .gtwiz_buffbypass_rx_start_user_in  (1'b0),
        .gtwiz_buffbypass_rx_done_out       (buffbypass_rx_done),
        .gtwiz_buffbypass_rx_error_out      (buffbypass_rx_error),
        .gtwiz_reset_clk_freerun_in         (freerun_clk),
        .gtwiz_reset_all_in                 (gtwiz_reset_all),
        .gtwiz_reset_tx_pll_and_datapath_in (1'b0),
        .gtwiz_reset_tx_datapath_in         (1'b0),
        .gtwiz_reset_rx_pll_and_datapath_in (1'b0),
        .gtwiz_reset_rx_datapath_in         (1'b0),
        .gtwiz_reset_rx_cdr_stable_out      (cdr_stable),
        .gtwiz_reset_tx_done_out            (tx_done),
        .gtwiz_reset_rx_done_out            (rx_done),
        .gtwiz_userdata_tx_in               (gt_txdata),
        .gtwiz_userdata_rx_out              (gt_rxdata),
        .gtrefclk00_in                      (gt_refclk),
        .qpll0outclk_out                    (),
        .qpll0outrefclk_out                 (),
        .gtyrxn_in                          (gt_rxn),
        .gtyrxp_in                          (gt_rxp),
        .loopback_in                        (lb_q),
        .rxbufstatus_out                    (rxbufstatus),
        .rx8b10ben_in                       (1'b1),
        .rxcommadeten_in                    (1'b1),
        .rxmcommaalignen_in                 (1'b1),
        .rxpcommaalignen_in                 (1'b1),
        .rxusrclk_in                        (rxusrclk),
        .rxusrclk2_in                       (rxusrclk),
        .tx8b10ben_in                       (1'b1),
        .txctrl0_in                         (16'h0000),
        .txctrl1_in                         (16'h0000),
        .txctrl2_in                         (gt_txctrl2),
        .txusrclk_in                        (txusrclk),
        .txusrclk2_in                       (txusrclk),
        .gtpowergood_out                    (gtpowergood),
        .gtytxn_out                         (gt_txn),
        .gtytxp_out                         (gt_txp),
        .rxbyteisaligned_out                (rx_byte_aligned),
        .rxbyterealign_out                  (rx_byte_realign),
        .rxcommadet_out                     (rx_comma_det),
        .rxctrl0_out                        (gt_rxctrl0),
        .rxctrl1_out                        (gt_rxctrl1),
        .rxctrl2_out                        (gt_rxctrl2),
        .rxctrl3_out                        (gt_rxctrl3),
        .rxoutclk_out                       (rxoutclk),
        .rxpmaresetdone_out                 (rxpmaresetdone),
        .txoutclk_out                       (txoutclk),
        .txpmaresetdone_out                 (txpmaresetdone),
        .txprgdivresetdone_out              ()
    );

    assign gtwiz_reset_all = ~rstn || (lb_rst_cnt != 8'd0);

    xpm_cdc_single #(.DEST_SYNC_FF(4), .SRC_INPUT_REG(1))
        inst_bp_s (.src_clk(rxusrclk), .src_in(buffbypass_rx_done),
                   .dest_clk(txusrclk), .dest_out(buffbypass_rx_done_s));

    // ---------------------------------------------------- bring-up FSM
    //
    // No Aurora channel_up is handed to us, so link state is ours to determine:
    // GT resets complete, TX buffer bypass converged, then byte alignment held
    // stable for a while. The dwell stops link_up flapping while the aligner is
    // still hunting for a comma.
    localparam int ALIGN_DWELL = 1024;

    typedef enum logic [1:0] { L_RESET, L_WAIT_GT, L_ALIGN, L_UP } lnk_e;
    lnk_e        lnk_state;
    logic [15:0] align_cnt;

    always_ff @(posedge user_clk) begin
        if (!rstn) begin
            lnk_state <= L_RESET;
            align_cnt <= '0;
            link_up   <= 1'b0;
        end else begin
            link_up <= (lnk_state == L_UP);
            case (lnk_state)
                L_RESET: lnk_state <= L_WAIT_GT;

                L_WAIT_GT:
                    if (tx_done && rx_done && buffbypass_tx_done && !buffbypass_tx_error
                                           && buffbypass_rx_done_s) begin
                        align_cnt <= '0;
                        lnk_state <= L_ALIGN;
                    end

                L_ALIGN: begin
                    if (!rx_aligned_s || rx_realign_s) align_cnt <= '0;
                    else if (align_cnt == ALIGN_DWELL[15:0])  lnk_state <= L_UP;
                    else                                      align_cnt <= align_cnt + 16'd1;
                    if (!tx_done || !rx_done) lnk_state <= L_WAIT_GT;
                end

                L_UP:
                    // A realign means the byte boundary moved underneath us, so
                    // everything in flight is suspect. Drop the link rather than
                    // hand braid_link plausible-looking garbage.
                    if (!tx_done || !rx_done || rx_realign_s || !rx_aligned_s)
                        lnk_state <= L_WAIT_GT;

                default: lnk_state <= L_RESET;
            endcase
        end
    end

    // ------------------------------------------------------------ framing
    logic [1:0] framer_dbg;
    logic       stk_comma;

    braid_framer inst_framer (
        .clk_tx       (txusrclk),
        .rstn_tx      (rstn),
        .link_up_tx   (link_up),
        .clk_rx       (rxusrclk),
        .rstn_rx      (rstn_rx),
        .link_up_rx   (link_up_rx),
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
        .gt_txdata    (gt_txdata),
        .gt_txctrl2   (gt_txctrl2),
        .gt_rxdata    (gt_rxdata),
        .gt_rxctrl0   (gt_rxctrl0),
        .gt_rxctrl1   (gt_rxctrl1),
        .gt_rxctrl3   (gt_rxctrl3),
        .dbg          (framer_dbg)
    );

    // Comma-seen is a GT-level observation, so it lives here rather than in the
    // framer. Cleared while the link is down: otherwise a transient during comma
    // hunting latches forever and the bit tells you nothing about steady state.
    // rx_comma_det is in the recovered domain; use its synchronised copy so
    // this sticky bit stays in the TX domain alongside the rest of phy_dbg.
    always_ff @(posedge txusrclk) begin
        if (!rstn)           stk_comma <= 1'b0;
        else if (!link_up)   stk_comma <= 1'b0;
        else if (rx_comma_s) stk_comma <= 1'b1;
    end

    logic [1:0] framer_dbg_s;
    xpm_cdc_array_single #(.DEST_SYNC_FF(4), .SRC_INPUT_REG(1), .WIDTH(2))
        inst_fdbg_s (.src_clk(rxusrclk), .src_in(framer_dbg),
                     .dest_clk(txusrclk), .dest_out(framer_dbg_s));

    assign phy_dbg = {framer_dbg_s[1], framer_dbg_s[0], stk_comma, rx_aligned_s};

endmodule
