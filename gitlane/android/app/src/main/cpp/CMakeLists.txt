cmake_minimum_required(VERSION 3.18.1)
project("git_bridge")

# ─── Shared library exposed to JNI ───────────────────────────────────────────
add_library(git_bridge SHARED git_bridge.c)

# ─── Prebuilt libgit2 static library (placed per-ABI under jniLibs/) ─────────
add_library(git2 STATIC IMPORTED)
set_target_properties(git2 PROPERTIES
        IMPORTED_LOCATION ${CMAKE_SOURCE_DIR}/jniLibs/${ANDROID_ABI}/libgit2.a)

# ─── Headers for libgit2 ──────────────────────────────────────────────────────
target_include_directories(git_bridge PRIVATE ${CMAKE_SOURCE_DIR}/include)

# ─── System log library ───────────────────────────────────────────────────────
find_library(log-lib log)

# ─── Link everything ─────────────────────────────────────────────────────────
target_link_libraries(
        git_bridge
        git2
        ${log-lib}
)
