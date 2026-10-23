# ==========================================================================
# V80 vFPGA mesh floorplan -- 20 cells (N_REGIONS=20)
#
# Auto-generated 2026-09-16 for the EN_PR=1 inter-vFPGA P2P NoC pivot.
# Even-column single-CR reconfigurable partitions (X0/X2/X4/X6/X8) -- device-
# verified rebuffer-free => HDPR-93-safe; and clear of the odd-column NoC tiles
# (X1/X3/X5/X7) where the P2P hubs + shell routing sit.
#
# SLR1 = CR rows Y5-7 (vFPGA 0-9, hubs 0,1) ; SLR2 = Y8-10 (vFPGA 10-19, hubs 2,3).
# X0Y5/X0Y8 have 0 SLICE (skipped). 10 per SLR matches the hub-SLR pairing so each
# vFPGA reaches its hub within-SLR.
#
# N=20 chosen so the shell-in-SLR0 host fabric + 20 vFPGA datapaths stay UNDER the
# SLR0<->SLR1 SLL budget (18870): ~20 x 770 = ~15400 SLLs. (N=28 needed 21563 > 18870;
# see 2026-09-16 analysis.) Scaling past 20 needs the host<->vFPGA path off SLLs
# (NoC) or ctrl_cc hard-placed in SLR1 -- tracked as follow-up.
#
# N-agnostic: get_cells -quiet so only existing wrappers get pblocked.
# ==========================================================================

create_pblock pblock_inst_user_wrapper_0
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_0] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_0]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_0] -add {CLOCKREGION_X2Y5:CLOCKREGION_X2Y5}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_0]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_0]

create_pblock pblock_inst_user_wrapper_1
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_1] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_1]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_1] -add {CLOCKREGION_X4Y5:CLOCKREGION_X4Y5}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_1]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_1]

create_pblock pblock_inst_user_wrapper_2
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_2] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_2]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_2] -add {CLOCKREGION_X6Y5:CLOCKREGION_X6Y5}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_2]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_2]

create_pblock pblock_inst_user_wrapper_3
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_3] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_3]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_3] -add {CLOCKREGION_X8Y5:CLOCKREGION_X8Y5}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_3]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_3]

create_pblock pblock_inst_user_wrapper_4
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_4] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_4]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_4] -add {CLOCKREGION_X0Y6:CLOCKREGION_X0Y6}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_4]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_4]

create_pblock pblock_inst_user_wrapper_5
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_5] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_5]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_5] -add {CLOCKREGION_X2Y6:CLOCKREGION_X2Y6}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_5]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_5]

create_pblock pblock_inst_user_wrapper_6
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_6] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_6]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_6] -add {CLOCKREGION_X4Y6:CLOCKREGION_X4Y6}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_6]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_6]

create_pblock pblock_inst_user_wrapper_7
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_7] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_7]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_7] -add {CLOCKREGION_X6Y6:CLOCKREGION_X6Y6}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_7]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_7]

create_pblock pblock_inst_user_wrapper_8
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_8] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_8]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_8] -add {CLOCKREGION_X8Y6:CLOCKREGION_X8Y6}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_8]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_8]

create_pblock pblock_inst_user_wrapper_9
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_9] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_9]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_9] -add {CLOCKREGION_X0Y7:CLOCKREGION_X0Y7}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_9]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_9]

create_pblock pblock_inst_user_wrapper_10
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_10] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_10]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_10] -add {CLOCKREGION_X2Y8:CLOCKREGION_X2Y8}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_10]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_10]

create_pblock pblock_inst_user_wrapper_11
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_11] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_11]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_11] -add {CLOCKREGION_X4Y8:CLOCKREGION_X4Y8}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_11]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_11]

create_pblock pblock_inst_user_wrapper_12
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_12] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_12]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_12] -add {CLOCKREGION_X6Y8:CLOCKREGION_X6Y8}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_12]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_12]

create_pblock pblock_inst_user_wrapper_13
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_13] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_13]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_13] -add {CLOCKREGION_X8Y8:CLOCKREGION_X8Y8}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_13]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_13]

create_pblock pblock_inst_user_wrapper_14
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_14] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_14]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_14] -add {CLOCKREGION_X0Y9:CLOCKREGION_X0Y9}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_14]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_14]

create_pblock pblock_inst_user_wrapper_15
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_15] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_15]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_15] -add {CLOCKREGION_X2Y9:CLOCKREGION_X2Y9}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_15]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_15]

create_pblock pblock_inst_user_wrapper_16
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_16] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_16]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_16] -add {CLOCKREGION_X4Y9:CLOCKREGION_X4Y9}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_16]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_16]

create_pblock pblock_inst_user_wrapper_17
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_17] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_17]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_17] -add {CLOCKREGION_X6Y9:CLOCKREGION_X6Y9}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_17]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_17]

create_pblock pblock_inst_user_wrapper_18
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_18] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_18]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_18] -add {CLOCKREGION_X8Y9:CLOCKREGION_X8Y9}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_18]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_18]

create_pblock pblock_inst_user_wrapper_19
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_19] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_19]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_19] -add {CLOCKREGION_X0Y10:CLOCKREGION_X0Y10}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_19]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_19]

# ==========================================================================
# Shell host/control fabric -> SLR0 (keeps it out of the SLR1 vFPGA regions:
# fixes the SLR1 legalization overlap; at N=20 the resulting SLR0<->SLR1 SLL
# demand ~15400 is under the 18870 budget, so all four cells can stay in SLR0).
# inst_shell is NOT HD.RECONFIGURABLE, so a placement pblock on its children is
# legal (verified on shell_linked.dcp: rc=0). Excludes P2P hubs + inst_dynamic.
# ==========================================================================
create_pblock pblock_shell_host
add_cells_to_pblock [get_pblocks pblock_shell_host] [get_cells {inst_shell/inst_shell_slave inst_shell/inst_shell_data_cc inst_shell/inst_shell_ctrl_cc inst_shell/inst_stats_hch_0}]
resize_pblock [get_pblocks pblock_shell_host] -add {SLICE_X0Y0:SLICE_X379Y331}
set_property IS_SOFT FALSE [get_pblocks pblock_shell_host]
