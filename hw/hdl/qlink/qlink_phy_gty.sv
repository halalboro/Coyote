/**
 * QLINK PHY backend — raw GTY (phase B)
 *
 * The transceiver, its clocking and its bring-up FSM. All framing lives in
 * qlink_framer_raw, which is instantiated here and is the SAME module the
 * testbench exercises (examples/16_qlink/sim/tb_qlink.sv). Keep it that way:
 * if the framing is ever copied back into this file, the simulation stops
 * testing what is actually synthesised, which is worse than having no
 * simulation at all.
 *
 * Single GTY lane, 12.5 Gbps, RAW encoding -- no 8B/10B, no comma detector, no
 * gearbox -- 32-bit user datapath at 390.625 MHz, 156.25 MHz reference, TX and
 * RX buffers bypassed. RAW rather than 8B/10B because the GT's own PCS (the
 * part that used to do 8B/10B and comma detection) measured 23.8 ns of a
 * 31.8 ns transceiver on hardware, against 8.0 ns for the PMA alone. Word
 * alignment, DC balance (scrambling) and framing all moved into
 * qlink_framer_raw instead -- see that file for the wire protocol.
 * TXPROGDIV_FREQ_VAL lands on the SAME 390.625 MHz fabric clock the 8B/10B
 * configuration used (see scripts/ip_inst/qlink_infrastructure.tcl), so this
 * change does not touch timing closure.
 *
 * Port names are taken from the ACTUAL generated wrapper
 * (gtwizard_ultrascale:1.7, Vivado 2025.1, GTYE4).
 *
 * Raw mode has no control-character mapping: there is no TXCTRL2/RXCTRL0-3
 * and no comma detector on the GT side. Word alignment instead comes from
 * pulsing RXSLIDE_IN (UG578) under the framer's own hunt FSM.
 */

module qlink_phy_gty (
    // Free-running clock for the GT reset controller. Must match
    // CONFIG.FREERUN_FREQUENCY in qlink_infrastructure.tcl (100 MHz -> dclk).
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
    // Raw mode has no GT-level comma/K-char status, so these four bits report
    // the framer's own view of the line plus the one GT flag that can still
    // fail silently. Reaches software as REG_STATUS[4:1] (this is the vFPGA's
    // aurora_lane_up), which is the ONLY status path out of the shell -- see
    // the note on ber_count at the framer instantiation below.
    //   [0] rx_aligned    framer's rxslide-hunt FSM has lock (live, not sticky)
    //   [1] ber_count != 0        any bit error since the link came up
    //   [2] ber_count >= 256      ...and enough of them that it is not just a
    //                             bring-up transient. [2] without [1] is
    //                             impossible; [1] alone after a clean bring-up
    //                             is the expected steady state.
    //   [3] buffbypass_rx_error   the RX elastic-buffer bypass alignment
    //                             procedure FAILED. Reported, not gated: see
    //                             the bring-up FSM.
    output logic [3:0]    phy_dbg,

    // ---- qlink_link side: 32-bit words ----
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
    logic        txpmaresetdone, rxpmaresetdone, gtpowergood;
    logic [2:0]  rxbufstatus;

    logic [31:0] gt_txdata, gt_rxdata;
    // Raw mode: the GT does no word alignment of its own (no comma detector),
    // so the framer drives rxslide directly and reports back whether it has
    // found lock. Both are in the RECOVERED (rxusrclk) domain -- see the
    // framer instantiation below.
    logic        gt_rxslide, rx_aligned_raw;
    logic [15:0] ber_count;

    // TXOUTCLK must be buffered before use as the user clock. DIV=0 (divide by
    // 1) because the wizard resolves TXPROGDIV_FREQ_VAL to 390.625 MHz at this
    // line rate and datapath width (12.5 Gbps / 32 bits), and sources TXOUTCLK
    // from TXPROGDIVCLK -- confirmed against the generated OOC constraints,
    // which put create_clock -period 2.56 on all four usrclk ports. VERIFY
    // against the wizard's generated example design if the link fails to come
    // up -- this divider is the most version-sensitive line in this file.
    BUFG_GT bufg_tx (.I(txoutclk), .CE(1'b1), .CEMASK(1'b0), .CLR(1'b0),
                     .CLRMASK(1'b0), .DIV(3'd0), .O(txusrclk));

    assign user_clk = txusrclk;

    // With the RX elastic buffer BYPASSED, RXUSRCLK must come from RXOUTCLK --
    // the recovered clock. That is what makes bypass safe without any shared
    // reference between the two ends: the RX datapath is frequency-locked to
    // the incoming data by construction. The cost is that RX fabric logic now
    // lives in its own domain, which is why qlink_framer_raw takes two clocks.
    BUFG_GT bufg_rx (.I(rxoutclk), .CE(1'b1), .CEMASK(1'b0), .CLR(1'b0),
                     .CLRMASK(1'b0), .DIV(3'd0), .O(rxusrclk));
    assign rx_clk = rxusrclk;

    // Reset and link state into the recovered-clock domain.
    //
    // rstn_rx FOLLOWS THE GT RX RESET, NOT JUST rstn. This matters more in raw
    // mode than it did with 8B/10B, where the GT's comma detector re-aligned
    // itself after any reset without the fabric being told. Now alignment is
    // OURS: it lives in qlink_framer_raw's rxslide-hunt FSM, and the only thing
    // that makes it re-hunt is this reset.
    //
    // Any GT RX reset re-locks the CDR on a fresh, arbitrary bit phase -- wrong
    // 31 times out of 32. Tying rstn_rx to rstn alone (= ~sys_reset) means a
    // reset that is NOT a full shell reset leaves the framer's flops frozen and
    // then resumed in A_LOCKED, still asserting rx_aligned for an alignment
    // that no longer exists. The bring-up FSM below would see rx_aligned_s
    // already high, dwell, and declare link_up on a dead link, with every
    // diagnostic bit reading healthy.
    //
    // That is not a corner case: main.cpp writes reg::LOOPBACK before wait_link
    // whenever the requested mode differs, which drives lb_rst_cnt ->
    // gtwiz_reset_all. `qlink bench -l 2` -- the FIRST command in the bring-up
    // procedure, and the one that splits the latency budget without a second
    // bitstream -- takes exactly this path. So does a cable re-plug or a peer
    // restart. Gating on rx_done makes all of them re-hunt, which is the whole
    // point of having a hunt FSM.
    logic rstn_rx, link_up_rx;
    logic rx_datapath_rstn;
    assign rx_datapath_rstn = rstn && rx_done;

    xpm_cdc_async_rst #(.DEST_SYNC_FF(4), .RST_ACTIVE_HIGH(0))
        inst_rstn_rx (.src_arst(rx_datapath_rstn), .dest_clk(rxusrclk), .dest_arst(rstn_rx));
    xpm_cdc_single #(.DEST_SYNC_FF(4), .SRC_INPUT_REG(0))
        inst_lu_rx (.src_clk(txusrclk), .src_in(link_up),
                    .dest_clk(rxusrclk), .dest_out(link_up_rx));

    // RX alignment status back into the TX domain for the bring-up FSM below.
    // Raw mode has no GT-level comma/byte-align status any more -- this is the
    // FRAMER's own rx_aligned (driven by its internal rxslide-hunt FSM), not a
    // GT output. Declared here; the CDC itself sits just after the framer
    // instantiation below, next to where rx_aligned_raw is actually driven.
    logic rx_aligned_s;

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

    qlink_gty inst_gt (
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
        .rxslide_in                         (gt_rxslide),
        .rxusrclk_in                        (rxusrclk),
        .rxusrclk2_in                       (rxusrclk),
        .txusrclk_in                        (txusrclk),
        .txusrclk2_in                       (txusrclk),
        .gtpowergood_out                    (gtpowergood),
        .gtytxn_out                         (gt_txn),
        .gtytxp_out                         (gt_txp),
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
    // stable for a while. The dwell stops link_up flapping while the framer's
    // own alignment FSM is still pulsing rxslide, hunting for lock.
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
                    if (!rx_aligned_s) align_cnt <= '0;
                    else if (align_cnt == ALIGN_DWELL[15:0])  lnk_state <= L_UP;
                    else                                      align_cnt <= align_cnt + 16'd1;
                    if (!tx_done || !rx_done) lnk_state <= L_WAIT_GT;
                end

                L_UP:
                    // Losing rx_aligned means the framer's own alignment FSM
                    // has re-hunted (see qlink_framer_raw's A_LOCKED case): the
                    // byte boundary moved underneath us, so everything in
                    // flight is suspect. Drop the link rather than hand
                    // qlink_link plausible-looking garbage.
                    if (!tx_done || !rx_done || !rx_aligned_s)
                        lnk_state <= L_WAIT_GT;

                default: lnk_state <= L_RESET;
            endcase
        end
    end

    // ------------------------------------------------------------ framing
    logic [1:0] framer_dbg;

    qlink_framer_raw inst_framer (
        .clk_tx       (txusrclk),
        .rstn_tx      (rstn),
        .link_up_tx   (link_up),
        .phy_tx_data  (phy_tx_data),
        .phy_tx_valid (phy_tx_valid),
        .phy_tx_last  (phy_tx_last),
        .phy_tx_ready (phy_tx_ready),
        .phy_tx_hdr   (phy_tx_hdr),
        .phy_tx_cks   (phy_tx_cks),
        .phy_tx_type  (phy_tx_type),
        .gt_txdata    (gt_txdata),
        .clk_rx       (rxusrclk),
        .rstn_rx      (rstn_rx),
        .link_up_rx   (link_up_rx),
        .phy_rx_data  (phy_rx_data),
        .phy_rx_valid (phy_rx_valid),
        .phy_rx_eof   (phy_rx_eof),
        .phy_rx_err   (phy_rx_err),
        .phy_rx_hdr   (phy_rx_hdr),
        .phy_rx_sof   (phy_rx_sof),
        .phy_rx_type  (phy_rx_type),
        .phy_rx_cks   (phy_rx_cks),
        .gt_rxdata    (gt_rxdata),
        .rxslide      (gt_rxslide),
        .rx_aligned   (rx_aligned_raw),
        .ber_count    (ber_count),
        .dbg          (framer_dbg)
    );

    // rx_aligned_raw is the framer's own alignment status (recovered-clock
    // domain, driven by its internal rxslide-hunt FSM -- not a GT signal).
    // Synchronised into the TX domain for the bring-up FSM above, same
    // xpm_cdc_single style as inst_lu_rx/inst_bp_s elsewhere in this file.
    xpm_cdc_single #(.DEST_SYNC_FF(4), .SRC_INPUT_REG(1))
        inst_al_s (.src_clk(rxusrclk), .src_in(rx_aligned_raw),
                   .dest_clk(txusrclk), .dest_out(rx_aligned_s));

    // Raw mode has no GT-level comma/disparity flags left to report, so these
    // four bits carry the framer's own line-quality view plus buffbypass_rx_error.
    //
    // WHY buffbypass_rx_error IS HERE AND NOT IN THE FSM ABOVE. It is the one
    // GT flag that can fail without any other symptom: with the RX elastic
    // buffer bypassed, a failed bypass alignment leaves the RX datapath
    // sampling at the wrong phase, and everything downstream -- including the
    // framer's own aligner -- just sees a bad line. Gating link_up on it would
    // be the obvious move, but if the wizard ever sets it spuriously or
    // stickily the link would never come up at all, and that failure is
    // indistinguishable from a dead cable without a bitstream to debug it.
    // Reporting it costs nothing and answers the question directly. Promote it
    // into the L_WAIT_GT condition once hardware shows it behaves.
    //
    // WHY ONLY A MAGNITUDE BIT AND NOT ber_count ITSELF. The full 16-bit
    // counter cannot reach the vFPGA: the shell->vFPGA status path is
    // aurora_channel_up (1) + aurora_lane_up (4), hard-coded at that width
    // across four files in hw/templates/, and it is fully used by phy_dbg
    // already. Widening it for a diagnostic counter is not worth touching
    // shared templates every other example also builds against. Bit [2] is the
    // distinction that actually matters during bring-up -- "a glitch while the
    // aligner was hunting" versus "this line is erroring continuously" -- and
    // it fits in the space there was.
    //
    // The four bits are independent slow status flags, so a plain array_single
    // is right; there is no value that must be coherent across them.
    logic [3:0] rx_dbg, rx_dbg_s;
    assign rx_dbg = {buffbypass_rx_error,      // [3]
                     (ber_count >= 16'd256),   // [2]
                     framer_dbg[0],            // [1] ber_count != 0
                     framer_dbg[1]};           // [0] rx_aligned

    xpm_cdc_array_single #(.DEST_SYNC_FF(4), .SRC_INPUT_REG(1), .WIDTH(4))
        inst_fdbg_s (.src_clk(rxusrclk), .src_in(rx_dbg),
                     .dest_clk(txusrclk), .dest_out(rx_dbg_s));

    assign phy_dbg = rx_dbg_s;

endmodule
