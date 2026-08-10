/**
 * BRAID system-level latency model
 *
 * tb_braid.sv proves the protocol. THIS testbench exists to account for the gap
 * between what the protocol costs (35 ns one-way, measured in tb_braid Test 3)
 * and what the hardware actually delivers (289 ns one-way). ~215 ns is
 * unexplained, and unexplained latency is the thing standing between us and a
 * <100 ns design.
 *
 * It reproduces the real system structure that tb_braid deliberately omits:
 *   - braid_link on aclk (400 MHz), NOT on the GT clock
 *   - braid_framer on the GT user clock (257.8125 MHz)
 *   - a PACKET-MODE async FIFO between them in each direction
 *   - a fixed GT + wire delay taken from AMD's measured figure
 *
 * If the modelled one-way latency lands near 289 ns, the FIFOs are the missing
 * 215 ns and deleting them is worth ~200 ns. If it lands far below, the model is
 * still missing something and we should find out what BEFORE spending a bitgen.
 */

`timescale 1ns/1ps

// ---------------------------------------------------------------------------
// Behavioural model of Xilinx axis_data_fifo in PACKET mode with async clocks.
//
// Packet mode = store and forward: nothing is readable until tlast has been
// written. That is the property we suspect is expensive, so it is modelled
// explicitly rather than as a fixed delay.
//
// SYNC_STAGES models the gray-code pointer synchroniser: after the packet is
// fully written, the read side cannot see it for this many rd_clk edges.
// ---------------------------------------------------------------------------
module tb_pkt_fifo #(
    parameter int WIDTH       = 32,
    parameter int SYNC_STAGES = 3
) (
    input  logic              wr_clk,
    input  logic              rd_clk,
    input  logic              rstn,

    input  logic [WIDTH-1:0]  s_data,
    input  logic              s_valid,
    input  logic              s_last,
    output logic              s_ready,

    output logic [WIDTH-1:0]  m_data,
    output logic              m_valid,
    output logic              m_last,
    input  logic              m_ready
);

    typedef struct { logic [WIDTH-1:0] d; logic l; } beat_t;
    beat_t q [$];

    // wr_pkts is written ONLY by wr_clk; rd_pkts and sync[] ONLY by rd_clk.
    // The gray-code pointer synchroniser is modelled as SYNC_STAGES rd_clk
    // registers on the completed-packet count -- that delay is exactly what
    // makes a packet-mode async FIFO expensive, so it is explicit here.
    int wr_pkts = 0;
    int rd_pkts = 0;
    int sync [SYNC_STAGES];

    assign s_ready = 1'b1;   // modelled deep enough never to stall the writer

    always @(posedge wr_clk) begin
        if (!rstn) begin
            q.delete();
            wr_pkts <= 0;
        end else if (s_valid) begin
            q.push_back('{s_data, s_last});
            if (s_last) wr_pkts <= wr_pkts + 1;   // store-and-forward gate
        end
    end

    always @(posedge rd_clk) begin
        if (!rstn) begin
            for (int i = 0; i < SYNC_STAGES; i++) sync[i] <= 0;
            rd_pkts <= 0;
            m_valid <= 1'b0;
            m_last  <= 1'b0;
        end else begin
            sync[0] <= wr_pkts;
            for (int i = 1; i < SYNC_STAGES; i++) sync[i] <= sync[i-1];

            if (!m_valid || m_ready) begin
                if (sync[SYNC_STAGES-1] > rd_pkts && q.size() > 0) begin
                    beat_t b = q.pop_front();
                    m_data  <= b.d;
                    m_last  <= b.l;
                    m_valid <= 1'b1;
                    if (b.l) rd_pkts <= rd_pkts + 1;
                end else begin
                    m_valid <= 1'b0;
                end
            end
        end
    end
endmodule


module tb_braid_sys;

    localparam int N_STAB = 1024;
    localparam int N_CORR = 64;

    // Real clock ratio: Coyote aclk 400 MHz vs GT user clock 257.8125 MHz.
    localparam real ACLK_HALF = 1.25;    // 400 MHz
    localparam real UCLK_HALF = 1.9394;  // 257.8125 MHz

    // AMD's measured GTY figure at 10.3125 Gbps, 32-bit datapath: 27.83 ns for
    // TX+RX. Plus ~10 ns of cable. Split across the two directions of the model.
    localparam real GT_DELAY = 27.83 + 10.0;

    logic aclk = 0, uclk = 0, rstn = 0;
    always #(ACLK_HALF) aclk = ~aclk;
    always #(UCLK_HALF) uclk = ~uclk;

    // ---------------- A: sender, braid_link on aclk ----------------
    logic [N_STAB-1:0] a_syn_bits;
    logic              a_syn_valid;
    logic [19:0]       a_syn_round;
    logic [7:0]        a_words;

    logic [31:0] a_ptx_data, a_prx_data;
    logic        a_ptx_valid, a_ptx_last, a_ptx_ready;
    logic        a_prx_valid, a_prx_last;
    logic [31:0] a_txf, a_txd, a_rxf, a_rxe, a_rxg;
    logic [N_STAB-1:0] a_syn_out; logic a_syn_out_valid, a_syn_out_gap;
    logic [31:0] a_syn_out_round;
    logic [N_CORR-1:0] a_corr_out; logic a_corr_out_valid;

    braid_link_tx #(.N_STAB(N_STAB), .N_CORR(N_CORR)) u_link_a_tx (
        .clk(aclk), .rstn(rstn), .link_up(1'b1), .clr(1'b0),
        .syn_bits(a_syn_bits), .syn_valid(a_syn_valid), .syn_round(a_syn_round),
        .syn_words_sel(a_words),
        .corr_bits('0), .corr_valid(1'b0),
        .phy_tx_data(a_ptx_data), .phy_tx_valid(a_ptx_valid),
        .phy_tx_last(a_ptx_last), .phy_tx_ready(a_ptx_ready),
        .tx_frames(a_txf), .tx_dropped(a_txd)
    );

    braid_link_rx #(.N_STAB(N_STAB), .N_CORR(N_CORR)) u_link_a_rx (
        .clk(aclk), .rstn(rstn), .link_up(1'b1), .clr(1'b0),
        .syn_out_bits(a_syn_out), .syn_out_valid(a_syn_out_valid),
        .syn_out_round(a_syn_out_round), .syn_out_gap(a_syn_out_gap),
        .corr_out_bits(a_corr_out), .corr_out_valid(a_corr_out_valid),
        .phy_rx_data(a_prx_data), .phy_rx_valid(a_prx_valid),
        .phy_rx_last(a_prx_last), .phy_rx_err(1'b0),
        .rx_frames(a_rxf), .rx_errors(a_rxe), .rx_gaps(a_rxg)
    );

    // aclk -> uclk packet FIFO (the real axis_data_fifo_braid_tx)
    logic [31:0] a_fr_tx_data; logic a_fr_tx_valid, a_fr_tx_last, a_fr_tx_ready;
    tb_pkt_fifo #(.WIDTH(32)) u_fifo_a_tx (
        .wr_clk(aclk), .rd_clk(uclk), .rstn(rstn),
        .s_data(a_ptx_data), .s_valid(a_ptx_valid), .s_last(a_ptx_last),
        .s_ready(a_ptx_ready),
        .m_data(a_fr_tx_data), .m_valid(a_fr_tx_valid), .m_last(a_fr_tx_last),
        .m_ready(a_fr_tx_ready)
    );

    logic [31:0] a_gt_txdata; logic [7:0] a_gt_txctrl2;
    wire  [31:0] a_gt_rxdata; wire  [15:0] a_gt_rxctrl0;
    logic [31:0] a_fr_rx_data; logic a_fr_rx_valid, a_fr_rx_last, a_fr_rx_err;
    logic [1:0]  a_dbg;

    braid_framer u_fr_a (
        .clk_tx(uclk), .rstn_tx(rstn), .link_up_tx(1'b1),
        .clk_rx(uclk), .rstn_rx(rstn), .link_up_rx(1'b1),
        .phy_tx_data(a_fr_tx_data), .phy_tx_valid(a_fr_tx_valid),
        .phy_tx_last(a_fr_tx_last), .phy_tx_ready(a_fr_tx_ready),
        .phy_rx_data(a_fr_rx_data), .phy_rx_valid(a_fr_rx_valid),
        .phy_rx_last(a_fr_rx_last), .phy_rx_err(a_fr_rx_err),
        .gt_txdata(a_gt_txdata), .gt_txctrl2(a_gt_txctrl2),
        .gt_rxdata(a_gt_rxdata), .gt_rxctrl0(a_gt_rxctrl0),
        .gt_rxctrl1(16'b0), .gt_rxctrl3(8'b0), .dbg(a_dbg)
    );

    // uclk -> aclk packet FIFO (axis_data_fifo_braid_rx). A never receives in
    // this test but the instance keeps the two sides symmetric.
    tb_pkt_fifo #(.WIDTH(32)) u_fifo_a_rx (
        .wr_clk(uclk), .rd_clk(aclk), .rstn(rstn),
        .s_data(a_fr_rx_data), .s_valid(a_fr_rx_valid), .s_last(a_fr_rx_last),
        .s_ready(),
        .m_data(a_prx_data), .m_valid(a_prx_valid), .m_last(a_prx_last),
        .m_ready(1'b1)
    );

    // ---------------- B: receiver, same structure ----------------
    logic [31:0] b_ptx_data, b_prx_data;
    logic        b_ptx_valid, b_ptx_last, b_ptx_ready;
    logic        b_prx_valid, b_prx_last;
    logic [31:0] b_txf, b_txd, b_rxf, b_rxe, b_rxg;
    logic [N_STAB-1:0] b_syn_out; logic b_syn_out_valid, b_syn_out_gap;
    logic [31:0] b_syn_out_round;
    logic [N_CORR-1:0] b_corr_out; logic b_corr_out_valid;

    braid_link_tx #(.N_STAB(N_STAB), .N_CORR(N_CORR)) u_link_b_tx (
        .clk(aclk), .rstn(rstn), .link_up(1'b1), .clr(1'b0),
        // B never transmits syndromes in these tests; it only reflects/receives.
        .syn_bits('0), .syn_valid(1'b0), .syn_round(20'b0),
        .syn_words_sel(8'd0),
        .corr_bits('0), .corr_valid(1'b0),
        .phy_tx_data(b_ptx_data), .phy_tx_valid(b_ptx_valid),
        .phy_tx_last(b_ptx_last), .phy_tx_ready(b_ptx_ready),
        .tx_frames(b_txf), .tx_dropped(b_txd)
    );

    braid_link_rx #(.N_STAB(N_STAB), .N_CORR(N_CORR)) u_link_b_rx (
        .clk(aclk), .rstn(rstn), .link_up(1'b1), .clr(1'b0),
        .syn_out_bits(b_syn_out), .syn_out_valid(b_syn_out_valid),
        .syn_out_round(b_syn_out_round), .syn_out_gap(b_syn_out_gap),
        .corr_out_bits(b_corr_out), .corr_out_valid(b_corr_out_valid),
        .phy_rx_data(b_prx_data), .phy_rx_valid(b_prx_valid),
        .phy_rx_last(b_prx_last), .phy_rx_err(1'b0),
        .rx_frames(b_rxf), .rx_errors(b_rxe), .rx_gaps(b_rxg)
    );

    logic [31:0] b_fr_tx_data; logic b_fr_tx_valid, b_fr_tx_last, b_fr_tx_ready;
    tb_pkt_fifo #(.WIDTH(32)) u_fifo_b_tx (
        .wr_clk(aclk), .rd_clk(uclk), .rstn(rstn),
        .s_data(b_ptx_data), .s_valid(b_ptx_valid), .s_last(b_ptx_last),
        .s_ready(b_ptx_ready),
        .m_data(b_fr_tx_data), .m_valid(b_fr_tx_valid), .m_last(b_fr_tx_last),
        .m_ready(b_fr_tx_ready)
    );

    logic [31:0] b_gt_txdata; logic [7:0] b_gt_txctrl2;
    wire  [31:0] b_gt_rxdata; wire  [15:0] b_gt_rxctrl0;
    logic [31:0] b_fr_rx_data; logic b_fr_rx_valid, b_fr_rx_last, b_fr_rx_err;
    logic [1:0]  b_dbg;

    braid_framer u_fr_b (
        .clk_tx(uclk), .rstn_tx(rstn), .link_up_tx(1'b1),
        .clk_rx(uclk), .rstn_rx(rstn), .link_up_rx(1'b1),
        .phy_tx_data(b_fr_tx_data), .phy_tx_valid(b_fr_tx_valid),
        .phy_tx_last(b_fr_tx_last), .phy_tx_ready(b_fr_tx_ready),
        .phy_rx_data(b_fr_rx_data), .phy_rx_valid(b_fr_rx_valid),
        .phy_rx_last(b_fr_rx_last), .phy_rx_err(b_fr_rx_err),
        .gt_txdata(b_gt_txdata), .gt_txctrl2(b_gt_txctrl2),
        .gt_rxdata(b_gt_rxdata), .gt_rxctrl0(b_gt_rxctrl0),
        .gt_rxctrl1(16'b0), .gt_rxctrl3(8'b0), .dbg(b_dbg)
    );

    tb_pkt_fifo #(.WIDTH(32)) u_fifo_b_rx (
        .wr_clk(uclk), .rd_clk(aclk), .rstn(rstn),
        .s_data(b_fr_rx_data), .s_valid(b_fr_rx_valid), .s_last(b_fr_rx_last),
        .s_ready(),
        .m_data(b_prx_data), .m_valid(b_prx_valid), .m_last(b_prx_last),
        .m_ready(1'b1)
    );

    // ---------------- the wire, with the GT's measured delay ----------------
    // Modelled as a shift register on uclk. A `#delay` continuous assignment
    // would be INERTIAL and silently swallow every transition shorter than the
    // delay -- the data changes every 3.9 ns against a 37.8 ns delay, so
    // nothing would ever propagate.
    localparam int GT_STAGES = 10;   // 37.83 ns / 3.879 ns per uclk

    logic [31:0] pipe_ab_data [GT_STAGES];
    logic [3:0]  pipe_ab_k    [GT_STAGES];
    logic [31:0] pipe_ba_data [GT_STAGES];
    logic [3:0]  pipe_ba_k    [GT_STAGES];

    always @(posedge uclk) begin
        pipe_ab_data[0] <= a_gt_txdata;
        pipe_ab_k[0]    <= a_gt_txctrl2[3:0];
        pipe_ba_data[0] <= b_gt_txdata;
        pipe_ba_k[0]    <= b_gt_txctrl2[3:0];
        for (int i = 1; i < GT_STAGES; i++) begin
            pipe_ab_data[i] <= pipe_ab_data[i-1];
            pipe_ab_k[i]    <= pipe_ab_k[i-1];
            pipe_ba_data[i] <= pipe_ba_data[i-1];
            pipe_ba_k[i]    <= pipe_ba_k[i-1];
        end
    end

    assign b_gt_rxdata  = pipe_ab_data[GT_STAGES-1];
    assign b_gt_rxctrl0 = {12'b0, pipe_ab_k[GT_STAGES-1]};
    assign a_gt_rxdata  = pipe_ba_data[GT_STAGES-1];
    assign a_gt_rxctrl0 = {12'b0, pipe_ba_k[GT_STAGES-1]};

    // ---------------- stimulus ----------------
    function automatic logic [N_STAB-1:0] pattern(input logic [19:0] r);
        logic [N_STAB+31:0] p;
        for (int k = 0; k <= (N_STAB/32); k++)
            p[k*32 +: 32] = {12'b0, r} ^ (32'h9E3779B9 * (k + 1));
        return p[N_STAB-1:0];
    endfunction

    initial begin
        a_syn_bits = '0; a_syn_valid = 0; a_syn_round = '0; a_words = 8'd4;
        repeat (40) @(posedge aclk);
        rstn = 1;
        repeat (40) @(posedge aclk);

        $display("\n=== System-level one-way latency (braid_link on aclk, framer on uclk) ===");
        $display("  model: aclk 400 MHz, uclk 257.8125 MHz, packet FIFOs both ways,");
        $display("         GT+wire fixed at %0.2f ns (AMD measured 27.83 + ~10 cable)", GT_DELAY);
        $display("  words   one-way ns   (aclk period 2.5 ns, uclk 3.88 ns)");

        for (int w = 1; w <= 8; w = w * 2) begin
            time t0, t1;
            a_words = w[7:0];
            @(posedge aclk);
            a_syn_bits  <= pattern(20'd3);
            a_syn_round <= 20'd3;
            a_syn_valid <= 1'b1;
            t0 = $time;
            @(posedge aclk);
            a_syn_valid <= 1'b0;
            // Sample synchronously. @(posedge b_syn_out_valid) fires on an X->1
            // transition at time zero, which reported 0.1 ns rather than a real
            // measurement.
            do @(posedge aclk); while (b_syn_out_valid !== 1'b1);
            t1 = $time;
            $display("  %5d   %8.1f", w, real'(t1 - t0));
            repeat (200) @(posedge aclk);
        end

        $display("\n  Hardware measured one-way at 4 words: 306 ns (612 ns RTT / 2)");
        $display("  If the model is close, the packet FIFOs ARE the missing latency.\n");
        $finish;
    end

    initial begin
        #500000;
        $display("*** TIMEOUT -- no frame delivered ***");
        $finish;
    end

endmodule
