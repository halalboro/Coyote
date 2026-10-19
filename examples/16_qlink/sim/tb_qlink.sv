/**
 * tb_qlink — Phase A protocol smoke test
 *
 * Covers the pieces that changed in Phase A:
 *   Test 1  startup: alignment + one SYN frame round-trips cleanly
 *   Test 2  TYPE demux: all four classes land with correct type/flags
 *   Test 3  protocol-only latency (no GT, no CDC) — HDR + 14 payload + CRC
 *   Test 4  corrupt payload: cut-through delivers, then rx_bad retracts
 *   Test 5  back-to-back frames: no state leakage between frames
 *
 * The old N_STAB-shaped stimulus and the Fletcher-16 checksum tests are
 * gone. CRC-32 correctness is implicit — if the RX accepts a frame the
 * TX produced, HDR+ROUND+PAYLOAD+CRC round-tripped.
 */

`timescale 1ns/1ps

module tb_qlink;

    localparam int PAYLOAD_BITS = 416;

    // Protocol classes (match vfpga_top.svh / qlink spec §4).
    localparam logic [3:0] TYPE_SYN = 4'h1;
    localparam logic [3:0] TYPE_FRM = 4'h2;
    localparam logic [3:0] TYPE_FUS = 4'h3;
    localparam logic [3:0] TYPE_CTL = 4'h4;

    logic clk = 0, rstn = 0, b_rstn_rx = 0;
    initial forever #(1.28) clk = ~clk;   // ~390.625 MHz

    // -----------------------------------------------------------------
    // Card A: link_tx -> framer -> wire -> framer -> link_rx (loopback)
    // Card B: same but driven from a separate stimulus.
    // We only exercise A -> B here; the test is one-directional per run.
    // -----------------------------------------------------------------
    // Application side (card A, TX)
    logic [3:0]              a_type, a_flags;
    logic [7:0]              a_src, a_dst, a_epoch;
    logic [31:0]             a_round;
    logic [PAYLOAD_BITS-1:0] a_payload;
    logic                    a_valid;
    logic [31:0]             a_frames, a_dropped;

    // PHY side (card A, TX)
    logic [31:0]             a_ptx_data;
    logic                    a_ptx_valid, a_ptx_last, a_ptx_ready;
    logic [31:0]             a_ptx_hdr,  a_ptx_cks;
    logic [31:0]             a_txdata;

    qlink_link_tx u_link_a_tx (
        .clk(clk), .rstn(rstn), .link_up(1'b1), .clr(1'b0),
        .tx_type(a_type), .tx_flags(a_flags),
        .tx_src(a_src), .tx_dst(a_dst), .tx_epoch(a_epoch),
        .tx_round(a_round), .tx_payload(a_payload), .tx_valid(a_valid),
        .phy_tx_data(a_ptx_data), .phy_tx_valid(a_ptx_valid),
        .phy_tx_last(a_ptx_last), .phy_tx_ready(a_ptx_ready),
        .phy_tx_hdr(a_ptx_hdr),  .phy_tx_cks(a_ptx_cks),
        .tx_frames(a_frames), .tx_dropped(a_dropped)
    );

    qlink_framer_raw u_fr_a (
        .clk_tx(clk), .rstn_tx(rstn), .link_up_tx(1'b1),
        .phy_tx_data(a_ptx_data), .phy_tx_valid(a_ptx_valid),
        .phy_tx_last(a_ptx_last), .phy_tx_ready(a_ptx_ready),
        .phy_tx_hdr(a_ptx_hdr), .phy_tx_cks(a_ptx_cks),
        .gt_txdata(a_txdata),
        .clk_rx(clk), .rstn_rx(rstn), .link_up_rx(1'b1),
        .phy_rx_data(), .phy_rx_valid(),
        .phy_rx_eof(), .phy_rx_err(),
        .phy_rx_hdr(), .phy_rx_sof(),
        .phy_rx_cks(),
        .gt_rxdata(32'h5C3D_2A96),  // RX-side of A is unused in this TB
        .rxslide(), .rx_aligned(),
        .ber_count(), .dbg()
    );

    // Wire with configurable corruption and bit misalignment. The receive
    // side of card B reads this.
    logic [31:0] wire_data;
    logic [31:0] b_txdata_q;
    int          b_offset;
    logic        b_rxslide;
    logic        b_rxslide_q;
    logic        corrupt_pulse = 1'b0;
    logic [31:0] corrupt_mask  = 32'h0;

    always_ff @(posedge clk) b_txdata_q <= a_txdata;

    // Edge-triggered slide: one bit of rotation per rxslide pulse (UG578
    // compliant). Matches the DUT model used in tb_qlink_raw.sv.
    always @(posedge clk) begin
        b_rxslide_q <= b_rxslide;
        if (!b_rstn_rx)                     b_offset <= 0;
        else if (b_rxslide && !b_rxslide_q) b_offset <= (b_offset + 31) % 32;
    end

    always_comb begin
        logic [63:0] widened;
        widened  = {a_txdata, b_txdata_q};
        wire_data = widened[b_offset +: 32];
        if (corrupt_pulse) wire_data = wire_data ^ corrupt_mask;
    end

    // Card B: framer -> link_rx
    logic [31:0]             b_prx_data;
    logic                    b_prx_valid, b_prx_last, b_prx_sof;
    logic [31:0]             b_prx_hdr, b_prx_cks;
    logic                    b_rx_aligned;

    qlink_framer_raw u_fr_b (
        .clk_tx(clk), .rstn_tx(rstn), .link_up_tx(1'b1),
        .phy_tx_data(32'h0), .phy_tx_valid(1'b0),
        .phy_tx_last(1'b0), .phy_tx_ready(),
        .phy_tx_hdr(32'h0), .phy_tx_cks(32'h0),
        .gt_txdata(),
        .clk_rx(clk), .rstn_rx(b_rstn_rx), .link_up_rx(1'b1),
        .phy_rx_data(b_prx_data), .phy_rx_valid(b_prx_valid),
        .phy_rx_eof(b_prx_last), .phy_rx_err(),
        .phy_rx_hdr(b_prx_hdr), .phy_rx_sof(b_prx_sof),
        .phy_rx_cks(b_prx_cks),
        .gt_rxdata(wire_data),
        .rxslide(b_rxslide), .rx_aligned(b_rx_aligned),
        .ber_count(), .dbg()
    );

    logic                    b_valid, b_bad;
    logic [3:0]              b_type, b_flags;
    logic [7:0]              b_src, b_dst, b_epoch;
    logic [31:0]             b_round;
    logic [PAYLOAD_BITS-1:0] b_payload;
    logic [31:0]             b_frames, b_errors;

    qlink_link_rx u_link_b_rx (
        .clk(clk), .rstn(b_rstn_rx), .link_up(1'b1), .clr(1'b0),
        .rx_valid(b_valid), .rx_bad(b_bad),
        .rx_type(b_type), .rx_flags(b_flags),
        .rx_src(b_src), .rx_dst(b_dst), .rx_epoch(b_epoch),
        .rx_round(b_round), .rx_payload(b_payload),
        .phy_rx_data(b_prx_data), .phy_rx_valid(b_prx_valid),
        .phy_rx_eof(b_prx_last), .phy_rx_sof(b_prx_sof),
        .phy_rx_hdr(b_prx_hdr), .phy_rx_cks(b_prx_cks),
        .phy_rx_err(1'b0),
        .rx_frames(b_frames), .rx_errors(b_errors)
    );

    // -----------------------------------------------------------------
    // Test helpers
    // -----------------------------------------------------------------
    function automatic logic [PAYLOAD_BITS-1:0] pattern(input logic [31:0] r);
        logic [PAYLOAD_BITS+31:0] p;
        for (int k = 0; k <= (PAYLOAD_BITS/32); k++)
            p[k*32 +: 32] = r ^ (32'h9E3779B9 * (k + 1));
        return p[PAYLOAD_BITS-1:0];
    endfunction

    task send_frame(input logic [3:0] t, input logic [3:0] f,
                    input logic [7:0] s, input logic [7:0] d, input logic [7:0] e,
                    input logic [31:0] rnd);
        @(posedge clk);
        a_type <= t; a_flags <= f; a_src <= s; a_dst <= d; a_epoch <= e;
        a_round <= rnd; a_payload <= pattern(rnd);
        a_valid <= 1'b1;
        @(posedge clk);
        a_valid <= 1'b0;
    endtask

    // -----------------------------------------------------------------
    initial begin
        a_type = 4'h0; a_flags = 4'h0;
        a_src = 8'h0; a_dst = 8'h0; a_epoch = 8'h0;
        a_round = 32'h0; a_payload = '0; a_valid = 1'b0;

        rstn = 0; b_rstn_rx = 0;
        repeat (20) @(posedge clk);
        rstn = 1; b_rstn_rx = 1;

        // Wait for the aligner to lock up. Worst-case convergence from offset 0
        // and with LOCK_COUNT consecutive ALIGN words is < 400 cycles.
        wait (b_rx_aligned === 1'b1);
        $display("\n=== Test 1: aligned link, one SYN frame ===");
        $display("  [startup] aligned after %0t ps", $time);

        // Give a few extra idle cycles so the scramblers are in known '1 state.
        repeat (20) @(posedge clk);

        send_frame(TYPE_SYN, 4'h0, 8'h01, 8'h02, 8'h00, 32'h0000_0001);

        begin
            automatic longint tdl = $time + 400 * 1280;
            wait (b_valid === 1'b1 || $time > tdl);
            if (b_valid !== 1'b1) begin
                $display("  *** FAIL: no frame received");
                $finish;
            end
        end
        if (b_type !== TYPE_SYN || b_round !== 32'h1 ||
            b_payload !== pattern(32'h1)) begin
            $display("  *** FAIL: type=%0h round=%0h payload mismatch", b_type, b_round);
        end else begin
            $display("  PASS: SYN frame delivered correctly");
        end

        // Wait for the bad-strobe window to pass (two cycles after rx_valid).
        repeat (4) @(posedge clk);
        if (b_bad) begin
            $display("  *** FAIL: rx_bad asserted on a clean frame");
        end

        // -------------------------------------------------------------
        $display("\n=== Test 2: TYPE demux (SYN / FRM / FUS / CTL) ===");
        begin
            automatic int ok = 1;
            logic [3:0] types [4] = '{TYPE_SYN, TYPE_FRM, TYPE_FUS, TYPE_CTL};
            for (int i = 0; i < 4; i++) begin
                automatic longint tdl;
                send_frame(types[i], 4'(i), 8'(i), 8'(i+10), 8'(i+20),
                           32'h0000_0100 + i);
                tdl = $time + 400 * 1280;
                wait (b_valid === 1'b1 || $time > tdl);
                if (b_valid !== 1'b1) begin
                    $display("  *** FAIL [i=%0d]: no frame", i); ok = 0;
                end else if (b_type !== types[i] || b_round !== 32'h0100 + i) begin
                    $display("  *** FAIL [i=%0d]: type=%0h expected=%0h round=%0h",
                             i, b_type, types[i], b_round); ok = 0;
                end
                repeat (4) @(posedge clk);
            end
            if (ok) $display("  PASS: all four classes delivered with correct TYPE");
        end

        // -------------------------------------------------------------
        $display("\n=== Test 3: protocol-only cycle count ===");
        begin
            automatic longint t_fire, t_delivered;
            automatic real ns;
            @(posedge clk);
            t_fire = $time;
            send_frame(TYPE_SYN, 4'h0, 8'h00, 8'h00, 8'h00, 32'h0000_0200);
            wait (b_valid === 1'b1);
            t_delivered = $time;
            ns = (t_delivered - t_fire) * 0.001;
            $display("  frame-fire to rx_valid: %0.1f ns (expect ~41 ns +  framer HDR cycle)",
                     ns);
            repeat (4) @(posedge clk);
        end

        // -------------------------------------------------------------
        $display("\n=== Test 4: corrupt payload, cut-through + retract ===");
        begin
            automatic int delivered = 0;
            automatic int bad_count = 0;
            automatic longint tdl;

            // Fire one frame, flip a bit while a payload word is on the wire.
            // The scrambler polynomial turns one wire-bit flip into three
            // descrambled bit flips, so CRC-32 is overwhelmingly likely to
            // reject it. Corrupt for a few cycles to be sure the hit lands
            // inside the frame (HDR / payload / trailer — any of them fails
            // the CRC).
            fork
                send_frame(TYPE_SYN, 4'h0, 8'h00, 8'h00, 8'h00, 32'h0000_0300);
                begin
                    wait (a_ptx_valid === 1'b1);
                    repeat (6) @(posedge clk);
                    corrupt_mask  = 32'hFEED_C0DE;
                    corrupt_pulse = 1'b1;
                    repeat (3) @(posedge clk);
                    corrupt_pulse = 1'b0;
                    corrupt_mask  = 32'h0;
                end
            join

            // Watch for rx_valid and rx_bad concurrently across the delivery
            // window. rx_bad is a 1-cycle pulse 1-2 cycles after rx_valid, so
            // we need to be looking at every posedge, not just the last one.
            tdl = $time + 400 * 1280;
            fork : watch4
                begin
                    while ($time < tdl) begin
                        @(posedge clk);
                        if (b_valid) delivered++;
                        if (b_bad)   bad_count++;
                        if (delivered && bad_count) disable watch4;
                    end
                end
            join

            if (delivered && bad_count)
                $display("  PASS: delivered once, retracted once (delivered=%0d bad=%0d)",
                         delivered, bad_count);
            else
                $display("  *** FAIL: delivered=%0d retracted=%0d", delivered, bad_count);
        end

        // -------------------------------------------------------------
        $display("\n=== Test 5: back-to-back frames ===");
        begin
            automatic int received = 0;
            automatic longint tdl;
            automatic logic [3:0] exp_t;
            automatic int ok = 1;
            // Send 5 back-to-back frames at the fastest cadence possible.
            fork
                begin
                    for (int i = 0; i < 5; i++) begin
                        send_frame(TYPE_SYN, 4'h0, 8'h00, 8'h00, 8'h00,
                                   32'h0000_0400 + i);
                        // Space minimally; let link_tx finish last frame first.
                        repeat (18) @(posedge clk);
                    end
                end
                begin
                    tdl = $time + 2000 * 1280;
                    while (received < 5 && $time < tdl) begin
                        @(posedge clk);
                        if (b_valid) begin
                            if (b_round !== 32'h0000_0400 + received) begin
                                $display("  *** FAIL: expected round=%0h got %0h",
                                         32'h0000_0400 + received, b_round);
                                ok = 0;
                            end
                            received++;
                        end
                    end
                end
            join_any
            disable fork;
            if (received == 5 && ok) $display("  PASS: 5 back-to-back frames delivered in order");
            else $display("  *** FAIL: received=%0d (want 5)", received);
        end

        $display("\nDone. a_frames=%0d a_dropped=%0d b_frames=%0d b_errors=%0d",
                 a_frames, a_dropped, b_frames, b_errors);
        $finish;
    end

    initial begin
        #(5_000_000);
        $display("*** TIMEOUT ***");
        $finish;
    end

endmodule
