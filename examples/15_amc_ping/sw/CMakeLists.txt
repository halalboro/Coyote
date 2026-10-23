cmake_minimum_required(VERSION 3.5)
project(example_15_r5_coprocessor)

if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release CACHE STRING "Build type" FORCE)
endif()

message("*** Coyote Example 15: R5 Co-processor Provider [Software] ***")

# Self-contained host: binds the R5 provider via the co-processor control target
# (config region) and reads the self-test verdict from the vFPGA control region.
# Both are raw device mmaps, so no Coyote runtime / Boost is required.
add_executable(test src/main.cpp)
set_property(TARGET test PROPERTY CXX_STANDARD 17)
