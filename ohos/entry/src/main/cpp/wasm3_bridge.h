/*
 * wasm3_bridge.h
 *
 * Stable C ABI exposed to Dart via dart:ffi.
 *
 * This is the bridge between the Dart side (package:oronbox wasm runtime)
 * and the wasm3 interpreter. It wraps wasm3's API into a small, stable,
 * pointer-based C interface so that Dart only has to deal with opaque
 * handles and fixed-size numeric/pointer values.
 *
 * Design notes:
 *   - Every object (environment, runtime, module, instance, function,
 *     memory) is represented by an opaque `uintptr_t`-sized handle.
 *   - Host import functions are registered through a single callback type
 *     `Wasm3HostCall`, which receives the raw function pointer stack `_sp`
 *     and memory base `_mem` exactly as wasm3 hands them to a M3RawCall.
 *   - Value marshalling between Dart and wasm3 uses little-endian fixed
 *     width slots (i32/i64/f32/f64) so Dart's FFI can read/write them
 *     through ByteData views.
 */

#ifndef WASM3_BRIDGE_H
#define WASM3_BRIDGE_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/* ---------------------------------------------------------------------------
 * Opaque handles (returned and consumed by Dart, never dereferenced there).
 * ------------------------------------------------------------------------- */

typedef void* WbWasmEnvironment;
typedef void* WbWasmRuntime;
typedef void* WbWasmModule;
typedef void* WbWasmFunction;

/* A host (Dart) callback that backs a wasm import.
 *
 *   runtime   - the runtime that owns the call
 *   userdata  - opaque pointer set at link time (WbLinkFunction)
 *   sp        - wasm3 raw call stack (uint64_t slots); return slots first,
 *               then arguments. See wasm3.h m3Api* macros for the layout.
 *   mem       - linear memory base of the calling module (may be NULL)
 *
 * The callback must return a value usable as an M3Result (const void*):
 *   NULL (m3Err_none == 0) on success, or an M3Result error pointer.
 * Because m3Err_none is 0 and errors are small consts, returning an
 * integer-cast pointer is sufficient.
 */
typedef const void* (*WbHostCall)(void* runtime, void* userdata,
                                  uint64_t* sp, void* mem);

/* ---------------------------------------------------------------------------
 * Environment & runtime
 * ------------------------------------------------------------------------- */

WbWasmEnvironment wb_wasm_new_environment(void);
void              wb_wasm_free_environment(WbWasmEnvironment env);

WbWasmRuntime     wb_wasm_new_runtime(WbWasmEnvironment env,
                                      uint32_t stack_size_bytes,
                                      void* userdata);
void              wb_wasm_free_runtime(WbWasmRuntime rt);

/* Returns the last error info of `rt` into a caller-provided buffer.
 * Returns the number of bytes written (excluding NUL), or 0 if none. */
int               wb_wasm_get_error(WbWasmRuntime rt, char* buf, int buf_len);

/* ---------------------------------------------------------------------------
 * Module compilation
 * ------------------------------------------------------------------------- */

/* Parses a wasm binary (does NOT load/instantiate it). Returns a module
 * handle or NULL on failure. The module must be loaded via
 * wb_wasm_load_module before imports are linked and the start section runs. */
WbWasmModule wb_wasm_compile(WbWasmRuntime rt,
                             const uint8_t* wasm_bytes,
                             uint32_t num_bytes);

/* Loads a parsed module into a runtime (does NOT run the start section).
 * must be called BEFORE linking imports: wasm3 requires the module to be
 * loaded into a runtime before m3_LinkRawFunctionEx can find its imports.
 * Returns 0 on success, non-zero on failure. */
int wb_wasm_load_module(WbWasmRuntime rt, WbWasmModule module);

/* Runs the module's start section (if present). Must be called AFTER all
 * imports are linked. Returns 0 on success, non-zero on failure. */
int wb_wasm_run_start(WbWasmModule module);

/* Loads + instantiates a parsed module into its runtime, running the start
 * section if present. Back-compat convenience; modules with imports must use
 * wb_wasm_load_module -> link imports -> wb_wasm_run_start instead.
 * Returns 0 on success, non-zero on failure. */
int wb_wasm_instantiate(WbWasmRuntime rt, WbWasmModule module);

void         wb_wasm_free_module(WbWasmModule module);

/* ---------------------------------------------------------------------------
 * Host function linking (imports)
 * ---------------------------------------------------------------------------

 * `signature` uses wasm3's signature language:
 *   return types (0..N) then '(' arg types ')'.
 *   'v'=void 'i'=i32 'I'=i64 'f'=f32 'F'=f64 '*'=i32(pointer)
 *   e.g. "v(ii)" = void (i32, i32); "i(iI)" = i32 (i32, i64).
 * Returns 0 on success, non-zero otherwise.
 */
int  wb_wasm_link_function(WbWasmModule module,
                           const char* module_name,
                           const char* function_name,
                           const char* signature,
                           WbHostCall callback,
                           void* userdata);

/* ---------------------------------------------------------------------------
 * Function lookup & calling
 * ---------------------------------------------------------------------------

 * Returns 1 if the function was found (stored in *out), else 0.
 * Function handles are only valid for the lifetime of the runtime.
 */
int wb_wasm_find_function(WbWasmFunction* out,
                          WbWasmRuntime rt,
                          const char* function_name);

/* Runs the function with the given raw argument slots.
 *   args  - pointer to packed argument slots (each 8 bytes, little-endian)
 *   argc  - number of arguments
 *   rets  - pointer to a buffer that will receive return slots
 *   retc  - number of return slots to read back
 * Returns 0 on success, non-zero on trap/error.
 */
int wb_wasm_call(WbWasmFunction fn,
                 const uint64_t* args, uint32_t argc,
                 uint64_t* rets, uint32_t retc);

/* Argument/return reflection (for Dart's module introspection). */
uint32_t wb_wasm_arg_count(WbWasmFunction fn);
uint32_t wb_wasm_ret_count(WbWasmFunction fn);
/* Type ids: 0=none 1=i32 2=i64 3=f32 4=f64 (mirror wasm3 M3ValueType). */
int      wb_wasm_arg_type(WbWasmFunction fn, uint32_t index);
int      wb_wasm_ret_type(WbWasmFunction fn, uint32_t index);

/* ---------------------------------------------------------------------------
 * Memory access
 * ---------------------------------------------------------------------------

 * Returns the linear memory base pointer and size of the module's memory
 * at `memory_index` (almost always 0). Returns NULL if absent.
 */
uint8_t* wb_wasm_get_memory(WbWasmModule module,
                            uint32_t memory_index,
                            size_t* out_size_bytes);

/* Grows memory by `delta_pages`. Returns new page count, or 0 on failure. */
uint32_t wb_wasm_grow_memory(WbWasmModule module, uint32_t delta_pages);

/* Current memory size in pages. */
uint32_t wb_wasm_memory_pages(WbWasmModule module);

#ifdef __cplusplus
}
#endif

#endif /* WASM3_BRIDGE_H */
