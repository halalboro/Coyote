/**
 * ALIGN pattern property check.
 *
 * The pattern is load-bearing and cannot be picked by eye:
 *   1. UNIQUE ROTATION -- if any non-zero cyclic shift equals the pattern, the
 *      aligner locks at the wrong bit offset and every received word is rotated.
 *      This failure looks exactly like a dead link and is very expensive to
 *      diagnose on hardware.
 *   2. DC BALANCED -- 16 ones, so a long idle does not drift AC coupling.
 *   3. TRANSITION RICH -- no run longer than 4, so the CDR holds through idle.
 */
`timescale 1ns/1ps
module tb_qlink_align;
    localparam logic [31:0] W_ALIGN = 32'h5C3D_2A96;

    function automatic logic [31:0] rotl(input logic [31:0] v, input int n);
        return (v << n) | (v >> (32 - n));
    endfunction

    initial begin
        int ones = 0, maxrun = 0, run = 1, collisions = 0;
        int trailing_run, leading_run, wrap_run;
        logic last;

        for (int i = 0; i < 32; i++) if (W_ALIGN[i]) ones++;

        last = W_ALIGN[0];
        for (int i = 1; i < 32; i++) begin
            if (W_ALIGN[i] === last) run++; else run = 1;
            last = W_ALIGN[i];
            if (run > maxrun) maxrun = run;
        end

        // Check wrap-around: bits 31 and 0 are adjacent in the circular stream
        if (W_ALIGN[31] === W_ALIGN[0]) begin
            trailing_run = 1;  // Start with bit 31
            for (int i = 30; i >= 0 && W_ALIGN[i] === W_ALIGN[31]; i--)
                trailing_run++;

            // Check if all bits are the same (degenerate case)
            if (trailing_run == 32) begin
                maxrun = 32;
            end else begin
                leading_run = 1;  // Start with bit 0
                for (int i = 1; i < 32 && W_ALIGN[i] === W_ALIGN[0]; i++)
                    leading_run++;

                wrap_run = trailing_run + leading_run;
                if (wrap_run > maxrun) maxrun = wrap_run;
            end
        end

        for (int n = 1; n < 32; n++)
            if (rotl(W_ALIGN, n) === W_ALIGN) collisions++;

        $display("\n=== ALIGN pattern %08x ===", W_ALIGN);
        $display("  ones=%0d/32   longest run=%0d   self-rotations=%0d", ones, maxrun, collisions);
        if (ones == 16 && maxrun <= 4 && collisions == 0)
            $display("  PASS: balanced, transition-rich, unambiguous");
        else
            $display("  *** FAIL: pick a different pattern ***");
        $finish;
    end
endmodule
