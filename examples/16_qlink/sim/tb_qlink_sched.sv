/**
 * tb_qlink_sched — unit test for qlink_rx_sched (Phase D)
 *
 * Validates the barrier timer + modular round classification. Six
 * scenarios: in-order sequence, future jump, stale arrival, startup
 * gate (no barrier counting before first arrival), barrier close on
 * silence, wrap crossing (0xFFFFFFFF → 0).
 */

`timescale 1ns/1ps

module tb_qlink_sched;

    localparam int T_BAR_CYCLES = 128;    // short for test speed

    logic        clk  = 1'b0;
    logic        rstn = 1'b0;
    logic        clr  = 1'b0;
    logic        rx_valid = 1'b0;
    logic [31:0] rx_round = '0;

    logic [31:0] expected_round;
    logic [31:0] rx_in_order, rx_stale, rx_future, rx_missed;

    always #1.28 clk = ~clk;   // 390.625 MHz

    qlink_rx_sched #(.T_BAR_CYCLES(T_BAR_CYCLES)) dut (.*);

    int errors = 0;

    task automatic check_u32(input string name,
                             input logic [31:0] actual,
                             input logic [31:0] expected);
        if (actual !== expected) begin
            $display("  FAIL  %-50s got=%0d exp=%0d", name, actual, expected);
            errors++;
        end
    endtask

    // Pulse rx_valid for one cycle with the given round.
    task automatic deliver(input logic [31:0] r);
        @(posedge clk);
        rx_round <= r;
        rx_valid <= 1'b1;
        @(posedge clk);
        rx_valid <= 1'b0;
    endtask

    initial begin
        $display("=== tb_qlink_sched: RX scheduler + barrier ===");

        rstn <= 1'b0;
        repeat (4) @(posedge clk);
        rstn <= 1'b1;
        repeat (2) @(posedge clk);

        check_u32("post-reset expected",    expected_round, 32'd0);
        check_u32("post-reset in_order",    rx_in_order,    32'd0);
        check_u32("post-reset missed",      rx_missed,      32'd0);

        // ---------------- Test 1: startup gate
        // Before any arrival, long silence must NOT count as missed.
        $display("\n--- Test 1: silence before first arrival is not a miss");
        repeat (T_BAR_CYCLES * 3) @(posedge clk);
        check_u32("test1 missed stays 0",   rx_missed,      32'd0);
        check_u32("test1 expected stays 0", expected_round, 32'd0);

        // ---------------- Test 2: in-order sequence
        $display("\n--- Test 2: in-order 0..4");
        for (int i = 0; i < 5; i++) begin
            deliver(i[31:0]);
            repeat (4) @(posedge clk);
        end
        check_u32("test2 in_order",         rx_in_order,    32'd5);
        check_u32("test2 expected == 5",    expected_round, 32'd5);
        check_u32("test2 missed stays 0",   rx_missed,      32'd0);

        // ---------------- Test 3: future jump (gap of 2 means miss +=2)
        // expected is 5, deliver round 7 → gap=2, missed +=2, expected→8
        $display("\n--- Test 3: future round=7 while expected=5 (gap=2)");
        deliver(32'd7);
        repeat (4) @(posedge clk);
        check_u32("test3 future count",     rx_future,      32'd1);
        check_u32("test3 missed +=2",       rx_missed,      32'd2);
        check_u32("test3 expected == 8",    expected_round, 32'd8);

        // ---------------- Test 4: stale (round < expected)
        $display("\n--- Test 4: stale round=3 while expected=8");
        deliver(32'd3);
        repeat (4) @(posedge clk);
        check_u32("test4 stale count",      rx_stale,       32'd1);
        check_u32("test4 missed unchanged", rx_missed,      32'd2);
        check_u32("test4 expected unchanged", expected_round, 32'd8);

        // ---------------- Test 5: barrier close after silence
        // After test 4 the timer is zero (just saw a frame). Wait
        // T_BAR_CYCLES+2 to force exactly one close.
        $display("\n--- Test 5: barrier closes once on silence");
        repeat (T_BAR_CYCLES + 2) @(posedge clk);
        check_u32("test5 missed +=1 (one close)", rx_missed, 32'd3);
        check_u32("test5 expected == 9",   expected_round,  32'd9);
        // A second interval → another close.
        repeat (T_BAR_CYCLES + 2) @(posedge clk);
        check_u32("test5 second close",     rx_missed,      32'd4);
        check_u32("test5 expected == 10",   expected_round, 32'd10);

        // ---------------- Test 6: wrap crossing
        // Clear and arm with expected=0xFFFFFFFE. Deliver 0xFFFFFFFE
        // (in-order), then 0xFFFFFFFF (in-order), then 0 (in-order).
        $display("\n--- Test 6: 0xFFFFFFFE → 0xFFFFFFFF → 0 is in-order");
        clr <= 1'b1;
        @(posedge clk);
        clr <= 1'b0;
        @(posedge clk);
        check_u32("test6 cleared missed",   rx_missed,      32'd0);
        check_u32("test6 cleared expected", expected_round, 32'd0);
        // Jump expected to 0xFFFFFFFE by delivering a future.
        // Gap from 0 to 0xFFFFFFFE = -2 (modular) → that's round_lt, stale.
        // Can't jump expected forward through stale. Instead, let
        // barriers advance expected one by one — that's slow. Easier:
        // deliver incrementally. Actually simplest: nudge expected via
        // a legitimate future jump: deliver(0xFFFFFFFD) with gap +FFFFFFFD,
        // which is > 2^31 and thus round_lt, STALE. That won't work.
        //
        // The cleanest way to reach expected=0xFFFFFFFE: just deliver
        // round=0xFFFFFFFE as a future. Gap = 0xFFFFFFFE which, treated
        // as signed, is -2 — round_lt, stale. Hmm. The modular
        // comparator does NOT let you jump by 2^32-2 (that's half-circle).
        //
        // Deliver(0x7FFFFFFF): gap = 0x7FFFFFFF (positive signed), gt,
        // missed += 0x7FFFFFFF, expected → 0x80000000.
        // Deliver(0xFFFFFFFD): gap = 0x7FFFFFFD, gt,
        // missed += 0x7FFFFFFD, expected → 0xFFFFFFFE.
        // Clear counters again so wrap test is clean.
        deliver(32'h7FFFFFFF);
        repeat (4) @(posedge clk);
        deliver(32'hFFFFFFFD);
        repeat (4) @(posedge clk);
        check_u32("test6 expected == 0xFFFFFFFE", expected_round, 32'hFFFFFFFE);
        clr <= 1'b1;
        @(posedge clk);
        clr <= 1'b0;
        @(posedge clk);
        // Reset moves expected back to 0 — but we specifically want to
        // test wrap crossing from 0xFFFFFFFE. Alternative test:
        // Deliver 0xFFFFFFFE, 0xFFFFFFFF, 0, 1 with no clear.
        // After clear, expected = 0 and in_order = 0 again. Build
        // from scratch: use rapid-fire future-jump to walk through
        // the top of the range, then prove wrap works.
        $display("    (clear + rebuild)");
        deliver(32'h7FFFFFFF);     // expected: 0 → 0x80000000, missed += 0x7FFFFFFF
        repeat (4) @(posedge clk);
        deliver(32'hFFFFFFFD);     // expected: 0x80000000 → 0xFFFFFFFE, missed += 0x7FFFFFFD
        repeat (4) @(posedge clk);
        deliver(32'hFFFFFFFE);     // in-order
        repeat (4) @(posedge clk);
        check_u32("test6 after 0xFFFFFFFE: in_order 1",
                  rx_in_order, 32'd1);
        check_u32("test6 after 0xFFFFFFFE: expected 0xFFFFFFFF",
                  expected_round, 32'hFFFFFFFF);
        deliver(32'hFFFFFFFF);     // in-order
        repeat (4) @(posedge clk);
        check_u32("test6 after 0xFFFFFFFF: in_order 2",
                  rx_in_order, 32'd2);
        check_u32("test6 after 0xFFFFFFFF: expected 0 (wrap)",
                  expected_round, 32'd0);
        deliver(32'd0);            // in-order ACROSS the wrap
        repeat (4) @(posedge clk);
        check_u32("test6 after 0 (wrap): in_order 3",
                  rx_in_order, 32'd3);
        check_u32("test6 after 0 (wrap): expected 1",
                  expected_round, 32'd1);

        $display("");
        if (errors == 0) begin
            $display("PASS: all RX scheduler checks passed");
        end else begin
            $display("FAIL: %0d check(s) failed", errors);
        end
        $finish;
    end

    initial begin
        #5_000_000;
        $display("FAIL: TB watchdog expired");
        $finish;
    end

endmodule
