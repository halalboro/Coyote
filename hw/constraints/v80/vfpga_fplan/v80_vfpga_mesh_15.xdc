# V80 vFPGA mesh -- 15 cells (N_REGIONS=15). Matches shipped static_synthed N_USR_IRQ=15 exactly
# (m_usr_irq[14:0]) -> clean static<->shell link. Even-column HDPR-93-safe cells; 8 SLR1 + 7 SLR2.

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
resize_pblock [get_pblocks pblock_inst_user_wrapper_8] -add {CLOCKREGION_X2Y8:CLOCKREGION_X2Y8}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_8]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_8]

create_pblock pblock_inst_user_wrapper_9
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_9] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_9]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_9] -add {CLOCKREGION_X4Y8:CLOCKREGION_X4Y8}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_9]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_9]

create_pblock pblock_inst_user_wrapper_10
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_10] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_10]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_10] -add {CLOCKREGION_X6Y8:CLOCKREGION_X6Y8}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_10]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_10]

create_pblock pblock_inst_user_wrapper_11
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_11] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_11]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_11] -add {CLOCKREGION_X8Y8:CLOCKREGION_X8Y8}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_11]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_11]

create_pblock pblock_inst_user_wrapper_12
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_12] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_12]]
# X6Y9 (was X0Y9): the device-edge column X0 is co-occupied by the static shell
# there (GTM_QUAD_X0Y9:Y10, DPLL_X0Y10), starving routable fabric -> build_hnoc15c
# failed route verify with [Route 35-536] unresolvable 1-node congestion on vFPGA 12's
# local credit FIFOs. X6Y9 is a clean interior even-column CR directly above the
# proven-good vFPGA 10 (X6Y8); completes the Y9 row (X2/X4/X6 like Y8's X2/X4/X6/X8).
resize_pblock [get_pblocks pblock_inst_user_wrapper_12] -add {CLOCKREGION_X6Y9:CLOCKREGION_X6Y9}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_12]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_12]

create_pblock pblock_inst_user_wrapper_13
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_13] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_13]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_13] -add {CLOCKREGION_X2Y9:CLOCKREGION_X2Y9}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_13]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_13]

create_pblock pblock_inst_user_wrapper_14
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_14] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_14]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_14] -add {CLOCKREGION_X4Y9:CLOCKREGION_X4Y9}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_14]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_14]

create_pblock pblock_shell_host
add_cells_to_pblock [get_pblocks pblock_shell_host] [get_cells {inst_shell/inst_shell_slave inst_shell/inst_shell_data_cc inst_shell/inst_shell_ctrl_cc inst_shell/inst_stats_hch_0}]
resize_pblock [get_pblocks pblock_shell_host] -add {SLICE_X0Y0:SLICE_X379Y331}
set_property IS_SOFT FALSE [get_pblocks pblock_shell_host]
