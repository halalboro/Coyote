/**
 * This file is part of the Coyote <https://github.com/fpgasystems/Coyote>
 *
 * MIT Licence
 * Copyright (c) 2025, Systems Group, ETH Zurich
 * All rights reserved.
 */

import lynxTypes::*;

/////////////////////////////////////////////////////////////////////////////
// Minimal vFPGA for the N=32 shared-hub P2P mesh bring-up.
//
// A tiny host-stream loopback (recv -> send) plus tie-offs. ~a handful of LUTs,
// so 32 of these fit the shell region easily (unlike the heavy AES example).
//
// The inter-vFPGA P2P NoC datapath (axis_to_mm -> hub NoC -> mm_to_axis_demux)
// is instantiated and kept alive by the shell wrapper (DONT_TOUCH); this first
// cut does not drive it from user logic. Its purpose is to prove the N=32 stack
// builds (hub NoC, demux, templates) and place/route closes.
/////////////////////////////////////////////////////////////////////////////

// Host stream loopback: echo the host read stream back on the write stream.
assign axis_host_send[0].tdata  = axis_host_recv[0].tdata;
assign axis_host_send[0].tkeep  = axis_host_recv[0].tkeep;
assign axis_host_send[0].tlast  = axis_host_recv[0].tlast;
assign axis_host_send[0].tid    = axis_host_recv[0].tid;
assign axis_host_send[0].tvalid = axis_host_recv[0].tvalid;
assign axis_host_recv[0].tready = axis_host_send[0].tready;

// Unused control / memory / notify interfaces -> tie off.
always_comb axi_ctrl.tie_off_s();
always_comb notify.tie_off_m();
always_comb sq_rd.tie_off_m();
always_comb sq_wr.tie_off_m();
always_comb cq_rd.tie_off_s();
always_comb cq_wr.tie_off_s();
