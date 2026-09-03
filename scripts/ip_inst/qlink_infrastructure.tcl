##############################################################################
## QLINK — shell-level IP generation
##
## Gated by cfg(en_qlink_gty). Consumed by hw/hdl/qlink/qlink_gty_wrapper.sv.
##
## One GTY lane, 12.5 Gbps, RAW encoding (no 8B/10B, no comma detector, no
## 64B/66B gearbox), 32-bit user datapath at 390.625 MHz, 156.25 MHz
## reference, TX and RX buffers bypassed.
##
## WHY RAW AT 12.5 AND NOT 8B/10B AT 15.625 (the previous configuration).
## Measured on hardware: the GT's own PCS -- the block that does 8B/10B and
## comma detection -- was 23.8 ns of a 31.8 ns transceiver, against 8.0 ns for
## the PMA alone. Raw mode drops the PCS entirely; word alignment, DC balance
## and framing move into qlink_framer_raw (hw/hdl/qlink) instead.
##
## 12.5 Gbps / 32-bit user width lands on the SAME 390.625 MHz TXPROGDIV_FREQ
## fabric clock the 8B/10B configuration used. The reference MULTIPLIER differs
## (156.25 x 80 here, x 100 for 8B/10B); what matches is the word rate, because
## 8B/10B put 40 bits on the wire per 32-bit word and raw puts 32:
##     12.5e9 / 32 = 390.625 MHz     15.625e9 / 40 = 390.625 MHz
## User throughput is identical too (12.5 Gbps both ways) -- the 25% rate drop
## is exactly the 8B/10B line overhead that raw mode no longer pays. So the
## design closes timing exactly as it did before --
## nothing downstream of the GT needed to change clock. This configuration was
## probed and confirmed accepted by the wizard.
##
## RX_COMMA_ALIGN_WORD STAYS AT 4, IN RAW MODE TOO. It is NOT an 8B/10B
## property, and an earlier revision of this file was wrong to say the
## RX_COMMA_* properties are rejected in raw mode -- all five are accepted
## (verified by generating the IP with this exact dict). ALIGN_WORD is the one
## that must be set, because in RXSLIDE_MODE=PCS it also sets the SLIDE SPAN:
##
##   UG578 "Manual Alignment": "a maximum of 40 bits of sliding is possible when
##   RX_INT_DATAWIDTH = 1 (4-byte) and ALIGN_COMMA_WORD = 4" -- the slide
##   position wraps back to 0 after ALIGN_COMMA_WORD x bits-per-character.
##
## In raw mode the character is a byte, so the wizard default of 1 gives an
## 8-position slide window on a 32-bit word. qlink_framer_raw's hunt FSM walks
## one bit at a time expecting to sweep all 32 (tb_qlink_raw proves convergence
## from all 32 offsets, but against a testbench wire with a full 32-bit wrap,
## which silicon would not have). With the default the deserialiser starts on an
## arbitrary one of 32 phases and 24 of them are unreachable: rxslide cycles
## through the same 8 forever, rx_aligned never asserts, link_up never rises.
## Cold boot to cold boot that presents as an INTERMITTENTLY dead cable -- works
## once, dead three times -- which is the most expensive symptom there is.
##
## Do NOT also add RX_COMMA_P_ENABLE/M_ENABLE. UG578 requires
## RXPCOMMAALIGNEN=0 and RXMCOMMAALIGNEN=0 for RXSLIDE to work, and the wizard
## already resolves them to 0; enabling them would break manual alignment.
## Setting ALIGN_WORD alone leaves comma DETECTION off, as raw mode requires.
##
## Word alignment in raw mode otherwise comes from pulsing RXSLIDE_IN under
## fabric control (RX_SLIDE_MODE PCS), which is why rxslide_in must be in
## ENABLE_OPTIONAL_PORTS.
##############################################################################

if {$cfg(en_qlink_gty) eq 1} {

    if {$cfg(fdev) eq "u280"} {
        ## VERIFIED against Vivado 2025.1 / gtwizard_ultrascale:1.7 on a GTYE4
        ## part: this dict was applied and generate_target completed.
        ##
        ## KEEP THIS AS ONE set_property -dict. Setting these individually
        ## FAILS -- the wizard validates each property against a half-configured
        ## state and rejects e.g. TX_REFCLK_FREQUENCY 156.25 with a bare
        ## "failed due to earlier errors". Confirmed experimentally: 156.25,
        ## 161.1328125, 257.8125 and 322.265625 were each rejected on their own,
        ## then all accepted together in a dict. Do not split this up.
        create_ip -name gtwizard_ultrascale -vendor xilinx.com -library ip \
            -module_name qlink_gty

        ## RX_BUFFER_MODE 0 bypasses the RX elastic buffer, which is the largest
        ## single GT latency term. It does NOT require the two ends to share a
        ## reference clock: the buffer exists to bridge the recovered clock and
        ## whatever RXUSRCLK you choose, and in bypass RXUSRCLK is driven FROM
        ## RXOUTCLK, so it is locked to the incoming data by construction. The
        ## consequence is that RX fabric logic must run on the recovered clock --
        ## see qlink_phy_gty, where the framer's RX half is clocked separately
        ## from its TX half.
        ##
        ## RX_EQ_MODE=LPM: UG578 recommends LPM for channels with under 14 dB
        ## loss at Nyquist, and a 1-3 m QSFP28 DAC is well inside that. There is
        ## no documented latency claim for LPM -- it is here to be measured.
        ## REVERT TO AUTO if rx_errors moves at all; LPM adaptation is the only
        ## plausible cause and it is the speculative half of this change.
        ##
        ## RAW MODE (TX/RX_DATA_ENCODING RAW, TX/RX_INT_DATA_WIDTH 32). Raw
        ## drops the PCS's 8B/10B and comma-detect logic entirely, which is the
        ## whole latency win -- but it also means the GT no longer does word
        ## alignment, DC balance or framing at all; qlink_framer_raw
        ## (hw/hdl/qlink) now owns all three.
        ##
        ## INTERNAL WIDTH IS 32, NOT 16, and that is deliberate. AMD's fintech
        ## blog cites ~13 ns for a 16-bit internal datapath, which 8B/10B could
        ## not reach (internal width must be a multiple of 10 there, and the
        ## wizard only offered 40). Raw mode does expose 16 -- but it buys
        ## nothing here. The internal width must equal the user width or the GT
        ## inserts a gearbox, and a gearbox is exactly the buffering this whole
        ## change exists to delete. Holding int = user = 16 instead would put
        ## the fabric at 781.25 MHz, which this design does not close at. 32/32
        ## is the widest setting that keeps the gearbox out at 390.625 MHz.
        ##
        ## RX_SLIDE_MODE PCS + rxslide_in in ENABLE_OPTIONAL_PORTS: without a
        ## comma detector, word alignment is done by pulsing RXSLIDE_IN from
        ## fabric logic (qlink_framer_raw's alignment FSM) until the received
        ## word matches the framer's W_ALIGN pattern. PCS-domain sliding (as
        ## opposed to PMA) is what UG578 pairs with buffer-bypass raw mode.
        ##
        ## CHANNEL_ENABLE is PART-SPECIFIC and is the one value in this dict that
        ## did NOT carry over from the probe part (xcu55c accepts X0Y0; the U280
        ## does not). On xcu280 the valid set is X0Y40-X0Y47 and X1Y0-X1Y15.
        ## X0Y44 is the QSFP1 quad's lane 0 -- the same channel example 14's
        ## working build placed gt1_*[0] on, and what u280_shell_zqlink_1.xdc
        ## LOCs. If you retarget the board, this line must be revisited.
        set_property -dict [list \
            CONFIG.GT_TYPE              GTY \
            CONFIG.CHANNEL_ENABLE       X0Y44 \
            CONFIG.TX_MASTER_CHANNEL    X0Y44 \
            CONFIG.RX_MASTER_CHANNEL    X0Y44 \
            CONFIG.TX_LINE_RATE         12.5 \
            CONFIG.RX_LINE_RATE         12.5 \
            CONFIG.TX_REFCLK_FREQUENCY  156.25 \
            CONFIG.RX_REFCLK_FREQUENCY  156.25 \
            CONFIG.TX_DATA_ENCODING     RAW \
            CONFIG.RX_DATA_DECODING     RAW \
            CONFIG.TX_INT_DATA_WIDTH    32 \
            CONFIG.RX_INT_DATA_WIDTH    32 \
            CONFIG.TX_USER_DATA_WIDTH   32 \
            CONFIG.RX_USER_DATA_WIDTH   32 \
            CONFIG.TX_BUFFER_MODE       0 \
            CONFIG.RX_BUFFER_MODE       0 \
            CONFIG.RX_BUFFER_BYPASS_MODE SINGLE \
            CONFIG.RX_SLIDE_MODE        PCS \
            CONFIG.RX_COMMA_ALIGN_WORD  4 \
            CONFIG.RX_EQ_MODE           LPM \
            CONFIG.FREERUN_FREQUENCY    100 \
            CONFIG.ENABLE_OPTIONAL_PORTS {rxslide_in loopback_in rxbufstatus_out} \
        ] [get_ips qlink_gty]
    }

    ## NO CDC FIFOs HERE ANY MORE.
    ##
    ## Two packet-mode axis_data_fifo instances used to bridge the GT user clock
    ## to aclk. They cost ~25 ns per crossing and there were four of them on a
    ## measured round trip, which made them the largest known term in the
    ## latency budget. The vFPGA now runs the protocol core on the GT clocks
    ## directly (qlink_gty_wrapper exports them), so nothing needs bridging.
    ##
    ## If you ever put them back, remember the lesson that cost three builds:
    ## packet mode holds a whole frame before releasing it, so FIFO_DEPTH must
    ## exceed 1 header + MAX_WORDS payload + 1 checksum. Depth 32 against a
    ## 34-word frame let short frames through and failed long ones with ~2
    ## errors each, which looks like a line-quality problem and is not.
}
