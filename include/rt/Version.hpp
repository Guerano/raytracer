#pragma once

#include <string_view>

namespace rt {

// Library version, as declared in the top-level CMakeLists.txt.
[[nodiscard]] std::string_view version() noexcept;

} // namespace rt
