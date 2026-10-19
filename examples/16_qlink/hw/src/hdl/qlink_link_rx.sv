/**
 * QLINK protocol core — RX half
 *
 * Phase A: fixed-size 64 B frames per QLink v1.6 §3. The sink interface is
 * generic (type, flags, src, dst, epoch, round, 52 B payload) with class
 * demux left to whatever instantiates this. CRC-32 is checked against the
 * wire trailer; a mismatch retracts the delivered frame via rx_bad.
 *
 * ERROR POLICY — detect and flag, never retry. In real-time QEC a NACK
 * cannot arrive before the decode window closes, so there is no ARQ. A bad
 * frame is dropped and counted (R3); a missed round is detectable by the
 * round counter at the consumer (phase-B modular comparator).
 *
 * CUT-THROUGH: rx_valid is asserted on the LAST PAYLOAD WORD, before the
 * CRC trailer has arrived. rx_bad pulses one cycle later if that frame
 * turns out to be corrupt. The consuming decoder starts work on an
 * unvalidated frame and is told shortly afterward if it was wrong — the
 * right trade for real-time QEC, where a correction that arrives after the
 * decode window has closed is worthless.
 *
 * IF THE CONSUMING DECODER CANNOT RETRACT, wait for rx_bad to be known one
 * cycle after rx_valid before trusting the frame.
 *
 * PORTABILITY RULE: no Coyote types. Plain `logic` ports only.
 */

module qlink_link_rx (
    input  logic                  clk,
    input  logic                  rstn,
    input  logic                  link_up,
    input  logic                  clr,        // clears counters + round state

    // ---- generic sink side (consume on the application) ----
    output logic                  rx_valid,       // cut-through, 1-cycle pulse
    output logic                  rx_bad,         // 1 or 2 cycles after rx_valid: frame corrupt
    output logic [3:0]            rx_type,        // §4 class id
    output logic [3:0]            rx_flags,
    output logic [7:0]            rx_src,
    output logic [7:0]            rx_dst,
    output logic [7:0]            rx_epoch,
    output logic [31:0]           rx_round,
    output logic [415:0]          rx_payload,

    // ---- abstract PHY: 32-bit words, framed ----
    input  logic [31:0]           phy_rx_data,
    input  logic                  phy_rx_valid,
    input  logic                  phy_rx_eof,    // strobe AFTER the last word
    input  logic                  phy_rx_sof,
    input  logic [31:0]           phy_rx_hdr,    // §3 bytes 0..3
    input  logic [31:0]           phy_rx_cks,    // §3 bytes 60..63 (CRC-32)
    input  logic                  phy_rx_err,    // from the PHY; raw mode ties this low

    // ---- counters ----
    output logic [31:0]           rx_frames,
    output logic [31:0]           rx_errors
);

    // Must match the TX side. The framer parameterises PAYLOAD_WORDS; link_rx
    // uses it to know when the last payload word is on the wire.
    localparam int PAYLOAD_WORDS = 14;

    function automatic logic [31:0] crc32_byte(
        input logic [31:0] c_in, input logic [7:0] b
    );
        logic [31:0] c;
        c = c_in ^ {24'd0, b};
        for (int i = 0; i < 8; i++)
            c = (c >> 1) ^ (c[0] ? 32'hEDB88320 : 32'd0);
        return c;
    endfunction

    function automatic logic [31:0] crc32_word(
        input logic [31:0] c_in, input logic [31:0] w
    );
        logic [31:0] c;
        c = crc32_byte(c_in, w[7:0]);
        c = crc32_byte(c,    w[15:8]);
        c = crc32_byte(c,    w[23:16]);
        c = crc32_byte(c,    w[31:24]);
        return c;
    endfunction

    // §3 header unpacking — mirrors qlink_link_tx.pack_hdr. Keep symmetric.
    function automatic logic [3:0] unpack_type (input logic [31:0] h); return h[3:0];   endfunction
    function automatic logic [3:0] unpack_flags(input logic [31:0] h); return h[7:4];   endfunction
    function automatic logic [7:0] unpack_src  (input logic [31:0] h); return h[15:8];  endfunction
    function automatic logic [7:0] unpack_dst  (input logic [31:0] h); return h[23:16]; endfunction
    function automatic logic [7:0] unpack_epoch(input logic [31:0] h); return h[31:24]; endfunction

    typedef enum logic [1:0] { R_IDLE, R_PAY, R_TRAIL } rx_state_e;
    rx_state_e              rx_state;

    logic [31:0]            rx_hdr_lat;
    logic [31:0]            rx_round_lat;
    logic [415:0]           rx_buf;
    logic [7:0]             rx_idx;
    logic [31:0]            crc_run;
    logic                   rx_bad_pre;   // flagged mid-frame (phy_rx_err, etc.)

    // rx_buf as it will be AFTER this cycle's write. Cut-through must deliver
    // the full payload on the same cycle the final word arrives, and rx_buf
    // writes non-blocking, so the registered value is one word short.
    logic [415:0]           rx_buf_now;
    always_comb begin
        rx_buf_now = rx_buf;
        // idx-1 because payload_word(1) lands in rx_buf[31:0] etc.
        if (rx_idx >= 8'd1 && rx_idx <= PAYLOAD_WORDS[7:0] - 8'd1)
            rx_buf_now[(rx_idx-1)*32 +: 32] = phy_rx_data;
    end

    always_ff @(posedge clk) begin
        if (!rstn || clr) begin
            rx_state   <= R_IDLE;
            rx_valid   <= 1'b0;
            rx_bad     <= 1'b0;
            rx_bad_pre <= 1'b0;
            rx_type    <= '0;
            rx_flags   <= '0;
            rx_src     <= '0;
            rx_dst     <= '0;
            rx_epoch   <= '0;
            rx_round   <= '0;
            rx_payload <= '0;
            rx_hdr_lat <= '0;
            rx_round_lat <= '0;
            rx_buf     <= '0;
            rx_idx     <= '0;
            crc_run    <= '0;
            rx_frames  <= '0;
            rx_errors  <= '0;
        end else begin
            rx_valid <= 1'b0;
            rx_bad   <= 1'b0;

            // SOF: a mid-frame SOF means the previous frame was truncated —
            // the framer drops a broken frame without a trailer, so this is
            // where that gets counted.
            if (phy_rx_sof) begin
                if (rx_state != R_IDLE) rx_errors <= rx_errors + 32'd1;
                rx_hdr_lat <= phy_rx_hdr;
                rx_bad_pre <= phy_rx_err;
                rx_idx     <= 8'd0;
                // Prime the CRC with HDR; ROUND will be the first payload
                // word, folded in at R_PAY cycle 1.
                crc_run    <= crc32_word(32'hFFFFFFFF, phy_rx_hdr);
                rx_state   <= R_PAY;
            end else if (phy_rx_eof) begin
                if (rx_state != R_TRAIL) begin
                    rx_errors <= rx_errors + 32'd1;   // truncated
                end else begin
                    rx_frames <= rx_frames + 32'd1;
                    // Validate CRC. The trailer compares against the running
                    // CRC after the final XOR; a mismatch RETRACTS the frame
                    // delivered one cycle ago.
                    if (rx_bad_pre || phy_rx_err || (crc_run ^ 32'hFFFFFFFF) != phy_rx_cks) begin
                        rx_errors <= rx_errors + 32'd1;
                        rx_bad    <= 1'b1;
                    end
                end
                rx_state <= R_IDLE;
            end else if (phy_rx_valid && rx_state == R_PAY) begin
                if (phy_rx_err) rx_bad_pre <= 1'b1;

                // Fold this word into the CRC.
                crc_run <= crc32_word(crc_run, phy_rx_data);

                if (rx_idx == 8'd0) begin
                    // First payload word = ROUND (§3 bytes 4..7).
                    rx_round_lat <= phy_rx_data;
                end else begin
                    // Payload words land in rx_buf[(idx-1)*32 +: 32].
                    rx_buf[(rx_idx-1)*32 +: 32] <= phy_rx_data;
                end

                rx_idx <= rx_idx + 8'd1;

                if (rx_idx + 8'd1 == PAYLOAD_WORDS[7:0]) begin
                    // LAST payload word. Deliver cut-through; the trailer
                    // will either confirm or retract this on the next EOF.
                    rx_state   <= R_TRAIL;
                    rx_type    <= unpack_type (rx_hdr_lat);
                    rx_flags   <= unpack_flags(rx_hdr_lat);
                    rx_src     <= unpack_src  (rx_hdr_lat);
                    rx_dst     <= unpack_dst  (rx_hdr_lat);
                    rx_epoch   <= unpack_epoch(rx_hdr_lat);
                    rx_round   <= rx_round_lat;
                    rx_payload <= rx_buf_now;
                    rx_valid   <= 1'b1;
                end
            end
        end
    end

endmodule
