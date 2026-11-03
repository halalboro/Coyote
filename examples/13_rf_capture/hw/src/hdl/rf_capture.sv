`timescale 1ns / 1ps

import lynxTypes::*;

/**
 * Sends a fixed number of ADC stream words to card memory; all other words are discarded.
 *
 * Registers (axi_ctrl, 64-bit, the index is the cThread::setCSR offset):
 *   0 RW  Number of 64-byte words to capture
 *   1 W   Any write starts a capture
 *   2 R   [0] capture in progress
 *   3 R   Words captured since the last start
 */
module rf_capture (
    input  logic    aclk,
    input  logic    aresetn,
    AXI4L.s         axi_ctrl,
    AXI4S.s         axis_rf,
    AXI4SR.m        axis_card
);

logic [2:0]  waddr;
logic        have_aw, have_w;
logic [63:0] wdata;
logic [31:0] n_words, left, done;
logic        busy, start;

assign axi_ctrl.awready = !have_aw && !axi_ctrl.bvalid;
assign axi_ctrl.wready  = !have_w  && !axi_ctrl.bvalid;
assign axi_ctrl.bresp   = 2'b00;
assign axi_ctrl.rresp   = 2'b00;
assign axi_ctrl.arready = !axi_ctrl.rvalid;
assign start = have_aw && have_w && waddr == 3'd1;

always_ff @(posedge aclk) begin
    if (!aresetn) begin
        have_aw <= 1'b0;
        have_w <= 1'b0;
        axi_ctrl.bvalid <= 1'b0;
        axi_ctrl.rvalid <= 1'b0;
        n_words <= '0;
    end else begin
        if (axi_ctrl.awvalid && axi_ctrl.awready) begin
            waddr <= axi_ctrl.awaddr[5:3];
            have_aw <= 1'b1;
        end
        if (axi_ctrl.wvalid && axi_ctrl.wready) begin
            wdata <= axi_ctrl.wdata;
            have_w <= 1'b1;
        end
        if (have_aw && have_w) begin
            have_aw <= 1'b0;
            have_w <= 1'b0;
            axi_ctrl.bvalid <= 1'b1;
            if (waddr == 3'd0) n_words <= wdata[31:0];
        end
        if (axi_ctrl.bvalid && axi_ctrl.bready) axi_ctrl.bvalid <= 1'b0;

        if (axi_ctrl.arvalid && axi_ctrl.arready) begin
            axi_ctrl.rvalid <= 1'b1;
            case (axi_ctrl.araddr[5:3])
                3'd0:    axi_ctrl.rdata <= 64'(n_words);
                3'd2:    axi_ctrl.rdata <= 64'(busy);
                3'd3:    axi_ctrl.rdata <= 64'(done);
                default: axi_ctrl.rdata <= '0;
            endcase
        end
        if (axi_ctrl.rvalid && axi_ctrl.rready) axi_ctrl.rvalid <= 1'b0;
    end
end

// While busy, words go to card memory, with the shell's back-pressure; otherwise they are discarded
logic last;
assign axis_card.tdata  = axis_rf.tdata;
assign axis_card.tkeep  = axis_rf.tkeep;
assign axis_card.tid    = '0;
assign axis_card.tlast  = last;
assign axis_card.tvalid = busy && axis_rf.tvalid;
assign axis_rf.tready   = busy ? axis_card.tready : 1'b1;

always_ff @(posedge aclk) begin
    if (!aresetn) begin
        busy <= 1'b0;
        last <= 1'b0;
        left <= '0;
        done <= '0;
    end else if (start) begin
        busy <= n_words != 0;
        last <= n_words == 1;
        left <= n_words;
        done <= '0;
    end else if (axis_card.tvalid && axis_card.tready) begin
        left <= left - 1;
        last <= left == 2;
        done <= done + 1;
        if (last) begin
            busy <= 1'b0;
            last <= 1'b0;
        end
    end
end

endmodule
