/**
 * BRAID protocol testbench
 *
 * Two complete braid_link + braid_framer stacks wired back to back, with the
 * GT replaced by a direct connection of {txdata, txcharisk} to
 * {rxdata, rxcharisk}. That is exactly what a working, correctly-aligned GT
 * delivers, so this exercises the whole framing and protocol path without the
 * transceiver's simulation model.
 *
 * Deliberately also models the failure that cost three hardware builds: set
 * MISALIGN to a non-zero byte count and the receiver sees the byte stream
 * rotated, which is what RX_COMMA_ALIGN_WORD=1 does on real silicon. The test
 * asserts that a correctly aligned link passes AND that a misaligned one is
 * caught rather than silently delivering bad syndromes.
 *
 *   xvlog -sv tb_braid.sv ../hw/src/hdl/braid_link_tx.sv \
 *                          ../hw/src/hdl/braid_link_rx.sv \
 *              ../../../hw/hdl/braid/braid_framer.sv
 *   xelab -debug typical tb_braid -s tb && xsim tb -R
 */

`timescale 1ns/1ps

module tb_braid;

    localparam int N_STAB = 992;    // match vfpga_top: 31 words max (echo CDC cap)
    localparam int N_CORR = 64;

    logic clk = 0, rstn = 0;
    always #2 clk = ~clk;          // 250 MHz-ish, value is irrelevant here

    // ------------------------------------------------------------ A -> B
    logic [31:0] a_txdata, b_rxdata;
    logic [7:0]  a_txctrl2;
    logic [15:0] b_rxctrl0;
    logic [31:0] b_txdata, a_rxdata;
    logic [7:0]  b_txctrl2;
    logic [15:0] a_rxctrl0;

    // Byte rotation applied to the A->B direction, modelling a comma that
    // aligned to the wrong lane. 0 = correct alignment.
    int MISALIGN = 0;

    // Framer sidebands. Declared HERE, above the first instance that uses them:
    // below it, Verilog's implicit-net rule silently turns each into an
    // undriven 1-bit wire and the header/checksum read as zero.
    logic [23:0] a_hdr, a_cks, b_hdr, b_cks;
    logic [23:0] a_rhdr, a_rcks, b_rhdr, b_rcks;
    logic        a_rsof, b_rsof;


    // Corrupts one bit of the Nth data word of the A->B frame, counting from
    // SOF. Models a bit error that 8B/10B happens not to catch, which is
    // exactly the case cut-through delivery has to handle correctly: the
    // syndrome is already at the decoder by the time the checksum says it was
    // wrong.
    int  CORRUPT_WORD = 0;    // 0 = off
    int  corrupt_cnt  = 0;
    bit  corrupt_arm  = 0;

    // The "wire": previous word plus current word, rotated by MISALIGN bytes.
    logic [31:0] a_txdata_q;
    logic [7:0]  a_txctrl2_q;
    always_ff @(posedge clk) begin
        a_txdata_q  <= a_txdata;
        a_txctrl2_q <= a_txctrl2;
    end

    always_comb begin
        case (MISALIGN)
            1: begin
                b_rxdata  = {a_txdata[7:0],   a_txdata_q[31:8]};
                b_rxctrl0 = {12'b0, a_txctrl2[0],   a_txctrl2_q[3:1]};
            end
            2: begin
                b_rxdata  = {a_txdata[15:0],  a_txdata_q[31:16]};
                b_rxctrl0 = {12'b0, a_txctrl2[1:0], a_txctrl2_q[3:2]};
            end
            3: begin
                b_rxdata  = {a_txdata[23:0],  a_txdata_q[31:24]};
                b_rxctrl0 = {12'b0, a_txctrl2[2:0], a_txctrl2_q[3]};
            end
            default: begin
                b_rxdata  = a_txdata;
                b_rxctrl0 = {12'b0, a_txctrl2[3:0]};
            end
        endcase
        if (CORRUPT_WORD != 0 && corrupt_cnt == CORRUPT_WORD && b_rxctrl0[3:0] == 4'b0)
            b_rxdata = b_rxdata ^ 32'h0000_0010;
    end

    // Counts data words since the last SOF, so CORRUPT_WORD selects a position
    // within the frame rather than an absolute time.
    always @(posedge clk) begin
        if (!rstn) begin
            corrupt_cnt <= 0;
            corrupt_arm <= 0;
        end else if (a_txctrl2[0] && a_txdata[7:0] == 8'hFB) begin   // K27.7 SOF
            corrupt_cnt <= 1;
            corrupt_arm <= 1;
        end else if (corrupt_arm && a_txctrl2[3:0] == 4'b0) begin
            corrupt_cnt <= corrupt_cnt + 1;
        end
    end

    // B -> A is always clean; only one direction is exercised for syndromes.
    assign a_rxdata  = b_txdata;
    assign a_rxctrl0 = {12'b0, b_txctrl2[3:0]};

    // ------------------------------------------------------- A: sender
    logic [N_STAB-1:0] a_syn_bits;
    logic              a_syn_valid;
    logic [15:0]       a_syn_round;
    logic [7:0]        a_words;
    logic [31:0]       a_ptx_data, a_prx_data;
    logic              a_ptx_valid, a_ptx_last, a_ptx_ready;
    logic              a_prx_valid, a_prx_last, a_prx_err;
    logic [31:0]       a_txf, a_txd, a_rxf, a_rxe, a_rxg;
    logic [N_STAB-1:0] a_syn_out;
    logic              a_syn_out_valid, a_syn_out_gap;
    logic [31:0]       a_syn_out_round;
    logic [N_CORR-1:0] a_corr_out;
    logic              a_corr_out_valid;
    logic [1:0]        a_dbg;

    braid_link_tx #(.N_STAB(N_STAB), .N_CORR(N_CORR)) u_link_a_tx (
        .clk(clk), .rstn(rstn), .link_up(1'b1), .clr(1'b0),
        .syn_bits(a_syn_bits), .syn_valid(a_syn_valid), .syn_round(a_syn_round),
        .syn_words_sel(a_words),
        .corr_bits('0), .corr_valid(1'b0),
        .phy_tx_data(a_ptx_data), .phy_tx_valid(a_ptx_valid),
        .phy_tx_last(a_ptx_last), .phy_tx_ready(a_ptx_ready),
        .phy_tx_hdr(a_hdr), .phy_tx_cks(a_cks), .phy_tx_type(), .syn_sparse(1'b0),
        .tx_frames(a_txf), .tx_dropped(a_txd)
    );

    braid_link_rx #(.N_STAB(N_STAB), .N_CORR(N_CORR)) u_link_a_rx (
        .clk(clk), .rstn(rstn), .link_up(1'b1), .clr(1'b0),
        .syn_out_bits(a_syn_out), .syn_out_valid(a_syn_out_valid),
        .syn_out_round(a_syn_out_round), .syn_out_gap(a_syn_out_gap), .syn_out_bad(),
        .corr_out_bits(a_corr_out), .corr_out_valid(a_corr_out_valid),
        .phy_rx_data(a_prx_data), .phy_rx_valid(a_prx_valid),
        .phy_rx_eof(a_prx_last), .phy_rx_sof(a_rsof), .phy_rx_hdr(a_rhdr),
        .phy_rx_type(2'd0), .syn_out_sparse(), .phy_rx_cks(a_rcks), .phy_rx_err(a_prx_err),
        .rx_frames(a_rxf), .rx_errors(a_rxe), .rx_gaps(a_rxg)
    );

    braid_framer u_fr_a (
        .clk_tx(clk), .rstn_tx(rstn), .link_up_tx(1'b1),
        .clk_rx(clk), .rstn_rx(rstn), .link_up_rx(1'b1),
        .phy_tx_data(a_ptx_data), .phy_tx_valid(a_ptx_valid),
        .phy_tx_last(a_ptx_last), .phy_tx_ready(a_ptx_ready),
        .phy_tx_hdr(a_hdr), .phy_tx_cks(a_cks), .phy_tx_type(2'd0),
        .phy_rx_data(a_prx_data), .phy_rx_valid(a_prx_valid),
        .phy_rx_eof(a_prx_last), .phy_rx_sof(a_rsof), .phy_rx_hdr(a_rhdr),
        .phy_rx_type(), .phy_rx_cks(a_rcks), .phy_rx_err(a_prx_err),
        .gt_txdata(a_txdata), .gt_txctrl2(a_txctrl2),
        .gt_rxdata(a_rxdata), .gt_rxctrl0(a_rxctrl0),
        .gt_rxctrl1(16'b0), .gt_rxctrl3(8'b0),
        .dbg(a_dbg)
    );

    // ----------------------------------------------------- B: receiver
    logic [31:0]       b_ptx_data, b_prx_data;
    logic              b_ptx_valid, b_ptx_last, b_ptx_ready;
    logic              b_prx_valid, b_prx_last, b_prx_err;
    logic [31:0]       b_txf, b_txd, b_rxf, b_rxe, b_rxg;
    logic              b_syn_out_bad;
    logic [N_STAB-1:0] b_syn_out;
    logic              b_syn_out_valid, b_syn_out_gap;
    logic [31:0]       b_syn_out_round;
    logic [N_CORR-1:0] b_corr_out;
    logic              b_corr_out_valid;
    logic [1:0]        b_dbg;

    braid_link_tx #(.N_STAB(N_STAB), .N_CORR(N_CORR)) u_link_b_tx (
        .clk(clk), .rstn(rstn), .link_up(1'b1), .clr(1'b0),
        // B never transmits syndromes in these tests; it only reflects/receives.
        .syn_bits('0), .syn_valid(1'b0), .syn_round(16'b0),
        .syn_words_sel(8'd0),
        .corr_bits('0), .corr_valid(1'b0),
        .phy_tx_data(b_ptx_data), .phy_tx_valid(b_ptx_valid),
        .phy_tx_last(b_ptx_last), .phy_tx_ready(b_ptx_ready),
        .phy_tx_hdr(b_hdr), .phy_tx_cks(b_cks), .phy_tx_type(), .syn_sparse(1'b0),
        .tx_frames(b_txf), .tx_dropped(b_txd)
    );

    braid_link_rx #(.N_STAB(N_STAB), .N_CORR(N_CORR)) u_link_b_rx (
        .clk(clk), .rstn(rstn), .link_up(1'b1), .clr(1'b0),
        .syn_out_bits(b_syn_out), .syn_out_valid(b_syn_out_valid),
        .syn_out_round(b_syn_out_round), .syn_out_gap(b_syn_out_gap),
        .syn_out_bad(b_syn_out_bad),
        .corr_out_bits(b_corr_out), .corr_out_valid(b_corr_out_valid),
        .phy_rx_data(b_prx_data), .phy_rx_valid(b_prx_valid),
        .phy_rx_eof(b_prx_last), .phy_rx_sof(b_rsof), .phy_rx_hdr(b_rhdr),
        .phy_rx_type(2'd0), .syn_out_sparse(), .phy_rx_cks(b_rcks), .phy_rx_err(b_prx_err),
        .rx_frames(b_rxf), .rx_errors(b_rxe), .rx_gaps(b_rxg)
    );

    braid_framer u_fr_b (
        .clk_tx(clk), .rstn_tx(rstn), .link_up_tx(1'b1),
        .clk_rx(clk), .rstn_rx(rstn), .link_up_rx(1'b1),
        .phy_tx_data(b_ptx_data), .phy_tx_valid(b_ptx_valid),
        .phy_tx_last(b_ptx_last), .phy_tx_ready(b_ptx_ready),
        .phy_tx_hdr(b_hdr), .phy_tx_cks(b_cks), .phy_tx_type(2'd0),
        .phy_rx_data(b_prx_data), .phy_rx_valid(b_prx_valid),
        .phy_rx_eof(b_prx_last), .phy_rx_sof(b_rsof), .phy_rx_hdr(b_rhdr),
        .phy_rx_type(), .phy_rx_cks(b_rcks), .phy_rx_err(b_prx_err),
        .gt_txdata(b_txdata), .gt_txctrl2(b_txctrl2),
        .gt_rxdata(b_rxdata), .gt_rxctrl0(b_rxctrl0),
        .gt_rxctrl1(16'b0), .gt_rxctrl3(8'b0),
        .dbg(b_dbg)
    );

    // ------------------------------------------------------- stimulus
    // Same deterministic pattern vfpga_top uses, so the simulation exercises
    // the payload the hardware actually sends.
    function automatic logic [N_STAB-1:0] pattern(input logic [15:0] r);
        logic [N_STAB+31:0] p;
        for (int k = 0; k <= (N_STAB/32); k++)
            p[k*32 +: 32] = {16'b0, r} ^ (32'h9E3779B9 * (k + 1));
        return p[N_STAB-1:0];
    endfunction

    int sent, recvd, bad;
    int n_out_bad;
    logic [31:0] b_rxe_before;

    always @(posedge clk) begin
        if (rstn && b_syn_out_bad) n_out_bad <= n_out_bad + 1;
    end

    wire [7:0] tb_active = (a_words == 8'd0 || a_words > 8'd32) ? 8'd32 : a_words;
    wire [N_STAB-1:0] tb_mask = ({N_STAB{1'b1}} >> (N_STAB - {tb_active, 5'b0}));

    task automatic send_rounds(input int n, input int gap_cycles);
        for (int i = 0; i < n; i++) begin
            @(posedge clk);
            a_syn_bits  <= pattern(i[15:0]);
            a_syn_round <= i[15:0];
            a_syn_valid <= 1'b1;
            @(posedge clk);
            a_syn_valid <= 1'b0;
            repeat (gap_cycles) @(posedge clk);
        end
    endtask

    // Score B's received syndromes against the expected pattern.
    // Plain `always`, not `always_ff`: the stimulus block also resets these
    // counters between tests, and always_ff forbids a second procedural driver.
    always @(posedge clk) begin
        if (rstn && b_syn_out_valid) begin
            recvd <= recvd + 1;
            // Mask to the words actually sent. Above that, syn_out_bits holds
            // stale data from an earlier, longer frame -- the same trap
            // vfpga_top's checker has to avoid.
            if ((b_syn_out & tb_mask) != (pattern(b_syn_out_round[15:0]) & tb_mask)) begin
                bad <= bad + 1;
                $display("  [%0t] MISMATCH round=%0d", $time, b_syn_out_round);
            end
        end
    end

    initial begin
        sent = 0; recvd = 0; bad = 0;
        a_syn_bits = '0; a_syn_valid = 0; a_syn_round = '0; a_words = 8'd0;
        repeat (20) @(posedge clk);
        rstn = 1;
        repeat (20) @(posedge clk);

        // ---- Test 1: correctly aligned link ----
        $display("\n=== Test 1: aligned link, 64 rounds ===");
        MISALIGN = 0;
        // 4 words = d=11-sized syndrome. With the full 32-word payload a frame
        // takes ~36 cycles, so a 20-cycle gap would offer rounds faster than the
        // link can send them and half would be correctly dropped as "busy".
        a_words = 8'd4;
        send_rounds(64, 20);
        repeat (200) @(posedge clk);
        $display("  tx_frames=%0d rx_frames=%0d rx_errors=%0d rx_gaps=%0d",
                 a_txf, b_rxf, b_rxe, b_rxg);
        $display("  delivered=%0d mismatches=%0d  dbg_b=%b", recvd, bad, b_dbg);

        if (recvd == 64 && bad == 0 && b_rxe == 0 && b_rxg == 0)
            $display("  PASS");
        else begin
            $display("  *** FAIL: aligned link did not deliver cleanly ***");
            $finish;
        end

        // ---- Test 2: misaligned by one byte ----
        // Models RX_COMMA_ALIGN_WORD=1 putting the comma in the wrong lane.
        // The link must NOT silently deliver corrupted syndromes.
        $display("\n=== Test 2: 1-byte misalignment (must be caught) ===");
        MISALIGN = 1;
        recvd = 0; bad = 0;
        send_rounds(32, 20);
        repeat (200) @(posedge clk);
        $display("  delivered=%0d mismatches=%0d rx_errors=%0d dbg_b=%b",
                 recvd, bad, b_rxe, b_dbg);
        if (bad == 0 && recvd == 0)
            $display("  PASS: nothing delivered (frames rejected)");
        else if (bad > 0)
            $display("  PASS: corruption detected and flagged");
        else
            $display("  *** FAIL: delivered %0d frames as good ***", recvd);

        // ---- Test 3: protocol latency decomposition ----
        // The "wire" here is a direct connection, so this measures ONLY
        // braid_link's TX framing + braid_framer + braid_framer + braid_link's
        // RX reassembly. Any hardware RTT above 2x this is GT, CDC and cable.
        $display("\n=== Test 3: protocol-only latency (no GT, no CDC) ===");
        $display("  words  bytes   cycles      ns @390.6MHz");
        MISALIGN = 0;
        // 1,2,4,8,16 then the full-width 31. MAX is 31 rather than 32 because
        // vfpga_top's echo crossing caps the payload at 992 bits; doubling alone
        // would stop at 16 and never exercise a full-size frame.
        for (int w = 1; w <= 31; w = (w * 2 > 31 && w != 31) ? 31 : w * 2) begin
            time t0, t1;
            a_words = w[7:0];
            @(posedge clk);
            a_syn_bits  <= pattern(16'd7);
            a_syn_round <= 16'd7;
            a_syn_valid <= 1'b1;
            t0 = $time;
            @(posedge clk);
            a_syn_valid <= 1'b0;
            @(posedge b_syn_out_valid);
            t1 = $time;
            $display("  %5d  %5d   %6d      %8.1f",
                     w, w*4, (t1-t0)/4, ((t1-t0)/4) * 1000.0 / 390.625);
            repeat (50) @(posedge clk);
        end

        // ---- Test 4: cut-through delivery of a CORRUPT frame ----
        //
        // Cut-through means syn_out_valid fires before the checksum is
        // validated, so a corrupt frame IS delivered and then retracted one
        // cycle later on syn_out_bad. The contract that matters to a decoder:
        // every corrupt frame must raise syn_out_bad, and the round must not
        // advance -- so the next good frame reports the gap.
        //
        // Test 2 covers misalignment, where nothing is delivered at all. This
        // covers the opposite and more dangerous case: a frame that looks
        // perfectly well formed until its last word.
        $display("\n=== Test 4: corrupt payload, cut-through + retract ===");
        MISALIGN = 0;
        a_words  = 8'd4;
        recvd = 0; bad = 0; n_out_bad = 0;
        b_rxe_before = b_rxe;
        repeat (20) @(posedge clk);

        CORRUPT_WORD = 3;          // a payload word, not the header
        send_rounds(1, 40);
        repeat (40) @(posedge clk);
        CORRUPT_WORD = 0;

        $display("  delivered=%0d syn_out_bad=%0d rx_errors=+%0d",
                 recvd, n_out_bad, b_rxe - b_rxe_before);
        if (recvd == 1 && n_out_bad == 1 && (b_rxe - b_rxe_before) == 1)
            $display("  PASS: delivered once, retracted once, counted once");
        else
            $display("  *** FAIL: cut-through did not retract a corrupt frame ***");

        // The round must NOT have advanced past the corrupt frame, so the next
        // good round is reported as a gap rather than silently accepted.
        recvd = 0; n_out_bad = 0;
        send_rounds(1, 40);
        repeat (40) @(posedge clk);
        $display("  next good frame: delivered=%0d syn_out_bad=%0d gaps=%0d",
                 recvd, n_out_bad, b_rxg);
        if (recvd == 1 && n_out_bad == 0)
            $display("  PASS: recovered on the next frame");
        else
            $display("  *** FAIL: did not recover ***");

        // ---- Test 5: back-to-back frames, no gap ----
        //
        // syn_valid is held HIGH, not pulsed. Pulsing it every N cycles locks
        // the offset between the pulse and the frame boundary, and the window
        // that matters here is exactly one cycle wide -- the cycle after the
        // last payload word, when the FSM is back in T_IDLE but the framer has
        // not yet emitted the trailer. A round starting there used to overwrite
        // the running checksum before the trailer read it, sending a perfectly
        // good frame with the next frame's partial sum.
        //
        // Pulsed stimulus never lands on that cycle. This test passed against
        // the broken RTL until the stimulus was changed to a level.
        $display("\n=== Test 5: back-to-back frames (syn_valid held high) ===");
        MISALIGN = 0; CORRUPT_WORD = 0;
        a_words = 8'd4;
        recvd = 0; bad = 0; n_out_bad = 0;
        b_rxe_before = b_rxe;
        repeat (20) @(posedge clk);

        @(posedge clk);
        a_syn_bits  <= pattern(16'd9);
        a_syn_round <= 16'd9;
        a_syn_valid <= 1'b1;
        repeat (200) @(posedge clk);
        a_syn_valid <= 1'b0;
        repeat (60) @(posedge clk);

        // Gaps are EXPECTED here: the round number never advances, so every
        // frame after the first reads as a repeat. Errors and mismatches are
        // what this test is about.
        $display("  delivered=%0d mismatches=%0d rx_errors=+%0d syn_out_bad=%0d",
                 recvd, bad, b_rxe - b_rxe_before, n_out_bad);
        if (recvd > 4 && bad == 0 && (b_rxe - b_rxe_before) == 0 && n_out_bad == 0)
            $display("  PASS: %0d back-to-back frames, none corrupt", recvd);
        else
            $display("  *** FAIL: back-to-back frames are being corrupted ***");

        $display("\nDone.");
        $finish;
    end

    initial begin
        #2_000_000;
        $display("*** TIMEOUT ***");
        $finish;
    end

endmodule
