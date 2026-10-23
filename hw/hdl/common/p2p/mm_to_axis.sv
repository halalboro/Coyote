/**
 * This file is part of the Coyote <https://github.com/fpgasystems/Coyote>
 *
 * MIT Licence
 * Copyright (c) 2021-2025, Systems Group, ETH Zurich
 * All rights reserved.

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

import lynxTypes::*;

/**
 * @brief Milestone B.2 — AXI4-MM write to AXI-Stream bridge (P2P NoC egress).
 *
 * Terminates one axi_noc_p2p master port (NoC -> vFPGA) and converts inbound
 * MM write bursts back into an AXI-Stream toward the receiving vFPGA. The NoC
 * has already routed the transaction to this endpoint by address, so the
 * address bits are discarded here — only the write payload matters.
 *
 * Mapping: each accepted W beat becomes one AXIS beat (tdata=wdata,
 * tkeep=wstrb, tlast=wlast). A single write response (BRESP=OKAY) is returned
 * per burst after its last beat is consumed downstream.
 *
 * The read channel is unused (P2P is write-only); it is tied to a benign slave
 * idle (never asserts arready-driven activity; returns nothing).
 *
 * Simplifying assumptions (MVP transport bring-up):
 *   - One outstanding write burst at a time.
 *   - AW is accepted and its (unused) fields dropped; W beats stream out; B is
 *     returned once the burst's wlast beat is delivered to the AXIS consumer.
 */
module mm_to_axis #(
    parameter integer                       DATA_BITS = AXI_DATA_BITS,     // 512
    parameter integer                       ADDR_BITS = 64
) (
    input  logic                            aclk,
    input  logic                            aresetn,

    // AXI4-MM write slave (from NoC MI)
    AXI4.s                                  s_axi,

    // AXI-Stream egress (to vFPGA recv)
    output logic                            m_axis_tvalid,
    input  logic                            m_axis_tready,
    output logic [DATA_BITS-1:0]            m_axis_tdata,
    output logic [DATA_BITS/8-1:0]          m_axis_tkeep,
    output logic                            m_axis_tlast
);

    // ---------------------------------------------------------------------
    // FSM: accept AW, stream all W beats to AXIS, then emit B.
    // ---------------------------------------------------------------------
    typedef enum logic[1:0] {ST_AW, ST_DATA, ST_BRESP} state_t;
    state_t state_C, state_N;

    logic aw_fire, w_fire, b_fire;
    assign aw_fire = s_axi.awvalid & s_axi.awready;
    assign w_fire  = s_axi.wvalid  & s_axi.wready;
    assign b_fire  = s_axi.bvalid  & s_axi.bready;

    // The W beat is forwarded to AXIS; wready is gated on the AXIS consumer.
    always_comb begin
        state_N = state_C;

        // AXI4 slave defaults
        s_axi.awready = 1'b0;
        s_axi.wready  = 1'b0;
        s_axi.bvalid  = 1'b0;
        s_axi.bresp   = 2'b00; // OKAY
        s_axi.bid     = '0;

        // Unused read channel — idle slave
        s_axi.arready = 1'b0;
        s_axi.rvalid  = 1'b0;
        s_axi.rdata   = '0;
        s_axi.rresp   = 2'b00;
        s_axi.rid     = '0;
        s_axi.rlast   = 1'b0;

        // AXIS master defaults
        m_axis_tvalid = 1'b0;
        m_axis_tdata  = s_axi.wdata;
        m_axis_tkeep  = s_axi.wstrb;
        m_axis_tlast  = s_axi.wlast;

        case (state_C)
            ST_AW: begin
                // Accept the write address (fields unused); move to data.
                s_axi.awready = 1'b1;
                if (aw_fire) state_N = ST_DATA;
            end

            ST_DATA: begin
                // Forward each W beat to the AXIS consumer. Backpressure the
                // W channel with the AXIS tready so no data is dropped.
                m_axis_tvalid = s_axi.wvalid;
                s_axi.wready  = m_axis_tready;
                if (w_fire && s_axi.wlast) state_N = ST_BRESP;
            end

            ST_BRESP: begin
                s_axi.bvalid = 1'b1;
                if (b_fire) state_N = ST_AW;
            end
        endcase
    end

    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            state_C <= ST_AW;
        end else begin
            state_C <= state_N;
        end
    end

endmodule
