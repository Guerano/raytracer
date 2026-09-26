add_library(rt)
add_library(rt::rt ALIAS rt)

target_sources(rt PRIVATE
    Version.cpp
)
target_include_directories(rt PUBLIC "${PROJECT_SOURCE_DIR}/include")
target_compile_features(rt PUBLIC cxx_std_20)
target_compile_definitions(rt PRIVATE RT_VERSION="${PROJECT_VERSION}")
rt_set_warnings(rt)
