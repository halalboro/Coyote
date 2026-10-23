create_pblock pblock_inst_shell
add_cells_to_pblock [get_pblocks pblock_inst_shell] [get_cells -quiet [list inst_shell]]
resize_pblock [get_pblocks pblock_inst_shell] -add {SLICE_X164Y188:SLICE_X203Y331 SLICE_X144Y0:SLICE_X163Y331 SLICE_X0Y428:SLICE_X27Y903}
resize_pblock [get_pblocks pblock_inst_shell] -add {BLI_A_GRP0_X84Y0:BLI_A_GRP0_X97Y0}
resize_pblock [get_pblocks pblock_inst_shell] -add {BLI_A_GRP1_X84Y0:BLI_A_GRP1_X97Y0}
resize_pblock [get_pblocks pblock_inst_shell] -add {BLI_A_GRP2_X84Y0:BLI_A_GRP2_X97Y0}
resize_pblock [get_pblocks pblock_inst_shell] -add {BLI_B_GRP0_X84Y0:BLI_B_GRP0_X97Y0}
resize_pblock [get_pblocks pblock_inst_shell] -add {BLI_B_GRP1_X84Y0:BLI_B_GRP1_X97Y0}
resize_pblock [get_pblocks pblock_inst_shell] -add {BLI_B_GRP2_X84Y0:BLI_B_GRP2_X97Y0}
resize_pblock [get_pblocks pblock_inst_shell] -add {BLI_C_GRP0_X84Y0:BLI_C_GRP0_X97Y0}
resize_pblock [get_pblocks pblock_inst_shell] -add {BLI_C_GRP1_X84Y0:BLI_C_GRP1_X97Y0}
resize_pblock [get_pblocks pblock_inst_shell] -add {BLI_C_GRP2_X84Y0:BLI_C_GRP2_X97Y0}
resize_pblock [get_pblocks pblock_inst_shell] -add {BLI_D_GRP4_X84Y0:BLI_D_GRP4_X97Y0}
resize_pblock [get_pblocks pblock_inst_shell] -add {BLI_D_GRP5_X84Y0:BLI_D_GRP5_X97Y0}
resize_pblock [get_pblocks pblock_inst_shell] -add {BLI_D_GRP6_X84Y0:BLI_D_GRP6_X97Y0}
resize_pblock [get_pblocks pblock_inst_shell] -add {BLI_D_GRP7_X84Y0:BLI_D_GRP7_X97Y0}
resize_pblock [get_pblocks pblock_inst_shell] -add {BUFG_FABRIC_X2Y48:BUFG_FABRIC_X2Y95}
resize_pblock [get_pblocks pblock_inst_shell] -add {BUFG_GT_X0Y120:BUFG_GT_X0Y239}
resize_pblock [get_pblocks pblock_inst_shell] -add {BUFG_GT_SYNC_X0Y205:BUFG_GT_SYNC_X0Y409}
resize_pblock [get_pblocks pblock_inst_shell] -add {DCMAC_X0Y2:DCMAC_X0Y2}
resize_pblock [get_pblocks pblock_inst_shell] -add {DPLL_X0Y10:DPLL_X0Y19}
resize_pblock [get_pblocks pblock_inst_shell] -add {DSP58_CPLX_X3Y94:DSP58_CPLX_X5Y165 DSP58_CPLX_X3Y0:DSP58_CPLX_X3Y93}
resize_pblock [get_pblocks pblock_inst_shell] -add {DSP_X6Y94:DSP_X11Y165 DSP_X6Y0:DSP_X7Y93}
resize_pblock [get_pblocks pblock_inst_shell] -add {GTM_QUAD_X0Y9:GTM_QUAD_X0Y10}
resize_pblock [get_pblocks pblock_inst_shell] -add {GTM_REFCLK_X0Y18:GTM_REFCLK_X0Y21}
resize_pblock [get_pblocks pblock_inst_shell] -add {HBM_MC_X15Y0:HBM_MC_X15Y0 HBM_MC_X0Y0:HBM_MC_X1Y0}
resize_pblock [get_pblocks pblock_inst_shell] -add {HBM_PHY_CHNL_X15Y0:HBM_PHY_CHNL_X15Y0 HBM_PHY_CHNL_X0Y0:HBM_PHY_CHNL_X1Y0}
resize_pblock [get_pblocks pblock_inst_shell] -add {IRI_QUAD_X0Y3660:IRI_QUAD_X17Y3671 IRI_QUAD_X1Y3648:IRI_QUAD_X16Y3659 IRI_QUAD_X0Y2892:IRI_QUAD_X17Y3647 IRI_QUAD_X0Y1740:IRI_QUAD_X3Y2507 IRI_QUAD_X92Y780:IRI_QUAD_X134Y1355 IRI_QUAD_X92Y16:IRI_QUAD_X106Y779 IRI_QUAD_X94Y4:IRI_QUAD_X105Y15 IRI_QUAD_X92Y0:IRI_QUAD_X106Y3}
resize_pblock [get_pblocks pblock_inst_shell] -add {MRMAC_X0Y2:MRMAC_X0Y4}
resize_pblock [get_pblocks pblock_inst_shell] -add {NOC_NMU512_X1Y4:NOC_NMU512_X1Y6}
resize_pblock [get_pblocks pblock_inst_shell] -add {NOC_NMU_HBM2E_X61Y0:NOC_NMU_HBM2E_X63Y0 NOC_NMU_HBM2E_X0Y0:NOC_NMU_HBM2E_X5Y0}
resize_pblock [get_pblocks pblock_inst_shell] -add {NOC_NPS_VNOC_X1Y8:NOC_NPS_VNOC_X1Y13}
resize_pblock [get_pblocks pblock_inst_shell] -add {NOC_NSU512_X1Y4:NOC_NSU512_X1Y6}
resize_pblock [get_pblocks pblock_inst_shell] -add {RAMB18_X6Y96:RAMB18_X7Y167 RAMB18_X5Y2:RAMB18_X5Y167 RAMB18_X0Y216:RAMB18_X0Y455}
resize_pblock [get_pblocks pblock_inst_shell] -add {RAMB36_X6Y48:RAMB36_X7Y83 RAMB36_X5Y1:RAMB36_X5Y83 RAMB36_X0Y108:RAMB36_X0Y227}
resize_pblock [get_pblocks pblock_inst_shell] -add {URAM288_X3Y48:URAM288_X4Y83 URAM288_X3Y1:URAM288_X3Y47}
resize_pblock [get_pblocks pblock_inst_shell] -add {URAM_CAS_DLY_X3Y2:URAM_CAS_DLY_X4Y3 URAM_CAS_DLY_X3Y0:URAM_CAS_DLY_X3Y1}
# Phase 2 (Strategy B): SLR0-only shell, SLR1 and SLR2 fully freed for vFPGAs.
#
# Empirical justification (from build_test of Strategy A in
# examples/07_perf_fpga/hw/build_test/reports/shell_utilization.rpt):
#   SLR0  19,515 SLICEs used  (17.34%)
#   SLR1  0 SLICEs used   ← shell did not use the corridor at all
#   SLR2  0 SLICEs used   ← shell did not use SLR2
#   SLLs  0 used in either direction
#
# The shell genuinely doesn't need any SLR1/SLR2 fabric for this build
# configuration (no EN_RDMA, no EN_TCP, no EN_MEM). Strategy B drops the
# SLR1 corridor entirely and removes SLR2 from the pblock, freeing ~50
# CRs across the upper two SLRs for vFPGAs in a regular mesh layout.
#
# What remains in the pblock:
#   SLR0 fabric (CR Y0..Y4):  shell logic + CPM5 NoC interface
#   SLR1 row Y4 only:         retains SLR0/SLR1 boundary routing CRs
#   SLR2/SLR1 rows Y5..Y11:   REMOVED -- now available for vFPGA pblocks
#
# NoC tile carry-forward (separate resize_pblock lines above):
#   NOC_NMU512_X1Y4:X1Y6, NOC_NSU512_X1Y4:X1Y6 stay shell-owned.
#   NOC_NMU_HBM2E_X0..5/X61..63 (HBM access) stay shell-owned.
#   NOC_NPS_VNOC_X1Y8:Y13 (vertical routing through SLR2) stay shell-owned.
#   Other NoC tiles (X3, X5, X7 columns in SLR1/SLR2) become available
#   for per-vFPGA NMU/NSU instances in the mesh layout.
#
# If a future shell config (EN_RDMA, EN_TCP, EN_MEM) needs SLR1/SLR2 area,
# revert to Strategy A by widening these ranges.
resize_pblock [get_pblocks pblock_inst_shell] -add {CLOCKREGION_X5Y3:CLOCKREGION_X9Y4 CLOCKREGION_X4Y1:CLOCKREGION_X8Y2 CLOCKREGION_X5Y0:CLOCKREGION_X10Y0}
# Enlarge the shell pblock to cover the full SLR1 (CR rows Y5-7) and SLR2 (Y8-10)
# so the 32 vFPGAs fit -- but as PURE SITE RANGES (SLICE/BRAM/DSP/URAM), NOT full
# CLOCKREGIONs.
#
# WHY NOT full CLOCKREGIONs (the previous approach, reverted here): a
# `-add CLOCKREGION_X0Y5:...` grab takes the ENTIRE clock region -- including the
# column-X0 vertical clock/interconnect spine that carries CPM5(X0Y0) and
# PS9(X0Y0-2) ground up out of SLR0. With that spine owned by the reconfigurable
# shell partition, the static GND tie-off cannot route and route_design dies with
#   [Route 35-534] Boundary Net GNDNet not completely routed
#   (6492 CPM5 + 3020 PS9 unroutable pins; "Site pin does not reach interconnect
#   fabric").
# A SLICE/BRAM/DSP/URAM site range claims only those hard-block SITES; the INT /
# clock / NoC tiles in the same clock regions stay static-owned, so the global
# GNDNet still routes. This is exactly the shipped base pblock's style (lines
# above: SLICE_X0Y428:.. + explicit RAMB/DSP/URAM/NoC tiles) -- proven GND-safe on
# the shipped static_routed_locked_v80_gen5.dcp. SLICE_X0 columns are included and
# are safe (the base already owns SLICE_X0Y428:X903 and routes GND); only the
# INT/clock spine, which site ranges never touch, must stay static.
#
# Coordinates enumerated live from the device (link_design -part xcv80... ;
# get_sites + CLOCK_REGION property): full SLR1 = CR rows Y5-7, full SLR2 = Y8-10.
# The two SLICE rects below are the exact per-SLR bounding boxes (n=102528 = all of
# SLR1, n=106720 = all of SLR2). SLR0 (line 66) left untouched -- its X4-X10 CRs do
# not touch the X0 CPM5/PS9 spine, so they are not the GND culprit.
resize_pblock [get_pblocks pblock_inst_shell] -add {SLICE_X0Y332:SLICE_X379Y619 SLICE_X0Y620:SLICE_X391Y903}
# Hard-block columns (BRAM/DSP/URAM) are sparse -- their bounding-box corners are
# not always real sites, so a coordinate range like DSP58_X0Y166:DSP58_X23Y451 is
# rejected ([Place 30-342] invalid range). Add them as get_sites object lists
# filtered to the SLR1+SLR2 clock-region rows (Y5-10) instead.
#
# XDC-STRICT: NO Tcl loops -- Vivado silently drops `foreach` from XDC files
# ([Designutils 20-1307] "Command 'foreach' is not supported in the xdc constraint
# file"), which leaves the pblock without the hard-block sites and yields the
# original edge-strip capacity (2186 RAMB18) at place_design DRC. Inline command
# substitution (`[get_sites -filter ...]`) IS accepted in XDC, so the four adds
# below are pure XDC. The CLOCK_REGION glob "*Y5..*Y10" covers exactly SLR1+SLR2
# (V80 rows are Y0..Y11; there is no Y12+, so *Y5 cannot accidentally match Y50).
resize_pblock [get_pblocks pblock_inst_shell] -add [get_sites -quiet -filter {SITE_TYPE =~ RAMB18*  && (CLOCK_REGION =~ *Y5 || CLOCK_REGION =~ *Y6 || CLOCK_REGION =~ *Y7 || CLOCK_REGION =~ *Y8 || CLOCK_REGION =~ *Y9 || CLOCK_REGION =~ *Y10)}]
resize_pblock [get_pblocks pblock_inst_shell] -add [get_sites -quiet -filter {SITE_TYPE =~ RAMB36*  && (CLOCK_REGION =~ *Y5 || CLOCK_REGION =~ *Y6 || CLOCK_REGION =~ *Y7 || CLOCK_REGION =~ *Y8 || CLOCK_REGION =~ *Y9 || CLOCK_REGION =~ *Y10)}]
resize_pblock [get_pblocks pblock_inst_shell] -add [get_sites -quiet -filter {SITE_TYPE =~ URAM288* && (CLOCK_REGION =~ *Y5 || CLOCK_REGION =~ *Y6 || CLOCK_REGION =~ *Y7 || CLOCK_REGION =~ *Y8 || CLOCK_REGION =~ *Y9 || CLOCK_REGION =~ *Y10)}]
resize_pblock [get_pblocks pblock_inst_shell] -add [get_sites -quiet -filter {SITE_TYPE =~ DSP58*   && (CLOCK_REGION =~ *Y5 || CLOCK_REGION =~ *Y6 || CLOCK_REGION =~ *Y7 || CLOCK_REGION =~ *Y8 || CLOCK_REGION =~ *Y9 || CLOCK_REGION =~ *Y10)}]
# P2P Network-3 NoC endpoints (reconfigurable, instantiated in shell_top; placed by
# xdc/p2p_noc_conn.xdc). Full CLOCKREGIONs used to sweep these tiles into the shell
# partition; site ranges do not, so add the 8 endpoint tiles explicitly -- otherwise
# a reconfigurable NoC endpoint lands on a static-owned NoC tile (HDPR-116 illegal
# placement / GND tie-off failure on its unused sideband pins).
# SLR-SPREAD (must match the LOCATION pins in p2p_noc_conn_tmplt.txt):
#   SLR1 send NMU  X0Y8,X1Y8   (CR X1Y5,X3Y5)    SLR2 send NMU  X2Y13,X3Y13 (CR X5Y8,X7Y8)
#   SLR1 recv NSU  X0Y12,X1Y12 (CR X1Y7,X3Y7)    SLR2 recv NSU  X2Y17,X3Y17 (CR X5Y10,X7Y10)
resize_pblock [get_pblocks pblock_inst_shell] -add {NOC_NMU512_X0Y8:NOC_NMU512_X1Y8}
resize_pblock [get_pblocks pblock_inst_shell] -add {NOC_NMU512_X2Y13:NOC_NMU512_X3Y13}
resize_pblock [get_pblocks pblock_inst_shell] -add {NOC_NSU512_X0Y12:NOC_NSU512_X1Y12}
resize_pblock [get_pblocks pblock_inst_shell] -add {NOC_NSU512_X2Y17:NOC_NSU512_X3Y17}
set_property SNAPPING_MODE ON [get_pblocks pblock_inst_shell]
set_property IS_SOFT FALSE [get_pblocks pblock_inst_shell]