/**
 * Coyote Example 15: R5 Co-processor Provider — vFPGA body.
 *
 * Two independent datapaths in one region:
 *
 *   host memory  ->  perf_local (+1 per 32-bit word)  ->  host memory
 *   R5 (master)  ->  coprocessor_slave (PING/INC/ADD/SUM + verdict MMIO)  ->  R5
 *
 * The co-processor slave is driven by the R5 over the provider transport
 * (axis_coprocessor_recv/send + s_axi_coprocessor_mmio). It also exposes the
 * verdict register file, read-only, on the vFPGA control interface axi_ctrl so
 * the host can read the R5's self-test result over BAR4.
 *
 * Host-stream only (EN_STRM=1, N_STRM_AXI=1, no card memory); descriptors tied
 * off. Binding (host <-> control target <-> R5) happens in the shell — this
 * body just services the datapath.
 */

import lynxTypes::*;

// host memory => vFPGA (+1 per 32-bit word) => host memory
perf_local inst_host_link (
    .axis_in    (axis_host_recv[0]),
    .axis_out   (axis_host_send[0]),
    .aclk       (aclk),
    .aresetn    (aresetn)
);

// R5 <-> vFPGA co-processor slave over the provider transport. axi_ctrl gives
// the host a read-only mirror of the verdict registers the R5 writes via MMIO.
coprocessor_slave inst_coprocessor (
    .aclk       (aclk),
    .aresetn    (aresetn),
    .axis_recv  (axis_coprocessor_recv[0]),
    .axis_send  (axis_coprocessor_send[0]),
    .axis_mmio  (s_axi_coprocessor_mmio[0]),
    .axi_ctrl   (axi_ctrl)
);

// Tie off unused interfaces
always_comb notify.tie_off_m();
always_comb sq_rd.tie_off_m();
always_comb sq_wr.tie_off_m();
always_comb cq_rd.tie_off_s();
always_comb cq_wr.tie_off_s();
