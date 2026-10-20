/**
 * QLink TICK calibration FSM — Phase C
 *
 * Measures the one-way link delay D by firing a TICK CTL frame carrying the
 * local tx-clock cycle count, then waiting for the peer to echo it back.
 * Round-trip delay = cur_cycle - sent_cycle. One-way D = (RTT - T_PEER) / 2,
 * where T_PEER is the peer's fixed internal rx-to-tx turnaround.
 *
 * The measured value lands in cal_d_shadow and only becomes cal_d_active
 * at the next round boundary (R15: "slot update at next r₀"), so a
 * calibration in flight never affects scheduling of an epoch already in
 * progress. Any GT re-train raises retrain_sticky, which clears cal_valid
 * and forces software to recalibrate before trusting the slot schedule.
 *
 * TICK frame encoding on the wire (reused in vfpga_top.svh):
 *   TYPE   = TYPE_CTL   (4'h4)
 *   FLAGS  = {2'b00, is_echo, is_tick}
 *              is_tick  = 1'b1
 *              is_echo  = 1'b0 for a probe, 1'b1 for the reply
 *   ROUND  = tx-clock cycle at which the probe was emitted (the timestamp)
 *   PAYLOAD = all zeros for Phase C (reserved for peer-perceived delay later)
 *
 * The TICK ROUND field double-booking (round-counter vs timestamp) is safe
 * because TICK frames do not participate in the deadline schedule: they are
 * off-deadline CTL traffic. A fuser receiving a TICK does not advance its
 * round state from it.
 *
 * This module runs entirely in the tx-clock domain. Retrain_sticky is
 * crossed in from aclk by the caller.
 */

`timescale 1ns/1ps

module qlink_tick_cal #(
    // Peer internal rx→tx turnaround, in local tx-clock cycles. For a
    // peer running identical RTL this is the fixed receive-to-echo
    // pipeline depth: link_rx cut-through delivery + a crossing +
    // link_tx first-word emission. Measured constant per build; the
    // tx-clock cycle used here IS the peer's tx-clock because they
    // nominally match. Default 20 is a placeholder; vfpga_top overrides.
    parameter int T_PEER    = 20,
    // Give up on an echo after this many cycles and return to IDLE
    // without updating the shadow. ~2.6 µs at 390.625 MHz.
    parameter int T_TIMEOUT = 1024
) (
    input  logic        clk,
    input  logic        rstn,

    // Free-running tx-clock cycle count, same source used for RTT_CYCLES.
    input  logic [31:0] cur_cycle,

    // One-shot trigger: software (via CSR CDC pulse) asks for a new cal.
    // Ignored unless state == CAL_IDLE.
    input  logic        trigger_cal,

    // Boundary pulse: when state == CAL_HOLD, this commits shadow→active.
    // Phase C: vfpga_top pulses this at a configurable round rollover.
    // Phase D: this becomes the real slot boundary (R15).
    input  logic        round_boundary,

    // Re-train dirty bit from the PHY wrapper. While set, cal_valid stays
    // low and any in-flight calibration is forced back to IDLE: the
    // measured D belongs to a lane geometry that no longer applies.
    input  logic        retrain_sticky,

    // TICK probe emission request. Vfpga_top arbitrates against the
    // generator and the echo path; when it accepts (tx_tick_fire pulsed),
    // the FSM latches cur_cycle as the sent timestamp and moves to WAIT.
    output logic        tx_tick_req,
    input  logic        tx_tick_fire,
    output logic [31:0] tx_tick_cycle,

    // TICK echo arrival from the RX path (filtered by the caller:
    // rx_valid && TYPE == CTL && FLAGS == {is_echo=1, is_tick=1}, with
    // the ROUND field pulled from the frame as the original timestamp).
    input  logic        rx_echo_valid,
    input  logic [31:0] rx_echo_cycle,

    // Outputs for CSRs.
    output logic [31:0] cal_d_active,
    output logic [31:0] cal_d_shadow,
    output logic        cal_valid,
    output logic [1:0]  cal_state_dbg
);

    typedef enum logic [1:0] {
        CAL_IDLE,   // waiting for trigger
        CAL_SEND,   // asserting tx_tick_req until the arbiter fires it
        CAL_WAIT,   // probe out, waiting for the echo (or timeout)
        CAL_HOLD    // measured; waiting for round_boundary to commit
    } cal_state_e;

    cal_state_e state;
    logic [31:0] sent_cycle;
    logic [31:0] wait_timer;
    logic [31:0] measured_rtt;

    assign cal_state_dbg = state;
    assign tx_tick_req   = (state == CAL_SEND);
    assign tx_tick_cycle = cur_cycle;    // sampled at fire time by the arbiter

    always_ff @(posedge clk) begin
        if (!rstn) begin
            state         <= CAL_IDLE;
            sent_cycle    <= '0;
            wait_timer    <= '0;
            measured_rtt  <= '0;
            cal_d_active  <= '0;
            cal_d_shadow  <= '0;
            cal_valid     <= 1'b0;
        end else begin
            // A re-train invalidates the active D unconditionally. The
            // shadow is kept so software can read "last measured" even
            // after a re-train, but it is no longer trustworthy.
            if (retrain_sticky) begin
                cal_valid <= 1'b0;
                if (state == CAL_WAIT || state == CAL_SEND)
                    state <= CAL_IDLE;
            end

            unique case (state)
                CAL_IDLE: begin
                    if (trigger_cal && !retrain_sticky) begin
                        state      <= CAL_SEND;
                        wait_timer <= '0;
                    end
                end

                CAL_SEND: begin
                    if (tx_tick_fire) begin
                        sent_cycle <= cur_cycle;
                        state      <= CAL_WAIT;
                        wait_timer <= '0;
                    end
                end

                CAL_WAIT: begin
                    wait_timer <= wait_timer + 32'd1;
                    if (rx_echo_valid && rx_echo_cycle == sent_cycle) begin
                        // RTT in cycles, minus the peer's internal
                        // turnaround, halved. If the arithmetic underflows
                        // (peer slower than expected), clamp to zero rather
                        // than wrap through 2^32.
                        measured_rtt <= cur_cycle - sent_cycle;
                        if ((cur_cycle - sent_cycle) > T_PEER)
                            cal_d_shadow <= (cur_cycle - sent_cycle - T_PEER) >> 1;
                        else
                            cal_d_shadow <= '0;
                        state <= CAL_HOLD;
                    end else if (wait_timer >= T_TIMEOUT) begin
                        state <= CAL_IDLE;
                    end
                end

                CAL_HOLD: begin
                    if (round_boundary) begin
                        cal_d_active <= cal_d_shadow;
                        cal_valid    <= 1'b1;
                        state        <= CAL_IDLE;
                    end
                end
            endcase
        end
    end

endmodule
