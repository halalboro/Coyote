######################################################################################
# Coyote Example 16: BRAID
#   Bidirectional Rapid Anyon Interconnect for Decoders
#
# Low-latency QEC syndrome transport between two FPGAs. Phase 1 runs the BRAID
# protocol core over the proven Aurora path so framing, checksums, round
# counting and gap detection can be validated on working hardware. Phase 2
# swaps the PHY for a raw GTY (8B/10B, buffer bypass) to reach <100 ns one-way;
# the protocol core is unchanged by that swap.
#
# See docs/superpowers/specs/2026-08-05-syndrome-link-design.md
######################################################################################

cmake_minimum_required(VERSION 3.5)
set(CYT_DIR ${CMAKE_SOURCE_DIR}/../../../)
set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} ${CYT_DIR}/cmake)
find_package(CoyoteHW REQUIRED)

project(example_16_braid)
message("*** Coyote Example 16: BRAID syndrome link [Hardware] ***")

set(N_REGIONS 1)

# Raw GTY on QSFP1: single lane, 10.3125 Gbps, 8B/10B. Presents the same
# 256-bit AXIS interface to the vFPGA that EN_AURORA_1 does, so the dynamic and
# user templates are shared. The two are mutually exclusive (same cage, same
# vFPGA ports) and CMake will error if both are set.
set(EN_BRAID_GTY 1)
set(EN_AURORA_1  0)

set(EN_NET_0  0)
set(EN_NET_1  0)
set(EN_RDMA   0)
set(EN_TCP    0)

# BRAID needs no host DMA -- syndromes are generated and checked in fabric, and
# only CSRs cross PCIe -- but EN_STRM must stay 1 anyway.
#
# With EN_STRM=0 and no card memory, hw/hdl/mmu/tlb_fsm.sv fails to elaborate:
# ST_CARD_SEND is declared only under `ifdef EN_MEM (line ~118), yet the `else
# branch of `ifdef EN_STRM assigns it unguarded (lines ~546 and ~559). That
# combination is untested upstream -- every other example enables one or the
# other. Cheaper to keep the host stream infrastructure built and unused than to
# patch shared Coyote code; the vFPGA ties off axis_host_recv/send anyway.
set(EN_STRM   1)
set(N_STRM_AXI 1)

set(BUILD_OPT 1)

validation_checks_hw()

load_apps (
    VFPGA_C0_0 "src"
)

create_hw()
