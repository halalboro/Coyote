/**
 * QLINK protocol testbench
 *
 * Two complete qlink_link + qlink_framer_raw stacks wired back to back, with
 * the GT replaced by a direct 32-bit connection from one framer's gt_txdata
 * to the other's gt_rxdata. That is exactly what a working, correctly-aligned
 * raw-mode GT delivers, so this exercises the whole framing and protocol path
 * without the transceiver's simulation model.
 *
 * Also models the failure that used to cost three hardware builds under
 * 8B/10B, in its raw-mode shape: set MISALIGN to a non-zero BIT count and,
 * combined with a b_rstn_rx pulse (Test 2), the receiving framer's aligner
 * starts hunting from a rotated bit boundary -- what an arbitrary GT lock
 * offset looks like on real silicon.
 *
 * *** TEST 2 CHANGED MEANING WHEN THE PHY WENT RAW -- READ THE COMMENT AT
 * TEST 2 BELOW BEFORE ASSUMING YOU KNOW WHAT IT CHECKS. *** Under 8B/10B a
 * misaligned comma just stayed wrong and nothing was ever delivered; that is
 * what this test used to assert. Raw mode's aligner is designed to recover
 * from exactly this fault, so the old assertion would now be asserting that
 * the recovery logic is broken. Test 2 now asserts the opposite: the link
 * RE-LOCKS and resumes delivering frames correctly.
 *
 *   xvlog -sv tb_qlink.sv ../hw/src/hdl/qlink_link_tx.sv \
 *                          ../hw/src/hdl/qlink_link_rx.sv \
 *              ../../../hw/hdl/qlink/qlink_framer_raw.sv \
 *              ../../../hw/hdl/qlink/qlink_scrambler.sv
 *   xelab -debug typical tb_qlink -s tb && xsim tb -R
 */

`timescale 1ns/1ps

module tb_qlink;

    localparam int N_STAB = 992;    // match vfpga_top: 31 words max (echo CDC cap)
    localparam int N_CORR = 64;

    logic clk = 0, rstn = 0;
    always #2 clk = ~clk;          // 250 MHz-ish, value is irrelevant here

    // ------------------------------------------------------------ A -> B
    logic [31:0] a_txdata, b_rxdata;
    logic [31:0] b_txdata, a_rxdata;

    // Bit-rotation offset applied to the A->B wire, modelling the raw-mode
    // deserialiser landing at an arbitrary bit boundary -- what
    // RX_COMMA_ALIGN_WORD misalignment modelled for 8B/10B, rxslide now
    // walks back one bit at a time instead (see qlink_framer_raw's alignment
    // FSM, and tb_qlink_raw.sv, which is where this bit-rotating wire model
    // is copied from). 0 = correct alignment. Changing MISALIGN alone has no
    // effect: it is only loaded into b_offset (below) while b_rstn_rx is
    // held low, so a deliberate b_rstn_rx pulse is required too -- see
    // Test 2 for why.
    int MISALIGN = 0;

    // RX-domain reset for u_fr_b ONLY, separate from the testbench-wide
    // `rstn`. Pulsing it low re-arms u_fr_b's alignment FSM (back to A_HUNT)
    // against whatever MISALIGN currently is, without touching u_fr_a or
    // resetting qlink_link_a/b's frame/error/gap counters. See Test 2.
    logic b_rstn_rx;

    // Declared HERE (rather than down in the "A: sender" section with the
    // rest of u_link_a_tx's ports) because the corrupt-word logic below reads
    // them: SystemVerilog requires a declaration to textually precede its
    // first use (xvlog VRFC 10-3380, "used before its declaration") -- unlike
    // C, module-scope order is NOT just documentation here. Declared, not
    // left as implicit nets, for the reason the comment below explains.
    logic a_ptx_valid, a_ptx_ready;

    // Framer sidebands. Declared HERE, above the first instance that uses them:
    // below it, Verilog's implicit-net rule silently turns each into an
    // undriven 1-bit wire and the header/checksum read as zero.
    logic [23:0] a_hdr, a_cks, b_hdr, b_cks;
    logic [23:0] a_rhdr, a_rcks, b_rhdr, b_rcks;
    logic        a_rsof, b_rsof;

    // Raw-framer alignment/BER sidebands. New in raw mode -- 8B/10B had no
    // equivalent (comma lock was instantaneous per-word, not a hunted state).
    logic        a_rxslide, b_rxslide;
    logic        a_aligned, b_aligned;
    logic [15:0] a_ber, b_ber;

    // Corrupts one bit of the Nth payload word of the A->B frame, counting
    // from 1 at the first payload word (the header/marker word is never
    // targeted). Models a bit error that survives to the decoder, which is
    // exactly the case cut-through delivery has to handle correctly: the
    // syndrome is already at the decoder by the time the checksum says it
    // was wrong.
    int  CORRUPT_WORD = 0;    // 0 = off
    int  corrupt_cnt  = 0;    // payload words consumed THIS frame, before now

    // The "wire": previous word plus current word, rotated by b_offset bits.
    // b_offset is the live rotation state: loaded from MISALIGN while
    // b_rstn_rx is low, decremented by one on every rxslide pulse u_fr_b's
    // aligner issues afterwards -- mirroring tb_qlink_raw.sv's
    // offset/offset_load model, including the reason it has exactly one
    // procedural writer (see that testbench's comment on the point).
    logic [31:0] a_txdata_q;
    int          b_offset;

    always_ff @(posedge clk) a_txdata_q <= a_txdata;

    // Edge-sensitive for the same reason tb_qlink_raw.sv is: UG578 gives one
    // bit of slide per rxslide PULSE (min two cycles high, >32 low between),
    // not one per cycle high.
    logic b_rxslide_q;
    always @(posedge clk) begin
        b_rxslide_q <= b_rxslide;
        if (!b_rstn_rx)                     b_offset <= MISALIGN % 32;
        else if (b_rxslide && !b_rxslide_q) b_offset <= (b_offset + 31) % 32;
    end

    always_comb begin
        b_rxdata = (b_offset == 0) ? a_txdata
                 : ((a_txdata << (32 - b_offset)) | (a_txdata_q >> b_offset));
        // Only meaningful with MISALIGN==0 (Test 4, the only user of
        // CORRUPT_WORD): flips a bit in the wire word carrying payload word
        // CORRUPT_WORD of the A->B frame.
        if (CORRUPT_WORD != 0 && a_ptx_valid && a_ptx_ready &&
            (corrupt_cnt + 1) == CORRUPT_WORD)
            b_rxdata = b_rxdata ^ 32'h0000_0010;
    end

    // Counts payload words since the start of the current frame, using the
    // link_tx<->framer handshake directly (a_ptx_valid && a_ptx_ready) rather
    // than snooping the wire -- raw mode has no per-word marker on the wire
    // to snoop for. Self-resetting: it drops to 0 on every cycle that is not
    // an active payload cycle, which happens between every pair of frames
    // (T_IDLE/T_HDR/T_EOF all deassert phy_tx_ready), so no separate
    // start-of-frame edge detector is needed.
    always @(posedge clk) begin
        if (!rstn || !(a_ptx_valid && a_ptx_ready))
            corrupt_cnt <= 0;
        else
            corrupt_cnt <= corrupt_cnt + 1;
    end

    // B -> A is always clean; only one direction is exercised for syndromes.
    assign a_rxdata = b_txdata;

    // ------------------------------------------------------- A: sender
    logic [N_STAB-1:0] a_syn_bits;
    logic              a_syn_valid;
    logic [15:0]       a_syn_round;
    logic [7:0]        a_words;
    logic [31:0]       a_ptx_data, a_prx_data;
    // a_ptx_valid, a_ptx_ready declared earlier (A -> B wire model needs
    // them before this point) -- see the comment there. Only a_ptx_last is
    // new here.
    logic              a_ptx_last;
    logic              a_prx_valid, a_prx_last, a_prx_err;
    logic [31:0]       a_txf, a_txd, a_rxf, a_rxe, a_rxg;
    logic [N_STAB-1:0] a_syn_out;
    logic              a_syn_out_valid, a_syn_out_gap;
    logic [31:0]       a_syn_out_round;
    logic [N_CORR-1:0] a_corr_out;
    logic              a_corr_out_valid;
    logic [1:0]        a_dbg;

    qlink_link_tx #(.N_STAB(N_STAB), .N_CORR(N_CORR)) u_link_a_tx (
        .clk(clk), .rstn(rstn), .link_up(1'b1), .clr(1'b0),
        .syn_bits(a_syn_bits), .syn_valid(a_syn_valid), .syn_round(a_syn_round),
        .syn_words_sel(a_words),
        .corr_bits('0), .corr_valid(1'b0),
        .phy_tx_data(a_ptx_data), .phy_tx_valid(a_ptx_valid),
        .phy_tx_last(a_ptx_last), .phy_tx_ready(a_ptx_ready),
        .phy_tx_hdr(a_hdr), .phy_tx_cks(a_cks), .phy_tx_type(), .syn_sparse(1'b0),
        .tx_frames(a_txf), .tx_dropped(a_txd)
    );

    qlink_link_rx #(.N_STAB(N_STAB), .N_CORR(N_CORR)) u_link_a_rx (
        .clk(clk), .rstn(rstn), .link_up(1'b1), .clr(1'b0),
        .syn_out_bits(a_syn_out), .syn_out_valid(a_syn_out_valid),
        .syn_out_round(a_syn_out_round), .syn_out_gap(a_syn_out_gap), .syn_out_bad(),
        .corr_out_bits(a_corr_out), .corr_out_valid(a_corr_out_valid),
        .phy_rx_data(a_prx_data), .phy_rx_valid(a_prx_valid),
        .phy_rx_eof(a_prx_last), .phy_rx_sof(a_rsof), .phy_rx_hdr(a_rhdr),
        .phy_rx_type(2'd0), .syn_out_sparse(), .phy_rx_cks(a_rcks), .phy_rx_err(a_prx_err),
        .rx_frames(a_rxf), .rx_errors(a_rxe), .rx_gaps(a_rxg)
    );

    qlink_framer_raw u_fr_a (
        .clk_tx(clk), .rstn_tx(rstn), .link_up_tx(1'b1),
        .phy_tx_data(a_ptx_data), .phy_tx_valid(a_ptx_valid),
        .phy_tx_last(a_ptx_last), .phy_tx_ready(a_ptx_ready),
        .phy_tx_hdr(a_hdr), .phy_tx_cks(a_cks), .phy_tx_type(2'd0),
        .gt_txdata(a_txdata),
        .clk_rx(clk), .rstn_rx(rstn), .link_up_rx(1'b1),
        .phy_rx_data(a_prx_data), .phy_rx_valid(a_prx_valid),
        .phy_rx_eof(a_prx_last), .phy_rx_err(a_prx_err),
        .phy_rx_hdr(a_rhdr), .phy_rx_sof(a_rsof),
        .phy_rx_type(), .phy_rx_cks(a_rcks),
        .gt_rxdata(a_rxdata),
        .rxslide(a_rxslide), .rx_aligned(a_aligned), .ber_count(a_ber),
        .dbg(a_dbg)
    );

    // ----------------------------------------------------- B: receiver
    logic [31:0]       b_ptx_data, b_prx_data;
    logic              b_ptx_valid, b_ptx_last, b_ptx_ready;
    logic              b_prx_valid, b_prx_last, b_prx_err;
    logic [31:0]       b_txf, b_txd, b_rxf, b_rxe, b_rxg;
    logic              b_syn_out_bad;
    logic [N_STAB-1:0] b_syn_out;
    logic              b_syn_out_valid, b_syn_out_gap;
    logic [31:0]       b_syn_out_round;
    logic [N_CORR-1:0] b_corr_out;
    logic              b_corr_out_valid;
    logic [1:0]        b_dbg;

    qlink_link_tx #(.N_STAB(N_STAB), .N_CORR(N_CORR)) u_link_b_tx (
        .clk(clk), .rstn(rstn), .link_up(1'b1), .clr(1'b0),
        // B never transmits syndromes in these tests; it only reflects/receives.
        .syn_bits('0), .syn_valid(1'b0), .syn_round(16'b0),
        .syn_words_sel(8'd0),
        .corr_bits('0), .corr_valid(1'b0),
        .phy_tx_data(b_ptx_data), .phy_tx_valid(b_ptx_valid),
        .phy_tx_last(b_ptx_last), .phy_tx_ready(b_ptx_ready),
        .phy_tx_hdr(b_hdr), .phy_tx_cks(b_cks), .phy_tx_type(), .syn_sparse(1'b0),
        .tx_frames(b_txf), .tx_dropped(b_txd)
    );

    qlink_link_rx #(.N_STAB(N_STAB), .N_CORR(N_CORR)) u_link_b_rx (
        .clk(clk), .rstn(rstn), .link_up(1'b1), .clr(1'b0),
        .syn_out_bits(b_syn_out), .syn_out_valid(b_syn_out_valid),
        .syn_out_round(b_syn_out_round), .syn_out_gap(b_syn_out_gap),
        .syn_out_bad(b_syn_out_bad),
        .corr_out_bits(b_corr_out), .corr_out_valid(b_corr_out_valid),
        .phy_rx_data(b_prx_data), .phy_rx_valid(b_prx_valid),
        .phy_rx_eof(b_prx_last), .phy_rx_sof(b_rsof), .phy_rx_hdr(b_rhdr),
        .phy_rx_type(2'd0), .syn_out_sparse(), .phy_rx_cks(b_rcks), .phy_rx_err(b_prx_err),
        .rx_frames(b_rxf), .rx_errors(b_rxe), .rx_gaps(b_rxg)
    );

    qlink_framer_raw u_fr_b (
        .clk_tx(clk), .rstn_tx(rstn), .link_up_tx(1'b1),
        .phy_tx_data(b_ptx_data), .phy_tx_valid(b_ptx_valid),
        .phy_tx_last(b_ptx_last), .phy_tx_ready(b_ptx_ready),
        .phy_tx_hdr(b_hdr), .phy_tx_cks(b_cks), .phy_tx_type(2'd0),
        .gt_txdata(b_txdata),
        // rstn_rx is b_rstn_rx, NOT the testbench-wide rstn: Test 2 pulses
        // this on its own to force u_fr_b's aligner to re-hunt against a
        // forced bit misalignment. See the b_rstn_rx declaration above and
        // the Test 2 comment below.
        .clk_rx(clk), .rstn_rx(b_rstn_rx), .link_up_rx(1'b1),
        .phy_rx_data(b_prx_data), .phy_rx_valid(b_prx_valid),
        .phy_rx_eof(b_prx_last), .phy_rx_err(b_prx_err),
        .phy_rx_hdr(b_rhdr), .phy_rx_sof(b_rsof),
        .phy_rx_type(), .phy_rx_cks(b_rcks),
        .gt_rxdata(b_rxdata),
        .rxslide(b_rxslide), .rx_aligned(b_aligned), .ber_count(b_ber),
        .dbg(b_dbg)
    );

    // ------------------------------------------------------- stimulus
    // Same deterministic pattern vfpga_top uses, so the simulation exercises
    // the payload the hardware actually sends.
    function automatic logic [N_STAB-1:0] pattern(input logic [15:0] r);
        logic [N_STAB+31:0] p;
        for (int k = 0; k <= (N_STAB/32); k++)
            p[k*32 +: 32] = {16'b0, r} ^ (32'h9E3779B9 * (k + 1));
        return p[N_STAB-1:0];
    endfunction

    int sent, recvd, bad;
    int n_out_bad;
    logic [31:0] b_rxe_before;

    always @(posedge clk) begin
        if (rstn && b_syn_out_bad) n_out_bad <= n_out_bad + 1;
    end

    wire [7:0] tb_active = (a_words == 8'd0 || a_words > 8'd32) ? 8'd32 : a_words;
    wire [N_STAB-1:0] tb_mask = ({N_STAB{1'b1}} >> (N_STAB - {tb_active, 5'b0}));

    task automatic send_rounds(input int n, input int gap_cycles);
        for (int i = 0; i < n; i++) begin
            @(posedge clk);
            a_syn_bits  <= pattern(i[15:0]);
            a_syn_round <= i[15:0];
            a_syn_valid <= 1'b1;
            @(posedge clk);
            a_syn_valid <= 1'b0;
            repeat (gap_cycles) @(posedge clk);
        end
    endtask

    // Raw mode has no instant comma lock: qlink_framer_raw's aligner has to
    // hunt, one rxslide pulse at a time, until LOCK_COUNT consecutive ALIGN
    // words confirm it. tb_qlink_raw.sv measured a worst case of 2078 clock
    // cycles across all 32 possible starting bit offsets, so protocol tests
    // must not assume alignment is immediate -- this waits for the real
    // rx_aligned signal on both framers (with a generous timeout as a safety
    // net, not as the expected duration) rather than a fixed short delay.
    localparam int ALIGN_TIMEOUT = 3000;
    task automatic wait_aligned(input string label);
        int cyc;
        cyc = 0;
        while (!(a_aligned && b_aligned) && cyc < ALIGN_TIMEOUT) begin
            @(posedge clk);
            cyc++;
        end
        if (!(a_aligned && b_aligned)) begin
            $display("  *** FAIL: %s -- alignment not reached after %0d cycles (a=%b b=%b) ***",
                     label, cyc, a_aligned, b_aligned);
            $finish;
        end else begin
            $display("  [%s] alignment acquired after %0d cycles (a=%b b=%b)",
                     label, cyc, a_aligned, b_aligned);
        end
    endtask

    // Score B's received syndromes against the expected pattern.
    // Plain `always`, not `always_ff`: the stimulus block also resets these
    // counters between tests, and always_ff forbids a second procedural driver.
    always @(posedge clk) begin
        if (rstn && b_syn_out_valid) begin
            recvd <= recvd + 1;
            // Mask to the words actually sent. Above that, syn_out_bits holds
            // stale data from an earlier, longer frame -- the same trap
            // vfpga_top's checker has to avoid.
            if ((b_syn_out & tb_mask) != (pattern(b_syn_out_round[15:0]) & tb_mask)) begin
                bad <= bad + 1;
                $display("  [%0t] MISMATCH round=%0d", $time, b_syn_out_round);
            end
        end
    end

    initial begin
        sent = 0; recvd = 0; bad = 0;
        a_syn_bits = '0; a_syn_valid = 0; a_syn_round = '0; a_words = 8'd0;
        b_rstn_rx = 1'b0;
        repeat (20) @(posedge clk);
        rstn = 1;
        b_rstn_rx = 1'b1;
        repeat (20) @(posedge clk);

        // Give both raw-mode aligners time to lock before trusting anything
        // downstream of them -- see wait_aligned's comment.
        wait_aligned("startup");

        // ---- Test 1: correctly aligned link ----
        $display("\n=== Test 1: aligned link, 64 rounds ===");
        MISALIGN = 0;
        // 4 words = d=11-sized syndrome. With the full 32-word payload a frame
        // takes ~36 cycles, so a 20-cycle gap would offer rounds faster than the
        // link can send them and half would be correctly dropped as "busy".
        a_words = 8'd4;
        send_rounds(64, 20);
        repeat (200) @(posedge clk);
        $display("  tx_frames=%0d rx_frames=%0d rx_errors=%0d rx_gaps=%0d",
                 a_txf, b_rxf, b_rxe, b_rxg);
        $display("  delivered=%0d mismatches=%0d  dbg_b=%b", recvd, bad, b_dbg);

        if (recvd == 64 && bad == 0 && b_rxe == 0 && b_rxg == 0)
            $display("  PASS");
        else begin
            $display("  *** FAIL: aligned link did not deliver cleanly ***");
            $finish;
        end

        // ---- Test 2: bit misalignment -- raw mode RECOVERS, unlike 8B/10B ----
        //
        // *** THIS TEST'S MEANING CHANGED WHEN THE PHY WENT RAW. READ THIS. ***
        // Under 8B/10B, RX_COMMA_ALIGN_WORD misalignment put the comma in the
        // wrong lane and it just stayed there -- there was no recovery path,
        // so this test used to assert that a misaligned link delivers
        // NOTHING ("PASS: nothing delivered (frames rejected)"). Raw mode has
        // no comma and no fixed lane: qlink_framer_raw's alignment FSM pulses
        // rxslide, one bit at a time, until the received word matches
        // W_ALIGN (tb_qlink_raw.sv proves this converges from all 32 possible
        // starting bit offsets). So the SAME underlying fault -- the
        // deserialiser landing at the wrong bit boundary -- is now something
        // the link is SUPPOSED to recover from, and the old assertion would
        // now be asserting that the recovery logic is broken. The correct,
        // and opposite, assertion is that after a forced misalignment the
        // link RE-LOCKS (via rxslide) and resumes delivering frames
        // correctly.
        //
        // Why this needs a b_rstn_rx pulse and not just a MISALIGN change:
        // qlink_framer_raw only re-hunts from A_LOCKED after 255 CONFIRMED
        // one-word glitches (idle_glitch_pending in that module) -- a
        // deliberate choice so a single bit error never tears down a good
        // lock. A wire that is CONTINUOUSLY misaligned never produces that
        // "idle, one bad word, idle again" pattern -- it never looks idle at
        // all -- so that path alone would never re-hunt here. What IS
        // representative of the real fault (a GT lock landing at a bad bit
        // offset at power-up or after a re-lock) is the aligner starting
        // fresh from A_HUNT against an already-misaligned wire, which is
        // exactly what pulsing u_fr_b's own rstn_rx models. That pulse
        // touches only u_fr_b's alignment/frame-reception state, not the
        // testbench-wide `rstn`, so qlink_link_a/b's frame/error/gap counters
        // are undisturbed by the pulse itself.
        $display("\n=== Test 2: bit misalignment, aligner recovers via rxslide ===");
        MISALIGN = 5;    // arbitrary non-zero bit offset. Convergence from
                          // ALL 32 offsets is already proven in
                          // tb_qlink_raw.sv; this proves that one of them
                          // round-trips the WHOLE protocol stack (link_tx,
                          // framer, scrambler, link_rx, checksum) correctly
                          // after recovery, which tb_qlink_raw.sv cannot --
                          // it has no qlink_link on either end.
        recvd = 0; bad = 0;
        b_rstn_rx = 1'b0;
        repeat (10) @(posedge clk);
        b_rstn_rx = 1'b1;
        wait_aligned("Test 2 re-lock");
        send_rounds(32, 20);
        repeat (200) @(posedge clk);
        $display("  delivered=%0d mismatches=%0d rx_errors=%0d dbg_b=%b",
                 recvd, bad, b_rxe, b_dbg);
        if (recvd == 32 && bad == 0)
            $display("  PASS: link recovered from misalignment and delivered %0d/32 frames cleanly", recvd);
        else
            $display("  *** FAIL: link did not recover from misalignment (delivered=%0d mismatches=%0d) ***",
                     recvd, bad);

        // ---- Test 3: protocol latency decomposition ----
        // The "wire" here is a direct connection, so this measures ONLY
        // qlink_link's TX framing + qlink_framer + qlink_framer + qlink_link's
        // RX reassembly. Any hardware RTT above 2x this is GT, CDC and cable.
        $display("\n=== Test 3: protocol-only latency (no GT, no CDC) ===");
        $display("  words  bytes   cycles      ns @390.6MHz");
        MISALIGN = 0;
        // 1,2,4,8,16 then the full-width 31. MAX is 31 rather than 32 because
        // vfpga_top's echo crossing caps the payload at 992 bits; doubling alone
        // would stop at 16 and never exercise a full-size frame.
        for (int w = 1; w <= 31; w = (w * 2 > 31 && w != 31) ? 31 : w * 2) begin
            time t0, t1;
            a_words = w[7:0];
            @(posedge clk);
            a_syn_bits  <= pattern(16'd7);
            a_syn_round <= 16'd7;
            a_syn_valid <= 1'b1;
            t0 = $time;
            @(posedge clk);
            a_syn_valid <= 1'b0;
            @(posedge b_syn_out_valid);
            t1 = $time;
            $display("  %5d  %5d   %6d      %8.1f",
                     w, w*4, (t1-t0)/4, ((t1-t0)/4) * 1000.0 / 390.625);
            repeat (50) @(posedge clk);
        end

        // ---- Test 4: cut-through delivery of a CORRUPT frame ----
        //
        // Cut-through means syn_out_valid fires before the checksum is
        // validated, so a corrupt frame IS delivered and then retracted one
        // cycle later on syn_out_bad. The contract that matters to a decoder:
        // every corrupt frame must raise syn_out_bad, and the round must not
        // advance -- so the next good frame reports the gap.
        //
        // Test 2 covers misalignment, where recovery happens before any frame
        // is accepted. This covers a different and more dangerous case: a
        // frame that looks perfectly well formed until its last word.
        $display("\n=== Test 4: corrupt payload, cut-through + retract ===");
        MISALIGN = 0;
        a_words  = 8'd4;
        recvd = 0; bad = 0; n_out_bad = 0;
        b_rxe_before = b_rxe;
        repeat (20) @(posedge clk);

        CORRUPT_WORD = 3;          // a payload word, not the header
        send_rounds(1, 40);
        repeat (40) @(posedge clk);
        CORRUPT_WORD = 0;

        $display("  delivered=%0d syn_out_bad=%0d rx_errors=+%0d",
                 recvd, n_out_bad, b_rxe - b_rxe_before);
        if (recvd == 1 && n_out_bad == 1 && (b_rxe - b_rxe_before) == 1)
            $display("  PASS: delivered once, retracted once, counted once");
        else
            $display("  *** FAIL: cut-through did not retract a corrupt frame ***");

        // The round must NOT have advanced past the corrupt frame, so the next
        // good round is reported as a gap rather than silently accepted.
        recvd = 0; n_out_bad = 0;
        send_rounds(1, 40);
        repeat (40) @(posedge clk);
        $display("  next good frame: delivered=%0d syn_out_bad=%0d gaps=%0d",
                 recvd, n_out_bad, b_rxg);
        if (recvd == 1 && n_out_bad == 0)
            $display("  PASS: recovered on the next frame");
        else
            $display("  *** FAIL: did not recover ***");

        // ---- Test 5: back-to-back frames, no gap ----
        //
        // syn_valid is held HIGH, not pulsed. Pulsing it every N cycles locks
        // the offset between the pulse and the frame boundary, and the window
        // that matters here is exactly one cycle wide -- the cycle after the
        // last payload word, when the FSM is back in T_IDLE but the framer has
        // not yet emitted the trailer. A round starting there used to overwrite
        // the running checksum before the trailer read it, sending a perfectly
        // good frame with the next frame's partial sum.
        //
        // Pulsed stimulus never lands on that cycle. This test passed against
        // the broken RTL until the stimulus was changed to a level.
        $display("\n=== Test 5: back-to-back frames (syn_valid held high) ===");
        MISALIGN = 0; CORRUPT_WORD = 0;
        a_words = 8'd4;
        recvd = 0; bad = 0; n_out_bad = 0;
        b_rxe_before = b_rxe;
        repeat (20) @(posedge clk);

        @(posedge clk);
        a_syn_bits  <= pattern(16'd9);
        a_syn_round <= 16'd9;
        a_syn_valid <= 1'b1;
        repeat (200) @(posedge clk);
        a_syn_valid <= 1'b0;
        repeat (60) @(posedge clk);

        // Gaps are EXPECTED here: the round number never advances, so every
        // frame after the first reads as a repeat. Errors and mismatches are
        // what this test is about.
        $display("  delivered=%0d mismatches=%0d rx_errors=+%0d syn_out_bad=%0d",
                 recvd, bad, b_rxe - b_rxe_before, n_out_bad);
        if (recvd > 4 && bad == 0 && (b_rxe - b_rxe_before) == 0 && n_out_bad == 0)
            $display("  PASS: %0d back-to-back frames, none corrupt", recvd);
        else
            $display("  *** FAIL: back-to-back frames are being corrupted ***");

        $display("\nDone.");
        $finish;
    end

    initial begin
        #2_000_000;
        $display("*** TIMEOUT ***");
        $finish;
    end

endmodule
