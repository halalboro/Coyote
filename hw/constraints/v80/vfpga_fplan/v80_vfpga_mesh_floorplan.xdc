# =============================================================================
# V80 vFPGA mesh floorplan -- LARGE profile (up to 9 cells, 2x2 CR each)
# =============================================================================
# Plain XDC (Vivado's constraint parser doesn't support proc/if/switch/puts).
#
# Priority order: SLR1 cells FIRST (adjacent to the SLR0-only shell, easier
# DFX partition-pin routing), then SLR2 lower, then SLR2 top.
# For low N_REGIONS builds the closest cells (best for DFX routing) are used.
#
# Requires: static rebuilt with Strategy B v80_static_floorplan.xdc.
#
# Mesh layout (after Strategy B frees SLR1+SLR2):
#
#      X→  0   1   2   3   4   5   6   7   8   9  10
#   Y11   .   .  [F6][N6][F7][N7][F8][N8] .   .   .   SLR2 top (idx 6,7,8)
#   Y10   .   .  [F6][N6][F7][N7][F8][N8] .   .   .
#    Y9   .   .  [F3][N3][F4][N4][F5][N5] .   .   .   SLR2 lower (idx 3,4,5)
#    Y8   .   .  [F3][N3][F4][N4][F5][N5] .   .   .
#    Y7   .   .  [F0][N0][F1][N1][F2][N2] .   .   .
#    Y6   .   .  [F0][N0][F1][N1][F2][N2] .   .   .   SLR1 (idx 0,1,2) — closest to shell
#    Y5   .   .  [F0][N0][F1][N1][F2][N2] .   .   .
#    Y4-Y0  ──────── shell (SLR0-only) ────────
#
# Note: only pblocks 0-3 are declared here (default Coyote multitenancy
# example has N_REGIONS=4). For N>4, append more declarations following
# the same pattern (cells 4-8 in SLR2).
# =============================================================================

# vFPGA 0  -- SLR1 left (closest to shell, 3-row cell)
create_pblock pblock_inst_user_wrapper_0
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_0] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_0]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_0] -add {CLOCKREGION_X2Y5:CLOCKREGION_X3Y7}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_0]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_0]

# vFPGA 1  -- SLR1 center
create_pblock pblock_inst_user_wrapper_1
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_1] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_1]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_1] -add {CLOCKREGION_X4Y5:CLOCKREGION_X5Y7}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_1]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_1]

# vFPGA 2  -- SLR1 right
create_pblock pblock_inst_user_wrapper_2
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_2] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_2]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_2] -add {CLOCKREGION_X6Y5:CLOCKREGION_X7Y7}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_2]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_2]

# vFPGA 3  -- SLR2 lower-left (closest SLR2 row to shell)
create_pblock pblock_inst_user_wrapper_3
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_3] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_3]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_3] -add {CLOCKREGION_X2Y8:CLOCKREGION_X3Y9}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_3]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_3]

# vFPGA 4  -- SLR2 lower-center
create_pblock pblock_inst_user_wrapper_4
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_4] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_4]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_4] -add {CLOCKREGION_X4Y8:CLOCKREGION_X5Y9}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_4]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_4]

# vFPGA 5  -- SLR2 lower-right
create_pblock pblock_inst_user_wrapper_5
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_5] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_5]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_5] -add {CLOCKREGION_X6Y8:CLOCKREGION_X7Y9}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_5]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_5]

# vFPGA 6  -- SLR2 top-left (Y10..Y11)
create_pblock pblock_inst_user_wrapper_6
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_6] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_6]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_6] -add {CLOCKREGION_X2Y10:CLOCKREGION_X3Y11}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_6]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_6]

# vFPGA 7  -- SLR2 top-center
create_pblock pblock_inst_user_wrapper_7
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_7] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_7]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_7] -add {CLOCKREGION_X4Y10:CLOCKREGION_X5Y11}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_7]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_7]

# vFPGA 8  -- SLR2 top-right
create_pblock pblock_inst_user_wrapper_8
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_8] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_8]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_8] -add {CLOCKREGION_X6Y10:CLOCKREGION_X7Y11}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_8]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_8]
