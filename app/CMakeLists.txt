add_executable(raytracer main.cpp)
target_link_libraries(raytracer PRIVATE rt::rt)
rt_set_warnings(raytracer)
