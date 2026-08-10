/**
 * BRAID protocol core — RX half
 *
 * Split out of braid_link so the TX and RX halves can run on different clocks.
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
 * Frame boundaries come from the PHY (phy_rx_last), so no sync word is needed
 * here -- the raw-GTY PHY derives it from the K-character SOF/EOF.
 */

module braid_link_rx #(
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

    // ---- correction return path ----
    output logic [N_CORR-1:0]     corr_out_bits,
    output logic                  corr_out_valid,

    // ---- abstract PHY: 32-bit words, framed ----
    input  logic [31:0]           phy_rx_data,
    input  logic                  phy_rx_valid,
    input  logic                  phy_rx_last,
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

    // Duplicated from braid_link_tx on purpose: the two halves must not depend
    // on each other, so either can be lifted into a different project alone.
    function automatic logic [31:0] cks_pack(input logic [15:0] a, input logic [15:0] b);
        return {b, a};
    endfunction

    typedef enum logic [1:0] { R_HDR, R_PAY, R_CKS, R_FLUSH } rx_state_e;
    rx_state_e                 rx_state;

    logic [MAX_WORDS*32-1:0]   rx_buf;
    logic [7:0]                rx_words, rx_idx;
    logic [3:0]                rx_type;
    logic [19:0]               rx_round, rx_round_prev;
    logic                      rx_round_seen;
    logic [15:0]               rx_cka, rx_ckb;
    logic [15:0]               rx_wraps;
    logic                      rx_bad;

    always_ff @(posedge clk) begin
        if (!rstn || clr) begin
            rx_state       <= R_HDR;
            syn_out_valid  <= 1'b0;
            syn_out_gap    <= 1'b0;
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
            rx_type        <= '0;
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

            if (phy_rx_valid) begin
                if (phy_rx_err) rx_bad <= 1'b1;

                case (rx_state)
                    R_HDR: begin
                        rx_type  <= phy_rx_data[31:28];
                        rx_words <= phy_rx_data[27:20];
                        rx_round <= phy_rx_data[19:0];
                        rx_cka   <= phy_rx_data[31:16] + phy_rx_data[15:0];
                        rx_ckb   <= phy_rx_data[31:16] + phy_rx_data[15:0];
                        rx_idx   <= '0;
                        rx_bad   <= phy_rx_err;
                        // A length that does not match this build means the two
                        // ends were compiled with different N_STAB. Catch it
                        // here rather than let it look like data corruption.
                        if (phy_rx_data[27:20] > MAX_WORDS[7:0]) rx_bad <= 1'b1;
                        if (phy_rx_last) begin           // header-only frame
                            rx_errors <= rx_errors + 32'd1;
                            rx_state  <= R_HDR;
                        end else begin
                            rx_state  <= R_PAY;
                        end
                    end

                    R_PAY: begin
                        // Indexed write, not a shift: the payload then always
                        // lands at a fixed base regardless of word count, so
                        // extraction below is a plain low-order slice.
                        rx_buf[rx_idx*32 +: 32] <= phy_rx_data;
                        rx_cka <= rx_cka + phy_rx_data[15:0] + phy_rx_data[31:16];
                        rx_ckb <= rx_ckb + rx_cka + phy_rx_data[15:0] + phy_rx_data[31:16];
                        rx_idx <= rx_idx + 8'd1;
                        if (rx_idx + 8'd1 == rx_words) rx_state <= R_CKS;
                        if (phy_rx_last) begin           // frame ended early
                            rx_errors <= rx_errors + 32'd1;
                            rx_state  <= R_HDR;
                        end
                    end

                    R_CKS: begin
                        rx_state  <= R_HDR;
                        rx_frames <= rx_frames + 32'd1;

                        if (rx_bad || phy_rx_err ||
                            phy_rx_data != cks_pack(rx_cka, rx_ckb)) begin
                            rx_errors <= rx_errors + 32'd1;
                        end else if (rx_type == TYPE_SYN) begin
                            syn_out_bits  <= rx_buf[N_STAB-1:0];
                            syn_out_valid <= 1'b1;

                            if (rx_round_seen && (rx_round != rx_round_prev + 20'd1)) begin
                                syn_out_gap <= 1'b1;
                                rx_gaps     <= rx_gaps + 32'd1;
                            end
                            if (rx_round_seen && (rx_round < rx_round_prev))
                                rx_wraps <= rx_wraps + 16'd1;

                            rx_round_prev <= rx_round;
                            rx_round_seen <= 1'b1;
                            syn_out_round <= {rx_wraps[11:0], rx_round};
                        end else if (rx_type == TYPE_CORR) begin
                            corr_out_bits  <= rx_buf[N_CORR-1:0];
                            corr_out_valid <= 1'b1;
                        end else begin
                            rx_errors <= rx_errors + 32'd1;   // unknown type
                        end
                    end

                    default: rx_state <= R_HDR;
                endcase
            end
        end
    end

endmodule
