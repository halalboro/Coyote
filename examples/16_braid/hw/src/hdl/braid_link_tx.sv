/**
 * BRAID protocol core — TX half
 *
 * Split out of braid_link so the TX and RX halves can run on different clocks.
 * That is required once the RX elastic buffer is bypassed: RX fabric must run on
 * the recovered clock while TX runs on the local one. The two FSMs never shared
 * state, so the split is mechanical.
 *
 * PORTABILITY RULE: no Coyote types. No AXI4S, no lynx_pkg, no axi_ctrl -- plain
 * `logic` ports only. This file is meant to be copied verbatim into a bare
 * Vivado project on an RFSoC. Everything shell-specific belongs outside.
 *
 * Frame layout (32-bit words):
 *   w0        header    {type[3:0], n_words[7:0], round[19:0]}
 *   w1..wN    payload   dense bitmap
 *   wN+1      checksum  {ck_b[15:0], ck_a[15:0]}, Fletcher-style
 *
 * Syndromes take priority over corrections: syndromes are on the critical path,
 * corrections are not. A round offered while the link is busy is DROPPED and
 * counted, never queued -- a queued syndrome is a stale syndrome, and a backlog
 * in a real-time decoder is worse than a gap.
 */

module braid_link_tx #(
    parameter int N_STAB = 120,     // stabilizer bits per round
    parameter int N_CORR = 64       // correction bits returned
) (
    input  logic                  clk,
    input  logic                  rstn,
    input  logic                  link_up,
    input  logic                  clr,        // clears counters

    // ---- syndrome source side ----
    input  logic [N_STAB-1:0]     syn_bits,
    input  logic                  syn_valid,  // one pulse per round
    // The round number comes from the syndrome source, not from a counter here.
    // An internal counter would drift the moment a round is dropped, permanently
    // desynchronising the receiver's expectations from the sender's.
    input  logic [19:0]           syn_round,
    // Payload words per syndrome frame; 0 selects the full N_STAB width. The
    // receiver takes the length from the frame header, so it needs no knowledge.
    input  logic [7:0]            syn_words_sel,

    // ---- correction return path ----
    input  logic [N_CORR-1:0]     corr_bits,
    input  logic                  corr_valid,

    // ---- abstract PHY: 32-bit words, framed ----
    output logic [31:0]           phy_tx_data,
    output logic                  phy_tx_valid,
    output logic                  phy_tx_last,
    input  logic                  phy_tx_ready,

    // ---- counters ----
    output logic [31:0]           tx_frames,
    output logic [31:0]           tx_dropped
);

    localparam int SYN_WORDS  = (N_STAB + 31) / 32;
    localparam int CORR_WORDS = (N_CORR + 31) / 32;
    localparam int MAX_WORDS  = (SYN_WORDS > CORR_WORDS) ? SYN_WORDS : CORR_WORDS;

    localparam logic [3:0] TYPE_SYN  = 4'h1;
    localparam logic [3:0] TYPE_CORR = 4'h2;

    // Fletcher-style rather than CRC: a 32-bit-wide CRC unrolls to ~32 levels of
    // XOR and will not close timing at the GT word rate. Two adders are shallow
    // and still catch reordering and most bit errors. Strong single-bit
    // protection comes from the PHY's 8B/10B disparity and not-in-table flags.
    function automatic logic [31:0] cks_pack(input logic [15:0] a, input logic [15:0] b);
        return {b, a};
    endfunction

    typedef enum logic [1:0] { T_IDLE, T_HDR, T_PAY, T_CKS } tx_state_e;
    tx_state_e                 tx_state;

    logic [MAX_WORDS*32-1:0]   tx_shift;
    logic [7:0]                tx_words, tx_idx;
    logic [3:0]                tx_type;
    logic [19:0]               tx_round;
    logic [15:0]               tx_cka, tx_ckb;

    wire tx_go = phy_tx_ready || !phy_tx_valid;

    always_ff @(posedge clk) begin
        if (!rstn || clr) begin
            tx_state     <= T_IDLE;
            phy_tx_valid <= 1'b0;
            phy_tx_last  <= 1'b0;
            phy_tx_data  <= '0;
            tx_round     <= '0;
            tx_frames    <= '0;
            tx_dropped   <= '0;
            tx_cka       <= '0;
            tx_ckb       <= '0;
            tx_idx       <= '0;
            tx_words     <= '0;
            tx_type      <= '0;
            tx_shift     <= '0;
        end else begin
            if (tx_go) phy_tx_valid <= 1'b0;
            phy_tx_last <= 1'b0;

            case (tx_state)
                T_IDLE: begin
                    if (link_up && syn_valid) begin
                        tx_type  <= TYPE_SYN;
                        tx_words <= (syn_words_sel == 8'd0) ? SYN_WORDS[7:0]
                                  : ((syn_words_sel > MAX_WORDS[7:0]) ? MAX_WORDS[7:0]
                                                                      : syn_words_sel);
                        tx_shift <= {{(MAX_WORDS*32 - N_STAB){1'b0}}, syn_bits};
                        tx_round <= syn_round;
                        tx_state <= T_HDR;
                    end else if (link_up && corr_valid) begin
                        tx_type  <= TYPE_CORR;
                        tx_words <= CORR_WORDS[7:0];
                        tx_shift <= {{(MAX_WORDS*32 - N_CORR){1'b0}}, corr_bits};
                        tx_round <= syn_round;   // a correction answers this round
                        tx_state <= T_HDR;
                    end else if (syn_valid || corr_valid) begin
                        tx_dropped <= tx_dropped + 32'd1;   // link down
                    end
                end

                T_HDR: if (tx_go) begin
                    phy_tx_data  <= {tx_type, tx_words, tx_round};
                    phy_tx_valid <= 1'b1;
                    // Seed over BOTH header halves so the round number is
                    // covered too, not just the type/length field.
                    tx_cka       <= {tx_type, tx_words, tx_round[19:16]} + tx_round[15:0];
                    tx_ckb       <= {tx_type, tx_words, tx_round[19:16]} + tx_round[15:0];
                    tx_idx       <= '0;
                    tx_state     <= T_PAY;
                end

                T_PAY: if (tx_go) begin
                    phy_tx_data  <= tx_shift[31:0];
                    phy_tx_valid <= 1'b1;
                    tx_shift     <= tx_shift >> 32;
                    tx_cka       <= tx_cka + tx_shift[15:0]  + tx_shift[31:16];
                    tx_ckb       <= tx_ckb + tx_cka + tx_shift[15:0] + tx_shift[31:16];
                    tx_idx       <= tx_idx + 8'd1;
                    if (tx_idx + 8'd1 == tx_words) tx_state <= T_CKS;
                end

                T_CKS: if (tx_go) begin
                    phy_tx_data  <= cks_pack(tx_cka, tx_ckb);
                    phy_tx_valid <= 1'b1;
                    phy_tx_last  <= 1'b1;
                    tx_frames    <= tx_frames + 32'd1;
                    tx_state     <= T_IDLE;
                end

                default: tx_state <= T_IDLE;
            endcase

            // A round offered while the link is mid-frame cannot be sent.
            if (tx_state != T_IDLE && syn_valid) tx_dropped <= tx_dropped + 32'd1;
        end
    end

endmodule
