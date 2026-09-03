/**
 * QLINK protocol core — RX half
 *
 * Split out of qlink_link so the TX and RX halves can run on different clocks.
 * Once the RX elastic buffer is bypassed, RX fabric must run on the RECOVERED
 * clock while TX runs on the local one. The two FSMs never shared state.
 *
 * PORTABILITY RULE: no Coyote types. No AXI4S, no lynx_pkg, no axi_ctrl -- plain
 * `logic` ports only. This file is meant to be copied verbatim into a bare
 * Vivado project on an RFSoC. Everything shell-specific belongs outside.
 *
 * ERROR POLICY -- detect and flag, never retry. In real-time QEC a NACK cannot
 * possibly arrive before the decode window closes, so there is no ARQ. A bad
 * frame is dropped and counted; a missed round is reported via syn_out_gap, so
 * the decoder knows exactly what it lost and can degrade deliberately. Silently
 * delivering a corrupted syndrome would produce a confidently wrong correction,
 * which is strictly worse than a flagged gap.
 *
 * Frame boundaries and the header come from the PHY (phy_rx_sof / phy_rx_eof),
 * so this module consumes payload words and nothing else
 * here -- the raw-GTY PHY derives it from the K-character SOF/EOF.
 */

module qlink_link_rx #(
    parameter int N_STAB = 120,     // stabilizer bits per round
    parameter int N_CORR = 64       // correction bits returned
) (
    input  logic                  clk,
    input  logic                  rstn,
    input  logic                  link_up,
    // Clears counters AND the round-tracking state. Without this the counters
    // are cumulative across runs, and rx_round_prev survives -- so a sender
    // restarting at round 0 looks like a gap and fails an otherwise clean run.
    input  logic                  clr,

    // ---- syndrome sink side (consume these on the decoder) ----
    output logic [N_STAB-1:0]     syn_out_bits,
    output logic                  syn_out_valid,
    output logic [31:0]           syn_out_round,
    output logic                  syn_out_gap,   // a round went missing
    // CUT 4 (cut-through): syn_out_valid is asserted on the LAST PAYLOAD WORD,
    // before the checksum has arrived. syn_out_bad pulses one or two cycles
    // later if that syndrome turns out to be corrupt.
    //
    // This is a design decision, not an optimisation. The decoder starts on a
    // syndrome that has not been validated and is told shortly afterwards if it
    // was wrong. For real-time QEC that is the right trade -- a correction that
    // arrives after the decode window has closed is worthless, so starting
    // early and retracting beats waiting and being certain. It is the same
    // reasoning that already makes this link drop-and-flag rather than retry.
    //
    // IF THE CONSUMING DECODER CANNOT RETRACT, DO NOT USE syn_out_valid ALONE.
    // Wait for syn_out_bad to be known, one cycle after syn_out_valid.
    output logic                  syn_out_bad,
    // Set when the delivered payload is a list of positions rather than a dense
    // bitmap. Passed through from the frame's marker; this module never looks
    // inside the payload.
    output logic                  syn_out_sparse,

    // ---- correction return path ----
    output logic [N_CORR-1:0]     corr_out_bits,
    output logic                  corr_out_valid,

    // ---- abstract PHY: 32-bit words, framed ----
    input  logic [31:0]           phy_rx_data,
    input  logic                  phy_rx_valid,
    input  logic                  phy_rx_eof,    // strobe AFTER the last word
    // Frame delimiters carry the header and checksum, so there is no header
    // word and no checksum word to consume. See qlink_framer.
    input  logic                  phy_rx_sof,
    input  logic [23:0]           phy_rx_hdr,    // {round[15:0], n_words[7:0]}
    input  logic [1:0]            phy_rx_type,
    input  logic [23:0]           phy_rx_cks,
    input  logic                  phy_rx_err,    // 8B/10B error flag

    // ---- counters ----
    output logic [31:0]           rx_frames,
    output logic [31:0]           rx_errors,
    output logic [31:0]           rx_gaps
);

    localparam int SYN_WORDS  = (N_STAB + 31) / 32;
    localparam int CORR_WORDS = (N_CORR + 31) / 32;
    localparam int MAX_WORDS  = (SYN_WORDS > CORR_WORDS) ? SYN_WORDS : CORR_WORDS;

    localparam logic [3:0] TYPE_SYN  = 4'h1;
    localparam logic [3:0] TYPE_CORR = 4'h2;

    // The checksum packing is duplicated from qlink_link_tx on purpose: the two
    // halves must not depend on each other, so either can be lifted into a
    // different project alone. It lives at rx_cks_calc below.

    typedef enum logic [1:0] { R_IDLE, R_PAY, R_TRAIL } rx_state_e;
    rx_state_e                 rx_state;

    logic [MAX_WORDS*32-1:0]   rx_buf;
    logic [7:0]                rx_words, rx_idx;
    logic [1:0]                rx_type;
    logic [15:0]               rx_round, rx_round_prev;
    logic                      rx_round_seen;
    logic [15:0]               rx_cka, rx_ckb;
    logic [15:0]               rx_wraps;
    logic                      rx_bad;

    // rx_buf as it will be AFTER this cycle's write. Cut-through has to deliver
    // the payload on the same cycle the final word arrives, and rx_buf is
    // written non-blocking, so the registered value is one word short.
    logic [MAX_WORDS*32-1:0]   rx_buf_now;
    always_comb begin
        rx_buf_now = rx_buf;
        rx_buf_now[rx_idx*32 +: 32] = phy_rx_data;
    end

    wire rx_gap_now = rx_round_seen && (rx_round != rx_round_prev + 16'd1);
    wire [23:0] rx_cks_calc = {rx_ckb[11:0], rx_cka[11:0]};

    always_ff @(posedge clk) begin
        if (!rstn || clr) begin
            rx_state       <= R_IDLE;
            syn_out_valid  <= 1'b0;
            syn_out_gap    <= 1'b0;
            syn_out_bad    <= 1'b0;
            corr_out_valid <= 1'b0;
            rx_frames      <= '0;
            rx_errors      <= '0;
            rx_gaps        <= '0;
            rx_round_seen  <= 1'b0;
            rx_wraps       <= '0;
            rx_bad         <= 1'b0;
            rx_buf         <= '0;
            rx_idx         <= '0;
            rx_words       <= '0;
            rx_type        <= 2'd0;
            syn_out_sparse <= 1'b0;
            rx_round       <= '0;
            rx_round_prev  <= '0;
            rx_cka         <= '0;
            rx_ckb         <= '0;
            syn_out_bits   <= '0;
            corr_out_bits  <= '0;
            syn_out_round  <= '0;
        end else begin
            syn_out_valid  <= 1'b0;
            corr_out_valid <= 1'b0;
            syn_out_gap    <= 1'b0;
            syn_out_bad    <= 1'b0;

            // A marker anywhere restarts the frame. Arriving mid-frame means the
            // previous one was truncated -- the framer drops a broken frame
            // without a trailer, so this is where that gets counted.
            if (phy_rx_sof) begin
                if (rx_state != R_IDLE) rx_errors <= rx_errors + 32'd1;
                rx_words <= phy_rx_hdr[7:0];
                rx_round <= phy_rx_hdr[23:8];
                rx_type  <= phy_rx_type;
                rx_idx   <= '0;
                rx_cka   <= '0;
                rx_ckb   <= '0;
                // A length that does not match this build means the two ends
                // were compiled with different N_STAB. Catch it here rather
                // than let it look like data corruption.
                rx_bad   <= phy_rx_err || (phy_rx_hdr[7:0] > MAX_WORDS[7:0])
                                       || (phy_rx_hdr[7:0] == 8'd0);
                rx_state <= R_PAY;
            end else if (phy_rx_eof) begin
                if (rx_state != R_TRAIL) begin
                    rx_errors <= rx_errors + 32'd1;   // truncated
                end else begin
                    rx_frames <= rx_frames + 32'd1;
                    if (rx_bad || phy_rx_err || phy_rx_cks != rx_cks_calc) begin
                        rx_errors   <= rx_errors + 32'd1;
                        // Retract: the syndrome delivered a cycle ago was
                        // corrupt. rx_round_prev is deliberately NOT advanced,
                        // so the next good frame reports the gap.
                        syn_out_bad <= 1'b1;
                    end else if (rx_type != 2'd1) begin
                        if (rx_gap_now) rx_gaps <= rx_gaps + 32'd1;
                        if (rx_round < rx_round_prev) rx_wraps <= rx_wraps + 16'd1;
                        rx_round_prev <= rx_round;
                        rx_round_seen <= 1'b1;
                    end
                end
                rx_state <= R_IDLE;
            end else if (phy_rx_valid && rx_state == R_PAY) begin
                if (phy_rx_err) rx_bad <= 1'b1;
                // Indexed write, not a shift: the payload then always lands at
                // a fixed base regardless of word count, so extraction below is
                // a plain low-order slice.
                rx_buf[rx_idx*32 +: 32] <= phy_rx_data;
                rx_cka <= rx_cka + phy_rx_data[15:0] + phy_rx_data[31:16];
                rx_ckb <= rx_ckb + rx_cka + phy_rx_data[15:0] + phy_rx_data[31:16];
                rx_idx <= rx_idx + 8'd1;

                if (rx_idx + 8'd1 == rx_words) begin
                    rx_state <= R_TRAIL;
                    // CUT-THROUGH: deliver NOW, validate when the trailer lands.
                    if (rx_type != 2'd1) begin
                        syn_out_bits   <= rx_buf_now[N_STAB-1:0];
                        syn_out_sparse <= (rx_type == 2'd2);
                        syn_out_valid <= 1'b1;
                        syn_out_round <= {rx_wraps, rx_round};
                        syn_out_gap   <= rx_gap_now;
                    end else begin
                        corr_out_bits  <= rx_buf_now[N_CORR-1:0];
                        corr_out_valid <= 1'b1;
                    end
                end
            end
        end
    end

endmodule
