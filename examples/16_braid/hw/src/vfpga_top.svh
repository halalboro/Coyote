/**
 * Coyote Example 16: BRAID — Bidirectional Rapid Anyon Interconnect for Decoders
 *
 * Coyote-side wrapper around the portable braid_link protocol core. Everything
 * Coyote-specific lives HERE; braid_link.sv itself stays free of Coyote types so
 * it can be copied verbatim into a bare RFSoC project.
 *
 * Phase 1 binds the core to the proven Aurora path (braid_phy_aurora) so the
 * protocol can be validated on hardware that works today. Phase 2 swaps in a raw
 * GTY backend for the <100 ns target; nothing in this file or in braid_link.sv
 * changes when that happens.
 *
 * A synthetic syndrome generator and a checker sit either side of the core, so a
 * pair of cards can validate framing, checksums, round counting and gap
 * detection without any real QEC hardware attached.
 *
 * Register map (host CSR index = byte offset / 8):
 *   0  CTRL        RW : bit0=run generator, bit1=arm checker, bit2=clear counters
 *   1  STATUS      RO : bit0=channel_up, bits[4:1]=lane_up, bit5=link_up
 *   2  N_ROUNDS    RW : rounds to generate (0 = free-run until stopped)
 *   3  INTERVAL    RW : aclk cycles between generated rounds
 *   4  TX_FRAMES   RO
 *   5  TX_DROPPED  RO : rounds offered while the link was busy or down
 *   6  RX_FRAMES   RO
 *   7  RX_ERRORS   RO : checksum / length / PHY errors
 *   8  RX_GAPS     RO : rounds that went missing
 *   9  RX_MISMATCH RO : payload did not match the expected pattern
 *   10 LAST_ROUND  RO : round number of the last good syndrome
 *   11..15 SCRATCH RW
 */

// 1024 bits = 32 words = 128 bytes maximum. The runtime SYN_WORDS register
// selects how much of it is actually sent, so one bitstream can sweep syndrome
// size -- i.e. code distance. d=11 is ~120 bits (4 words), d=25 ~624 (20 words).
localparam int N_STAB = 1024;   // MAXIMUM stabilizers per round
localparam int N_CORR = 64;

// =========================================================================
// Constants and register map
// =========================================================================
localparam integer N_REGS        = 16;
localparam integer ADDR_LSB      = $clog2(AXIL_DATA_BITS/8);
localparam integer ADDR_MSB      = $clog2(N_REGS);
localparam integer AXI_ADDR_BITS = ADDR_LSB + ADDR_MSB;

localparam integer REG_CTRL        = 0;
localparam integer REG_STATUS      = 1;
localparam integer REG_N_ROUNDS    = 2;
localparam integer REG_INTERVAL    = 3;
localparam integer REG_TX_FRAMES   = 4;
localparam integer REG_TX_DROPPED  = 5;
localparam integer REG_RX_FRAMES   = 6;
localparam integer REG_RX_ERRORS   = 7;
localparam integer REG_RX_GAPS     = 8;
localparam integer REG_RX_MISMATCH = 9;
localparam integer REG_LAST_ROUND  = 10;
localparam integer REG_SYN_WORDS   = 11;   // RW, payload words per frame
localparam integer REG_RTT_CYCLES  = 12;   // RO, aclk cycles for the last echo
localparam integer REG_SCRATCH0    = 13;

// =========================================================================
// Declarations
// =========================================================================
logic [AXI_ADDR_BITS-1:0]              axi_awaddr, axi_araddr;
logic                                  axi_awready, axi_arready, axi_wready;
logic                                  axi_bvalid, axi_rvalid, aw_en;
logic [1:0]                            axi_bresp, axi_rresp;
logic [AXIL_DATA_BITS-1:0]             axi_rdata;
logic [N_REGS-1:0][AXIL_DATA_BITS-1:0] ctrl_reg;
logic                                  ctrl_reg_wren, ctrl_reg_rden;

// braid core <-> phy
logic [31:0] phy_tx_data, phy_rx_data;
logic        phy_tx_valid, phy_tx_last, phy_tx_ready;
logic        phy_rx_valid, phy_rx_last, phy_rx_err;

// braid core user ports
logic [N_STAB-1:0] syn_bits, syn_out_bits;
logic              syn_valid, syn_out_valid, syn_out_gap;
logic [31:0]       syn_out_round;
logic [N_CORR-1:0] corr_bits, corr_out_bits;
logic              corr_valid, corr_out_valid;
logic [31:0]       tx_frames, tx_dropped, rx_frames, rx_errors, rx_gaps;

// generator / checker
logic [31:0]       gen_timer, gen_count, rx_mismatch, last_round;
logic [19:0]       gen_round;
// The round number presented to braid_link must be registered in the same cycle
// as syn_bits. gen_round increments on that cycle too, so passing it directly
// would stamp the frame with R+1 while carrying pattern(R).
logic [19:0]       gen_round_q;

// Latency measurement. Same approach as example 14: one free-running aclk
// counter timestamps both ends of the round trip on the SAME card, so no clock
// sync between hosts is needed. The far card echoes (CTRL bit3), so what is
// measured is a round trip -- halve it for a one-way estimate.
logic [31:0]       cyc_cnt, t_start, rtt_cycles;
logic              t_start_v;

wire run       = ctrl_reg[REG_CTRL][0];
wire arm       = ctrl_reg[REG_CTRL][1];
wire clr       = ctrl_reg[REG_CTRL][2];
// These two were missing for one build. Verilog's implicit-net rule turned the
// undeclared identifiers into undriven 1-bit wires reading 0, so it SYNTHESISED
// CLEANLY while echo mode could never engage and SYN_WORDS was ignored. Nothing
// warned. If you add a control alias, declare it here.
wire        echo_mode = ctrl_reg[REG_CTRL][3];
wire [7:0]  syn_words = ctrl_reg[REG_SYN_WORDS][7:0];
wire [31:0] n_rounds = ctrl_reg[REG_N_ROUNDS][31:0];
wire [31:0] interval = ctrl_reg[REG_INTERVAL][31:0];

wire [ADDR_MSB-1:0] wr_idx = axi_awaddr[ADDR_LSB+:ADDR_MSB];
wire [ADDR_MSB-1:0] rd_idx = axi_araddr[ADDR_LSB+:ADDR_MSB];
wire wr_allowed = (wr_idx == REG_CTRL) || (wr_idx == REG_N_ROUNDS) ||
                  (wr_idx == REG_INTERVAL) || (wr_idx == REG_SYN_WORDS) ||
                  (wr_idx >= REG_SCRATCH0);

wire link_up = aurora_channel_up;

// Masks off the words beyond the current payload length.
// Clamped: an out-of-range value would underflow the shift below and produce
// an all-zero mask, which reads as "everything matches".
wire [7:0] active_words = (syn_words == 8'd0 || syn_words > 8'd32) ? 8'd32 : syn_words;
wire [N_STAB-1:0] word_mask = ({N_STAB{1'b1}} >> (N_STAB - {active_words, 5'b0}));

// Deterministic pattern both ends compute independently from the round number,
// so the checker needs no side channel to know what to expect.
function automatic logic [N_STAB-1:0] pattern(input logic [19:0] r);
    logic [N_STAB+31:0] p;
    for (int k = 0; k <= (N_STAB/32); k++)
        p[k*32 +: 32] = {12'b0, r} ^ (32'h9E3779B9 * (k + 1));
    return p[N_STAB-1:0];
endfunction

// =========================================================================
// AXI4-Lite slave (canonical Coyote structure -- see
// examples/07_perf_fpga/hw/src/hdl/perf_fpga_axi_ctrl_parser.sv).
// Do NOT hand-roll this: sampling wdata anywhere other than the AW+W handshake
// cycle silently drops every host write.
// =========================================================================
assign ctrl_reg_wren = axi_wready && axi_ctrl.wvalid && axi_awready && axi_ctrl.awvalid;
assign ctrl_reg_rden = axi_arready && axi_ctrl.arvalid && !axi_rvalid;

always_ff @(posedge aclk) begin
    if (!aresetn) ctrl_reg <= '0;
    else if (ctrl_reg_wren && wr_allowed)
        for (int i = 0; i < (AXIL_DATA_BITS/8); i++)
            if (axi_ctrl.wstrb[i])
                ctrl_reg[wr_idx][(i*8)+:8] <= axi_ctrl.wdata[(i*8)+:8];
end

always_ff @(posedge aclk) begin
    if (!aresetn) axi_rdata <= '0;
    else if (ctrl_reg_rden) begin
        case (rd_idx)
            REG_STATUS:      axi_rdata <= {58'b0, link_up, aurora_lane_up, aurora_channel_up};
            REG_TX_FRAMES:   axi_rdata <= {32'b0, tx_frames};
            REG_TX_DROPPED:  axi_rdata <= {32'b0, tx_dropped};
            REG_RX_FRAMES:   axi_rdata <= {32'b0, rx_frames};
            REG_RX_ERRORS:   axi_rdata <= {32'b0, rx_errors};
            REG_RX_GAPS:     axi_rdata <= {32'b0, rx_gaps};
            REG_RX_MISMATCH: axi_rdata <= {32'b0, rx_mismatch};
            REG_LAST_ROUND:  axi_rdata <= {32'b0, last_round};
            REG_RTT_CYCLES:  axi_rdata <= {32'b0, rtt_cycles};
            default:         axi_rdata <= ctrl_reg[rd_idx];
        endcase
    end
end

assign axi_ctrl.awready = axi_awready;
assign axi_ctrl.arready = axi_arready;
assign axi_ctrl.wready  = axi_wready;
assign axi_ctrl.bvalid  = axi_bvalid;
assign axi_ctrl.bresp   = axi_bresp;
assign axi_ctrl.rdata   = axi_rdata;
assign axi_ctrl.rvalid  = axi_rvalid;
assign axi_ctrl.rresp   = axi_rresp;

always_ff @(posedge aclk) begin
    if (!aresetn) begin
        axi_awready <= 1'b0; axi_awaddr <= '0; aw_en <= 1'b1;
    end else if (!axi_awready && axi_ctrl.awvalid && axi_ctrl.wvalid && aw_en) begin
        axi_awready <= 1'b1; aw_en <= 1'b0;
        axi_awaddr  <= axi_ctrl.awaddr[AXI_ADDR_BITS-1:0];
    end else if (axi_ctrl.bready && axi_bvalid) begin
        aw_en <= 1'b1; axi_awready <= 1'b0;
    end else axi_awready <= 1'b0;
end

always_ff @(posedge aclk) begin
    if (!aresetn) axi_wready <= 1'b0;
    else axi_wready <= (!axi_wready && axi_ctrl.wvalid && axi_ctrl.awvalid && aw_en);
end

always_ff @(posedge aclk) begin
    if (!aresetn) begin
        axi_bvalid <= 1'b0; axi_bresp <= 2'b00;
    end else if (axi_awready && axi_ctrl.awvalid && !axi_bvalid && axi_wready && axi_ctrl.wvalid) begin
        axi_bvalid <= 1'b1; axi_bresp <= 2'b00;
    end else if (axi_ctrl.bready && axi_bvalid) axi_bvalid <= 1'b0;
end

always_ff @(posedge aclk) begin
    if (!aresetn) begin
        axi_arready <= 1'b0; axi_araddr <= '0;
    end else if (!axi_arready && axi_ctrl.arvalid) begin
        axi_arready <= 1'b1; axi_araddr <= axi_ctrl.araddr[AXI_ADDR_BITS-1:0];
    end else axi_arready <= 1'b0;
end

always_ff @(posedge aclk) begin
    if (!aresetn) begin
        axi_rvalid <= 1'b0; axi_rresp <= 2'b00;
    end else if (axi_arready && axi_ctrl.arvalid && !axi_rvalid) begin
        axi_rvalid <= 1'b1; axi_rresp <= 2'b00;
    end else if (axi_rvalid && axi_ctrl.rready) axi_rvalid <= 1'b0;
end

// =========================================================================
// Synthetic syndrome generator
// =========================================================================
// Echo mode: reflect every received syndrome straight back out, unchanged.
// The far card then measures a round trip against its own clock, so no clock
// synchronisation between hosts is needed.
logic [N_STAB-1:0] echo_bits;
logic              echo_valid;
logic [19:0]       echo_round;

always_ff @(posedge aclk) begin
    if (!aresetn) begin
        echo_bits  <= '0;
        echo_valid <= 1'b0;
        echo_round <= '0;
    end else begin
        echo_valid <= echo_mode && syn_out_valid;
        echo_bits  <= syn_out_bits;
        echo_round <= syn_out_round[19:0];
    end
end

always_ff @(posedge aclk) begin
    if (!aresetn || !run) begin
        gen_timer   <= '0;
        gen_count   <= '0;
        gen_round   <= '0;
        gen_round_q <= '0;
        syn_valid   <= 1'b0;
        syn_bits    <= '0;
    end else begin
        syn_valid <= 1'b0;
        if (link_up && (n_rounds == 0 || gen_count < n_rounds)) begin
            if (gen_timer >= interval) begin
                gen_timer   <= '0;
                syn_bits    <= pattern(gen_round);
                gen_round_q <= gen_round;          // must match syn_bits
                syn_valid   <= 1'b1;
                gen_round   <= gen_round + 20'd1;
                gen_count   <= gen_count + 32'd1;
            end else begin
                gen_timer <= gen_timer + 32'd1;
            end
        end
    end
end

// Corrections are not exercised by the generator yet; tie off cleanly.
assign corr_bits  = '0;
assign corr_valid = 1'b0;

// =========================================================================
// Latency measurement
//
// Single outstanding round: the host sends one, waits for the echo, reads the
// result. t_start is taken when the round leaves, and the delta when the echo
// of that same round returns. Both timestamps come from this card's counter.
// =========================================================================
always_ff @(posedge aclk) begin
    if (!aresetn) cyc_cnt <= '0;
    else          cyc_cnt <= cyc_cnt + 32'd1;
end

always_ff @(posedge aclk) begin
    if (!aresetn || clr) begin
        t_start    <= '0;
        t_start_v  <= 1'b0;
        rtt_cycles <= '0;
    end else begin
        // A locally generated round leaves: start the clock. Not armed in echo
        // mode, where this card is the reflector rather than the measurer.
        if (syn_valid && !echo_mode) begin
            t_start   <= cyc_cnt;
            t_start_v <= 1'b1;
        end
        // Its echo comes back.
        if (syn_out_valid && t_start_v && !echo_mode) begin
            rtt_cycles <= cyc_cnt - t_start;
            t_start_v  <= 1'b0;
        end
    end
end

// =========================================================================
// Checker
// =========================================================================
always_ff @(posedge aclk) begin
    if (!aresetn || !arm || clr) begin
        rx_mismatch <= '0;
        last_round  <= '0;
    end else if (syn_out_valid) begin
        last_round <= syn_out_round;
        // Compare only the words actually transmitted. With a runtime payload
        // length the upper bits of syn_out_bits are stale from a previous,
        // longer frame and would read as mismatches.
        if ((syn_out_bits & word_mask) != (pattern(syn_out_round[19:0]) & word_mask))
            rx_mismatch <= rx_mismatch + 32'd1;
    end
end

// =========================================================================
// BRAID core + phase-1 Aurora backend
// =========================================================================
braid_link_tx #(.N_STAB(N_STAB), .N_CORR(N_CORR)) inst_braid_tx (
    .clk(aclk), .rstn(aresetn), .link_up(link_up), .clr(clr),
    .syn_bits(echo_mode ? echo_bits  : syn_bits),
    .syn_valid(echo_mode ? echo_valid : syn_valid),
    .syn_round(echo_mode ? echo_round : gen_round_q),
    .syn_words_sel(syn_words),
    .corr_bits(corr_bits), .corr_valid(corr_valid),
    .phy_tx_data(phy_tx_data), .phy_tx_valid(phy_tx_valid),
    .phy_tx_last(phy_tx_last), .phy_tx_ready(phy_tx_ready),
    .tx_frames(tx_frames), .tx_dropped(tx_dropped)
);

braid_link_rx #(.N_STAB(N_STAB), .N_CORR(N_CORR)) inst_braid_rx (
    .clk(aclk), .rstn(aresetn), .link_up(link_up), .clr(clr),
    .syn_out_bits(syn_out_bits), .syn_out_valid(syn_out_valid),
    .syn_out_round(syn_out_round), .syn_out_gap(syn_out_gap),
    .corr_out_bits(corr_out_bits), .corr_out_valid(corr_out_valid),
    .phy_rx_data(phy_rx_data), .phy_rx_valid(phy_rx_valid),
    .phy_rx_last(phy_rx_last), .phy_rx_err(phy_rx_err),
    .rx_frames(rx_frames), .rx_errors(rx_errors), .rx_gaps(rx_gaps)
);

// The shell routes the BRAID GTY PHY out on the same 256-bit AXIS ports the
// Aurora integration used, so nothing in the dynamic/user templates changes.
braid_phy_shim inst_phy (
    .clk(aclk), .rstn(aresetn),
    .phy_tx_data(phy_tx_data), .phy_tx_valid(phy_tx_valid),
    .phy_tx_last(phy_tx_last), .phy_tx_ready(phy_tx_ready),
    .phy_rx_data(phy_rx_data), .phy_rx_valid(phy_rx_valid),
    .phy_rx_last(phy_rx_last), .phy_rx_err(phy_rx_err),
    .shl_tx_tdata(axis_aurora_tx.tdata), .shl_tx_tvalid(axis_aurora_tx.tvalid),
    .shl_tx_tlast(axis_aurora_tx.tlast), .shl_tx_tready(axis_aurora_tx.tready),
    .shl_rx_tdata(axis_aurora_rx.tdata), .shl_rx_tvalid(axis_aurora_rx.tvalid),
    .shl_rx_tlast(axis_aurora_rx.tlast), .shl_rx_tready(axis_aurora_rx.tready)
);

assign axis_aurora_tx.tkeep = '1;

// =========================================================================
// Tie off unused Coyote interfaces
// =========================================================================
always_comb axis_host_recv[0].tie_off_s();
always_comb axis_host_send[0].tie_off_m();
always_comb notify.tie_off_m();
always_comb sq_rd.tie_off_m();
always_comb sq_wr.tie_off_m();
always_comb cq_rd.tie_off_s();
always_comb cq_wr.tie_off_s();
