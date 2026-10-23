# CMake configuration
cmake_minimum_required(VERSION 3.5)
project(example_13_micro_blossom)

if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release CACHE STRING "Build type" FORCE)
endif()

option(EN_SIM "Enable simulation mode for Coyote" OFF)

if(EN_SIM)
    add_subdirectory(../../../sim/sw ${CMAKE_BINARY_DIR}/coyote)
else()
    add_subdirectory(../../../sw ${CMAKE_BINARY_DIR}/coyote)
endif()

message("*** Coyote Example 13: Micro Blossom QEC Decoder [Software] ***")

set(TARGET_DIR "${CMAKE_SOURCE_DIR}/src/")

# ---- Smoke test (host control path only) --------------------------------
set(EXEC test)
add_executable(${EXEC} ${TARGET_DIR}/main.cpp)
target_link_libraries(${EXEC} PUBLIC Coyote)

# ---- Host-driven decode (primal on host CPU, dual in vFPGA) --------------
# Reuses Micro Blossom's Rust primal+control loop (the `blossom` crate) as a
# static library; decode_main.cpp + mb_csr.cpp supply the Coyote CSR transport.
option(EN_DECODE "Build the host-driven Micro Blossom decoder (needs the Rust toolchain)" ON)
if(EN_DECODE)
    set(MB_RUST_DIR "/scratch/anubhav/micro-blossom/src/cpu/blossom")
    set(MB_RUST_LIB "${MB_RUST_DIR}/target/release/libmicro_blossom.a")

    add_custom_command(
        OUTPUT ${MB_RUST_LIB}
        COMMAND cargo build --release --lib
        WORKING_DIRECTORY ${MB_RUST_DIR}
        COMMENT "Building Micro Blossom Rust staticlib (libmicro_blossom.a)"
        VERBATIM
    )
    add_custom_target(mb_rust DEPENDS ${MB_RUST_LIB})

    add_executable(decode ${TARGET_DIR}/decode_main.cpp ${TARGET_DIR}/mb_csr.cpp)
    add_dependencies(decode mb_rust)
    target_include_directories(decode PRIVATE ${TARGET_DIR})
    # --start-group resolves the cross-references: the Rust archive imports
    # mb_csr_* from mb_csr.o, and decode_main.o calls mb_decode_and_check from
    # the archive. The Rust staticlib drags in std -> pthread/dl/m + unwind.
    target_link_libraries(decode PUBLIC Coyote
        -Wl,--start-group ${MB_RUST_LIB} -Wl,--end-group
        pthread dl m)
endif()
