# CMakeLists.txt — OronBox wasm3 native bridge for HarmonyOS
#
# Builds libwasm3.so (the wasm3 interpreter + our C ABI bridge) that the
# Dart side loads via dart:ffi to execute the Opus decoder and WebP encoder
# .wasm assets on OpenHarmony.

cmake_minimum_required(VERSION 3.16)

project(wasm3bridge C)

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
