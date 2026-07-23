# Example mesh recipe: 3 large + 6 small = 9 vFPGAs, mixed sizes.
#
# Usage:
#   export CYT_MESH_PROFILE=recipe
#   export CYT_MESH_RECIPE=$(realpath hw/constraints/v80/vfpga_fplan/example_recipe_mixed.tcl)
#   cmake ... -DFPLAN_PATH=$(realpath hw/constraints/v80/vfpga_fplan/v80_vfpga_mesh_floorplan.xdc)
#
# Layout:
#
#      X→  0   1   2   3   4   5   6   7   8
#   Y11   .   .  [vF3      ][vF4      ][vF5  ]   ← 3 small cells in SLR2 top
#   Y10   .   .  [vF3      ][vF4      ][vF5  ]
#   Y9    .   .  [vF6      ][vF7      ][vF8  ]   ← 3 small cells in SLR2 lower
#   Y8    .   .  [vF6      ][vF7      ][vF8  ]
#   Y7    .   .  [vF0  ][vF1  ][vF2  ]           ← 3 large cells in SLR1
#   Y6    .   .  [vF0  ][vF1  ][vF2  ]
#   Y5    .   .  [vF0  ][vF1  ][vF2  ]
#
# This pattern reserves SLR1 (most contiguous free area) for the 3 large
# accelerators, and uses the SLR2 row-pairs for 6 medium control vFPGAs.

# Large cells (SLR1)
cyt_mesh_pblock 0   2 5   3 7
cyt_mesh_pblock 1   4 5   5 7
cyt_mesh_pblock 2   6 5   7 7

# Medium cells (SLR2 top)
cyt_mesh_pblock 3   2 10  3 11
cyt_mesh_pblock 4   4 10  5 11
cyt_mesh_pblock 5   6 10  7 11

# Medium cells (SLR2 lower)
cyt_mesh_pblock 6   2 8   3 9
cyt_mesh_pblock 7   4 8   5 9
cyt_mesh_pblock 8   6 8   7 9
