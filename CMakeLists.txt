cmake_minimum_required(VERSION 3.28)

project(raytracer VERSION 0.1.0 LANGUAGES CXX)

option(RT_BUILD_TESTS "Build the unit tests" ON)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

list(APPEND CMAKE_MODULE_PATH "${PROJECT_SOURCE_DIR}/cmake")
include(Warnings)
include(Dependencies)

add_subdirectory(src)
add_subdirectory(app)

if(RT_BUILD_TESTS)
    enable_testing()
    add_subdirectory(tests)
endif()
