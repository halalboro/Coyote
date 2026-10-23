# ==========================================================================
# V80 vFPGA mesh floorplan -- 28 cells (SMALL profile, N_REGIONS=28)
#
# Auto-generated 2026-09-14 for the EN_PR=1 inter-vFPGA P2P NoC pivot
# (docs/superpowers/plans/2026-09-14-p2p-mesh-pivot.md). Each vFPGA is a
# single-clock-region reconfigurable partition on an EVEN column (X0/X2/X4/
# X6/X8) -- device-verified rebuffer-free, so HDPR-93-safe (no CLK_REBUF_
# VERT_SSIT tile straddle; those live only in odd cols X1/X3/X5/X7). Even
# columns also keep the vFPGAs clear of the odd-column NoC tiles where the
# P2P hubs (NOC_NMU512/NSU512 in CRs X1/X3/X5/X7) and shell routing sit.
#
# SLR map: SLR1 = CR rows Y5-7, SLR2 = Y8-10. X0Y5/X0Y8 have 0 SLICE (skipped).
# Hub-SLR pairing (p2p_noc_conn_tmplt.txt): send/recv hubs 0,1 in SLR1 serve
# vFPGAs 0-13; hubs 2,3 in SLR2 serve 14-27. Indices below are laid out so
# 0-13 land in SLR1 and 14-27 in SLR2 -> each vFPGA's soft AXIS to its hub
# stays within-SLR; the hardened NoC carries any inter-SLR P2P hop.
#
# N-agnostic: get_cells -quiet means only wrappers that exist get pblocked.
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
resize_pblock [get_pblocks pblock_inst_user_wrapper_10] -add {CLOCKREGION_X2Y7:CLOCKREGION_X2Y7}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_10]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_10]

create_pblock pblock_inst_user_wrapper_11
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_11] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_11]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_11] -add {CLOCKREGION_X4Y7:CLOCKREGION_X4Y7}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_11]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_11]

create_pblock pblock_inst_user_wrapper_12
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_12] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_12]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_12] -add {CLOCKREGION_X6Y7:CLOCKREGION_X6Y7}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_12]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_12]

create_pblock pblock_inst_user_wrapper_13
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_13] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_13]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_13] -add {CLOCKREGION_X8Y7:CLOCKREGION_X8Y7}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_13]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_13]

create_pblock pblock_inst_user_wrapper_14
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_14] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_14]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_14] -add {CLOCKREGION_X2Y8:CLOCKREGION_X2Y8}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_14]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_14]

create_pblock pblock_inst_user_wrapper_15
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_15] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_15]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_15] -add {CLOCKREGION_X4Y8:CLOCKREGION_X4Y8}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_15]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_15]

create_pblock pblock_inst_user_wrapper_16
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_16] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_16]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_16] -add {CLOCKREGION_X6Y8:CLOCKREGION_X6Y8}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_16]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_16]

create_pblock pblock_inst_user_wrapper_17
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_17] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_17]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_17] -add {CLOCKREGION_X8Y8:CLOCKREGION_X8Y8}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_17]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_17]

create_pblock pblock_inst_user_wrapper_18
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_18] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_18]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_18] -add {CLOCKREGION_X0Y9:CLOCKREGION_X0Y9}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_18]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_18]

create_pblock pblock_inst_user_wrapper_19
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_19] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_19]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_19] -add {CLOCKREGION_X2Y9:CLOCKREGION_X2Y9}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_19]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_19]

create_pblock pblock_inst_user_wrapper_20
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_20] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_20]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_20] -add {CLOCKREGION_X4Y9:CLOCKREGION_X4Y9}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_20]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_20]

create_pblock pblock_inst_user_wrapper_21
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_21] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_21]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_21] -add {CLOCKREGION_X6Y9:CLOCKREGION_X6Y9}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_21]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_21]

create_pblock pblock_inst_user_wrapper_22
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_22] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_22]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_22] -add {CLOCKREGION_X8Y9:CLOCKREGION_X8Y9}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_22]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_22]

create_pblock pblock_inst_user_wrapper_23
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_23] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_23]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_23] -add {CLOCKREGION_X0Y10:CLOCKREGION_X0Y10}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_23]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_23]

create_pblock pblock_inst_user_wrapper_24
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_24] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_24]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_24] -add {CLOCKREGION_X2Y10:CLOCKREGION_X2Y10}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_24]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_24]

create_pblock pblock_inst_user_wrapper_25
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_25] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_25]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_25] -add {CLOCKREGION_X4Y10:CLOCKREGION_X4Y10}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_25]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_25]

create_pblock pblock_inst_user_wrapper_26
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_26] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_26]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_26] -add {CLOCKREGION_X6Y10:CLOCKREGION_X6Y10}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_26]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_26]

create_pblock pblock_inst_user_wrapper_27
add_cells_to_pblock [get_pblocks pblock_inst_user_wrapper_27] [get_cells -quiet [list inst_shell/inst_dynamic/inst_user_wrapper_27]]
resize_pblock [get_pblocks pblock_inst_user_wrapper_27] -add {CLOCKREGION_X8Y10:CLOCKREGION_X8Y10}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_user_wrapper_27]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_user_wrapper_27]

# ==========================================================================
# Shell placement (added 2026-09-15, refined 2026-09-16) -- two-region split.
#
# Background: EN_SHELL_PBLOCK=0 leaves inst_shell unconstrained. First fix pinned
# the whole host/control fabric to SLR0 -> resolved the SLR1 legalization overlap
# ("16 overlapping pblocks", [Place 30-4538]) BUT over-subscribed the SLR0<->SLR1
# SLLs: [Place 30-5425] 22677 required vs 18870 available (build_mesh, 2026-09-15).
#
# Net-crossing analysis on shell_opted.dcp (nets from each pinned cell reaching the
# 28 vFPGAs in inst_dynamic):
#   inst_shell_slave    30      inst_shell_data_cc  1452
#   inst_shell_ctrl_cc  24419  <-- the SLL hog     inst_stats_hch_0  8
# ctrl_cc is the control clock-crossing fanning out to all 28 vFPGAs; pinning it to
# SLR0 forced 24k vFPGA-facing nets across the SLR0<->SLR1 boundary. It belongs
# NEXT TO the vFPGAs (SLR1), where only its ~1300 host-side nets cross.
#
# Region A (hard, SLR0): the genuinely host-side fabric -- axi_main crossbar, the
#   512b data CDC, DMA stats. Small vFPGA-facing footprint (~1490 nets).
create_pblock pblock_shell_host
add_cells_to_pblock [get_pblocks pblock_shell_host] [get_cells {inst_shell/inst_shell_slave inst_shell/inst_shell_data_cc inst_shell/inst_stats_hch_0}]
resize_pblock [get_pblocks pblock_shell_host] -add {SLICE_X0Y0:SLICE_X379Y331}
set_property IS_SOFT FALSE [get_pblocks pblock_shell_host]
# Region B (SOFT, SLR1): the control CDC. SOFT so it yields around the hard vFPGA RP
#   pblocks (no overlap-legalization error) while being pulled to SLR1, next to the
#   28 vFPGAs it drives -> SLR0<->SLR1 SLL demand drops 22677 -> ~2800.
create_pblock pblock_shell_ctrlcc
add_cells_to_pblock [get_pblocks pblock_shell_ctrlcc] [get_cells {inst_shell/inst_shell_ctrl_cc}]
resize_pblock [get_pblocks pblock_shell_ctrlcc] -add {SLICE_X0Y332:SLICE_X379Y619}
set_property IS_SOFT TRUE [get_pblocks pblock_shell_ctrlcc]
