/**
 * QLINK system-level latency model
 *
 * tb_qlink.sv proves the protocol. THIS testbench predicts the full one-way
 * latency of a real link, so a build can be checked against a number decided
 * beforehand rather than explained afterwards.
 *
 * It builds the same path twice at two LINE RATES and reports both:
 *
 *   now   10.3125 Gbps, GT user clock 257.8125 MHz  -- what is on the cards
 *   next  15.625  Gbps, GT user clock 390.625  MHz  -- Task 3
 *
 * CALIBRATION. The GT is a fixed pipeline whose stage count does not change
 * with line rate, so its latency in nanoseconds scales with the clock. The
 * stage count here comes from OUR MEASUREMENT -- 55.6 ns via `qlink bench -l 2`
 * at 10.3125 Gbps, plus ~9.6 ns of cable -- not from AMD's published 27.83 ns,
 * which is less than half what our transceiver actually does. There is no point
 * modelling someone else's silicon when we have measured our own.
 *
 * The pre-2b comparison this file used to carry is gone. Once the framer
 * stopped holding a word back, "old FIFOs plus new framer" was a configuration
 * that never existed, and a fictional baseline is worse than none. The real
 * before/after is on hardware: 306 ns one-way, then 117.9.
 */

`timescale 1ns/1ps

// ---------------------------------------------------------------------------
// One complete A -> wire -> B path, parameterised only by how many uclk periods
// the transceiver and cable take.
//
// The arrival timestamp is captured INSIDE this module, on whichever clock the
// receiving qlink_link_rx is actually running on. Sampling it from the top level
// would need a poll faster than the fastest clock in either configuration, and
// getting that wrong shows up as a plausible-looking few-ns error rather than as
// a failure.
// ---------------------------------------------------------------------------
module tb_qlink_path #(
    parameter int N_STAB     = 992,
    parameter int N_CORR     = 64,
    // Total fixed delay each way, in uclk periods: our MEASURED GT (55.6 ns at
    // 10.3125 Gbps, from `qlink bench -l 2`) plus ~9.6 ns of cable. Not AMD's
    // published 27.83 -- ours is twice that and there is no point modelling
    // someone else's transceiver when we have measured our own.
    parameter int GT_STAGES  = 17
) (
    input  logic              uclk,
    input  logic              rstn,

    input  logic [N_STAB-1:0] syn_bits,
    input  logic              syn_valid,
    input  logic [15:0]       syn_round,
    input  logic [7:0]        words,

    input  logic              clr_out,
    output logic              out_seen,
    output real               out_time
);

    // Everything runs on the GT clock. Since Task 2b there is nothing else.
    wire lclk = uclk;

    // Framer sidebands. Declared HERE, above the first instance that uses them:
    // below it, Verilog's implicit-net rule silently turns each into an
    // undriven 1-bit wire and the header/checksum read as zero.
    logic [23:0] a_hdr, a_cks, b_hdr, b_cks;
    logic [23:0] a_rhdr, a_rcks, b_rhdr, b_rcks;
    logic        a_rsof, b_rsof;


    // ---------------- A: sender ----------------
    logic [31:0] a_ptx_data, a_prx_data;
    logic        a_ptx_valid, a_ptx_last, a_ptx_ready;
    logic        a_prx_valid, a_prx_last;
    logic [31:0] a_txf, a_txd, a_rxf, a_rxe, a_rxg;
    logic [N_STAB-1:0] a_syn_out; logic a_syn_out_valid, a_syn_out_gap;
    logic [31:0] a_syn_out_round;
    logic [N_CORR-1:0] a_corr_out; logic a_corr_out_valid;

    qlink_link_tx #(.N_STAB(N_STAB), .N_CORR(N_CORR)) u_link_a_tx (
        .clk(lclk), .rstn(rstn), .link_up(1'b1), .clr(1'b0),
        .syn_bits(syn_bits), .syn_valid(syn_valid), .syn_round(syn_round),
        .syn_words_sel(words),
        .corr_bits('0), .corr_valid(1'b0),
        .phy_tx_data(a_ptx_data), .phy_tx_valid(a_ptx_valid),
        .phy_tx_last(a_ptx_last), .phy_tx_ready(a_ptx_ready),
        .phy_tx_hdr(a_hdr), .phy_tx_cks(a_cks), .phy_tx_type(), .syn_sparse(1'b0),
        .tx_frames(a_txf), .tx_dropped(a_txd)
    );

    qlink_link_rx #(.N_STAB(N_STAB), .N_CORR(N_CORR)) u_link_a_rx (
        .clk(lclk), .rstn(rstn), .link_up(1'b1), .clr(1'b0),
        .syn_out_bits(a_syn_out), .syn_out_valid(a_syn_out_valid),
        .syn_out_round(a_syn_out_round), .syn_out_gap(a_syn_out_gap), .syn_out_bad(),
        .corr_out_bits(a_corr_out), .corr_out_valid(a_corr_out_valid),
        .phy_rx_data(a_prx_data), .phy_rx_valid(a_prx_valid),
        .phy_rx_eof(a_prx_last), .phy_rx_sof(a_rsof), .phy_rx_hdr(a_rhdr),
        .phy_rx_type(2'd0), .syn_out_sparse(), .phy_rx_cks(a_rcks), .phy_rx_err(1'b0),
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

    qlink_link_tx #(.N_STAB(N_STAB), .N_CORR(N_CORR)) u_link_b_tx (
        .clk(lclk), .rstn(rstn), .link_up(1'b1), .clr(1'b0),
        // B never transmits syndromes in these tests; it only receives.
        .syn_bits('0), .syn_valid(1'b0), .syn_round(16'b0),
        .syn_words_sel(8'd0),
        .corr_bits('0), .corr_valid(1'b0),
        .phy_tx_data(b_ptx_data), .phy_tx_valid(b_ptx_valid),
        .phy_tx_last(b_ptx_last), .phy_tx_ready(b_ptx_ready),
        .phy_tx_hdr(b_hdr), .phy_tx_cks(b_cks), .phy_tx_type(), .syn_sparse(1'b0),
        .tx_frames(b_txf), .tx_dropped(b_txd)
    );

    qlink_link_rx #(.N_STAB(N_STAB), .N_CORR(N_CORR)) u_link_b_rx (
        .clk(lclk), .rstn(rstn), .link_up(1'b1), .clr(1'b0),
        .syn_out_bits(b_syn_out), .syn_out_valid(b_syn_out_valid),
        .syn_out_round(b_syn_out_round), .syn_out_gap(b_syn_out_gap), .syn_out_bad(),
        .corr_out_bits(b_corr_out), .corr_out_valid(b_corr_out_valid),
        .phy_rx_data(b_prx_data), .phy_rx_valid(b_prx_valid),
        .phy_rx_eof(b_prx_last), .phy_rx_sof(b_rsof), .phy_rx_hdr(b_rhdr),
        .phy_rx_type(2'd0), .syn_out_sparse(), .phy_rx_cks(b_rcks), .phy_rx_err(1'b0),
        .rx_frames(b_rxf), .rx_errors(b_rxe), .rx_gaps(b_rxg)
    );

    logic [31:0] b_fr_tx_data; logic b_fr_tx_valid, b_fr_tx_last, b_fr_tx_ready;
    logic [31:0] b_fr_rx_data; logic b_fr_rx_valid, b_fr_rx_last, b_fr_rx_err;

    // ---------------- the thing under study ----------------
    // Task 2b: the protocol core runs on the GT clock, so there is nothing to
    // bridge. This is the entire change, expressed.
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

    // ---------------- framers, always on the GT clock ----------------
    logic [31:0] a_gt_txdata; logic [7:0] a_gt_txctrl2;
    wire  [31:0] a_gt_rxdata; wire  [15:0] a_gt_rxctrl0;
    logic [1:0]  a_dbg;

    qlink_framer u_fr_a (
        .clk_tx(uclk), .rstn_tx(rstn), .link_up_tx(1'b1),
        .clk_rx(uclk), .rstn_rx(rstn), .link_up_rx(1'b1),
        .phy_tx_data(a_fr_tx_data), .phy_tx_valid(a_fr_tx_valid),
        .phy_tx_last(a_fr_tx_last), .phy_tx_ready(a_fr_tx_ready),
        .phy_tx_hdr(a_hdr), .phy_tx_cks(a_cks), .phy_tx_type(2'd0),
        .phy_rx_data(a_fr_rx_data), .phy_rx_valid(a_fr_rx_valid),
        .phy_rx_eof(a_fr_rx_last), .phy_rx_err(a_fr_rx_err),
        .phy_rx_hdr(a_rhdr), .phy_rx_sof(a_rsof), .phy_rx_type(), .phy_rx_cks(a_rcks),
        .gt_txdata(a_gt_txdata), .gt_txctrl2(a_gt_txctrl2),
        .gt_rxdata(a_gt_rxdata), .gt_rxctrl0(a_gt_rxctrl0),
        .gt_rxctrl1(16'b0), .gt_rxctrl3(8'b0), .dbg(a_dbg)
    );

    logic [31:0] b_gt_txdata; logic [7:0] b_gt_txctrl2;
    wire  [31:0] b_gt_rxdata; wire  [15:0] b_gt_rxctrl0;
    logic [1:0]  b_dbg;

    qlink_framer u_fr_b (
        .clk_tx(uclk), .rstn_tx(rstn), .link_up_tx(1'b1),
        .clk_rx(uclk), .rstn_rx(rstn), .link_up_rx(1'b1),
        .phy_tx_data(b_fr_tx_data), .phy_tx_valid(b_fr_tx_valid),
        .phy_tx_last(b_fr_tx_last), .phy_tx_ready(b_fr_tx_ready),
        .phy_tx_hdr(b_hdr), .phy_tx_cks(b_cks), .phy_tx_type(2'd0),
        .phy_rx_data(b_fr_rx_data), .phy_rx_valid(b_fr_rx_valid),
        .phy_rx_eof(b_fr_rx_last), .phy_rx_err(b_fr_rx_err),
        .phy_rx_hdr(b_rhdr), .phy_rx_sof(b_rsof), .phy_rx_type(), .phy_rx_cks(b_rcks),
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


module tb_qlink_sys;

    localparam int N_STAB = 992;
    localparam int N_CORR = 64;

    // Two line rates, two GT user clocks.
    localparam real UCLK_NOW_HALF  = 1.93940;   // 257.8125 MHz, 10.3125 Gbps
    localparam real UCLK_NEXT_HALF = 1.28000;   // 390.625  MHz, 15.625  Gbps

    // Measured fixed delay each way at 10.3125 Gbps: 55.6 ns of GT (bench -l 2)
    // + ~9.6 ns of cable = 65.2 ns = 16.8 periods of 3.879 ns.
    // The GT part scales with the clock, the cable does not:
    //   next = 55.6/1.5152 + 9.6 = 46.3 ns = 18.1 periods of 2.560 ns.
    localparam int STAGES_NOW  = 17;
    localparam int STAGES_NEXT = 18;

    logic uclk_now = 0, uclk_next = 0, rstn = 0;
    always #(UCLK_NOW_HALF)  uclk_now  = ~uclk_now;
    always #(UCLK_NEXT_HALF) uclk_next = ~uclk_next;

    logic [N_STAB-1:0] syn_bits;
    logic              syn_valid_now, syn_valid_next;
    logic [15:0]       syn_round;
    logic [7:0]        words;
    logic              clr_out;

    logic now_seen, next_seen;
    real  now_time, next_time;

    tb_qlink_path #(.N_STAB(N_STAB), .N_CORR(N_CORR), .GT_STAGES(STAGES_NOW)) u_now (
        .uclk(uclk_now), .rstn(rstn),
        .syn_bits(syn_bits), .syn_valid(syn_valid_now), .syn_round(syn_round),
        .words(words), .clr_out(clr_out),
        .out_seen(now_seen), .out_time(now_time)
    );

    tb_qlink_path #(.N_STAB(N_STAB), .N_CORR(N_CORR), .GT_STAGES(STAGES_NEXT)) u_next (
        .uclk(uclk_next), .rstn(rstn),
        .syn_bits(syn_bits), .syn_valid(syn_valid_next), .syn_round(syn_round),
        .words(words), .clr_out(clr_out),
        .out_seen(next_seen), .out_time(next_time)
    );

    function automatic logic [N_STAB-1:0] pattern(input logic [15:0] r);
        logic [N_STAB+31:0] p;
        for (int k = 0; k <= (N_STAB/32); k++)
            p[k*32 +: 32] = {16'b0, r} ^ (32'h9E3779B9 * (k + 1));
        return p[N_STAB-1:0];
    endfunction

    // Each path is launched on ITS OWN clock, so the launch instant is a real
    // edge in that domain rather than a shared edge that only one of them sees.
    task automatic launch_now();
        @(posedge uclk_now); syn_valid_now <= 1'b1;
        @(posedge uclk_now); syn_valid_now <= 1'b0;
    endtask
    task automatic launch_next();
        @(posedge uclk_next); syn_valid_next <= 1'b1;
        @(posedge uclk_next); syn_valid_next <= 1'b0;
    endtask

    initial begin
        real t0n, t0x;
        syn_bits = '0; syn_valid_now = 0; syn_valid_next = 0;
        syn_round = '0; words = 8'd4; clr_out = 1;
        repeat (40) @(posedge uclk_now);
        rstn = 1;
        repeat (40) @(posedge uclk_now);

        $display("\n=== Predicted one-way latency, 10.3125 vs 15.625 Gbps ===");
        $display("  GT calibrated from MEASUREMENT: 55.6 ns at 10.3125 Gbps");
        $display("  (qlink bench -l 2), plus ~9.6 ns of cable.\n");
        $display("  words    10.3125G    15.625G      saved");

        for (int w = 1; w <= 31; w = (w * 2 > 31 && w != 31) ? 31 : w * 2) begin
            words = w[7:0];
            clr_out = 1; repeat (4) @(posedge uclk_now); clr_out = 0;
            syn_bits = pattern(16'd3); syn_round = 16'd3;

            t0n = $realtime; launch_now();
            wait (now_seen);
            t0x = $realtime; launch_next();
            wait (next_seen);

            $display("  %5d   %8.1f   %8.1f   %8.1f",
                     w, now_time - t0n, next_time - t0x,
                     (now_time - t0n) - (next_time - t0x));
            repeat (200) @(posedge uclk_now);
        end

        $display("\n  Hardware today at 4 words: 117.9 ns one-way, measured");
        $display("  symmetrically (echo --words 4 / bench --words 4).");
        $display("  If the 10.3125G column does not land near that, this model");
        $display("  is wrong and its 15.625G prediction is worth nothing.\n");
        $finish;
    end

    initial begin
        #500000;
        $display("*** TIMEOUT -- no frame delivered ***");
        $finish;
    end

endmodule
