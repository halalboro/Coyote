######################################################################################
# Coyote Example 15: R5 Co-processor Provider [Hardware]
#
# Exercises the on-card R5<->vFPGA channel over Theo's co-processor provider
# (R5-as-master, M_AXI_LPD), superseding the earlier OCM/S_AXI_LPD self-test.
#
# Roles: the R5 is the master/orchestrator; the vFPGA is a co-processor SLAVE.
# The R5 firmware sends request packets, the vFPGA computes (PING/INC/ADD/SUM)
# and returns a result, and the R5 mirrors a verdict into the vFPGA MMIO
# aperture. The host binds the provider once (co-processor control CSR) and
# reads that verdict back over BAR4.
#
# Builds:
#   - Static layer (rebuilt) with the bare V80 R5-0 platform (M_AXI_LPD scratch)
#   - Shell as usual, with the co-processor provider stack + gateway
#   - r5_provider.elf (R5 firmware) injected into the PDI as an rpu_subsystem
#     delay-handoff image (core=r5-0), same path as AMC's amc.elf
#
# Success criterion: host reads the vFPGA verdict MAGIC (0x52355650 "R5VP") and
# PASS on all four opcodes. See sw/src/main.cpp and README.md.
######################################################################################

cmake_minimum_required(VERSION 3.5)
set(CYT_DIR ${CMAKE_SOURCE_DIR}/../../../)
set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} ${CYT_DIR}/cmake)
find_package(CoyoteHW REQUIRED)

project(example_15_r5_coprocessor)
message("*** Coyote Example 15: R5 Co-processor Provider [Hardware] ***")

set(N_REGIONS 1)

# Bare R5-0 static platform (M_AXI_LPD scratch) + the co-processor provider.
# Mutually exclusive with EN_AMC (both would collide on the R5/LPD window).
# Requires a static rebuild because the platform modifies design_static.
set(EN_V80_R5_PLATFORM 1)
set(EN_V80_R5_PROVIDER 1)
set(N_COPROCESSOR_PORTS 1)
# Static-only flow: the R5 platform changes CIPS, so a shell-only build is not
# valid here. Force exactly one build flow (BUILD_SHELL defaults to 1).
set(BUILD_STATIC 1)
set(BUILD_SHELL 0)
set(BUILD_APP 0)
# Disable the shell floorplan: this is a static build (no shell reconfiguration),
# and the shell pblock (pblock_inst_shell, SLR1/2) squeezes the static NoC endpoints
# into SLR0 and strands X0/X1-column NoC-tile GND -> the CPM/QDMA route failure.
# Allowed for BUILD_STATIC=1. See Theo's v80-notes.rst + our AMC floorplan history.
set(EN_SHELL_PBLOCK 0)

# No networking / RDMA / TCP for this bring-up. Host streams enabled so the
# vFPGA has a host datapath (perf_local +1 loopback) alongside the co-processor.
set(EN_NET_0  0)
set(EN_NET_1  0)
set(EN_RDMA   0)
set(EN_TCP    0)
set(EN_STRM   1)
set(N_STRM_AXI 1)

# Build with optimization
set(BUILD_OPT 1)

# Register the R5-0 as the physical provider behind logical co-processor port 0.
register_coprocessor_provider(
    NAME v80-r5-0
    TOP r5_coprocessor_provider_stack
    ENDPOINT_ID 1
    PROCESSOR_CLASS r5
    RUNTIME_ABI baremetal
    FIRMWARE_ABI coyote-r5-provider-mmio-v1
    STREAM_ABI 1
    MMIO_ABI 1
)

validation_checks_hw()

load_apps (
    VFPGA_C0_0 "src"
)

create_hw()
