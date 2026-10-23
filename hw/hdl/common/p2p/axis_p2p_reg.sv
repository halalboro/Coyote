/**
 * This file is part of the Coyote <https://github.com/fpgasystems/Coyote>
 *
 * MIT Licence
 * Copyright (c) 2026, Systems Group, ETH Zurich
 * All rights reserved.
 */

// Fully-registered AXI-Stream skid buffer for the flat (tdata/tkeep/tlast/tdest)
// signals used by axis_p2p_arbiter / axis_p2p_demux / xpm_*_strm. Breaks BOTH the
// forward data path AND the backward tready path so a NoC endpoint's tready no
// longer propagates combinationally through the K->1 arbiter (the ~-4.5ns
// build_hnoc15 WNS path on inst_hnoc_c2h_nmu_00/s_axis_tready). Full throughput
// (one beat/cycle when the skid slot is free). Carries tdest through the same
// register as the data so it stays aligned across the variable-occupancy skid.
//
// N_STAGES chains that many single skid buffers (each adds one cycle of latency
// and one more level of pipelining). Standard skid-buffer FSM; s_axis_tready is a
// registered signal (= ~skid_valid), isolating upstream from m_axis_tready.

module axis_p2p_reg #(
    parameter int unsigned DATA_BITS = 512,
    parameter int unsigned DEST_BITS = 5,
    parameter int unsigned N_STAGES  = 2
) (
    input  logic                     aclk,
    input  logic                     aresetn,
    // slave (input)
    input  logic                     s_axis_tvalid,
    output logic                     s_axis_tready,
    input  logic [DATA_BITS-1:0]     s_axis_tdata,
    input  logic [DATA_BITS/8-1:0]   s_axis_tkeep,
    input  logic                     s_axis_tlast,
    input  logic [DEST_BITS-1:0]     s_axis_tdest,
    // master (output)
    output logic                     m_axis_tvalid,
    input  logic                     m_axis_tready,
    output logic [DATA_BITS-1:0]     m_axis_tdata,
    output logic [DATA_BITS/8-1:0]   m_axis_tkeep,
    output logic                     m_axis_tlast,
    output logic [DEST_BITS-1:0]     m_axis_tdest
);
    localparam int unsigned W = DATA_BITS + DATA_BITS/8 + 1 + DEST_BITS;

    // packed per-stage boundary buses (stage 0 = input, stage N_STAGES = output)
    logic [N_STAGES:0][W-1:0] pkt;
    logic [N_STAGES:0]        vld;
    logic [N_STAGES:0]        rdy;

    assign pkt[0]        = {s_axis_tdest, s_axis_tlast, s_axis_tkeep, s_axis_tdata};
    assign vld[0]        = s_axis_tvalid;
    assign s_axis_tready = rdy[0];

    assign {m_axis_tdest, m_axis_tlast, m_axis_tkeep, m_axis_tdata} = pkt[N_STAGES];
    assign m_axis_tvalid = vld[N_STAGES];
    assign rdy[N_STAGES] = m_axis_tready;

    for (genvar s = 0; s < N_STAGES; s++) begin : g_stage
        // one skid buffer: input side pkt[s]/vld[s]/rdy[s], output side pkt[s+1]/vld[s+1]/rdy[s+1]
        logic [W-1:0] out_pkt;
        logic         out_vld;
        logic [W-1:0] skid_pkt;
        logic         skid_vld;

        // accept from upstream unless our skid slot is occupied
        assign rdy[s]     = ~skid_vld;
        assign pkt[s+1]   = out_pkt;
        assign vld[s+1]   = out_vld;

        always_ff @(posedge aclk) begin
            if (!aresetn) begin
                out_vld  <= 1'b0;
                skid_vld <= 1'b0;
            end else begin
                if (~skid_vld) begin
                    if (out_vld & ~rdy[s+1] & vld[s]) begin
                        // output stalled and a new beat arrives (accepted, since rdy[s]=1) -> park it
                        skid_pkt <= pkt[s];
                        skid_vld <= 1'b1;
                    end else if (~out_vld | rdy[s+1]) begin
                        // output free or being consumed -> load next beat (or drain)
                        out_vld <= vld[s];
                        if (vld[s]) out_pkt <= pkt[s];
                    end
                end else begin
                    // skid holds a beat; upstream stalled (rdy[s]=0). drain skid -> output when able
                    if (rdy[s+1]) begin
                        out_pkt  <= skid_pkt;
                        out_vld  <= 1'b1;
                        skid_vld <= 1'b0;
                    end
                end
            end
        end
    end
endmodule
