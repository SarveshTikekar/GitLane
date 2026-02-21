cmake_minimum_required(VERSION 3.18.1)
project("git_bridge")

# ─── Shared library exposed to JNI ───────────────────────────────────────────
add_library(git_bridge SHARED git_bridge.c)

# ─── Prebuilt Static Libraries (per-ABI under jniLibs/) ───────────────────────

# libgit2
add_library(git2 STATIC IMPORTED)
set_target_properties(git2 PROPERTIES
        IMPORTED_LOCATION ${CMAKE_SOURCE_DIR}/../jniLibs/${ANDROID_ABI}/libgit2.a)

# mbedTLS stack
add_library(mbedtls STATIC IMPORTED)
set_target_properties(mbedtls PROPERTIES
        IMPORTED_LOCATION ${CMAKE_SOURCE_DIR}/../jniLibs/${ANDROID_ABI}/libmbedtls.a)

add_library(mbedx509 STATIC IMPORTED)
set_target_properties(mbedx509 PROPERTIES
        IMPORTED_LOCATION ${CMAKE_SOURCE_DIR}/../jniLibs/${ANDROID_ABI}/libmbedx509.a)

add_library(mbedcrypto STATIC IMPORTED)
set_target_properties(mbedcrypto PROPERTIES
        IMPORTED_LOCATION ${CMAKE_SOURCE_DIR}/../jniLibs/${ANDROID_ABI}/libmbedcrypto.a)

# ─── Headers for libgit2 ──────────────────────────────────────────────────────
target_include_directories(git_bridge PRIVATE ${CMAKE_SOURCE_DIR}/include)

# ─── System libraries ─────────────────────────────────────────────────────────
find_library(log-lib log)
find_library(z-lib z) # libgit2 needs zlib

# ─── Link everything (Order: git2 -> mbedtls -> x509 -> crypto) ───────────────
target_link_libraries(
        git_bridge
        git2
        mbedtls
        mbedx509
        mbedcrypto
        ${z-lib}
        ${log-lib}
)
