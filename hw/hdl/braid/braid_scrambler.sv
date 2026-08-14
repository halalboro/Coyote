/**
 * BRAID scrambler — parallel self-synchronous, x^58 + x^39 + 1
 *
 * In RAW mode the GT does no line coding, so the fabric must guarantee two
 * things the 8B/10B PCS used to: enough transitions for the CDR to stay locked,
 * and rough DC balance for the AC-coupled channel.
 *
 * THIS IS NOT OPTIONAL FOR QEC. A syndrome is mostly zeros -- most stabilizers
 * do not fire -- so the unscrambled line would sit at DC through every idle
 * round and the receiver would lose lock. The pathological input is the COMMON
 * case here, not a corner case.
 *
 * SELF-SYNCHRONOUS (the polynomial feeds back from the CIPHERTEXT) so the two
 * ends never exchange state: the descrambler locks itself within 58 bits of
 * joining the stream. The cost is error multiplication -- one line error
 * produces three -- which is fine because the frame checksum catches it either
 * way, and 8B/10B's own error flags are gone regardless.
 *
 * Purely combinational, so it folds into an existing register stage and costs
 * no cycles. It is an XOR tree roughly 2-3 LUT levels deep at 32 bits.
 *
 * Same module both directions: INVERT=0 scrambles, INVERT=1 descrambles. The
 * only difference is which of input and output feeds the state.
 */
module braid_scrambler #(
    parameter bit INVERT = 0
) (
    input  logic [31:0] d_in,
    input  logic [57:0] state_in,
    output logic [31:0] d_out,
    output logic [57:0] state_out
);
    logic [57:0] s;
    logic [31:0] o;

    always_comb begin
        s = state_in;
        for (int i = 0; i < 32; i++) begin
            // x^58 + x^39 + 1
            automatic logic fb = s[57] ^ s[38];
            o[i] = d_in[i] ^ fb;
            // Self-synchronous: the shift register is fed by the CIPHERTEXT,
            // which is d_in on the descrambling side and o on the scrambling
            // side. Getting this backwards produces a scrambler that works in
            // simulation against itself and desynchronises on real hardware
            // the first time a bit error arrives.
            s = {s[56:0], INVERT ? d_in[i] : o[i]};
        end
    end

    assign d_out    = o;
    assign state_out = s;
endmodule
