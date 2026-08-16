cmake_minimum_required(VERSION 3.5)
project(example_15_amc_ping)

if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release CACHE STRING "Build type" FORCE)
endif()

# This test uses raw PCIe BAR4 mmap (sysfs resource4) — no Coyote runtime needed
# for Phase A. Once a proper GCQ host driver lands we'll switch to cThread/GCQ.

message("*** Coyote Example 15: AMC Ping [Software] ***")

find_package(Boost REQUIRED COMPONENTS program_options)

# 1) 'test' — raw PCIe BAR4 mmap VMR0 read (Phase A first-light). No Coyote runtime.
add_executable(test src/main.cpp)
target_link_libraries(test PUBLIC Boost::program_options)
set_property(TARGET test PROPERTY CXX_STANDARD 17)

# 2) 'amc_vfpga_demo' — exercises the functional vFPGA (cThread +1 loopback) AND
#    the AMC mailbox (via the driver's MMAP_AMC region) in one process, proving
#    coexistence. Links the Coyote runtime for cThread.
add_subdirectory(../../../sw ${CMAKE_BINARY_DIR}/coyote)
add_executable(amc_vfpga_demo src/amc_vfpga_demo.cpp)
target_link_libraries(amc_vfpga_demo PUBLIC Coyote Boost::program_options)
set_property(TARGET amc_vfpga_demo PROPERTY CXX_STANDARD 17)

# 3) 'ocm_verdict' — reads the R5's vFPGA<->R5 OCM channel self-test verdict from
#    the AMC DDR window (raw MMAP_AMC mmap, no Coyote runtime). See amc.c/ocm_mbx.sv.
add_executable(ocm_verdict src/ocm_verdict.cpp)
set_property(TARGET ocm_verdict PROPERTY CXX_STANDARD 17)
