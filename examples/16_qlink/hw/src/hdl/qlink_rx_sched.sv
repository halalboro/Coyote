/**
 * QLink RX scheduler — Phase D (minimal slot schedule + barrier T_bar)
 *
 * Tracks the expected round number using modular 32-bit arithmetic
 * (qlink_round_pkg) so a 71-minute wrap never flips the stale/future
 * classification. On every non-TICK data frame it decides whether the
 * frame is in-order, stale, or ahead of schedule, and advances the
 * expected round accordingly. A barrier timer closes T_BAR_CYCLES
 * after the last data arrival; when it closes without a new frame,
 * one erasure is counted and the expected round is advanced.
 *
 * This is the first consumer of qlink_round_pkg. Phase A's plain
 * comparator in vfpga_top's checker is kept — it still only looks
 * at payload vs pattern(round), which is independent of ordering.
 *
 * Phase D policy (will refine in later phases):
 *   - A frame with round == expected is in-order; advance expected.
 *   - A frame with round > expected (modular) is ahead; count every
 *     round in the gap as missed, jump expected to rx_round + 1.
 *   - A frame with round < expected (modular) is stale; count it but
 *     do not advance expected.
 *   - T_BAR_CYCLES with no data closes one barrier: missed += 1,
 *     expected += 1, timer resets.
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
    parameter int T_BAR_CYCLES = 1024
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
    output logic [31:0] rx_missed
);

    import qlink_round_pkg::*;

    logic [31:0] barrier_timer;
    logic        rx_seen;

    always_ff @(posedge clk) begin
        if (!rstn || clr) begin
            expected_round <= '0;
            rx_in_order    <= '0;
            rx_stale       <= '0;
            rx_future      <= '0;
            rx_missed      <= '0;
            barrier_timer  <= '0;
            rx_seen        <= 1'b0;
        end else begin
            if (rx_valid) begin
                barrier_timer <= '0;
                rx_seen       <= 1'b1;
                if (round_eq(rx_round, expected_round)) begin
                    rx_in_order    <= rx_in_order + 32'd1;
                    expected_round <= expected_round + 32'd1;
                end else if (round_gt(rx_round, expected_round)) begin
                    // Future arrival — count the skipped rounds as missed
                    // and jump expected past rx_round. round_gap(a,b) is
                    // positive here because round_gt(a,b) is true, so
                    // casting through 32'(..) is width-only, not sign.
                    rx_future      <= rx_future + 32'd1;
                    rx_missed      <= rx_missed +
                                      32'(round_gap(rx_round, expected_round));
                    expected_round <= rx_round + 32'd1;
                end else begin
                    rx_stale <= rx_stale + 32'd1;
                end
            end else if (rx_seen) begin
                if (barrier_timer >= T_BAR_CYCLES) begin
                    rx_missed      <= rx_missed + 32'd1;
                    expected_round <= expected_round + 32'd1;
                    barrier_timer  <= '0;
                end else begin
                    barrier_timer  <= barrier_timer + 32'd1;
                end
            end
        end
    end

endmodule
