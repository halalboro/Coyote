######################################################################################
# This file is part of the Coyote <https://github.com/fpgasystems/Coyote>
#
# MIT Licence
# Copyright (c) 2026, Systems Group, ETH Zurich
# All rights reserved.
######################################################################################

# CMake configuration
cmake_minimum_required(VERSION 3.5)
set(CYT_DIR ${CMAKE_SOURCE_DIR}/../../../)
set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} ${CYT_DIR}/cmake)
find_package(CoyoteHW REQUIRED)

project(example_13_micro_blossom)
message("*** Coyote Example 13: Micro Blossom QEC Decoder [Hardware] ***")

# Single vFPGA, host-driven control only (no data streams, no card memory)
set(N_REGIONS 1)
set(EN_STRM 1)
set(N_STRM_AXI 1)
set(EN_MEM 0)

# Confirm that the selected options are allowed
validation_checks_hw()

# Load a user application in Configuration #0, Region #0
load_apps (
    VFPGA_C0_0 "src"
)

# Create the hardware project
create_hw()
