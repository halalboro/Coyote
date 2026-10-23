######################################################################################
# Coyote Example 16: V80 200G DCMAC raw Ethernet echo [Hardware]
#
# Brings up the Versal DCMAC on the V80's QSFP56 cage and echoes whole Ethernet
# frames back to the peer with the MAC addresses swapped. The network stack is
# bypassed, so the vFPGA is the MAC client and owns the entire frame.
#
# Requires:
#   - Vivado 2025.1 or newer (DCMAC block design)
#   - a 200GAUI-4 peer or a QSFP56 loopback module in the cage
#   - the cage powered up and out of low-power mode; on the V80 that is the AVED
#     satellite controller's job (ami_tool), not the PL's
######################################################################################

cmake_minimum_required(VERSION 3.5)
set(CYT_DIR ${CMAKE_SOURCE_DIR}/../../../)
set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} ${CYT_DIR}/cmake)
find_package(CoyoteHW REQUIRED)

project(example_16_dcmac)
message("*** Coyote Example 16: V80 200G DCMAC raw Ethernet [Hardware] ***")

set(FDEV_NAME "v80")
set(N_REGIONS 1)

# Raw Ethernet to vFPGA 0, network stack bypassed. This also forces EN_NET=1.
set(EN_NET_RAW 1)
set(NET_RAW_VFPGA_ID 0)

# Which DCMAC site, and therefore which QSFP cage:
#   EN_NET_0 -> DCMAC_X1Y1, GTM_QUAD_X1Y7, bank 209, refclk AR51 -> qsfp0
#   EN_NET_1 -> DCMAC_X0Y2, GTM_QUAD_X0Y9, bank 111, refclk AL17 -> qsfp3
# The back-to-back cable to the peer V80 is in cage 3, so index 1.
set(EN_NET_0 0)
set(EN_NET_1 1)

# Everything above the MAC needs the stack that EN_NET_RAW removes.
set(EN_RDMA    0)
set(EN_TCP     0)
set(EN_SNIFFER 0)
set(EN_STATS   0)

# The DCMAC and its GT quad cannot sit inside a reconfigurable partition, so the
# shell must not be floorplanned as one. With BUILD_STATIC=1 the whole design is
# linked flat, which satisfies that.
#
# BUILD_STATIC already covers static + shell, and BUILD_SHELL defaults to 1 in
# the cache, so it has to be cleared here or validation_checks_hw sees two build
# flows selected and stops with "Choose one build flow."
set(BUILD_STATIC 1)
set(BUILD_SHELL 0)
set(BUILD_APP 0)
set(EN_SHELL_PBLOCK 0)
set(EN_PR 0)

# Host streams stay on so the vFPGA boundary keeps its usual shape; this example
# ties them off and moves no data over PCIe beyond CSR reads and writes.
set(EN_STRM   1)
set(N_STRM_AXI 1)

# 512 b x 400 MHz = 204.8 Gb/s, comfortably above the DCMAC's 200 Gb/s line
# rate, so a full-rate receive burst cannot overrun the RX CDC FIFO. CMake
# raises NCLK_F to this by default on Versal network builds; set explicitly
# here so the intent survives someone changing that default.
set(NCLK_F 400)
set(ACLK_F 400)

set(BUILD_OPT 1)

validation_checks_hw()

load_apps (
    VFPGA_C0_0 "src"
)

create_hw()
