/**
 * tb_qlink_sched — unit test for qlink_rx_sched (Phase D + E)
 *
 * Phase D scenarios: in-order sequence, future jump, stale arrival,
 * startup gate (no barrier counting before first arrival), barrier
 * close on silence, wrap crossing (0xFFFFFFFF → 0).
 *
 * Phase E scenarios: W_CUTOFF escalates missed → truncated after
 * consecutive barrier closes; fence_count tracks epoch rollovers;
 * fence_bad flags epochs that contained a skipped round; a clean
 * epoch (every expected round delivered) leaves fence_bad alone.
 */

`timescale 1ns/1ps

module tb_qlink_sched;

    localparam int T_BAR_CYCLES      = 128;    // short for test speed
    localparam int W_CUTOFF          = 3;      // small for test speed
    localparam int EPOCH_ROUNDS_LOG2 = 3;      // 8 rounds / epoch (test)

    logic        clk  = 1'b0;
    logic        rstn = 1'b0;
    logic        clr  = 1'b0;
    logic        rx_valid = 1'b0;
    logic [31:0] rx_round = '0;

    logic [31:0] expected_round;
    logic [31:0] rx_in_order, rx_stale, rx_future, rx_missed;
    logic [31:0] rx_truncated, fence_count, fence_bad;

    always #1.28 clk = ~clk;   // 390.625 MHz

    qlink_rx_sched #(
        .T_BAR_CYCLES     (T_BAR_CYCLES),
        .W_CUTOFF         (W_CUTOFF),
        .EPOCH_ROUNDS_LOG2(EPOCH_ROUNDS_LOG2)
    ) dut (.*);

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

    task automatic clear_all();
        clr <= 1'b1;
        @(posedge clk);
        clr <= 1'b0;
        // Give the DUT one cycle to re-arm after clear, plus one more
        // because expected_round is a nonblocking assignment and the
        // fence block reads it combinationally.
        repeat (2) @(posedge clk);
    endtask

    initial begin
        $display("=== tb_qlink_sched: RX scheduler + barrier + cutoff + fence ===");

        rstn <= 1'b0;
        repeat (4) @(posedge clk);
        rstn <= 1'b1;
        repeat (2) @(posedge clk);

        check_u32("post-reset expected",     expected_round, 32'd0);
        check_u32("post-reset in_order",     rx_in_order,    32'd0);
        check_u32("post-reset missed",       rx_missed,      32'd0);
        check_u32("post-reset truncated",    rx_truncated,   32'd0);
        check_u32("post-reset fence_count",  fence_count,    32'd0);
        check_u32("post-reset fence_bad",    fence_bad,      32'd0);

        // ---------------- Test 1: startup gate
        $display("\n--- Test 1: silence before first arrival is not a miss");
        repeat (T_BAR_CYCLES * 3) @(posedge clk);
        check_u32("test1 missed stays 0",    rx_missed,      32'd0);
        check_u32("test1 truncated stays 0", rx_truncated,   32'd0);
        check_u32("test1 expected stays 0",  expected_round, 32'd0);

        // ---------------- Test 2: in-order sequence
        $display("\n--- Test 2: in-order 0..4");
        for (int i = 0; i < 5; i++) begin
            deliver(i[31:0]);
            repeat (4) @(posedge clk);
        end
        check_u32("test2 in_order",          rx_in_order,    32'd5);
        check_u32("test2 expected == 5",     expected_round, 32'd5);
        check_u32("test2 missed stays 0",    rx_missed,      32'd0);

        // ---------------- Test 3: future jump
        $display("\n--- Test 3: future round=7 while expected=5 (gap=2)");
        deliver(32'd7);
        repeat (4) @(posedge clk);
        check_u32("test3 future count",      rx_future,      32'd1);
        check_u32("test3 missed +=2",        rx_missed,      32'd2);
        check_u32("test3 expected == 8",     expected_round, 32'd8);

        // ---------------- Test 4: stale
        $display("\n--- Test 4: stale round=3 while expected=8");
        deliver(32'd3);
        repeat (4) @(posedge clk);
        check_u32("test4 stale count",       rx_stale,       32'd1);
        check_u32("test4 missed unchanged",  rx_missed,      32'd2);
        check_u32("test4 expected unchanged", expected_round, 32'd8);

        // ---------------- Test 5: barrier close once (missed, not yet truncated)
        $display("\n--- Test 5: barrier closes once on silence (missed +=1)");
        repeat (T_BAR_CYCLES + 2) @(posedge clk);
        check_u32("test5 missed +=1",        rx_missed,      32'd3);
        check_u32("test5 expected == 9",     expected_round, 32'd9);
        check_u32("test5 truncated stays 0", rx_truncated,   32'd0);

        // ---------------- Test 6: W_CUTOFF escalation to truncated
        // W_CUTOFF=3, we already have 1 consec_miss from test 5.
        // Need 2 more silent barrier closes to reach W_CUTOFF.
        $display("\n--- Test 6: W_CUTOFF=3 forces truncated after 2 more silences");
        repeat (T_BAR_CYCLES + 2) @(posedge clk);  // consec=2
        check_u32("test6a truncated stays 0", rx_truncated,  32'd0);
        repeat (T_BAR_CYCLES + 2) @(posedge clk);  // consec=3 → escalate
        check_u32("test6b truncated +=1",     rx_truncated,  32'd1);
        // A fresh arrival resets consec_misses.
        deliver(32'd99);
        repeat (4) @(posedge clk);
        // Three MORE silent barriers escalate again.
        repeat ((T_BAR_CYCLES + 2) * 3) @(posedge clk);
        check_u32("test6c truncated +=1 again", rx_truncated, 32'd2);

        // ---------------- Test 7: fence_count / fence_bad with CLEAN epoch
        clear_all();
        $display("\n--- Test 7: one CLEAN epoch (fence_count==1, fence_bad==0)");
        // Deliver rounds 0..7 (one full epoch at EPOCH_LOG2=3). The
        // 8th in-order arrival takes expected to 8, which crosses the
        // epoch boundary and triggers fence_count.
        for (int i = 0; i < 8; i++) begin
            deliver(i[31:0]);
            repeat (4) @(posedge clk);
        end
        // Give the fence block a cycle to notice expected moved.
        repeat (2) @(posedge clk);
        check_u32("test7 in_order 8",         rx_in_order,    32'd8);
        check_u32("test7 expected == 8",      expected_round, 32'd8);
        check_u32("test7 fence_count == 1",   fence_count,    32'd1);
        check_u32("test7 fence_bad == 0",     fence_bad,      32'd0);

        // ---------------- Test 8: a DIRTY epoch bumps fence_bad
        $display("\n--- Test 8: dirty epoch (one barrier close) bumps fence_bad");
        // We're at expected=8 (epoch 1). Deliver rounds 8..13 clean.
        for (int i = 8; i < 14; i++) begin
            deliver(i[31:0]);
            repeat (4) @(posedge clk);
        end
        check_u32("test8 expected == 14",     expected_round, 32'd14);
        // Let one barrier close so round 14 is "missed", expected→15,
        // epoch_bad flag is set.
        repeat (T_BAR_CYCLES + 2) @(posedge clk);
        check_u32("test8 missed +=1",         rx_missed,      32'd1);
        check_u32("test8 expected == 15",     expected_round, 32'd15);
        // Then deliver round 15 so expected→16, which crosses the
        // next epoch boundary.
        deliver(32'd15);
        repeat (4) @(posedge clk);
        check_u32("test8 fence_count == 2",   fence_count,    32'd2);
        check_u32("test8 fence_bad == 1",     fence_bad,      32'd1);

        // ---------------- Test 9: future-jump across multiple epochs
        clear_all();
        $display("\n--- Test 9: future jump crosses several epochs in one shot");
        // From expected=0 jump to rx_round=20 (gap=20, expected→21).
        // 21 >> 3 = 2 → fence_count += 2. epoch_bad was set this
        // same cycle, so fence_bad += 1 (just once).
        deliver(32'd20);
        repeat (4) @(posedge clk);
        check_u32("test9 expected == 21",     expected_round, 32'd21);
        check_u32("test9 fence_count == 2",   fence_count,    32'd2);
        check_u32("test9 fence_bad == 1",     fence_bad,      32'd1);

        // ---------------- Test 10: wrap crossing (same as Phase D)
        clear_all();
        $display("\n--- Test 10: 0xFFFFFFFE → 0xFFFFFFFF → 0 is in-order");
        deliver(32'h7FFFFFFF);
        repeat (4) @(posedge clk);
        deliver(32'hFFFFFFFD);
        repeat (4) @(posedge clk);
        deliver(32'hFFFFFFFE);
        repeat (4) @(posedge clk);
        check_u32("test10 expected 0xFFFFFFFF",
                  expected_round, 32'hFFFFFFFF);
        deliver(32'hFFFFFFFF);
        repeat (4) @(posedge clk);
        check_u32("test10 wrap: expected 0",
                  expected_round, 32'd0);
        deliver(32'd0);
        repeat (4) @(posedge clk);
        check_u32("test10 past wrap: expected 1",
                  expected_round, 32'd1);

        $display("");
        if (errors == 0) begin
            $display("PASS: all RX scheduler + cutoff + fence checks passed");
        end else begin
            $display("FAIL: %0d check(s) failed", errors);
        end
        $finish;
    end

    initial begin
        #50_000_000;
        $display("FAIL: TB watchdog expired");
        $finish;
    end

endmodule
