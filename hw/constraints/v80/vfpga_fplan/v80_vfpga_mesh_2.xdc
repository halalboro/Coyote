# V80 vFPGA mesh floorplan -- 2 cells (N_REGIONS=2), for the EN_HOST_NOC Phase-1 bring-up.
# 1 SLR1 + 1 SLR2 even-column (HDPR-93-safe) cells + shell host fabric -> SLR0.

create_pblock pblock_inst_user_wrapper_0
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_0] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_0]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_0] -add {CLOCKREGION_X2Y5:CLOCKREGION_X2Y5}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_0]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_0]

create_pblock pblock_inst_user_wrapper_1
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_1] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_1]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_1] -add {CLOCKREGION_X2Y8:CLOCKREGION_X2Y8}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_1]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_1]

create_pblock pblock_shell_host
add_cells_to_pblock [get_pblocks pblock_shell_host] [get_cells {inst_shell/inst_shell_slave inst_shell/inst_shell_data_cc inst_shell/inst_shell_ctrl_cc inst_shell/inst_stats_hch_0}]
resize_pblock [get_pblocks pblock_shell_host] -add {SLICE_X0Y0:SLICE_X379Y331}
set_property IS_SOFT FALSE [get_pblocks pblock_shell_host]
