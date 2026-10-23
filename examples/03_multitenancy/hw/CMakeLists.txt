######################################################################################
# This file is part of the Coyote <https://github.com/fpgasystems/Coyote>
# 
# MIT Licence
# Copyright (c) 2025, Systems Group, ETH Zurich
# All rights reserved.
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
######################################################################################

# CMake configuration
cmake_minimum_required(VERSION 3.16)
set(CYT_DIR ${CMAKE_SOURCE_DIR}/../../../)
set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} ${CYT_DIR}/cmake)
find_package(CoyoteHW REQUIRED)

project(example_03_multitenancy)
message("*** Coyote Example 3: Multiple, Parallel AES Encryption Blocks [Hardware] ***")

# Number of vFPGAs (parallel user applications).
# Default 32, but honor a command-line -DN_REGIONS=<n> override (find_package sets
# the cache default to 1; a plain set() here would otherwise clobber -D).
if(NOT N_REGIONS OR N_REGIONS EQUAL 1)
    set(N_REGIONS 32)
endif()

# Enables host memory streams
set(EN_STRM 1)

# Build with optimizations for easier timing closure
set(BUILD_OPT 1)

# Confirm that the selected options are allowed
validation_checks_hw()

# Loads the four user applications (more on the meaning of C0 in Example 10)
# src corresponds to the folder which includes the vfpga_top.svh file and the RTL/HLS kernel
# There is absolutely no requirement that the individual applications point to different source folders.
# 32 small loopback vFPGAs (src_min) for the shared-hub P2P mesh bring-up.
# The heavy AES logic in "src" does not fit 32x and does not exercise P2P.
# Build the per-vFPGA app list dynamically so it scales with N_REGIONS (all src_min,
# single config C0). Avoids hardcoding a fixed vFPGA count.
math(EXPR _p2p_n_minus1 "${N_REGIONS} - 1")
set(_p2p_apps "")
foreach(_i RANGE 0 ${_p2p_n_minus1})
    list(APPEND _p2p_apps VFPGA_C0_${_i} "src_min")
endforeach()
load_apps(${_p2p_apps})

# Create the hardware project
create_hw()
