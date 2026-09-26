#include "rt/Version.hpp"

#include <catch2/catch_test_macros.hpp>

#include <algorithm>

TEST_CASE("version follows major.minor.patch", "[version]") {
    const auto version = rt::version();
    REQUIRE_FALSE(version.empty());
    CHECK(std::count(version.begin(), version.end(), '.') == 2);
}
