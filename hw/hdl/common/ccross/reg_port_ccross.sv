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

/**
 * Clock crossing for a single-outstanding register access port.
 *
 * The port is deliberately minimal - a request pulse carrying {wr, addr,
 * wdata}, answered some time later by a response pulse carrying {resp, rdata}
 * - so it can be threaded through the shell boundary without an AXI4-Lite
 * clock converter IP. Each direction is one xpm_cdc_handshake, which moves the
 * whole word coherently and carries its own timing constraints.
 *
 * Contract, both sides:
 *   - *_req / *_rsp are single-cycle pulses; the payload is sampled with them.
 *   - At most one request is in flight. The master must not issue s_req again
 *     until it has seen s_rsp, and the slave answers each m_req with exactly
 *     one m_rsp.
 *
 * A response can arrive before the handshake that carried its request has
 * finished its return-to-zero phase, so the next request may legally turn up
 * while that crossing is still busy. Each direction therefore holds one
 * pending transfer and starts it as soon as the crossing is free.
 *
 * Request-to-response latency is a few tens of cycles of the slower clock;
 * this is a debug/control path, not a datapath.
 */
module reg_port_ccross #(
    parameter integer ADDR_BITS = 32,
    parameter integer DATA_BITS = 32
) (
    // Master side (issues requests)
    input  logic                    s_clk,
    input  logic                    s_resetn,
    input  logic                    s_req,
    input  logic                    s_wr,
    input  logic [ADDR_BITS-1:0]    s_addr,
    input  logic [DATA_BITS-1:0]    s_wdata,
    output logic                    s_rsp,
    output logic [DATA_BITS-1:0]    s_rdata,
    output logic [1:0]              s_resp,

    // Slave side (serves requests)
    input  logic                    m_clk,
    input  logic                    m_resetn,
    output logic                    m_req,
    output logic                    m_wr,
    output logic [ADDR_BITS-1:0]    m_addr,
    output logic [DATA_BITS-1:0]    m_wdata,
    input  logic                    m_rsp,
    input  logic [DATA_BITS-1:0]    m_rdata,
    input  logic [1:0]              m_resp
);

localparam integer REQ_BITS = 1 + ADDR_BITS + DATA_BITS;
localparam integer RSP_BITS = 2 + DATA_BITS;

// ---------------------------------------------------------------------------
// Source-side handshake FSM, shared shape for both directions:
//   IDLE  -> (pulse) latch payload, raise send
//   SEND  -> (rcv)   drop send
//   DRAIN -> (!rcv)  back to IDLE
// xpm_cdc_handshake requires src_in stable while src_send is high and src_send
// to stay low until src_rcv has fallen again; the DRAIN state enforces that.
// ---------------------------------------------------------------------------
typedef enum logic [1:0] {ST_IDLE, ST_SEND, ST_DRAIN} hs_state_t;

// Request: s_clk -> m_clk
hs_state_t               req_state;
logic                    req_send;
logic                    req_rcv;
logic [REQ_BITS-1:0]     req_src;
logic [REQ_BITS-1:0]     req_dst;
logic                    req_dst_vld;
logic                    req_pend;
logic [REQ_BITS-1:0]     req_pend_data;

always_ff @(posedge s_clk) begin
    if (!s_resetn) begin
        req_state     <= ST_IDLE;
        req_send      <= 1'b0;
        req_src       <= '0;
        req_pend      <= 1'b0;
        req_pend_data <= '0;
    end else begin
        if (s_req) begin
            req_pend      <= 1'b1;
            req_pend_data <= {s_wr, s_addr, s_wdata};
        end

        case (req_state)
            ST_IDLE: if (req_pend) begin
                req_src   <= req_pend_data;
                req_send  <= 1'b1;
                req_pend  <= s_req;   // a request in this very cycle stays pending
                req_state <= ST_SEND;
            end
            ST_SEND: if (req_rcv) begin
                req_send  <= 1'b0;
                req_state <= ST_DRAIN;
            end
            ST_DRAIN: if (!req_rcv) begin
                req_state <= ST_IDLE;
            end
            default: req_state <= ST_IDLE;
        endcase
    end
end

xpm_cdc_handshake #(
    .DEST_EXT_HSK   (0),
    .DEST_SYNC_FF   (4),
    .INIT_SYNC_FF   (0),
    .SIM_ASSERT_CHK (0),
    .SRC_SYNC_FF    (4),
    .WIDTH          (REQ_BITS)
) inst_req_hs (
    .src_clk  (s_clk),
    .src_in   (req_src),
    .src_send (req_send),
    .src_rcv  (req_rcv),
    .dest_clk (m_clk),
    .dest_req (req_dst_vld),
    .dest_ack (1'b0),
    .dest_out (req_dst)
);

// dest_req is a one-cycle pulse with DEST_EXT_HSK = 0, and dest_out holds
// until the next transfer, so the payload can be driven straight out.
always_ff @(posedge m_clk) begin
    if (!m_resetn) begin
        m_req <= 1'b0;
    end else begin
        m_req <= req_dst_vld;
    end
end

assign {m_wr, m_addr, m_wdata} = req_dst;

// Response: m_clk -> s_clk
hs_state_t               rsp_state;
logic                    rsp_send;
logic                    rsp_rcv;
logic [RSP_BITS-1:0]     rsp_src;
logic [RSP_BITS-1:0]     rsp_dst;
logic                    rsp_dst_vld;
logic                    rsp_pend;
logic [RSP_BITS-1:0]     rsp_pend_data;

always_ff @(posedge m_clk) begin
    if (!m_resetn) begin
        rsp_state     <= ST_IDLE;
        rsp_send      <= 1'b0;
        rsp_src       <= '0;
        rsp_pend      <= 1'b0;
        rsp_pend_data <= '0;
    end else begin
        if (m_rsp) begin
            rsp_pend      <= 1'b1;
            rsp_pend_data <= {m_resp, m_rdata};
        end

        case (rsp_state)
            ST_IDLE: if (rsp_pend) begin
                rsp_src   <= rsp_pend_data;
                rsp_send  <= 1'b1;
                rsp_pend  <= m_rsp;
                rsp_state <= ST_SEND;
            end
            ST_SEND: if (rsp_rcv) begin
                rsp_send  <= 1'b0;
                rsp_state <= ST_DRAIN;
            end
            ST_DRAIN: if (!rsp_rcv) begin
                rsp_state <= ST_IDLE;
            end
            default: rsp_state <= ST_IDLE;
        endcase
    end
end

xpm_cdc_handshake #(
    .DEST_EXT_HSK   (0),
    .DEST_SYNC_FF   (4),
    .INIT_SYNC_FF   (0),
    .SIM_ASSERT_CHK (0),
    .SRC_SYNC_FF    (4),
    .WIDTH          (RSP_BITS)
) inst_rsp_hs (
    .src_clk  (m_clk),
    .src_in   (rsp_src),
    .src_send (rsp_send),
    .src_rcv  (rsp_rcv),
    .dest_clk (s_clk),
    .dest_req (rsp_dst_vld),
    .dest_ack (1'b0),
    .dest_out (rsp_dst)
);

always_ff @(posedge s_clk) begin
    if (!s_resetn) begin
        s_rsp <= 1'b0;
    end else begin
        s_rsp <= rsp_dst_vld;
    end
end

assign {s_resp, s_rdata} = rsp_dst;

endmodule
