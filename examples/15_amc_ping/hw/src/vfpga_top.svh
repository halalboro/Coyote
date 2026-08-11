/**
 * Coyote Example 15: AMC Ping — functional vFPGA (host loopback +1).
 *
 * Replaces the Phase-A placeholder with a real, simple kernel so the vFPGA and
 * the AMC can be exercised together in one bitstream:
 *
 *   host memory  ->  vFPGA  ->  host memory
 *
 * `perf_local` streams host data through the vFPGA and increments each 32-bit
 * word by 1, so the host can verify end-to-end that the vFPGA actually
 * processed the data (out[i] == in[i] + 1). The AMC runs independently on the
 * R5 and is reached over PCIe (BAR4 DDR window / GCQ mailbox) — the two share
 * the card but not the datapath, and coexist without interfering.
 *
 * This example is host-stream only (EN_STRM=1, N_STRM_AXI=1, no card memory),
 * so only the host link is wired; everything else is tied off.
 */

import lynxTypes::*;

// host memory => vFPGA (+1 per 32-bit word) => host memory
perf_local inst_host_link (
    .axis_in    (axis_host_recv[0]),
    .axis_out   (axis_host_send[0]),
    .aclk       (aclk),
    .aresetn    (aresetn)
);

// Tie off unused interfaces
always_comb notify.tie_off_m();
always_comb sq_rd.tie_off_m();
always_comb sq_wr.tie_off_m();
always_comb cq_rd.tie_off_s();
always_comb cq_wr.tie_off_s();
always_comb axi_ctrl.tie_off_s();
