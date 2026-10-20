/**
 * QLink round-number arithmetic — RFC-1982 serial-number comparator
 *
 * The ROUND field in a §3 frame is 32 bits. At 1 µs cadence it wraps every
 * ~71 minutes. Any consumer that reasons about "newer / older / behind by N"
 * must do so modularly: a plain unsigned compare across the wrap boundary
 * flips sign and makes a round that is one step ahead look billions of steps
 * behind, which would misfire every staleness check in the receiver.
 *
 * The classic trick is signed subtraction: $signed(a - b) is the shortest
 * signed distance from b to a on the 2^32 circle. Half-circle (gap = ±2^31)
 * is intrinsically ambiguous; this helper picks the convention that 2^31 is
 * "ahead" (round_gt true), matching RFC-1982 §3.2.
 *
 * All functions are pure combinational and synthesise to a single 32-bit
 * subtract plus a sign-bit read.
 *
 * Phase B deliverable: helper only, no consumer wires it in yet. Phase D/E
 * use it for the fence check, slot-schedule staleness, and gap detection.
 */

package qlink_round_pkg;

    function automatic logic round_lt (input logic [31:0] a, input logic [31:0] b);
        return $signed(a - b) < 0;
    endfunction

    function automatic logic round_leq(input logic [31:0] a, input logic [31:0] b);
        return $signed(a - b) <= 0;
    endfunction

    function automatic logic round_gt (input logic [31:0] a, input logic [31:0] b);
        return $signed(a - b) > 0;
    endfunction

    function automatic logic round_geq(input logic [31:0] a, input logic [31:0] b);
        return $signed(a - b) >= 0;
    endfunction

    function automatic logic round_eq (input logic [31:0] a, input logic [31:0] b);
        return a == b;
    endfunction

    // Signed modular distance from b to a, in rounds. Positive = a ahead of b.
    // Range: [-2^31, 2^31 - 1]. Use as the staleness window: rx is stale if
    // round_gap(rx, cur) < -W for some policy-chosen W (R16).
    function automatic logic signed [31:0] round_gap(input logic [31:0] a,
                                                      input logic [31:0] b);
        return $signed(a - b);
    endfunction

endpackage
