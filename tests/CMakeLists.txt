add_executable(rt_tests
    unit/VersionTests.cpp
)
target_link_libraries(rt_tests PRIVATE rt::rt Catch2::Catch2WithMain)
rt_set_warnings(rt_tests)

include(Catch)
catch_discover_tests(rt_tests)
