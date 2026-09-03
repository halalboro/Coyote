/**
 * QLINK framer — 8B/10B K-character framing, with no GT and no vendor primitives
 *
 * Split out of qlink_phy_gty so it can be simulated. Every bug found on hardware
 * so far has lived in this layer (all-comma idle, lane-0 detection, comma
 * alignment), and each cost a ~3 hour bitgen. This module is pure RTL: two of
 * them wired back to back in a testbench exercise the whole framing protocol in
 * milliseconds. Keep it that way -- if the framing is ever copied back into
 * qlink_phy_gty, the simulation stops testing what is actually synthesised.
 *
 * STREAMING FRAME LAYOUT. A frame is:
 *
 *     MARKER   {round[15:0], n_words[7:0], K}     one word
 *     payload  n_words data words
 *     TRAILER  {checksum[23:0], K29.7}             one word
 *
 * There is no separate header word and no separate checksum word. Both used to
 * exist and both were waste: a control word carries ONE K-character, in byte
 * lane 0, leaving three data bytes that were being filled with D16.2 padding.
 * The header now rides in the marker's spare bytes and the checksum in the
 * trailer's, so a frame is two words shorter and the payload starts one word
 * sooner.
 *
 * The frame TYPE is the marker's K-character rather than a field, which is what
 * frees the 24 bits:
 *     K27.7 (0xFB) -> syndrome, dense bitmap
 *     K28.3 (0x7C) -> syndrome, sparse (a list of fired stabilizer positions)
 *     K28.2 (0x5C) -> correction
 * None is a comma (only K28.1/K28.5/K28.7 are), so none can be mistaken for the
 * idle word by the alignment logic.
 *
 * THE FRAMER DOES NOT INTERPRET THE PAYLOAD, and neither do the link cores.
 * Dense and sparse differ only in what the bytes mean, which is an agreement
 * between the syndrome source and the decoder. The type bit exists so a
 * receiver can tell them apart when both are in use on one link -- it is not
 * what makes sparse cheaper. Sparse is cheaper because it needs fewer words,
 * and the link already sends however many words it is given.
 *
 * TWO CLOCK DOMAINS. The TX half runs on the local transmit user clock; the RX
 * half runs on the RECOVERED clock. That is a consequence of bypassing the RX
 * elastic buffer, which is the single largest GT latency saving available. The
 * two halves share no state, so this costs nothing but the port list.
 *
 * Control words carry exactly ONE K-character, in byte lane 0. An idle of
 * {4{K28.5}} would put a comma in every lane and the aligner -- which locks the
 * byte boundary by placing a detected comma in lane 0 -- would have four to
 * choose from, leaving the received word boundary 0-3 bytes off. This only
 * works if RX_COMMA_ALIGN_WORD equals the datapath width in bytes (4); the
 * default of 1 lets the comma land in any lane.
 */

module qlink_framer (
    // ---- TX domain: local transmit user clock ----
    input  logic          clk_tx,
    input  logic          rstn_tx,
    input  logic          link_up_tx,

    input  logic [31:0]   phy_tx_data,
    input  logic          phy_tx_valid,
    input  logic          phy_tx_last,
    output logic          phy_tx_ready,
    // Carried in the marker and trailer rather than in words of their own.
    // hdr must be stable for the whole frame; cks only on the final cycle.
    input  logic [23:0]   phy_tx_hdr,     // {round[15:0], n_words[7:0]}
    input  logic [23:0]   phy_tx_cks,
    input  logic [1:0]    phy_tx_type,    // 0=dense syn, 1=correction, 2=sparse syn

    output logic [31:0]   gt_txdata,
    output logic [7:0]    gt_txctrl2,     // TXCHARISK

    // ---- RX domain: recovered clock ----
    input  logic          clk_rx,
    input  logic          rstn_rx,
    input  logic          link_up_rx,

    output logic [31:0]   phy_rx_data,
    output logic          phy_rx_valid,
    output logic          phy_rx_eof,     // one-cycle strobe AFTER the last word
    output logic          phy_rx_err,
    output logic [23:0]   phy_rx_hdr,     // held from phy_rx_sof to the next SOF
    output logic          phy_rx_sof,
    output logic [1:0]    phy_rx_type,
    output logic [23:0]   phy_rx_cks,     // valid with phy_rx_eof

    input  logic [31:0]   gt_rxdata,
    input  logic [15:0]   gt_rxctrl0,     // RXCHARISK
    input  logic [15:0]   gt_rxctrl1,     // RXDISPERR
    input  logic [7:0]    gt_rxctrl3,     // RXNOTINTABLE

    // sticky diagnostics, clk_rx domain
    //   [0] a K-char was seen in lane 0      <- alignment correct
    //   [1] a K-char was seen in lanes 1..3  <- MISALIGNED
    output logic [1:0]    dbg
);

    localparam logic [7:0] K28_5 = 8'hBC;   // comma / idle
    localparam logic [7:0] K27_7 = 8'hFB;   // start of frame, syndrome
    localparam logic [7:0] K28_2 = 8'h5C;   // start of frame, correction
    localparam logic [7:0] K28_3 = 8'h7C;   // start of frame, sparse syndrome
    localparam logic [7:0] K29_7 = 8'hFD;   // end of frame
    localparam logic [7:0] D16_2 = 8'h50;   // neutral filler, not a comma

    localparam logic [31:0] W_IDLE = {D16_2, D16_2, D16_2, K28_5};
    localparam logic [7:0]  CTRL_K = 8'b0000_0001;   // K in lane 0 only

    // ================================================================ TX
    typedef enum logic [1:0] { T_IDLE, T_DATA, T_EOF } tx_e;
    tx_e tx_state;

    wire [7:0] k_sof = (phy_tx_type == 2'd1) ? K28_2
                     : (phy_tx_type == 2'd2) ? K28_3 : K27_7;
    wire [31:0] w_marker  = {phy_tx_hdr, k_sof};
    wire [31:0] w_trailer = {phy_tx_cks, K29_7};

    // COMBINATIONAL datapath, registered state. The output register that used
    // to sit here was back to back with qlink_link_tx's own output register,
    // so every word paid two stages to cross one module boundary. gt_txdata
    // feeds the GT's TXDATA input, which registers it inside the transceiver --
    // combinational into a register is the normal arrangement, not a shortcut.
    always_comb begin
        gt_txctrl2 = CTRL_K;
        case (tx_state)
            T_IDLE:  gt_txdata = (rstn_tx && link_up_tx && phy_tx_valid) ? w_marker : W_IDLE;
            T_DATA:  begin
                if (phy_tx_valid) begin
                    gt_txdata  = phy_tx_data;
                    // Must match: 0x0F here would mark the payload bytes as
                    // control characters and the far end would see
                    // not-in-table errors for the whole frame.
                    gt_txctrl2 = 8'h00;
                end else begin
                    gt_txdata  = W_IDLE;
                end
            end
            T_EOF:   gt_txdata = w_trailer;
            default: gt_txdata = W_IDLE;
        endcase
    end

    always_ff @(posedge clk_tx) begin
        if (!rstn_tx) begin
            tx_state <= T_IDLE;
        end else begin
            case (tx_state)
                T_IDLE: if (link_up_tx && phy_tx_valid) tx_state <= T_DATA;
                T_DATA: if (phy_tx_valid && phy_tx_last) tx_state <= T_EOF;
                T_EOF:  tx_state <= T_IDLE;
                default: tx_state <= T_IDLE;
            endcase
        end
    end

    assign phy_tx_ready = (tx_state == T_DATA);

    // ================================================================ RX
    wire rx_is_k     = gt_rxctrl0[0];
    wire rx_is_sof_s = rx_is_k && (gt_rxdata[7:0] == K27_7);
    wire rx_is_sof_c = rx_is_k && (gt_rxdata[7:0] == K28_2);
    wire rx_is_sof_p = rx_is_k && (gt_rxdata[7:0] == K28_3);
    wire rx_is_sof   = rx_is_sof_s || rx_is_sof_c || rx_is_sof_p;
    wire rx_is_eof   = rx_is_k && (gt_rxdata[7:0] == K29_7);
    wire rx_code_err = (|gt_rxctrl1[3:0]) | (|gt_rxctrl3[3:0]);

    logic in_frame;

    logic stk_k_lane0, stk_k_other;
    always_ff @(posedge clk_rx) begin
        if (!rstn_rx || !link_up_rx) begin
            // Cleared while the link is down. A transient during comma hunting
            // would otherwise latch K_misaligned forever, making the bit
            // useless for judging steady state -- which is what it is for.
            stk_k_lane0 <= 1'b0;
            stk_k_other <= 1'b0;
        end else begin
            if (gt_rxctrl0[0])    stk_k_lane0 <= 1'b1;
            if (|gt_rxctrl0[3:1]) stk_k_other <= 1'b1;
        end
    end
    assign dbg = {stk_k_other, stk_k_lane0};

    // COMBINATIONAL as well, for the same reason: this register was back to
    // back with qlink_link_rx's. gt_rxdata comes straight off the GT's own
    // output register, so the path into qlink_link_rx is still
    // register-to-register -- it just has the K-character decode in it now.
    //
    // phy_rx_hdr and phy_rx_cks are NO LONGER HELD. Each is only meaningful on
    // the cycle its strobe is asserted; qlink_link_rx latches them there.
    //
    // KNOWN LOSS: an 8B/10B error in the trailer is reported on phy_rx_eof,
    // which arrives after the syndrome has already been delivered by
    // cut-through. It is counted, not retracted. The trailer carries no payload.
    assign phy_rx_data  = gt_rxdata;
    assign phy_rx_hdr   = gt_rxdata[31:8];
    assign phy_rx_cks   = gt_rxdata[31:8];
    assign phy_rx_type  = rx_is_sof_c ? 2'd1 : rx_is_sof_p ? 2'd2 : 2'd0;
    assign phy_rx_err   = rx_code_err;
    assign phy_rx_sof   = rstn_rx && link_up_rx && rx_is_sof;
    assign phy_rx_eof   = rstn_rx && link_up_rx && in_frame && rx_is_eof;
    assign phy_rx_valid = rstn_rx && link_up_rx && in_frame && !rx_is_k;

    always_ff @(posedge clk_rx) begin
        if (!rstn_rx || !link_up_rx) begin
            in_frame <= 1'b0;
        end else if (rx_is_sof) begin
            in_frame <= 1'b1;
        end else if (in_frame && rx_is_k) begin
            // EOF, or any other control word -- which means the frame broke.
            // Either way the frame is over; qlink_link_rx tells them apart from
            // whether an EOF strobe accompanied it.
            in_frame <= 1'b0;
        end
    end

endmodule
