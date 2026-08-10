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
 *   xvlog -sv tb_braid.sv ../hw/src/hdl/braid_link.sv \
 *              ../../../hw/hdl/braid/braid_framer.sv
 *   xelab -debug typical tb_braid -s tb && xsim tb -R
 */

`timescale 1ns/1ps

module tb_braid;

    localparam int N_STAB = 1024;   // match vfpga_top: 32 words max
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
    end

    // B -> A is always clean; only one direction is exercised for syndromes.
    assign a_rxdata  = b_txdata;
    assign a_rxctrl0 = {12'b0, b_txctrl2[3:0]};

    // ------------------------------------------------------- A: sender
    logic [N_STAB-1:0] a_syn_bits;
    logic              a_syn_valid;
    logic [19:0]       a_syn_round;
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
        .tx_frames(a_txf), .tx_dropped(a_txd)
    );

    braid_link_rx #(.N_STAB(N_STAB), .N_CORR(N_CORR)) u_link_a_rx (
        .clk(clk), .rstn(rstn), .link_up(1'b1), .clr(1'b0),
        .syn_out_bits(a_syn_out), .syn_out_valid(a_syn_out_valid),
        .syn_out_round(a_syn_out_round), .syn_out_gap(a_syn_out_gap),
        .corr_out_bits(a_corr_out), .corr_out_valid(a_corr_out_valid),
        .phy_rx_data(a_prx_data), .phy_rx_valid(a_prx_valid),
        .phy_rx_last(a_prx_last), .phy_rx_err(a_prx_err),
        .rx_frames(a_rxf), .rx_errors(a_rxe), .rx_gaps(a_rxg)
    );

    braid_framer u_fr_a (
        .clk_tx(clk), .rstn_tx(rstn), .link_up_tx(1'b1),
        .clk_rx(clk), .rstn_rx(rstn), .link_up_rx(1'b1),
        .phy_tx_data(a_ptx_data), .phy_tx_valid(a_ptx_valid),
        .phy_tx_last(a_ptx_last), .phy_tx_ready(a_ptx_ready),
        .phy_rx_data(a_prx_data), .phy_rx_valid(a_prx_valid),
        .phy_rx_last(a_prx_last), .phy_rx_err(a_prx_err),
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
    logic [N_STAB-1:0] b_syn_out;
    logic              b_syn_out_valid, b_syn_out_gap;
    logic [31:0]       b_syn_out_round;
    logic [N_CORR-1:0] b_corr_out;
    logic              b_corr_out_valid;
    logic [1:0]        b_dbg;

    braid_link_tx #(.N_STAB(N_STAB), .N_CORR(N_CORR)) u_link_b_tx (
        .clk(clk), .rstn(rstn), .link_up(1'b1), .clr(1'b0),
        // B never transmits syndromes in these tests; it only reflects/receives.
        .syn_bits('0), .syn_valid(1'b0), .syn_round(20'b0),
        .syn_words_sel(8'd0),
        .corr_bits('0), .corr_valid(1'b0),
        .phy_tx_data(b_ptx_data), .phy_tx_valid(b_ptx_valid),
        .phy_tx_last(b_ptx_last), .phy_tx_ready(b_ptx_ready),
        .tx_frames(b_txf), .tx_dropped(b_txd)
    );

    braid_link_rx #(.N_STAB(N_STAB), .N_CORR(N_CORR)) u_link_b_rx (
        .clk(clk), .rstn(rstn), .link_up(1'b1), .clr(1'b0),
        .syn_out_bits(b_syn_out), .syn_out_valid(b_syn_out_valid),
        .syn_out_round(b_syn_out_round), .syn_out_gap(b_syn_out_gap),
        .corr_out_bits(b_corr_out), .corr_out_valid(b_corr_out_valid),
        .phy_rx_data(b_prx_data), .phy_rx_valid(b_prx_valid),
        .phy_rx_last(b_prx_last), .phy_rx_err(b_prx_err),
        .rx_frames(b_rxf), .rx_errors(b_rxe), .rx_gaps(b_rxg)
    );

    braid_framer u_fr_b (
        .clk_tx(clk), .rstn_tx(rstn), .link_up_tx(1'b1),
        .clk_rx(clk), .rstn_rx(rstn), .link_up_rx(1'b1),
        .phy_tx_data(b_ptx_data), .phy_tx_valid(b_ptx_valid),
        .phy_tx_last(b_ptx_last), .phy_tx_ready(b_ptx_ready),
        .phy_rx_data(b_prx_data), .phy_rx_valid(b_prx_valid),
        .phy_rx_last(b_prx_last), .phy_rx_err(b_prx_err),
        .gt_txdata(b_txdata), .gt_txctrl2(b_txctrl2),
        .gt_rxdata(b_rxdata), .gt_rxctrl0(b_rxctrl0),
        .gt_rxctrl1(16'b0), .gt_rxctrl3(8'b0),
        .dbg(b_dbg)
    );

    // ------------------------------------------------------- stimulus
    // Same deterministic pattern vfpga_top uses, so the simulation exercises
    // the payload the hardware actually sends.
    function automatic logic [N_STAB-1:0] pattern(input logic [19:0] r);
        logic [N_STAB+31:0] p;
        for (int k = 0; k <= (N_STAB/32); k++)
            p[k*32 +: 32] = {12'b0, r} ^ (32'h9E3779B9 * (k + 1));
        return p[N_STAB-1:0];
    endfunction

    int sent, recvd, bad;

    wire [7:0] tb_active = (a_words == 8'd0 || a_words > 8'd32) ? 8'd32 : a_words;
    wire [N_STAB-1:0] tb_mask = ({N_STAB{1'b1}} >> (N_STAB - {tb_active, 5'b0}));

    task automatic send_rounds(input int n, input int gap_cycles);
        for (int i = 0; i < n; i++) begin
            @(posedge clk);
            a_syn_bits  <= pattern(i[19:0]);
            a_syn_round <= i[19:0];
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
            if ((b_syn_out & tb_mask) != (pattern(b_syn_out_round[19:0]) & tb_mask)) begin
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
        $display("  words  bytes   cycles      ns @257.8MHz");
        MISALIGN = 0;
        for (int w = 1; w <= 32; w = w * 2) begin
            time t0, t1;
            a_words = w[7:0];
            @(posedge clk);
            a_syn_bits  <= pattern(20'd7);
            a_syn_round <= 20'd7;
            a_syn_valid <= 1'b1;
            t0 = $time;
            @(posedge clk);
            a_syn_valid <= 1'b0;
            @(posedge b_syn_out_valid);
            t1 = $time;
            $display("  %5d  %5d   %6d      %8.1f",
                     w, w*4, (t1-t0)/4, ((t1-t0)/4) * 1000.0 / 257.8125);
            repeat (50) @(posedge clk);
        end

        $display("\nDone.");
        $finish;
    end

    initial begin
        #2_000_000;
        $display("*** TIMEOUT ***");
        $finish;
    end

endmodule
