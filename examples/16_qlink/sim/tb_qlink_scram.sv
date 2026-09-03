/**
 * qlink_scrambler unit test.
 *
 * A self-synchronous scrambler has one property that matters and is easy to get
 * wrong: descrambling must recover the input WITHOUT the two ends ever
 * exchanging state. The descrambler's state comes from the ciphertext it
 * receives, so it locks itself within 58 bits of arriving mid-stream.
 *
 * Test 3 is the one that matters for QEC specifically: an all-zeros payload is
 * the common case for a syndrome (most stabilizers do not fire) and is exactly
 * the input that would produce a DC-locked, transition-free line and unlock the
 * CDR if the scrambler were absent or broken.
 */
`timescale 1ns/1ps
module tb_qlink_scram;
    logic [31:0] plain, cipher, recovered;
    logic [57:0] s_tx, s_tx_n, s_rx, s_rx_n;

    qlink_scrambler #(.INVERT(0)) u_scr (
        .d_in(plain),  .state_in(s_tx), .d_out(cipher),    .state_out(s_tx_n));
    qlink_scrambler #(.INVERT(1)) u_des (
        .d_in(cipher), .state_in(s_rx), .d_out(recovered), .state_out(s_rx_n));

    int errors = 0, ones = 0, total = 0, maxrun = 0, run = 0;
    logic last = 1'bx;

    task automatic step(input logic [31:0] p);
        plain = p;
        #1;
        if (recovered !== plain) begin
            errors++;
            $display("  MISMATCH plain=%08x cipher=%08x recovered=%08x",
                     plain, cipher, recovered);
        end
        for (int i = 0; i < 32; i++) begin
            if (cipher[i]) ones++;
            total++;
            if (cipher[i] === last) run++; else run = 1;
            last = cipher[i];
            if (run > maxrun) maxrun = run;
        end
        s_tx = s_tx_n; s_rx = s_rx_n;
        #1;
    endtask

    initial begin
        // Deliberately DIFFERENT initial states: a self-synchronous descrambler
        // must converge without being told the transmitter's state.
        s_tx = 58'h3FF_FFFF_FFFF_FFFF;
        s_rx = 58'h000_0000_0000_0000;

        // Two words to let the descrambler lock (58 bits < 2 x 32).
        step(32'hDEAD_BEEF); step(32'hCAFE_BABE);
        errors = 0; ones = 0; total = 0; maxrun = 0;

        $display("\n=== Test 1: random payload round-trips ===");
        for (int i = 0; i < 500; i++) step($urandom());
        $display("  errors=%0d", errors);
        if (errors == 0) $display("  PASS"); else $display("  *** FAIL ***");

        $display("\n=== Test 2: all-ones payload ===");
        errors = 0;
        for (int i = 0; i < 200; i++) step(32'hFFFF_FFFF);
        if (errors == 0) $display("  PASS"); else $display("  *** FAIL ***");

        $display("\n=== Test 3: ALL-ZEROS payload (the QEC common case) ===");
        errors = 0; ones = 0; total = 0; maxrun = 0;
        for (int i = 0; i < 1000; i++) step(32'h0000_0000);
        $display("  errors=%0d  ones=%0d/%0d (%.1f%%)  longest run=%0d",
                 errors, ones, total, 100.0*ones/total, maxrun);
        // A dead scrambler would give 0%% ones and a run of 32000.
        if (errors == 0 && ones > total*4/10 && ones < total*6/10 && maxrun < 40)
            $display("  PASS: an empty syndrome still produces a balanced, transition-rich line");
        else
            $display("  *** FAIL: the CDR would unlock on an empty syndrome ***");

        $display("\nDone.");
        $finish;
    end
endmodule
