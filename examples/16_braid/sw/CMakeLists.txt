cmake_minimum_required(VERSION 3.5)
project(example_16_braid)

if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release CACHE STRING "Build type" FORCE)
endif()

option(EN_SIM "Enable simulation mode for Coyote" OFF)

if(EN_SIM)
    add_subdirectory(../../../sim/sw ${CMAKE_BINARY_DIR}/coyote)
else()
    add_subdirectory(../../../sw ${CMAKE_BINARY_DIR}/coyote)
endif()

message("*** Coyote Example 16: BRAID syndrome link [Software] ***")

set(TARGET_DIR "${CMAKE_SOURCE_DIR}/src/")

set(EXEC braid)
add_executable(${EXEC} ${TARGET_DIR}/main.cpp)
target_include_directories(${EXEC} PRIVATE ${TARGET_DIR})
target_link_libraries(${EXEC} PUBLIC Coyote)

find_package(Boost REQUIRED COMPONENTS program_options)
target_link_libraries(${EXEC} PUBLIC Boost::program_options)
