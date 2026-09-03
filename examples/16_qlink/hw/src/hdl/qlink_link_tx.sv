/**
 * QLINK protocol core — TX half
 *
 * Split out of qlink_link so the TX and RX halves can run on different clocks.
 * That is required once the RX elastic buffer is bypassed: RX fabric must run on
 * the recovered clock while TX runs on the local one. The two FSMs never shared
 * state, so the split is mechanical.
 *
 * PORTABILITY RULE: no Coyote types. No AXI4S, no lynx_pkg, no axi_ctrl -- plain
 * `logic` ports only. This file is meant to be copied verbatim into a bare
 * Vivado project on an RFSoC. Everything shell-specific belongs outside.
 *
 * Frame layout (32-bit words) -- STREAMING, no header or checksum word:
 *   w0..wN-1  payload   dense bitmap, nothing else
 *
 * The header and the checksum ride in the framer's marker and trailer words,
 * which each carry one K-character and three otherwise-wasted data bytes. This
 * module emits ONLY payload; qlink_framer inserts the delimiters around it.
 * That is worth a cycle of latency and two words of every frame.
 *
 * Syndromes take priority over corrections: syndromes are on the critical path,
 * corrections are not. A round offered while the link is busy is DROPPED and
 * counted, never queued -- a queued syndrome is a stale syndrome, and a backlog
 * in a real-time decoder is worse than a gap.
 */

module qlink_link_tx #(
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
    // 16 bits, not 20: the round rides in the marker word's spare bytes
    // alongside an 8-bit length, and 8+16 is the 24 bits a control word has
    // free. It wraps every 65536 rounds -- 65 ms at a 1 us cadence -- and the
    // receiver extends it with a wrap counter.
    input  logic [15:0]           syn_round,
    // Payload words per syndrome frame; 0 selects the full N_STAB width. The
    // receiver takes the length from the frame header, so it needs no knowledge.
    input  logic [7:0]            syn_words_sel,
    // Marks the payload as a list of fired stabilizer positions rather than a
    // dense bitmap. This module does NOT interpret either -- it sends
    // syn_words_sel words of syn_bits and the flag rides along so the decoder
    // knows what it is looking at. Sparse is cheaper only because the source
    // asks for fewer words.
    input  logic                  syn_sparse,

    // ---- correction return path ----
    input  logic [N_CORR-1:0]     corr_bits,
    input  logic                  corr_valid,

    // ---- abstract PHY: 32-bit words, framed ----
    output logic [31:0]           phy_tx_data,
    output logic                  phy_tx_valid,
    output logic                  phy_tx_last,
    input  logic                  phy_tx_ready,
    // Sidebands the framer folds into the delimiters. hdr is stable for the
    // whole frame; cks is only read on the cycle after the last payload word.
    output logic [23:0]           phy_tx_hdr,
    output logic [23:0]           phy_tx_cks,
    output logic [1:0]            phy_tx_type,

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
    // The packing now lives at phy_tx_cks, since the value goes out in the
    // framer's trailer rather than in a word of its own.

    typedef enum logic [0:0] { T_IDLE, T_PAY } tx_state_e;
    tx_state_e                 tx_state;

    logic [MAX_WORDS*32-1:0]   tx_shift;
    logic [7:0]                tx_words, tx_idx;
    logic [15:0]               tx_cka, tx_ckb;

    wire tx_go = phy_tx_ready || !phy_tx_valid;

    // Payload length, resolved combinationally so the first payload word and the
    // header sideband can both be presented on the syn_valid cycle.
    wire [7:0] words_c = (syn_words_sel == 8'd0) ? SYN_WORDS[7:0]
                       : ((syn_words_sel > MAX_WORDS[7:0]) ? MAX_WORDS[7:0]
                                                           : syn_words_sel);

    // Twelve bits of each running sum rather than sixteen: narrower than the old
    // 32-bit field, but the PHY's 8B/10B disparity and not-in-table flags already
    // catch single-bit errors, and what this is really for is detecting
    // reordering and truncation.
    //
    // LATCHED, not driven combinationally from tx_cka/tx_ckb. The framer reads
    // this one cycle AFTER this FSM has returned to T_IDLE, so a round arriving
    // on that cycle would overwrite the running sums before the trailer went
    // out -- sending the previous frame with the NEXT frame's partial checksum,
    // which the receiver correctly reports as a corrupt frame that was never
    // actually corrupt. Only reachable with back-to-back frames, which is why
    // nothing caught it until the FSM was read rather than simulated.
    logic [23:0] cks_hold;
    assign phy_tx_cks = cks_hold;

    // The sums as they will be after this cycle's word, so the last word can
    // latch the final value in the same cycle it is issued.
    wire [15:0] cka_nxt = tx_cka + tx_shift[15:0] + tx_shift[31:16];
    wire [15:0] ckb_nxt = tx_ckb + tx_cka + tx_shift[15:0] + tx_shift[31:16];
    wire [15:0] cka_syn0 = syn_bits[15:0]  + syn_bits[31:16];
    wire [15:0] cka_cor0 = corr_bits[15:0] + corr_bits[31:16];

    always_ff @(posedge clk) begin
        if (!rstn || clr) begin
            tx_state     <= T_IDLE;
            phy_tx_valid <= 1'b0;
            phy_tx_last  <= 1'b0;
            phy_tx_data  <= '0;
            phy_tx_hdr   <= '0;
            phy_tx_type  <= 2'd0;
            tx_frames    <= '0;
            tx_dropped   <= '0;
            tx_cka       <= '0;
            tx_ckb       <= '0;
            tx_idx       <= '0;
            tx_words     <= '0;
            tx_shift     <= '0;
            cks_hold     <= '0;
        end else begin
            // last must be held for exactly as long as valid is. Clearing it
            // unconditionally works only while the last word is issued from a
            // state where the framer is already ready -- which stopped being
            // true when the first payload word moved into T_IDLE. The framer
            // then consumes the word with last already low, never emits a
            // trailer, and sits in T_DATA forever: the link dies silently after
            // exactly one frame.
            if (tx_go) begin
                phy_tx_valid <= 1'b0;
                phy_tx_last  <= 1'b0;
            end

            case (tx_state)
                // The FIRST PAYLOAD WORD goes out here, together with the header
                // sideband. There is no header word to emit first.
                T_IDLE: begin
                    if (link_up && syn_valid && tx_go) begin
                        phy_tx_hdr   <= {syn_round, words_c};
                        phy_tx_type  <= syn_sparse ? 2'd2 : 2'd0;
                        phy_tx_data  <= syn_bits[31:0];
                        phy_tx_valid <= 1'b1;
                        phy_tx_last  <= (words_c == 8'd1);
                        tx_words     <= words_c;
                        tx_shift     <= {{(MAX_WORDS*32 - N_STAB){1'b0}}, syn_bits} >> 32;
                        tx_cka       <= cka_syn0;
                        tx_ckb       <= cka_syn0;
                        tx_idx       <= 8'd1;
                        // Single-word frame: this IS the last word, so the
                        // trailer value is final already.
                        if (words_c == 8'd1) cks_hold <= {cka_syn0[11:0], cka_syn0[11:0]};
                        if (words_c == 8'd1) begin
                            tx_frames <= tx_frames + 32'd1;
                            tx_state  <= T_IDLE;
                        end else begin
                            tx_state  <= T_PAY;
                        end
                    end else if (link_up && corr_valid && tx_go) begin
                        phy_tx_hdr   <= {syn_round, CORR_WORDS[7:0]};
                        phy_tx_type  <= 2'd1;
                        phy_tx_data  <= corr_bits[31:0];
                        phy_tx_valid <= 1'b1;
                        phy_tx_last  <= (CORR_WORDS == 1);
                        tx_words     <= CORR_WORDS[7:0];
                        tx_shift     <= {{(MAX_WORDS*32 - N_CORR){1'b0}}, corr_bits} >> 32;
                        tx_cka       <= cka_cor0;
                        tx_ckb       <= cka_cor0;
                        tx_idx       <= 8'd1;
                        if (CORR_WORDS == 1) cks_hold <= {cka_cor0[11:0], cka_cor0[11:0]};
                        tx_state     <= (CORR_WORDS == 1) ? T_IDLE : T_PAY;
                        if (CORR_WORDS == 1) tx_frames <= tx_frames + 32'd1;
                    end else if (syn_valid || corr_valid) begin
                        tx_dropped <= tx_dropped + 32'd1;   // link down, or busy
                    end
                end

                T_PAY: if (tx_go) begin
                    phy_tx_data  <= tx_shift[31:0];
                    phy_tx_valid <= 1'b1;
                    tx_shift     <= tx_shift >> 32;
                    tx_cka       <= cka_nxt;
                    tx_ckb       <= ckb_nxt;
                    tx_idx       <= tx_idx + 8'd1;
                    if (tx_idx + 8'd1 == tx_words) begin
                        cks_hold    <= {ckb_nxt[11:0], cka_nxt[11:0]};
                        phy_tx_last <= 1'b1;
                        tx_frames   <= tx_frames + 32'd1;
                        tx_state    <= T_IDLE;
                    end
                end

                default: tx_state <= T_IDLE;
            endcase

            // A round offered while the link is mid-frame cannot be sent.
            if (tx_state != T_IDLE && syn_valid) tx_dropped <= tx_dropped + 32'd1;
        end
    end

endmodule
