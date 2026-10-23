/**
 * Coyote Example 13: Micro Blossom QEC Decoder
 *
 * Wraps the Micro Blossom (paper: Wu et al., "Micro Blossom") generated
 * Verilog as a vFPGA. Host PCIe writes/reads pass through:
 *
 *   axi_ctrl (AXI4-Lite, 64-bit data) ─► MicroBlossomBus.s0_* (AXI4-Lite, 64-bit)
 *
 * Micro Blossom uses a 23-bit address space (8 MiB); we take the low 23
 * bits of axi_ctrl's address. Both Micro Blossom clock domains (clk,
 * slow_clk) are tied to aclk because the .v was generated with
 * --clock-divide-by 1.
 *
 * Bus protocol matches: Coyote's axi_ctrl IS AXI4-Lite with 64-bit data,
 * so no protocol converter is needed. (We tried AXI4 with a protocol
 * converter first; the axi_protocol_converter IP isn't available for
 * Versal HBM. Switched to AxiLite4 bus type — clean direct connection.)
 *
 * Address remap (host CSR window is only 64 KiB):
 *   Coyote's per-vFPGA user-control window is 64 KiB, so the host (via
 *   getCSR/setCSR) can only generate axi_ctrl byte offsets 0x0000..0xFFFF.
 *   Micro Blossom's control regs (0x00..0x30) and 64-bit instruction port
 *   (0x1000) live inside that window, but its per-context readout block at
 *   0x2_0000 does not. We alias a free low window [0x8000,0x8080) onto the
 *   context-0 readout block [0x2_0000,0x2_0080) for BOTH reads and writes
 *   (set_maximum_growth and clear-grown are writes). All other offsets pass
 *   through unchanged. 0x8000 is clear of the control regs and the
 *   instruction page (0x1000..0x1FFF). Extend MB_ALIAS_SPAN by 128 B per
 *   extra context if more contexts are ever needed (mind the 64 KiB ceiling).
 */

// Alias context-0 readout block into the host-reachable 64 KiB CSR window.
//   host [0x8000,0x8080) -> MB [0x2_0000,0x2_0080)   (both read and write)
// Everything else (control regs 0x00..0x30, instruction port 0x1000) passes
// through unchanged. The MB readout decode then sees subAddress=addr[6:0] and
// contextId=addr[16:7], so 0x2_0000/+16/+32/+40 land as context 0, offset 0/16/
// 32/40 — exactly the clear-grown / maxGrowth / SingleReadout fields.
localparam logic [22:0] MB_ALIAS_BASE   = 23'h00_8000;
localparam logic [22:0] MB_READOUT_BASE = 23'h02_0000;
localparam logic [22:0] MB_ALIAS_SPAN   = 23'h00_0080; // one 128 B context block

logic [22:0] mb_awaddr_remapped;
logic [22:0] mb_araddr_remapped;

always_comb begin
    mb_awaddr_remapped = axi_ctrl.awaddr[22:0];
    if ((axi_ctrl.awaddr[22:0] >= MB_ALIAS_BASE) &&
        (axi_ctrl.awaddr[22:0] <  (MB_ALIAS_BASE + MB_ALIAS_SPAN)))
        mb_awaddr_remapped = MB_READOUT_BASE + (axi_ctrl.awaddr[22:0] - MB_ALIAS_BASE);
end

always_comb begin
    mb_araddr_remapped = axi_ctrl.araddr[22:0];
    if ((axi_ctrl.araddr[22:0] >= MB_ALIAS_BASE) &&
        (axi_ctrl.araddr[22:0] <  (MB_ALIAS_BASE + MB_ALIAS_SPAN)))
        mb_araddr_remapped = MB_READOUT_BASE + (axi_ctrl.araddr[22:0] - MB_ALIAS_BASE);
end

MicroBlossomBus inst_mb (
    // Both clock domains tied to aclk (generator was run with --clock-divide-by 1)
    .clk      (aclk),
    .slow_clk (aclk),
    // Micro Blossom uses active-high synchronous reset
    .reset    (~aresetn),

    // AXI4-Lite slave — low 23 bits of address, with the readout-block remap
    .s0_awaddr  (mb_awaddr_remapped),
    .s0_awprot  (axi_ctrl.awprot),
    .s0_awvalid (axi_ctrl.awvalid),
    .s0_awready (axi_ctrl.awready),

    .s0_wdata   (axi_ctrl.wdata),
    .s0_wstrb   (axi_ctrl.wstrb),
    .s0_wvalid  (axi_ctrl.wvalid),
    .s0_wready  (axi_ctrl.wready),

    .s0_bresp   (axi_ctrl.bresp),
    .s0_bvalid  (axi_ctrl.bvalid),
    .s0_bready  (axi_ctrl.bready),

    .s0_araddr  (mb_araddr_remapped),
    .s0_arprot  (axi_ctrl.arprot),
    .s0_arvalid (axi_ctrl.arvalid),
    .s0_arready (axi_ctrl.arready),

    .s0_rdata   (axi_ctrl.rdata),
    .s0_rresp   (axi_ctrl.rresp),
    .s0_rvalid  (axi_ctrl.rvalid),
    .s0_rready  (axi_ctrl.rready)
);

// Tie off unused Coyote interfaces — first iteration is host-control-only.
always_comb axis_host_recv[0].tie_off_s();
always_comb axis_host_send[0].tie_off_m();
always_comb notify.tie_off_m();
always_comb sq_rd.tie_off_m();
always_comb sq_wr.tie_off_m();
always_comb cq_rd.tie_off_s();
always_comb cq_wr.tie_off_s();
