`timescale 1ns / 1ps

import lynxTypes::*;

/**
 * vFPGA stream to DAC samples.
 *
 * Crosses into the converter clock and unpacks each stream word into four 128-bit converter words (lowest bits first).
 * tkeep and tlast are ignored, so every beat is 64 bytes of samples.
 *
 * The DAC output is exactly zero unless enabled. While disabled, the stream is not ready and the FIFO is held in reset, so
 * nothing buffered earlier can come out after an enable. A converter cannot wait for data: when the FIFO runs empty, the
 * output is zero and sticky underflow is set (only after the first word, so waiting for the vFPGA to start is not an error).
 */
module rf_dac_stream #(
    parameter integer FIFO_DEPTH = 512
) (
    // vFPGA clock
    input  logic                        vclk,
    AXI4S.s                             s_axis,

    // Converter clock
    input  logic                        rf_clk,
    output logic [127:0]                rf_tdata = '0,
    output logic                        rf_tvalid = 1'b0,
    input  logic                        rf_tready,

    // Control clock
    input  logic                        aclk,
    input  logic                        enable,
    output logic                        underflow,
    output logic [31:0]                 word_count
);

logic en_rf, en_v;
xpm_cdc_single #(.DEST_SYNC_FF(4), .INIT_SYNC_FF(1), .SRC_INPUT_REG(1)) inst_en_rf (.src_clk(aclk), .src_in(enable), .dest_clk(rf_clk), .dest_out(en_rf));
xpm_cdc_single #(.DEST_SYNC_FF(4), .INIT_SYNC_FF(1), .SRC_INPUT_REG(1)) inst_en_v  (.src_clk(aclk), .src_in(enable), .dest_clk(vclk),   .dest_out(en_v));

logic                     full, wr_rst_busy, rd_rst_busy, empty;
logic [AXI_DATA_BITS-1:0] rd_data;
logic                     rd_en;

assign s_axis.tready = en_v && !full && !wr_rst_busy;

xpm_fifo_async #(
    .FIFO_MEMORY_TYPE("block"),
    .FIFO_WRITE_DEPTH(FIFO_DEPTH),
    .WRITE_DATA_WIDTH(AXI_DATA_BITS),
    .READ_DATA_WIDTH(AXI_DATA_BITS),
    .READ_MODE("fwft"),
    .FIFO_READ_LATENCY(0),
    .CDC_SYNC_STAGES(3),
    .USE_ADV_FEATURES("0000")
) inst_fifo (
    .rst(!en_v),
    .wr_clk(vclk),
    .wr_en(s_axis.tvalid && s_axis.tready),
    .din(s_axis.tdata),
    .full(full),
    .wr_rst_busy(wr_rst_busy),
    .rd_clk(rf_clk),
    .rd_en(rd_en),
    .dout(rd_data),
    .empty(empty),
    .rd_rst_busy(rd_rst_busy),
    .sleep(1'b0),
    .injectsbiterr(1'b0),
    .injectdbiterr(1'b0)
);

logic [1:0]   cnt = '0;
logic [383:0] hold;
logic         started = 1'b0, underflow_rf = 1'b0;
logic [31:0]  count_rf = '0;

logic have_word;
assign have_word = !empty && !rd_rst_busy;
assign rd_en     = en_rf && rf_tready && (cnt == 2'd0) && have_word;

always_ff @(posedge rf_clk) begin
    if (!en_rf) begin
        cnt <= '0;
        started <= 1'b0;
        underflow_rf <= 1'b0;
        count_rf <= '0;
        rf_tdata <= '0;
        rf_tvalid <= 1'b0;
    end else begin
        rf_tvalid <= 1'b1;
        if (rf_tready) begin
            if (cnt != 2'd0) begin
                rf_tdata <= hold[(cnt-1)*128 +: 128];
                cnt <= cnt + 1;
            end else if (have_word) begin
                rf_tdata <= rd_data[127:0];
                hold <= rd_data[AXI_DATA_BITS-1:128];
                cnt <= 2'd1;
                started <= 1'b1;
                count_rf <= count_rf + 1;
            end else begin
                rf_tdata <= '0;
                if (started) underflow_rf <= 1'b1;
            end
        end
    end
end

xpm_cdc_single #(.DEST_SYNC_FF(4), .INIT_SYNC_FF(1), .SRC_INPUT_REG(1)) inst_udf (.src_clk(rf_clk), .src_in(underflow_rf), .dest_clk(aclk), .dest_out(underflow));
xpm_cdc_gray #(.DEST_SYNC_FF(4), .INIT_SYNC_FF(1), .WIDTH(32)) inst_cnt (.src_clk(rf_clk), .src_in_bin(count_rf), .dest_clk(aclk), .dest_out_bin(word_count));

endmodule
