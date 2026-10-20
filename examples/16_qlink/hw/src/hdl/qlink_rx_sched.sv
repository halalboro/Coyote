/**
 * QLink RX scheduler — Phase E (adds cutoff + fence stub to Phase D)
 *
 * Tracks the expected round number using modular 32-bit arithmetic
 * (qlink_round_pkg) so a 71-minute wrap never flips the stale/future
 * classification. On every non-TICK data frame it decides whether the
 * frame is in-order, stale, or ahead of schedule, and advances the
 * expected round accordingly. A barrier timer closes T_BAR_CYCLES
 * after the last data arrival; when it closes without a new frame,
 * one erasure is counted and the expected round is advanced.
 *
 * Phase E adds two signals on top:
 *   * rx_truncated: W_CUTOFF consecutive barrier closes without any
 *     arrival. The soft "missed" is a bump; truncated is the hard
 *     escalation the slow decoder has to notice.
 *   * fence_count / fence_bad: one fence per epoch of EPOCH_ROUNDS
 *     rounds that the scheduler walks through. fence_bad bumps for
 *     every epoch that contained at least one skipped expected
 *     round (barrier close OR future-jump gap). Software reads
 *     fence_count / fence_bad to decide epoch-boundary commits.
 *
 * This is the first consumer of qlink_round_pkg. Phase A's plain
 * comparator in vfpga_top's checker is kept — it still only looks
 * at payload vs pattern(round), which is independent of ordering.
 *
 * Phase D/E policy (will refine when the real W and cutoff numbers
 * are chosen in the open-items pass):
 *   - A frame with round == expected is in-order; advance expected.
 *   - A frame with round > expected (modular) is ahead; count every
 *     round in the gap as missed, jump expected to rx_round + 1, and
 *     poison the current epoch.
 *   - A frame with round < expected (modular) is stale; count it but
 *     do not advance expected.
 *   - T_BAR_CYCLES with no data closes one barrier: missed += 1,
 *     expected += 1, timer resets, epoch poisoned.
 *   - W_CUTOFF consecutive barrier closes without any arrival in
 *     between: truncated += 1, consec_misses resets.
 *
 * Startup gate: the first arrival latches rx_seen, enabling barrier
 * counting. Before any arrival, long periods of silence don't count
 * as misses — the schedule has not yet started.
 *
 * The counters saturate at 2^32 - 1 by overflow wraparound; the host
 * is expected to clear them with `clr` between runs.
 */

`timescale 1ns/1ps

module qlink_rx_sched #(
    // Barrier closes after this many cycles of no data arrival. For
    // a 1 µs SYN cadence at 390.625 MHz (391 cycles/slot) a value
    // around 2 × slot is a sensible default: tolerates a slot of
    // skew without false alarms. Vfpga_top overrides.
    parameter int T_BAR_CYCLES      = 1024,
    // Hard cutoff: how many back-to-back barrier closes count as a
    // truncation event. 4 slots at 1 µs cadence ≈ a 4 µs outage.
    // Open-items pass will tie this to a measured W.
    parameter int W_CUTOFF          = 4,
    // Epoch size in rounds (log2). Must match the TX side's
    // EPOCH_ROUNDS_LOG2 so fence boundaries line up with the TICK
    // calibration commit boundary.
    parameter int EPOCH_ROUNDS_LOG2 = 4
) (
    input  logic        clk,
    input  logic        rstn,
    input  logic        clr,

    // Non-TICK data frame arrival (filtered by the caller).
    input  logic        rx_valid,
    input  logic [31:0] rx_round,

    output logic [31:0] expected_round,
    output logic [31:0] rx_in_order,
    output logic [31:0] rx_stale,
    output logic [31:0] rx_future,
    output logic [31:0] rx_missed,
    // Phase E
    output logic [31:0] rx_truncated,
    output logic [31:0] fence_count,
    output logic [31:0] fence_bad
);

    import qlink_round_pkg::*;

    logic [31:0] barrier_timer;
    logic        rx_seen;
    logic [31:0] consec_misses;
    logic        epoch_bad;
    logic [31:0] prev_expected_epoch;

    // Current epoch index. `>>` is zero-extending, so the top
    // EPOCH_ROUNDS_LOG2 bits are 0 and modular arithmetic below
    // stays width-safe.
    wire [31:0]  expected_epoch = expected_round >> EPOCH_ROUNDS_LOG2;

    always_ff @(posedge clk) begin
        if (!rstn || clr) begin
            expected_round      <= '0;
            rx_in_order         <= '0;
            rx_stale            <= '0;
            rx_future           <= '0;
            rx_missed           <= '0;
            rx_truncated        <= '0;
            fence_count         <= '0;
            fence_bad           <= '0;
            barrier_timer       <= '0;
            rx_seen             <= 1'b0;
            consec_misses       <= '0;
            epoch_bad           <= 1'b0;
            prev_expected_epoch <= '0;
        end else begin
            // ---------- Fence tracking ----------
            // Fire when expected rolled into one or more new epochs
            // since last cycle. A single future-jump that crosses
            // several epochs counts them all in fence_count but
            // only once in fence_bad — the epoch_bad flag collapses
            // multiple misses to one dirty-epoch report.
            if (expected_epoch != prev_expected_epoch) begin
                fence_count         <= fence_count +
                                       (expected_epoch - prev_expected_epoch);
                prev_expected_epoch <= expected_epoch;
                if (epoch_bad) fence_bad <= fence_bad + 32'd1;
                epoch_bad <= 1'b0;
            end

            // ---------- Arrival vs barrier ----------
            if (rx_valid) begin
                barrier_timer <= '0;
                rx_seen       <= 1'b1;
                consec_misses <= '0;
                if (round_eq(rx_round, expected_round)) begin
                    rx_in_order    <= rx_in_order + 32'd1;
                    expected_round <= expected_round + 32'd1;
                end else if (round_gt(rx_round, expected_round)) begin
                    rx_future      <= rx_future + 32'd1;
                    rx_missed      <= rx_missed +
                                      32'(round_gap(rx_round, expected_round));
                    expected_round <= rx_round + 32'd1;
                    epoch_bad      <= 1'b1;
                end else begin
                    rx_stale <= rx_stale + 32'd1;
                end
            end else if (rx_seen) begin
                if (barrier_timer >= T_BAR_CYCLES) begin
                    rx_missed      <= rx_missed + 32'd1;
                    expected_round <= expected_round + 32'd1;
                    barrier_timer  <= '0;
                    epoch_bad      <= 1'b1;
                    // Hard-cutoff escalation. consec_misses counts
                    // back-to-back barrier closes with no arrival
                    // in between; once it reaches W_CUTOFF, we
                    // register a truncation and start counting over.
                    if (consec_misses + 32'd1 >= W_CUTOFF) begin
                        rx_truncated  <= rx_truncated + 32'd1;
                        consec_misses <= '0;
                    end else begin
                        consec_misses <= consec_misses + 32'd1;
                    end
                end else begin
                    barrier_timer <= barrier_timer + 32'd1;
                end
            end
        end
    end

endmodule
