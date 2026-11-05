`timescale 1ns / 1ps

/**
 * RF service registers, 32-bit, at the RF control window. Both enables reset to 0.
 *   0x00 R   ID, 0x52460001
 *   0x04 RW  [0] ADC stream enable, [1] DAC stream enable (DAC output is zero while 0),
 *            [2] ADC test pattern instead of samples (consecutive 16-bit values; change it while disabled)
 *   0x08 R   [0] ADC overflow, [1] DAC underflow; sticky, cleared by disabling that direction
 *   0x0C R   ADC stream words written (64 bytes each), cleared by disabling
 *   0x10 R   DAC stream words played (64 bytes each), cleared by disabling
 *   0x14 R   Number of converter channels per direction (shells from before this register read 0, and have one)
 *   0x18 RW  [1:0] ADC channel, [9:8] DAC channel; change them while that direction is disabled
 *   0x1C R   Sampling rate in kHz (shells from before this register read 0, and run at 2457600)
 */
module rf_slave #(
    parameter logic [31:0] RATE_KHZ = 32'd2457600
) (
    input  logic        aclk,
    input  logic        aresetn,
    AXI4L.s             s_axi,

    output logic        adc_enable,
    output logic        dac_enable,
    output logic        adc_test,
    output logic [1:0]  adc_select,
    output logic [1:0]  dac_select,
    input  logic        adc_overflow,
    input  logic        dac_underflow,
    input  logic [31:0] adc_words,
    input  logic [31:0] dac_words
);

localparam logic [31:0] RF_ID = 32'h52460001;

logic [7:0] waddr;
logic       have_aw, have_w;
logic [31:0] wdata;
logic [3:0]  wstrb;

assign s_axi.awready = !have_aw && !s_axi.bvalid;
assign s_axi.wready  = !have_w  && !s_axi.bvalid;
assign s_axi.bresp   = 2'b00;
assign s_axi.rresp   = 2'b00;
assign s_axi.arready = !s_axi.rvalid;

always_ff @(posedge aclk) begin
    if (!aresetn) begin
        have_aw <= 1'b0;
        have_w <= 1'b0;
        s_axi.bvalid <= 1'b0;
        s_axi.rvalid <= 1'b0;
        adc_enable <= 1'b0;
        dac_enable <= 1'b0;
        adc_test <= 1'b0;
        adc_select <= '0;
        dac_select <= '0;
    end else begin
        if (s_axi.awvalid && s_axi.awready) begin
            waddr <= s_axi.awaddr[7:0];
            have_aw <= 1'b1;
        end
        if (s_axi.wvalid && s_axi.wready) begin
            wdata <= s_axi.wdata;
            wstrb <= s_axi.wstrb;
            have_w <= 1'b1;
        end
        if (have_aw && have_w) begin
            have_aw <= 1'b0;
            have_w <= 1'b0;
            s_axi.bvalid <= 1'b1;
            if (waddr[7:2] == 6'd1 && wstrb[0]) begin
                adc_enable <= wdata[0];
                dac_enable <= wdata[1];
                adc_test <= wdata[2];
            end
            if (waddr[7:2] == 6'd6) begin
                if (wstrb[0]) adc_select <= wdata[1:0];
                if (wstrb[1]) dac_select <= wdata[9:8];
            end
        end
        if (s_axi.bvalid && s_axi.bready) s_axi.bvalid <= 1'b0;

        if (s_axi.arvalid && s_axi.arready) begin
            s_axi.rvalid <= 1'b1;
            case (s_axi.araddr[7:2])
                6'd0:    s_axi.rdata <= RF_ID;
                6'd1:    s_axi.rdata <= {29'd0, adc_test, dac_enable, adc_enable};
                6'd2:    s_axi.rdata <= {30'd0, dac_underflow, adc_overflow};
                6'd3:    s_axi.rdata <= adc_words;
                6'd4:    s_axi.rdata <= dac_words;
                6'd5:    s_axi.rdata <= 32'd4;
                6'd6:    s_axi.rdata <= {22'd0, dac_select, 6'd0, adc_select};
                6'd7:    s_axi.rdata <= RATE_KHZ;
                default: s_axi.rdata <= 32'd0;
            endcase
        end
        if (s_axi.rvalid && s_axi.rready) s_axi.rvalid <= 1'b0;
    end
end

endmodule
