# =============================================================================
# V80 vFPGA mesh floorplan -- 17 cells, 1 CR each (N_REGIONS=17)
# Derived from v80_vfpga_mesh_medium.xdc by dropping cell 17 (that file's 18th
# pblock references inst_user_wrapper_17, which does not exist at N=17). Use for
# the SHELL build: -DFPLAN_PATH=.../v80_vfpga_mesh_17.xdc
# =============================================================================
# Plain XDC (Vivado's constraint parser doesn't support proc/if/switch/puts).
#
# ROOT CAUSE OF THE OLD HDPR-93 (fixed here):
#   The CLK_REBUF_VERT_SSIT vertical clock-rebuffer tiles live ONLY in the ODD
#   clock-region columns X1/X3/X5/X7, and each rebuffer is a *vertical*
#   structure spanning the full SLR height (SLR1 = Y5..Y7, SLR2 = Y8..Y11).
#   The previous medium profile used 2-CR-wide cells (X{2}:X{3}, X{4}:X{5},
#   X{6}:X{7}) that were only 1 CR TALL. Such a cell claims one row of a vertical
#   rebuffer it does not fully own -> DFX "over usage" -> ERROR DRC HDPR-93.
#   (The large profile passes because its cells are full-SLR-height, so they own
#    the entire rebuffer segment.)  The old header blamed row Y5; that was wrong.
#
# FIX: use 1-CR-wide cells on the EVEN columns X2/X4/X6 only. Even columns
#   contain no CLK_REBUF_VERT_SSIT tiles (verified on xcv80 via get_tiles), so
#   no partial-rebuffer ownership can occur at any row. Each cell = 1 CR
#   (3840 SLICEs, ~24k LUT6 — ample for a vFPGA).
#
# NoC NOTE: the ODD columns also hold the NMU/NSU NoC endpoints. Even-only cells
#   therefore have NO NoC tile inside the pblock. This is correct for designs
#   where the vFPGA needs no NoC-in-pblock — e.g. host-stream-only (en_mem=0),
#   like the 03_multitenancy example, and the Milestone B.2 P2P path whose NoC
#   endpoints (axi_noc_p2p) live in the STATIC/shell, not in the vFPGA. If a
#   future design needs card/DDR memory (en_mem=1) with a per-vFPGA NoC master,
#   use the large profile (full-SLR-height cells own both the NMU and the
#   rebuffer) instead of this one.
#
# Requires: static rebuilt with Strategy B v80_static_floorplan.xdc.
#
# Mesh layout (each [n] is one full clock region on an even column):
#
#      X->  0   1   2   3   4   5   6   7   8   9  10
#   Y10   .   .  [15]  .  [16]  .  [17]  .   .   .   .    SLR2 top
#    Y9   .   .  [12]  .  [13]  .  [14]  .   .   .   .
#    Y8   .   .  [ 9]  .  [10]  .  [11]  .   .   .   .    SLR2 lower
#    Y7   .   .  [ 6]  .  [ 7]  .  [ 8]  .   .   .   .
#    Y6   .   .  [ 3]  .  [ 4]  .  [ 5]  .   .   .   .    SLR1
#    Y5   .   .  [ 0]  .  [ 1]  .  [ 2]  .   .   .   .    SLR1 (now usable)
#    Y4-Y0  ──────── shell (SLR0-only) ────────
#          odd cols X1/X3/X5/X7 = SSIT rebuffer + NoC columns, left to static
#
# For N_REGIONS <= 9  : SLR1 rows Y5..Y7 (cells 0..8).
# For N_REGIONS <= 18 : + SLR2 rows Y8..Y10 (cells 9..17).
# =============================================================================

# vFPGA 0  -- SLR1 Y5 left
create_pblock pblock_inst_user_wrapper_0
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_0] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_0]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_0] -add {CLOCKREGION_X2Y5:CLOCKREGION_X2Y5}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_0]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_0]

# vFPGA 1  -- SLR1 Y5 center
create_pblock pblock_inst_user_wrapper_1
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_1] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_1]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_1] -add {CLOCKREGION_X4Y5:CLOCKREGION_X4Y5}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_1]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_1]

# vFPGA 2  -- SLR1 Y5 right
create_pblock pblock_inst_user_wrapper_2
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_2] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_2]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_2] -add {CLOCKREGION_X6Y5:CLOCKREGION_X6Y5}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_2]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_2]

# vFPGA 3  -- SLR1 Y6 left
create_pblock pblock_inst_user_wrapper_3
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_3] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_3]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_3] -add {CLOCKREGION_X2Y6:CLOCKREGION_X2Y6}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_3]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_3]

# vFPGA 4  -- SLR1 Y6 center
create_pblock pblock_inst_user_wrapper_4
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_4] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_4]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_4] -add {CLOCKREGION_X4Y6:CLOCKREGION_X4Y6}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_4]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_4]

# vFPGA 5  -- SLR1 Y6 right
create_pblock pblock_inst_user_wrapper_5
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_5] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_5]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_5] -add {CLOCKREGION_X6Y6:CLOCKREGION_X6Y6}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_5]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_5]

# vFPGA 6  -- SLR1 Y7 left
create_pblock pblock_inst_user_wrapper_6
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_6] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_6]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_6] -add {CLOCKREGION_X2Y7:CLOCKREGION_X2Y7}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_6]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_6]

# vFPGA 7  -- SLR1 Y7 center
create_pblock pblock_inst_user_wrapper_7
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_7] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_7]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_7] -add {CLOCKREGION_X4Y7:CLOCKREGION_X4Y7}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_7]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_7]

# vFPGA 8  -- SLR1 Y7 right
create_pblock pblock_inst_user_wrapper_8
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_8] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_8]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_8] -add {CLOCKREGION_X6Y7:CLOCKREGION_X6Y7}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_8]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_8]

# vFPGA 9  -- SLR2 Y8 left
create_pblock pblock_inst_user_wrapper_9
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_9] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_9]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_9] -add {CLOCKREGION_X2Y8:CLOCKREGION_X2Y8}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_9]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_9]

# vFPGA 10 -- SLR2 Y8 center
create_pblock pblock_inst_user_wrapper_10
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_10] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_10]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_10] -add {CLOCKREGION_X4Y8:CLOCKREGION_X4Y8}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_10]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_10]

# vFPGA 11 -- SLR2 Y8 right
create_pblock pblock_inst_user_wrapper_11
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_11] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_11]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_11] -add {CLOCKREGION_X6Y8:CLOCKREGION_X6Y8}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_11]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_11]

# vFPGA 12 -- SLR2 Y9 left
create_pblock pblock_inst_user_wrapper_12
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_12] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_12]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_12] -add {CLOCKREGION_X2Y9:CLOCKREGION_X2Y9}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_12]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_12]

# vFPGA 13 -- SLR2 Y9 center
create_pblock pblock_inst_user_wrapper_13
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_13] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_13]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_13] -add {CLOCKREGION_X4Y9:CLOCKREGION_X4Y9}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_13]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_13]

# vFPGA 14 -- SLR2 Y9 right
create_pblock pblock_inst_user_wrapper_14
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_14] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_14]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_14] -add {CLOCKREGION_X6Y9:CLOCKREGION_X6Y9}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_14]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_14]

# vFPGA 15 -- SLR2 Y10 left
create_pblock pblock_inst_user_wrapper_15
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_15] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_15]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_15] -add {CLOCKREGION_X2Y10:CLOCKREGION_X2Y10}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_15]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_15]

# vFPGA 16 -- SLR2 Y10 center
create_pblock pblock_inst_user_wrapper_16
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_16] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_16]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_16] -add {CLOCKREGION_X4Y10:CLOCKREGION_X4Y10}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_16]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_16]
