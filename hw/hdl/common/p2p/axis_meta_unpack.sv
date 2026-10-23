/**
 * This file is part of the Coyote <https://github.com/fpgasystems/Coyote>
 *
 * MIT Licence
 * Copyright (c) 2026, Systems Group, ETH Zurich
 * All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:

 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.

 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

`timescale 1ns / 1ps

// =====================================================================
// axis_meta_unpack
// Inverse of axis_meta_pack: take a single-beat 512-bit AXI-Stream flit
// (delivered by the per-vFPGA NoC demux) and fan it back out to 3 metaIntf
// master streams by the 2-bit channel tag in the top tdata bits. The payload
// occupies the low bits; each output takes its own slice width.
//
// Exactly one output's valid is asserted per incoming beat (selected by tag);
// the input tready reflects that selected output's ready, so backpressure is
// stream-accurate. Flat ports (different STYPEs per channel).
// =====================================================================
module axis_meta_unpack #(
    parameter integer DATA_BITS = 512,
    parameter integer W0        = 256,
    parameter integer W1        = 128,
    parameter integer W2        = 128,
    parameter integer TAG_BITS  = 2
) (
    input  logic                       aclk,
    input  logic                       aresetn,

    // packed input AXI-Stream (from the per-vFPGA NoC demux output)
    input  logic                       s_tvalid,
    output logic                       s_tready,
    input  logic [DATA_BITS-1:0]       s_tdata,
    input  logic [DATA_BITS/8-1:0]     s_tkeep,
    input  logic                       s_tlast,

    // ch0
    output logic                       m0_valid,
    input  logic                       m0_ready,
    output logic [W0-1:0]              m0_data,
    // ch1
    output logic                       m1_valid,
    input  logic                       m1_ready,
    output logic [W1-1:0]              m1_data,
    // ch2
    output logic                       m2_valid,
    input  logic                       m2_ready,
    output logic [W2-1:0]              m2_data
);
    localparam integer PAY = DATA_BITS - TAG_BITS;

    logic [TAG_BITS-1:0] tag;
    logic [PAY-1:0]      pay;
    assign tag = s_tdata[DATA_BITS-1 -: TAG_BITS];
    assign pay = s_tdata[PAY-1:0];

    // data slices (low bits of the payload)
    assign m0_data = pay[W0-1:0];
    assign m1_data = pay[W1-1:0];
    assign m2_data = pay[W2-1:0];

    // route valid by tag
    assign m0_valid = s_tvalid & (tag == 2'd0);
    assign m1_valid = s_tvalid & (tag == 2'd1);
    assign m2_valid = s_tvalid & (tag == 2'd2);

    // input ready = the selected channel's ready (unknown tag -> drop, ready=1
    // to avoid lock-up; cannot occur with a well-formed packer)
    always_comb begin
        unique case (tag)
            2'd0:    s_tready = m0_ready;
            2'd1:    s_tready = m1_ready;
            2'd2:    s_tready = m2_ready;
            default: s_tready = 1'b1;
        endcase
    end

endmodule
