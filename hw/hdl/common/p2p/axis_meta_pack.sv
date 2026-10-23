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
// axis_meta_pack
// Collapse 3 independent single-beat metaIntf streams (valid/ready/data,
// different widths) of ONE vFPGA into a single 512-bit AXI-Stream flit for
// carriage over the hardened NoC. A 2-bit channel tag in the top tdata bits
// identifies the source stream; the payload occupies the low bits
// (zero-extended). Every meta beat becomes exactly one AXIS packet (tlast=1).
//
// Priority arbitration (ch0 > ch1 > ch2) over the three valids; the grant is
// resolved combinationally and completes in one beat on m_tready, so there is
// no held multi-cycle state (meta beats are atomic). Flat ports are used (not
// a metaIntf modport) because the three inputs carry different STYPEs.
// =====================================================================
module axis_meta_pack #(
    parameter integer DATA_BITS = 512,                 // NoC AXIS width
    parameter integer DEST_BITS = 5,                   // tdest = target vFPGA id
    parameter integer W0        = 256,                 // ch0 payload width (bits)
    parameter integer W1        = 128,                 // ch1 payload width
    parameter integer W2        = 128,                 // ch2 payload width
    parameter integer TAG_BITS  = 2                    // channel-id width (>=2)
) (
    input  logic                       aclk,
    input  logic                       aresetn,

    // target vFPGA id stamped into tdest (constant per instance)
    input  logic [DEST_BITS-1:0]       dest_id,

    // ch0
    input  logic                       s0_valid,
    output logic                       s0_ready,
    input  logic [W0-1:0]              s0_data,
    // ch1
    input  logic                       s1_valid,
    output logic                       s1_ready,
    input  logic [W1-1:0]              s1_data,
    // ch2
    input  logic                       s2_valid,
    output logic                       s2_ready,
    input  logic [W2-1:0]              s2_data,

    // packed output AXI-Stream (to the group arbiter / NMU)
    output logic                       m_tvalid,
    input  logic                       m_tready,
    output logic [DATA_BITS-1:0]       m_tdata,
    output logic [DATA_BITS/8-1:0]     m_tkeep,
    output logic                       m_tlast,
    output logic [DEST_BITS-1:0]       m_tdest
);
    // sanity: all payloads + tag must fit one flit
    // (W* + TAG_BITS <= DATA_BITS) — enforced by elaboration if violated via part-select.
    localparam integer PAY = DATA_BITS - TAG_BITS;

    // priority grant: ch0 > ch1 > ch2
    logic [TAG_BITS-1:0] gnt_tag;
    logic                any_valid;
    logic [PAY-1:0]      pay;

    always_comb begin
        any_valid = s0_valid | s1_valid | s2_valid;
        gnt_tag   = '0;
        pay       = '0;
        if (s0_valid) begin
            gnt_tag = 2'd0;
            pay     = {{(PAY-W0){1'b0}}, s0_data};
        end else if (s1_valid) begin
            gnt_tag = 2'd1;
            pay     = {{(PAY-W1){1'b0}}, s1_data};
        end else if (s2_valid) begin
            gnt_tag = 2'd2;
            pay     = {{(PAY-W2){1'b0}}, s2_data};
        end
    end

    // outputs: single-beat packet
    assign m_tvalid = any_valid;
    assign m_tdata  = {gnt_tag, pay};
    assign m_tkeep  = {(DATA_BITS/8){1'b1}};
    assign m_tlast  = 1'b1;
    assign m_tdest  = dest_id;

    // backpressure: only the granted channel sees ready
    assign s0_ready = m_tready &  s0_valid;
    assign s1_ready = m_tready & ~s0_valid &  s1_valid;
    assign s2_ready = m_tready & ~s0_valid & ~s1_valid & s2_valid;

endmodule
