/**
 * tb_qlink_tick — unit test for qlink_tick_cal
 *
 * Phase C FSM: trigger → send → wait → hold → commit at round boundary.
 * Also exercises timeout, re-train invalidation, and the "slot update at
 * next r₀" semantics (shadow does not become active until the boundary).
 *
 * This is a unit test. The full TICK path (CTL/is_tick/is_echo encoding,
 * RX-to-TX CDC of the echo pulse, generator arbitration) is covered by
 * lint_elab's full-hierarchy elaboration of vfpga_top.
 */

`timescale 1ns/1ps

module tb_qlink_tick;

    localparam int T_PEER    = 20;
    // Long enough that a d_rt=200 cycle test still fires an echo before
    // the FSM gives up and returns to IDLE. test 3 exercises the timeout
    // itself by not delivering an echo; it still finishes in <400 cycles.
    localparam int T_TIMEOUT = 300;

    logic        clk  = 1'b0;
    logic        rstn = 1'b0;
    logic [31:0] cur_cycle;

    logic        trigger_cal     = 1'b0;
    logic        round_boundary  = 1'b0;
    logic        retrain_sticky  = 1'b0;

    logic        tx_tick_req;
    logic        tx_tick_fire    = 1'b0;
    logic [31:0] tx_tick_cycle;

    logic        rx_echo_valid   = 1'b0;
    logic [31:0] rx_echo_cycle   = '0;

    logic [31:0] cal_d_active;
    logic [31:0] cal_d_shadow;
    logic        cal_valid;
    logic [1:0]  cal_state_dbg;

    // Free-running tx-clock cycle counter, same source as the DUT sees in
    // vfpga_top (where it reuses cyc_cnt for RTT).
    always_ff @(posedge clk) begin
        if (!rstn) cur_cycle <= '0;
        else       cur_cycle <= cur_cycle + 32'd1;
    end

    always #1.28 clk = ~clk;    // 2.56 ns period = 390.625 MHz

    qlink_tick_cal #(.T_PEER(T_PEER), .T_TIMEOUT(T_TIMEOUT)) dut (.*);

    int errors = 0;

    task automatic check(input string name,
                         input logic actual, input logic expected);
        if (actual !== expected) begin
            $display("  FAIL  %-50s got=%b exp=%b", name, actual, expected);
            errors++;
        end
    endtask

    task automatic check_u32(input string name,
                             input logic [31:0] actual,
                             input logic [31:0] expected);
        if (actual !== expected) begin
            $display("  FAIL  %-50s got=%0d exp=%0d", name, actual, expected);
            errors++;
        end
    endtask

    // One-shot pulse helpers.
    task automatic pulse_trigger();
        @(posedge clk); trigger_cal <= 1'b1;
        @(posedge clk); trigger_cal <= 1'b0;
    endtask

    task automatic pulse_round_boundary();
        @(posedge clk); round_boundary <= 1'b1;
        @(posedge clk); round_boundary <= 1'b0;
    endtask

    // Simulate the arbiter accepting the probe on the next cycle.
    task automatic accept_tx();
        @(posedge clk);
        wait (tx_tick_req);
        @(posedge clk); tx_tick_fire <= 1'b1;
        @(posedge clk); tx_tick_fire <= 1'b0;
    endtask

    // Simulate the echo arriving d_rt cycles after the probe went out.
    // The arbiter sees tx_tick_cycle at fire time and the peer echoes it
    // unchanged, so we capture that cycle number for later.
    task automatic deliver_echo(input logic [31:0] rt_cycles);
        logic [31:0] captured;
        wait (tx_tick_fire);
        captured = tx_tick_cycle;
        // Burn rt_cycles - 1 cycles (one cycle already elapsed between
        // the fire pulse and now).
        repeat (rt_cycles - 1) @(posedge clk);
        rx_echo_valid <= 1'b1;
        rx_echo_cycle <= captured;
        @(posedge clk);
        rx_echo_valid <= 1'b0;
    endtask

    initial begin
        $display("=== tb_qlink_tick: TICK calibration FSM ===");

        // Reset
        rstn <= 1'b0;
        repeat (4) @(posedge clk);
        rstn <= 1'b1;
        repeat (2) @(posedge clk);

        check("post-reset cal_valid",     cal_valid,                 1'b0);
        check_u32("post-reset cal_d_active", cal_d_active,           32'd0);
        check_u32("post-reset cal_d_shadow", cal_d_shadow,           32'd0);
        check("post-reset state==IDLE",   cal_state_dbg == 2'd0,     1'b1);

        // ---------------- Test 1: basic cal round trip
        // d_rt = 100 cycles, T_PEER = 20 → shadow = (100 - 20) / 2 = 40.
        $display("\n--- Test 1: basic cal, d_rt=100, T_PEER=20 → shadow=40");
        fork
            pulse_trigger();
            begin
                accept_tx();
                deliver_echo(32'd100);
            end
        join

        // Wait for shadow to settle.
        repeat (4) @(posedge clk);
        check_u32("test1 shadow", cal_d_shadow, 32'd40);
        check("test1 state==HOLD", cal_state_dbg == 2'd3, 1'b1);
        check("test1 active not yet committed", cal_valid, 1'b0);

        // Commit at the round boundary.
        pulse_round_boundary();
        @(posedge clk);
        check_u32("test1 active after boundary", cal_d_active, 32'd40);
        check("test1 cal_valid after boundary",  cal_valid, 1'b1);
        check("test1 state==IDLE after commit",  cal_state_dbg == 2'd0, 1'b1);

        // ---------------- Test 2: shadow does NOT update active without boundary
        // Verifies R15 semantics explicitly.
        $display("\n--- Test 2: shadow waits for boundary (R15)");
        fork
            pulse_trigger();
            begin
                accept_tx();
                deliver_echo(32'd200);     // shadow = (200 - 20)/2 = 90
            end
        join
        repeat (4) @(posedge clk);
        check_u32("test2 new shadow",            cal_d_shadow, 32'd90);
        check_u32("test2 active still old",      cal_d_active, 32'd40);
        check("test2 cal_valid still 1",         cal_valid,    1'b1);
        pulse_round_boundary();
        @(posedge clk);
        check_u32("test2 active updated",        cal_d_active, 32'd90);

        // ---------------- Test 3: timeout
        $display("\n--- Test 3: timeout (no echo) returns to IDLE");
        pulse_trigger();
        accept_tx();
        // Do NOT deliver echo. Wait > T_TIMEOUT.
        repeat (T_TIMEOUT + 8) @(posedge clk);
        check("test3 state back to IDLE",  cal_state_dbg == 2'd0, 1'b1);
        check_u32("test3 shadow unchanged", cal_d_shadow, 32'd90);
        check_u32("test3 active unchanged", cal_d_active, 32'd90);
        check("test3 cal_valid still 1",   cal_valid,    1'b1);

        // ---------------- Test 4: re-train sticky invalidates cal_valid
        //                           and aborts an in-flight probe.
        $display("\n--- Test 4: retrain invalidates cal_valid and aborts probe");
        pulse_trigger();
        accept_tx();
        // Mid-wait, assert retrain. Two posedges after the assignment
        // let the DUT's NBA for the retrain reaction settle before
        // the check reads the registers (classic SV TB race otherwise).
        repeat (10) @(posedge clk);
        retrain_sticky <= 1'b1;
        repeat (3) @(posedge clk);
        check("test4 cal_valid cleared by retrain", cal_valid, 1'b0);
        check("test4 state forced to IDLE",         cal_state_dbg == 2'd0, 1'b1);

        // Trigger while sticky high: must be ignored.
        pulse_trigger();
        repeat (4) @(posedge clk);
        check("test4 trigger ignored while sticky", cal_state_dbg == 2'd0, 1'b1);
        check("test4 no tx_tick_req",               tx_tick_req, 1'b0);

        // Clear sticky and retry.
        retrain_sticky <= 1'b0;
        @(posedge clk);
        fork
            pulse_trigger();
            begin
                accept_tx();
                deliver_echo(32'd60);     // shadow = (60-20)/2 = 20
            end
        join
        repeat (4) @(posedge clk);
        pulse_round_boundary();
        @(posedge clk);
        check_u32("test4 recovered cal_d_active", cal_d_active, 32'd20);
        check("test4 cal_valid re-asserted",      cal_valid,    1'b1);

        // ---------------- Test 5: underflow clamp
        // RTT = 10, T_PEER = 20 → naive subtraction underflows. Clamp to 0.
        $display("\n--- Test 5: RTT < T_PEER clamps shadow to 0");
        fork
            pulse_trigger();
            begin
                accept_tx();
                deliver_echo(32'd10);
            end
        join
        repeat (4) @(posedge clk);
        check_u32("test5 shadow clamped",         cal_d_shadow, 32'd0);
        pulse_round_boundary();
        @(posedge clk);
        check_u32("test5 active clamped",         cal_d_active, 32'd0);

        // ---------------- Test 6: trigger while in HOLD is ignored
        $display("\n--- Test 6: trigger ignored while in HOLD");
        fork
            pulse_trigger();
            begin
                accept_tx();
                deliver_echo(32'd80);     // shadow = (80-20)/2 = 30
            end
        join
        repeat (4) @(posedge clk);
        check("test6 state == HOLD", cal_state_dbg == 2'd3, 1'b1);
        pulse_trigger();     // should be dropped
        repeat (4) @(posedge clk);
        check("test6 still HOLD after re-trigger", cal_state_dbg == 2'd3, 1'b1);
        check_u32("test6 shadow unchanged", cal_d_shadow, 32'd30);
        pulse_round_boundary();
        @(posedge clk);
        check_u32("test6 active committed", cal_d_active, 32'd30);

        $display("");
        if (errors == 0) begin
            $display("PASS: all TICK calibration checks passed");
        end else begin
            $display("FAIL: %0d check(s) failed", errors);
        end
        $finish;
    end

    // Watchdog: should never need more than a few milliseconds.
    initial begin
        #5_000_000;
        $display("FAIL: TB watchdog expired");
        $finish;
    end

endmodule
