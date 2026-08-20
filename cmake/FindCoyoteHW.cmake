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

############################################
##         COYOTE HARDWARE PACKAGE        ##
############################################
# @brief Set-up the necessary config, dependencies and software to build the Coyote hardware

cmake_minimum_required(VERSION 3.5)

set(IPREPO_DIR ${CMAKE_BINARY_DIR}/iprepo)
file(MAKE_DIRECTORY ${IPREPO_DIR})

############################################
##            USER CONFIGURATION          ##
############################################
# Target FPGA device; supported Alveo U55C, Alveo U280, Alveo U250, Alveo V80
set(FDEV_NAME "0" CACHE STRING "Target FPGA device")

##
## BUILD CONFIGURATION
##

# Number of vFPGAs
set(N_REGIONS 1 CACHE STRING "Number of vFPGAs")

# Re-builds the static layer of Coyote, alongside the standard shell and app build
# Not recommended for most users, as the static layer is not configurable and will very rarey require code changes
set(BUILD_STATIC 0 CACHE STRING "Static build flow: static + shell")

# Builds the Coyote shell (dynamic + app layer) and links against an existing static layer checkpoint
# Recommended for most users, since it's much faster than BUILD_STATIC and the shell is the configurable part of Coyote
set(BUILD_SHELL 1 CACHE STRING "Build shell, linking against existing design check-point")

# Build the user logic (vFPGA) and link it against an existing shell 
set(BUILD_APP 0 CACHE STRING "Build app portion of the design (on top of existing shell config)")

# Packetization size; data transfers (host, card or net) of size > PMTU_BYTES are split into multiple packets
set(PMTU_BYTES 4096 CACHE STRING "Packetization size [B]")

# Unit tests/Simulation
set(UNIT_TEST_DIR "${CMAKE_SOURCE_DIR}/unit-tests" CACHE STRING "Path to the unit-test folder.")
set(SIM_DPI_LIB_NAME "coyote_sim" CACHE STRING "Name of the DPI-C library to link for simulation WITHOUT the '.so' extension.")
set(SIM_CLOCK_PERIOD "4ns" CACHE STRING "Clock period used in the simulation. Can have one of the following extensions: fs, ps, ns, us, ms, sec")

##
## MEMORY & STREAMS
##

# Enable streams from host
set(EN_STRM 1 CACHE STRING "Enable host streams")

# Number of parallel streams from host (per vFPGA)
set(N_STRM_AXI 1 CACHE STRING "Number of host streams")

# Number of processor-neutral logical co-processor ports per vFPGA. Physical
# processor providers are registered independently and bind at runtime.
set(N_COPROCESSOR_PORTS 0 CACHE STRING "Number of logical co-processor ports")

# Enable streams from card memory (HBM/DDR)
set(EN_MEM 0 CACHE STRING "Enable memory streams")

# Number of parallel streams from card memory (per vFPGA)
set(N_CARD_AXI 1 CACHE STRING "Number of memory streams")

# Enable automatic placement of DDRs (only applicable for DDR-enabled UltraScale+ devices)
set(DDR_AUTO 1 CACHE STRING "Automatic placement of DDRs")

# Striping fragmentation size
# NOTE: On UltraScale+ HBM devices, this variable has no effect, since striping is done through the RAMA IP with the default fragmentation size
set(STRIPE_FRAG_SIZE 1024 CACHE STRING "Stripe fragment size")

# Concatenate HBM bank ports to achieve higher throughput
# Currently only supported on HBM-enabled UltraScale+ devices; may be supported on Versal devices in the future
set(HBM_SPLIT 0 CACHE STRING "Concatenate HBM ports to achieve higher throughput")

# HBM implementation on Versal devices; parameter ignored on UltraScale+ devices
# See hw/bd/versal/cr_hbm.tcl for more details
set(HBM_IMPL "unified" CACHE STRING "HBM implementation on Versal devices, available: unified or block")

set(DATA_DEST_BITS 4 CACHE STRING "Number of bits used to address the coyote stream index.")
set(VADDR_BITS 48 CACHE STRING "Bits of a virtual address used e.g. in the MMU.")

##
## TLB
##
# Regular-pages TLB size; TLB size is 2 ** 10; increase if facing page faults but keep in mind BRAM usage
set(TLBS_S 10 CACHE STRING "TLB (small) size")

# Regular-pages TLB associativity
set(TLBS_A 4 CACHE STRING "TLB (small) associativity")

# Regular-pages TLB page order: 2 ^ TLBS_BITS should corresponds to your regular page size (2 ^ 12 = 4KB, indeed regular page in Linux)
# Modify only if page size is not 4KB
set(TLBS_BITS 12 CACHE STRING "TLB (small) page order")

# Huge-pages TLB size; TLB size is 2 ** 9; increase if facing page faults but keep in mind BRAM usage
set(TLBL_S 9 CACHE STRING "TLB (huge) size")

# Huge-pages TLB associativity
set(TLBL_A 2 CACHE STRING "TLB (huge) associativity")

# Huge-pages TLB page order: 2 ^ TLBL_BITS should corresponds to your huge page size (2 ^ 21 = 2MB, indeed huge page in Linux)
# Modify only if page size is not 2MB; e.g. if you use 1GB huge pages
set(TLBL_BITS 21 CACHE STRING "TLB (huge) page order")

# Use NRU eviction policy
set(EN_NRU 0 CACHE STRING "Enable NRU eviction policy")

# Number of outstanding requests in MMU
set(N_TLB_ACTV 16 CACHE STRING "Number of outstanding PMTUs in MMU")

##
## NETWORKING
##
# Enable RDMA stack
set(EN_RDMA 0 CACHE STRING "Enable RDMA stack")

# Number of RDMA streams, per vFPGA
set(N_RDMA_AXI 1 CACHE STRING "Number of RDMA streams")

# Enable TCP/IP stack
set(EN_TCP 0 CACHE STRING "Enable TCP/IP stack.")

# Number of TCP/IP streams, per vFPGA
set(N_TCP_AXI 1 CACHE STRING "Number of TCP/IP streams")

# Packet sniffer
set(EN_SNIFFER 0 CACHE STRING "Enable packet sniffer.")
set(SNIFFER_VFPGA_ID 0 CACHE STRING "ID of vFPGA to receive packet sniffer data stream.")

# Use QSFP port 0
set(EN_NET_0 1 CACHE STRING "QSFP port 0")

# Use QSFP port 1
set(EN_NET_1 0 CACHE STRING "QSFP port 1")

# Aurora 64B/66B on QSFP1 (4 lanes @ 25.78125 Gbps).
# Mutually exclusive with EN_NET_1 (both occupy the same physical QSFP1 cage).
# When EN_AURORA_1=1, the shell instantiates an Aurora IP in parallel to CMAC
# (which stays on QSFP0 when EN_NET_0=1). Aurora's user-side AXIS is brought
# into each vFPGA as axis_aurora_rx / axis_aurora_tx.
set(EN_AURORA_1 0 CACHE STRING "Enable Aurora 64B/66B on QSFP1")

# Number of Aurora streams per vFPGA (currently always 1; reserved for future fan-out)
set(N_AURORA_AXI 1 CACHE STRING "Number of Aurora streams per vFPGA")

##
## AVED MANAGEMENT CONTROL (AMC) firmware bringup on V80
##
# When EN_AMC=1, the V80 shell adds:
#   - GCQ (Generic Command Queue) IP between PCIe (S00) and APU/RPU (S01)
#   - Optional HW Discovery + UUID ROM (Tier 1 from docs/AVED_vs_Coyote.md row 4/6)
# Plus the build flow gains an AMC firmware pass that emits amc.elf and merges
# it into the PMC BIF.
#
# Requires AVED's iprepo (cmd_queue_v2_0, hw_discovery_v1_0, shell_utils_uuid_rom_v2_0).
# AVED_IPREPO_PATH must point to AVED/hw/<release>/src/iprepo. Felix's tree at
# /scratch/felix/aved/AVED/hw/amd_v80_gen5x8_25.1/src/iprepo is the default on rose.
set(EN_AMC 0 CACHE STRING "Enable AVED Management Control (AMC) firmware integration on V80")
set(AVED_IPREPO_PATH "/scratch/felix/aved/AVED/hw/amd_v80_gen5x8_25.1/src/iprepo"
    CACHE STRING "Path to AVED iprepo containing cmd_queue, hw_discovery, uuid_rom IPs")

##
## RECONFIGURATION
##
# Enable application (vFPGA) reconfiguration
set(EN_PR 0 CACHE STRING "Enable application-level (vFPGA) reconfiguration")

# Number of PR configurations; in total N_CONFIG x N_REGION apps must be provided; for more details see Example 9: Partial Reconfiguration
set(N_CONFIG 1 CACHE STRING "Number of PR configurations (for each vFPGA)")

# Floorplan for PR; for more details on floorplans, Example 9: Partial Reconfiguration 
set(FPLAN_PATH 0 CACHE STRING "Path to vFPGA floorplan; only applicable if EN_PR=1")

# Number of clock cycles after which the loaded app is considered valid (due to the ICAP done signal being lost if crossing SLR regions on the U55C)
set(EOS_TIME 1000000 CACHE STRING "End of startup time.")

# Enable inter-vFPGA AXI-Stream ring
# When EN_P2P=1 and N_REGIONS>1, each vFPGA exposes axis_p2p_send (master) and
# axis_p2p_recv (slave) ports at AXI_DATA_BITS wide. In dynamic_top these are
# wired in a ring: wrapper[i].axis_p2p_send -> wrapper[(i+1) mod N].axis_p2p_recv.
# Provides zero-DRAM inter-vFPGA data movement for pipelined multi-vFPGA
# workloads. On Versal, the ring wires cross SLR boundaries via SLLs.
# Future: replace ring with hardened NoC AXIS mesh (needs static rebuild).
set(EN_P2P 0 CACHE STRING "Enable inter-vFPGA AXI-Stream ring (only meaningful when N_REGIONS>1)")

# Enable explicit floor-planning & reconfiguration of the shell.
# With a floorplan, it's possible to reuse an existing routed checkpoint of the static layer, as well as do run-time shell reconfiguration
# However, if disabled, it may be possible to achieve higher clock frequencies and better timing closure
# Additionally, on Versal devices, which do not support nested DFX, shell reconfiguration must be disabled if application-level reconfiguration (EN_PR=1) is enabled
set(EN_SHELL_PBLOCK 1 CACHE STRING "Enable shell pblock (floorplanning and reconfiguration)")

##
## CLOCKS
##
# Default system clock
set(ACLK_F 400 CACHE STRING "System clock frequency")

# Enable clock domain crossing for the network stack
set(EN_NCLK 1 CACHE STRING "Network clock crossing (250 MHz by default)")

# Target network clock crossing, if EN_NCLK=1
set(NCLK_F 250 CACHE STRING "Network clock frequency")

# Enable clock domain crossing for the user logic
set(EN_UCLK 0 CACHE STRING "User clock crossing (300 MHz by default)")

# Target user logic clock crossing, if EN_UCLK=1
set(UCLK_F 250 CACHE STRING "User clock frequency")

# Static layer clock frequency; only applicable to Versal devices,
# since it can be dynamically generated from the CIPS
# On UltraScale+ devices, it is always 250 MHz
# For PCIe Gen4x16 or Gen5x8, it's recommended to set it and ACLK_F to 400 MHz
set(SCLK_F 400 CACHE STRING "Static layer clock frequency")

# On Versal devices (V80), users can choose between PCIe Gen4x16 or Gen5x8
# Both offer the same theoretical throughput (32 GB/s), but can lead to different timing closure
# Additionally, using PCIe Gen5x8 leaves room for one more QDMA core at Gen5x8, therefore up to 64 Gb/s
set(PCIE_GEN 5 CACHE STRING "Versal PCIe configuration: Gen4x16 or Gen5x8")

# Enable the V80 R5-0 hardware-platform slice in the persistent static layer.
# This only exposes the processor and a bounded LPD scratch target; it does not
# register R5 as a logical co-processor provider.
set(EN_V80_R5_PLATFORM 0 CACHE STRING "Enable the V80 R5-0 static platform")
set(V80_R5_PROCESSOR "psv_cortexr5_0")
set(V80_R5_LPD_DATA_BITS 32)
set(V80_R5_LPD_CLOCK_HZ 33333333)
set(V80_R5_SCRATCH_BASE 2147483648) # 0x80000000
set(V80_R5_SCRATCH_BYTES 4096)
set(V80_R5_ATCM_BASE 0)
set(V80_R5_ATCM_BYTES 65536)
set(V80_R5_BTCM_BASE 131072) # 0x00020000
set(V80_R5_BTCM_BYTES 65536)

# Bind the V80 R5-0 platform to one processor-neutral logical port through the
# shell-resident bounded polling backend. Static and shell builds must enable
# this independently so their checkpoint boundary is identical.
set(EN_V80_R5_PROVIDER 0 CACHE STRING "Enable the V80 R5-0 co-processor provider")
set(V80_R5_PROVIDER_BASE 2147549184) # 0x80010000
set(V80_R5_PROVIDER_BYTES 65536)
set(V80_R5_PROVIDER_QUEUE_DEPTH 4)
set(V80_R5_PROVIDER_ENDPOINT_ID 1)
set(V80_R5_PROVIDER_RUNTIME_ABI "baremetal")
set(V80_R5_PROVIDER_FIRMWARE_ABI "coyote-r5-provider-mmio-v1")

# Clock uncertainty for HLS synthesis; default 27% since HLS estimates can be different from the actual PnR
# Therefore, HLS synthesis should always be performed conservatively, with a higher clock uncertainty
set(HLS_CLOCK_UNCERTAINTY "27" CACHE STRING "HLS synthesis clock uncertainty [%]")

##
## DEBUG & SYSTEM
##
# Enable sysfs statistics in the driver
set(EN_STATS 1 CACHE STRING "Enable driver sysfs statistics")

# Enable AVX (for host CPUs which include AVX), enabling faste data transfer
set(EN_AVX 1 CACHE STRING "AVX environment")

# Enable writeback, for polling completions from the host CPU --- best NOT to change
set(EN_WB 1 CACHE STRING "Enable writeback")

set(STATIC_PROBE 1044942 CACHE STRING "Static probe ID")
set(SHELL_PROBE 1044942 CACHE STRING "Shell probe ID")

##
## VIVADO
##
# Number of cores to use for synthesis and implementation
set(COMP_CORES 8 CACHE STRING "Number of compilation cores")

# Run implementation with optimization, can help close timing but significantly longer compilation time
set(BUILD_OPT 0 CACHE STRING "Build optimizations (significantly longer compilation times)")

##
## DESIGN CHECKPOINTS
##

# Path to static layer checkpoint, routed and locked
# Coyote provides static layer checkpoints for Alveo U55C, U280, U250 clocked at 250MHz
# Since the static layer never changes, a checkpoint is used for faster Place-and-Route
# Users are free to provide their own via this variable, or, rebuild the static part using BUILD_STATIC = 1
set(STATIC_PATH "${CYT_DIR}/hw/checkpoints" CACHE STRING "Static layer checkpoint")

# Path to a routed and locked shell checkpoint, used for linking an app against it (BUILD_APP = 1)
set(SHELL_PATH "0" CACHE STRING "External shell checkpoint")

##
## ADVANCED
##

# Number of outstanding transactions
# NOTE: If changing the default value and using a QDMA-based platform, 
# the driver must be recompiled, so that QDMA_N_ACTIVE_QUEUES (in driver/include/coyote_defs.h) >= 3 * N_OUTSANDING
set(N_OUTSTANDING 8 CACHE STRING "Number of supported outstanding transactions")

# Varios variables related to pipeline stages
# Each of the following controls the number of register stages in more congested areas of design
# Usually, the default values work just fine; only tweak if facing timing closure issues
set(NR_ST_S0 2 CACHE STRING "Static host stage 0")
set(NR_ST_S1 2 CACHE STRING "Static host stage 1")
set(NR_SH_S0 3 CACHE STRING "Shell host stage 0")
set(NR_SH_S1 2 CACHE STRING "Shell host stage 1")
set(NR_DH_S0 3 CACHE STRING "Dynamic host stage 0")
set(NR_DH_S1 3 CACHE STRING "Dynamic host stage 1")
set(NR_DC_S0 3 CACHE STRING "Dynamic card stage 0")
set(NR_DC_S1 3 CACHE STRING "Dynamic card stage 1")
set(NR_DN_S0 3 CACHE STRING "Dynamic net stage 0")
set(NR_DN_S1 3 CACHE STRING "Dynamic net stage 1")
set(NR_N_S0 6 CACHE STRING "Network stage 0")
set(NR_N_S1 4 CACHE STRING "Network stage 1")
set(NR_N_S2 5 CACHE STRING "Network stage 2")
set(NR_CC 4 CACHE STRING "Static dynamic cc")
set(NR_SD 3 CACHE STRING "Static decouple reg")
set(NR_DD 3 CACHE STRING "Dynamic decouple reg")
set(NR_PR 4 CACHE STRING "PR reg")
set(NR_NST 4 CACHE STRING "Network stats")
set(NR_HST 4 CACHE STRING "Host DMA stats")

##
## LEGACY VARIABLES
##
set(NR_E_S0 3 CACHE STRING "Enzian stage 0")
set(NR_E_S1 2 CACHE STRING "Enzian stage 1")
set(NET_DROP 0 CACHE STRING "Network dropper")
set(EN_XTERM 1 CACHE STRING "Terminal prints")

##
## DON'T TOUCH; COYOTE INTERNAL
##
set(LOAD_APPS 0 CACHE STRING "Load external apps")

# Processor-neutral co-processor application interface. These dimensions form
# one shell/application compatibility contract and remain independent of any
# physical R5/A72 provider backend.
set(COPROCESSOR_INTERFACE_PRESENT 0)
set(COPROCESSOR_INTERFACE_VERSION 1)
set(COPROCESSOR_STREAM_ABI 1)
set(COPROCESSOR_STREAM_DATA_BITS 512)
set(COPROCESSOR_STREAM_ID_BITS 6)
set(COPROCESSOR_MAX_PACKET_BYTES 4096)
set(COPROCESSOR_MMIO_ABI 1)
set(COPROCESSOR_MMIO_ADDR_BITS 12)
set(COPROCESSOR_MMIO_DATA_BITS 64)
set(COPROCESSOR_BINDING_GENERATION_BITS 32)
set(COPROCESSOR_PROVIDER_COUNT 0)
set(COPROCESSOR_PROVIDER_DESCRIPTORS "")
set(COPROCESSOR_PROVIDER_TOPS "")
set(COPROCESSOR_PROVIDER_SOURCES "")
set(COPROCESSOR_PROVIDER_INCLUDE_DIRS "")
set(COPROCESSOR_PROVIDER_INIT_TCL "")

############################################
##        SOFTWARE DEPENDENCIES           ##
############################################
find_package(Vivado REQUIRED)
if (NOT VIVADO_FOUND)
   message(FATAL_ERROR "Vivado not found.")
endif()

find_package(VitisHLS REQUIRED)
if (NOT VITIS_HLS_FOUND)
  message(FATAL_ERROR "Vitis HLS not found.")
endif()

############################################
##               MACROS                   ##
############################################

function(period_calc expr out)
    execute_process(COMMAND awk "BEGIN {printf ${expr}}" OUTPUT_VARIABLE __out)
    set(${out} ${__out} PARENT_SCOPE)
endfunction()

# Convert paths to a Tcl list whose elements remain intact in generated scripts.
function(_coyote_paths_to_tcl out_var)
    set(result "")
    foreach(path IN LISTS ARGN)
        string(REPLACE "\\" "\\\\" escaped "${path}")
        string(REPLACE "\"" "\\\"" escaped "${escaped}")
        string(REPLACE "$" "\\$" escaped "${escaped}")
        string(REPLACE "[" "\\[" escaped "${escaped}")
        string(REPLACE "]" "\\]" escaped "${escaped}")
        set(result "${result} \"${escaped}\"")
    endforeach()
    set(${out_var} "${result}" PARENT_SCOPE)
endfunction()

# Register a physical provider implementation without changing the logical
# application interface. Provider-free configurations are valid and exercise
# deterministic unbound behavior without a physical hard CPU.
function(register_coprocessor_provider)
    if(BUILD_APP)
        message(FATAL_ERROR "register_coprocessor_provider() is only valid for shell/static builds")
    endif()

    cmake_parse_arguments(
        "PROVIDER"
        ""
        "NAME;TOP;ENDPOINT_ID;PROCESSOR_CLASS;RUNTIME_ABI;FIRMWARE_ABI;STREAM_ABI;MMIO_ABI;CAPACITY;TIMING_NS;INIT_TCL"
        "SOURCES;INCLUDE_DIRS"
        ${ARGN}
    )
    if(PROVIDER_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "Unknown register_coprocessor_provider() arguments: ${PROVIDER_UNPARSED_ARGUMENTS}")
    endif()
    foreach(required NAME TOP ENDPOINT_ID PROCESSOR_CLASS RUNTIME_ABI FIRMWARE_ABI STREAM_ABI MMIO_ABI)
        if(NOT DEFINED PROVIDER_${required} OR PROVIDER_${required} STREQUAL "")
            message(FATAL_ERROR "register_coprocessor_provider() requires ${required}")
        endif()
    endforeach()
    foreach(token NAME PROCESSOR_CLASS RUNTIME_ABI FIRMWARE_ABI)
        if(NOT PROVIDER_${token} MATCHES "^[A-Za-z0-9][A-Za-z0-9_.+-]*$")
            message(FATAL_ERROR "Co-processor provider ${token} contains unsupported characters")
        endif()
    endforeach()
    if(NOT PROVIDER_TOP MATCHES "^[A-Za-z_][A-Za-z0-9_]*$")
        message(FATAL_ERROR "Co-processor provider TOP must be a simple SystemVerilog module identifier")
    endif()
    foreach(numeric ENDPOINT_ID STREAM_ABI MMIO_ABI)
        if(NOT PROVIDER_${numeric} MATCHES "^[1-9][0-9]*$")
            message(FATAL_ERROR "Co-processor provider ${numeric} must be a positive integer")
        endif()
    endforeach()

    if(PROVIDER_ENDPOINT_ID GREATER 65535)
        message(FATAL_ERROR "Co-processor provider ENDPOINT_ID must fit the 16-bit public contract")
    endif()
    if(NOT DEFINED PROVIDER_CAPACITY OR PROVIDER_CAPACITY STREQUAL "")
        set(PROVIDER_CAPACITY 1)
    endif()
    if(NOT DEFINED PROVIDER_TIMING_NS OR PROVIDER_TIMING_NS STREQUAL "")
        set(PROVIDER_TIMING_NS 0)
    endif()
    foreach(numeric CAPACITY TIMING_NS)
        if(NOT PROVIDER_${numeric} MATCHES "^[0-9]+$")
            message(FATAL_ERROR "Co-processor provider ${numeric} must be a nonnegative integer")
        endif()
    endforeach()
    if(NOT PROVIDER_CAPACITY EQUAL 1)
        message(FATAL_ERROR "Initial co-processor providers are exclusive and require CAPACITY 1")
    endif()

    if(COPROCESSOR_PROVIDER_DESCRIPTORS MATCHES "(^|;)${PROVIDER_ENDPOINT_ID}\\|")
        message(FATAL_ERROR "Duplicate co-processor provider endpoint ID ${PROVIDER_ENDPOINT_ID}")
    endif()

    set(normalized_sources "")
    foreach(path IN LISTS PROVIDER_SOURCES)
        get_filename_component(path_abs "${path}" ABSOLUTE BASE_DIR "${CMAKE_CURRENT_SOURCE_DIR}")
        if(NOT EXISTS "${path_abs}" OR IS_DIRECTORY "${path_abs}")
            message(FATAL_ERROR "Co-processor provider RTL source does not exist: ${path_abs}")
        endif()
        list(APPEND normalized_sources "${path_abs}")
    endforeach()
    list(REMOVE_DUPLICATES normalized_sources)

    set(normalized_include_dirs "")
    foreach(path IN LISTS PROVIDER_INCLUDE_DIRS)
        get_filename_component(path_abs "${path}" ABSOLUTE BASE_DIR "${CMAKE_CURRENT_SOURCE_DIR}")
        if(NOT IS_DIRECTORY "${path_abs}")
            message(FATAL_ERROR "Co-processor provider include directory does not exist: ${path_abs}")
        endif()
        list(APPEND normalized_include_dirs "${path_abs}")
    endforeach()
    list(REMOVE_DUPLICATES normalized_include_dirs)

    set(init_tcl "")
    if(DEFINED PROVIDER_INIT_TCL AND NOT PROVIDER_INIT_TCL STREQUAL "")
        get_filename_component(init_tcl "${PROVIDER_INIT_TCL}" ABSOLUTE BASE_DIR "${CMAKE_CURRENT_SOURCE_DIR}")
        if(NOT EXISTS "${init_tcl}" OR IS_DIRECTORY "${init_tcl}")
            message(FATAL_ERROR "Co-processor provider INIT_TCL does not exist: ${init_tcl}")
        endif()
    endif()

    set(descriptor "${PROVIDER_ENDPOINT_ID}|${PROVIDER_NAME}|${PROVIDER_PROCESSOR_CLASS}|${PROVIDER_RUNTIME_ABI}|${PROVIDER_FIRMWARE_ABI}|${PROVIDER_STREAM_ABI}|${PROVIDER_MMIO_ABI}|1|${PROVIDER_CAPACITY}|${PROVIDER_TIMING_NS}")
    set(descriptors ${COPROCESSOR_PROVIDER_DESCRIPTORS})
    list(APPEND descriptors "${descriptor}")
    set(tops ${COPROCESSOR_PROVIDER_TOPS})
    list(APPEND tops "${PROVIDER_TOP}")
    set(sources ${COPROCESSOR_PROVIDER_SOURCES})
    list(APPEND sources ${normalized_sources})
    list(REMOVE_DUPLICATES sources)
    set(include_dirs ${COPROCESSOR_PROVIDER_INCLUDE_DIRS})
    list(APPEND include_dirs ${normalized_include_dirs})
    list(REMOVE_DUPLICATES include_dirs)
    set(init_scripts ${COPROCESSOR_PROVIDER_INIT_TCL})
    if(NOT init_tcl STREQUAL "")
        list(APPEND init_scripts "${init_tcl}")
    endif()
    list(REMOVE_DUPLICATES init_scripts)
    math(EXPR provider_count "${COPROCESSOR_PROVIDER_COUNT} + 1")

    set(COPROCESSOR_PROVIDER_COUNT ${provider_count} PARENT_SCOPE)
    set(COPROCESSOR_PROVIDER_DESCRIPTORS "${descriptors}" PARENT_SCOPE)
    set(COPROCESSOR_PROVIDER_TOPS "${tops}" PARENT_SCOPE)
    set(COPROCESSOR_PROVIDER_SOURCES "${sources}" PARENT_SCOPE)
    set(COPROCESSOR_PROVIDER_INCLUDE_DIRS "${include_dirs}" PARENT_SCOPE)
    set(COPROCESSOR_PROVIDER_INIT_TCL "${init_scripts}" PARENT_SCOPE)
    message("** Co-processor provider ${PROVIDER_NAME} (endpoint ${PROVIDER_ENDPOINT_ID}, class ${PROVIDER_PROCESSOR_CLASS})")
endfunction()

macro(_validate_coprocessor_interface)
    if(NOT N_COPROCESSOR_PORTS MATCHES "^[0-9]+$")
        message(FATAL_ERROR "N_COPROCESSOR_PORTS must be a nonnegative integer")
    endif()
    if(N_COPROCESSOR_PORTS GREATER 8)
        message(FATAL_ERROR "At most eight logical co-processor ports are supported")
    endif()
    if(COPROCESSOR_PROVIDER_COUNT GREATER 0 AND N_COPROCESSOR_PORTS EQUAL 0)
        message(FATAL_ERROR "Physical co-processor providers require at least one logical port")
    endif()
    if(N_COPROCESSOR_PORTS GREATER 0)
        if((BUILD_SHELL OR BUILD_STATIC) AND NOT BUILD_APP)
            set(COPROCESSOR_INTERFACE_PRESENT 1)
        endif()
        foreach(abi COPROCESSOR_STREAM_ABI COPROCESSOR_MMIO_ABI)
            if(NOT ${abi} MATCHES "^[1-9][0-9]*$")
                message(FATAL_ERROR "${abi} must be a positive integer")
            endif()
        endforeach()
        if(NOT COPROCESSOR_INTERFACE_PRESENT EQUAL 1)
            message(FATAL_ERROR "Enabled logical co-processor ports require a complete exported interface contract")
        endif()
        if(NOT COPROCESSOR_INTERFACE_VERSION EQUAL 1 OR
           NOT COPROCESSOR_STREAM_DATA_BITS EQUAL 512 OR
           NOT COPROCESSOR_STREAM_ID_BITS EQUAL 6 OR
           NOT COPROCESSOR_MAX_PACKET_BYTES EQUAL 4096 OR
           NOT COPROCESSOR_MMIO_ADDR_BITS EQUAL 12 OR
           NOT COPROCESSOR_MMIO_DATA_BITS EQUAL 64 OR
           NOT COPROCESSOR_BINDING_GENERATION_BITS EQUAL 32)
            message(FATAL_ERROR "Unsupported logical co-processor interface dimensions")
        endif()
    endif()
endmacro()

# Performs base validation checks of configured parmeters and sets the other params
macro(validation_checks_hw)
    if(NOT DEFINED CYT_DIR)
        message(FATAL_ERROR "Coyote directory not set.")
    endif()

    # On UltraScale+ devices, Coyote floorplans the shell and the static layer
    # Since the static layer rerely changes, a routed and locked checkpoint is provided
    # However, for Versal devices Coyote doesn't yet provide this feature, therefore it
    # always re-synthesizes the static layer.
    set(NN 0)
    if(BUILD_STATIC)
        message("** Static design flow")
        MATH(EXPR NN "${NN}+1")
    endif()
    if(BUILD_SHELL)
        message("** Shell design flow")
        MATH(EXPR NN "${NN}+1")
    endif()
    if(BUILD_APP)
        message("** App design flow")
        MATH(EXPR NN "${NN}+1")
    endif()

    if(NOT NN EQUAL 1)
        message(FATAL_ERROR "Choose one build flow.")
    endif()

    if(NOT EN_V80_R5_PLATFORM MATCHES "^[01]$")
        message(FATAL_ERROR "EN_V80_R5_PLATFORM must be 0 or 1")
    endif()
    if(EN_V80_R5_PLATFORM)
        if(NOT FDEV_NAME STREQUAL "v80")
            message(FATAL_ERROR "The R5 hardware platform is available only on V80")
        endif()
        if(NOT BUILD_STATIC)
            message(FATAL_ERROR "The R5 hardware platform changes CIPS and requires BUILD_STATIC=1")
        endif()
        if(EN_PR)
            message(FATAL_ERROR "Static R5 platform builds do not support EN_PR=1")
        endif()
    endif()

    if(NOT EN_V80_R5_PROVIDER MATCHES "^[01]$")
        message(FATAL_ERROR "EN_V80_R5_PROVIDER must be 0 or 1")
    endif()
    if(EN_V80_R5_PROVIDER)
        if(NOT FDEV_NAME STREQUAL "v80")
            message(FATAL_ERROR "The R5 co-processor provider is available only on V80")
        endif()
        if(BUILD_APP)
            message(FATAL_ERROR "Applications request logical co-processor ports; EN_V80_R5_PROVIDER belongs to static/shell builds")
        endif()
        if(BUILD_STATIC AND NOT EN_V80_R5_PLATFORM)
            message(FATAL_ERROR "Static R5 provider builds require EN_V80_R5_PLATFORM=1")
        endif()
        if(NOT N_REGIONS EQUAL 1 OR NOT N_COPROCESSOR_PORTS EQUAL 1)
            message(FATAL_ERROR "The initial R5 provider requires one region and one logical co-processor port")
        endif()
        if(EN_UCLK)
            message(FATAL_ERROR "The initial R5 provider requires EN_UCLK=0 so its logical interfaces share the shell clock")
        endif()
        if(NOT COPROCESSOR_PROVIDER_COUNT EQUAL 1)
            message(FATAL_ERROR "The initial R5 provider requires exactly one registered endpoint descriptor")
        endif()
    endif()

    if(BUILD_SHELL OR BUILD_STATIC)
        if((SHELL_PROBE EQUAL STATIC_PROBE) AND BUILD_SHELL)
            message("** Maybe not a bad choice to set a unique probe ID for the shell.")
        endif()

        ##
        ## Set device details (part number, memory size etc.)                                                     
        ## Memory size is obtained by calculating 1 << HBM_SIZE or 1 << DDR_SIZE e.g., on the u55c,
        ## HBM_SIZE = 34, so 1 << 34 ~ 16 GB of HBM. On Versal devices, which access memory through the NoC,
        ## the addresses start from 0x4000000000, so keep track of the variable using MEM_OFFSET
        ## When using Coyote's stripe module (axi_stripe), it's necessary to know the memory size
        ## per channel (memory controller), stored in the variable MC_SIZE
        ##
        
        # u55c
        if(FDEV_NAME STREQUAL "u55c") 
            # Platform details
            set(FPGA_ARCH "ultrascale_plus")
            set(FPGA_PART xcu55c-fsvh2892-2L-e CACHE STRING "FPGA Part" FORCE)
            
            # No DDR on the u55c
            set(DDR_SIZE 0)
            set(N_DDR_CHAN 0)

            # HBM configuration
            set(HCLK_F 450)
            set(HBM_SIZE 34)

            # Striping --- effectively unused, since the RAMA IP handles striping
            set(MC_SIZE 29)
            set(N_STRIPE_CHAN 32)
            set(MEM_OFFSET 0)
        
        # u250
        elseif(FDEV_NAME STREQUAL "u250")
            # Platform details
            set(FPGA_ARCH "ultrascale_plus")
            set(FPGA_PART xcu250-figd2104-2L-e CACHE STRING "FPGA Part" FORCE)

            # DDR configuration
            set(DDR_SIZE 34)
            set(N_DDR_CHAN 1)
            
            # No HBM on the u250
            set(HCLK_F 1)
            set(HBM_SIZE 0)
            
            # Striping
            set(MC_SIZE ${DDR_SIZE}) 
            set(N_STRIPE_CHAN ${N_DDR_CHAN})
            set(MEM_OFFSET 0)
        
        # u280
        elseif(FDEV_NAME STREQUAL "u280")
            # Platform details
            set(FPGA_ARCH "ultrascale_plus")
            set(FPGA_PART xcu280-fsvh2892-2L-e CACHE STRING "FPGA Part" FORCE)

            # DDR configuration
            set(DDR_SIZE 34)
            set(N_DDR_CHAN 1)
            
            # HBM configuration
            set(HCLK_F 450)
            set(HBM_SIZE 33)

            # Striping
            set(MC_SIZE ${DDR_SIZE}) 
            set(N_STRIPE_CHAN ${N_DDR_CHAN})
            set(MEM_OFFSET 0)
        
        # v80
        elseif(FDEV_NAME STREQUAL "v80")
            # Platform details
            set(FPGA_ARCH "versal")
            set(FPGA_PART xcv80-lsva4737-2MHP-e-S CACHE STRING "FPGA Part" FORCE)

            # Onboard 4 GB DDR4 (axi_noc_mc_ddr4_0). Off by default; enabled
            # automatically when EN_AMC=1 because AMC firmware on R5 places
            # its .text/.data/.bss at 0x40000000 (inside DDR_LOW0).
            # 2^32 = 4 GB.
            if(EN_AMC)
                set(DDR_SIZE 32)
                set(N_DDR_CHAN 1)
            else()
                set(DDR_SIZE 0)
                set(N_DDR_CHAN 0)
            endif()
            
            # HBM configuration
            set(HCLK_F 400)
            set(HBM_SIZE 35)
            
            # Striping for unified HBM implementation
            set(MC_SIZE 30)
            set(N_STRIPE_CHAN 32)
            set(MEM_OFFSET 274877906944) # 0x4000000000 ~ 256 GiB

            if (BUILD_SHELL OR BUILD_APP)
                # Shell builds link against an existing static checkpoint, whose
                # SCLK_F was baked in at the time of the static build. The shell's
                # clk_wiz must be configured for that exact input frequency.
                # Upstream ships a 333 MHz checkpoint and forces SCLK_F=333 here.
                # If the user has explicitly overridden SCLK_F (e.g. because they
                # rebuilt the static at a different frequency and swapped it in),
                # honor that override.
                if (NOT DEFINED CACHE{SCLK_F} OR SCLK_F STREQUAL "250")
                    message(" ** V80 with BUILD_SHELL=1 or BUILD_APP=1 selected, defaulting SCLK_F to 333 MHz to match the shipped static checkpoint")
                    set(SCLK_F 333)
                else()
                    message(" ** V80 with BUILD_SHELL=1 or BUILD_APP=1: honoring user-provided SCLK_F=${SCLK_F} (must match the static checkpoint actually in use)")
                endif()
            endif()
        
        # Fail on unsupported device
        else()
            message(FATAL_ERROR "Target device not supported.")
        endif()
        message("** Target platform ${FDEV_NAME}")

        # Three host channels: streaming data host <-> vFPGA, migration channel (sync/offload), and, PR & WB channel
        set(N_HCHAN 3)

        ##
        ## DDR and HBM support
        ## ! u280 has both DDR and HBM, HBM enabled by default; if DDR is required add u280 in DDR_DEV and remove it from HBM_DEV
        ## ! v80 has both DDR and HBM, HBM is enabled by default and supported; DDR not supported yet
        ##
        set(DDR_DEV "u250")
        set(HBM_DEV "u55c" "u280" "v80")

        list(FIND DDR_DEV ${FDEV_NAME} TMP_DEV)
        if(NOT TMP_DEV EQUAL -1)
            set(AV_DDR 1)
        else()
            set(AV_DDR 0)
        endif()

        list(FIND HBM_DEV ${FDEV_NAME} TMP_DEV)
        if(NOT TMP_DEV EQUAL -1)
            set(AV_HBM 1)
        else()
            set(AV_HBM 0)
        endif()

        ##
        ## User logic
        ##
        # Max regions
        set(MULT_REGIONS 0)
        if(N_REGIONS GREATER 1)
            set(MULT_REGIONS 1)
        endif()
        # Option A shared-hub P2P NoC: receivers group into 16 hub NSUs (each with
        # a 1->K demux), so every NMU addresses <=16 hubs regardless of N and the
        # 17-node full-mesh limit no longer binds. NoC scales to ~76 (NMU tiles);
        # capped at 32 here (validated hub NoC + IRQ/floorplan scaled to 32).
        if(N_REGIONS GREATER 32)
            message(FATAL_ERROR "Max 32 vFPGAs supported (shared-hub P2P NoC; raise with IRQ/floorplan scaling).")
        endif()

        # Number of configurations needs to be 1 without PR
        if(N_CONFIG GREATER 1 AND NOT EN_PR)
            message(FATAL_ERROR "When PR is not enabled only one configuration of the shell should exist.")
        endif()

        # Check PCIe Gen for Versal devices
        if(FPGA_ARCH STREQUAL "versal")
            if (NOT (PCIE_GEN EQUAL 4 OR PCIE_GEN EQUAL 5))
                message(FATAL_ERROR "Versal devices only support PCIe Gen4x16 or Gen5x8.")
            else()
                # PCIe transceiver signal is 16 bits for Gen4x16
                # and 8 bits for Gen5x8
                if (PCIE_GEN EQUAL 4)
                    set(PCIE_GT_BITS 16)
                else()
                    set(PCIE_GT_BITS 8)
                endif()
            endif()
        else()
            # UltraScale+ devices only support PCIe Gen3x16, therefore 16 bits
            set(PCIE_GT_BITS 16)
        endif()

        # User credits (enabled by default)
        set(EN_CRED_LOCAL 1)
        set(EN_CRED_REMOTE 1)

        # User regs
        set(EN_USER_REG 0)

        # Static synthesis does not have PR
        if(BUILD_STATIC AND EN_PR) 
            message(FATAL_ERROR "Static builds do not support PR.")
        endif()

        # Check if the shell pblock option is valid; the shell floorplan (and shell reconfiguration) can only be disabled when:
        # 1. Running a static build, as the entire design is re-synthesized and re-implemented (with no pre-routed checkpoints with prior constraints)
        # 2. When enabling vFPGA reconfiguration on Versal devices (EN_PR=1), as nested reconfiguration is not supported on Versal devices (may become available in future Vivado releases)
        # - The shell pblock cannot be disabled during the shell design flow (BUILD_SHELL=1), as it relies on a routed and locked static checkpoint, which already contains the shell floorplan (and marks it as reconfigurable)
        # TODO: What about app flow?
        set(SHELL_PBLOCK_OPT_VALID 0)
        if(EN_PR AND FPGA_ARCH STREQUAL "versal")
            set(SHELL_PBLOCK_OPT_VALID 1)
        elseif(BUILD_STATIC)
            set(SHELL_PBLOCK_OPT_VALID 1)
        elseif(BUILD_SHELL)
            if(EN_SHELL_PBLOCK)
                set(SHELL_PBLOCK_OPT_VALID 1)
            else()
                set(SHELL_PBLOCK_OPT_VALID 0)
            endif()
        endif()

        if (NOT SHELL_PBLOCK_OPT_VALID)
            message(FATAL_ERROR "The shell pblock option (EN_SHELL_PBLOCK) can only be disabled for (1) static builds of (BUILD_STATIC=1) or (2) builds for Versal devices with application-level reconfiguration (EN_PR=1).")
        endif()

        # Check nested reconfiguration isn't enabled
        if (FPGA_ARCH STREQUAL "versal" AND EN_PR AND EN_SHELL_PBLOCK)
            message(FATAL_ERROR "Versal devices do not support nested reconfiguration yet; to enable application-level reconfiguration (EN_PR=1), disable shell reconfiguration (EN_SHELL_PBLOCK=0)")
        endif()

        # Period
        period_calc("1000.0 / ${ACLK_F}" ACLK_P)
        period_calc("1000.0 / ${NCLK_F}" NCLK_P)
        period_calc("1000.0 / ${UCLK_F}" UCLK_P)
        period_calc("1000.0 / ${HCLK_F}" HCLK_P)
        period_calc("1000.0 / ${SCLK_F}" SCLK_P)

        ##
        ## Network
        ##
        set(EN_DCARD 0)
        set(EN_HCARD 0)

        if(EN_TCP)
            set(N_TCP_CHAN 1)
            set(TCP_STACK_EN 1 CACHE BOOL "Enable TCP/IP stack")
        else()
            set(N_TCP_CHAN 0)
            set(TCP_STACK_EN 0 CACHE BOOL "Enable TCP/IP stack")
        endif()
        if(EN_RDMA)
            set(N_RDMA_CHAN 1)
            set(ROCE_STACK_EN 1 CACHE BOOL "RDMA stack disabled.")
        else()
            set(N_RDMA_CHAN 0)
            set(ROCE_STACK_EN 0 CACHE BOOL "RDMA stack disabled.")
        endif() 

        if(EN_TCP OR EN_RDMA)
            if(AV_DDR)  
                set(EN_DCARD 1)
                set(EN_HCARD 0)
                if(N_DDR_CHAN EQUAL 0)
                    set(N_DDR_CHAN 1)
                endif()
            elseif(AV_HBM)
                set(EN_DCARD 0)
                set(EN_HCARD 1)
            endif()
        else()
            if(EN_MEM)
                if(AV_DDR)
                    set(EN_DCARD 1)
                    set(EN_HCARD 0)
                elseif(AV_HBM)
                    set(EN_DCARD 0)
                    set(EN_HCARD 1)
                endif()
            endif()
        endif()

        # Top net enabled
        if(EN_RDMA OR EN_TCP OR EN_SNIFFER)
            set(EN_NET 1)
        else()
            set(EN_NET 0)
        endif()

        # Versal networking uses DCMAC (200 Gb/s) — ported from
        # fpgasystems/Versal-DCMAC into hw/hdl/network/dcmac/ and
        # hw/bd/versal/cr_dcmac.tcl. Only V80 has a board_config_dcmac entry
        # so far; other Versal boards (VHK158, VPK120) need an entry added
        # before EN_NET works on them.
        if (EN_NET AND FPGA_ARCH STREQUAL "versal" AND NOT FDEV_NAME STREQUAL "v80")
            message(FATAL_ERROR "EN_NET on Versal currently requires FDEV_NAME=v80 "
                                "(no DCMAC site mapping for ${FDEV_NAME} in board_config_dcmac.tcl).")
        endif()
        
        # Mult user channels
        set(MULT_RDMA_AXI 0)
        if(N_RDMA_AXI GREATER 1)
            set(MULT_RDMA_AXI 1)
        endif()

        set(MULT_TCP_AXI 0)
        if(N_TCP_AXI GREATER 1)
            set(MULT_TCP_AXI 1)
        endif()

        # WBs
        set(N_WBS 2)
        if(EN_RDMA)
            set(N_WBS 4)
        endif()

        # Ports: CMAC can be on at most one QSFP. With EN_AURORA_1=1, Aurora
        # occupies QSFP1 in parallel to CMAC on QSFP0 (the typical setup).
        if(EN_NET_0 AND EN_NET_1)
            message(FATAL_ERROR "Both CMAC ports (EN_NET_0 and EN_NET_1) enabled; CMAC supports only one QSFP at a time.")
        endif()
        if(EN_AURORA_1 AND EN_NET_1)
            message(FATAL_ERROR "EN_AURORA_1 and EN_NET_1 both enabled; both want the QSFP1 cage.")
        endif()
        if(EN_AMC AND NOT FDEV_NAME STREQUAL "v80")
            message(FATAL_ERROR "EN_AMC=1 is only supported on V80 (FDEV_NAME=v80).")
        endif()
        if(EN_AMC AND NOT IS_DIRECTORY ${AVED_IPREPO_PATH})
            message(FATAL_ERROR "EN_AMC=1 but AVED_IPREPO_PATH does not exist: ${AVED_IPREPO_PATH}")
        endif()
        if(EN_AMC AND NOT BUILD_STATIC)
            message(WARNING "EN_AMC=1 modifies the static layer (adds GCQ + axi_noc_mc_ddr4_0). "
                            "The shipped V80 static checkpoint does not include these. "
                            "You probably want -DBUILD_STATIC=1 for the first build.")
        endif()
        set(QSFP 0)
        if(EN_NET_1)
            set(QSFP 1)
        endif()

        ##
        ## Memory
        ##

        # Total AXI memory channels
        if(EN_HCARD OR EN_DCARD)
            set(EN_CARD 1)
        else()
            set(EN_CARD 0)
        endif()

        if(FPGA_ARCH STREQUAL "versal" AND HBM_SPLIT EQUAL 1)
            message(WARNING "Versal device selected, HBM splitting not supported yet; building with default HBM interface")
            set(HBM_SPLIT 0)
        endif()

        # Total memory AXI channels
        set(N_MEM_CHAN 0)
        set(N_NET_CHAN 0)
        MATH(EXPR N_NET_CHAN "${N_TCP_CHAN} + ${N_RDMA_CHAN}")
        if(EN_MEM)
            MATH(EXPR N_MEM_CHAN "${N_REGIONS} * ${N_CARD_AXI} + 1 + ${N_MEM_CHAN}")
        endif()
        if(EN_TCP OR EN_RDMA)
            MATH(EXPR N_MEM_CHAN "${N_NET_CHAN} + ${N_MEM_CHAN}")
        endif()

        # Most boards only up to 4
        if(EN_DCARD)
            if((N_DDR_CHAN GREATER 4) OR (N_DDR_CHAN LESS 1))
                message(FATAL_ERROR "Number of DDR channels misconfigured.")
            endif()
        endif()

        set(DDR_0 0) # Bottom SLR (TODO: Check this stuff, might be completely different)
        set(DDR_1 0) # Mid SLRs
        set(DDR_2 0) # Mid SLRs
        set(DDR_3 0) # Top SLR

        if(DDR_AUTO)
            if(EN_DCARD)
                if(N_DDR_CHAN GREATER 0)
                    set(DDR_0 1)
                endif()
                if(N_DDR_CHAN GREATER 1)
                    set(DDR_1 1)
                endif()
                if(N_DDR_CHAN GREATER 2)
                    set(DDR_2 1)
                    set(DDR_3 1)
                endif()
            endif()
        endif()

        # On UltraScale+ HBM devices, striping is done through the RAMA IP in the design_hbm BD, so bypass Coyote's striping module
        # On UltraScale+ DDR devices, striping is enabled when more than one DDR channel is enabled
        set(EN_MEM_STRIPE 0)
        if((N_DDR_CHAN GREATER 1) AND EN_DCARD AND (FPGA_ARCH STREQUAL "ultrascale_plus"))
            set(EN_MEM_STRIPE 1)
        endif()

        # To reduce PC collisions, striping is enabled on Versal devices with 'unified' HBM implementation
        if(FPGA_ARCH STREQUAL "versal" AND HBM_IMPL STREQUAL "unified")
            set(EN_MEM_STRIPE 1)
        endif()

        # Compare for mismatch
        if(EN_DCARD)
            MATH(EXPR N_DDRS "${DDR_0}+${DDR_1}+${DDR_2}+${DDR_3}")
            if(NOT N_DDRS EQUAL ${N_DDR_CHAN})
                message(FATAL_ERROR "DDRs have not been configured properly.")
            endif()
        endif()

        ##
        ## Enzian --- DEPRECATED
        ##

        # Enzian currently doesn't support any form of AVX
        set(POL_INV 0)
        if(FDEV_NAME STREQUAL "enzian")
        if(EN_AVX)
            message("AVX instructions not supported on the Enzian platform currently. Force disable.")
            set(EN_AVX 0)
        endif()
        if(EN_NET)
            set(POL_INV 1)
        endif()
        endif()

        ##
        ## Control regs
        ##

        set(EN_GP_CTRL 0)
        if(N_GP_CTRL GREATER 0)
            set(EN_GP_CTRL 1)
        endif()
        set(EN_GP_STAT 0)
        if(N_GP_STAT GREATER 0)
            set(EN_GP_STAT 1)
        endif()
        set(EN_GP_RW 0)
        if(N_GP_RW GREATER 0)
            set(EN_GP_RW 1)
        endif()


        ##
        ## Rest of parameters
        ##

        set(N_SCHAN 0 CACHE STRING "Total number of shell crossing channels.")
        MATH(EXPR N_SCHAN "${N_HCHAN}-1")

        set(N_CHAN 0)
        if(EN_STRM)
            MATH(EXPR N_CHAN "${N_CHAN}+1")
        endif()
        if(EN_MEM)
            MATH(EXPR N_CHAN "${N_CHAN}+1")
        endif()

        set(NN 0)
        set(STRM_CHAN -1 CACHE STRING "Stream channel.")
        set(CARD_CHAN -1 CACHE STRING "Memory channel.")
        set(MULT_STRM_AXI 0)
        set(MULT_CARD_AXI 0)
        if(EN_STRM)
            set(STRM_CHAN ${NN})
            MATH(EXPR NN "${NN}+1")
            if(N_STRM_AXI GREATER 1)
                set(MULT_STRM_AXI 1)
            endif()
        endif()
        if(EN_MEM)
            set(CARD_CHAN ${NN})
            MATH(EXPR NN "${NN}+1")
            if(N_CARD_AXI GREATER 1)
                set(MULT_CARD_AXI 1)
            endif()
        endif()

        set(EN_XCH_0 0 CACHE STRING "Status counter channel 0.")
        set(EN_XCH_1 0 CACHE STRING "Status counter channel 1.")
        if(N_CHAN GREATER 0)
            set(EN_XCH_0 1)
        endif()
        if(N_CHAN GREATER 1)
            set(EN_XCH_1 1)
        endif()

    else()
        if(SHELL_PATH EQUAL "0")
            message(FATAL_ERROR "External shell path not provided.")
        endif()

        set(COPROCESSOR_REQUESTED_PORTS ${N_COPROCESSOR_PORTS})
        set(COPROCESSOR_REQUESTED_INTERFACE_VERSION ${COPROCESSOR_INTERFACE_VERSION})
        set(COPROCESSOR_REQUESTED_STREAM_ABI ${COPROCESSOR_STREAM_ABI})
        set(COPROCESSOR_REQUESTED_STREAM_DATA_BITS ${COPROCESSOR_STREAM_DATA_BITS})
        set(COPROCESSOR_REQUESTED_STREAM_ID_BITS ${COPROCESSOR_STREAM_ID_BITS})
        set(COPROCESSOR_REQUESTED_MAX_PACKET_BYTES ${COPROCESSOR_MAX_PACKET_BYTES})
        set(COPROCESSOR_REQUESTED_MMIO_ABI ${COPROCESSOR_MMIO_ABI})
        set(COPROCESSOR_REQUESTED_MMIO_ADDR_BITS ${COPROCESSOR_MMIO_ADDR_BITS})
        set(COPROCESSOR_REQUESTED_MMIO_DATA_BITS ${COPROCESSOR_MMIO_DATA_BITS})
        set(COPROCESSOR_REQUESTED_GENERATION_BITS ${COPROCESSOR_BINDING_GENERATION_BITS})

        # Clear local defaults so an old or incomplete shell export cannot be
        # mistaken for a compatible co-processor contract.
        set(COPROCESSOR_INTERFACE_PRESENT 0)
        set(N_COPROCESSOR_PORTS 0)
        set(COPROCESSOR_INTERFACE_VERSION 0)
        set(COPROCESSOR_STREAM_ABI 0)
        set(COPROCESSOR_STREAM_DATA_BITS 0)
        set(COPROCESSOR_STREAM_ID_BITS 0)
        set(COPROCESSOR_MAX_PACKET_BYTES 0)
        set(COPROCESSOR_MMIO_ABI 0)
        set(COPROCESSOR_MMIO_ADDR_BITS 0)
        set(COPROCESSOR_MMIO_DATA_BITS 0)
        set(COPROCESSOR_BINDING_GENERATION_BITS 0)
        set(COPROCESSOR_PROVIDER_COUNT 0)
        set(COPROCESSOR_PROVIDER_DESCRIPTORS "")
        include("${SHELL_PATH}/export.cmake")

        if(COPROCESSOR_REQUESTED_PORTS GREATER 0 AND NOT COPROCESSOR_INTERFACE_PRESENT EQUAL 1)
            message(FATAL_ERROR "Application requires logical co-processor ports, but the shell exports no complete co-processor contract")
        endif()
        if(COPROCESSOR_REQUESTED_PORTS GREATER N_COPROCESSOR_PORTS)
            message(FATAL_ERROR "Application requires ${COPROCESSOR_REQUESTED_PORTS} logical co-processor ports, but the shell exports ${N_COPROCESSOR_PORTS}")
        endif()
        if(COPROCESSOR_REQUESTED_PORTS GREATER 0 AND
           (NOT COPROCESSOR_REQUESTED_INTERFACE_VERSION EQUAL COPROCESSOR_INTERFACE_VERSION OR
            NOT COPROCESSOR_REQUESTED_STREAM_ABI EQUAL COPROCESSOR_STREAM_ABI OR
            NOT COPROCESSOR_REQUESTED_STREAM_DATA_BITS EQUAL COPROCESSOR_STREAM_DATA_BITS OR
            NOT COPROCESSOR_REQUESTED_STREAM_ID_BITS EQUAL COPROCESSOR_STREAM_ID_BITS OR
            NOT COPROCESSOR_REQUESTED_MAX_PACKET_BYTES EQUAL COPROCESSOR_MAX_PACKET_BYTES OR
            NOT COPROCESSOR_REQUESTED_MMIO_ABI EQUAL COPROCESSOR_MMIO_ABI OR
            NOT COPROCESSOR_REQUESTED_MMIO_ADDR_BITS EQUAL COPROCESSOR_MMIO_ADDR_BITS OR
            NOT COPROCESSOR_REQUESTED_MMIO_DATA_BITS EQUAL COPROCESSOR_MMIO_DATA_BITS OR
            NOT COPROCESSOR_REQUESTED_GENERATION_BITS EQUAL COPROCESSOR_BINDING_GENERATION_BITS))
            message(FATAL_ERROR "Application co-processor interface is incompatible with the exported shell")
        endif()

        if(EN_PR EQUAL 0)
            message(FATAL_ERROR "PR not enabled in the shell.")
        endif()

    endif()

    _validate_coprocessor_interface()
endmacro()

# Load applications
macro(load_apps)

    if(N_REGIONS EQUAL 0)
        message(FATAL_ERROR "N_REGIONS not set.")
    endif()

    # Load shell
    MATH(EXPR NN "2 * ${N_REGIONS} * ${N_CONFIG}")
    if(NOT ${ARGC} EQUAL ${NN}) 
        message(FATAL_ERROR "Provide N_REGIONS * N_CONFIG apps.")
    endif()

    set(APP_VARS "")
    set(c_idx 0)
    set(v_idx 0)
    while(c_idx LESS N_CONFIG)
        while(v_idx LESS N_REGIONS)
            set(APP_VARS "${APP_VARS}VFPGA_C${c_idx}_${v_idx};")
            MATH(EXPR v_idx "${v_idx}+1")    
        endwhile()
        MATH(EXPR c_idx "${c_idx}+1")
        set(v_idx 0)
    endwhile()

    cmake_parse_arguments(
        "APPS" # prefix of output variables
        ""
        ""
        "${APP_VARS}"
        ${ARGN}
    )

    set(c_idx 0)
    set(v_idx 0)
    MATH(EXPR NN "${N_REGIONS}-1")
    set(APPS_ALL "")
    message("**")
    message("** ─── Applications")
    
    while(c_idx LESS N_CONFIG)
        message("**   └── Config ${c_idx}")

        while(v_idx LESS N_REGIONS)
            if(NOT DEFINED "APPS_VFPGA_C${c_idx}_${v_idx}")
                message(FATAL_ERROR "Missing arguments.")
            endif()

            list(LENGTH "APPS_VFPGA_C${c_idx}_${v_idx}" l_tmp)
            if(NOT l_tmp EQUAL 1)
                message(FATAL_ERROR "Wrong number of arguments provided, ${l_tmp}.")
            endif()

            if(v_idx LESS NN)            
                set(TMP_P "**     ├── vFPGA ${v_idx}:")
            else()
                set(TMP_P "**     └── vFPGA ${v_idx}:")  
            endif()
            set(TMP_P "${TMP_P} path:")
            set(t_idx 0)
            foreach(vf_app IN LISTS "APPS_VFPGA_C${c_idx}_${v_idx}")
                set(TMP_P "${TMP_P} ${vf_app}")
                set(APPS_ALL "${APPS_ALL}set vfpga_c${c_idx}_${v_idx} \"${vf_app}\"\n")
                MATH(EXPR t_idx "${t_idx}+1")
            endforeach()
            message("${TMP_P}")

            MATH(EXPR v_idx "${v_idx}+1")
        endwhile()
        MATH(EXPR c_idx "${c_idx}+1")
        set(v_idx 0)
    endwhile()
    message("**")

    set(LOAD_APPS 1)

endmacro()

# Generate templated scripts, from the parameters configured here
macro(gen_scripts)
    _coyote_paths_to_tcl(COPROCESSOR_PROVIDER_SOURCES_TCL ${COPROCESSOR_PROVIDER_SOURCES})
    _coyote_paths_to_tcl(COPROCESSOR_PROVIDER_INCLUDE_DIRS_TCL ${COPROCESSOR_PROVIDER_INCLUDE_DIRS})
    _coyote_paths_to_tcl(COPROCESSOR_PROVIDER_INIT_TCL_TCL ${COPROCESSOR_PROVIDER_INIT_TCL})

    # Python
    configure_file(${CYT_DIR}/scripts/cr_prjcts/write_hdl.py.in ${CMAKE_BINARY_DIR}/write_hdl.py)
    configure_file(${CYT_DIR}/scripts/impl/fix_bif.py.in ${CMAKE_BINARY_DIR}/fix_bif.py)

    # Base script. Keep disabled generation byte-equivalent by appending the
    # processor-platform fragment only when the static R5 option is enabled.
    configure_file(${CYT_DIR}/scripts/base.tcl.in ${CMAKE_BINARY_DIR}/base.tcl)
    if(EN_V80_R5_PLATFORM)
        configure_file(${CYT_DIR}/scripts/v80-r5-platform-base.tcl.in ${CMAKE_BINARY_DIR}/v80-r5-platform-base.tcl)
        file(READ ${CMAKE_BINARY_DIR}/v80-r5-platform-base.tcl v80_r5_platform_base)
        file(APPEND ${CMAKE_BINARY_DIR}/base.tcl "\n${v80_r5_platform_base}")
    endif()

    # HLS & SpinalHDL scripts
    configure_file(${CYT_DIR}/scripts/apps/comp_hls.tcl.in ${CMAKE_BINARY_DIR}/comp_hls.tcl)
    configure_file(${CYT_DIR}/scripts/apps/comp_spinal.tcl.in ${CMAKE_BINARY_DIR}/comp_spinal.tcl)

    # Python sim (unit-testing framework)
    configure_file(${CYT_DIR}/scripts/unit_test/__init__.in.py ${CMAKE_BINARY_DIR}/coyote_test/__init__.py)

    # Project creation scripts
    configure_file(${CYT_DIR}/scripts/cr_prjcts/cr_static.tcl.in ${CMAKE_BINARY_DIR}/cr_static.tcl)
    configure_file(${CYT_DIR}/scripts/cr_prjcts/cr_shell.tcl.in ${CMAKE_BINARY_DIR}/cr_shell.tcl)
    configure_file(${CYT_DIR}/scripts/cr_prjcts/cr_user.tcl.in ${CMAKE_BINARY_DIR}/cr_user.tcl)
    configure_file(${CYT_DIR}/scripts/cr_prjcts/cr_sim.tcl.in ${CMAKE_BINARY_DIR}/cr_sim.tcl)

    # Synthesis scripts
    configure_file(${CYT_DIR}/scripts/synth/synth_static.tcl.in ${CMAKE_BINARY_DIR}/synth_static.tcl)
    configure_file(${CYT_DIR}/scripts/synth/synth_shell.tcl.in ${CMAKE_BINARY_DIR}/synth_shell.tcl)
    configure_file(${CYT_DIR}/scripts/synth/synth_user.tcl.in ${CMAKE_BINARY_DIR}/synth_user.tcl)

    # Linking script
    configure_file(${CYT_DIR}/scripts/impl/link.tcl.in ${CMAKE_BINARY_DIR}/link.tcl)

    # Place-and-Route scripts
    configure_file(${CYT_DIR}/scripts/impl/pnr_shell.tcl.in ${CMAKE_BINARY_DIR}/pnr_shell.tcl)
    if(EN_V80_R5_PLATFORM)
        configure_file(${CYT_DIR}/scripts/impl/export_platform.tcl.in ${CMAKE_BINARY_DIR}/export_platform.tcl)
        configure_file(${CYT_DIR}/scripts/checks/check_v80_r5_platform.tcl.in ${CMAKE_BINARY_DIR}/check_v80_r5_platform.tcl)
    endif()
    if(EN_V80_R5_PROVIDER)
        configure_file(${CYT_DIR}/scripts/checks/check_v80_r5_provider_project.tcl.in ${CMAKE_BINARY_DIR}/check_v80_r5_provider_project.tcl)
    endif()

    # Dynamic and app scripts
    if (FPGA_ARCH STREQUAL "versal")
        configure_file(${CYT_DIR}/scripts/dyn/flow_dyn_versal.tcl.in ${CMAKE_BINARY_DIR}/flow_dyn.tcl)
    elseif(FPGA_ARCH STREQUAL "ultrascale_plus")
        configure_file(${CYT_DIR}/scripts/dyn/flow_dyn_ultrascale_plus.tcl.in ${CMAKE_BINARY_DIR}/flow_dyn.tcl)
    else()
        message(FATAL_ERROR "Unsupported FPGA architecture.")
    endif()
    configure_file(${CYT_DIR}/scripts/dyn/flow_app.tcl.in ${CMAKE_BINARY_DIR}/flow_app.tcl)

    # Bitgen
    configure_file(${CYT_DIR}/scripts/impl/bitgen.tcl.in ${CMAKE_BINARY_DIR}/bitgen.tcl)

    # AMC firmware build wrapper (V80 + EN_AMC=1 only — but always generated so
    # invocations from bitgen.tcl have a valid path even when AMC is disabled;
    # it short-circuits with a no-op in that case).
    if (EN_AMC)
        configure_file(${CYT_DIR}/scripts/fw/build_amc.sh.in ${CMAKE_BINARY_DIR}/build_amc.sh @ONLY)
        # Make it executable
        execute_process(COMMAND chmod +x ${CMAKE_BINARY_DIR}/build_amc.sh)
    endif()

    # Export CMake config. Keep the disabled output byte-identical; the logical
    # co-processor contract is appended only when ports are present.
    configure_file(${CYT_DIR}/scripts/export.cmake.in ${CMAKE_BINARY_DIR}/export.cmake)
    if(N_COPROCESSOR_PORTS GREATER 0)
        configure_file(${CYT_DIR}/scripts/coprocessor-export.cmake.in ${CMAKE_BINARY_DIR}/coprocessor-export.cmake)
        file(READ ${CMAKE_BINARY_DIR}/coprocessor-export.cmake coprocessor_export)
        file(APPEND ${CMAKE_BINARY_DIR}/export.cmake "\n${coprocessor_export}")
    endif()
    if(EN_V80_R5_PLATFORM)
        configure_file(${CYT_DIR}/scripts/v80-r5-platform-export.cmake.in ${CMAKE_BINARY_DIR}/v80-r5-platform-export.cmake)
        file(READ ${CMAKE_BINARY_DIR}/v80-r5-platform-export.cmake v80_r5_platform_export)
        file(APPEND ${CMAKE_BINARY_DIR}/export.cmake "\n${v80_r5_platform_export}")
    endif()
endmacro()

# Generate dependency lists
macro(gen_dep_lists)
    MATH(EXPR NN_CONFIG "${N_CONFIG} - 1")
    MATH(EXPR NN_REGIONS "${N_REGIONS} - 1")

    # Synthesis
    set(DEP_DCP_LIST_SYNTH_STATIC ${CMAKE_BINARY_DIR}/checkpoints/static/static_synthed.dcp)
    set(DEP_DCP_LIST_SYNTH_SHELL ${CMAKE_BINARY_DIR}/checkpoints/shell/shell_synthed.dcp)
    set(DEP_DCP_LIST_SYNTH_USER  "")
    foreach(i RANGE ${NN_CONFIG})
        foreach(j RANGE ${NN_REGIONS})
            list(APPEND DEP_DCP_LIST_SYNTH_USER ${CMAKE_BINARY_DIR}/checkpoints/config_${i}/user_synthed_c${i}_${j}.dcp)
        endforeach() 
    endforeach()

    # Link
    set(DEP_DCP_LIST_LINK  ${CMAKE_BINARY_DIR}/checkpoints/shell_linked.dcp)

    # Compile
    if(EN_PR)
        # Nested DFX not supported on Versal devices; hence, pr_subdivide and pr_recombine are not available
        # For Versal devices, shell reconfiguration is explicitly disabled when application-level PR is enabled
        # The synthesised checkpoints and the vFPGA floorplans are linked and routed for each configuration
        # More details can be found in gen_targets and the script flow_dyn_versal.tcl
        if(BUILD_SHELL AND FPGA_ARCH STREQUAL "ultrascale_plus")
            # pnr_shell.tcl owns shell_routed.dcp; flow_dyn.tcl subsequently
            # subdivides it and owns shell_subdivided.dcp.
            set(DEP_DCP_LIST_COMP ${CMAKE_BINARY_DIR}/checkpoints/shell_routed.dcp)
        elseif(BUILD_APP)
            set(DEP_DCP_LIST_COMP ${SHELL_PATH}/checkpoints/shell_routed_locked.dcp)
            foreach(i RANGE ${NN_CONFIG})
                foreach(j RANGE ${NN_REGIONS})
                    list(APPEND DEP_DCP_LIST_COMP ${CMAKE_BINARY_DIR}/checkpoints/config_${i}/user_synthed_c${i}_${j}.dcp)
                endforeach()
            endforeach()
        else()
            set(DEP_DCP_LIST_COMP "")
        endif()
    else()
        set(DEP_DCP_LIST_COMP ${CMAKE_BINARY_DIR}/checkpoints/shell_routed.dcp)
    endif()

    # Dynamic
    # Declare every shell artifact owned by the dynamic flow, including the
    # locked checkpoint exported to later BUILD_APP invocations.
    set(DEP_DCP_LIST_DYN "")
    if(BUILD_SHELL)
        if(FPGA_ARCH STREQUAL "ultrascale_plus")
            list(APPEND DEP_DCP_LIST_DYN
                ${CMAKE_BINARY_DIR}/checkpoints/shell_subdivided.dcp
                ${CMAKE_BINARY_DIR}/checkpoints/shell_recombined.dcp
            )
        else()
            # Versal does not support subdivision/recombination; its dynamic
            # flow routes the complete shell around the application RPs.
            list(APPEND DEP_DCP_LIST_DYN ${CMAKE_BINARY_DIR}/checkpoints/shell_routed.dcp)
        endif()
        list(APPEND DEP_DCP_LIST_DYN ${CMAKE_BINARY_DIR}/checkpoints/shell_routed_locked.dcp)
    endif()
    foreach(i RANGE ${NN_CONFIG})
        list(APPEND DEP_DCP_LIST_DYN ${CMAKE_BINARY_DIR}/checkpoints/config_${i}/shell_routed_c${i}.dcp)
    endforeach()

    # Bitgen
    if(BUILD_STATIC)
        if (FPGA_ARCH STREQUAL "ultrascale_plus")
            set(DEP_DCP_LIST_BGEN  ${CMAKE_BINARY_DIR}/checkpoints/cyt_top.bit)
        else()
            set(DEP_DCP_LIST_BGEN  ${CMAKE_BINARY_DIR}/checkpoints/cyt_top.pdi)
        endif()
    else()
        if(BUILD_SHELL)
            if (FPGA_ARCH STREQUAL "ultrascale_plus")
                set(DEP_DCP_LIST_BGEN  ${CMAKE_BINARY_DIR}/checkpoints/shell_top.bit)
            else()
                set(DEP_DCP_LIST_BGEN  ${CMAKE_BINARY_DIR}/checkpoints/shell_top.pdi)
            endif()
        else()
            set(DEP_DCP_LIST_BGEN  "")
        endif()
        if(EN_PR)
            # PR bitgen writes deployable artifacts under bitstreams/. App-only
            # builds intentionally declare no full-shell output.
            set(DEP_DCP_LIST_BGEN "")
            if(BUILD_SHELL)
                if(FPGA_ARCH STREQUAL "ultrascale_plus")
                    list(APPEND DEP_DCP_LIST_BGEN
                        ${CMAKE_BINARY_DIR}/bitstreams/shell_top.bin
                        ${CMAKE_BINARY_DIR}/bitstreams/cyt_top.bit
                    )
                else()
                    list(APPEND DEP_DCP_LIST_BGEN ${CMAKE_BINARY_DIR}/bitstreams/cyt_top.pdi)
                endif()
            endif()

            if(FPGA_ARCH STREQUAL "ultrascale_plus")
                foreach(i RANGE ${NN_CONFIG})
                    foreach(j RANGE ${NN_REGIONS})
                        list(APPEND DEP_DCP_LIST_BGEN ${CMAKE_BINARY_DIR}/bitstreams/config_${i}/vfpga_c${i}_${j}.bin)
                    endforeach()
                endforeach()
            else()
                foreach(i RANGE ${NN_CONFIG})
                    foreach(j RANGE ${NN_REGIONS})
                        list(APPEND DEP_DCP_LIST_BGEN ${CMAKE_BINARY_DIR}/bitstreams/config_${i}/vfpga_c${i}_${j}.pdi)
                    endforeach()
                endforeach()
            endif()
        endif()
    endif()

endmacro()

# Generate build targets
macro(gen_targets)
    if(EN_NET)
        add_subdirectory(${CYT_DIR}/hw/services/network ${CMAKE_BINARY_DIR}/network)
        set(NET_SYNTH_CMD COMMAND make services)
    endif()

    if(LOAD_APPS)
        if(VITIS_HLS_MODE STREQUAL "vitis_hls")
            set(HLS_SYNTH_CMD COMMAND ${VITIS_HLS_BINARY} -f comp_hls.tcl)
        else()
            set(HLS_SYNTH_CMD COMMAND ${VITIS_HLS_BINARY} --tcl comp_hls.tcl --mode hls)
        endif()
        set(SPINAL_HDL_GEN_CMD COMMAND ${VIVADO_BINARY} -mode tcl -source ${CMAKE_BINARY_DIR}/comp_spinal.tcl -notrace)
    endif()

    # Shell flow
    set(STATIC_PRJCT_CMD COMMAND ${VIVADO_BINARY} -mode tcl -source ${CMAKE_BINARY_DIR}/cr_static.tcl -notrace)
    set(SHELL_PRJCT_CMD COMMAND ${VIVADO_BINARY} -mode tcl -source ${CMAKE_BINARY_DIR}/cr_shell.tcl -notrace)
    set(APP_PRJCT_CMD COMMAND ${VIVADO_BINARY} -mode tcl -source ${CMAKE_BINARY_DIR}/cr_user.tcl -notrace)
    set(SIM_PRJCT_CMD COMMAND ${VIVADO_BINARY} -mode tcl -source ${CMAKE_BINARY_DIR}/cr_sim.tcl -notrace)

    set(SYNTH_CMD_STATIC  COMMAND ${VIVADO_BINARY} -mode tcl -source ${CMAKE_BINARY_DIR}/synth_static.tcl -notrace)
    set(SYNTH_CMD_SHELL   COMMAND ${VIVADO_BINARY} -mode tcl -source ${CMAKE_BINARY_DIR}/synth_shell.tcl -notrace)
    set(SYNTH_CMD_USER    COMMAND ${VIVADO_BINARY} -mode tcl -source ${CMAKE_BINARY_DIR}/synth_user.tcl -notrace)

    set(LINK_CMD COMMAND ${VIVADO_BINARY} -mode tcl -source ${CMAKE_BINARY_DIR}/link.tcl -notrace)

    set(COMP_CMD COMMAND ${VIVADO_BINARY} -mode tcl -source ${CMAKE_BINARY_DIR}/pnr_shell.tcl -notrace)

    set(DYN_CMD COMMAND ${VIVADO_BINARY} -mode tcl -source ${CMAKE_BINARY_DIR}/flow_dyn.tcl -notrace)
    set(APP_CMD COMMAND ${VIVADO_BINARY} -mode tcl -source ${CMAKE_BINARY_DIR}/flow_app.tcl -notrace)
    
    set(BGEN_CMD COMMAND ${VIVADO_BINARY} -mode tcl -source ${CMAKE_BINARY_DIR}/bitgen.tcl -notrace)
    if(EN_V80_R5_PLATFORM)
        set(PLATFORM_CMD COMMAND ${VIVADO_BINARY} -mode tcl -source ${CMAKE_BINARY_DIR}/export_platform.tcl -notrace)
        set(PLATFORM_CHECK_CMD COMMAND ${VIVADO_BINARY} -mode tcl -source ${CMAKE_BINARY_DIR}/check_v80_r5_platform.tcl -notrace)
    endif()
    if(EN_V80_R5_PROVIDER)
        set(PROVIDER_PROJECT_CHECK_CMD COMMAND ${VIVADO_BINARY} -mode tcl -source ${CMAKE_BINARY_DIR}/check_v80_r5_provider_project.tcl -notrace)
    endif()

    # Dependencies
    gen_dep_lists()

    # Sim
    # -----------------------------------
    add_custom_target(sim
        ${HLS_SYNTH_CMD}
        ${SPINAL_HDL_GEN_CMD}
        ${SIM_PRJCT_CMD}
    )
    # Compile DPI-C library for test bench
    add_subdirectory(${CYT_DIR}/sim/hw/dpi ${CMAKE_BINARY_DIR}/dpi)
    add_dependencies(sim sim_dpi_c)

    # Project
    # -----------------------------------
    if(BUILD_STATIC)
        add_custom_target(project
            ${NET_SYNTH_CMD}
            ${HLS_SYNTH_CMD}
            ${SPINAL_HDL_GEN_CMD}
            ${STATIC_PRJCT_CMD}
            ${SHELL_PRJCT_CMD}
            ${APP_PRJCT_CMD}
        )
    elseif(BUILD_SHELL)
        add_custom_target(project 
            ${NET_SYNTH_CMD}
            ${HLS_SYNTH_CMD}
            ${SPINAL_HDL_GEN_CMD}
            ${SHELL_PRJCT_CMD}
            ${APP_PRJCT_CMD}
        )
    elseif(BUILD_APP)
        add_custom_target(project 
            ${HLS_SYNTH_CMD}
            ${SPINAL_HDL_GEN_CMD}
            ${APP_PRJCT_CMD}
        )
    endif()

    # Synth
    # -----------------------------------
    add_custom_target(synth 
        DEPENDS ${DEP_DCP_LIST_SYNTH_USER}
    )

    if(BUILD_APP)
        add_custom_command(
            OUTPUT ${DEP_DCP_LIST_SYNTH_USER}
            ${SYNTH_CMD_USER}
        )
    else()
        add_custom_command(
            OUTPUT ${DEP_DCP_LIST_SYNTH_USER}
            ${SYNTH_CMD_USER}
            DEPENDS ${DEP_DCP_LIST_SYNTH_SHELL}
        )

        if(BUILD_SHELL)
            add_custom_command(
                OUTPUT ${DEP_DCP_LIST_SYNTH_SHELL}
                ${SYNTH_CMD_SHELL}
            )
        
        elseif(BUILD_STATIC)
            add_custom_command(
                OUTPUT ${DEP_DCP_LIST_SYNTH_SHELL}
                ${SYNTH_CMD_SHELL}
                DEPENDS ${DEP_DCP_LIST_SYNTH_STATIC}
            )

            add_custom_command(
                OUTPUT ${DEP_DCP_LIST_SYNTH_STATIC}
                ${SYNTH_CMD_STATIC}
            )
        endif()
    endif()


    if(BUILD_SHELL OR BUILD_STATIC) 
        # Versal devices do not support nested DFX (shell subdivision and recombination);
        # therefore, the shell is not linked and routed with the default configuration (#0) when PR is enabled;
        # instead, we directly load synthesised DCPs and the floorplan, and run PnR for each configuration
        if (NOT (EN_PR AND FPGA_ARCH STREQUAL "versal"))
            # Linking
            # -----------------------------------
            add_custom_target(link 
                DEPENDS ${DEP_DCP_LIST_LINK}
            )

            add_custom_command(
                OUTPUT ${DEP_DCP_LIST_LINK}
                ${LINK_CMD}
                DEPENDS ${DEP_DCP_LIST_SYNTH_USER}
            )

            # Shell place & route
            # -----------------------------------
            add_custom_target(shell 
                DEPENDS ${DEP_DCP_LIST_COMP}
            )

            add_custom_command(
                OUTPUT ${DEP_DCP_LIST_COMP}
                ${COMP_CMD}
                DEPENDS ${DEP_DCP_LIST_LINK}
            )
        endif()
    endif()

    # Fixed hardware platform
    # -----------------------------------
    if(EN_V80_R5_PROVIDER)
        add_custom_target(provider-project-design-check ${PROVIDER_PROJECT_CHECK_CMD})
        add_dependencies(provider-project-design-check project)
    endif()
    if(EN_V80_R5_PLATFORM)
        set(V80_R5_PLATFORM_XSA ${CMAKE_BINARY_DIR}/platform/cyt_top.xsa)
        add_custom_target(platform-design-check ${PLATFORM_CHECK_CMD})
        add_dependencies(platform-design-check project)
        add_custom_target(platform DEPENDS ${V80_R5_PLATFORM_XSA})
        add_custom_command(
            OUTPUT ${V80_R5_PLATFORM_XSA}
            ${PLATFORM_CMD}
            DEPENDS ${CMAKE_BINARY_DIR}/checkpoints/shell_routed.dcp
        )
    endif()

    # Bitgen
    # -----------------------------------
    add_custom_target(bitgen 
        DEPENDS ${DEP_DCP_LIST_BGEN}
    )

    if(EN_PR)
        add_custom_command(
            OUTPUT ${DEP_DCP_LIST_BGEN}
            ${BGEN_CMD}
            DEPENDS ${DEP_DCP_LIST_DYN}
        )

        add_custom_target(app
            DEPENDS ${DEP_DCP_LIST_DYN}
        )

        if(BUILD_APP)
            add_custom_command(
                OUTPUT ${DEP_DCP_LIST_DYN}
                ${APP_CMD}
                DEPENDS ${DEP_DCP_LIST_COMP}
            )
        else()
            # On UltraScale+ devices (which support nested DFX), the partial vFPGA bitstreams are 
            # generated by subdividing the full routed shell and running PnR on for each vFPGA configuration
            if(FPGA_ARCH STREQUAL "ultrascale_plus")
                add_custom_command(
                    OUTPUT ${DEP_DCP_LIST_DYN}
                    ${DYN_CMD}
                    DEPENDS ${DEP_DCP_LIST_COMP}
                )
            # Versal devices, however, do not support nested DFX, and as such, no shell subdivision/recombination
            # Therefore, the shell is not linked and routed; instead, it loads the synthesised DCPs for the
            # static layer, the shell and the vFPGAs, as well as the floorplans and runs PnR for each configuration
            elseif(FPGA_ARCH STREQUAL "versal")
                add_custom_command(
                    OUTPUT ${DEP_DCP_LIST_DYN}
                    ${DYN_CMD}
                    DEPENDS ${DEP_DCP_LIST_SYNTH_USER}
                )
            else()
                message(FATAL_ERROR "Unsupported FPGA architecture.")
            endif()
        endif()
    else()
        add_custom_command(
            OUTPUT ${DEP_DCP_LIST_BGEN}
            ${BGEN_CMD}
            DEPENDS ${DEP_DCP_LIST_COMP}
        )
    endif()

endmacro()

# Create build
macro(create_hw)
    gen_scripts()
    gen_targets()

endmacro()