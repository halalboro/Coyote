`timescale 1ns / 1ps

import lynxTypes::*;

/**
 * ADC samples to a vFPGA stream.
 *
 * Packs four 128-bit converter words (first sample in the lowest bits) into one stream word and crosses into the vFPGA
 * clock. A converter cannot be paused, so when the vFPGA does not keep up, whole stream words are dropped and sticky
 * overflow is set (not for the words dropped while the FIFO comes out of reset after an enable). While disabled, the FIFO is held in reset, so nothing stale reaches the vFPGA after an enable.
 */
module rf_adc_stream #(
    parameter integer FIFO_DEPTH = 512
) (
    // Converter clock
    input  logic                        rf_clk,
    input  logic [127:0]                rf_tdata,
    input  logic                        rf_tvalid,
    output logic                        rf_tready,

    // vFPGA clock
    input  logic                        vclk,
    AXI4S.m                             m_axis,

    // Control clock
    input  logic                        aclk,
    input  logic                        enable,
    output logic                        overflow,
    output logic [31:0]                 word_count
);

logic en_rf, en_v;
xpm_cdc_single #(.DEST_SYNC_FF(4), .INIT_SYNC_FF(1), .SRC_INPUT_REG(1)) inst_en_rf (.src_clk(aclk), .src_in(enable), .dest_clk(rf_clk), .dest_out(en_rf));
xpm_cdc_single #(.DEST_SYNC_FF(4), .INIT_SYNC_FF(1), .SRC_INPUT_REG(1)) inst_en_v  (.src_clk(aclk), .src_in(enable), .dest_clk(vclk),   .dest_out(en_v));

assign rf_tready = 1'b1;

logic [1:0]               cnt = '0;
logic [383:0]             hold;
logic [AXI_DATA_BITS-1:0] wr_data;
logic                     wr_en, full, wr_rst_busy, rd_rst_busy, empty, rd_en;
logic                     overflow_rf = 1'b0, started = 1'b0;
logic [31:0]              count_rf = '0;

always_ff @(posedge rf_clk) begin
    wr_en <= 1'b0;
    if (!en_rf) begin
        cnt <= '0;
        overflow_rf <= 1'b0;
        started <= 1'b0;
        count_rf <= '0;
    end else if (rf_tvalid) begin
        cnt <= cnt + 1;
        if (cnt == 2'd3) begin
            wr_data <= {rf_tdata, hold};
            if (!full && !wr_rst_busy) begin
                wr_en <= 1'b1;
                count_rf <= count_rf + 1;
                started <= 1'b1;
            end else if (started) begin
                overflow_rf <= 1'b1;
            end
        end else begin
            hold[cnt*128 +: 128] <= rf_tdata;
        end
    end
end

xpm_fifo_async #(
    .FIFO_MEMORY_TYPE("block"),
    .FIFO_WRITE_DEPTH(FIFO_DEPTH),
    .WRITE_DATA_WIDTH(AXI_DATA_BITS),
    .READ_DATA_WIDTH(AXI_DATA_BITS),
    .READ_MODE("fwft"),
    .FIFO_READ_LATENCY(0),
    .CDC_SYNC_STAGES(3),
    .PROG_FULL_THRESH(FIFO_DEPTH-8),
    .USE_ADV_FEATURES("0000")
) inst_fifo (
    .rst(!en_rf),
    .wr_clk(rf_clk),
    .wr_en(wr_en),
    .din(wr_data),
    .full(full),
    .wr_rst_busy(wr_rst_busy),
    .rd_clk(vclk),
    .rd_en(rd_en),
    .dout(m_axis.tdata),
    .empty(empty),
    .rd_rst_busy(rd_rst_busy),
    .sleep(1'b0),
    .injectsbiterr(1'b0),
    .injectdbiterr(1'b0)
);

assign m_axis.tvalid = en_v && !empty && !rd_rst_busy;
assign m_axis.tkeep  = '1;
assign m_axis.tlast  = 1'b0;
assign rd_en         = m_axis.tvalid && m_axis.tready;

xpm_cdc_single #(.DEST_SYNC_FF(4), .INIT_SYNC_FF(1), .SRC_INPUT_REG(1)) inst_ovf (.src_clk(rf_clk), .src_in(overflow_rf), .dest_clk(aclk), .dest_out(overflow));
xpm_cdc_gray #(.DEST_SYNC_FF(4), .INIT_SYNC_FF(1), .WIDTH(32)) inst_cnt (.src_clk(rf_clk), .src_in_bin(count_rf), .dest_clk(aclk), .dest_out_bin(word_count));

endmodule
