#include "rt/Version.hpp"

#include <cstdio>
#include <exception>
#include <iostream>

int main() {
    try {
        std::cout << "raytracer " << rt::version() << '\n';
        return 0;
    } catch (const std::exception& e) {
        std::fputs(e.what(), stderr);
        std::fputc('\n', stderr);
        return 1;
    }
}
