/**
 * qlink_framer_raw: alignment and frame round-trip.
 *
 * The wire is modelled as a barrel shifter whose offset is set per test, and
 * rxslide DECREMENTS that offset by one -- which is what the GT's PCS slide
 * actually does. Starting at every one of the 32 offsets proves the aligner
 * converges regardless of where the deserialiser happens to land at power-on.
 *
 * An aligner that works from offset 0 and nowhere else passes a naive test and
 * fails on hardware every time but one in 32.
 */
`timescale 1ns/1ps
module tb_qlink_raw;
    logic clk = 0, rstn = 0;
    always #1.28 clk = ~clk;          // 390.625 MHz

    logic [31:0] a_tx, b_rx, prev;
    int          offset;
    int          offset_load;
    logic        offset_load_en;

    // Bit-rotating wire. offset=0 is aligned.
    always_ff @(posedge clk) prev <= a_tx;
    //
    // NOTE on operand order: this puts the low bits of the NEWER word (a_tx)
    // above the high bits of the OLDER one (prev). For a serial stream that
    // is actually varying word to word, that is backwards from the physical
    // concatenation -- a true phase-shifted sample of two different
    // successive words would need the OLDER word's low bits above the
    // NEWER word's high bits, i.e. {prev[k-1:0], a_tx[31:k]}.
    //
    // It is harmless in THIS testbench only because of two facts that live
    // outside this expression, not because the expression itself is
    // correct in general:
    //   1. Throughout the whole alignment hunt (Test 1) TX transmits a
    //      constant W_ALIGN every cycle -- qlink_framer_raw drives
    //      gt_txdata = W_ALIGN unconditionally in T_IDLE, and phy_tx_valid
    //      is never asserted until after lock -- so prev == a_tx always.
    //      Any phase-shifted sample of a CONSTANT-word stream is a true
    //      cyclic rotation of that one word regardless of which operand
    //      supplies the high bits vs the low bits.
    //   2. Lock is only ever declared at offset == 0, which bypasses this
    //      expression entirely (b_rx = a_tx, the explicit special case
    //      below) -- so the framer's pass/fail verdict never depends on
    //      this rotated expression being right, only on the offset==0 case.
    //
    // If TX's idle output is ever made non-constant, or if this wire model
    // is reused to inject bit errors into live, varying frame data at a
    // nonzero offset, this operand order becomes wrong and must be rewritten
    // as {prev[k-1:0], a_tx[31:k]} (with k = offset, and offset==0 handled
    // separately as today since shifting a 32-bit value by 32 is not a no-op
    // in Verilog).
    always_comb b_rx = (offset == 0) ? a_tx
                     : ((a_tx << (32-offset)) | (prev >> offset));

    logic [31:0] ptx_data; logic ptx_valid, ptx_last, ptx_ready;
    logic [23:0] ptx_hdr, ptx_cks;
    logic [31:0] prx_data; logic prx_valid, prx_eof, prx_sof, prx_err;
    logic [23:0] prx_hdr, prx_cks;
    logic [1:0]  prx_type;
    logic        slide, aligned;
    logic [15:0] ber;
    logic [1:0]  dbg;

    // LOSS_COUNT shortened from its synthesis default of 16384 purely to keep
    // Test 3 fast -- it is a straight cycle count, so the default would be
    // 16384 cycles of simulated garbage per detection. The threshold is not the
    // thing under test, the detection MECHANISM is, and it is identical at any
    // value. Tests 1 and 2 are unaffected: neither runs 64 consecutive cycles
    // without an ALIGN word once locked.
    qlink_framer_raw #(.LOSS_COUNT(64)) u_framer (
        .clk_tx(clk), .rstn_tx(rstn), .link_up_tx(1'b1),
        .phy_tx_data(ptx_data), .phy_tx_valid(ptx_valid),
        .phy_tx_last(ptx_last), .phy_tx_ready(ptx_ready),
        .phy_tx_hdr(ptx_hdr), .phy_tx_cks(ptx_cks), .phy_tx_type(2'd0),
        .gt_txdata(a_tx),
        .clk_rx(clk), .rstn_rx(rstn), .link_up_rx(1'b1),
        .phy_rx_data(prx_data), .phy_rx_valid(prx_valid),
        .phy_rx_eof(prx_eof), .phy_rx_err(prx_err),
        .phy_rx_hdr(prx_hdr), .phy_rx_sof(prx_sof),
        .phy_rx_type(prx_type), .phy_rx_cks(prx_cks),
        .gt_rxdata(b_rx), .rxslide(slide), .rx_aligned(aligned),
        .ber_count(ber), .dbg(dbg)
    );

    // rxslide shifts the recovered word boundary by one bit.
    //
    // ADJUSTMENT: `offset` has exactly ONE procedural writer -- this block.
    // The brief's original code assigned `offset` from two places: a
    // blocking assignment in the stimulus `initial` block (`offset = off;`,
    // to set up each of the 32 starting offsets) and a nonblocking
    // assignment here (originally `always_ff`) that advances it on `slide`.
    // `xelab` rejected that outright at elaboration (SV LRM 9.2.2.4: a
    // variable written by an always_ff block must not be written by any
    // other procedural block -- "invalid combination of procedural
    // drivers", a hard error, not a lint warning).
    //
    // Downgrading that block from `always_ff` to plain `always` made it
    // elaborate, but two writers of the same variable is a race pattern by
    // construction, not something that becomes safe just because the
    // keyword changed. It was safe only because THIS stimulus sequencing
    // temporally partitions the two writers -- the initial block touches
    // `offset` solely while rstn=0, and the DUT holds rxslide low under
    // reset so this block cannot fire in that window. That safety is an
    // accident of sequencing, not a property of the code, and a later edit
    // to the stimulus could silently reintroduce a real race in the one
    // testbench that decides whether the aligner converges at all.
    //
    // Fixed properly: `offset` is now driven by this single clocked block
    // only. The stimulus requests a starting value via `offset_load`/
    // `offset_load_en` (a plain combinational request, not a write to
    // `offset` itself); this block is the sole arbiter between "load a new
    // starting offset" and "advance by one slide."
    // ONE SLIDE PER PULSE, NOT PER CYCLE. UG578 requires RXSLIDE to be held for
    // a minimum of TWO RXUSRCLK2 cycles and then deasserted for more than 32
    // before it can be reasserted; each such pulse moves the boundary by
    // exactly one bit. Modelling this level-sensitively (slide on every cycle
    // the signal is high) silently assumed a one-cycle pulse: the moment the
    // DUT was corrected to hold rxslide for the required two cycles, the model
    // stepped TWO bits per pulse, so only even offsets were reachable and
    // exactly 16 of the 32 starting offsets could never lock. That is a defect
    // in this model, not in the DUT -- and it would have read as the opposite.
    logic slide_q;
    always @(posedge clk) begin
        slide_q <= slide;
        if (offset_load_en)          offset <= offset_load;
        else if (slide && !slide_q)  offset <= (offset + 31) % 32;
    end

    int locked_from = 0, failed_from = 0;
    int max_lock_cycles = 0;

    initial begin
        ptx_data = '0; ptx_valid = 0; ptx_last = 0;
        ptx_hdr = 24'h000104;   // round=1, n_words=4
        ptx_cks = 24'hABCDEF;
        offset_load_en = 1'b0;

        $display("\n=== Test 1: aligner converges from all 32 bit offsets ===");
        for (int off = 0; off < 32; off++) begin
            automatic longint t_start;
            rstn = 0;
            // Hold offset_load_en for the WHOLE reset window rather than
            // pulsing it for a single cycle. A one-cycle pulse that gets
            // blocking-cleared on the same clock edge the single-writer
            // block reads it on is itself a same-edge blocking-write-vs-
            // clocked-read race (simulator-dependent evaluation order for
            // two processes triggered by the same event) -- exactly the
            // class of bug this refactor exists to eliminate. Holding it
            // high across all 5 reset cycles is idempotent (offset just
            // reloads the same value each cycle) and guarantees offset is
            // correctly loaded well before the edge that clears it, so
            // that edge's ordering no longer matters.
            offset_load = off; offset_load_en = 1'b1;
            repeat (5) @(posedge clk);  // same 5-cycle reset window as before
            offset_load_en = 1'b0;
            rstn = 1;
            t_start = $time;
            fork
                begin : wait_lock
                    wait (aligned === 1'b1);
                    locked_from++;
                    if (($time - t_start) / 2.56 > max_lock_cycles)
                        max_lock_cycles = ($time - t_start) / 2.56;
                    disable timeout;
                end
                begin : timeout
                    repeat (4000) @(posedge clk);
                    failed_from++;
                    $display("  offset %0d: NEVER LOCKED", off);
                    disable wait_lock;
                end
            join
        end
        $display("  locked from %0d/32 offsets", locked_from);
        $display("  worst-case convergence: %0d clk cycles", max_lock_cycles);
        if (locked_from == 32) $display("  PASS");
        else $display("  *** FAIL: %0d offsets never locked ***", failed_from);

        $display("\n=== Test 2: a frame round-trips once aligned ===");
        rstn = 0;
        offset_load = 7; offset_load_en = 1'b1;
        repeat (5) @(posedge clk);
        offset_load_en = 1'b0;
        rstn = 1;
        wait (aligned === 1'b1);
        repeat (10) @(posedge clk);

        fork
            begin
                @(posedge clk); ptx_valid <= 1'b1; ptx_data <= 32'h1111_1111;
                wait (ptx_ready === 1'b1);
                @(posedge clk); ptx_data <= 32'h2222_2222;
                @(posedge clk); ptx_data <= 32'h3333_3333;
                @(posedge clk); ptx_data <= 32'h4444_4444; ptx_last <= 1'b1;
                @(posedge clk); ptx_valid <= 1'b0; ptx_last <= 1'b0;
            end
            begin
                wait (prx_sof === 1'b1);
                if (prx_hdr !== 24'h000104)
                    $display("  *** header wrong: got %06x want 000104", prx_hdr);
                else
                    $display("  header OK: %06x", prx_hdr);
                wait (prx_eof === 1'b1);
                if (prx_cks !== 24'hABCDEF)
                    $display("  *** checksum wrong: got %06x", prx_cks);
                else
                    $display("  checksum OK: %06x", prx_cks);
            end
        join
        repeat (20) @(posedge clk);
        $display("  ber_count=%0d (expect 0)", ber);
        if (ber == 0) $display("  PASS"); else $display("  *** FAIL ***");

        // ------------------------------------------------------------------
        // Test 3 exists because the ORIGINAL loss-of-lock detector could never
        // fire. Both of its branches were gated on rx_is_align, but when word
        // alignment is genuinely lost every word is a ROTATION of W_ALIGN, and
        // no non-zero rotation of 5C3D_2A96 equals itself (tb_qlink_align
        // proves this). So rx_is_align was pinned false, rx_aligned could never
        // fall, and on hardware the framer would keep asserting alignment it no
        // longer had -- link_up would rise on a dead link with every diagnostic
        // bit reading healthy.
        //
        // The distinguishing feature of this test is that it does NOT touch
        // rstn. A reset makes any implementation re-hunt and proves nothing;
        // the whole failure was that nothing on hardware pulses rstn_rx when
        // the CDR silently re-locks on a new bit phase.
        $display("\n=== Test 3: alignment lost mid-run, WITHOUT a reset ===");
        begin
            automatic longint t_lost, t_relock;
            automatic bit ok = 1;

            if (aligned !== 1'b1) begin
                $display("  *** FAIL: not aligned going in");
                ok = 0;
            end

            // Shove the word boundary sideways while the link is up and locked.
            // rstn stays high throughout.
            @(posedge clk);
            offset_load = (offset + 5) % 32; offset_load_en = 1'b1;
            @(posedge clk);
            @(posedge clk);
            offset_load_en = 1'b0;

            t_lost = $time;
            fork
                begin wait (aligned === 1'b0); end
                begin repeat (20000) @(posedge clk); end
            join_any
            disable fork;

            if (aligned !== 1'b0) begin
                $display("  *** FAIL: rx_aligned never fell -- the framer still claims alignment it does not have");
                ok = 0;
            end else begin
                $display("  loss detected after %0d ns", $time - t_lost);
                t_relock = $time;
                fork
                    begin wait (aligned === 1'b1); end
                    begin repeat (20000) @(posedge clk); end
                join_any
                disable fork;

                if (aligned !== 1'b1) begin
                    $display("  *** FAIL: never re-locked after detecting loss");
                    ok = 0;
                end else begin
                    $display("  re-locked after a further %0d ns", $time - t_relock);
                end
            end

            if (ok) $display("  PASS: detected loss of alignment and re-hunted with no reset");
            else    $display("  *** FAIL ***");
        end

        $display("\nDone.");
        $finish;
    end

    initial begin
        #2000000;
        $display("*** TIMEOUT ***");
        $finish;
    end
endmodule
