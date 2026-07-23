# =============================================================================
# V80 SLR-aware vFPGA floorplan
# =============================================================================
# Distributes up to 6 vFPGAs across the V80's 3 SLRs in regions that the
# shipped static-shell checkpoint leaves free.
#
# Intended use:
#   cmake .. -DFDEV_NAME=v80 -DBUILD_APP=1 -DEN_PR=1 -DN_REGIONS=<1..6> \
#            -DFPLAN_PATH=$(realpath hw/constraints/v80/vfpga_fplan/v80_vfpga_slr_floorplan.xdc)
#
# Only the pblocks for actually-existing user_wrapper cells are created, so
# this file works for any N_REGIONS in [1..6] without edits. For N_REGIONS > 6
# extend the partition table at the bottom of this file.
#
# Layout (free CRs left by the shipped V80 static shell):
#
#      X→ 0   1   2   3   4   5   6   7   8   9  10
#   Y↓ ─────────────────────────────────────────────
#   11  .   S   S   S   S   S   S   S   .   .   .    ←┐
#   10  .   S   S   S   S   S   S   S   S   .   .     │ SLR2
#    9  .   S   S   S   S   S   S   S   S   .   .     │
#    8  .   S   S   S   S   S   S   S   S   .   .    ←┘
#    7  .   S   S   S   S   S   S   S   S   .   .    ←┐
#    6  .   S   S   S   S   S   S   S   S   S   .     │ SLR1
#    5  .   S   S   S   S   S   S   S   S   S   .     │
#    4  .   .   .   .   .   S   S   S   S   S   .    ←┘
#    3  .   .   .   .   .   S   S   S   S   S   .    ←┐
#    2  .   .   .   .   S   S   S   S   S   .   .     │ SLR0
#    1  .   .   .   .   S   S   S   S   S   .   .     │
#    0  .   .   .   .   .   S   S   S   S   S   S    ←┘
#
#   S = shell pblock, . = free.
#
# Per-vFPGA assignment (priority: largest regions first):
#
#   idx | SLR  | CR range              | rough capacity
#   ----|------|------------------------|---------------
#    0  | SLR0 | X0Y0 :  X4Y3          | ~20 CRs (big)
#    1  | SLR2 | X8Y8 : X10Y11         | ~12 CRs (medium)
#    2  | SLR2 | X0Y8 :  X0Y11         | ~4 CRs (small, thin)
#    3  | SLR1 | X9Y4 : X10Y7          | ~6 CRs (small)
#    4  | SLR1 | X0Y4 :  X0Y7          | ~4 CRs (small, thin)
#    5  | SLR0 | X9Y1 : X10Y2          | ~4 CRs (small)
#
# Caveats:
#   - SLR1 is mostly shell. The two SLR1 regions are thin column strips and
#     will not fit large accelerators. They are good targets for small/control
#     vFPGAs.
#   - SLR0's big region (idx 0) shares Y=0..3 with the shell's lower portion,
#     so it lives strictly in CR columns X0..X4. Resource counts are non-uniform
#     across SLRs: SLR0/SLR2 expose more URAM/DSP columns than SLR1's edges.
#   - SNAPPING_MODE ON snaps to whole-CR boundaries; combined with the
#     locked routed shell DCP, sites already used by the shell within these
#     CRs remain unavailable to the placer (which is what we want).
#
# To extend beyond 6 vFPGAs you would need to either (a) split idx 0's big
# SLR0 region into multiple sub-rectangles, or (b) rebuild the static shell
# with a tighter pblock that frees more SLR1 area. (b) is the proper way to
# unlock SLR1 for substantial vFPGAs and is tracked as Phase 2 work.
# =============================================================================

# Tcl helper: create the pblock only if the user_wrapper cell exists at this
# index. Lets a single XDC serve any N_REGIONS in [1..6].
proc cyt_slr_pblock {idx cr_x0 cr_y0 cr_x1 cr_y1} {
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
#                idx  CR_X0  CR_Y0  CR_X1  CR_Y1   SLR / size
cyt_slr_pblock   0      0      0      4      3   ;# SLR0 big left
cyt_slr_pblock   1      8      8     10     11   ;# SLR2 right block
cyt_slr_pblock   2      0      8      0     11   ;# SLR2 left thin
cyt_slr_pblock   3      9      4     10      7   ;# SLR1 right thin
cyt_slr_pblock   4      0      4      0      7   ;# SLR1 left thin
cyt_slr_pblock   5      9      1     10      2   ;# SLR0 right small
