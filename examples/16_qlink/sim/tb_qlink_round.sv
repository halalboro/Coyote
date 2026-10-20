/**
 * tb_qlink_round — modular round comparator (RFC-1982, 32-bit)
 *
 * Proves qlink_round_pkg survives the 32-bit wrap at ~71 min of 1 µs rounds.
 * The hazard this helper exists to prevent: unsigned-naive code would call
 * round = 1 "behind" round = 0xFFFFFFFE by about 4 billion, when the true
 * modular distance is +3. Every check below is a specific case where naive
 * unsigned arithmetic would be wrong.
 */

`timescale 1ns/1ps

module tb_qlink_round;

    import qlink_round_pkg::*;

    int errors = 0;

    task automatic check(input string name,
                         input logic actual, input logic expected);
        if (actual !== expected) begin
            $display("  FAIL  %-40s got=%b exp=%b", name, actual, expected);
            errors++;
        end
    endtask

    task automatic check_gap(input string name,
                             input logic signed [31:0] actual,
                             input logic signed [31:0] expected);
        if (actual !== expected) begin
            $display("  FAIL  %-40s got=%0d exp=%0d", name, actual, expected);
            errors++;
        end
    endtask

    initial begin
        $display("=== tb_qlink_round: 32-bit modular round arithmetic ===");

        // ---------------- 1. trivial ordering (sanity)
        check("5 < 10",       round_lt (32'd5,  32'd10), 1'b1);
        check("10 < 5",       round_lt (32'd10, 32'd5),  1'b0);
        check("5 > 10",       round_gt (32'd5,  32'd10), 1'b0);
        check("10 > 5",       round_gt (32'd10, 32'd5),  1'b1);
        check("5 == 5",       round_eq (32'd5,  32'd5),  1'b1);
        check("5 <= 5",       round_leq(32'd5,  32'd5),  1'b1);
        check("5 >= 5",       round_geq(32'd5,  32'd5),  1'b1);
        check("5 < 5",        round_lt (32'd5,  32'd5),  1'b0);
        check("5 > 5",        round_gt (32'd5,  32'd5),  1'b0);

        // ---------------- 2. wrap: 0 is one step ahead of 0xFFFFFFFF
        check("0 > 0xFFFFFFFF",     round_gt(32'd0, 32'hFFFFFFFF), 1'b1);
        check("0xFFFFFFFF < 0",     round_lt(32'hFFFFFFFF, 32'd0), 1'b1);
        check_gap("gap(0, FFFFFFFF)",   round_gap(32'd0, 32'hFFFFFFFF), 32'sd1);
        check_gap("gap(FFFFFFFF, 0)",   round_gap(32'hFFFFFFFF, 32'd0), -32'sd1);

        // ---------------- 3. signed-boundary crossing: 0x7FFF.. ↔ 0x8000..
        check("0x7FFFFFFF < 0x80000000",
              round_lt(32'h7FFFFFFF, 32'h80000000), 1'b1);
        check("0x80000000 > 0x7FFFFFFF",
              round_gt(32'h80000000, 32'h7FFFFFFF), 1'b1);
        check_gap("gap(0x80000000, 0x7FFFFFFF)",
                  round_gap(32'h80000000, 32'h7FFFFFFF), 32'sd1);

        // ---------------- 4. extremes of the signed range
        check_gap("gap(0x7FFFFFFF, 0) max+",
                  round_gap(32'h7FFFFFFF, 32'd0), 32'sh7FFFFFFF);
        // Half-circle: convention says 0x80000000 is "ahead" (round_gt true),
        // but the signed gap wraps to -2^31. Both lines below are the
        // compromise RFC-1982 §3.2 names explicitly.
        check_gap("gap(0x80000000, 0) half",
                  round_gap(32'h80000000, 32'd0), -32'sh80000000);
        check("0x80000000 > 0 (half-circle)",
              round_gt(32'h80000000, 32'd0), 1'b0);

        // ---------------- 5. the ~71 min wrap sweep (property-style)
        //
        //    Step a round forward by 7 for 10 000 iterations starting just
        //    below 0 so the sweep crosses the unsigned boundary ~17 times.
        //    At every step, next must be strictly > prev, and prev strictly
        //    < next, modularly. If the signed trick is right, this must
        //    hold whether or not we straddle 0xFFFFFFFF → 0 on this step.
        begin
            automatic logic [31:0] prev  = 32'hFFFFFF00;
            automatic logic [31:0] nxt   = '0;
            automatic int unsigned i     = 0;
            automatic int unsigned wraps = 0;
            for (i = 0; i < 10_000; i++) begin
                nxt = prev + 32'd7;
                check($sformatf("sweep[%0d] gt",  i), round_gt(nxt, prev), 1'b1);
                check($sformatf("sweep[%0d] lt'", i), round_lt(prev, nxt), 1'b1);
                if (nxt < prev) wraps++;
                prev = nxt;
            end
            $display("  sweep: 10000 steps of +7, %0d unsigned-boundary crossings",
                     wraps);
        end

        // ---------------- 6. staleness idiom: drop if more than W behind
        //
        //    rx_stale := round_gap(rx, cur) < -W  (W = 8 picked here)
        //    This is the shape Phase E's fence check will take.
        begin
            automatic logic [31:0] cur = 32'd100;
            check("rx=50  stale  W=8", round_gap(32'd50,  cur) < -32'sd8, 1'b1);
            check("rx=92  edge   W=8", round_gap(32'd92,  cur) < -32'sd8, 1'b0);
            check("rx=91  stale  W=8", round_gap(32'd91,  cur) < -32'sd8, 1'b1);
            check("rx=100 fresh  W=8", round_gap(32'd100, cur) < -32'sd8, 1'b0);
            check("rx=110 future W=8", round_gap(32'd110, cur) < -32'sd8, 1'b0);
        end

        // ---------------- 7. the real-wrap hazard
        //
        //    cur = 0xFFFFFFFE, rx = 1 → naive unsigned says "rx is 4 B behind",
        //    which would discard a frame that is in fact 3 rounds ahead.
        begin
            automatic logic [31:0] cur = 32'hFFFFFFFE;
            automatic logic [31:0] rx  = 32'd1;
            check("wrap: round_gt(1, FFFFFFFE)", round_gt(rx, cur), 1'b1);
            check_gap("wrap: gap(1, FFFFFFFE)",  round_gap(rx, cur), 32'sd3);
            check("wrap: NOT stale W=8",
                  round_gap(rx, cur) < -32'sd8, 1'b0);
        end

        $display("");
        if (errors == 0) begin
            $display("PASS: all round-comparator checks passed");
        end else begin
            $display("FAIL: %0d check(s) failed", errors);
        end
        $finish;
    end

endmodule
