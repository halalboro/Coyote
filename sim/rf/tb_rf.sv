`timescale 1ns / 1ps
// Stand-alone testbench for the RF service (hw/hdl/rf). The "converters" are modelled by counters. See run.sh.
import lynxTypes::*;

module tb_rf;
    logic aclk = 0, aresetn = 0, vclk = 0, adc_clk = 0, dac_clk = 0;
    bit   dac_clk_on = 0;
    always #2.0   aclk = ~aclk;                 // 250 MHz
    always #2.0   vclk = ~vclk;
    always #1.628 adc_clk = ~adc_clk;           // 307.2 MHz
    always #1.628 if (dac_clk_on) dac_clk = ~dac_clk;

    AXI4L #(.AXI4L_DATA_BITS(32)) axil (.aclk(aclk), .aresetn(aresetn));
    AXI4S axis_adc (.aclk(vclk), .aresetn(aresetn));
    AXI4S axis_dac (.aclk(vclk), .aresetn(aresetn));

    logic [127:0] adc_tdata = 0, dac_tdata;
    logic adc_tvalid = 1, adc_tready, dac_tvalid, dac_tready = 1;

    rf_service dut (.aclk, .aresetn, .s_axi_cnfg(axil), .vclk, .m_axis_adc(axis_adc), .s_axis_dac(axis_dac),
        .adc_clk, .adc_tdata, .adc_tvalid, .adc_tready, .dac_clk, .dac_tdata, .dac_tvalid, .dac_tready);

    int errors = 0;
    task automatic check(input bit ok, input string msg);
        if (ok) $display("ok    %s", msg); else begin $display("ERROR %s", msg); errors++; end
    endtask

    // Register access
    task automatic reg_wr(input int addr, input int data);
        @(posedge aclk); #0.1;
        axil.awaddr = addr; axil.awvalid = 1; axil.wdata = data; axil.wstrb = 4'hf; axil.wvalid = 1; axil.bready = 1;
        fork
            begin do @(posedge aclk); while (!axil.awready); #0.1 axil.awvalid = 0; end
            begin do @(posedge aclk); while (!axil.wready);  #0.1 axil.wvalid = 0; end
        join
        do @(posedge aclk); while (!axil.bvalid);
        #0.1 axil.bready = 0;
    endtask
    task automatic reg_rd(input int addr, output int data);
        @(posedge aclk); #0.1;
        axil.araddr = addr; axil.arvalid = 1; axil.rready = 1;
        do @(posedge aclk); while (!axil.arready);
        #0.1 axil.arvalid = 0;
        while (!axil.rvalid) @(posedge aclk);
        data = axil.rdata;
        @(posedge aclk); #0.1 axil.rready = 0;
    endtask

    // ADC model: 16-bit sample counter, 8 samples per clock
    logic [15:0] adc_next = 0;
    bit adc_hold = 0;
    always_ff @(posedge adc_clk) if (!adc_hold) begin
        for (int i = 0; i < 8; i++) adc_tdata[i*16 +: 16] <= adc_next + i;
        adc_next <= adc_next + 8;
    end

    // DAC model: every word it takes while tready is logged
    bit dac_watch = 0;
    int dac_nonzero = 0;
    logic [15:0] dac_log [$];
    always @(posedge dac_clk) if (dac_tready) begin
        if (dac_tdata !== '0) dac_nonzero <= dac_nonzero + 1;
        if (dac_watch) for (int i = 0; i < 8; i++) dac_log.push_back(dac_tdata[i*16 +: 16]);
    end

    // vFPGA side
    bit adc_drain = 0, adc_watch = 0;
    int adc_bad = 0, adc_beats = 0;
    logic [15:0] adc_expect; bit adc_first = 1;
    assign axis_adc.tready = adc_drain;
    always @(posedge vclk) if (axis_adc.tvalid && axis_adc.tready) begin
        adc_beats <= adc_beats + 1;
        if (adc_watch) begin
            automatic logic [15:0] e = adc_first ? axis_adc.tdata[15:0] : adc_expect;
            for (int i = 0; i < 32; i++) if (axis_adc.tdata[i*16 +: 16] !== (e + 16'(i))) adc_bad <= adc_bad + 1;
            adc_expect <= e + 16'd32;
            adc_first <= 0;
        end
    end

    bit dac_send = 0;
    logic [15:0] dac_seq = 16'h0100;
    int dac_beats_sent = 0;
    assign axis_dac.tvalid = dac_send;
    assign axis_dac.tkeep = '1;
    assign axis_dac.tlast = 0;
    always_comb for (int i = 0; i < 32; i++) axis_dac.tdata[i*16 +: 16] = dac_seq + 16'(i);
    always @(posedge vclk) if (axis_dac.tvalid && axis_dac.tready) begin
        dac_seq <= dac_seq + 16'd32;
        dac_beats_sent <= dac_beats_sent + 1;
    end

    int r;
    initial begin
        axil.awvalid = 0; axil.wvalid = 0; axil.arvalid = 0; axil.bready = 0; axil.rready = 0;
        repeat (20) @(posedge aclk);
        aresetn = 1;
        repeat (20) @(posedge aclk);

        // Registers, and the safe default with the DAC clock absent
        reg_rd('h00, r); check(r == 32'h52460001, "ID register");
        reg_rd('h04, r); check(r == 0, "enables reset to 0");
        dac_send = 1;
        repeat (200) @(posedge vclk);
        check(!axis_dac.tready, "DAC stream not ready while disabled");
        check(dac_beats_sent == 0, "no DAC data accepted while disabled");
        reg_wr('h04, 2);
        repeat (400) @(posedge vclk);
        check(!axis_dac.tready, "DAC enabled but no DAC clock: stream stays not ready");
        reg_rd('h04, r); check(r == 2, "registers still work without a DAC clock");
        reg_wr('h04, 0);
        dac_send = 0;

        // DAC clock running, disabled: output stays zero
        dac_clk_on = 1;
        repeat (2000) @(posedge vclk);
        check(dac_nonzero == 0 && dac_tvalid !== 1'b1, "DAC output zero and invalid while disabled");

        // ADC: nothing while disabled
        adc_drain = 1;
        repeat (200) @(posedge vclk);
        check(adc_beats == 0, "no ADC data while disabled");

        // ADC: continuous capture, samples in order, the stream keeps up
        adc_watch = 1;
        reg_wr('h04, 1);
        repeat (20000) @(posedge vclk);
        check(adc_beats > 5000, $sformatf("ADC stream running, %0d beats", adc_beats));
        check(adc_bad == 0, "ADC samples consecutive and in order");
        reg_rd('h08, r); check((r & 1) == 0, "no ADC overflow when drained");
        reg_rd('h0C, r); check(r > 5000, $sformatf("ADC word counter %0d", r));

        // ADC: a stalled vFPGA gives overflow
        adc_drain = 0;
        repeat (5000) @(posedge vclk);
        reg_rd('h08, r); check((r & 1) == 1, "ADC overflow when the vFPGA stalls");

        // ADC: disable clears, and nothing stale comes out afterwards
        reg_wr('h04, 0);
        repeat (200) @(posedge vclk);
        reg_rd('h08, r); check((r & 1) == 0, "disable clears ADC overflow");
        reg_rd('h0C, r); check(r == 0, "disable clears the ADC word counter");
        adc_beats = 0;
        adc_drain = 1;
        repeat (200) @(posedge vclk);
        check(adc_beats == 0, "no stale ADC data after disable");
        adc_watch = 0; adc_first = 1; adc_drain = 0;

        // DAC: data plays out exactly, in order
        dac_watch = 1;
        reg_wr('h04, 2);
        repeat (50) @(posedge vclk);
        dac_send = 1;
        repeat (3000) @(posedge vclk);
        check(dac_beats_sent > 500, $sformatf("DAC stream accepted %0d beats", dac_beats_sent));
        reg_rd('h08, r); check((r & 2) == 0, "no DAC underflow while the vFPGA keeps up");
        dac_send = 0;
        repeat (2000) @(posedge vclk);
        reg_rd('h08, r); check((r & 2) == 2, "DAC underflow when the vFPGA stops");
        check(dac_tdata === '0, "DAC output zero on underflow");
        begin
            automatic int i = 0, bad = 0, seen = 0; automatic logic [15:0] e = 16'h0100;
            while (i < dac_log.size() && dac_log[i] == 0) i++;
            for (; i < dac_log.size(); i++) begin
                if (dac_log[i] == 0 && e != 0) break;
                if (dac_log[i] !== e) bad++;
                e++; seen++;
            end
            check(bad == 0, $sformatf("DAC samples in order, %0d samples", seen));
            check(seen == dac_beats_sent * 32, $sformatf("all sent samples played (%0d of %0d)", seen, dac_beats_sent * 32));
            for (; i < dac_log.size(); i++) if (dac_log[i] !== 0) bad++;
            check(bad == 0, "only zeros after the data ended");
        end
        reg_rd('h10, r); check(r == dac_beats_sent, $sformatf("DAC word counter %0d", r));

        // DAC: buffered data must not survive a disable
        dac_tready = 0;            // the tile stops taking data, so the FIFO fills
        dac_send = 1;
        repeat (300) @(posedge vclk);
        dac_send = 0;
        reg_wr('h04, 0);
        repeat (200) @(posedge vclk);
        check(dac_tdata === '0 && dac_tvalid === 1'b0, "disable forces DAC output to zero at once");
        dac_tready = 1;
        dac_log.delete();
        reg_wr('h04, 2);
        repeat (2000) @(posedge vclk);
        begin
            automatic int nz = 0;
            foreach (dac_log[j]) if (dac_log[j] !== 0) nz++;
            check(nz == 0, "no stale DAC data after disable and enable");
        end
        reg_rd('h08, r); check((r & 2) == 0, "disable cleared DAC underflow");
        reg_wr('h04, 0);

        // ADC test pattern replaces the samples, even with the converter model's data held still
        adc_hold = 1;
        adc_watch = 1; adc_drain = 1; adc_bad = 0; adc_first = 1; adc_beats = 0;
        reg_wr('h04, 5);
        repeat (5000) @(posedge vclk);
        check(adc_beats > 1000, $sformatf("test pattern running, %0d beats", adc_beats));
        check(adc_bad == 0, "test pattern values consecutive");
        reg_rd('h04, r); check(r == 5, "test pattern bit reads back");
        reg_wr('h04, 0);
        repeat (200) @(posedge vclk);
        adc_hold = 0; adc_watch = 0; adc_first = 1; adc_drain = 0;

        // Both directions together
        adc_watch = 1; adc_drain = 1; adc_bad = 0;
        reg_wr('h04, 3);
        dac_send = 1;
        repeat (5000) @(posedge vclk);
        reg_rd('h08, r); check(r == 0, $sformatf("both directions run together without errors (status %0d)", r));
        check(adc_bad == 0, "ADC in order with both running");
        reg_wr('h04, 0);

        if (errors) $display("FAIL: %0d errors", errors); else $display("PASS");
        $finish;
    end
    initial begin #2ms; $display("FAIL: timeout"); $finish; end
endmodule
