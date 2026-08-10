/**
 * braid_cdc_event unit test
 *
 * This module is the one piece of Task 2b that neither tb_braid nor
 * tb_braid_sys touches, and it is also the one whose failure mode is silent:
 * a torn wide transfer produces a payload that is half of one round and half of
 * the next, carried by a perfectly well-formed valid pulse. The checksum was
 * computed on the far side of the crossing, so nothing downstream can catch it.
 *
 * Two clocks, deliberately not integer-related, at the real frequencies:
 * 257.8125 MHz source (the GT receive clock) and 400 MHz destination (aclk).
 * They drift against each other for the whole run, so the accept and delivery
 * edges land in every relative phase rather than one convenient alignment.
 *
 * WIDTH is 1012 -- the actual echo-path width, which is also the widest
 * xpm_cdc_handshake this design can legally instantiate.
 *
 * The contract under test:
 *   1. Every value the crossing ACCEPTS is delivered exactly once, unmodified,
 *      and in order.
 *   2. Values offered while busy are dropped, never queued, never torn.
 *   3. src_accept genuinely marks the latching cycle, so a caller that holds
 *      src_valid until src_accept can never lose an update.
 */

`timescale 1ns/1ps

module tb_braid_cdc;

    localparam int W = 1012;    // N_STAB(992) + round(20)
    localparam int N = 200;

    logic sclk = 0, dclk = 0, srstn = 0;
    always #1.9394 sclk = ~sclk;   // 257.8125 MHz, the GT clock
    always #1.2500 dclk = ~dclk;   // 400 MHz, aclk

    logic         s_valid, s_busy, s_accept;
    logic [W-1:0] s_data;
    logic         d_valid;
    logic [W-1:0] d_data;

    braid_cdc_event #(.WIDTH(W)) dut (
        .src_clk(sclk), .src_rstn(srstn),
        .src_valid(s_valid), .src_data(s_data),
        .src_busy(s_busy), .src_accept(s_accept),
        .dest_clk(dclk), .dest_valid(d_valid), .dest_data(d_data)
    );

    // A value wide enough that a tear anywhere shows up: every 32-bit lane
    // carries the sequence number mixed with the lane index, so a payload
    // assembled from two different transfers cannot look self-consistent.
    function automatic logic [W-1:0] mk(input int unsigned n);
        logic [W+31:0] p;
        for (int k = 0; k <= (W/32); k++)
            p[k*32 +: 32] = (32'h9E3779B9 * (k + 1)) ^ n;
        return p[W-1:0];
    endfunction

    logic [W-1:0] expect_q [$];
    int n_offered = 0, n_accepted = 0, n_recv = 0, n_bad = 0, n_unexpected = 0;
    bit pulse_mode = 0;

    // Delivery latency, measured rather than assumed. vfpga_top quotes this
    // number in the comment explaining why every reported RTT contains a fixed
    // echo-crossing term, and a quoted number nobody measured is how a budget
    // ends up with 166 ns unaccounted for.
    real t_acc_q [$];
    real lat_min = 1.0e9, lat_max = 0.0, lat_sum = 0.0;
    int  lat_n = 0;

    // ---------------- producer ----------------
    // Level mode: hold s_valid until s_accept, then present the next value.
    // Pulse mode: offer a one-cycle pulse regardless of busy, so the crossing
    // has to drop what it cannot take.
    int pulse_gap = 0;

    always @(posedge sclk) begin
        if (!srstn) begin
            s_valid <= 1'b0;
            s_data  <= '0;
        end else if (!pulse_mode) begin
            if (!s_valid) begin
                if (n_offered < N) begin
                    s_data  <= mk(n_offered);
                    s_valid <= 1'b1;
                end
            end else if (s_accept) begin
                // s_data is being latched by the DUT on this same edge, so this
                // is exactly the value that must come out the other side.
                expect_q.push_back(s_data);
                t_acc_q.push_back($realtime);
                n_accepted <= n_accepted + 1;
                n_offered  <= n_offered + 1;
                s_valid    <= 1'b0;
            end
        end else begin
            s_valid <= 1'b0;
            if (s_valid && s_accept) begin
                expect_q.push_back(s_data);
                n_accepted <= n_accepted + 1;
            end
            if (pulse_gap == 0) begin
                if (n_offered < N) begin
                    s_data    <= mk(1000 + n_offered);
                    s_valid   <= 1'b1;
                    n_offered <= n_offered + 1;
                end
                pulse_gap <= 2;          // far faster than the crossing can drain
            end else begin
                pulse_gap <= pulse_gap - 1;
            end
        end
    end

    // ---------------- consumer ----------------
    logic [W-1:0] exp;
    always @(posedge dclk) begin
        if (d_valid) begin
            if (expect_q.size() == 0) begin
                n_unexpected <= n_unexpected + 1;
            end else begin
                exp = expect_q.pop_front();
                if (d_data !== exp) n_bad <= n_bad + 1;
                n_recv <= n_recv + 1;
                if (t_acc_q.size() > 0) begin
                    real lat = $realtime - t_acc_q.pop_front();
                    if (lat < lat_min) lat_min = lat;
                    if (lat > lat_max) lat_max = lat;
                    lat_sum += lat;
                    lat_n   += 1;
                end
            end
        end
    end

    initial begin
        repeat (20) @(posedge sclk);
        srstn = 1;

        // ---- Test 1: level-with-accept, nothing may be lost ----
        pulse_mode = 0;
        wait (n_offered == N);
        repeat (200) @(posedge dclk);

        $display("\n=== Test 1: level + src_accept (the status-register pattern) ===");
        $display("  offered=%0d accepted=%0d delivered=%0d corrupt=%0d unexpected=%0d",
                 n_offered, n_accepted, n_recv, n_bad, n_unexpected);
        if (n_accepted == N && n_recv == N && n_bad == 0 && n_unexpected == 0
            && expect_q.size() == 0)
            $display("  PASS: all %0d values crossed exactly once, uncorrupted", N);
        else
            $display("  *** FAIL ***");

        $display("  accept -> dest_valid: min %0.1f ns  mean %0.1f ns  max %0.1f ns",
                 lat_min, lat_sum / lat_n, lat_max);
        $display("  (this is the fixed term inside every reported RTT; the real");
        $display("   decoder does not echo and never pays it)");

        // ---- Test 2: pulses faster than the crossing drains ----
        n_offered = 0; n_accepted = 0; n_recv = 0; n_bad = 0; n_unexpected = 0;
        expect_q.delete(); t_acc_q.delete();
        pulse_mode = 1;
        wait (n_offered == N);
        repeat (400) @(posedge dclk);

        $display("\n=== Test 2: pulses while busy (the drop-don't-queue pattern) ===");
        $display("  offered=%0d accepted=%0d delivered=%0d corrupt=%0d unexpected=%0d",
                 n_offered, n_accepted, n_recv, n_bad, n_unexpected);
        // Dropping is the CORRECT behaviour here, so accepted < offered is
        // expected and is not a failure. What must hold is that everything
        // accepted arrives intact: a dropped syndrome is a counted gap, a torn
        // one is a wrong correction.
        if (n_accepted < n_offered && n_recv == n_accepted && n_bad == 0
            && n_unexpected == 0 && expect_q.size() == 0)
            $display("  PASS: %0d of %0d offered were dropped, %0d crossed intact",
                     n_offered - n_accepted, n_offered, n_recv);
        else if (n_accepted == n_offered)
            $display("  *** FAIL: nothing was dropped -- the test did not stress it ***");
        else
            $display("  *** FAIL ***");

        $display("\nDone.");
        $finish;
    end

    initial begin
        #2000000;
        $display("*** TIMEOUT ***");
        $finish;
    end

endmodule
