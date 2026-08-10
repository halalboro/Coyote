/**
 * BRAID event-with-payload clock crossing
 *
 * Carries one value across a clock boundary atomically, on demand. Wraps
 * xpm_cdc_handshake with the four-phase source-side sequencing that macro
 * requires, so call sites stay readable.
 *
 * WHY NOT SOMETHING SIMPLER
 *
 * The obvious shortcut -- xpm_cdc_array_single on the data plus xpm_cdc_pulse on
 * the valid -- is WRONG here and looks right in simulation. Both paths have the
 * same number of destination flops, so the data is still resolving from its own
 * metastability on the cycle the pulse arrives, and individual bits can land on
 * either side. The result is a torn word: a payload that is half of round N and
 * half of round N+1, with a perfectly valid-looking valid pulse on it. Nothing
 * in the protocol above can detect that, because the checksum is recomputed on
 * the far side of the crossing.
 *
 * xpm_cdc_handshake holds the source data stable until the destination has
 * captured it, which is what makes the transfer atomic.
 *
 * DROP-DON'T-QUEUE, same as the rest of BRAID: a request arriving while a
 * transfer is in flight is discarded and src_busy is asserted so the caller can
 * count it. A four-phase handshake costs roughly SRC_SYNC_FF + DEST_SYNC_FF
 * destination cycles per transfer, so the sustainable rate is well under one
 * transfer per ~10 cycles. Every BRAID user of this module is either
 * single-outstanding (the latency benchmark's echo) or a
 * latest-value-wins status register, so dropping is the correct policy rather
 * than a limitation to work around.
 *
 * dest_data is only meaningful on the cycle dest_valid is high. Capture it.
 */

module braid_cdc_event #(
    parameter int WIDTH = 32
) (
    input  logic             src_clk,
    input  logic             src_rstn,
    input  logic             src_valid,
    input  logic [WIDTH-1:0] src_data,
    output logic             src_busy,
    // High on the cycle src_data is actually latched. Callers that must not
    // lose an update hold src_valid as a LEVEL and drop it on src_accept,
    // rather than presenting a one-cycle pulse that the busy check can discard.
    output logic             src_accept,

    input  logic             dest_clk,
    output logic             dest_valid,
    output logic [WIDTH-1:0] dest_data
);

    logic             src_send, src_rcv;
    logic [WIDTH-1:0] src_hold;
    logic             dest_req, dest_req_q;

    assign src_busy   = src_send || src_rcv;
    assign src_accept = !src_send && !src_rcv && src_valid;

    always_ff @(posedge src_clk) begin
        if (!src_rstn) begin
            src_send <= 1'b0;
            src_hold <= '0;
        end else if (src_send) begin
            // Four-phase: drop src_send only once the destination has
            // acknowledged, then wait for src_rcv to fall before starting again.
            if (src_rcv) src_send <= 1'b0;
        end else if (!src_rcv && src_valid) begin
            src_hold <= src_data;
            src_send <= 1'b1;
        end
    end

    xpm_cdc_handshake #(
        .DEST_EXT_HSK  (0),      // no external ack; dest_req is self-clearing
        .DEST_SYNC_FF  (4),
        .INIT_SYNC_FF  (0),
        .SIM_ASSERT_CHK(0),
        .SRC_SYNC_FF   (4),
        .WIDTH         (WIDTH)
    ) inst_hs (
        .src_clk  (src_clk),
        .src_in   (src_hold),
        .src_send (src_send),
        .src_rcv  (src_rcv),
        .dest_clk (dest_clk),
        .dest_out (dest_data),
        .dest_req (dest_req),
        .dest_ack (1'b0)
    );

    // dest_req is documented as a single destination-clock pulse when
    // DEST_EXT_HSK is 0. Edge-detect anyway: a level would otherwise be counted
    // once per cycle by every caller, and the edge detector costs one flop.
    always_ff @(posedge dest_clk) dest_req_q <= dest_req;
    assign dest_valid = dest_req && !dest_req_q;

endmodule
