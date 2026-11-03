`timescale 1ns / 1ps
// Stand-alone testbench for examples/13_rf_capture/hw/src/hdl/rf_capture.sv
import lynxTypes::*;

module tb_capture;
    logic aclk = 0, aresetn = 0;
    always #2.0 aclk = ~aclk;

    AXI4L  axil (.aclk(aclk), .aresetn(aresetn));
    AXI4S  axis_rf (.aclk(aclk), .aresetn(aresetn));
    AXI4SR axis_card (.aclk(aclk), .aresetn(aresetn));

    AXI4S  axis_dac (.aclk(aclk), .aresetn(aresetn));

    rf_capture dut (.aclk, .aresetn, .axi_ctrl(axil), .axis_rf, .axis_card, .axis_dac);

    int errors = 0;
    task automatic check(input bit ok, input string msg);
        if (ok) $display("ok    %s", msg); else begin $display("ERROR %s", msg); errors++; end
    endtask

    task automatic reg_wr(input int idx, input longint data);
        @(posedge aclk); #0.1;
        axil.awaddr = idx * 8; axil.awvalid = 1; axil.wdata = data; axil.wstrb = '1; axil.wvalid = 1; axil.bready = 1;
        fork
            begin do @(posedge aclk); while (!axil.awready); #0.1 axil.awvalid = 0; end
            begin do @(posedge aclk); while (!axil.wready);  #0.1 axil.wvalid = 0; end
        join
        do @(posedge aclk); while (!axil.bvalid);
        #0.1 axil.bready = 0;
    endtask
    task automatic reg_rd(input int idx, output longint data);
        @(posedge aclk); #0.1;
        axil.araddr = idx * 8; axil.arvalid = 1; axil.rready = 1;
        do @(posedge aclk); while (!axil.arready);
        #0.1 axil.arvalid = 0;
        while (!axil.rvalid) @(posedge aclk);
        data = axil.rdata;
        @(posedge aclk); #0.1 axil.rready = 0;
    endtask

    // ADC stream: a running word counter, always valid unless paused
    bit rf_pause = 0;
    int unsigned rf_seq = 0;
    assign axis_rf.tvalid = !rf_pause;
    assign axis_rf.tkeep = '1;
    assign axis_rf.tlast = 0;
    always_comb axis_rf.tdata = 512'(rf_seq);
    always @(posedge aclk) if (axis_rf.tvalid && axis_rf.tready) rf_seq <= rf_seq + 1;

    // Card side: logs every word, with optional stalls
    bit card_stall = 0;
    int unsigned got[$]; int lasts = 0, last_pos = -1;
    logic card_ready = 1;
    always @(posedge aclk) card_ready <= !card_stall || ($urandom_range(3) == 0);
    assign axis_card.tready = card_ready;
    always @(posedge aclk) if (axis_card.tvalid && axis_card.tready) begin
        got.push_back(int'(axis_card.tdata[31:0]));
        if (axis_card.tlast) begin lasts++; last_pos = got.size(); end
    end

    task automatic capture(input int n, input string name);
        longint r; int bad = 0;
        got.delete(); lasts = 0; last_pos = -1;
        reg_wr(0, n);
        reg_wr(1, 1);
        repeat (n * 6 + 100) @(posedge aclk);
        reg_rd(2, r); check(r == 0, {name, ": capture finished"});
        reg_rd(3, r); check(r == n, $sformatf("%s: word counter %0d", name, r));
        check(got.size() == n, $sformatf("%s: %0d words reached card memory", name, got.size()));
        for (int i = 1; i < got.size(); i++) if (got[i] != got[i-1] + 1) bad++;
        check(bad == 0, {name, ": words consecutive"});
        check(lasts == 1 && last_pos == n, {name, ": one tlast, on the final word"});
    endtask

    // DAC side: logs every word, with optional stalls
    bit dac_stall = 0;
    logic [511:0] dac_got[$];
    logic dac_ready = 1;
    always @(posedge aclk) dac_ready <= !dac_stall || ($urandom_range(3) == 0);
    assign axis_dac.tready = dac_ready;
    always @(posedge aclk) if (axis_dac.tvalid && axis_dac.tready) dac_got.push_back(axis_dac.tdata);

    function automatic logic [15:0] wave(input int i);
        return 16'(i * 7 + 3);
    endfunction

    // Checks that the words received are the waveform in order, looping, from its start
    task automatic check_play(input string name, input int min_words);
        int bad = 0;
        check(dac_got.size() >= min_words, $sformatf("%s: %0d words played", name, dac_got.size()));
        foreach (dac_got[w]) for (int s = 0; s < 32; s++)
            if (dac_got[w][s*16 +: 16] !== wave((w % 64) * 32 + s)) bad++;
        check(bad == 0, {name, ": samples in order, looping"});
    endtask

    longint r; int seq0;
    initial begin
        axil.awvalid = 0; axil.wvalid = 0; axil.arvalid = 0; axil.bready = 0; axil.rready = 0;
        repeat (20) @(posedge aclk);
        aresetn = 1;
        repeat (20) @(posedge aclk);

        seq0 = rf_seq;
        repeat (100) @(posedge aclk);
        check(rf_seq > seq0 + 50, "words are discarded while idle");
        check(got.size() == 0, "nothing goes to card memory while idle");

        capture(1, "1 word");
        capture(1000, "1000 words");
        card_stall = 1;
        capture(1000, "1000 words with stalls");
        card_stall = 0;
        rf_pause = 1;
        reg_wr(0, 10); reg_wr(1, 1);
        repeat (50) @(posedge aclk);
        reg_rd(2, r); check(r == 1, "waits for ADC words");
        rf_pause = 0;
        repeat (50) @(posedge aclk);
        reg_rd(2, r); check(r == 0, "continues when they arrive");
        got.delete();
        reg_wr(0, 0); reg_wr(1, 1);
        repeat (50) @(posedge aclk);
        check(got.size() == 0, "zero words does nothing");
        reg_rd(0, r); check(r == 0, "length reads back");

        // Waveform playback
        repeat (20) @(posedge aclk);
        check(!axis_dac.tvalid, "nothing offered to the DAC before playing");
        reg_rd(5, r); check(r == 0, "playback is off after reset");
        for (int i = 0; i < 2048; i++) reg_wr(4, (longint'(i) << 16) | longint'(wave(i)));
        repeat (20) @(posedge aclk);
        check(!axis_dac.tvalid && dac_got.size() == 0, "writing samples plays nothing");
        reg_wr(5, 1);
        repeat (400) @(posedge aclk);
        reg_rd(5, r); check(r == 1, "playback reads back on");
        reg_wr(5, 0);
        repeat (5) @(posedge aclk);
        check_play("free running", 300);
        check(!axis_dac.tvalid, "stops offering when off");
        dac_got.delete();
        dac_stall = 1;
        reg_wr(5, 1);
        repeat (2000) @(posedge aclk);
        reg_wr(5, 0);
        dac_stall = 0;
        repeat (5) @(posedge aclk);
        check_play("with stalls, restarted from the beginning", 300);

        if (errors) $display("FAIL: %0d errors", errors); else $display("PASS");
        $finish;
    end
    initial begin #5ms; $display("FAIL: timeout"); $finish; end
endmodule
