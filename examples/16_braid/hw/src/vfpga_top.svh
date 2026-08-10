/**
 * Coyote Example 16: BRAID — Bidirectional Rapid Anyon Interconnect for Decoders
 *
 * Coyote-side wrapper around the portable braid_link protocol cores. Everything
 * Coyote-specific lives HERE; braid_link_tx.sv / braid_link_rx.sv stay free of
 * Coyote types so they can be copied verbatim into a bare RFSoC project.
 *
 * =========================================================================
 * CLOCK DOMAINS -- read this before touching anything below.
 *
 * Since Task 2b the syndrome datapath does NOT run in aclk. It runs on the
 * transceiver's own clocks, which is the entire point: the two fabric CDC FIFOs
 * that used to bridge them were the largest known term in the latency budget.
 *
 *   aclk        400 MHz    AXI4-Lite CSR block ONLY
 *   braid_tx_clk 257.8125 MHz  generator, braid_link_tx, RTT counter
 *   braid_rx_clk 257.8125 MHz  braid_link_rx, checker  (RECOVERED from the peer)
 *
 * braid_tx_clk and braid_rx_clk are the same nominal frequency but are NOT the
 * same clock: rx is recovered from the incoming serial stream and tracks the far
 * card's oscillator, so the two drift by up to a few hundred ppm. Every signal
 * that moves between the three domains below goes through an XPM macro. There
 * are no exceptions in this file, and adding one will not produce a warning.
 *
 * Counters cross with xpm_cdc_gray rather than being re-counted in aclk from
 * crossed pulses: gray cannot lose an increment, whereas a pulse crossing drops
 * events that arrive closer together than the synchroniser depth -- which
 * tx_dropped does exactly when the link is down and the generator is free-
 * running at INTERVAL=0.
 * =========================================================================
 *
 * A synthetic syndrome generator and a checker sit either side of the cores, so
 * a pair of cards can validate framing, checksums, round counting and gap
 * detection without any real QEC hardware attached.
 *
 * Register map (host CSR index = byte offset / 8):
 *   0  CTRL        RW : bit0=run generator, bit1=arm checker, bit2=clear counters,
 *                       bit3=echo received syndromes back
 *   1  STATUS      RO : bit0=channel_up, bits[4:1]=PHY debug, bit5=link_up
 *   2  N_ROUNDS    RW : rounds to generate (0 = free-run until stopped)
 *   3  INTERVAL    RW : braid_tx_clk cycles between generated rounds (NOT aclk)
 *   4  TX_FRAMES   RO
 *   5  TX_DROPPED  RO : rounds offered while the link was busy or down
 *   6  RX_FRAMES   RO
 *   7  RX_ERRORS   RO : checksum / length / PHY errors
 *   8  RX_GAPS     RO : rounds that went missing
 *   9  RX_MISMATCH RO : payload did not match the expected pattern
 *   10 LAST_ROUND  RO : round number of the last good syndrome
 *   11 SYN_WORDS   RW : payload words per frame, 1..31
 *   12 RTT_CYCLES  RO : braid_tx_clk cycles for the last echo (NOT aclk)
 *   13 LOOPBACK    RW : GT LOOPBACK[2:0], UG578. Latency decomposition tool --
 *                       000 normal, 010 near-end PMA, 110 far-end PMA. Changing
 *                       it resets the transceiver, so the link drops and comes
 *                       back; wait for STATUS again before measuring.
 *   14..15 SCRATCH RW
 */

// 992 bits = 31 words = 124 bytes maximum. The runtime SYN_WORDS register
// selects how much of it is actually sent, so one bitstream can sweep syndrome
// size -- i.e. code distance. d=11 is ~120 bits (4 words), d=25 ~624 (20 words).
//
// Why 31 words and not 32: echo mode has to carry {round, payload} across the
// rx->tx boundary in ONE atomic transfer, and xpm_cdc_handshake tops out at
// 1024 bits. 992 + 20 = 1012 fits; 1024 + 20 does not. Splitting it across two
// handshakes would break atomicity, which is the only property that makes the
// crossing correct at all.
localparam int N_STAB = 992;    // MAXIMUM stabilizers per round
localparam int N_CORR = 64;
localparam int MAX_WORDS_SEL = N_STAB / 32;   // 31

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
localparam integer REG_RTT_CYCLES  = 12;   // RO, tx_clk cycles for the last echo
localparam integer REG_LOOPBACK    = 13;   // RW, GT LOOPBACK[2:0]
localparam integer REG_SCRATCH0    = 14;

// =========================================================================
// Declarations -- aclk domain
// =========================================================================
logic [AXI_ADDR_BITS-1:0]              axi_awaddr, axi_araddr;
logic                                  axi_awready, axi_arready, axi_wready;
logic                                  axi_bvalid, axi_rvalid, aw_en;
logic [1:0]                            axi_bresp, axi_rresp;
logic [AXIL_DATA_BITS-1:0]             axi_rdata;
logic [N_REGS-1:0][AXIL_DATA_BITS-1:0] ctrl_reg;
logic                                  ctrl_reg_wren, ctrl_reg_rden;

// Counter and status values after crossing back into aclk for the CSR reads.
logic [31:0] tx_frames_a, tx_dropped_a;
logic [31:0] rx_frames_a, rx_errors_a, rx_gaps_a, rx_mismatch_a;
logic [31:0] rtt_cycles_a, last_round_a;

wire tclk  = braid_tx_clk;
wire rclk  = braid_rx_clk;
wire trstn = braid_tx_rstn;
wire rrstn = braid_rx_rstn;

wire run       = ctrl_reg[REG_CTRL][0];
wire arm       = ctrl_reg[REG_CTRL][1];
wire clr       = ctrl_reg[REG_CTRL][2];
// These two were missing for one build. Verilog's implicit-net rule turned the
// undeclared identifiers into undriven 1-bit wires reading 0, so it SYNTHESISED
// CLEANLY while echo mode could never engage and SYN_WORDS was ignored. Nothing
// warned. If you add a control alias, declare it here.
wire        echo_mode = ctrl_reg[REG_CTRL][3];
wire [7:0]  syn_words = ctrl_reg[REG_SYN_WORDS][7:0];
wire [31:0] n_rounds  = ctrl_reg[REG_N_ROUNDS][31:0];
wire [31:0] interval  = ctrl_reg[REG_INTERVAL][31:0];

// Quasi-static; braid_gty_wrapper synchronises it and resets the GT on change.
assign braid_loopback_sel = ctrl_reg[REG_LOOPBACK][2:0];

wire [ADDR_MSB-1:0] wr_idx = axi_awaddr[ADDR_LSB+:ADDR_MSB];
wire [ADDR_MSB-1:0] rd_idx = axi_araddr[ADDR_LSB+:ADDR_MSB];
wire wr_allowed = (wr_idx == REG_CTRL) || (wr_idx == REG_N_ROUNDS) ||
                  (wr_idx == REG_INTERVAL) || (wr_idx == REG_SYN_WORDS) ||
                  (wr_idx == REG_LOOPBACK) || (wr_idx >= REG_SCRATCH0);

// channel_up is already synchronised into aclk by braid_gty_wrapper.
wire link_up_a = aurora_channel_up;

// =========================================================================
// Declarations -- braid_tx_clk domain
// =========================================================================
logic [31:0] phy_tx_data;
logic        phy_tx_valid, phy_tx_last, phy_tx_ready;

logic [N_STAB-1:0] syn_bits;
logic              syn_valid;
logic [N_CORR-1:0] corr_bits;
logic              corr_valid;
logic [31:0]       tx_frames, tx_dropped;

logic [31:0] gen_timer, gen_count;
logic [19:0] gen_round;
// The round number presented to braid_link_tx must be registered in the same
// cycle as syn_bits. gen_round increments on that cycle too, so passing it
// directly would stamp the frame with R+1 while carrying pattern(R).
logic [19:0] gen_round_q;

logic [31:0] cyc_cnt, t_start, rtt_cycles;
logic        t_start_v, rtt_new, rtt_ack;

// Control and configuration after crossing from aclk.
logic        run_t, clr_t, echo_t, link_up_t;
logic [31:0] n_rounds_t, interval_t;
logic [7:0]  syn_words_t;

// Echo payload after crossing from braid_rx_clk.
logic              rx_event_t;
logic [N_STAB+19:0] echo_word_t;
logic [N_STAB-1:0] echo_bits;
logic              echo_valid;
logic [19:0]       echo_round;

// =========================================================================
// Declarations -- braid_rx_clk domain
// =========================================================================
logic [31:0] phy_rx_data;
logic        phy_rx_valid, phy_rx_last, phy_rx_err;

logic [N_STAB-1:0] syn_out_bits;
logic              syn_out_valid, syn_out_gap;
logic [31:0]       syn_out_round;
logic [N_CORR-1:0] corr_out_bits;
logic              corr_out_valid;
logic [31:0]       rx_frames, rx_errors, rx_gaps;

logic [31:0] rx_mismatch, last_round;
logic        last_round_new, last_round_ack, echo_busy;

logic        arm_r, clr_r, link_up_r;
logic [7:0]  syn_words_r;

// Masks off the words beyond the current payload length.
// Clamped: an out-of-range value would underflow the shift below and produce
// an all-zero mask, which reads as "everything matches".
wire [7:0] active_words = (syn_words_r == 8'd0 || syn_words_r > MAX_WORDS_SEL[7:0])
                        ? MAX_WORDS_SEL[7:0] : syn_words_r;
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
            REG_STATUS:      axi_rdata <= {58'b0, link_up_a, aurora_lane_up, aurora_channel_up};
            REG_TX_FRAMES:   axi_rdata <= {32'b0, tx_frames_a};
            REG_TX_DROPPED:  axi_rdata <= {32'b0, tx_dropped_a};
            REG_RX_FRAMES:   axi_rdata <= {32'b0, rx_frames_a};
            REG_RX_ERRORS:   axi_rdata <= {32'b0, rx_errors_a};
            REG_RX_GAPS:     axi_rdata <= {32'b0, rx_gaps_a};
            REG_RX_MISMATCH: axi_rdata <= {32'b0, rx_mismatch_a};
            REG_LAST_ROUND:  axi_rdata <= {32'b0, last_round_a};
            REG_RTT_CYCLES:  axi_rdata <= {32'b0, rtt_cycles_a};
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
// CSR crossing layer: aclk -> GT domains
//
// N_ROUNDS, INTERVAL and SYN_WORDS are configuration, not data: they are
// written by the host while the generator is stopped and are therefore stable
// across the crossing. Writing them while RUN is asserted is a software bug
// that will produce a torn value -- set them first, then set RUN.
// =========================================================================
xpm_cdc_array_single #(.DEST_SYNC_FF(4), .SRC_INPUT_REG(1), .WIDTH(4))
    inst_ctrl_tx (.src_clk(aclk), .src_in({link_up_a, echo_mode, clr, run}),
                  .dest_clk(tclk), .dest_out({link_up_t, echo_t, clr_t, run_t}));

xpm_cdc_array_single #(.DEST_SYNC_FF(4), .SRC_INPUT_REG(1), .WIDTH(32))
    inst_nrnd_tx (.src_clk(aclk), .src_in(n_rounds),
                  .dest_clk(tclk), .dest_out(n_rounds_t));

xpm_cdc_array_single #(.DEST_SYNC_FF(4), .SRC_INPUT_REG(1), .WIDTH(32))
    inst_intv_tx (.src_clk(aclk), .src_in(interval),
                  .dest_clk(tclk), .dest_out(interval_t));

xpm_cdc_array_single #(.DEST_SYNC_FF(4), .SRC_INPUT_REG(1), .WIDTH(8))
    inst_swrd_tx (.src_clk(aclk), .src_in(syn_words),
                  .dest_clk(tclk), .dest_out(syn_words_t));

xpm_cdc_array_single #(.DEST_SYNC_FF(4), .SRC_INPUT_REG(1), .WIDTH(3))
    inst_ctrl_rx (.src_clk(aclk), .src_in({link_up_a, clr, arm}),
                  .dest_clk(rclk), .dest_out({link_up_r, clr_r, arm_r}));

xpm_cdc_array_single #(.DEST_SYNC_FF(4), .SRC_INPUT_REG(1), .WIDTH(8))
    inst_swrd_rx (.src_clk(aclk), .src_in(syn_words),
                  .dest_clk(rclk), .dest_out(syn_words_r));

// =========================================================================
// CSR crossing layer: GT domains -> aclk
//
// Gray for anything that is a +1 counter, handshake for anything that is not.
// A plain xpm_cdc_array_single on a 32-bit counter tears mid-count and produces
// readings that never existed.
//
// SIM_LOSSLESS_GRAY_CHK is off because CLEAR jumps these counters straight to
// zero, which is a legitimate multi-bit step the checker would flag.
// =========================================================================
xpm_cdc_gray #(.DEST_SYNC_FF(4), .INIT_SYNC_FF(0), .REG_OUTPUT(1),
               .SIM_ASSERT_CHK(0), .SIM_LOSSLESS_GRAY_CHK(0), .WIDTH(32))
    inst_txf_a (.src_clk(tclk), .src_in_bin(tx_frames),
                .dest_clk(aclk), .dest_out_bin(tx_frames_a));

xpm_cdc_gray #(.DEST_SYNC_FF(4), .INIT_SYNC_FF(0), .REG_OUTPUT(1),
               .SIM_ASSERT_CHK(0), .SIM_LOSSLESS_GRAY_CHK(0), .WIDTH(32))
    inst_txd_a (.src_clk(tclk), .src_in_bin(tx_dropped),
                .dest_clk(aclk), .dest_out_bin(tx_dropped_a));

xpm_cdc_gray #(.DEST_SYNC_FF(4), .INIT_SYNC_FF(0), .REG_OUTPUT(1),
               .SIM_ASSERT_CHK(0), .SIM_LOSSLESS_GRAY_CHK(0), .WIDTH(32))
    inst_rxf_a (.src_clk(rclk), .src_in_bin(rx_frames),
                .dest_clk(aclk), .dest_out_bin(rx_frames_a));

xpm_cdc_gray #(.DEST_SYNC_FF(4), .INIT_SYNC_FF(0), .REG_OUTPUT(1),
               .SIM_ASSERT_CHK(0), .SIM_LOSSLESS_GRAY_CHK(0), .WIDTH(32))
    inst_rxe_a (.src_clk(rclk), .src_in_bin(rx_errors),
                .dest_clk(aclk), .dest_out_bin(rx_errors_a));

xpm_cdc_gray #(.DEST_SYNC_FF(4), .INIT_SYNC_FF(0), .REG_OUTPUT(1),
               .SIM_ASSERT_CHK(0), .SIM_LOSSLESS_GRAY_CHK(0), .WIDTH(32))
    inst_rxg_a (.src_clk(rclk), .src_in_bin(rx_gaps),
                .dest_clk(aclk), .dest_out_bin(rx_gaps_a));

xpm_cdc_gray #(.DEST_SYNC_FF(4), .INIT_SYNC_FF(0), .REG_OUTPUT(1),
               .SIM_ASSERT_CHK(0), .SIM_LOSSLESS_GRAY_CHK(0), .WIDTH(32))
    inst_rxm_a (.src_clk(rclk), .src_in_bin(rx_mismatch),
                .dest_clk(aclk), .dest_out_bin(rx_mismatch_a));

// Not counters: an arbitrary 32-bit value that changes in one step.
//
// braid_cdc_event presents dest_data only on the cycle dest_valid is high, so
// both need a holding register in aclk for the CSR read mux to see. Those
// registers are also where CLEAR takes effect for these two: the bench pulses
// CLEAR and then polls RTT_CYCLES for a non-zero value as its completion
// signal, so a stale value surviving a clear reads as an instant, wrong answer.
// That exact bug already cost one debugging session.
logic [31:0] rtt_cycles_x, last_round_x;
logic        rtt_valid_a,  last_round_valid_a;

// src_valid is a LEVEL for both, cleared by src_accept. A one-cycle pulse gets
// discarded if the crossing happens to be busy, and for a status register the
// consequence is not a lost sample but a PERMANENTLY stale one: the dropped
// update is the last one there will ever be, so the host reads an old round
// number or an old RTT forever and has no way to tell.
braid_cdc_event #(.WIDTH(32)) inst_rtt_a (
    .src_clk(tclk), .src_rstn(trstn), .src_valid(rtt_new), .src_data(rtt_cycles),
    .src_busy(), .src_accept(rtt_ack),
    .dest_clk(aclk), .dest_valid(rtt_valid_a), .dest_data(rtt_cycles_x)
);

braid_cdc_event #(.WIDTH(32)) inst_lrnd_a (
    .src_clk(rclk), .src_rstn(rrstn), .src_valid(last_round_new), .src_data(last_round),
    .src_busy(), .src_accept(last_round_ack),
    .dest_clk(aclk), .dest_valid(last_round_valid_a), .dest_data(last_round_x)
);

always_ff @(posedge aclk) begin
    if (!aresetn || clr) begin
        rtt_cycles_a <= '0;
        last_round_a <= '0;
    end else begin
        if (rtt_valid_a)        rtt_cycles_a <= rtt_cycles_x;
        if (last_round_valid_a) last_round_a <= last_round_x;
    end
end

// =========================================================================
// Echo crossing: braid_rx_clk -> braid_tx_clk
//
// The reflector cannot avoid this one. braid_link_tx must be clocked by the
// local transmit clock -- that is what the GT serialiser consumes -- so a
// received syndrome has to change domain before it can go back out. It is the
// ONLY crossing left on the syndrome path, down from four.
//
// It is deliberately unconditional rather than gated on echo mode, because the
// measuring card needs the same event to stop its RTT counter, and taking both
// from one transfer guarantees the timestamp and the payload refer to the same
// round.
//
// COST, measured in sim/tb_braid_cdc.sv rather than assumed: 16.4-18.9 ns,
// mean 18.1. A round trip contains TWO of them -- one on the reflector turning
// the frame around, one on the measurer stopping its counter -- so subtract
// ~36 ns from any reported RTT to get the figure the real system would see.
// The real decoder consumes syndromes in the receive domain and pays neither.
// =========================================================================
// A pulse is correct HERE, unlike the two status crossings above: a syndrome
// that cannot be reflected immediately is stale, and re-offering it later would
// send the decoder an old round dressed up as a current one. Dropping is the
// policy everywhere else in BRAID for the same reason.
braid_cdc_event #(.WIDTH(N_STAB + 20)) inst_echo_cdc (
    .src_clk    (rclk),
    .src_rstn   (rrstn),
    .src_valid  (syn_out_valid),
    .src_data   ({syn_out_round[19:0], syn_out_bits}),
    .src_busy   (echo_busy),
    .src_accept (),
    .dest_clk   (tclk),
    .dest_valid (rx_event_t),
    .dest_data  (echo_word_t)
);

always_ff @(posedge tclk) begin
    if (!trstn) begin
        echo_bits  <= '0;
        echo_valid <= 1'b0;
        echo_round <= '0;
    end else begin
        echo_valid <= echo_t && rx_event_t;
        if (rx_event_t) begin
            echo_bits  <= echo_word_t[N_STAB-1:0];
            echo_round <= echo_word_t[N_STAB+19:N_STAB];
        end
    end
end

// =========================================================================
// Synthetic syndrome generator -- braid_tx_clk
// =========================================================================
always_ff @(posedge tclk) begin
    if (!trstn || !run_t) begin
        gen_timer   <= '0;
        gen_count   <= '0;
        gen_round   <= '0;
        gen_round_q <= '0;
        syn_valid   <= 1'b0;
        syn_bits    <= '0;
    end else begin
        syn_valid <= 1'b0;
        if (link_up_t && (n_rounds_t == 0 || gen_count < n_rounds_t)) begin
            if (gen_timer >= interval_t) begin
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
// Latency measurement -- braid_tx_clk
//
// Single outstanding round: the host sends one, waits for the echo, reads the
// result. t_start is taken when the round leaves, and the delta when the echo
// of that same round returns. Both timestamps come from this card's transmit
// clock, so no clock sync between hosts is needed -- but note the units are
// tx_clk cycles (3.879 ns), NOT aclk cycles. The host converts.
// =========================================================================
always_ff @(posedge tclk) begin
    if (!trstn) cyc_cnt <= '0;
    else        cyc_cnt <= cyc_cnt + 32'd1;
end

always_ff @(posedge tclk) begin
    if (!trstn || clr_t) begin
        t_start    <= '0;
        t_start_v  <= 1'b0;
        rtt_cycles <= '0;
        rtt_new    <= 1'b0;
    end else begin
        if (rtt_ack) rtt_new <= 1'b0;
        // A locally generated round leaves: start the clock. Not armed in echo
        // mode, where this card is the reflector rather than the measurer.
        if (syn_valid && !echo_t) begin
            t_start   <= cyc_cnt;
            t_start_v <= 1'b1;
        end
        // Its echo comes back.
        if (rx_event_t && t_start_v && !echo_t) begin
            rtt_cycles <= cyc_cnt - t_start;
            rtt_new    <= 1'b1;
            t_start_v  <= 1'b0;
        end
    end
end

// =========================================================================
// Checker -- braid_rx_clk
// =========================================================================
always_ff @(posedge rclk) begin
    if (!rrstn || !arm_r || clr_r) begin
        rx_mismatch    <= '0;
        last_round     <= '0;
        last_round_new <= 1'b0;
    end else begin
        if (last_round_ack) last_round_new <= 1'b0;
        if (syn_out_valid) begin
            last_round     <= syn_out_round;
            last_round_new <= 1'b1;
            // Compare only the words actually transmitted. With a runtime
            // payload length the upper bits of syn_out_bits are stale from a
            // previous, longer frame and would read as mismatches.
            if ((syn_out_bits & word_mask) != (pattern(syn_out_round[19:0]) & word_mask))
                rx_mismatch <= rx_mismatch + 32'd1;
        end
    end
end

// =========================================================================
// BRAID protocol cores
// =========================================================================
braid_link_tx #(.N_STAB(N_STAB), .N_CORR(N_CORR)) inst_braid_tx (
    .clk(tclk), .rstn(trstn), .link_up(link_up_t), .clr(clr_t),
    .syn_bits(echo_t ? echo_bits  : syn_bits),
    .syn_valid(echo_t ? echo_valid : syn_valid),
    .syn_round(echo_t ? echo_round : gen_round_q),
    .syn_words_sel(syn_words_t),
    .corr_bits(corr_bits), .corr_valid(corr_valid),
    .phy_tx_data(phy_tx_data), .phy_tx_valid(phy_tx_valid),
    .phy_tx_last(phy_tx_last), .phy_tx_ready(phy_tx_ready),
    .tx_frames(tx_frames), .tx_dropped(tx_dropped)
);

braid_link_rx #(.N_STAB(N_STAB), .N_CORR(N_CORR)) inst_braid_rx (
    .clk(rclk), .rstn(rrstn), .link_up(link_up_r), .clr(clr_r),
    .syn_out_bits(syn_out_bits), .syn_out_valid(syn_out_valid),
    .syn_out_round(syn_out_round), .syn_out_gap(syn_out_gap),
    .corr_out_bits(corr_out_bits), .corr_out_valid(corr_out_valid),
    .phy_rx_data(phy_rx_data), .phy_rx_valid(phy_rx_valid),
    .phy_rx_last(phy_rx_last), .phy_rx_err(phy_rx_err),
    .rx_frames(rx_frames), .rx_errors(rx_errors), .rx_gaps(rx_gaps)
);

// The shell routes the BRAID GTY PHY out on the same 256-bit AXIS ports the
// Aurora integration used -- but on the GT clocks, not aclk. The shim is pure
// rewiring and therefore has no clock of its own.
braid_phy_shim inst_phy (
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
