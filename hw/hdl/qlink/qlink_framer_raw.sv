/**
 * QLINK framer — RAW mode
 *
 * Replaces qlink_framer. The GT no longer does 8B/10B or gearboxing, which is
 * the entire point: measured on hardware, the PCS was 23.8 ns of a 31.8 ns
 * transceiver, against 8.0 ns for the PMA.
 *
 * Three jobs the PCS used to do now live here:
 *   WORD ALIGNMENT   pulse rxslide until the received word matches W_ALIGN
 *   DC BALANCE       scramble everything except ALIGN itself
 *   FRAMING          ALIGN when idle; a frame is the first non-ALIGN word
 *
 * WIRE PROTOCOL
 *   idle    ALIGN ALIGN ALIGN ...        unscrambled
 *   frame   HDR PAY..PAY TRAILER         scrambled
 * Word count is identical to the 8B/10B version, so framing adds no latency.
 * Frame length comes from HDR, so a payload word that happens to scramble to
 * ALIGN is harmless -- it is just payload. The only hazard is HDR itself
 * scrambling to ALIGN, which loses one frame with probability 2^-32: about one
 * round per 72 minutes at a 1 us cadence, and it is counted as a gap.
 *
 * TWO CLOCK DOMAINS, as before: TX on the local transmit clock, RX on the
 * recovered clock, sharing no state.
 */
module qlink_framer_raw #(
    parameter logic [31:0] W_ALIGN = 32'h5C3D_2A96,
    // rxslide must be held low for at least 32 RXUSRCLK cycles between pulses
    // (UG578). 64 is comfortable and costs only startup time.
    parameter int SLIDE_WAIT = 64,
    // Consecutive ALIGN words needed to declare alignment good.
    parameter int LOCK_COUNT = 32,
    // Consecutive words WITHOUT a single ALIGN before alignment is given up and
    // re-hunted (see the A_LOCKED case). 16384 words is ~42 us at 390.625 MHz.
    //
    // The floor on this value is the longest gapless burst of frames the link
    // can legitimately carry, since a burst emits no ALIGN words either. 16384
    // cycles is about 2730 back-to-back 6-cycle frames, which no real workload
    // approaches -- QEC rounds are ~1 us apart and a frame is 6 cycles, so the
    // line is idle over 99% of the time. Lower it in simulation to keep the
    // recovery test short.
    parameter int LOSS_COUNT = 16384
) (
    // ---- TX domain ----
    input  logic          clk_tx,
    input  logic          rstn_tx,
    input  logic          link_up_tx,
    input  logic [31:0]   phy_tx_data,
    input  logic          phy_tx_valid,
    input  logic          phy_tx_last,
    output logic          phy_tx_ready,
    input  logic [23:0]   phy_tx_hdr,
    input  logic [23:0]   phy_tx_cks,
    input  logic [1:0]    phy_tx_type,
    output logic [31:0]   gt_txdata,

    // ---- RX domain ----
    input  logic          clk_rx,
    input  logic          rstn_rx,
    input  logic          link_up_rx,
    output logic [31:0]   phy_rx_data,
    output logic          phy_rx_valid,
    output logic          phy_rx_eof,
    output logic          phy_rx_err,
    output logic [23:0]   phy_rx_hdr,
    output logic          phy_rx_sof,
    output logic [1:0]    phy_rx_type,
    output logic [23:0]   phy_rx_cks,
    input  logic [31:0]   gt_rxdata,
    output logic          rxslide,
    output logic          rx_aligned,
    // Idle is a known pattern and the link is idle >98% of the time, so every
    // bit error during idle is detectable. This is a continuous BER monitor and
    // it is strictly better than the 8B/10B flags it replaces.
    output logic [15:0]   ber_count,
    output logic [1:0]    dbg
);

    // ================================================================ TX
    // FIX (round 3): no registered T_HDR stage. qlink_framer (8B/10B) emits
    // its marker COMBINATIONALLY in T_IDLE, on the same cycle phy_tx_valid is
    // first seen, and moves straight to T_DATA -- it never spends a cycle
    // "in" the header. Reinstating a separate registered header state here
    // cost +1 cycle end to end versus that baseline (measured: +2 cycles /
    // +5.1 ns total together with the RX-side fix below), silently giving
    // back a chunk of the latency raw mode exists to save. Only the FSM state
    // remains registered; the header, like the trailer, is emitted
    // combinationally.
    typedef enum logic [1:0] { T_IDLE, T_DATA, T_EOF } tx_e;
    tx_e tx_state;

    logic [57:0] scr_state, scr_state_n;
    logic [31:0] scr_in, scr_out;

    qlink_scrambler #(.INVERT(0)) u_scr (
        .d_in(scr_in), .state_in(scr_state),
        .d_out(scr_out), .state_out(scr_state_n));

    // gt_txdata needs scr_out's VALUE combinationally, this same cycle, for
    // every word (header, payload, trailer). u_scr is a separate module
    // instance, so in event-driven simulation scr_out only becomes visible
    // one extra simulation delta after whatever changed scr_in or scr_state
    // (the same submodule-instance-boundary delay explained in detail at
    // rx_word_fast below, on the RX side). For the header this delay is
    // invisible because scr_state sits at a constant '1 throughout idle and
    // scr_in is the constant header fields, so scr_out is already settled
    // long before phy_tx_valid changes. It is NOT invisible for the payload
    // or trailer: scr_in tracks phy_tx_data (changing every cycle) and, for
    // the trailer specifically, scr_state itself just updated at the T_DATA
    // -> T_EOF edge -- so u_scr must freshly compute scr_out for the new
    // state, and a strobe/data pair on the RX side that is otherwise race-
    // free (phy_rx_eof, zero-hop from rx_state; phy_rx_cks, now zero-extra-
    // hop via rx_word_fast) would still visibly disagree by one delta, this
    // time because the WIRE VALUE itself (gt_txdata/gt_rxdata) hadn't
    // finished settling, not because of anything on the RX side. tx_word_fast
    // is the same closed-form substitute as rx_word_fast, applied here for
    // the same reason: qlink_scrambler's transform is scr_in XORed with a
    // mask that depends on scr_state alone (see the derivation at
    // rx_word_fast), so it needs no wait on u_scr's own process. u_scr stays
    // instantiated and still does the real, load-bearing work: computing
    // scr_state_n so the always_ff below can advance scr_state for the next
    // word.
    // Deliberately ONE always_comb, not a mask signal computed by one block
    // and XORed with scr_in by a second (assign) statement. Two chained
    // processes are, again, two hops: the mask's own block would need to
    // react to scr_state before tx_word_fast's block could react to the
    // mask. Folding both into a single process means the whole expression
    // recomputes -- and settles -- in one reaction to either operand
    // changing, scr_state included. This is exactly what bit the trailer
    // initially: scr_state genuinely changes at the T_DATA -> T_EOF edge
    // (unlike the header, where it sits unchanging at '1 through all of
    // idle), so a split mask/XOR pair still cost the extra hop there.
    logic [31:0] tx_word_fast;
    always_comb
        for (int i = 0; i < 32; i++)
            tx_word_fast[i] = scr_in[i] ^ scr_state[57-i] ^ scr_state[38-i];

    // What this cycle puts on the wire, before scrambling. In T_IDLE, scr_in
    // is only actually used when a frame is starting this cycle (see the
    // gt_txdata mux below); otherwise it is don't-care and gt_txdata picks
    // W_ALIGN instead. The header is scrambled with scr_state == '1 -- the
    // value it is forced to throughout idle (see the always_ff below) --
    // which is exactly the state RX expects to descramble it with.
    always_comb begin
        case (tx_state)
            T_IDLE:  scr_in = {phy_tx_hdr, 6'b0, phy_tx_type};
            T_DATA:  scr_in = phy_tx_valid ? phy_tx_data : 32'h0;
            T_EOF:   scr_in = {phy_tx_cks, 8'h00};
            default: scr_in = 32'h0;
        endcase
    end

    // ALIGN goes out UNSCRAMBLED. It has to be recognisable by a receiver that
    // has not yet locked, and a receiver that has not locked cannot descramble.
    // T_IDLE emits the scrambled header the instant phy_tx_valid is seen
    // (mirroring qlink_framer's w_marker mux), not one cycle later.
    always_comb begin
        case (tx_state)
            T_IDLE:  gt_txdata = (rstn_tx && link_up_tx && phy_tx_valid) ? tx_word_fast : W_ALIGN;
            T_DATA:  gt_txdata = phy_tx_valid ? tx_word_fast : W_ALIGN;
            default: gt_txdata = tx_word_fast;
        endcase
    end

    always_ff @(posedge clk_tx) begin
        if (!rstn_tx) begin
            tx_state  <= T_IDLE;
            scr_state <= '1;
        end else begin
            // The scrambler only advances on words it actually produced. ALIGN
            // is not scrambled, so idle must not disturb the state -- otherwise
            // the two ends' scramblers diverge across every idle gap.
            //
            // FIX 2: while idle, scr_state is actively held AT '1, not merely
            // left undisturbed. Holding it at whatever value it last reached
            // (the state after the previous frame's trailer) would mean every
            // frame after the first starts its header scrambled from a
            // different state than RX expects (RX resets to '1 on lock and on
            // every idle word -- see below), corrupting every header. Forcing
            // '1 every idle cycle on both ends makes frame-start state
            // synchrony unconditional: true at cold start, after re-lock, and
            // after any number of prior frames, with no handshake needed.
            //
            // FIX (round 3): T_IDLE now splits in two. If a frame is starting
            // this cycle (link_up_tx && phy_tx_valid), the header was just
            // scrambled combinationally from '1 above, so state must advance
            // to scr_state_n to account for having sent it -- exactly like
            // T_HDR used to, just without spending a separate cycle there.
            // Otherwise this is a genuinely idle cycle (ALIGN went out) and
            // state is forced to '1, as before.
            if (tx_state == T_IDLE) begin
                if (link_up_tx && phy_tx_valid)
                    scr_state <= scr_state_n;
                else
                    scr_state <= '1;
            end else if (!(tx_state == T_DATA && !phy_tx_valid))
                scr_state <= scr_state_n;

            case (tx_state)
                T_IDLE: if (link_up_tx && phy_tx_valid) tx_state <= T_DATA;
                T_DATA: if (phy_tx_valid && phy_tx_last) tx_state <= T_EOF;
                T_EOF:  tx_state <= T_IDLE;
                default: tx_state <= T_IDLE;
            endcase
        end
    end

    // The header occupies its own wire slot, exactly as the 8B/10B marker did,
    // so payload starts on the same cycle it does today.
    assign phy_tx_ready = (tx_state == T_DATA);

    // synthesis translate_off
    // UNREACHABLE by construction: qlink_link_tx holds phy_tx_valid high for a
    // whole frame, because phy_tx_ready is asserted throughout T_DATA. If this
    // ever fires, the invariant below has been broken and the link WILL
    // desynchronise on hardware in a way that looks like random corruption.
    always_ff @(posedge clk_tx)
        if (rstn_tx && tx_state == T_DATA && !phy_tx_valid)
            $error("qlink_framer_raw: mid-frame bubble on phy_tx_valid. The RX has no matching skip, so the scramblers will diverge permanently. See the scrambler-state invariant comment.");
    // synthesis translate_on

    // ================================================================ RX
    logic [57:0] des_state, des_state_n;
    logic [31:0] des_out;

    qlink_scrambler #(.INVERT(1)) u_des (
        .d_in(gt_rxdata), .state_in(des_state),
        .d_out(des_out), .state_out(des_state_n));

    wire rx_is_align = (gt_rxdata == W_ALIGN);

    // ---- frame reception state, declared here (not lower in the file) so the
    // alignment FSM below can reference rx_state before its always_ff block.
    // An undeclared identifier here would silently become an undriven 1-bit
    // wire that reads as zero and synthesises cleanly -- this project has
    // shipped that exact bug twice before (echo_mode, lb_q), so it is not left
    // to Verilog's implicit-net rule.
    typedef enum logic [1:0] { R_IDLE, R_HDR, R_PAY, R_TRAIL } rx_e;
    rx_e        rx_state;
    logic [7:0] rx_left;

    // des_out is registered-state-driven but computed by a SEPARATE module
    // instance (u_des): in event-driven simulation, a signal reaching
    // downstream logic THROUGH a submodule's own combinational process
    // settles one simulation delta later than a signal computed directly
    // from a top-level continuous assign, even within the same timestep and
    // even though both react to the same root event (gt_rxdata changing).
    // rx_is_align and rx_state (direct assign / plain register) are such
    // "fast" signals; des_out (through u_des) is "slow" by exactly that one
    // hop. A strobe gated on a fast signal alone becomes visible to any
    // delta-sensitive observer (a testbench `wait()`, not a clocked register
    // -- real synchronous logic only ever samples after the whole timestep
    // settles, so this never matters in hardware) one delta before its
    // paired data value, if that value comes from des_out, has caught up.
    // Registering just the trailer's strobe/data pair to dodge this is NOT
    // safe here: qlink_link_rx (`if (phy_rx_sof) ... else if (phy_rx_eof)
    // ...`) assumes sof and eof are both zero-hop, so for a back-to-back
    // frame (trailer word immediately followed by the next header, no idle
    // gap) a one-cycle-late eof lands on the SAME cycle as the next frame's
    // sof and is silently dropped by that if/else-if -- confirmed by
    // deliberately trying it: tb_qlink's back-to-back-frames test broke.
    //
    // The actual fix is a closed-form, zero-extra-hop equivalent for des_out
    // itself, derived from qlink_scrambler's own structure. Inside its loop,
    // at iteration i the feedback bit read is s[57] ^ s[38] using s AS OF i
    // prior shifts; since positions 57 and 38 are both >= 31 they are NEVER
    // among the low bits a 32-bit word's worth of shifting touches, so at
    // iteration i, s[57] == state_in[57-i] and s[38] == state_in[38-i] --
    // ALWAYS, for any state_in, regardless of d_in or INVERT (INVERT only
    // selects what gets shifted IN afterward, which this never reads). So
    // qlink_scrambler's output is exactly d_in[i] ^ (state_in[57-i] ^
    // state_in[38-i]) for every bit i -- an XOR with a mask that depends on
    // state_in ALONE. des_state is a plain register (zero-hop, exactly as
    // fast as rx_is_align/rx_state), so this mask, and hence this whole
    // expression, needs no wait on u_des's own process to react to the
    // current gt_rxdata. It is not an approximation valid only near '1 (that
    // was an earlier, narrower version of this fix) -- it is the exact same
    // function qlink_scrambler computes, for every state, every word, every
    // rx_state. u_des itself is still instantiated and still does the real
    // work this framer actually depends on: advancing des_state/des_state_n
    // for the next word, which DOES need the full bit-by-bit chain.
    //
    // Deliberately ONE always_comb, not a mask signal computed by one block
    // and XORed with gt_rxdata by a second (assign) statement -- the same
    // reasoning as tx_word_fast above applies here too, and for the same
    // reason it mattered there: des_state genuinely changes at the last
    // R_PAY cycle -> R_TRAIL edge (advancing through the payload), so a
    // split mask/XOR pair would still cost an extra hop for the trailer
    // specifically, even though the header (where des_state sits unchanging
    // at '1 through idle) would not have shown it.
    // FIX (round 3): RX output datapath is COMBINATIONAL, driven from
    // rx_word_fast and the REGISTERED rx_state -- mirroring exactly how
    // qlink_framer (8B/10B) drives phy_rx_data/hdr/cks/type/sof/eof/valid
    // from gt_rxdata and the registered in_frame/rx_is_sof/rx_is_eof. Only
    // rx_state, rx_left, des_state, the alignment FSM and the counters stay
    // registered below. Reinstating a clocked output stage here cost the
    // other +1 cycle of the +2 cycle / +5.1 ns regression found by the
    // downstream latency test versus the 8B/10B baseline.
    //
    // On the cycle rx_state == R_IDLE and the current word is not ALIGN,
    // that word IS the header -- decided combinationally, the same cycle it
    // is on the wire, not the cycle after. Likewise the trailer is decided
    // the cycle rx_state == R_TRAIL, and payload the cycles rx_state ==
    // R_PAY. phy_rx_hdr/phy_rx_cks/phy_rx_type carry meaning only on the
    // cycle their matching strobe (phy_rx_sof / phy_rx_eof) is asserted, same
    // convention as qlink_framer.
    //
    logic [31:0] rx_word_fast;
    always_comb
        for (int i = 0; i < 32; i++)
            rx_word_fast[i] = gt_rxdata[i] ^ des_state[57-i] ^ des_state[38-i];

    // A corrupted header can decode to n_words == 0 (FIX 5, round 2): treated
    // as a bad frame everywhere it matters, including here in the
    // combinational sof strobe below, so a dropped bad header never produces
    // a stray start-of-frame.
    wire rx_hdr_bad = (rx_word_fast[15:8] == 8'd0);

    assign phy_rx_data  = rx_word_fast;
    assign phy_rx_hdr   = rx_word_fast[31:8];
    assign phy_rx_cks   = rx_word_fast[31:8];
    assign phy_rx_type  = rx_word_fast[1:0];
    assign phy_rx_valid = rstn_rx && link_up_rx && rx_aligned && (rx_state == R_PAY);
    assign phy_rx_sof   = rstn_rx && link_up_rx && rx_aligned && (rx_state == R_IDLE) && !rx_is_align && !rx_hdr_bad;
    // phy_rx_eof does NOT genuinely need rx_word_fast -- unlike the header,
    // the trailer is located by COUNT (rx_left reaching zero, folded into
    // rx_state reaching R_TRAIL), not by CONTENT, so its correctness never
    // depended on gt_rxdata in the first place. That asymmetry is protocol-
    // level, not an implementation gap: it is the one pairing this fix
    // cannot make atomic with its data (phy_rx_cks) purely combinationally
    // -- see the report for the full account of why, and why phy_rx_eof
    // must stay exactly this fast regardless (qlink_link_rx's
    // `if (phy_rx_sof) ... else if (phy_rx_eof) ...` requires it for
    // back-to-back frames; delaying it breaks that instead).
    assign phy_rx_eof   = rstn_rx && link_up_rx && rx_aligned && (rx_state == R_TRAIL);
    // Raw mode has no per-word error indication -- that is exactly what
    // 8B/10B's control-character/disparity checks gave up when the GT
    // switched to raw (FIX 4, round 2). Tied permanently low rather than
    // inventing a signal; the frame checksum in qlink_link_rx is the
    // per-frame integrity check that replaces it, and ber_count below is the
    // continuous line-quality monitor that replaces the 8B/10B
    // not-in-table/disparity flags.
    assign phy_rx_err   = 1'b0;

    // FIX 1/3: a non-ALIGN word seen while idle is indistinguishable, at that
    // instant, from the first word of a genuine frame -- a healthy frame
    // start looks exactly like a one-word idle corruption until the NEXT
    // word arrives. This one-deep history flag defers the call by a cycle:
    // it is set when the previous cycle saw a non-ALIGN word while idle, and
    // both ber_count (below) and al_good in the A_LOCKED case use it, rather
    // than the raw one-cycle condition, to decide "that was a bit error, not
    // a frame." A real frame moves R_IDLE -> R_PAY and does not return to
    // R_IDLE until its trailer, so it never confirms the flag; only a
    // genuine one-word glitch (idle -> non-ALIGN -> idle again) does. Driven
    // in the frame-reception always_ff below; read here (registered value,
    // same clk_rx domain) by the alignment FSM's A_LOCKED case.
    logic idle_glitch_pending;

    // ---- alignment FSM: pulse rxslide until ALIGN appears ----
    typedef enum logic [1:0] { A_HUNT, A_WAIT, A_LOCKED } al_e;
    al_e         al_state;
    logic [7:0]  al_wait;
    logic [7:0]  al_good;
    // Words seen since the last ALIGN, while locked. 16 bits because the
    // threshold must exceed the longest legitimate gapless frame burst.
    logic [15:0] al_lost;

    always_ff @(posedge clk_rx) begin
        if (!rstn_rx) begin
            al_state   <= A_HUNT;
            al_wait    <= '0;
            al_good    <= '0;
            al_lost    <= '0;
            rxslide    <= 1'b0;
            rx_aligned <= 1'b0;
        end else begin
            rxslide <= 1'b0;
            case (al_state)
                A_HUNT: begin
                    if (rx_is_align) begin
                        if (al_good == LOCK_COUNT[7:0]) begin
                            al_state   <= A_LOCKED;
                            rx_aligned <= 1'b1;
                            al_lost    <= '0;   // enter locked with a clean slate
                        end else begin
                            al_good <= al_good + 8'd1;
                        end
                    end else begin
                        // Not ALIGN and not locked: shift by one bit and wait.
                        al_good  <= '0;
                        rxslide  <= 1'b1;
                        al_wait  <= SLIDE_WAIT[7:0];
                        al_state <= A_WAIT;
                    end
                end
                A_WAIT: begin
                    // UG578 (RXSLIDE port description): "RXSLIDE must be
                    // asserted for a minimum pulse width of two RXUSRCLK2
                    // cycles. RXSLIDE must be deasserted for more than 32
                    // RXUSRCLK2 cycles before it can be reasserted." A_HUNT
                    // drove it high for cycle 1; this re-drives it for cycle 2,
                    // after which the blanket clear at the top of the else
                    // takes it low. A ONE-cycle pulse is silently ignored by
                    // the PCS -- the aligner would appear to hunt forever and
                    // present exactly as a dead cable.
                    //
                    // The v1.3 attribute table still says "one RXUSRCLK2
                    // cycle"; that is the stale copy. The v1.3 revision history
                    // records "Extended RXSLIDE pulse width to cover two
                    // RXUSRCLK2 cycles" against the timing figures, which is
                    // the corrected text. Two cycles satisfies both readings.
                    if (al_wait == SLIDE_WAIT[7:0]) rxslide <= 1'b1;

                    if (al_wait == 8'd0) al_state <= A_HUNT;
                    else                 al_wait  <= al_wait - 8'd1;
                end
                A_LOCKED: begin
                    // LOSS OF ALIGNMENT. This must trip on the ABSENCE of
                    // ALIGN, never on its presence.
                    //
                    // The previous version counted (idle_glitch_pending &&
                    // rx_is_align) -- a confirmed ONE-WORD idle glitch -- and
                    // re-hunted after 255 of them. Both of its branches were
                    // gated on rx_is_align, and that is precisely backwards for
                    // the fault it names: when word alignment is actually lost,
                    // every received word is a ROTATION of W_ALIGN, and
                    // tb_qlink_align proves no non-zero rotation of 5C3D_2A96
                    // equals itself. So rx_is_align was stuck false, al_good
                    // never advanced, rx_aligned could never fall, and the
                    // detector was blind to the only thing it existed to catch.
                    //
                    // What trips now: a word that is definitively NOT a valid
                    // idle word and NOT a valid frame start -- non-ALIGN while
                    // R_IDLE, carrying a header whose n_words is 0. A
                    // legitimate frame start always carries n_words in 1..31
                    // (qlink_link_tx never emits an empty frame, and the R_IDLE
                    // case below already drops n_words == 0 as a bad header), so
                    // real traffic NEVER increments this -- not even 255
                    // back-to-back frames with no idle gap, which is the exact
                    // false-teardown the old comment was written to avoid.
                    // Misaligned garbage hits n_words == 0 about 1 word in 256,
                    // so the counter saturates in ~65k words (~168 us at
                    // 390.625 MHz) and re-hunts. Slower than a bring-up hunt,
                    // which is right: this is a fault path, not the fast path.
                    //
    // What trips now: a sustained run of words with NOT ONE ALIGN among
                    // them. A single ALIGN clears the counter outright -- that
                    // is positive proof the byte boundary is still correct, and
                    // on a healthy link idle ALIGN words arrive constantly.
                    //
                    // This deliberately does NOT qualify on rx_state. An
                    // earlier attempt counted only R_IDLE words carrying a
                    // zero n_words, reasoning that legitimate frames could then
                    // never contribute. It was far too slow to be useful:
                    // misaligned garbage decodes to a NON-zero n_words 255
                    // times out of 256, and each of those drags the receiver
                    // into R_PAY for up to 255 words, so the counter advanced
                    // roughly once per 32k words instead of once per word.
                    // Recovery would have taken milliseconds. Test 3 in
                    // tb_qlink_raw.sv caught that; it is the reason this
                    // counter is unconditional.
                    if (rx_is_align) begin
                        al_lost <= '0;
                    end else if (al_lost == LOSS_COUNT[15:0]) begin
                        al_state   <= A_HUNT;
                        rx_aligned <= 1'b0;
                        al_good    <= '0;
                        al_lost    <= '0;
                    end else begin
                        al_lost <= al_lost + 16'd1;
                    end
                end
            endcase
        end
    end

    // ---- frame reception ----
    // FIX (round 3): phy_rx_data/hdr/cks/type/valid/sof/eof/err moved out of
    // this always_ff entirely -- they are driven by the continuous assigns
    // above now (all now safe from the delta-race rx_word_fast eliminates,
    // header AND trailer alike), not registered here. Only the state that
    // genuinely needs to persist across cycles (rx_state, rx_left,
    // des_state, ber_count, idle_glitch_pending) remains.
    always_ff @(posedge clk_rx) begin
        if (!rstn_rx) begin
            rx_state     <= R_IDLE;
            des_state    <= '1;
            rx_left      <= '0;
            ber_count    <= '0;
            idle_glitch_pending <= 1'b0;
        end else begin
            // Mirror of the transmitter: the descrambler advances only on words
            // the scrambler produced, never on ALIGN.
            //
            // This check deliberately does NOT look at rx_is_align while
            // rx_state == R_PAY, even though a scrambled payload word can, by
            // pure chance, equal W_ALIGN (probability 2^-32 per word -- at
            // four payload words per 1 us round that is roughly one collision
            // every 18 minutes). Skipping such a word as if it were idle would
            // advance the TX scrambler (which produced and sent it as a real,
            // scrambled word) without advancing the RX descrambler to match --
            // a PERMANENT divergence between the two ends' states, breaking
            // every frame from that point on. So during R_PAY (and R_TRAIL)
            // every word is treated as real payload/trailer data and always
            // advances des_state, full stop, regardless of its value.
            //
            // What makes that safe rather than reckless: qlink_link_tx holds
            // phy_tx_valid high for the entire frame once it starts (this
            // framer asserts phy_tx_ready throughout T_DATA, so the upstream
            // FSM never stalls mid-frame), so the TX side never emits an
            // actual mid-frame ALIGN filler that would need a matching skip
            // here. The TX-side guard against a phy_tx_valid drop during
            // T_DATA is consequently unreachable under that contract (see the
            // simulation-only assertion after the TX always_ff block above) --
            // it exists only to fail loudly if that contract is ever broken,
            // not because RX is expected to mirror it during R_PAY/R_TRAIL.
            // Do not "fix" this asymmetry by adding an rx_is_align check here:
            // that would turn the common, harmless, 18-minute payload/ALIGN
            // coincidence into a permanent scrambler desync instead.
            //
            // FIX 2: while genuinely idle (R_IDLE and the word really is
            // ALIGN), des_state is actively forced to '1 every such cycle,
            // not merely left undisturbed. Merely holding it would let drift
            // accumulated during the rxslide hunt (below, des_state keeps
            // advancing on mis-rotated garbage while alignment isn't locked
            // yet) survive into the locked state, corrupting the first
            // header. Forcing '1 on every real idle word -- including the
            // LOCK_COUNT-long run counted before rx_aligned is even declared
            // -- self-corrects that drift with no handshake, and matches TX
            // now doing the same in its T_IDLE branch above.
            if (rx_state == R_IDLE && rx_is_align)
                des_state <= '1;
            else
                des_state <= des_state_n;

            // FIX 1/3: one-cycle-delayed view of "saw a non-ALIGN word while
            // idle." Combined with rx_is_align on the NEXT cycle (below, and
            // in the A_LOCKED case above) this turns the raw, ambiguous
            // per-cycle condition into "confirmed one-word glitch," which a
            // real frame (R_IDLE -> R_PAY, no return to R_IDLE until the
            // trailer) never triggers.
            idle_glitch_pending <= rx_aligned && (rx_state == R_IDLE) && !rx_is_align;

            if (!link_up_rx || !rx_aligned) begin
                rx_state <= R_IDLE;
            end else begin
                case (rx_state)
                    R_IDLE: begin
                        if (!rx_is_align) begin
                            // FIX 5: a corrupted header can decode to
                            // n_words == 0. Trusting it would load rx_left
                            // with 0, which underflows to 8'hFF on the very
                            // first R_PAY cycle (rx_left <= rx_left - 1) and
                            // floods 255 bogus phy_rx_valid words downstream.
                            // Treat n_words == 0 as a bad frame: drop it and
                            // stay in R_IDLE instead of entering R_PAY.
                            if (des_out[15:8] == 8'd0) begin
                                // Bad header -- do nothing, remain in R_IDLE.
                                // rx_hdr_bad (above) keeps phy_rx_sof from
                                // strobing for it.
                            end else begin
                                // First non-ALIGN word is the header. The
                                // combinational phy_rx_hdr/phy_rx_type/
                                // phy_rx_sof above already reflect it this
                                // same cycle; only the state that must
                                // persist into R_PAY is registered here.
                                rx_left  <= des_out[15:8];
                                rx_state <= R_PAY;
                            end
                        end
                    end
                    R_PAY: begin
                        rx_left <= rx_left - 8'd1;
                        if (rx_left == 8'd1) rx_state <= R_TRAIL;
                    end
                    R_TRAIL: begin
                        rx_state <= R_IDLE;
                    end
                    default: rx_state <= R_IDLE;
                endcase
            end

            // FIX 1: BER monitor, gated on the confirmed one-word glitch
            // (idle_glitch_pending && rx_is_align) rather than the raw
            // "non-ALIGN seen while idle" condition. The raw condition IS
            // the frame-start condition too, so a healthy link with regular
            // frames would have saturated this counter at 0xFFFF almost
            // immediately, making dbg[1] permanently (and falsely) report
            // errors. The residual false-count rate is 2^-32 per word (a
            // payload word that happens to equal W_ALIGN and is then
            // followed by real ALIGN) -- the same negligible rate the rest
            // of this design already tolerates elsewhere.
            if (idle_glitch_pending && rx_is_align && ber_count != 16'hFFFF)
                ber_count <= ber_count + 16'd1;
        end
    end

    assign dbg = {rx_aligned, (ber_count != 16'd0)};

endmodule
