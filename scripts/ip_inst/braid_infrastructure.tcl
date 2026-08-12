##############################################################################
## BRAID — shell-level IP generation
##
## Gated by cfg(en_braid_gty). Consumed by hw/hdl/braid/braid_gty_wrapper.sv.
##
## One GTY lane, 15.625 Gbps, 8B/10B (no 64B/66B gearbox), 32-bit user
## datapath at 390.625 MHz, 156.25 MHz reference, TX and RX buffers bypassed.
##
## WHY 15.625 AND NOT MORE. 156.25 x 100. Probed exhaustively on GTYE4:
##   - GTY 8B/10B tops out at 16.375 Gbps. 17.5 and above are rejected.
##   - The line rate must be an exact integer multiple of the board reference,
##     which `braid clock` measured at 156.25 MHz (257.808 read against a
##     257.8125 prediction). x100 is the largest multiple under the ceiling.
##   - 25.78125 Gbps needs RAW encoding AND a 64-bit datapath AND a
##     161.1328125 MHz reference. Not reachable, and not worth it: raw buys
##     I=32 instead of 40 and no 25% line overhead, both 1.25x, both exactly
##     cancelled by needing a 1.25x lower rate to hold the same fabric clock.
##     8B/10B at 15.625 and raw at 12.5 both land on 79.9 ns predicted.
##
## RX_COMMA_ALIGN_WORD STAYS AT 4. It is the datapath width in BYTES, and the
## datapath is still 32 bits. Getting this wrong cost three build cycles.
##############################################################################

if {$cfg(en_braid_gty) eq 1} {

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
            -module_name braid_gty

        ## RX_BUFFER_MODE 0 bypasses the RX elastic buffer, which is the largest
        ## single GT latency term. It does NOT require the two ends to share a
        ## reference clock: the buffer exists to bridge the recovered clock and
        ## whatever RXUSRCLK you choose, and in bypass RXUSRCLK is driven FROM
        ## RXOUTCLK, so it is locked to the incoming data by construction. The
        ## consequence is that RX fabric logic must run on the recovered clock --
        ## see braid_phy_gty, where the framer's RX half is clocked separately
        ## from its TX half.
        ##
        ## SHOW_REALIGN_COMMA=FALSE is documented in UG578 as "This setting
        ## reduces RX datapath latency" -- the comma that caused a realignment is
        ## not brought out to the RX interface. braid_framer never inspects it,
        ## so this is free.
        ##
        ## RX_EQ_MODE=LPM: UG578 recommends LPM for channels with under 14 dB
        ## loss at Nyquist, and a 1-3 m QSFP28 DAC is well inside that. There is
        ## no documented latency claim for LPM -- it is here to be measured.
        ## REVERT TO AUTO if rx_errors moves at all; LPM adaptation is the only
        ## plausible cause and it is the speculative half of this change.
        ##
        ## NOT available to us, despite AMD's fintech blog citing ~13 ns for it:
        ## a 16-bit INTERNAL datapath. With 8B/10B the internal width must be a
        ## multiple of 10 and this wizard only offers 40 -- int=20 is rejected at
        ## every user width (verified). A narrow internal path implies raw mode,
        ## i.e. owning scrambling and frame sync.
        ##
        ## RX_COMMA_ALIGN_WORD is the comma alignment granularity in BYTES. The
        ## default of 1 lets the aligner drop the comma on ANY byte boundary --
        ## lane 0, 1, 2 or 3 of our 4-byte word. braid_phy_gty tests lane 0
        ## only, so with the default the K-character usually lands where it
        ## never looks and no SOF is ever detected: rx_frames=0 AND rx_errors=0,
        ## which reads as a dead link rather than a misconfiguration. 4 forces
        ## the comma onto the word boundary, i.e. always lane 0.
        ##
        ## CHANNEL_ENABLE is PART-SPECIFIC and is the one value in this dict that
        ## did NOT carry over from the probe part (xcu55c accepts X0Y0; the U280
        ## does not). On xcu280 the valid set is X0Y40-X0Y47 and X1Y0-X1Y15.
        ## X0Y44 is the QSFP1 quad's lane 0 -- the same channel example 14's
        ## working build placed gt1_*[0] on, and what u280_shell_zbraid_1.xdc
        ## LOCs. If you retarget the board, this line must be revisited.
        set_property -dict [list \
            CONFIG.GT_TYPE              GTY \
            CONFIG.CHANNEL_ENABLE       X0Y44 \
            CONFIG.TX_MASTER_CHANNEL    X0Y44 \
            CONFIG.RX_MASTER_CHANNEL    X0Y44 \
            CONFIG.TX_LINE_RATE         15.625 \
            CONFIG.RX_LINE_RATE         15.625 \
            CONFIG.TX_REFCLK_FREQUENCY  156.25 \
            CONFIG.RX_REFCLK_FREQUENCY  156.25 \
            CONFIG.TX_DATA_ENCODING     8B10B \
            CONFIG.RX_DATA_DECODING     8B10B \
            CONFIG.TX_USER_DATA_WIDTH   32 \
            CONFIG.RX_USER_DATA_WIDTH   32 \
            CONFIG.TX_BUFFER_MODE       0 \
            CONFIG.RX_BUFFER_MODE       0 \
            CONFIG.RX_BUFFER_BYPASS_MODE SINGLE \
            CONFIG.RX_COMMA_P_ENABLE    true \
            CONFIG.RX_COMMA_M_ENABLE    true \
            CONFIG.RX_COMMA_PRESET      K28.5 \
            CONFIG.RX_COMMA_ALIGN_WORD  4 \
            CONFIG.RX_COMMA_SHOW_REALIGN_ENABLE false \
            CONFIG.RX_EQ_MODE           LPM \
            CONFIG.FREERUN_FREQUENCY    100 \
            CONFIG.ENABLE_OPTIONAL_PORTS {loopback_in rxbufstatus_out} \
        ] [get_ips braid_gty]
    }

    ## NO CDC FIFOs HERE ANY MORE.
    ##
    ## Two packet-mode axis_data_fifo instances used to bridge the GT user clock
    ## to aclk. They cost ~25 ns per crossing and there were four of them on a
    ## measured round trip, which made them the largest known term in the
    ## latency budget. The vFPGA now runs the protocol core on the GT clocks
    ## directly (braid_gty_wrapper exports them), so nothing needs bridging.
    ##
    ## If you ever put them back, remember the lesson that cost three builds:
    ## packet mode holds a whole frame before releasing it, so FIFO_DEPTH must
    ## exceed 1 header + MAX_WORDS payload + 1 checksum. Depth 32 against a
    ## 34-word frame let short frames through and failed long ones with ~2
    ## errors each, which looks like a line-quality problem and is not.
}
