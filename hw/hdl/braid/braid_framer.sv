/**
 * BRAID framer — 8B/10B K-character framing, with no GT and no vendor primitives
 *
 * Split out of braid_phy_gty so it can be simulated. Every bug found on hardware
 * so far has lived in this layer (all-comma idle, lane-0 detection, comma
 * alignment), and each cost a ~3 hour bitgen. This module is pure RTL: two of
 * them wired back to back in a testbench exercise the whole framing protocol in
 * milliseconds. Keep it that way -- if the framing is ever copied back into
 * braid_phy_gty, the simulation stops testing what is actually synthesised.
 *
 * TWO CLOCK DOMAINS. The TX half runs on the local transmit user clock; the RX
 * half runs on the RECOVERED clock. That is a consequence of bypassing the RX
 * elastic buffer: the buffer is what would otherwise bridge the recovered clock
 * to a clock of your choosing, and bypassing it is the single largest GT
 * latency saving available. The two halves share no state -- the TX and RX FSMs
 * were always independent -- so this costs nothing but the port list.
 *
 * Bypass does NOT require the two ends to share a reference clock: RXUSRCLK is
 * driven from RXOUTCLK, so it is frequency-locked to the incoming data by
 * construction. Onward crossing into aclk is handled by the async FIFO that was
 * already there.
 *
 * Control words carry exactly ONE K-character, in byte lane 0. An idle of
 * {4{K28.5}} would put a comma in every lane and the aligner -- which locks the
 * byte boundary by placing a detected comma in lane 0 -- would have four to
 * choose from, leaving the received word boundary 0-3 bytes off. This only
 * works if RX_COMMA_ALIGN_WORD equals the datapath width in bytes (4); the
 * default of 1 lets the comma land in any lane.
 */

module braid_framer (
    // ---- TX domain: local transmit user clock ----
    input  logic          clk_tx,
    input  logic          rstn_tx,
    input  logic          link_up_tx,

    input  logic [31:0]   phy_tx_data,
    input  logic          phy_tx_valid,
    input  logic          phy_tx_last,
    output logic          phy_tx_ready,

    output logic [31:0]   gt_txdata,
    output logic [7:0]    gt_txctrl2,     // TXCHARISK

    // ---- RX domain: recovered clock ----
    input  logic          clk_rx,
    input  logic          rstn_rx,
    input  logic          link_up_rx,

    output logic [31:0]   phy_rx_data,
    output logic          phy_rx_valid,
    output logic          phy_rx_last,
    output logic          phy_rx_err,

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
    localparam logic [7:0] K27_7 = 8'hFB;   // start of frame
    localparam logic [7:0] K29_7 = 8'hFD;   // end of frame
    localparam logic [7:0] D16_2 = 8'h50;   // neutral filler, not a comma

    localparam logic [31:0] W_IDLE = {D16_2, D16_2, D16_2, K28_5};
    localparam logic [31:0] W_SOF  = {D16_2, D16_2, D16_2, K27_7};
    localparam logic [31:0] W_EOF  = {D16_2, D16_2, D16_2, K29_7};
    localparam logic [7:0]  CTRL_K = 8'b0000_0001;   // K in lane 0 only

    // ================================================================ TX
    typedef enum logic [1:0] { T_IDLE, T_SOF, T_DATA, T_EOF } tx_e;
    tx_e tx_state;

    always_ff @(posedge clk_tx) begin
        if (!rstn_tx) begin
            tx_state   <= T_IDLE;
            gt_txdata  <= W_IDLE;
            // Must match W_IDLE's single K. 8'h0F here would mark the three
            // D16.2 filler bytes as control characters, and 0x50 is not a valid
            // K-code, so the far end would see not-in-table errors for as long
            // as reset was held.
            gt_txctrl2 <= CTRL_K;
        end else begin
            case (tx_state)
                T_IDLE: begin
                    gt_txdata  <= W_IDLE;
                    gt_txctrl2 <= CTRL_K;
                    if (link_up_tx && phy_tx_valid) tx_state <= T_SOF;
                end
                T_SOF: begin
                    gt_txdata  <= W_SOF;
                    gt_txctrl2 <= CTRL_K;
                    tx_state   <= T_DATA;
                end
                T_DATA: begin
                    // Only consume on a real handshake, otherwise a CDC
                    // underrun mid-frame clocks stale data out as payload in a
                    // frame that still looks well formed.
                    if (phy_tx_valid) begin
                        gt_txdata  <= phy_tx_data;
                        gt_txctrl2 <= 8'h00;
                        if (phy_tx_last) tx_state <= T_EOF;
                    end else begin
                        gt_txdata  <= W_IDLE;
                        gt_txctrl2 <= CTRL_K;
                    end
                end
                T_EOF: begin
                    gt_txdata  <= W_EOF;
                    gt_txctrl2 <= CTRL_K;
                    tx_state   <= T_IDLE;
                end
                default: tx_state <= T_IDLE;
            endcase
        end
    end

    assign phy_tx_ready = (tx_state == T_DATA);

    // ================================================================ RX
    wire rx_is_k     = gt_rxctrl0[0];
    wire rx_is_sof   = rx_is_k && (gt_rxdata[7:0] == K27_7);
    wire rx_is_eof   = rx_is_k && (gt_rxdata[7:0] == K29_7);
    wire rx_code_err = (|gt_rxctrl1[3:0]) | (|gt_rxctrl3[3:0]);

    logic [31:0] hold_data;
    logic        hold_valid, in_frame, err_sticky;

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

    // The EOF marker arrives AFTER the final data word, so one word is held
    // back to assert phy_rx_last alongside that word rather than a cycle late.
    always_ff @(posedge clk_rx) begin
        if (!rstn_rx) begin
            phy_rx_valid <= 1'b0;
            phy_rx_last  <= 1'b0;
            phy_rx_err   <= 1'b0;
            phy_rx_data  <= '0;
            hold_valid   <= 1'b0;
            hold_data    <= '0;
            in_frame     <= 1'b0;
            err_sticky   <= 1'b0;
        end else begin
            phy_rx_valid <= 1'b0;
            phy_rx_last  <= 1'b0;
            phy_rx_err   <= 1'b0;

            if (!link_up_rx) begin
                in_frame   <= 1'b0;
                hold_valid <= 1'b0;
                err_sticky <= 1'b0;
            end else if (rx_is_sof) begin
                in_frame   <= 1'b1;
                hold_valid <= 1'b0;
                err_sticky <= rx_code_err;
            end else if (in_frame) begin
                if (rx_is_eof) begin
                    if (hold_valid) begin
                        phy_rx_data  <= hold_data;
                        phy_rx_valid <= 1'b1;
                        phy_rx_last  <= 1'b1;
                        phy_rx_err   <= err_sticky | rx_code_err;
                    end
                    in_frame   <= 1'b0;
                    hold_valid <= 1'b0;
                    err_sticky <= 1'b0;
                end else if (rx_is_k) begin
                    // Any other control word mid-frame means the frame broke.
                    in_frame   <= 1'b0;
                    hold_valid <= 1'b0;
                    err_sticky <= 1'b0;
                end else begin
                    if (hold_valid) begin
                        phy_rx_data  <= hold_data;
                        phy_rx_valid <= 1'b1;
                        phy_rx_last  <= 1'b0;
                        phy_rx_err   <= err_sticky;
                    end
                    hold_data  <= gt_rxdata;
                    hold_valid <= 1'b1;
                    err_sticky <= rx_code_err;
                end
            end
        end
    end

endmodule
