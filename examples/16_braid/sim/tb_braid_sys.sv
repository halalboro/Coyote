/**
 * BRAID system-level latency model
 *
 * tb_braid.sv proves the protocol. THIS testbench exists to account for the gap
 * between what the protocol costs and what the hardware actually delivers, and
 * -- since Task 2b -- to predict how much of that gap deleting the fabric CDC
 * FIFOs should recover.
 *
 * It builds the same path TWICE and reports both:
 *
 *   PRE-2b   braid_link on aclk (400 MHz), braid_framer on the GT user clock
 *            (257.8125 MHz), a PACKET-MODE async FIFO between them each way.
 *   POST-2b  braid_link and braid_framer both on the GT user clock, no FIFOs.
 *
 * The DIFFERENCE is the number to hold the hardware to. If a real card does not
 * improve by roughly that much, the FIFO model was optimistic and the remaining
 * unaccounted latency is in the transceiver itself -- which is hypothesis (A),
 * and it changes what Task 3 is worth. That is the whole reason both models are
 * here rather than just the new one: a prediction you cannot compare against the
 * thing it replaced is not a prediction.
 *
 * CAVEAT, and it matters: the GT is a fixed 10-stage pipe using AMD's published
 * 27.83 ns. Simulation cannot measure our actual transceiver. Only hardware --
 * specifically `braid bench -l 2`, near-end PMA loopback -- can do that.
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


// ---------------------------------------------------------------------------
// One complete A -> wire -> B path. WITH_FIFOS selects the pre- or post-2b
// structure; everything else is identical between the two, which is the point.
//
// The arrival timestamp is captured INSIDE this module, on whichever clock the
// receiving braid_link_rx is actually running on. Sampling it from the top level
// would need a poll faster than the fastest clock in either configuration, and
// getting that wrong shows up as a plausible-looking few-ns error rather than as
// a failure.
// ---------------------------------------------------------------------------
module tb_braid_path #(
    parameter int N_STAB     = 992,
    parameter int N_CORR     = 64,
    parameter bit WITH_FIFOS = 1,
    parameter int GT_STAGES  = 10    // 37.83 ns / 3.879 ns per uclk
) (
    input  logic              aclk,
    input  logic              uclk,
    input  logic              rstn,

    input  logic [N_STAB-1:0] syn_bits,
    input  logic              syn_valid,
    input  logic [19:0]       syn_round,
    input  logic [7:0]        words,

    input  logic              clr_out,
    output logic              out_seen,
    output real               out_time
);

    // The protocol core's clock. Constant select, so this is a plain rename in
    // simulation rather than a real mux.
    wire lclk = WITH_FIFOS ? aclk : uclk;

    // ---------------- A: sender ----------------
    logic [31:0] a_ptx_data, a_prx_data;
    logic        a_ptx_valid, a_ptx_last, a_ptx_ready;
    logic        a_prx_valid, a_prx_last;
    logic [31:0] a_txf, a_txd, a_rxf, a_rxe, a_rxg;
    logic [N_STAB-1:0] a_syn_out; logic a_syn_out_valid, a_syn_out_gap;
    logic [31:0] a_syn_out_round;
    logic [N_CORR-1:0] a_corr_out; logic a_corr_out_valid;

    braid_link_tx #(.N_STAB(N_STAB), .N_CORR(N_CORR)) u_link_a_tx (
        .clk(lclk), .rstn(rstn), .link_up(1'b1), .clr(1'b0),
        .syn_bits(syn_bits), .syn_valid(syn_valid), .syn_round(syn_round),
        .syn_words_sel(words),
        .corr_bits('0), .corr_valid(1'b0),
        .phy_tx_data(a_ptx_data), .phy_tx_valid(a_ptx_valid),
        .phy_tx_last(a_ptx_last), .phy_tx_ready(a_ptx_ready),
        .tx_frames(a_txf), .tx_dropped(a_txd)
    );

    braid_link_rx #(.N_STAB(N_STAB), .N_CORR(N_CORR)) u_link_a_rx (
        .clk(lclk), .rstn(rstn), .link_up(1'b1), .clr(1'b0),
        .syn_out_bits(a_syn_out), .syn_out_valid(a_syn_out_valid),
        .syn_out_round(a_syn_out_round), .syn_out_gap(a_syn_out_gap),
        .corr_out_bits(a_corr_out), .corr_out_valid(a_corr_out_valid),
        .phy_rx_data(a_prx_data), .phy_rx_valid(a_prx_valid),
        .phy_rx_last(a_prx_last), .phy_rx_err(1'b0),
        .rx_frames(a_rxf), .rx_errors(a_rxe), .rx_gaps(a_rxg)
    );

    logic [31:0] a_fr_tx_data; logic a_fr_tx_valid, a_fr_tx_last, a_fr_tx_ready;
    logic [31:0] a_fr_rx_data; logic a_fr_rx_valid, a_fr_rx_last, a_fr_rx_err;

    // ---------------- B: receiver ----------------
    logic [31:0] b_ptx_data, b_prx_data;
    logic        b_ptx_valid, b_ptx_last, b_ptx_ready;
    logic        b_prx_valid, b_prx_last;
    logic [31:0] b_txf, b_txd, b_rxf, b_rxe, b_rxg;
    logic [N_STAB-1:0] b_syn_out; logic b_syn_out_valid, b_syn_out_gap;
    logic [31:0] b_syn_out_round;
    logic [N_CORR-1:0] b_corr_out; logic b_corr_out_valid;

    braid_link_tx #(.N_STAB(N_STAB), .N_CORR(N_CORR)) u_link_b_tx (
        .clk(lclk), .rstn(rstn), .link_up(1'b1), .clr(1'b0),
        // B never transmits syndromes in these tests; it only receives.
        .syn_bits('0), .syn_valid(1'b0), .syn_round(20'b0),
        .syn_words_sel(8'd0),
        .corr_bits('0), .corr_valid(1'b0),
        .phy_tx_data(b_ptx_data), .phy_tx_valid(b_ptx_valid),
        .phy_tx_last(b_ptx_last), .phy_tx_ready(b_ptx_ready),
        .tx_frames(b_txf), .tx_dropped(b_txd)
    );

    braid_link_rx #(.N_STAB(N_STAB), .N_CORR(N_CORR)) u_link_b_rx (
        .clk(lclk), .rstn(rstn), .link_up(1'b1), .clr(1'b0),
        .syn_out_bits(b_syn_out), .syn_out_valid(b_syn_out_valid),
        .syn_out_round(b_syn_out_round), .syn_out_gap(b_syn_out_gap),
        .corr_out_bits(b_corr_out), .corr_out_valid(b_corr_out_valid),
        .phy_rx_data(b_prx_data), .phy_rx_valid(b_prx_valid),
        .phy_rx_last(b_prx_last), .phy_rx_err(1'b0),
        .rx_frames(b_rxf), .rx_errors(b_rxe), .rx_gaps(b_rxg)
    );

    logic [31:0] b_fr_tx_data; logic b_fr_tx_valid, b_fr_tx_last, b_fr_tx_ready;
    logic [31:0] b_fr_rx_data; logic b_fr_rx_valid, b_fr_rx_last, b_fr_rx_err;

    // ---------------- the thing under study ----------------
    generate
        if (WITH_FIFOS) begin : g_cdc
            tb_pkt_fifo #(.WIDTH(32)) u_fifo_a_tx (
                .wr_clk(aclk), .rd_clk(uclk), .rstn(rstn),
                .s_data(a_ptx_data), .s_valid(a_ptx_valid), .s_last(a_ptx_last),
                .s_ready(a_ptx_ready),
                .m_data(a_fr_tx_data), .m_valid(a_fr_tx_valid),
                .m_last(a_fr_tx_last), .m_ready(a_fr_tx_ready)
            );
            tb_pkt_fifo #(.WIDTH(32)) u_fifo_a_rx (
                .wr_clk(uclk), .rd_clk(aclk), .rstn(rstn),
                .s_data(a_fr_rx_data), .s_valid(a_fr_rx_valid),
                .s_last(a_fr_rx_last), .s_ready(),
                .m_data(a_prx_data), .m_valid(a_prx_valid),
                .m_last(a_prx_last), .m_ready(1'b1)
            );
            tb_pkt_fifo #(.WIDTH(32)) u_fifo_b_tx (
                .wr_clk(aclk), .rd_clk(uclk), .rstn(rstn),
                .s_data(b_ptx_data), .s_valid(b_ptx_valid), .s_last(b_ptx_last),
                .s_ready(b_ptx_ready),
                .m_data(b_fr_tx_data), .m_valid(b_fr_tx_valid),
                .m_last(b_fr_tx_last), .m_ready(b_fr_tx_ready)
            );
            tb_pkt_fifo #(.WIDTH(32)) u_fifo_b_rx (
                .wr_clk(uclk), .rd_clk(aclk), .rstn(rstn),
                .s_data(b_fr_rx_data), .s_valid(b_fr_rx_valid),
                .s_last(b_fr_rx_last), .s_ready(),
                .m_data(b_prx_data), .m_valid(b_prx_valid),
                .m_last(b_prx_last), .m_ready(1'b1)
            );
        end else begin : g_direct
            // Task 2b: the protocol core runs on the GT clock, so there is
            // nothing to bridge. This is the entire change, expressed.
            assign a_fr_tx_data  = a_ptx_data;
            assign a_fr_tx_valid = a_ptx_valid;
            assign a_fr_tx_last  = a_ptx_last;
            assign a_ptx_ready   = a_fr_tx_ready;
            assign a_prx_data    = a_fr_rx_data;
            assign a_prx_valid   = a_fr_rx_valid;
            assign a_prx_last    = a_fr_rx_last;

            assign b_fr_tx_data  = b_ptx_data;
            assign b_fr_tx_valid = b_ptx_valid;
            assign b_fr_tx_last  = b_ptx_last;
            assign b_ptx_ready   = b_fr_tx_ready;
            assign b_prx_data    = b_fr_rx_data;
            assign b_prx_valid   = b_fr_rx_valid;
            assign b_prx_last    = b_fr_rx_last;
        end
    endgenerate

    // ---------------- framers, always on the GT clock ----------------
    logic [31:0] a_gt_txdata; logic [7:0] a_gt_txctrl2;
    wire  [31:0] a_gt_rxdata; wire  [15:0] a_gt_rxctrl0;
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

    logic [31:0] b_gt_txdata; logic [7:0] b_gt_txctrl2;
    wire  [31:0] b_gt_rxdata; wire  [15:0] b_gt_rxctrl0;
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

    // ---------------- the wire, with the GT's measured delay ----------------
    // A shift register on uclk. A `#delay` continuous assignment would be
    // INERTIAL and silently swallow every transition shorter than the delay --
    // the data changes every 3.9 ns against a 37.8 ns delay, so nothing would
    // ever propagate.
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

    // ---------------- arrival timestamp, on the receiver's own clock --------
    always @(posedge lclk) begin
        if (!rstn || clr_out) begin
            out_seen <= 1'b0;
            out_time <= 0.0;
        end else if (b_syn_out_valid && !out_seen) begin
            out_seen <= 1'b1;
            out_time <= $realtime;
        end
    end

endmodule


module tb_braid_sys;

    localparam int N_STAB = 992;
    localparam int N_CORR = 64;

    // Real clock ratio: Coyote aclk 400 MHz vs GT user clock 257.8125 MHz.
    localparam real ACLK_HALF = 1.25;    // 400 MHz
    localparam real UCLK_HALF = 1.9394;  // 257.8125 MHz

    // AMD's measured GTY figure at 10.3125 Gbps, 32-bit datapath: 27.83 ns for
    // TX+RX. Plus ~10 ns of cable.
    localparam real GT_DELAY = 27.83 + 10.0;

    logic aclk = 0, uclk = 0, rstn = 0;
    always #(ACLK_HALF) aclk = ~aclk;
    always #(UCLK_HALF) uclk = ~uclk;

    logic [N_STAB-1:0] syn_bits;
    logic              syn_valid;
    logic [19:0]       syn_round;
    logic [7:0]        words;
    logic              clr_out;

    logic old_seen, new_seen;
    real  old_time, new_time;

    tb_braid_path #(.N_STAB(N_STAB), .N_CORR(N_CORR), .WITH_FIFOS(1)) u_old (
        .aclk(aclk), .uclk(uclk), .rstn(rstn),
        .syn_bits(syn_bits), .syn_valid(syn_valid), .syn_round(syn_round),
        .words(words), .clr_out(clr_out),
        .out_seen(old_seen), .out_time(old_time)
    );

    tb_braid_path #(.N_STAB(N_STAB), .N_CORR(N_CORR), .WITH_FIFOS(0)) u_new (
        .aclk(aclk), .uclk(uclk), .rstn(rstn),
        .syn_bits(syn_bits), .syn_valid(syn_valid), .syn_round(syn_round),
        .words(words), .clr_out(clr_out),
        .out_seen(new_seen), .out_time(new_time)
    );

    function automatic logic [N_STAB-1:0] pattern(input logic [19:0] r);
        logic [N_STAB+31:0] p;
        for (int k = 0; k <= (N_STAB/32); k++)
            p[k*32 +: 32] = {12'b0, r} ^ (32'h9E3779B9 * (k + 1));
        return p[N_STAB-1:0];
    endfunction

    // Both paths are driven from the SAME stimulus. The pre-2b path samples it
    // on aclk and the post-2b path on uclk, which is exactly the asymmetry being
    // measured, so the launch instant has to be common to both.
    initial begin
        real t0;
        syn_bits = '0; syn_valid = 0; syn_round = '0; words = 8'd4; clr_out = 1;
        repeat (40) @(posedge aclk);
        rstn = 1;
        repeat (40) @(posedge aclk);

        $display("\n=== System-level one-way latency, pre- vs post-Task-2b ===");
        $display("  aclk 400 MHz, uclk 257.8125 MHz, GT+wire fixed at %0.2f ns", GT_DELAY);
        $display("  pre  = braid_link on aclk, packet CDC FIFOs both ways");
        $display("  post = braid_link on the GT clock, no FIFOs at all\n");
        $display("  words     pre ns    post ns     saved ns");

        for (int w = 1; w <= 31; w = (w * 2 > 31 && w != 31) ? 31 : w * 2) begin
            words = w[7:0];
            clr_out = 1;
            repeat (4) @(posedge aclk);
            clr_out = 0;
            @(posedge aclk);

            syn_bits  <= pattern(20'd3);
            syn_round <= 20'd3;
            syn_valid <= 1'b1;
            t0 = $realtime;
            @(posedge aclk);
            syn_valid <= 1'b0;

            wait (old_seen && new_seen);

            // No "%+f": xsim does not accept the plus flag and prints the
            // literal "8.1f" followed by an unformatted number.
            $display("  %5d   %8.1f   %8.1f   %8.1f",
                     w, old_time - t0, new_time - t0,
                     (old_time - t0) - (new_time - t0));
            repeat (200) @(posedge aclk);
        end

        $display("\n  Hardware, pre-2b, 4 words: 306 ns one-way (612 ns RTT / 2).");
        $display("  If 2b's measured saving matches the 'saved' column, the model is");
        $display("  right and the rest of the budget is the transceiver. If it comes");
        $display("  up short, the FIFO model was optimistic -- check `braid bench -l 2`");
        $display("  (near-end PMA loopback) to weigh our GT on its own.\n");
        $finish;
    end

    initial begin
        #500000;
        $display("*** TIMEOUT -- no frame delivered ***");
        $finish;
    end

endmodule
