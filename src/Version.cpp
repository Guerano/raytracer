#include "rt/Version.hpp"

#include <string_view>

namespace rt {

std::string_view version() noexcept {
    return RT_VERSION;
}

} // namespace rt
