`timescale 1ns / 1ps

import lynxTypes::*;

/**
 * RF data converter service: one receive and one transmit stream between the converter clocks and one vFPGA, plus the
 * control registers (rf_slave.sv). The streams carry 16-bit samples, first sample in the lowest bits.
 */
module rf_service (
    input  logic         aclk,
    input  logic         aresetn,
    AXI4L.s              s_axi_cnfg,

    // vFPGA side; vclk is aclk or uclk
    input  logic         vclk,
    AXI4S.m              m_axis_adc,
    AXI4S.s              s_axis_dac,

    // Converter side
    input  logic         adc_clk,
    input  logic [127:0] adc_tdata,
    input  logic         adc_tvalid,
    output logic         adc_tready,
    input  logic         dac_clk,
    output logic [127:0] dac_tdata,
    output logic         dac_tvalid,
    input  logic         dac_tready
);

logic adc_enable, dac_enable, adc_overflow, dac_underflow;
logic [31:0] adc_words, dac_words;

rf_slave inst_slave (
    .aclk(aclk), .aresetn(aresetn), .s_axi(s_axi_cnfg),
    .adc_enable(adc_enable), .dac_enable(dac_enable), .adc_overflow(adc_overflow), .dac_underflow(dac_underflow),
    .adc_words(adc_words), .dac_words(dac_words)
);

rf_adc_stream inst_adc (
    .rf_clk(adc_clk), .rf_tdata(adc_tdata), .rf_tvalid(adc_tvalid), .rf_tready(adc_tready),
    .vclk(vclk), .m_axis(m_axis_adc),
    .aclk(aclk), .enable(adc_enable), .overflow(adc_overflow), .word_count(adc_words)
);

rf_dac_stream inst_dac (
    .vclk(vclk), .s_axis(s_axis_dac),
    .rf_clk(dac_clk), .rf_tdata(dac_tdata), .rf_tvalid(dac_tvalid), .rf_tready(dac_tready),
    .aclk(aclk), .enable(dac_enable), .underflow(dac_underflow), .word_count(dac_words)
);

endmodule
