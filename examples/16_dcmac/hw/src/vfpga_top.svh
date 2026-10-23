/**
 * Coyote Example 16: V80 200G DCMAC raw Ethernet echo
 *
 * Brings the Versal DCMAC up on the V80's QSFP56 cage and echoes whole
 * Ethernet frames back to the peer with the source and destination MAC
 * addresses swapped. The network stack is bypassed (EN_NET_RAW=1), so this
 * vFPGA is the MAC client and owns the entire frame.
 *
 * Interfaces available here:
 *   - axis_net_raw_rx : 512-bit AXI4-Stream of received frames  (aclk domain)
 *   - axis_net_raw_tx : 512-bit AXI4-Stream of frames to send   (aclk domain)
 *   - mac_status[7:0] : {gt_rst_done_rx, gt_rst_done_tx, rst_done, rst_state[4:0]}
 *   - mac_reg_*       : register port into the MAC - the DCMAC's own PG369
 *                       registers below 0x100000, the shell's segment monitor
 *                       (hw/hdl/network/dcmac_cyt/dcmac_debug.sv) above
 *
 * Two endpoints running this design back to back would sit silent forever if
 * all it did was echo, so it can also *originate* traffic: setting CTRL bit3
 * emits TX_BURST single-beat frames. The usual back-to-back test is to enable
 * echo on the far side and generate on the near side, then watch RX_FRAMES on
 * the near side reach TX_BURST as the frames come back.
 *
 * Register map (host CSR index = byte offset / 8):
 *   0  CTRL       RW : bit0=echo enable, bit1=sink mode (accept and discard),
 *                      bit2=clear counters, bit3=generate burst (rising edge)
 *   1  STATUS     RO : bits[7:0]=mac_status, bit8=tx_valid_q, bit9=sof,
 *                      bit10=rx_tvalid, bit11=tx_tready, bit12=gen_run
 *   2  RX_FRAMES  RO : frames received (counted on tlast)
 *   3  RX_BYTES   RO : bytes received (sum of tkeep popcount)
 *   4  TX_FRAMES  RO : frames transmitted
 *   5  TX_BYTES   RO : bytes transmitted
 *   6  RX_FIRST   RO : low 64 bits of the most recent first beat, i.e. the
 *                      destination MAC, the low 2 bytes of the source MAC
 *   7  RX_RUNTS   RO : received frames shorter than 60 bytes
 *   8  TX_BURST   RW : number of frames to emit per generate burst
 *   9  GEN_SENT   RO : frames emitted by the generator since the last clear
 *   10 MREG_ADDR  RW : [31:0] MAC register address
 *   11 MREG_WDATA RW : [31:0] MAC register write data
 *   12 MREG_CMD   W  : any write issues one access; bit0 = 1 for a write.
 *                      Ignored while one is still in flight.
 *   13 MREG_RESP  RO : [31:0] read data, [33:32] AXI resp, [34] busy,
 *                      [63:48] completed-access count (wraps), so software
 *                      can tell a fresh answer from a stale one
 *   14..15 SCRATCH RW : unused by the design, handy for probing CSR writes
 *
 * The receive counters are pipelined (tap -> popcount -> accumulate ->
 * frame commit), so they settle a few cycles after the last beat. The first
 * build computed them combinationally off the RX FIFO output and failed
 * timing on RX_BYTES and RX_RUNTS at 400 MHz.
 *
 * The AXI4-Lite slave follows the standard Coyote parser structure, and in
 * particular samples wdata at the W-channel handshake rather than at write
 * commit - see the note in examples/14_aurora_loopback/hw/src/vfpga_top.svh.
 * ctrl_reg keeps exactly one driver; read-only values are overlaid in the read
 * mux, which is what keeps Vivado DRC MDRV-1 quiet.
 */

// =========================================================================
// Constants and register map
// =========================================================================
localparam integer N_REGS        = 16;
localparam integer ADDR_LSB      = $clog2(AXIL_DATA_BITS/8);
localparam integer ADDR_MSB      = $clog2(N_REGS);
localparam integer AXI_ADDR_BITS = ADDR_LSB + ADDR_MSB;

localparam integer REG_CTRL      = 0;
localparam integer REG_STATUS    = 1;
localparam integer REG_RX_FRAMES = 2;
localparam integer REG_RX_BYTES  = 3;
localparam integer REG_TX_FRAMES = 4;
localparam integer REG_TX_BYTES  = 5;
localparam integer REG_RX_FIRST  = 6;
localparam integer REG_RX_RUNTS  = 7;
localparam integer REG_TX_BURST  = 8;
localparam integer REG_GEN_SENT  = 9;
localparam integer REG_MREG_ADDR = 10;
localparam integer REG_MREG_WDAT = 11;
localparam integer REG_MREG_CMD  = 12;
localparam integer REG_MREG_RESP = 13;
localparam integer REG_SCRATCH0  = 14;

localparam integer NET_BYTES     = AXI_NET_BITS / 8;   // 64

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

// Echo datapath
logic                                       sof;
logic [AXI_NET_BITS-1:0]                    tx_data_q;
logic [NET_BYTES-1:0]                       tx_keep_q;
logic                                       tx_last_q;
logic                                       tx_valid_q;

// Counters
logic [63:0]                                rx_frames;
logic [63:0]                                rx_bytes;
logic [63:0]                                tx_frames;
logic [63:0]                                tx_bytes;
logic [63:0]                                rx_runts;
logic [63:0]                                rx_first_beat;
logic [15:0]                                frame_bytes;

// MAC register port
logic                                       mreg_busy;
logic [31:0]                                mreg_rdata;
logic [1:0]                                 mreg_resp;
logic [15:0]                                mreg_done;

// Frame generator
logic        gen_run;
logic        gen_start_q;
logic [63:0] gen_sent;

// Convenience aliases off the control register
wire echo_en    = ctrl_reg[REG_CTRL][0];
wire sink_en    = ctrl_reg[REG_CTRL][1];
wire cnt_clear  = ctrl_reg[REG_CTRL][2];
wire gen_start  = ctrl_reg[REG_CTRL][3];
wire [63:0] tx_burst = ctrl_reg[REG_TX_BURST];

wire [ADDR_MSB-1:0] wr_idx = axi_awaddr[ADDR_LSB+:ADDR_MSB];
wire [ADDR_MSB-1:0] rd_idx = axi_araddr[ADDR_LSB+:ADDR_MSB];

// Only CTRL, TX_BURST, the MAC register port's address/data/command and the
// scratch block accept host writes; the rest are read-only overlays produced
// in the read mux below.
wire wr_allowed = (wr_idx == REG_CTRL) || (wr_idx == REG_TX_BURST) ||
                  (wr_idx == REG_MREG_ADDR) || (wr_idx == REG_MREG_WDAT) ||
                  (wr_idx == REG_MREG_CMD) || (wr_idx >= REG_SCRATCH0);

// =========================================================================
// AXI4-Lite write process
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
            REG_STATUS:    axi_rdata <= {51'b0, gen_run, axis_net_raw_tx.tready,
                                         axis_net_raw_rx.tvalid, sof, tx_valid_q, mac_status};
            REG_RX_FRAMES: axi_rdata <= rx_frames;
            REG_RX_BYTES:  axi_rdata <= rx_bytes;
            REG_TX_FRAMES: axi_rdata <= tx_frames;
            REG_TX_BYTES:  axi_rdata <= tx_bytes;
            REG_RX_FIRST:  axi_rdata <= rx_first_beat;
            REG_RX_RUNTS:  axi_rdata <= rx_runts;
            REG_GEN_SENT:  axi_rdata <= gen_sent;
            REG_MREG_RESP: axi_rdata <= {mreg_done, 13'b0, mreg_busy, mreg_resp, mreg_rdata};
            default:       axi_rdata <= ctrl_reg[rd_idx];
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
// Echo datapath
//
// Single registered output beat rather than a combinational pass-through:
// tdata leaving a flop keeps the vFPGA -> shell FIFO write port off the
// critical path at 400 MHz, which is the same fix example 14 needed. The
// "output slot free" handshake still sustains one beat per cycle.
//
// The MAC swap only touches the first beat of a frame. Ethernet puts the
// destination MAC in bytes 0-5 and the source MAC in bytes 6-11, and the beat
// is 64 bytes wide, so the whole header is always inside beat 0.
// =========================================================================
wire [AXI_NET_BITS-1:0] rx_swapped = {axis_net_raw_rx.tdata[AXI_NET_BITS-1:96],
                                      axis_net_raw_rx.tdata[47:0],     // old dst -> src
                                      axis_net_raw_rx.tdata[95:48]};   // old src -> dst

// Output slot is free when empty, or when it is being drained this cycle.
wire out_free  = !tx_valid_q || axis_net_raw_tx.tready;

// Receive acceptance:
//  - while generating, accept and count everything but never echo it, so the
//    frames the far side sends back do not start an endless loop;
//  - in sink mode, accept and discard, which does not wait on the transmit
//    side at all;
//  - otherwise echo, which needs a free output slot.
assign axis_net_raw_rx.tready = (gen_run || sink_en) ? 1'b1 : (echo_en && out_free);

// ---------------------------------------------------------------------------
// Frame generator
//
// One 64-byte frame per beat, so every frame is single-beat and needs no
// length tracking. Layout, byte 0 first on the wire:
//   0..5   destination MAC, broadcast
//   6..11  source MAC, 02:00:00:00:00:01 (locally administered)
//   12..13 EtherType 0x88B5 (IEEE local experimental)
//   14..17 sequence number
//   18..63 byte-index pattern, so corruption is visible by inspection
// ---------------------------------------------------------------------------
wire [AXI_NET_BITS-1:0] gen_frame;

assign gen_frame[47:0]    = 48'hFFFF_FFFF_FFFF;
assign gen_frame[95:48]   = {8'h01, 8'h00, 8'h00, 8'h00, 8'h00, 8'h02};
assign gen_frame[111:96]  = {8'hB5, 8'h88};
assign gen_frame[143:112] = gen_sent[31:0];

for (genvar gi = 18; gi < NET_BYTES; gi++) begin : g_gen_pattern
    assign gen_frame[gi*8 +: 8] = gi[7:0];
end

// A burst starts on the rising edge of CTRL bit3 and runs until TX_BURST
// frames have been handed to the MAC.
wire gen_beat = gen_run && out_free;

// gen_sent counts within a burst and is reset when one starts, so it is
// independent of CTRL bit2 (clear counters) and cannot be disturbed mid-burst.
always_ff @(posedge aclk) begin
    if (!aresetn) begin
        gen_run     <= 1'b0;
        gen_start_q <= 1'b0;
        gen_sent    <= '0;
    end else begin
        gen_start_q <= gen_start;

        // CTRL bit2 doubles as an abort. A burst only ends by reaching
        // TX_BURST, so if the transmit path never drains — MAC held in reset,
        // link down with a full FIFO — gen_run would latch high and lock out
        // echo mode until the card is reprogrammed. This is the escape hatch.
        if (cnt_clear) begin
            gen_run  <= 1'b0;
            gen_sent <= '0;
        end else if (gen_start && !gen_start_q && (tx_burst != 0)) begin
            gen_run  <= 1'b1;
            gen_sent <= '0;
        end else if (gen_run && gen_beat) begin
            gen_sent <= gen_sent + 1;
            if (gen_sent + 1 >= tx_burst) begin
                gen_run <= 1'b0;
            end
        end
    end
end

wire rx_beat = axis_net_raw_rx.tvalid && axis_net_raw_rx.tready;
wire tx_beat = tx_valid_q && axis_net_raw_tx.tready;

assign axis_net_raw_tx.tdata  = tx_data_q;
assign axis_net_raw_tx.tkeep  = tx_keep_q;
assign axis_net_raw_tx.tlast  = tx_last_q;
assign axis_net_raw_tx.tvalid = tx_valid_q;

always_ff @(posedge aclk) begin
    if (!aresetn) begin
        sof        <= 1'b1;
        tx_valid_q <= 1'b0;
        tx_data_q  <= '0;
        tx_keep_q  <= '0;
        tx_last_q  <= 1'b0;
    end else begin
        // Drain first, then load: if both happen in the same cycle the load
        // wins, which is exactly the full-throughput case.
        if (axis_net_raw_tx.tready) begin
            tx_valid_q <= 1'b0;
        end

        // Start-of-frame tracking follows every accepted receive beat,
        // whatever the mode.
        if (rx_beat) begin
            sof <= axis_net_raw_rx.tlast;
        end

        // The generator owns the transmit register while a burst is running;
        // received frames are counted but not echoed back in that mode.
        if (gen_run) begin
            if (out_free) begin
                tx_data_q  <= gen_frame;
                tx_keep_q  <= {NET_BYTES{1'b1}};
                tx_last_q  <= 1'b1;
                tx_valid_q <= 1'b1;
            end
        end else if (rx_beat && !sink_en) begin
            tx_data_q  <= sof ? rx_swapped : axis_net_raw_rx.tdata;
            tx_keep_q  <= axis_net_raw_rx.tkeep;
            tx_last_q  <= axis_net_raw_rx.tlast;
            tx_valid_q <= 1'b1;
        end
    end
end

// =========================================================================
// Counters
//
// Receive side, pipelined so that nothing wide hangs combinationally off the
// RX FIFO output:
//   s1  tap the accepted beat (valid, last, sof, keep, low data)
//   s2  tkeep popcount
//   s3  byte accumulation; at tlast the frame length is committed
//   s4  frame count and the short-frame test
// Transmit side: tap, then accumulate.
// =========================================================================
logic                           s1_v, s1_last, s1_sof;
logic [NET_BYTES-1:0]           s1_keep;
logic [63:0]                    s1_head;
logic                           s2_v, s2_last, s2_sof;
logic [$clog2(NET_BYTES+1)-1:0] s2_bytes;
logic [63:0]                    s2_head;
logic                           s3_commit;
logic [15:0]                    s3_len;

logic                           tx1_v, tx1_last;
logic [$clog2(NET_BYTES+1)-1:0] tx1_bytes;

// Length of the frame so far including this beat. 16 bits saturates nothing
// below the DCMAC's 9600-byte maximum.
wire [15:0] s2_frame_len = (s2_sof ? 16'd0 : frame_bytes) + {9'b0, s2_bytes};

always_ff @(posedge aclk) begin
    if (!aresetn || cnt_clear) begin
        s1_v          <= 1'b0;
        s2_v          <= 1'b0;
        s3_commit     <= 1'b0;
        tx1_v         <= 1'b0;
        rx_frames     <= '0;
        rx_bytes      <= '0;
        tx_frames     <= '0;
        tx_bytes      <= '0;
        rx_runts      <= '0;
        rx_first_beat <= '0;
        frame_bytes   <= '0;
    end else begin
        // s1
        s1_v    <= rx_beat;
        s1_last <= axis_net_raw_rx.tlast;
        s1_sof  <= sof;
        s1_keep <= axis_net_raw_rx.tkeep;
        s1_head <= axis_net_raw_rx.tdata[63:0];

        // s2
        s2_v     <= s1_v;
        s2_last  <= s1_last;
        s2_sof   <= s1_sof;
        s2_bytes <= $countones(s1_keep);
        s2_head  <= s1_head;

        // s3
        s3_commit <= s2_v && s2_last;
        if (s2_v) begin
            rx_bytes    <= rx_bytes + s2_bytes;
            frame_bytes <= s2_frame_len;
            s3_len      <= s2_frame_len;
            if (s2_sof) begin
                rx_first_beat <= s2_head;
            end
        end

        // s4. The threshold is 60, not 64: whether the MAC strips the 4-byte
        // FCS before handing the frame over is exactly the kind of thing this
        // counter is here to settle, and 60 avoids flagging every legal
        // minimum-size frame if it does.
        if (s3_commit) begin
            rx_frames <= rx_frames + 1;
            if (s3_len < 16'd60) begin
                rx_runts <= rx_runts + 1;
            end
        end

        // Transmit
        tx1_v     <= tx_beat;
        tx1_last  <= tx_last_q;
        tx1_bytes <= $countones(tx_keep_q);
        if (tx1_v) begin
            tx_bytes <= tx_bytes + tx1_bytes;
            if (tx1_last) begin
                tx_frames <= tx_frames + 1;
            end
        end
    end
end

// =========================================================================
// MAC register port
//
// One access at a time: a write to MREG_CMD issues it from MREG_ADDR /
// MREG_WDATA, and the answer lands in MREG_RESP when the shell pulses
// mac_reg_rsp. The shell fails an access it cannot complete (resp 2'b11 after
// its own timeout), so busy always clears eventually.
// =========================================================================
wire mreg_go = ctrl_reg_wren && (wr_idx == REG_MREG_CMD) && !mreg_busy;

always_ff @(posedge aclk) begin
    if (!aresetn) begin
        mac_reg_req   <= 1'b0;
        mac_reg_wr    <= 1'b0;
        mac_reg_addr  <= '0;
        mac_reg_wdata <= '0;
        mreg_busy     <= 1'b0;
        mreg_rdata    <= '0;
        mreg_resp     <= 2'b00;
        mreg_done     <= '0;
    end else begin
        mac_reg_req <= 1'b0;
        if (mreg_go) begin
            mac_reg_req   <= 1'b1;
            mac_reg_wr    <= axi_ctrl.wdata[0];
            mac_reg_addr  <= ctrl_reg[REG_MREG_ADDR][31:0];
            mac_reg_wdata <= ctrl_reg[REG_MREG_WDAT][31:0];
            mreg_busy     <= 1'b1;
        end else if (mreg_busy && mac_reg_rsp) begin
            mreg_rdata    <= mac_reg_rdata;
            mreg_resp     <= mac_reg_resp;
            mreg_busy     <= 1'b0;
            mreg_done     <= mreg_done + 1;
        end
    end
end

// =========================================================================
// Tie-off unused interfaces
// =========================================================================
always_comb axis_host_recv[0].tie_off_s();
always_comb axis_host_send[0].tie_off_m();
always_comb notify.tie_off_m();
always_comb sq_rd.tie_off_m();
always_comb sq_wr.tie_off_m();
always_comb cq_rd.tie_off_s();
always_comb cq_wr.tie_off_s();
