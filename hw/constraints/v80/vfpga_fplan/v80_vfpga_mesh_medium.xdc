# =============================================================================
# V80 vFPGA mesh floorplan -- MEDIUM profile (up to 18 cells, 2 CR each)
# =============================================================================
# Plain XDC (Vivado's constraint parser doesn't support proc/if/switch/puts).
#
# Priority order: SLR1 first (3 rows Y5,Y6,Y7 × 3 col-pairs = 9 slots),
# then SLR2 lower (2 rows Y8,Y9 × 3 col-pairs = 6 slots),
# then SLR2 top (Y10 only × 3 col-pairs = 3 slots). Total = 18.
#
# Each cell is 2 CR wide × 1 CR tall (2 CRs total, ~half the area of the
# large profile). Cell shape pairs one fabric column with one NoC column
# so the NMU/NSU tiles sit inside the pblock.
#
# Requires: static rebuilt with Strategy B v80_static_floorplan.xdc.
#
# Mesh layout:
#
#      X→  0   1   2   3   4   5   6   7   8   9  10
#   Y11   .   .   .   .   .   .   .   .   .   .   .    (skipped -- no NoC tiles at Y11)
#   Y10   .   .  [15][15][16][16][17][17] .   .   .    SLR2 top row
#    Y9   .   .  [12][12][13][13][14][14] .   .   .
#    Y8   .   .  [ 9][ 9][10][10][11][11] .   .   .    SLR2 lower
#    Y7   .   .  [ 6][ 6][ 7][ 7][ 8][ 8] .   .   .
#    Y6   .   .  [ 3][ 3][ 4][ 4][ 5][ 5] .   .   .    SLR1
#    Y5   .   .  [ 0][ 0][ 1][ 1][ 2][ 2] .   .   .
#    Y4-Y0  ──────── shell (SLR0-only) ────────
#
# For N_REGIONS <= 9  : matches large profile density (SLR1-only).
# For N_REGIONS <= 15 : uses all SLR1 + SLR2 lower.
# For N_REGIONS <= 18 : full mesh incl. SLR2 top row Y10.
# =============================================================================

# vFPGA 0  -- SLR1 Y5 left
create_pblock pblock_inst_user_wrapper_0
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_0] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_0]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_0] -add {CLOCKREGION_X2Y5:CLOCKREGION_X3Y5}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_0]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_0]

# vFPGA 1  -- SLR1 Y5 center
create_pblock pblock_inst_user_wrapper_1
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_1] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_1]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_1] -add {CLOCKREGION_X4Y5:CLOCKREGION_X5Y5}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_1]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_1]

# vFPGA 2  -- SLR1 Y5 right
create_pblock pblock_inst_user_wrapper_2
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_2] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_2]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_2] -add {CLOCKREGION_X6Y5:CLOCKREGION_X7Y5}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_2]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_2]

# vFPGA 3  -- SLR1 Y6 left
create_pblock pblock_inst_user_wrapper_3
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_3] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_3]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_3] -add {CLOCKREGION_X2Y6:CLOCKREGION_X3Y6}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_3]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_3]

# vFPGA 4  -- SLR1 Y6 center
create_pblock pblock_inst_user_wrapper_4
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_4] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_4]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_4] -add {CLOCKREGION_X4Y6:CLOCKREGION_X5Y6}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_4]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_4]

# vFPGA 5  -- SLR1 Y6 right
create_pblock pblock_inst_user_wrapper_5
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_5] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_5]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_5] -add {CLOCKREGION_X6Y6:CLOCKREGION_X7Y6}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_5]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_5]

# vFPGA 6  -- SLR1 Y7 left
create_pblock pblock_inst_user_wrapper_6
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_6] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_6]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_6] -add {CLOCKREGION_X2Y7:CLOCKREGION_X3Y7}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_6]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_6]

# vFPGA 7  -- SLR1 Y7 center
create_pblock pblock_inst_user_wrapper_7
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_7] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_7]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_7] -add {CLOCKREGION_X4Y7:CLOCKREGION_X5Y7}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_7]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_7]

# vFPGA 8  -- SLR1 Y7 right
create_pblock pblock_inst_user_wrapper_8
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_8] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_8]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_8] -add {CLOCKREGION_X6Y7:CLOCKREGION_X7Y7}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_8]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_8]

# vFPGA 9  -- SLR2 Y8 left
create_pblock pblock_inst_user_wrapper_9
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_9] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_9]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_9] -add {CLOCKREGION_X2Y8:CLOCKREGION_X3Y8}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_9]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_9]

# vFPGA 10 -- SLR2 Y8 center
create_pblock pblock_inst_user_wrapper_10
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_10] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_10]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_10] -add {CLOCKREGION_X4Y8:CLOCKREGION_X5Y8}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_10]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_10]

# vFPGA 11 -- SLR2 Y8 right
create_pblock pblock_inst_user_wrapper_11
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_11] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_11]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_11] -add {CLOCKREGION_X6Y8:CLOCKREGION_X7Y8}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_11]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_11]

# vFPGA 12 -- SLR2 Y9 left
create_pblock pblock_inst_user_wrapper_12
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_12] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_12]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_12] -add {CLOCKREGION_X2Y9:CLOCKREGION_X3Y9}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_12]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_12]

# vFPGA 13 -- SLR2 Y9 center
create_pblock pblock_inst_user_wrapper_13
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_13] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_13]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_13] -add {CLOCKREGION_X4Y9:CLOCKREGION_X5Y9}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_13]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_13]

# vFPGA 14 -- SLR2 Y9 right
create_pblock pblock_inst_user_wrapper_14
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_14] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_14]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_14] -add {CLOCKREGION_X6Y9:CLOCKREGION_X7Y9}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_14]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_14]

# vFPGA 15 -- SLR2 Y10 left
create_pblock pblock_inst_user_wrapper_15
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_15] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_15]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_15] -add {CLOCKREGION_X2Y10:CLOCKREGION_X3Y10}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_15]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_15]

# vFPGA 16 -- SLR2 Y10 center
create_pblock pblock_inst_user_wrapper_16
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_16] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_16]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_16] -add {CLOCKREGION_X4Y10:CLOCKREGION_X5Y10}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_16]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_16]

# vFPGA 17 -- SLR2 Y10 right
create_pblock pblock_inst_user_wrapper_17
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_17] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_17]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_17] -add {CLOCKREGION_X6Y10:CLOCKREGION_X7Y10}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_17]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_17]
