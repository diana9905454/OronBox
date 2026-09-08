# CMakeLists.txt — OronBox wasm3 native bridge for HarmonyOS
#
# Builds libwasm3.so (the wasm3 interpreter + our C ABI bridge) that the
# Dart side loads via dart:ffi to execute the Opus decoder and WebP encoder
# .wasm assets on OpenHarmony.

cmake_minimum_required(VERSION 3.16)

project(wasm3bridge C CXX)

# ---------------------------------------------------------------------------
# wasm3 interpreter core sources (pure C99, no platform deps beyond libc)
# ---------------------------------------------------------------------------
set(WASM3_DIR ${CMAKE_CURRENT_SOURCE_DIR}/wasm3)

set(WASM3_SOURCES
    ${WASM3_DIR}/m3_core.c
    ${WASM3_DIR}/m3_env.c
    ${WASM3_DIR}/m3_compile.c
    ${WASM3_DIR}/m3_exec.c
    ${WASM3_DIR}/m3_function.c
    ${WASM3_DIR}/m3_info.c
    ${WASM3_DIR}/m3_module.c
    ${WASM3_DIR}/m3_parse.c
    ${WASM3_DIR}/m3_validate.c
    ${WASM3_DIR}/m3_bind.c
    ${WASM3_DIR}/m3_code.c
)

# ---------------------------------------------------------------------------
# Bridge library
# ---------------------------------------------------------------------------
add_library(wasm3 SHARED
    wasm3_bridge.c
    ${WASM3_SOURCES}
)

target_include_directories(wasm3 PRIVATE
    ${WASM3_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}
)

# Keep the C ABI clean and produce an exportable shared object.
set_target_properties(wasm3 PROPERTIES
    C_STANDARD 99
    C_STANDARD_REQUIRED ON
    POSITION_INDEPENDENT_CODE ON
)

# wasm3 needs nothing beyond libc; the float ops and stack checks are
# self-contained. Keep release flags lean.
if(CMAKE_BUILD_TYPE STREQUAL "Release" OR NOT CMAKE_BUILD_TYPE)
    target_compile_options(wasm3 PRIVATE -O2 -fno-strict-aliasing)
else()
    target_compile_options(wasm3 PRIVATE -O0 -g)
endif()

# ---------------------------------------------------------------------------
# Install to the entry module's native library dir so hvigor packs it.
# hvigor links the CMake output through externalNativeOptions; this explicit
# copy is a fallback for manual builds.
# ---------------------------------------------------------------------------
install(TARGETS wasm3 LIBRARY DESTINATION libs/${OHOS_ARCH})

# ---------------------------------------------------------------------------
# QuickJS-NG JS engine (pure C99) + our C ABI bridge, for in-app JS plugin
# support. Produces libquickjs_c_bridge_plugin.so that the Dart side (a local
# fork of quickjs_engine) loads via dart:ffi on OpenHarmony. The source list
# mirrors the upstream package's native/CMakeLists.txt (quickjs.c +
# libregexp.c + libunicode.c + dtoa.c + the bridge cpp). quickjs-libc.c is
# intentionally NOT compiled (it drags in POSIX fork/exec deps unavailable in
# the restricted OpenHarmony libc).
# ---------------------------------------------------------------------------
set(QUICKJS_DIR ${CMAKE_CURRENT_SOURCE_DIR}/quickjs)

set(QUICKJS_SOURCES
    ${QUICKJS_DIR}/quickjs.c
    ${QUICKJS_DIR}/libregexp.c
    ${QUICKJS_DIR}/libunicode.c
    ${QUICKJS_DIR}/dtoa.c
)

add_library(quickjs_c_bridge_plugin SHARED
    quickjs_bridge.cpp
    ${QUICKJS_SOURCES}
)

target_include_directories(quickjs_c_bridge_plugin PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${QUICKJS_DIR}
)

# Same version string the upstream package defines for QuickJS-NG 0.14.0.
# OpenHarmony ships musl libc, which gates clock_gettime/CLOCK_MONOTONIC
# behind _GNU_SOURCE; alloca needs an explicit <alloca.h> include outside of
# __sun (quickjs.c relies on it). Verified against the NDK clang directly.
target_compile_definitions(quickjs_c_bridge_plugin PRIVATE
    CONFIG_VERSION="ng-0.14.0"
    _GNU_SOURCE
)

set_target_properties(quickjs_c_bridge_plugin PROPERTIES
    C_STANDARD 11
    C_STANDARD_REQUIRED ON
    CXX_STANDARD 17
    CXX_STANDARD_REQUIRED ON
    POSITION_INDEPENDENT_CODE ON
    OUTPUT_NAME quickjs_c_bridge_plugin
)

# QuickJS uses libm (pow/floor/etc.) and, on arm64 clang, C11 atomics via the
# bundled quickjs-c-atomics.h. Keep aliasing strictness relaxed as upstream does.
target_link_libraries(quickjs_c_bridge_plugin PRIVATE m)

if(CMAKE_BUILD_TYPE STREQUAL "Release" OR NOT CMAKE_BUILD_TYPE)
    target_compile_options(quickjs_c_bridge_plugin PRIVATE -O2 -fno-strict-aliasing -include alloca.h)
else()
    target_compile_options(quickjs_c_bridge_plugin PRIVATE -O0 -g -include alloca.h)
endif()

install(TARGETS quickjs_c_bridge_plugin LIBRARY DESTINATION libs/${OHOS_ARCH})
