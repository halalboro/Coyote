# =============================================================================
# V80 SLR-aware vFPGA floorplan -- Phase 2 layout
# =============================================================================
# Use this floorplan ONLY if the static checkpoint has been rebuilt from the
# updated hw/constraints/v80/fplan/v80_static_floorplan.xdc (with the Strategy
# A narrow SLR1 corridor).
#
# If you are using the shipped routed-locked DCP
# (hw/checkpoints/static_routed_locked_v80_gen5.dcp without Phase 2 rebuild),
# use v80_vfpga_slr_floorplan.xdc instead -- this file assumes the freed SLR1
# area and will fail link with the old shell pblock.
#
# Intended use:
#   cmake .. -DFDEV_NAME=v80 -DBUILD_APP=1 -DEN_PR=1 -DN_REGIONS=<1..6> \
#            -DFPLAN_PATH=$(realpath \
#               hw/constraints/v80/vfpga_fplan/v80_vfpga_slr_floorplan_phase2.xdc)
#
# Layout (free CRs after Phase 2 SLR1 corridor):
#
#      X→ 0   1   2   3   4   5   6   7   8   9  10
#   Y↓ ─────────────────────────────────────────────
#   11  .   S   S   S   S   S   S   S   .   .   .    ←┐
#   10  .   S   S   S   S   S   S   S   S   .   .     │ SLR2 (unchanged)
#    9  .   S   S   S   S   S   S   S   S   .   .     │
#    8  .   S   S   S   S   S   S   S   S   .   .    ←┘
#    7  .   .   .   .   .   S   S   S   S   .   .    ←┐
#    6  .   .   .   .   .   S   S   .   .   .   .     │ SLR1 -- corridor only
#    5  .   .   .   .   .   S   S   .   .   .   .     │ shell occupies X5..X6
#    4  .   .   .   .   .   S   S   S   S   S   .    ←┘ (Y4 untouched)
#    3  .   .   .   .   .   S   S   S   S   S   .    ←┐
#    2  .   .   .   .   S   S   S   S   S   .   .     │ SLR0 (unchanged)
#    1  .   .   .   .   S   S   S   S   S   .   .     │
#    0  .   .   .   .   .   S   S   S   S   S   S    ←┘
#
#   S = shell corridor / shell SLR0/SLR2 footprint
#   . = free for vFPGAs
#
# Phase 2 frees in SLR1:
#   Y5: X1..X4 (4 CRs)  and X7..X9 (3 CRs)
#   Y6: X1..X4 (4 CRs)  and X7..X9 (3 CRs)
#   Y7: X1..X4 (4 CRs)
# Total: 18 additional SLR1 CRs become vFPGA-usable, in two contiguous
# rectangles (left ~12 CRs at X1..X4, right ~6 CRs at X7..X9).
#
# Per-vFPGA assignment (priority: largest regions first):
#
#   idx | SLR  | CR range          | size class       | what this gets you
#   ----|------|-------------------|------------------|--------------------
#    0  | SLR0 | X0Y0  :  X4Y3     | big (~20 CRs)    | major accelerator
#    1  | SLR2 | X8Y8  : X10Y11    | medium (~12 CRs) | mid-size accelerator
#    2  | SLR1 | X1Y5  :  X4Y7     | medium (~12 CRs) | NEW -- was thin
#    3  | SLR1 | X7Y5  :  X9Y6     | small (~6 CRs)   | NEW -- was thin
#    4  | SLR2 | X0Y8  :  X0Y11    | thin (~4 CRs)    | control vFPGA
#    5  | SLR0 | X9Y1  : X10Y2     | thin (~4 CRs)    | control vFPGA
#
# Compared to Phase 1 (with the wide shipped shell):
#   - vFPGA 2 grows from ~4 thin CRs to ~12 contiguous CRs in SLR1 left
#   - vFPGA 3 grows from ~4 thin CRs to ~6 contiguous CRs in SLR1 right
#   - Total substantial slots (>= 10 CRs): 2 -> 4
# =============================================================================

# Tcl helper: create the pblock only if the user_wrapper cell exists at this
# index. Lets a single XDC serve any N_REGIONS in [1..6].
proc cyt_slr_pblock_p2 {idx cr_x0 cr_y0 cr_x1 cr_y1} {
    set cell "inst_shell/inst_dynamic/inst_user_wrapper_${idx}"
    if {[llength [get_cells -quiet $cell]] == 0} {
        return
    }

    set pname "pblock_inst_user_wrapper_${idx}"
    create_pblock $pname
    add_cells_to_pblock [get_pblocks $pname] [get_cells $cell]
    resize_pblock [get_pblocks $pname] -add \
        "CLOCKREGION_X${cr_x0}Y${cr_y0}:CLOCKREGION_X${cr_x1}Y${cr_y1}"
    set_property SNAPPING_MODE ON  [get_pblocks $pname]
    set_property IS_SOFT      FALSE [get_pblocks $pname]
}

# Partition table — order matters: largest / most useful regions first so that
# small designs (low N_REGIONS) land in the best blocks.
#                  idx  CR_X0  CR_Y0  CR_X1  CR_Y1   SLR / size
cyt_slr_pblock_p2   0      0      0      4      3   ;# SLR0 big left
cyt_slr_pblock_p2   1      8      8     10     11   ;# SLR2 right block
cyt_slr_pblock_p2   2      1      5      4      7   ;# SLR1 left  (NEW)
cyt_slr_pblock_p2   3      7      5      9      6   ;# SLR1 right (NEW)
cyt_slr_pblock_p2   4      0      8      0     11   ;# SLR2 left thin
cyt_slr_pblock_p2   5      9      1     10      2   ;# SLR0 right small
