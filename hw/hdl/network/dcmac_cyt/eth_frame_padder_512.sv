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
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

`timescale 1ns / 1ps

import lynxTypes::*;

/**
 * Minimum-length Ethernet frame padding for a 512-bit AXI4-Stream.
 *
 * Replaces the HLS `ethernet_frame_padding_512_ip` used on the CMAC path,
 * which lives in the `fpga-network-stack` submodule and is therefore not
 * available on builds that bypass the network stack.
 *
 * The whole thing is combinational, with a single flop of state, because of
 * one observation: the datapath is 64 bytes wide and the minimum frame is
 * 60 bytes, so *any* frame shorter than the minimum fits entirely inside its
 * own first beat. A runt is therefore always a single-beat frame, and padding
 * it never requires buffering or stalling - only widening `tkeep` on that one
 * beat. Longer frames pass through untouched.
 *
 * `tkeep` is assumed contiguous from bit 0, which is the convention Coyote's
 * packetised network streams already follow.
 *
 * MIN_FRAME_BYTES defaults to 60, i.e. the 64-byte Ethernet minimum less the
 * 4-byte FCS, on the assumption that the MAC appends the FCS itself. Set it to
 * 64 if the MAC is ever configured to pass FCS through from the user side.
 */
module eth_frame_padder_512 #(
    parameter int MIN_FRAME_BYTES = 60
) (
    input  wire     aclk,
    input  wire     aresetn,

    AXI4S.s         s_axis,
    AXI4S.m         m_axis
);

localparam int DATA_BYTES = AXI_NET_BITS / 8;

// MIN_FRAME_BYTES must not exceed DATA_BYTES, or the single-beat argument
// above stops holding and this module would silently truncate frames.
localparam logic [DATA_BYTES-1:0] KEEP_PAD =
    {DATA_BYTES{1'b1}} >> (DATA_BYTES - MIN_FRAME_BYTES);

// Start-of-frame tracking: the next accepted beat begins a frame iff the
// previously accepted beat was a tlast. Resets to 1, since the first beat
// after reset is by definition a start of frame.
logic sof;
always_ff @(posedge aclk) begin
    if (aresetn == 1'b0) begin
        sof <= 1'b1;
    end else if (s_axis.tvalid && s_axis.tready) begin
        sof <= s_axis.tlast;
    end
end

// Number of valid bytes in the current beat.
logic [$clog2(DATA_BYTES+1)-1:0] beat_bytes;
always_comb begin
    beat_bytes = '0;
    for (int i = 0; i < DATA_BYTES; i++) begin
        beat_bytes += {{($clog2(DATA_BYTES+1)-1){1'b0}}, s_axis.tkeep[i]};
    end
end

// Single-beat frame carrying fewer than the minimum number of bytes.
logic runt;
assign runt = sof && s_axis.tlast && (beat_bytes < MIN_FRAME_BYTES);

always_comb begin
    m_axis.tvalid = s_axis.tvalid;
    m_axis.tlast  = s_axis.tlast;
    m_axis.tkeep  = runt ? KEEP_PAD : s_axis.tkeep;

    // Zero every byte the incoming tkeep does not mark valid. This both
    // supplies the pad bytes with zeroes and scrubs any trailing garbage on
    // the last beat of a normal frame.
    for (int i = 0; i < DATA_BYTES; i++) begin
        m_axis.tdata[i*8 +: 8] = s_axis.tkeep[i] ? s_axis.tdata[i*8 +: 8] : 8'h00;
    end
end

assign s_axis.tready = m_axis.tready;

endmodule
