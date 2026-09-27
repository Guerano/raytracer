include(FetchContent)

# RT_DEPS_CACHE, when set, holds dependency sources shared by every build tree of every worktree.
# Only sources are shared: each build tree keeps its own subbuild and binary directories.
set(RT_DEPS_CACHE "" CACHE PATH "Shared directory for FetchContent sources (optional)")

function(rt_declare_dependency name repository tag)
    string(TOUPPER "${name}" upperName)
    if(RT_DEPS_CACHE)
        set(sourceDir "${RT_DEPS_CACHE}/${name}-${tag}")
        if(EXISTS "${sourceDir}/CMakeLists.txt")
            set(FETCHCONTENT_SOURCE_DIR_${upperName} "${sourceDir}" PARENT_SCOPE)
        endif()
        FetchContent_Declare(${name}
            GIT_REPOSITORY "${repository}" GIT_TAG "${tag}" GIT_SHALLOW TRUE
            SOURCE_DIR "${sourceDir}" SYSTEM)
    else()
        FetchContent_Declare(${name}
            GIT_REPOSITORY "${repository}" GIT_TAG "${tag}" GIT_SHALLOW TRUE SYSTEM)
    endif()
endfunction()

if(RT_BUILD_TESTS)
    rt_declare_dependency(Catch2 https://github.com/catchorg/Catch2.git v3.8.1)
    FetchContent_MakeAvailable(Catch2)
endif()
