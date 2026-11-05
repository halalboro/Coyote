`timescale 1ns / 1ps

import lynxTypes::*;

/**
 * RF data converter service: one receive and one transmit stream between the converter clocks and one vFPGA, plus the
 * control registers (rf_slave.sv). The streams carry 16-bit samples, first sample in the lowest bits.
 * Each stream connects to one of the converter channels, chosen by a register; the other DAC channels get zeros.
 */
module rf_service #(
    parameter logic [31:0] RATE_KHZ = 32'd2457600
) (
    input  logic         aclk,
    input  logic         aresetn,
    AXI4L.s              s_axi_cnfg,

    // vFPGA side; vclk is aclk or uclk
    input  logic         vclk,
    AXI4S.m              m_axis_adc,
    AXI4S.s              s_axis_dac,

    // Converter side
    input  logic         adc_clk,
    input  logic [3:0][127:0] adc_tdata,
    input  logic [3:0]   adc_tvalid,
    output logic [3:0]   adc_tready,
    input  logic         dac_clk,
    output logic [3:0][127:0] dac_tdata,
    output logic [3:0]   dac_tvalid,
    input  logic [3:0]   dac_tready
);

logic adc_enable, dac_enable, adc_test, adc_overflow, dac_underflow;
logic [31:0] adc_words, dac_words;
logic [1:0] adc_select, dac_select, adc_select_rf, dac_select_rf;

rf_slave #(.RATE_KHZ(RATE_KHZ)) inst_slave (
    .aclk(aclk), .aresetn(aresetn), .s_axi(s_axi_cnfg),
    .adc_enable(adc_enable), .dac_enable(dac_enable), .adc_test(adc_test), .adc_select(adc_select), .dac_select(dac_select), .adc_overflow(adc_overflow), .dac_underflow(dac_underflow),
    .adc_words(adc_words), .dac_words(dac_words)
);

xpm_cdc_array_single #(.DEST_SYNC_FF(4), .INIT_SYNC_FF(1), .SRC_INPUT_REG(1), .WIDTH(2)) inst_adc_select (.src_clk(aclk), .src_in(adc_select), .dest_clk(adc_clk), .dest_out(adc_select_rf));
xpm_cdc_array_single #(.DEST_SYNC_FF(4), .INIT_SYNC_FF(1), .SRC_INPUT_REG(1), .WIDTH(2)) inst_dac_select (.src_clk(aclk), .src_in(dac_select), .dest_clk(dac_clk), .dest_out(dac_select_rf));

// A converter's ADC stream cannot be paused, so a register stage here needs no flow control
logic [127:0] adc_data;
logic         adc_valid;
assign adc_tready = '1;
always_ff @(posedge adc_clk) begin
    adc_data  <= adc_tdata[adc_select_rf];
    adc_valid <= adc_tvalid[adc_select_rf];
end

// The DAC stream does have flow control, so this is combinational
logic [127:0] dac_data;
logic         dac_valid, dac_ready;
assign dac_ready = dac_tready[dac_select_rf];
always_comb begin
    for (int i = 0; i < 4; i++) begin
        dac_tdata[i]  = (dac_select_rf == 2'(i)) ? dac_data : '0;
        dac_tvalid[i] = (dac_select_rf == 2'(i)) ? dac_valid : 1'b0;
    end
end

rf_adc_stream inst_adc (
    .rf_clk(adc_clk), .rf_tdata(adc_data), .rf_tvalid(adc_valid), .rf_tready(),
    .vclk(vclk), .m_axis(m_axis_adc),
    .aclk(aclk), .enable(adc_enable), .test(adc_test), .overflow(adc_overflow), .word_count(adc_words)
);

rf_dac_stream inst_dac (
    .vclk(vclk), .s_axis(s_axis_dac),
    .rf_clk(dac_clk), .rf_tdata(dac_data), .rf_tvalid(dac_valid), .rf_tready(dac_ready),
    .aclk(aclk), .enable(dac_enable), .underflow(dac_underflow), .word_count(dac_words)
);

endmodule
