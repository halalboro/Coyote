/**
 * This file is part of the Coyote <https://github.com/fpgasystems/Coyote>
 *
 * MIT Licence
 * Copyright (c) 2025, Systems Group, ETH Zurich
 * All rights reserved.
 */

import lynxTypes::*;

///////////////////////////////////////////////////////////////////////////////
// Inter-vFPGA P2P (Network-3) send-side arbiter: K AXIS streams -> 1.
//
// The streaming NoC caps an NMU at 16 connections, so N-way any-to-any needs the
// senders GROUPED: K vFPGA send streams share one xpm_nmu_strm via this K->1
// round-robin arbiter (mirrors the receive-side hub demux). tdest (the target
// vFPGA id) travels with the stream and is forwarded to the NMU unchanged.
//
// PACKET-GRANULAR: once a source is granted it holds the output until its tlast,
// so one packet is never interleaved with another. Fair rotating round-robin
// among sources asserting tvalid. No combinational loops.
///////////////////////////////////////////////////////////////////////////////

module axis_p2p_arbiter #(
    parameter integer                       K         = 4,             // vFPGAs per send group
    parameter integer                       DATA_BITS = AXI_DATA_BITS, // 512
    parameter integer                       DEST_BITS = 5              // tdest = target vFPGA id
) (
    input  logic                            aclk,
    input  logic                            aresetn,

    // K input AXI-Streams (one per vFPGA in this send group), packed
    input  logic [K-1:0]                    s_axis_tvalid,
    output logic [K-1:0]                    s_axis_tready,
    input  logic [K-1:0][DATA_BITS-1:0]     s_axis_tdata,
    input  logic [K-1:0][DATA_BITS/8-1:0]   s_axis_tkeep,
    input  logic [K-1:0]                    s_axis_tlast,
    input  logic [K-1:0][DEST_BITS-1:0]     s_axis_tdest,

    // 1 output AXI-Stream (to the group's xpm_nmu_strm)
    output logic                            m_axis_tvalid,
    input  logic                            m_axis_tready,
    output logic [DATA_BITS-1:0]            m_axis_tdata,
    output logic [DATA_BITS/8-1:0]          m_axis_tkeep,
    output logic                            m_axis_tlast,
    output logic [DEST_BITS-1:0]            m_axis_tdest
);

    localparam int SELW = (K <= 1) ? 1 : $clog2(K);

    logic [SELW-1:0] sel_C, sel_N;
    logic            lock_C, lock_N;

    // Rotating round-robin from the source AFTER sel_C.
    function automatic logic [SELW-1:0] next_src (input logic [SELW-1:0] cur);
        logic [SELW-1:0] cand;
        next_src = cur;
        for (int off = 1; off <= K; off++) begin
            cand = (cur + off) % K;
            if (s_axis_tvalid[cand]) begin
                next_src = cand;
                break;
            end
        end
    endfunction

    logic [SELW-1:0] gsrc;
    logic            granted;
    always_comb begin
        if (lock_C) begin
            gsrc    = sel_C;
            granted = 1'b1;
        end else begin
            gsrc    = (K > 1) ? next_src(sel_C) : '0;
            granted = s_axis_tvalid[gsrc];
        end
    end

    always_comb begin
        m_axis_tvalid = granted & s_axis_tvalid[gsrc];
        m_axis_tdata  = s_axis_tdata[gsrc];
        m_axis_tkeep  = s_axis_tkeep[gsrc];
        m_axis_tlast  = s_axis_tlast[gsrc];
        m_axis_tdest  = s_axis_tdest[gsrc];
        for (int k = 0; k < K; k++) s_axis_tready[k] = 1'b0;
        if (granted) s_axis_tready[gsrc] = m_axis_tready;
    end

    logic beat_fire, last_fire;
    assign beat_fire = m_axis_tvalid & m_axis_tready;
    assign last_fire = beat_fire & m_axis_tlast;

    always_comb begin
        sel_N  = sel_C;
        lock_N = lock_C;
        if (!lock_C) begin
            if (granted) begin
                sel_N  = gsrc;
                lock_N = ~last_fire;
            end
        end else begin
            if (last_fire) lock_N = 1'b0;
        end
    end

    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            sel_C  <= '0;
            lock_C <= 1'b0;
        end else begin
            sel_C  <= sel_N;
            lock_C <= lock_N;
        end
    end

endmodule
