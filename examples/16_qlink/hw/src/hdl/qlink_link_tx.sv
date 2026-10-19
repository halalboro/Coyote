/**
 * QLINK protocol core — TX half
 *
 * Phase A: fixed-size 64 B frames per QLink v1.6 §3. The old syndrome-shaped
 * `syn_bits[N_STAB-1:0]` input is gone; this core now takes a generic
 * (type, flags, src, dst, epoch, round, 52 B payload) tuple per frame and
 * leaves semantic interpretation to the vFPGA-side generator above it.
 *
 * WIRE FRAME (16 cycles, 64 B):
 *     cycle 1          HDR         (§3 bytes 0..3)                 — framer T_IDLE
 *     cycle 2          ROUND       (§3 bytes 4..7)                 — framer T_DATA
 *     cycle 3..15      PAYLOAD     (§3 bytes 8..59, 13 words)      — framer T_DATA
 *     cycle 16         CRC-32      (§3 bytes 60..63)               — framer T_EOF
 *
 * TIMING TRAP WORTH NAMING. The framer sits in T_IDLE during cycle 1 and
 * transitions to T_DATA at end of cycle 1. So phy_tx_ready is LOW during
 * cycle 1 and tx_go=0 at the posedge of cycle 2 — link_tx must NOT advance
 * phy_tx_data on that cycle, or payload_word(0)=ROUND is overwritten before
 * the framer ever consumes it. The tx_go gate handles this already, but it
 * is also the reason the fold schedule below starts both HDR and ROUND into
 * the running CRC at T_IDLE firing (not just HDR): there is no fold cycle
 * for ROUND in T_PAY because the stall at cycle 2 skips it.
 *
 * PORTABILITY RULE: no Coyote types. No AXI4S, no lynx_pkg, no axi_ctrl —
 * plain `logic` ports only. This file is meant to be copied verbatim into a
 * bare Vivado project on an RFSoC.
 *
 * BACKPRESSURE RULE (R2): a frame offered while the link is busy mid-frame or
 * down is DROPPED and counted, never queued. Queueing on the deadline path
 * turns a one-round latency miss into unbounded backlog.
 */

module qlink_link_tx (
    input  logic                  clk,
    input  logic                  rstn,
    input  logic                  link_up,
    input  logic                  clr,        // clears counters

    // ---- application side: one pulse = one 64 B frame ----
    input  logic [3:0]            tx_type,    // §4: SYN=1, FRM=2, FUS=3, CTL=4
    input  logic [3:0]            tx_flags,   // §3: erasure, truncated, last-of-group, reserved
    input  logic [7:0]            tx_src,
    input  logic [7:0]            tx_dst,
    input  logic [7:0]            tx_epoch,
    input  logic [31:0]           tx_round,
    input  logic [415:0]          tx_payload, // 52 B
    input  logic                  tx_valid,

    // ---- abstract PHY: 32-bit words, framed ----
    output logic [31:0]           phy_tx_data,
    output logic                  phy_tx_valid,
    output logic                  phy_tx_last,
    input  logic                  phy_tx_ready,
    output logic [31:0]           phy_tx_hdr,
    output logic [31:0]           phy_tx_cks,

    // ---- counters ----
    output logic [31:0]           tx_frames,
    output logic [31:0]           tx_dropped
);

    // §3 header packing. Byte 0 = {FLAGS[3:0], TYPE[3:0]} with TYPE in the LOW
    // nibble; little-endian byte-to-wire. Open-item #3 may freeze a different
    // layout later; the §4 class demux at RX uses the same packing, so changes
    // must stay symmetric with qlink_link_rx.
    function automatic logic [31:0] pack_hdr(
        input logic [3:0] t, input logic [3:0] f,
        input logic [7:0] s, input logic [7:0] d, input logic [7:0] e
    );
        return {e, d, s, f, t};
    endfunction

    // CRC-32/IEEE 802.3, reflected input/output, poly 0xEDB88320, init
    // 0xFFFFFFFF, final XOR 0xFFFFFFFF. Written as the straightforward
    // bit-serial algorithm; synthesis flattens the loop to a parallel XOR
    // network ~5 LUT levels deep per word, which closes at 390.625 MHz.
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

    // 14 payload words = 1 ROUND + 13 PAYLOAD words (56 bytes between HDR and
    // CRC trailer). Must match the framer's PAYLOAD_WORDS parameter.
    localparam int PAYLOAD_WORDS = 14;

    typedef enum logic [0:0] { T_IDLE, T_PAY } tx_state_e;
    tx_state_e              tx_state;

    logic [31:0]            lat_hdr, lat_round;
    logic [415:0]           lat_payload;
    logic [7:0]             tx_idx;
    logic [31:0]            crc_run;
    logic [31:0]            cks_hold;

    wire tx_go = phy_tx_ready || !phy_tx_valid;

    // Which word gets written to phy_tx_data at this cycle's posedge:
    //    tx_idx == 1 → ROUND, tx_idx == 2..13 → payload[31:0]..[415:384].
    // At T_IDLE firing we write ROUND directly (not via this function), so
    // tx_idx == 0 is unreachable in T_PAY.
    function automatic logic [31:0] payload_word(
        input logic [31:0]  rnd,
        input logic [415:0] p,
        input logic [7:0]   idx
    );
        case (idx)
            8'd0:    payload_word = rnd;        // never read in T_PAY (T_IDLE handles ROUND)
            8'd1:    payload_word = p[31:0];
            8'd2:    payload_word = p[63:32];
            8'd3:    payload_word = p[95:64];
            8'd4:    payload_word = p[127:96];
            8'd5:    payload_word = p[159:128];
            8'd6:    payload_word = p[191:160];
            8'd7:    payload_word = p[223:192];
            8'd8:    payload_word = p[255:224];
            8'd9:    payload_word = p[287:256];
            8'd10:   payload_word = p[319:288];
            8'd11:   payload_word = p[351:320];
            8'd12:   payload_word = p[383:352];
            8'd13:   payload_word = p[415:384];
            default: payload_word = 32'h0;
        endcase
    endfunction

    assign phy_tx_hdr = lat_hdr;
    assign phy_tx_cks = cks_hold;

    always_ff @(posedge clk) begin
        if (!rstn || clr) begin
            tx_state     <= T_IDLE;
            phy_tx_valid <= 1'b0;
            phy_tx_last  <= 1'b0;
            phy_tx_data  <= '0;
            lat_hdr      <= '0;
            lat_round    <= '0;
            lat_payload  <= '0;
            tx_idx       <= '0;
            crc_run      <= '0;
            cks_hold     <= '0;
            tx_frames    <= '0;
            tx_dropped   <= '0;
        end else begin
            // Deassert valid/last when the framer has consumed the previous
            // word. The gate matters: clearing phy_tx_last unconditionally
            // breaks single-word frames, where last is asserted the same cycle
            // the framer is still mid-handshake on the data.
            if (tx_go) begin
                phy_tx_valid <= 1'b0;
                phy_tx_last  <= 1'b0;
            end

            case (tx_state)
                T_IDLE: begin
                    if (link_up && tx_valid && tx_go) begin
                        // Latch the whole frame so application signals can
                        // move on this cycle.
                        logic [31:0] hdr_w;
                        hdr_w = pack_hdr(tx_type, tx_flags, tx_src, tx_dst, tx_epoch);

                        lat_hdr     <= hdr_w;
                        lat_round   <= tx_round;
                        lat_payload <= tx_payload;

                        // The framer puts HDR on the wire during the FOLLOWING
                        // cycle (it transitions T_IDLE → T_DATA at the end of
                        // this cycle), then ROUND the cycle after that from
                        // phy_tx_data. phy_tx_ready stays low across those two
                        // cycles — see the timing-trap note at the top — so
                        // this is the ONLY place to fold ROUND into the CRC;
                        // T_PAY will start its own folds at payload_word(1).
                        crc_run <= crc32_word(crc32_word(32'hFFFFFFFF, hdr_w), tx_round);

                        // phy_tx_data must hold ROUND through the stall at
                        // cycle 2. T_PAY only advances it from cycle 3 onward.
                        phy_tx_data  <= tx_round;
                        phy_tx_valid <= 1'b1;
                        phy_tx_last  <= 1'b0;
                        tx_idx       <= 8'd1;
                        tx_state     <= T_PAY;
                    end else if (tx_valid) begin
                        // Link down or framer busy: R2, drop and count.
                        tx_dropped <= tx_dropped + 32'd1;
                    end
                end

                T_PAY: if (tx_go) begin
                    // At this cycle's posedge, tx_idx is the index of the
                    // word being written to phy_tx_data. It will appear on
                    // the wire NEXT cycle. So the CRC should fold it in now.
                    //
                    // Why fold tx_idx (not tx_idx-1): there is exactly one
                    // T_PAY fold per payload word, starting at payload_word(1)
                    // and ending at payload_word(13). The ROUND word was
                    // already folded at T_IDLE firing because the framer
                    // stall at cycle 2 denies T_PAY a fold cycle for it.
                    phy_tx_data  <= payload_word(lat_round, lat_payload, tx_idx);
                    phy_tx_valid <= 1'b1;
                    tx_idx       <= tx_idx + 8'd1;

                    if (tx_idx == PAYLOAD_WORDS[7:0] - 8'd1) begin
                        // Last payload word being written. Fold it into the
                        // running CRC in-line and latch the trailer. Not fed
                        // through crc_run because tx_state → T_IDLE this
                        // cycle; no more fold opportunities.
                        cks_hold    <= crc32_word(crc_run,
                                                   payload_word(lat_round, lat_payload, tx_idx))
                                       ^ 32'hFFFFFFFF;
                        phy_tx_last <= 1'b1;
                        tx_frames   <= tx_frames + 32'd1;
                        tx_state    <= T_IDLE;
                    end else begin
                        crc_run <= crc32_word(crc_run,
                                               payload_word(lat_round, lat_payload, tx_idx));
                    end
                end

                default: tx_state <= T_IDLE;
            endcase

            // A second request mid-frame cannot be serviced.
            if (tx_state != T_IDLE && tx_valid) tx_dropped <= tx_dropped + 32'd1;
        end
    end

endmodule
