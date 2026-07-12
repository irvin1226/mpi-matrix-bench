cmake_minimum_required(VERSION 3.15 FATAL_ERROR)
project(mpi-matrix-bench CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -D_FILE_OFFSET_BITS=64")
set(CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} -Wall --pedantic -g -O0 -D_DEBUG")
set(CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/CMake" ${CMAKE_MODULE_PATH})
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_SOURCE_DIR})
set(CMAKE_EXPORT_COMPILE_COMMANDS 1)
set(CMAKE_BUILD_TYPE Debug)

find_package(MPI REQUIRED)

set(SOURCE_FILES src/matrix_mult.cpp)
add_executable(matrix_mult ${SOURCE_FILES})

target_link_libraries(matrix_mult MPI::MPI_CXX)
target_include_directories(matrix_mult PRIVATE ${MPI_CXX_INCLUDE_DIRS})