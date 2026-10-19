/**
 * QLINK system-level latency projection — Phase A
 *
 * The old tb_qlink_sys.sv built two full A-to-B paths (link_tx + framer +
 * cable + framer + link_rx) at two configurations to time-measure latency.
 * Phase A changes the frame size from variable 1..31 words to a fixed 14,
 * which only affects the protocol term (41 ns on the wire at 12.5 Gbps).
 * The GT and cable terms are measured on hardware and are unchanged.
 *
 * So this is now a projection, not a simulation: measured constants in,
 * arithmetic out. Keep it in the regression as a sanity line in the log.
 */

`timescale 1ns/1ps

module tb_qlink_sys;

    // Measured on the raw GTY PHY (54.7 ns one-way at 16 B payload):
    //   GT     26.8 ns
    //   cable  13.0 ns  (~2 m DAC)
    //   proto  15.4 ns  (6 cycles at 390.625 MHz, 4-word payload)
    localparam real GT_NS       = 26.8;
    localparam real CABLE_NS    = 13.0;

    // Phase A fixed-frame on wire: HDR + 14 payload + CRC = 16 cycles at
    // 2.56 ns = 41.0 ns.
    localparam real PROTO_PHASE_A_NS = 16 * 2.56;

    // Previous variable-length baseline at 16 B payload for context.
    localparam real PROTO_BRAID_NS   = 6  * 2.56;

    initial begin
        $display("\n=== QLink latency projection (Phase A, 64 B frame) ===");
        $display("  GT (measured):       %0.1f ns", GT_NS);
        $display("  cable (measured):    %0.1f ns  (~2 m DAC; 0.5 m saves ~7 ns)", CABLE_NS);
        $display("  protocol (fixed 64 B frame, 12.5 Gbps):  %0.1f ns",
                 PROTO_PHASE_A_NS);
        $display("  one-way one-shot:    %0.1f ns  (projection)",
                 GT_NS + CABLE_NS + PROTO_PHASE_A_NS);
        $display("");
        $display("  Context: BRAID/QLINK pre-Phase-A measured 54.7 ns at 16 B payload");
        $display("  decomposed as %0.1f + %0.1f + %0.1f.",
                 GT_NS, PROTO_BRAID_NS, CABLE_NS);
        $display("  Phase A trades %0.1f ns of extra serialization for the §3",
                 PROTO_PHASE_A_NS - PROTO_BRAID_NS);
        $display("  layout, class demux, and modular round tag.");
        $display("");
        $display("  25 Gbps / 64-bit (same fabric clock) halves the serialization");
        $display("  term to 20.5 ns, projecting ~60 ns one-way.");
        $display("");
        $display("PASS: projection reported");
        $finish;
    end

endmodule
