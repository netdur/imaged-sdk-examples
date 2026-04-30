cmake_minimum_required(VERSION 3.22)

project(live_caption_native LANGUAGES C)

add_library(OpenCL SHARED opencl_stub.c)
set_target_properties(OpenCL PROPERTIES OUTPUT_NAME OpenCL)
target_link_options(
    OpenCL
    PRIVATE
    "-Wl,--version-script=${CMAKE_CURRENT_SOURCE_DIR}/opencl_stub.map"
)
