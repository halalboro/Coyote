/**
 * Coyote Example 14: Aurora 64B/66B FPGA-to-FPGA Loopback
 *
 * User logic for the Aurora-loopback example. The vFPGA has access to:
 *   - axis_aurora_rx  : 256-bit AXI4-Stream from the Aurora RX path (aclk domain)
 *   - axis_aurora_tx  : 256-bit AXI4-Stream into Aurora TX path
 *   - aurora_channel_up, aurora_lane_up[3:0] : link status from Aurora IP
 *
 * Register map (host CSR index = byte offset / 8):
 *   0  CTRL          RW : bit0=TX start, bit1=RX arm, bit2=clear sticky debug bits,
 *                         bit3=echo mode (reflect RX back out TX)
 *   1  STATUS        RO : bit0=tx_done, bit1=rx_done, bit2=channel_up, bits[6:3]=lane_up
 *   2  TX_BURST      RW : number of 256-bit beats to send
 *   3  RX_BEAT_CNT   RO : observed RX beat count
 *   4  RX_MISMATCHES RO : beats where the expected pattern != received
 *   5  TX_BEAT_IDX   RO : live TX beat counter (how far the burst actually got)
 *   6  TX_DBG        RO : handshake / sticky debug bits, see below
 *   7  RX_FIRST_BEAT RO : low 64 bits of the first beat received after arming
 *   8  RTT_HEAD      RO : aclk cycles, first TX beat out -> first echoed beat back
 *   9  RTT_FULL      RO : aclk cycles, first TX beat out -> last echoed beat back
 *   10..15 SCRATCH   RW : unused by the design; targets for the CSR write probe
 *
 * Latency benchmark: one card sets CTRL bit3 and becomes a reflector, muxing its
 * Aurora RX stream straight back into TX through a single register stage (adds
 * exactly 1 aclk cycle, 2.5 ns at ACLK_F=400). The other card sends a burst and
 * hardware timestamps the round trip, so no cross-host clock sync is needed --
 * both timestamps are taken by the same counter on the same card.
 *
 * The AXI4-Lite slave below follows the standard Coyote parser structure (see
 * examples/07_perf_fpga/hw/src/hdl/perf_fpga_axi_ctrl_parser.sv). The previous
 * hand-rolled version sampled axi_ctrl.wdata at write-commit time rather than
 * at the W-channel handshake; by then the master had released the bus, so every
 * host write landed as zero. That left tx_start and rx_arm permanently low,
 * which is why tx_done never asserted and no beats were ever accepted.
 */

// =========================================================================
// Constants and register map
// =========================================================================
localparam integer N_REGS        = 16;
localparam integer ADDR_LSB      = $clog2(AXIL_DATA_BITS/8);
localparam integer ADDR_MSB      = $clog2(N_REGS);
localparam integer AXI_ADDR_BITS = ADDR_LSB + ADDR_MSB;

localparam integer REG_CTRL        = 0;
localparam integer REG_STATUS      = 1;
localparam integer REG_TX_BURST    = 2;
localparam integer REG_RX_BEATS    = 3;
localparam integer REG_RX_MISMATCH = 4;
localparam integer REG_TX_BEAT_IDX = 5;
localparam integer REG_TX_DBG      = 6;
localparam integer REG_RX_FIRST    = 7;
localparam integer REG_RTT_HEAD    = 8;
localparam integer REG_RTT_FULL    = 9;
localparam integer REG_SCRATCH0    = 10;

// =========================================================================
// Declarations
// =========================================================================
// AXI4-Lite slave internals
logic [AXI_ADDR_BITS-1:0]                   axi_awaddr;
logic [AXI_ADDR_BITS-1:0]                   axi_araddr;
logic                                       axi_awready;
logic                                       axi_arready;
logic                                       axi_wready;
logic                                       axi_bvalid;
logic [1:0]                                 axi_bresp;
logic [AXIL_DATA_BITS-1:0]                  axi_rdata;
logic                                       axi_rvalid;
logic [1:0]                                 axi_rresp;
logic                                       aw_en;

logic [N_REGS-1:0][AXIL_DATA_BITS-1:0]      ctrl_reg;
logic                                       ctrl_reg_wren;
logic                                       ctrl_reg_rden;

// TX path
logic [63:0]                                tx_beat_idx;
logic                                       tx_running;
logic                                       tx_done;
logic [255:0]                               tx_data_q;
logic                                       tx_valid_q;
logic                                       tx_last_q;

// RX path
logic [63:0]                                rx_beat_cnt;
logic [63:0]                                rx_mismatches;
logic                                       rx_done;
logic [255:0]                               rx_chk_data;
logic [63:0]                                rx_chk_expect;
logic                                       rx_chk_valid;
logic [63:0]                                rx_first_beat;
logic                                       rx_first_seen;

// Echo (reflector) pipeline stage
logic [255:0]                               echo_data_q;
logic                                       echo_valid_q;
logic                                       echo_last_q;

// Latency measurement
logic [63:0]                                cyc_cnt;
logic [63:0]                                t_start;
logic [63:0]                                rtt_head;
logic [63:0]                                rtt_full;
logic                                       t_start_v;
logic                                       head_v;

// Sticky debug flags
logic                                       stk_tx_tready;
logic                                       stk_tx_handshake;
logic                                       stk_rx_tvalid;
logic                                       stk_rx_tlast;
logic [63:0]                                tx_dbg;

// Convenience aliases off the control register
wire        tx_start       = ctrl_reg[REG_CTRL][0];
wire        rx_arm         = ctrl_reg[REG_CTRL][1];
wire        dbg_clear      = ctrl_reg[REG_CTRL][2];
wire        echo_mode      = ctrl_reg[REG_CTRL][3];
wire [63:0] tx_burst_beats = ctrl_reg[REG_TX_BURST];

wire [ADDR_MSB-1:0] wr_idx = axi_awaddr[ADDR_LSB+:ADDR_MSB];
wire [ADDR_MSB-1:0] rd_idx = axi_araddr[ADDR_LSB+:ADDR_MSB];

// Only CTRL, TX_BURST and the scratch block accept host writes. Everything
// else is a read-only overlay produced in the read process below.
wire wr_allowed = (wr_idx == REG_CTRL)     ||
                  (wr_idx == REG_TX_BURST) ||
                  (wr_idx >= REG_SCRATCH0);

// =========================================================================
// AXI4-Lite write process
//
// ctrl_reg has exactly one driver (this block); read-only status values are
// overlaid in the read mux instead, which keeps Vivado DRC MDRV-1 happy.
// =========================================================================
assign ctrl_reg_wren = axi_wready && axi_ctrl.wvalid && axi_awready && axi_ctrl.awvalid;

always_ff @(posedge aclk) begin
    if (!aresetn) begin
        ctrl_reg <= '0;
    end else if (ctrl_reg_wren && wr_allowed) begin
        for (int i = 0; i < (AXIL_DATA_BITS/8); i++) begin
            if (axi_ctrl.wstrb[i]) begin
                ctrl_reg[wr_idx][(i*8)+:8] <= axi_ctrl.wdata[(i*8)+:8];
            end
        end
    end
end

// =========================================================================
// AXI4-Lite read process
// =========================================================================
assign ctrl_reg_rden = axi_arready && axi_ctrl.arvalid && !axi_rvalid;

always_ff @(posedge aclk) begin
    if (!aresetn) begin
        axi_rdata <= '0;
    end else if (ctrl_reg_rden) begin
        case (rd_idx)
            REG_STATUS:
                axi_rdata <= {57'b0, aurora_lane_up, aurora_channel_up, rx_done, tx_done};
            REG_RX_BEATS:    axi_rdata <= rx_beat_cnt;
            REG_RX_MISMATCH: axi_rdata <= rx_mismatches;
            REG_TX_BEAT_IDX: axi_rdata <= tx_beat_idx;
            REG_TX_DBG:      axi_rdata <= tx_dbg;
            REG_RX_FIRST:    axi_rdata <= rx_first_beat;
            REG_RTT_HEAD:    axi_rdata <= rtt_head;
            REG_RTT_FULL:    axi_rdata <= rtt_full;
            default:         axi_rdata <= ctrl_reg[rd_idx];
        endcase
    end
end

// =========================================================================
// Standard AXI4-Lite handshake control (mirrors the Coyote parser template)
// =========================================================================
assign axi_ctrl.awready = axi_awready;
assign axi_ctrl.arready = axi_arready;
assign axi_ctrl.wready  = axi_wready;
assign axi_ctrl.bvalid  = axi_bvalid;
assign axi_ctrl.bresp   = axi_bresp;
assign axi_ctrl.rdata   = axi_rdata;
assign axi_ctrl.rvalid  = axi_rvalid;
assign axi_ctrl.rresp   = axi_rresp;

// awready / awaddr
always_ff @(posedge aclk) begin
    if (!aresetn) begin
        axi_awready <= 1'b0;
        axi_awaddr  <= '0;
        aw_en       <= 1'b1;
    end else begin
        if (!axi_awready && axi_ctrl.awvalid && axi_ctrl.wvalid && aw_en) begin
            axi_awready <= 1'b1;
            aw_en       <= 1'b0;
            axi_awaddr  <= axi_ctrl.awaddr[AXI_ADDR_BITS-1:0];
        end else if (axi_ctrl.bready && axi_bvalid) begin
            aw_en       <= 1'b1;
            axi_awready <= 1'b0;
        end else begin
            axi_awready <= 1'b0;
        end
    end
end

// wready
always_ff @(posedge aclk) begin
    if (!aresetn) begin
        axi_wready <= 1'b0;
    end else begin
        if (!axi_wready && axi_ctrl.wvalid && axi_ctrl.awvalid && aw_en) begin
            axi_wready <= 1'b1;
        end else begin
            axi_wready <= 1'b0;
        end
    end
end

// bvalid / bresp
always_ff @(posedge aclk) begin
    if (!aresetn) begin
        axi_bvalid <= 1'b0;
        axi_bresp  <= 2'b00;
    end else begin
        if (axi_awready && axi_ctrl.awvalid && !axi_bvalid && axi_wready && axi_ctrl.wvalid) begin
            axi_bvalid <= 1'b1;
            axi_bresp  <= 2'b00;
        end else if (axi_ctrl.bready && axi_bvalid) begin
            axi_bvalid <= 1'b0;
        end
    end
end

// arready / araddr
always_ff @(posedge aclk) begin
    if (!aresetn) begin
        axi_arready <= 1'b0;
        axi_araddr  <= '0;
    end else begin
        if (!axi_arready && axi_ctrl.arvalid) begin
            axi_arready <= 1'b1;
            axi_araddr  <= axi_ctrl.araddr[AXI_ADDR_BITS-1:0];
        end else begin
            axi_arready <= 1'b0;
        end
    end
end

// rvalid / rresp
always_ff @(posedge aclk) begin
    if (!aresetn) begin
        axi_rvalid <= 1'b0;
        axi_rresp  <= 2'b00;
    end else begin
        if (axi_arready && axi_ctrl.arvalid && !axi_rvalid) begin
            axi_rvalid <= 1'b1;
            axi_rresp  <= 2'b00;
        end else if (axi_rvalid && axi_ctrl.rready) begin
            axi_rvalid <= 1'b0;
        end
    end
end

// =========================================================================
// TX path: send `tx_burst_beats` counter-pattern beats over Aurora
//
// The AXIS output is registered. Previously tdata was driven combinationally
// from tx_beat_idx straight into the Aurora TX CDC FIFO's BRAM write port,
// which was the -0.837 ns worst path at ACLK_F=400 MHz. Data now leaves a
// flop, and only the load-enable depends on tready.
// =========================================================================
wire tx_out_free   = !tx_valid_q || axis_aurora_tx.tready;   // output slot free
wire tx_beat_taken = tx_valid_q && axis_aurora_tx.tready;    // a beat left the block
wire tx_more       = tx_running && aurora_channel_up && (tx_beat_idx < tx_burst_beats);

always_ff @(posedge aclk) begin
    if (!aresetn) begin
        tx_beat_idx <= '0;
        tx_running  <= 1'b0;
        tx_done     <= 1'b0;
        tx_data_q   <= '0;
        tx_valid_q  <= 1'b0;
        tx_last_q   <= 1'b0;
    end else begin
        // Start of a burst. A zero-length burst completes immediately rather
        // than leaving tx_running asserted forever with nothing to send.
        if (tx_start && !tx_running && !tx_done) begin
            if (tx_burst_beats == 64'd0) begin
                tx_done <= 1'b1;
            end else begin
                tx_running  <= 1'b1;
                tx_beat_idx <= '0;
            end
        end

        // Registered output stage: load the next beat only when the slot is free
        if (tx_out_free) begin
            if (tx_more) begin
                tx_valid_q  <= 1'b1;
                tx_data_q   <= {4{tx_beat_idx}};   // 256 bits = 4 copies of beat idx
                tx_last_q   <= (tx_beat_idx + 64'd1 == tx_burst_beats);
                tx_beat_idx <= tx_beat_idx + 64'd1;
            end else begin
                tx_valid_q <= 1'b0;
            end
        end

        // Burst completes when the final beat is actually accepted by Aurora
        if (tx_beat_taken && tx_last_q) begin
            tx_running <= 1'b0;
            tx_done    <= 1'b1;
        end

        // Edge-triggered restart: host clears CTRL to re-arm
        if (!tx_start) tx_done <= 1'b0;
    end
end

// =========================================================================
// Echo (reflector) path: RX straight back out TX through one register stage.
// Used by the far card during the latency benchmark. Registered rather than
// combinational so no long RX->TX path is created.
// =========================================================================
wire echo_out_free = !echo_valid_q || axis_aurora_tx.tready;

always_ff @(posedge aclk) begin
    if (!aresetn) begin
        echo_data_q  <= '0;
        echo_valid_q <= 1'b0;
        echo_last_q  <= 1'b0;
    end else if (echo_out_free) begin
        echo_valid_q <= echo_mode && axis_aurora_rx.tvalid;
        echo_data_q  <= axis_aurora_rx.tdata;
        echo_last_q  <= axis_aurora_rx.tlast;
    end
end

assign axis_aurora_tx.tvalid = echo_mode ? echo_valid_q : tx_valid_q;
assign axis_aurora_tx.tdata  = echo_mode ? echo_data_q  : tx_data_q;
assign axis_aurora_tx.tkeep  = '1;
assign axis_aurora_tx.tlast  = echo_mode ? echo_last_q  : tx_last_q;

// =========================================================================
// RX path: count beats, check pattern, count mismatches
//
// The 256-bit compare is pipelined one stage behind the beat counter so the
// comparator is not in the same path as the counter increment.
// =========================================================================
wire rx_handshake = axis_aurora_rx.tvalid && axis_aurora_rx.tready;

always_ff @(posedge aclk) begin
    if (!aresetn || !rx_arm) begin
        rx_beat_cnt   <= '0;
        rx_mismatches <= '0;
        rx_done       <= 1'b0;
        rx_chk_valid  <= 1'b0;
        rx_chk_data   <= '0;
        rx_chk_expect <= '0;
        rx_first_beat <= '0;
        rx_first_seen <= 1'b0;
    end else begin
        // Stage 1: accept the beat, capture it and the value it should have had
        rx_chk_valid  <= rx_handshake;
        rx_chk_data   <= axis_aurora_rx.tdata;
        rx_chk_expect <= rx_beat_cnt;

        if (rx_handshake) begin
            rx_beat_cnt <= rx_beat_cnt + 64'd1;
            if (axis_aurora_rx.tlast) rx_done <= 1'b1;
            if (!rx_first_seen) begin
                rx_first_beat <= axis_aurora_rx.tdata[63:0];
                rx_first_seen <= 1'b1;
            end
        end

        // Stage 2: compare
        if (rx_chk_valid && (rx_chk_data != {4{rx_chk_expect}})) begin
            rx_mismatches <= rx_mismatches + 64'd1;
        end
    end
end

assign axis_aurora_rx.tready = echo_mode ? echo_out_free : rx_arm;

// =========================================================================
// Latency measurement
//
// Both timestamps are taken by the same free-running counter on the same card,
// so no cross-host clock sync is involved. Captures are armed at burst start,
// so each iteration is self-contained. Deltas are computed here to keep the
// host out of the counter arithmetic. At ACLK_F=400 one tick is 2.5 ns; the
// counter is 64 bits so wrap is not a concern.
// =========================================================================
always_ff @(posedge aclk) begin
    if (!aresetn) cyc_cnt <= '0;
    else          cyc_cnt <= cyc_cnt + 64'd1;
end

always_ff @(posedge aclk) begin
    if (!aresetn) begin
        t_start   <= '0;
        rtt_head  <= '0;
        rtt_full  <= '0;
        t_start_v <= 1'b0;
        head_v    <= 1'b0;
    end else begin
        // Arm the capture at the start of a burst
        if (tx_start && !tx_running && !tx_done) begin
            t_start_v <= 1'b0;
            head_v    <= 1'b0;
        end

        // First beat of the burst leaves this card
        if (tx_beat_taken && !t_start_v) begin
            t_start   <= cyc_cnt;
            t_start_v <= 1'b1;
        end

        // First echoed beat comes back
        if (rx_handshake && t_start_v && !head_v) begin
            rtt_head <= cyc_cnt - t_start;
            head_v   <= 1'b1;
        end

        // Last echoed beat comes back
        if (rx_handshake && t_start_v && axis_aurora_rx.tlast) begin
            rtt_full <= cyc_cnt - t_start;
        end
    end
end

// =========================================================================
// Sticky debug flags — distinguish "never started" from "started and stalled"
// =========================================================================
always_ff @(posedge aclk) begin
    if (!aresetn || dbg_clear) begin
        stk_tx_tready    <= 1'b0;
        stk_tx_handshake <= 1'b0;
        stk_rx_tvalid    <= 1'b0;
        stk_rx_tlast     <= 1'b0;
    end else begin
        if (axis_aurora_tx.tready)                     stk_tx_tready    <= 1'b1;
        if (tx_beat_taken)                             stk_tx_handshake <= 1'b1;
        if (axis_aurora_rx.tvalid)                     stk_rx_tvalid    <= 1'b1;
        if (rx_handshake && axis_aurora_rx.tlast)      stk_rx_tlast     <= 1'b1;
    end
end

always_comb begin
    tx_dbg          = 64'b0;
    tx_dbg[0]       = tx_running;
    tx_dbg[1]       = tx_done;
    tx_dbg[2]       = tx_valid_q;
    tx_dbg[3]       = axis_aurora_tx.tready;
    tx_dbg[4]       = stk_tx_tready;
    tx_dbg[5]       = stk_tx_handshake;
    tx_dbg[6]       = aurora_channel_up;
    tx_dbg[10:7]    = aurora_lane_up;
    tx_dbg[11]      = rx_arm;
    tx_dbg[12]      = axis_aurora_rx.tvalid;
    tx_dbg[13]      = stk_rx_tvalid;
    tx_dbg[14]      = rx_done;
    tx_dbg[15]      = stk_rx_tlast;
    tx_dbg[16]      = tx_start;
    tx_dbg[17]      = tx_last_q;
end

// =========================================================================
// Tie off all the Coyote interfaces we don't use
// =========================================================================
always_comb axis_host_recv[0].tie_off_s();
always_comb axis_host_send[0].tie_off_m();
always_comb notify.tie_off_m();
always_comb sq_rd.tie_off_m();
always_comb sq_wr.tie_off_m();
always_comb cq_rd.tie_off_s();
always_comb cq_wr.tie_off_s();
