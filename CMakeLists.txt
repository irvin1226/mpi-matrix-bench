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

add_executable(matrix_mult_naive src/matrix_mult_naive.cpp)
target_link_libraries(matrix_mult_naive MPI::MPI_CXX)
target_include_directories(matrix_mult_naive PRIVATE ${MPI_CXX_INCLUDE_DIRS})

add_executable(matrix_mult_optimized src/matrix_mult_optimized.cpp)
target_link_libraries(matrix_mult_optimized MPI::MPI_CXX)
target_include_directories(matrix_mult_optimized PRIVATE ${MPI_CXX_INCLUDE_DIRS})

add_executable(matrix_mult_gpu src/matrix_mult_gpu.cpp)
target_link_libraries(matrix_mult_gpu MPI::MPI_CXX)
target_include_directories(matrix_mult_gpu PRIVATE ${MPI_CXX_INCLUDE_DIRS})