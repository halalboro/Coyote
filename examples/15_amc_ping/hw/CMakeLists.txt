######################################################################################
# Coyote Example 15: AMC Ping [Hardware]
#
# First-light test for AVED Management Controller (AMC) firmware on V80 RPU.
# Builds:
#   - Static layer (rebuilt) with DDR4 + GCQ + rpu_sc plumbing
#   - Shell as usual
#   - amc.elf (R5 firmware, FreeRTOS) injected into the PDI via fix_bif.py
#
# Success criterion: host reads AMC's partition-table magic (0x564D5230) from
# DDR4 over PCIe BAR4. See sw/src/main.cpp and README.md.
######################################################################################

cmake_minimum_required(VERSION 3.5)
set(CYT_DIR ${CMAKE_SOURCE_DIR}/../../../)
set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} ${CYT_DIR}/cmake)
find_package(CoyoteHW REQUIRED)

project(example_15_amc_ping)
message("*** Coyote Example 15: AMC Ping [Hardware] ***")

set(N_REGIONS 1)

# AMC bringup: pulls in GCQ, rpu_sc, axi_noc_mc_ddr4_0, AMC firmware build.
set(EN_AMC 1)

# Static rebuild is mandatory because EN_AMC=1 modifies design_static.
set(BUILD_STATIC 1)

# Phase A doesn't need networking / RDMA / TCP / sniffer. AMC owns the
# R5 + DDR4; the vFPGA just exists to satisfy Coyote's "at least one region" requirement.
set(EN_NET_0  0)
set(EN_NET_1  0)
set(EN_RDMA   0)
set(EN_TCP    0)

# Host streams enabled so the vFPGA has something to be connected to.
set(EN_STRM   1)
set(N_STRM_AXI 1)

# Build with optimization
set(BUILD_OPT 1)

validation_checks_hw()

load_apps (
    VFPGA_C0_0 "src"
)

create_hw()
