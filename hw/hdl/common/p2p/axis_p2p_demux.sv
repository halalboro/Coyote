/**
 * This file is part of the Coyote <https://github.com/fpgasystems/Coyote>
 *
 * MIT Licence
 * Copyright (c) 2025, Systems Group, ETH Zurich
 * All rights reserved.
 */

import lynxTypes::*;

///////////////////////////////////////////////////////////////////////////////
// Inter-vFPGA P2P (Network-3) receive-side hub demux: 1 AXIS stream -> K.
//
// The streaming NoC caps an NSU at 16 connections, so N-way any-to-any groups
// the RECEIVERS: K vFPGAs share one xpm_nsu_strm (a "hub"). The NoC delivers a
// packet to this hub via TDEST_ID = [BASE, BASE+K-1] on the NSU; this demux then
// forwards it to the one local vFPGA selected by tdest: sub = tdest - BASE.
//
// Pure combinational passthrough (no buffering). tdest is stable for a whole
// packet (set per packet by the sender, held by the send arbiter), so sub is
// stable across a packet's beats.
///////////////////////////////////////////////////////////////////////////////

module axis_p2p_demux #(
    parameter integer                       K         = 4,             // vFPGAs in this hub
    parameter integer                       DATA_BITS = AXI_DATA_BITS, // 512
    parameter integer                       DEST_BITS = 5,             // tdest width
    parameter integer                       BASE      = 0              // first vFPGA id in this hub
) (
    input  logic                            aclk,
    input  logic                            aresetn,

    // 1 input AXI-Stream (from the hub's xpm_nsu_strm)
    input  logic                            s_axis_tvalid,
    output logic                            s_axis_tready,
    input  logic [DATA_BITS-1:0]            s_axis_tdata,
    input  logic [DATA_BITS/8-1:0]          s_axis_tkeep,
    input  logic                            s_axis_tlast,
    input  logic [DEST_BITS-1:0]            s_axis_tdest,

    // K output AXI-Streams (one per vFPGA in this hub), packed
    output logic [K-1:0]                    m_axis_tvalid,
    input  logic [K-1:0]                    m_axis_tready,
    output logic [K-1:0][DATA_BITS-1:0]     m_axis_tdata,
    output logic [K-1:0][DATA_BITS/8-1:0]   m_axis_tkeep,
    output logic [K-1:0]                    m_axis_tlast
);

    localparam int SUBW = (K <= 1) ? 1 : $clog2(K);

    // Local index of the target vFPGA within this hub.
    logic [SUBW-1:0] sub;
    always_comb begin
        if (K <= 1) sub = '0;
        else        sub = (s_axis_tdest - DEST_BITS'(BASE));
    end

    always_comb begin
        for (int k = 0; k < K; k++) begin
            m_axis_tdata[k]  = s_axis_tdata;
            m_axis_tkeep[k]  = s_axis_tkeep;
            m_axis_tlast[k]  = s_axis_tlast;
            m_axis_tvalid[k] = 1'b0;
        end
        m_axis_tvalid[sub] = s_axis_tvalid;
        s_axis_tready      = m_axis_tready[sub];
    end

endmodule
