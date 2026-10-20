/**
 * Coyote Example 16: QLINK — Phase D adds a minimal slot schedule and
 * a barrier timer on top of Phase C's TICK calibration.
 *
 * Coyote-side wrapper around the portable qlink_link_tx / qlink_link_rx
 * cores. Everything Coyote-specific lives HERE; the cores stay free of
 * Coyote types so they can be copied verbatim into a bare RFSoC project.
 *
 * =========================================================================
 * PHASE C — WHAT'S NEW
 *
 *   * TICK calibration (R15, qlink_tick_cal.sv): software triggers a
 *     calibration round via CAL_CTRL; the TX side emits a TYPE_CTL / TICK
 *     probe tagged with the local tx-clock cycle; the peer echoes it;
 *     the FSM computes one-way D = (RTT - T_PEER) / 2. The measured D
 *     lands in CAL_D_SHADOW immediately but only becomes CAL_D (active)
 *     at the next round boundary — so a calibration in flight never
 *     affects an epoch already in progress.
 *   * Re-train dirty bit: a GT re-train invalidates the TICK calibration
 *     because the receiver pipeline / elastic buffer state may have
 *     shifted. We detect falling edges on aurora_channel_up (already
 *     aclk-synchronised by qlink_gty_wrapper) and latch retrain_sticky
 *     until the host clears it. While sticky, cal_valid stays 0 and any
 *     in-flight calibration is forced back to IDLE.
 *   * TICK echo path: whenever a TYPE_CTL / TICK probe arrives (FLAGS[0]
 *     set, FLAGS[1] clear), the vFPGA echoes it immediately with
 *     FLAGS[1] set. The echo carries the original ROUND unchanged, so
 *     the far-side CAL FSM can match it against its sent_cycle.
 *
 * =========================================================================
 * PHASE A frame layout (unchanged):
 *   HDR (TYPE/FLAGS/SRC/DST/EPOCH, 4 B) + ROUND (4 B) + PAYLOAD (52 B)
 *     + CRC-32 (4 B) = 64 B total. 14 payload words on the wire.
 *
 * TYPE field (§4): SYN=1, FRM=2, FUS=3, CTL=4.
 *
 * TICK encoding (Phase C): a frame is a TICK iff
 *   TYPE == CTL && FLAGS[0] == 1
 * and the echo direction is distinguished by FLAGS[1] (0 = probe,
 * 1 = reply). ROUND carries the sender's cycle timestamp. PAYLOAD is
 * zero (reserved for peer-perceived delay later).
 *
 * =========================================================================
 * CLOCK DOMAINS — read this before touching anything below.
 *
 *   aclk        400 MHz        AXI4-Lite CSR block ONLY (+ retrain detect,
 *                              because aurora_channel_up already lives here)
 *   qlink_tx_clk 390.625 MHz   generator, qlink_link_tx, RTT, TICK FSM
 *   qlink_rx_clk 390.625 MHz   qlink_link_rx, checker, TICK RX filter
 *                              (RECOVERED from the peer)
 *
 * qlink_tx_clk and qlink_rx_clk are the same nominal frequency but are
 * NOT the same clock: rx is recovered from the incoming serial stream
 * and tracks the far card's oscillator, so the two drift by up to a
 * few hundred ppm. Every signal that moves between the three domains
 * below goes through an XPM macro or a qlink_cdc_event wrapper.
 * =========================================================================
 *
 * Register map (host CSR index = byte offset / 8):
 *   0  CTRL        RW : bit0=run, bit1=arm, bit2=clear, bit3=echo
 *   1  STATUS      RO : bit0=channel_up, bits[4:1]=PHY debug, bit5=link_up
 *   2  N_ROUNDS    RW : rounds to generate (0 = free-run until stopped)
 *   3  INTERVAL    RW : qlink_tx_clk cycles between generated rounds
 *   4  TX_FRAMES   RO
 *   5  TX_DROPPED  RO
 *   6  RX_FRAMES   RO
 *   7  RX_ERRORS   RO
 *   8  RX_MISMATCH RO
 *   9  LAST_ROUND  RO
 *   10 LAST_TYPE   RO
 *   11 RTT_CYCLES  RO
 *   12 LOOPBACK    RW : GT LOOPBACK[2:0], UG578
 *   13 SCRATCH     RW
 *   14 CAL_CTRL    RW : WRITE bit0=trigger_cal, bit1=retrain_clear
 *                      READ  bit0=cal_valid, bit1=retrain_sticky,
 *                            bits[3:2]=cal_state, bit4=tx_tick_req
 *   15 CAL_D       RO : one-way delay D in tx_clk cycles (active)
 *   16 CAL_D_SHADOW RO: last measured D, not yet committed
 *   17 RETRAIN_CNT RO : monotonic re-train event counter
 *   18 RX_IN_ORDER RO : non-TICK frames arriving at expected_round
 *   19 RX_STALE    RO : non-TICK frames with round < expected (modular)
 *   20 RX_FUTURE   RO : non-TICK frames with round > expected (modular)
 *   21 RX_MISSED   RO : erasures at barrier close + skipped-round gaps
 *   22 EXPECTED    RO : current expected_round (debug)
 *   23 RX_SYN      RO : non-TICK §4 class counters (SYN only)
 *   24 RX_FRM      RO : non-TICK §4 class counters (FRM only)
 *   25 RX_FUS      RO : non-TICK §4 class counters (FUS only)
 *   26 RX_CTL      RO : CTL class, including TICK (sanity cross-check)
 *   27 RX_TRUNC    RO : W_CUTOFF consecutive barrier closes (hard cutoff)
 *   28 FENCE_CNT   RO : scheduler epoch rollovers since clear
 *   29 FENCE_BAD   RO : epochs that contained a skipped round
 *   30..31 reserved
 */

// 52 bytes = 416 bits of payload per frame.
localparam int PAYLOAD_BITS = 416;

// Protocol classes (§4). SYN upward, FRM downward, FUS lateral, CTL off-deadline.
localparam logic [3:0] TYPE_SYN = 4'h1;
localparam logic [3:0] TYPE_FRM = 4'h2;
localparam logic [3:0] TYPE_FUS = 4'h3;
localparam logic [3:0] TYPE_CTL = 4'h4;

// TICK flag positions inside the FLAGS nibble of a CTL frame.
localparam logic [3:0] FLAGS_TICK_PROBE = 4'b0001;   // is_tick=1, is_echo=0
localparam logic [3:0] FLAGS_TICK_ECHO  = 4'b0011;   // is_tick=1, is_echo=1

// Peer internal rx→tx turnaround in tx-clock cycles. The two cards run
// identical RTL, so this is the fixed receive-to-echo pipeline inside
// the peer when it reflects a TICK probe. ~16 cycles is a conservative
// upper bound at Phase A frame size; a build with wire-measured turn
// time can refine it. Treating this as a parameter keeps vfpga_top
// free of implementation assumptions downstream.
localparam int T_PEER_CYCLES = 20;

// Phase D slot schedule: an epoch is EPOCH_ROUNDS rounds, and r₀ is the
// first fire of each epoch. For the minimal single-source single-slot
// schedule, SYN fires once per round and the only interesting boundary
// is the epoch wrap — that's when cal_d_shadow commits to cal_d_active.
// Phase E can refine this with sub-slot scheduling.
localparam int EPOCH_ROUNDS_LOG2 = 4;    // 16 rounds / epoch

// RX barrier timeout in rx_clk cycles. With a 1 µs SYN cadence (391
// cycles at 390.625 MHz) a two-slot wait is a conservative default:
// tolerates one slot of skew without a false alarm.
localparam int T_BAR_CYCLES = 1024;

// =========================================================================
// Constants and register map
// =========================================================================
localparam integer N_REGS        = 32;
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
localparam integer REG_RX_MISMATCH = 8;
localparam integer REG_LAST_ROUND  = 9;
localparam integer REG_LAST_TYPE   = 10;
localparam integer REG_RTT_CYCLES  = 11;
localparam integer REG_LOOPBACK    = 12;
localparam integer REG_SCRATCH0    = 13;
localparam integer REG_CAL_CTRL    = 14;
localparam integer REG_CAL_D       = 15;
localparam integer REG_CAL_D_SHDW  = 16;
localparam integer REG_RETRAIN_CNT = 17;
localparam integer REG_RX_IN_ORDER = 18;
localparam integer REG_RX_STALE    = 19;
localparam integer REG_RX_FUTURE   = 20;
localparam integer REG_RX_MISSED   = 21;
localparam integer REG_EXPECTED    = 22;
// Phase E: per-class counters + cutoff + fence stub
localparam integer REG_RX_SYN      = 23;
localparam integer REG_RX_FRM      = 24;
localparam integer REG_RX_FUS      = 25;
localparam integer REG_RX_CTL      = 26;
localparam integer REG_RX_TRUNC    = 27;
localparam integer REG_FENCE_CNT   = 28;
localparam integer REG_FENCE_BAD   = 29;

// Hard-cutoff and fence-epoch defaults. W_CUTOFF has to be chosen with
// the open-items pass; 4 is a placeholder big enough to be rare under
// correct behaviour and small enough to catch an outage in a Stim run.
localparam int W_CUTOFF_SCHED = 4;

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
logic [31:0] rx_frames_a, rx_errors_a, rx_mismatch_a;
logic [31:0] rtt_cycles_a, last_round_a;
logic [3:0]  last_type_a;

// Phase C: retrain detect, cal readback.
logic        channel_up_q;
logic        retrain_sticky_a;
logic [31:0] retrain_count_a;
logic        trigger_cal_pulse_a;
logic        retrain_clear_pulse_a;
logic [31:0] cal_d_active_a, cal_d_shadow_a;
logic        cal_valid_a;
logic [1:0]  cal_state_dbg_a;
logic        tx_tick_req_a;

wire tclk  = qlink_tx_clk;
wire rclk  = qlink_rx_clk;
wire trstn = qlink_tx_rstn;
wire rrstn = qlink_rx_rstn;

wire run       = ctrl_reg[REG_CTRL][0];
wire arm       = ctrl_reg[REG_CTRL][1];
wire clr       = ctrl_reg[REG_CTRL][2];
wire echo_mode = ctrl_reg[REG_CTRL][3];
wire [31:0] n_rounds  = ctrl_reg[REG_N_ROUNDS][31:0];
wire [31:0] interval  = ctrl_reg[REG_INTERVAL][31:0];

// Quasi-static; qlink_gty_wrapper synchronises it and resets the GT on change.
assign qlink_loopback_sel = ctrl_reg[REG_LOOPBACK][2:0];

wire [ADDR_MSB-1:0] wr_idx = axi_awaddr[ADDR_LSB+:ADDR_MSB];
wire [ADDR_MSB-1:0] rd_idx = axi_araddr[ADDR_LSB+:ADDR_MSB];
wire wr_allowed = (wr_idx == REG_CTRL) || (wr_idx == REG_N_ROUNDS) ||
                  (wr_idx == REG_INTERVAL) ||
                  (wr_idx == REG_LOOPBACK) || (wr_idx == REG_SCRATCH0) ||
                  (wr_idx == REG_CAL_CTRL);

// channel_up is already synchronised into aclk by qlink_gty_wrapper.
wire link_up_a = aurora_channel_up;

// =========================================================================
// Declarations -- qlink_tx_clk domain
// =========================================================================
logic [31:0]            phy_tx_data;
logic                   phy_tx_valid, phy_tx_last, phy_tx_ready;
logic [31:0]            phy_tx_hdr, phy_tx_cks;

logic [3:0]             tx_type_t, tx_flags_t;
logic [7:0]             tx_src_t, tx_dst_t, tx_epoch_t;
logic [31:0]            tx_round_t;
logic [PAYLOAD_BITS-1:0] tx_payload_t;
logic                   tx_valid_t;
logic [31:0]            tx_frames, tx_dropped;

logic [31:0]            gen_timer, gen_count;
logic [31:0]            gen_round, gen_round_q;

logic [31:0]            cyc_cnt, t_start, rtt_cycles;
logic                   t_start_v, rtt_new, rtt_ack;

// Control and configuration after crossing from aclk.
logic                   run_t, clr_t, echo_t, link_up_t;
logic [31:0]            n_rounds_t, interval_t;

// Echoed payload after crossing from qlink_rx_clk.
logic                   rx_event_t;
logic [PAYLOAD_BITS+31:0] echo_word_t;    // {round[31:0], payload[415:0]}
logic [PAYLOAD_BITS-1:0] echo_payload;
logic                   echo_valid;
logic [31:0]            echo_round;

// Phase C: TICK calibration FSM I/O (tclk-side).
logic                   trigger_cal_t;
logic                   retrain_sticky_t;
logic                   round_boundary_t;
logic                   tx_tick_req_t;
logic                   tx_tick_fire_t;
logic [31:0]            tx_tick_cycle_t;
logic                   rx_echo_valid_t;
logic [31:0]            rx_echo_cycle_t;
logic [31:0]            cal_d_active_t, cal_d_shadow_t;
logic                   cal_valid_t;
logic [1:0]             cal_state_dbg_t;

// TICK echo pending in tclk after an incoming probe (set from rclk).
logic                   tick_echo_pending_t;
logic [31:0]            tick_echo_cycle_t;
logic                   tick_echo_set_t;
logic [31:0]            tick_echo_round_t;

// =========================================================================
// Declarations -- qlink_rx_clk domain
// =========================================================================
logic [31:0]             phy_rx_data;
logic                    phy_rx_valid, phy_rx_eof, phy_rx_err, phy_rx_sof;
logic [31:0]             phy_rx_hdr, phy_rx_cks;

logic                    rx_valid, rx_bad;
logic [3:0]              rx_type, rx_flags;
logic [7:0]              rx_src, rx_dst, rx_epoch;
logic [31:0]             rx_round;
logic [PAYLOAD_BITS-1:0] rx_payload;
logic [31:0]             rx_frames, rx_errors;

logic [31:0]             rx_mismatch, last_round;
logic [3:0]              last_type;
logic                    last_round_new, last_round_ack, echo_busy;

// Phase D: RX scheduler outputs (rclk-side).
logic [31:0]             expected_round_r;
logic [31:0]             rx_in_order_r, rx_stale_r, rx_future_r, rx_missed_r;

// Phase E: scheduler cutoff + fence outputs (rclk-side).
logic [31:0]             rx_truncated_r, fence_count_r, fence_bad_r;

// Phase E: per-§4-class RX counters (rclk-side).
logic [31:0]             rx_syn_r, rx_frm_r, rx_fus_r, rx_ctl_r;

// Phase D: counter readouts after CDC to aclk.
logic [31:0]             rx_in_order_a, rx_stale_a, rx_future_a, rx_missed_a;
logic [31:0]             expected_round_a;

// Phase E: cutoff + fence + per-class readouts after CDC to aclk.
logic [31:0]             rx_truncated_a, fence_count_a, fence_bad_a;
logic [31:0]             rx_syn_a, rx_frm_a, rx_fus_a, rx_ctl_a;

logic                    arm_r, clr_r, link_up_r;

// Phase C: TICK filters in rclk.
wire rx_is_tick_probe = rx_valid && (rx_type == TYPE_CTL) &&
                        (rx_flags == FLAGS_TICK_PROBE);
wire rx_is_tick_echo  = rx_valid && (rx_type == TYPE_CTL) &&
                        (rx_flags == FLAGS_TICK_ECHO);
// Non-TICK frames feed the normal checker; TICK frames bypass it so a
// probe does not count as a mismatch against the pattern function.
wire rx_data_valid    = rx_valid && !(rx_type == TYPE_CTL && rx_flags[0]);

// Deterministic pattern both ends compute independently from the round
// number, so the checker needs no side channel to know what to expect.
// 416 bits of pseudo-random payload keyed by the 32-bit round.
function automatic logic [PAYLOAD_BITS-1:0] pattern(input logic [31:0] r);
    logic [PAYLOAD_BITS+31:0] p;
    for (int k = 0; k <= (PAYLOAD_BITS/32); k++)
        p[k*32 +: 32] = r ^ (32'h9E3779B9 * (k + 1));
    return p[PAYLOAD_BITS-1:0];
endfunction

// =========================================================================
// AXI4-Lite slave (canonical Coyote structure).
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
            REG_RX_MISMATCH: axi_rdata <= {32'b0, rx_mismatch_a};
            REG_LAST_ROUND:  axi_rdata <= {32'b0, last_round_a};
            REG_LAST_TYPE:   axi_rdata <= {60'b0, last_type_a};
            REG_RTT_CYCLES:  axi_rdata <= {32'b0, rtt_cycles_a};
            // CAL_CTRL READ: status only; the written pulse bits aren't echoed.
            //   bit0 = cal_valid, bit1 = retrain_sticky,
            //   bits[3:2] = cal_state, bit4 = tx_tick_req (debug)
            REG_CAL_CTRL:    axi_rdata <= {59'b0, tx_tick_req_a, cal_state_dbg_a,
                                           retrain_sticky_a, cal_valid_a};
            REG_CAL_D:       axi_rdata <= {32'b0, cal_d_active_a};
            REG_CAL_D_SHDW:  axi_rdata <= {32'b0, cal_d_shadow_a};
            REG_RETRAIN_CNT: axi_rdata <= {32'b0, retrain_count_a};
            REG_RX_IN_ORDER: axi_rdata <= {32'b0, rx_in_order_a};
            REG_RX_STALE:    axi_rdata <= {32'b0, rx_stale_a};
            REG_RX_FUTURE:   axi_rdata <= {32'b0, rx_future_a};
            REG_RX_MISSED:   axi_rdata <= {32'b0, rx_missed_a};
            REG_EXPECTED:    axi_rdata <= {32'b0, expected_round_a};
            REG_RX_SYN:      axi_rdata <= {32'b0, rx_syn_a};
            REG_RX_FRM:      axi_rdata <= {32'b0, rx_frm_a};
            REG_RX_FUS:      axi_rdata <= {32'b0, rx_fus_a};
            REG_RX_CTL:      axi_rdata <= {32'b0, rx_ctl_a};
            REG_RX_TRUNC:    axi_rdata <= {32'b0, rx_truncated_a};
            REG_FENCE_CNT:   axi_rdata <= {32'b0, fence_count_a};
            REG_FENCE_BAD:   axi_rdata <= {32'b0, fence_bad_a};
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
// Phase C: pulse generators for CAL_CTRL W1C bits (aclk)
//
// A single-cycle write to CAL_CTRL whose data bit 0 is set produces a
// one-cycle trigger_cal pulse; bit 1 produces a one-cycle retrain_clear.
// The ctrl_reg still stores the written value, but the read mux returns
// status instead, so the written bits never actually surface.
// =========================================================================
wire cal_ctrl_wr = ctrl_reg_wren && wr_allowed && (wr_idx == REG_CAL_CTRL);
always_ff @(posedge aclk) begin
    if (!aresetn) begin
        trigger_cal_pulse_a   <= 1'b0;
        retrain_clear_pulse_a <= 1'b0;
    end else begin
        trigger_cal_pulse_a   <= cal_ctrl_wr && axi_ctrl.wstrb[0] && axi_ctrl.wdata[0];
        retrain_clear_pulse_a <= cal_ctrl_wr && axi_ctrl.wstrb[0] && axi_ctrl.wdata[1];
    end
end

// =========================================================================
// Phase C: retrain detect (aclk, R15)
//
// aurora_channel_up is already aclk-synchronised by qlink_gty_wrapper, so
// edge detection fits locally with no extra CDC. The sticky bit survives
// until software writes CAL_CTRL[1]; the count is monotonic.
// =========================================================================
always_ff @(posedge aclk) begin
    if (!aresetn) begin
        channel_up_q     <= 1'b0;
        retrain_sticky_a <= 1'b0;
        retrain_count_a  <= '0;
    end else begin
        channel_up_q <= aurora_channel_up;
        if (channel_up_q && !aurora_channel_up) begin
            retrain_sticky_a <= 1'b1;
            retrain_count_a  <= retrain_count_a + 32'd1;
        end else if (retrain_clear_pulse_a) begin
            retrain_sticky_a <= 1'b0;
        end
    end
end

// =========================================================================
// CSR crossing layer: aclk -> GT domains
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

xpm_cdc_array_single #(.DEST_SYNC_FF(4), .SRC_INPUT_REG(1), .WIDTH(3))
    inst_ctrl_rx (.src_clk(aclk), .src_in({link_up_a, clr, arm}),
                  .dest_clk(rclk), .dest_out({link_up_r, clr_r, arm_r}));

// retrain_sticky as a level into tclk so the TICK FSM can read it.
xpm_cdc_single #(.DEST_SYNC_FF(4), .SRC_INPUT_REG(1))
    inst_retr_tx (.src_clk(aclk), .src_in(retrain_sticky_a),
                  .dest_clk(tclk), .dest_out(retrain_sticky_t));

// trigger_cal as a one-shot pulse via qlink_cdc_event.
qlink_cdc_event #(.WIDTH(1)) inst_trig_cdc (
    .src_clk    (aclk),
    .src_rstn   (aresetn),
    .src_valid  (trigger_cal_pulse_a),
    .src_data   (1'b0),
    .src_busy   (),
    .src_accept (),
    .dest_clk   (tclk),
    .dest_valid (trigger_cal_t),
    .dest_data  ()
);

// =========================================================================
// CSR crossing layer: GT domains -> aclk
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
    inst_rxm_a (.src_clk(rclk), .src_in_bin(rx_mismatch),
                .dest_clk(aclk), .dest_out_bin(rx_mismatch_a));

// Phase C: cal_d_active, cal_d_shadow — not counters, slow signals; use
// xpm_cdc_array_single as the Coyote shell does for quasi-static CSR
// values. Updates happen at round boundaries (every ~2.6 µs here) which
// is many sync-FF settling times.
xpm_cdc_array_single #(.DEST_SYNC_FF(4), .SRC_INPUT_REG(1), .WIDTH(32))
    inst_cald_a (.src_clk(tclk), .src_in(cal_d_active_t),
                 .dest_clk(aclk), .dest_out(cal_d_active_a));
xpm_cdc_array_single #(.DEST_SYNC_FF(4), .SRC_INPUT_REG(1), .WIDTH(32))
    inst_calsh_a (.src_clk(tclk), .src_in(cal_d_shadow_t),
                  .dest_clk(aclk), .dest_out(cal_d_shadow_a));

xpm_cdc_single #(.DEST_SYNC_FF(4), .SRC_INPUT_REG(1))
    inst_calv_a (.src_clk(tclk), .src_in(cal_valid_t),
                 .dest_clk(aclk), .dest_out(cal_valid_a));

xpm_cdc_array_single #(.DEST_SYNC_FF(4), .SRC_INPUT_REG(1), .WIDTH(2))
    inst_cals_a (.src_clk(tclk), .src_in(cal_state_dbg_t),
                 .dest_clk(aclk), .dest_out(cal_state_dbg_a));

xpm_cdc_single #(.DEST_SYNC_FF(4), .SRC_INPUT_REG(1))
    inst_tickq_a (.src_clk(tclk), .src_in(tx_tick_req_t),
                  .dest_clk(aclk), .dest_out(tx_tick_req_a));

// Phase D: scheduler counter crossings (rclk -> aclk). Monotonic
// counters go through xpm_cdc_gray; expected_round is not monotonic
// (it can decrement when the host clears) so it rides the slower
// quasi-static path.
xpm_cdc_gray #(.DEST_SYNC_FF(4), .INIT_SYNC_FF(0), .REG_OUTPUT(1),
               .SIM_ASSERT_CHK(0), .SIM_LOSSLESS_GRAY_CHK(0), .WIDTH(32))
    inst_rxio_a (.src_clk(rclk), .src_in_bin(rx_in_order_r),
                 .dest_clk(aclk), .dest_out_bin(rx_in_order_a));
xpm_cdc_gray #(.DEST_SYNC_FF(4), .INIT_SYNC_FF(0), .REG_OUTPUT(1),
               .SIM_ASSERT_CHK(0), .SIM_LOSSLESS_GRAY_CHK(0), .WIDTH(32))
    inst_rxst_a (.src_clk(rclk), .src_in_bin(rx_stale_r),
                 .dest_clk(aclk), .dest_out_bin(rx_stale_a));
xpm_cdc_gray #(.DEST_SYNC_FF(4), .INIT_SYNC_FF(0), .REG_OUTPUT(1),
               .SIM_ASSERT_CHK(0), .SIM_LOSSLESS_GRAY_CHK(0), .WIDTH(32))
    inst_rxft_a (.src_clk(rclk), .src_in_bin(rx_future_r),
                 .dest_clk(aclk), .dest_out_bin(rx_future_a));
xpm_cdc_gray #(.DEST_SYNC_FF(4), .INIT_SYNC_FF(0), .REG_OUTPUT(1),
               .SIM_ASSERT_CHK(0), .SIM_LOSSLESS_GRAY_CHK(0), .WIDTH(32))
    inst_rxms_a (.src_clk(rclk), .src_in_bin(rx_missed_r),
                 .dest_clk(aclk), .dest_out_bin(rx_missed_a));
xpm_cdc_array_single #(.DEST_SYNC_FF(4), .SRC_INPUT_REG(1), .WIDTH(32))
    inst_exp_a (.src_clk(rclk), .src_in(expected_round_r),
                .dest_clk(aclk), .dest_out(expected_round_a));

// Phase E: cutoff / fence counters (monotonic → gray) + per-class
// counters (monotonic → gray). All four §4 classes are counted
// independently in rclk so a bytewise sanity check against RX_FRAMES
// stays local and the host does not need to post-process TICKs.
xpm_cdc_gray #(.DEST_SYNC_FF(4), .INIT_SYNC_FF(0), .REG_OUTPUT(1),
               .SIM_ASSERT_CHK(0), .SIM_LOSSLESS_GRAY_CHK(0), .WIDTH(32))
    inst_rxtr_a (.src_clk(rclk), .src_in_bin(rx_truncated_r),
                 .dest_clk(aclk), .dest_out_bin(rx_truncated_a));
xpm_cdc_gray #(.DEST_SYNC_FF(4), .INIT_SYNC_FF(0), .REG_OUTPUT(1),
               .SIM_ASSERT_CHK(0), .SIM_LOSSLESS_GRAY_CHK(0), .WIDTH(32))
    inst_fnc_a  (.src_clk(rclk), .src_in_bin(fence_count_r),
                 .dest_clk(aclk), .dest_out_bin(fence_count_a));
xpm_cdc_gray #(.DEST_SYNC_FF(4), .INIT_SYNC_FF(0), .REG_OUTPUT(1),
               .SIM_ASSERT_CHK(0), .SIM_LOSSLESS_GRAY_CHK(0), .WIDTH(32))
    inst_fnbd_a (.src_clk(rclk), .src_in_bin(fence_bad_r),
                 .dest_clk(aclk), .dest_out_bin(fence_bad_a));
xpm_cdc_gray #(.DEST_SYNC_FF(4), .INIT_SYNC_FF(0), .REG_OUTPUT(1),
               .SIM_ASSERT_CHK(0), .SIM_LOSSLESS_GRAY_CHK(0), .WIDTH(32))
    inst_rxsyn_a(.src_clk(rclk), .src_in_bin(rx_syn_r),
                 .dest_clk(aclk), .dest_out_bin(rx_syn_a));
xpm_cdc_gray #(.DEST_SYNC_FF(4), .INIT_SYNC_FF(0), .REG_OUTPUT(1),
               .SIM_ASSERT_CHK(0), .SIM_LOSSLESS_GRAY_CHK(0), .WIDTH(32))
    inst_rxfrm_a(.src_clk(rclk), .src_in_bin(rx_frm_r),
                 .dest_clk(aclk), .dest_out_bin(rx_frm_a));
xpm_cdc_gray #(.DEST_SYNC_FF(4), .INIT_SYNC_FF(0), .REG_OUTPUT(1),
               .SIM_ASSERT_CHK(0), .SIM_LOSSLESS_GRAY_CHK(0), .WIDTH(32))
    inst_rxfus_a(.src_clk(rclk), .src_in_bin(rx_fus_r),
                 .dest_clk(aclk), .dest_out_bin(rx_fus_a));
xpm_cdc_gray #(.DEST_SYNC_FF(4), .INIT_SYNC_FF(0), .REG_OUTPUT(1),
               .SIM_ASSERT_CHK(0), .SIM_LOSSLESS_GRAY_CHK(0), .WIDTH(32))
    inst_rxctl_a(.src_clk(rclk), .src_in_bin(rx_ctl_r),
                 .dest_clk(aclk), .dest_out_bin(rx_ctl_a));

// Not counters: an arbitrary 32-bit value that changes in one step.
logic [31:0] rtt_cycles_x;
logic [35:0] last_x;        // {type[3:0], round[31:0]}
logic        rtt_valid_a,  last_valid_a;

qlink_cdc_event #(.WIDTH(32)) inst_rtt_a (
    .src_clk(tclk), .src_rstn(trstn), .src_valid(rtt_new), .src_data(rtt_cycles),
    .src_busy(), .src_accept(rtt_ack),
    .dest_clk(aclk), .dest_valid(rtt_valid_a), .dest_data(rtt_cycles_x)
);

qlink_cdc_event #(.WIDTH(36)) inst_lrnd_a (
    .src_clk(rclk), .src_rstn(rrstn), .src_valid(last_round_new),
    .src_data({last_type, last_round}),
    .src_busy(), .src_accept(last_round_ack),
    .dest_clk(aclk), .dest_valid(last_valid_a), .dest_data(last_x)
);

always_ff @(posedge aclk) begin
    if (!aresetn || clr) begin
        rtt_cycles_a <= '0;
        last_round_a <= '0;
        last_type_a  <= '0;
    end else begin
        if (rtt_valid_a)  rtt_cycles_a <= rtt_cycles_x;
        if (last_valid_a) begin
            last_round_a <= last_x[31:0];
            last_type_a  <= last_x[35:32];
        end
    end
end

// =========================================================================
// Echo crossing: qlink_rx_clk -> qlink_tx_clk
//
// Carries {round[31:0], payload[415:0]} = 448 bits for FRM echo mode.
// A TICK probe or echo bypasses this crossing (rx_data_valid filters
// them out) and gets its own, narrower CDCs below.
// =========================================================================
qlink_cdc_event #(.WIDTH(PAYLOAD_BITS + 32)) inst_echo_cdc (
    .src_clk    (rclk),
    .src_rstn   (rrstn),
    .src_valid  (rx_data_valid),
    .src_data   ({rx_round, rx_payload}),
    .src_busy   (echo_busy),
    .src_accept (),
    .dest_clk   (tclk),
    .dest_valid (rx_event_t),
    .dest_data  (echo_word_t)
);

always_ff @(posedge tclk) begin
    if (!trstn) begin
        echo_payload <= '0;
        echo_valid   <= 1'b0;
        echo_round   <= '0;
    end else begin
        echo_valid <= echo_t && rx_event_t;
        if (rx_event_t) begin
            echo_payload <= echo_word_t[PAYLOAD_BITS-1:0];
            echo_round   <= echo_word_t[PAYLOAD_BITS+31:PAYLOAD_BITS];
        end
    end
end

// =========================================================================
// Phase C: TICK probe-arrived crossing (rclk -> tclk)
//
// On any inbound TICK probe, cross the probe's ROUND field to the TX
// domain and latch it as a pending echo request. The TX arbiter clears
// the pending bit when it fires the echo. If a second probe arrives
// before the first was echoed (deeply malformed peer behaviour) the
// later probe replaces the earlier one — nothing in a round schedule
// cares about a dropped TICK echo.
// =========================================================================
qlink_cdc_event #(.WIDTH(32)) inst_tick_echo_cdc (
    .src_clk    (rclk),
    .src_rstn   (rrstn),
    .src_valid  (rx_is_tick_probe),
    .src_data   (rx_round),
    .src_busy   (),
    .src_accept (),
    .dest_clk   (tclk),
    .dest_valid (tick_echo_set_t),
    .dest_data  (tick_echo_round_t)
);

// =========================================================================
// Phase C: TICK echo-arrived crossing (rclk -> tclk)
//
// Separate CDC so the CAL FSM sees echoes without entanglement in the
// probe-echo path. ROUND of the inbound echo is the sent_cycle of the
// original probe, which is what the FSM compares.
// =========================================================================
qlink_cdc_event #(.WIDTH(32)) inst_tick_rx_echo_cdc (
    .src_clk    (rclk),
    .src_rstn   (rrstn),
    .src_valid  (rx_is_tick_echo),
    .src_data   (rx_round),
    .src_busy   (),
    .src_accept (),
    .dest_clk   (tclk),
    .dest_valid (rx_echo_valid_t),
    .dest_data  (rx_echo_cycle_t)
);

// =========================================================================
// Phase D: slot schedule and round boundary (tclk)
//
// Replaces the Phase C free-running decimator with an epoch-wrap
// pulse tied to the generator. r₀ fires when the generator emits a
// SYN whose round is a multiple of 2^EPOCH_ROUNDS_LOG2 — i.e., once
// every EPOCH_ROUNDS rounds. This gives the TICK FSM a deterministic
// commit cadence that lines up with the schedule, not with an
// unrelated wall-clock timer.
// =========================================================================
assign round_boundary_t = tx_valid_t && !echo_t &&
                          (tx_type_t == TYPE_SYN) &&
                          (gen_round_q[EPOCH_ROUNDS_LOG2-1:0] == '0);

// =========================================================================
// Phase C: TICK calibration FSM
// =========================================================================
qlink_tick_cal #(
    .T_PEER   (T_PEER_CYCLES),
    .T_TIMEOUT(1024)
) inst_tick_cal (
    .clk           (tclk),
    .rstn          (trstn),
    .cur_cycle     (cyc_cnt),
    .trigger_cal   (trigger_cal_t),
    .round_boundary(round_boundary_t),
    .retrain_sticky(retrain_sticky_t),
    .tx_tick_req   (tx_tick_req_t),
    .tx_tick_fire  (tx_tick_fire_t),
    .tx_tick_cycle (tx_tick_cycle_t),
    .rx_echo_valid (rx_echo_valid_t),
    .rx_echo_cycle (rx_echo_cycle_t),
    .cal_d_active  (cal_d_active_t),
    .cal_d_shadow  (cal_d_shadow_t),
    .cal_valid     (cal_valid_t),
    .cal_state_dbg (cal_state_dbg_t)
);

// =========================================================================
// Phase C: TICK-echo pending latch (tclk)
//
// Latched from the rclk-crossed probe-arrived event. Cleared when the
// arbiter below emits the echo frame.
// =========================================================================
always_ff @(posedge tclk) begin
    if (!trstn) begin
        tick_echo_pending_t <= 1'b0;
        tick_echo_cycle_t   <= '0;
    end else begin
        if (tick_echo_set_t) begin
            tick_echo_pending_t <= 1'b1;
            tick_echo_cycle_t   <= tick_echo_round_t;
        end
        if (tick_echo_pending_t && tx_valid_t &&
            tx_type_t == TYPE_CTL && tx_flags_t == FLAGS_TICK_ECHO) begin
            tick_echo_pending_t <= 1'b0;
        end
    end
end

// =========================================================================
// Synthetic frame generator and TX arbitration — qlink_tx_clk
//
// Priority (one fire per cycle):
//   1. TICK echo (reply to an inbound probe)      — both roles
//   2. TICK probe (CAL initiator)                 — originator only
//   3. echo_t && echo_valid (FRM reflection)      — reflector only
//   4. SYN generator (interval-driven)            — originator only
//
// TICK echo takes highest priority so the round-trip is minimum-latency.
// TICK probe and SYN generation never collide because they are both
// originator-only, and the probe is at most one frame in flight.
// =========================================================================
always_ff @(posedge tclk) begin
    if (!trstn || !run_t) begin
        gen_timer      <= '0;
        gen_count      <= '0;
        gen_round      <= '0;
        gen_round_q    <= '0;
        tx_valid_t     <= 1'b0;
        tx_payload_t   <= '0;
        tx_round_t     <= '0;
        tx_type_t      <= TYPE_SYN;
        tx_flags_t     <= 4'h0;
        tx_src_t       <= 8'h00;
        tx_dst_t       <= 8'h00;
        tx_epoch_t     <= 8'h00;
        tx_tick_fire_t <= 1'b0;
    end else begin
        tx_valid_t     <= 1'b0;
        tx_tick_fire_t <= 1'b0;

        if (tick_echo_pending_t) begin
            // Highest priority: echo an inbound TICK probe immediately.
            tx_type_t    <= TYPE_CTL;
            tx_flags_t   <= FLAGS_TICK_ECHO;
            tx_round_t   <= tick_echo_cycle_t;
            tx_payload_t <= '0;
            tx_src_t     <= 8'h00;
            tx_dst_t     <= 8'h00;
            tx_epoch_t   <= 8'h00;
            tx_valid_t   <= 1'b1;
        end else if (tx_tick_req_t && !echo_t) begin
            // Originator CAL probe. ROUND carries the local cycle count.
            // tx_tick_fire_t pulses so qlink_tick_cal latches sent_cycle
            // on the same posedge the frame leaves — both read cyc_cnt
            // at the identical edge, so sent_cycle and the frame's ROUND
            // match exactly, and the echo matches on return.
            tx_type_t      <= TYPE_CTL;
            tx_flags_t     <= FLAGS_TICK_PROBE;
            tx_round_t     <= cyc_cnt;
            tx_payload_t   <= '0;
            tx_src_t       <= 8'h00;
            tx_dst_t       <= 8'h00;
            tx_epoch_t     <= 8'h00;
            tx_valid_t     <= 1'b1;
            tx_tick_fire_t <= 1'b1;
        end else if (echo_t) begin
            // Reflector: reflect whatever just arrived, as FRM.
            if (echo_valid) begin
                tx_payload_t <= echo_payload;
                tx_round_t   <= echo_round;
                tx_type_t    <= TYPE_FRM;
                tx_flags_t   <= 4'h0;
                tx_src_t     <= 8'h00;
                tx_dst_t     <= 8'h00;
                tx_epoch_t   <= 8'h00;
                tx_valid_t   <= 1'b1;
            end
        end else if (link_up_t && (n_rounds_t == 0 || gen_count < n_rounds_t)) begin
            // Originator: emit SYN at the configured cadence.
            if (gen_timer >= interval_t) begin
                gen_timer    <= '0;
                tx_payload_t <= pattern(gen_round);
                tx_round_t   <= gen_round;
                gen_round_q  <= gen_round;
                tx_type_t    <= TYPE_SYN;
                tx_flags_t   <= 4'h0;
                tx_src_t     <= 8'h00;
                tx_dst_t     <= 8'h00;
                tx_epoch_t   <= 8'h00;
                tx_valid_t   <= 1'b1;
                gen_round    <= gen_round + 32'd1;
                gen_count    <= gen_count + 32'd1;
            end else begin
                gen_timer <= gen_timer + 32'd1;
            end
        end
    end
end

// =========================================================================
// Latency measurement -- qlink_tx_clk
//
// Single outstanding round: fire, wait for the echo, read the result.
// Only counts non-TICK frames; TICK uses its own measurement via the
// qlink_tick_cal FSM.
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
        // Outbound SYN leaves (not armed in echo mode: this card is the
        // reflector, not the measurer). TICK frames don't start the RTT
        // timer — they have their own measurement path.
        if (tx_valid_t && !echo_t && tx_type_t == TYPE_SYN) begin
            t_start   <= cyc_cnt;
            t_start_v <= 1'b1;
        end
        // Its echo returns via the RX-to-TX crossing (FRM, non-TICK).
        if (rx_event_t && t_start_v && !echo_t) begin
            rtt_cycles <= cyc_cnt - t_start;
            rtt_new    <= 1'b1;
            t_start_v  <= 1'b0;
        end
    end
end

// =========================================================================
// Checker -- qlink_rx_clk
//
// Type-agnostic for non-TICK frames: on any arriving data frame, compare
// the payload against pattern(round). TICK frames bypass the checker
// via rx_data_valid.
// =========================================================================
always_ff @(posedge rclk) begin
    if (!rrstn || !arm_r || clr_r) begin
        rx_mismatch    <= '0;
        last_round     <= '0;
        last_type      <= '0;
        last_round_new <= 1'b0;
    end else begin
        if (last_round_ack) last_round_new <= 1'b0;
        if (rx_data_valid) begin
            last_round     <= rx_round;
            last_type      <= rx_type;
            last_round_new <= 1'b1;
            if (rx_payload != pattern(rx_round))
                rx_mismatch <= rx_mismatch + 32'd1;
        end
    end
end

// =========================================================================
// Phase D: RX scheduler + barrier (rclk)
//
// First consumer of qlink_round_pkg. Classifies each non-TICK data
// frame as in-order / stale / future, and closes a barrier
// T_BAR_CYCLES after the last data arrival to count erasures.
// The counters share arm_r/clr_r with the pattern checker.
// =========================================================================
qlink_rx_sched #(
    .T_BAR_CYCLES     (T_BAR_CYCLES),
    .W_CUTOFF         (W_CUTOFF_SCHED),
    .EPOCH_ROUNDS_LOG2(EPOCH_ROUNDS_LOG2)
) inst_rx_sched (
    .clk           (rclk),
    .rstn          (rrstn && arm_r),
    .clr           (clr_r),
    .rx_valid      (rx_data_valid),
    .rx_round      (rx_round),
    .expected_round(expected_round_r),
    .rx_in_order   (rx_in_order_r),
    .rx_stale      (rx_stale_r),
    .rx_future     (rx_future_r),
    .rx_missed     (rx_missed_r),
    .rx_truncated  (rx_truncated_r),
    .fence_count   (fence_count_r),
    .fence_bad     (fence_bad_r)
);

// =========================================================================
// Phase E: per-§4-class RX counters (rclk)
//
// Classifies every arriving frame (including TICK; see the data vs
// control note below) by its TYPE and bumps the matching counter.
// Lives next to the pattern checker so it shares arm_r / clr_r, and
// sees the same unfiltered rx_valid — TICK traffic is counted in
// RX_CTL for debuggability, since filtering TICK out of RX_CTL would
// make the sum rx_syn + rx_frm + rx_fus + rx_ctl != rx_frames and
// hide a dropped-TICK bug.
// =========================================================================
always_ff @(posedge rclk) begin
    if (!rrstn || !arm_r || clr_r) begin
        rx_syn_r <= '0;
        rx_frm_r <= '0;
        rx_fus_r <= '0;
        rx_ctl_r <= '0;
    end else if (rx_valid) begin
        case (rx_type)
            TYPE_SYN: rx_syn_r <= rx_syn_r + 32'd1;
            TYPE_FRM: rx_frm_r <= rx_frm_r + 32'd1;
            TYPE_FUS: rx_fus_r <= rx_fus_r + 32'd1;
            TYPE_CTL: rx_ctl_r <= rx_ctl_r + 32'd1;
            default:  ;  // bad TYPE is already counted in rx_errors
        endcase
    end
end

// =========================================================================
// QLINK protocol cores
// =========================================================================
qlink_link_tx inst_qlink_tx (
    .clk(tclk), .rstn(trstn), .link_up(link_up_t), .clr(clr_t),
    .tx_type(tx_type_t), .tx_flags(tx_flags_t),
    .tx_src(tx_src_t), .tx_dst(tx_dst_t), .tx_epoch(tx_epoch_t),
    .tx_round(tx_round_t), .tx_payload(tx_payload_t),
    .tx_valid(tx_valid_t),
    .phy_tx_data(phy_tx_data), .phy_tx_valid(phy_tx_valid),
    .phy_tx_last(phy_tx_last), .phy_tx_ready(phy_tx_ready),
    .phy_tx_hdr(phy_tx_hdr), .phy_tx_cks(phy_tx_cks),
    .tx_frames(tx_frames), .tx_dropped(tx_dropped)
);

qlink_link_rx inst_qlink_rx (
    .clk(rclk), .rstn(rrstn), .link_up(link_up_r), .clr(clr_r),
    .rx_valid(rx_valid), .rx_bad(rx_bad),
    .rx_type(rx_type), .rx_flags(rx_flags),
    .rx_src(rx_src), .rx_dst(rx_dst), .rx_epoch(rx_epoch),
    .rx_round(rx_round), .rx_payload(rx_payload),
    .phy_rx_data(phy_rx_data), .phy_rx_valid(phy_rx_valid),
    .phy_rx_eof(phy_rx_eof), .phy_rx_err(phy_rx_err),
    .phy_rx_sof(phy_rx_sof),
    .phy_rx_hdr(phy_rx_hdr), .phy_rx_cks(phy_rx_cks),
    .rx_frames(rx_frames), .rx_errors(rx_errors)
);

qlink_phy_shim inst_phy (
    .phy_tx_data(phy_tx_data), .phy_tx_valid(phy_tx_valid),
    .phy_tx_last(phy_tx_last), .phy_tx_ready(phy_tx_ready),
    .phy_tx_hdr(phy_tx_hdr), .phy_tx_cks(phy_tx_cks),
    .phy_rx_data(phy_rx_data), .phy_rx_valid(phy_rx_valid),
    .phy_rx_eof(phy_rx_eof), .phy_rx_err(phy_rx_err),
    .phy_rx_hdr(phy_rx_hdr), .phy_rx_sof(phy_rx_sof),
    .phy_rx_cks(phy_rx_cks),
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
