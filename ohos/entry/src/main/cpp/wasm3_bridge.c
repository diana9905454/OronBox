/*
 * wasm3_bridge.c
 *
 * Implementation of the stable C ABI for Dart (see wasm3_bridge.h).
 * Thin, minimal wrapper over the wasm3 interpreter.
 */

#include "wasm3_bridge.h"
#include "wasm3/wasm3.h"
#include "wasm3/m3_env.h"
#include "wasm3/m3_core.h"

#include <string.h>

/* M3Result is `const void*`; m3Err_none == 0. Our WbHostCall returns the same. */

WbWasmEnvironment wb_wasm_new_environment(void) {
  return (WbWasmEnvironment)m3_NewEnvironment();
}

void wb_wasm_free_environment(WbWasmEnvironment env) {
  if (env) m3_FreeEnvironment((IM3Environment)env);
}

WbWasmRuntime wb_wasm_new_runtime(WbWasmEnvironment env,
                                  uint32_t stack_size_bytes,
                                  void* userdata) {
  if (!env) return NULL;
  return (WbWasmRuntime)m3_NewRuntime((IM3Environment)env,
                                      stack_size_bytes, userdata);
}

void wb_wasm_free_runtime(WbWasmRuntime rt) {
  if (rt) m3_FreeRuntime((IM3Runtime)rt);
}

int wb_wasm_get_error(WbWasmRuntime rt, char* buf, int buf_len) {
  if (!rt || !buf || buf_len <= 0) return 0;
  M3ErrorInfo info;
  m3_GetErrorInfo((IM3Runtime)rt, &info);
  if (!info.message) return 0;
  int n = 0;
  while (n < buf_len - 1 && info.message[n]) {
    buf[n] = info.message[n];
    ++n;
  }
  buf[n] = '\0';
  return n;
}

WbWasmModule wb_wasm_compile(WbWasmRuntime rt,
                             const uint8_t* wasm_bytes,
                             uint32_t num_bytes) {
  if (!rt || !wasm_bytes || num_bytes == 0) return NULL;
  /* The runtime owns its environment; reach it through the (internal, but
   * stable) M3Runtime struct that m3_env.h exposes. */
  IM3Environment env = ((IM3Runtime)rt)->environment;
  IM3Module module = NULL;
  M3Result r = m3_ParseModule(env, &module, wasm_bytes, num_bytes);
  if (r) return NULL;
  return (WbWasmModule)module;
}

int wb_wasm_load_module(WbWasmRuntime rt, WbWasmModule module) {
  if (!rt || !module) return -1;
  M3Result r = m3_LoadModule((IM3Runtime)rt, (IM3Module)module);
  if (r) {
    /* m3_LoadModule's `_throw` path does not populate runtime->error, so
     * surface the M3Result string through m3Error so wb_wasm_get_error can
     * report the real cause instead of "unknown error". */
    m3Error(r, (IM3Runtime)rt, (IM3Module)module, NULL, __FILE__, __LINE__,
            "%s", r);
    return -2;
  }
  return 0;
}

int wb_wasm_run_start(WbWasmModule module) {
  if (!module) return -1;
  m3_RunStart((IM3Module)module);
  return 0;
}

int wb_wasm_instantiate(WbWasmRuntime rt, WbWasmModule module) {
  /* Back-compat: load then run start. New callers should link imports
   * between wb_wasm_load_module and wb_wasm_run_start (wasm3 requires the
   * module to be loaded into a runtime before imports can be linked). */
  int rc = wb_wasm_load_module(rt, module);
  if (rc) return rc;
  return wb_wasm_run_start(module);
}

void wb_wasm_free_module(WbWasmModule module) {
  /* A module handed to m3_LoadModule is owned by the runtime. A module that
   * was parsed but never loaded (e.g. compile failed downstream) must be
   * freed explicitly. */
  if (!module) return;
  IM3Module m = (IM3Module)module;
  if (!m3_GetModuleRuntime(m)) {
    m3_FreeModule(m);
  }
}

int wb_wasm_link_function(WbWasmModule module,
                          const char* module_name,
                          const char* function_name,
                          const char* signature,
                          WbHostCall callback,
                          void* userdata) {
  if (!module || !callback) return -1;
  /* wasm3's m3_LinkRawFunctionEx accepts a M3RawCall whose signature is
   * compatible with WbHostCall. We cast through the function pointer types;
   * they are ABI-identical for the common calling convention on arm64. */
  M3RawCall raw = (M3RawCall)callback;
  M3Result r = m3_LinkRawFunctionEx((IM3Module)module,
                                    module_name,
                                    function_name,
                                    signature,
                                    raw,
                                    userdata);
  if (r) {
    IM3Module m = (IM3Module)module;
    m3Error(r, m->runtime, m, NULL,
            __FILE__, __LINE__, "link %s.%s: %s", module_name, function_name, r);
  }
  return r ? 1 : 0;
}

int wb_wasm_find_function(WbWasmFunction* out,
                          WbWasmRuntime rt,
                          const char* function_name) {
  if (!out || !rt) return 0;
  IM3Function fn = NULL;
  M3Result r = m3_FindFunction(&fn, (IM3Runtime)rt, function_name);
  if (r || !fn) return 0;
  *out = (WbWasmFunction)fn;
  return 1;
}

int wb_wasm_call(WbWasmFunction fn,
                 const uint64_t* args, uint32_t argc,
                 uint64_t* rets, uint32_t retc) {
  if (!fn) return -1;
  IM3Function f = (IM3Function)fn;

  /* wasm3's m3_Call takes an array of `const void*` pointing at each argument
   * value. With d_m3Use32BitSlots=1, i32/f32 args are 32-bit; i64/f64 are
   * 64-bit. We pack everything into 64-bit slots from Dart, so we need to
   * present each argument with its correct width. To keep it simple and
   * correct we build per-argument pointers from the 64-bit slots, using
   * the reflected argument type to choose the width. */
  const void* argptrs[32];
  uint32_t n = m3_GetArgCount(f);
  if (n > 32) n = 32;
  uint32_t use = (argc < n) ? argc : n;

  /* Scratch 32-bit views for narrow args (avoid misaligned reads). */
  uint32_t narrow[32];

  for (uint32_t i = 0; i < use; ++i) {
    M3ValueType t = m3_GetArgType(f, i);
    if (t == c_m3Type_i32 || t == c_m3Type_f32) {
      narrow[i] = (uint32_t)(args[i] & 0xFFFFFFFFu);
      argptrs[i] = &narrow[i];
    } else {
      /* i64 / f64 — point directly at the 64-bit slot. */
      argptrs[i] = &args[i];
    }
  }

  M3Result r = m3_Call(f, use, argptrs);
  if (r) return -2;

  /* Read back return values. */
  const void* retptrs[32];
  uint32_t nr = m3_GetRetCount(f);
  uint32_t read = (retc < nr) ? retc : nr;
  if (read > 32) read = 32;

  uint64_t* retslots = rets;
  (void)retslots;
  /* Build return pointers. i32/f32 returns occupy a 32-bit slot; i64/f64 a
   * 64-bit slot. We widen into the 64-bit output buffer. */
  for (uint32_t i = 0; i < read; ++i) {
    M3ValueType t = m3_GetRetType(f, i);
    if (t == c_m3Type_i32 || t == c_m3Type_f32) {
      narrow[i] = 0;
      retptrs[i] = &narrow[i];
    } else {
      retptrs[i] = &rets[i];
    }
  }

  r = m3_GetResults(f, read, retptrs);
  if (r) return -3;

  /* Widen narrow results back into the 64-bit output slots. */
  for (uint32_t i = 0; i < read; ++i) {
    M3ValueType t = m3_GetRetType(f, i);
    if (t == c_m3Type_i32) {
      rets[i] = (uint64_t)(int64_t)(int32_t)narrow[i]; /* sign-extend i32 */
    } else if (t == c_m3Type_f32) {
      /* f32 result: bit pattern in narrow[i], zero-extend into slot */
      rets[i] = (uint64_t)narrow[i];
    }
  }

  return 0;
}

uint32_t wb_wasm_arg_count(WbWasmFunction fn) {
  return fn ? m3_GetArgCount((IM3Function)fn) : 0;
}

uint32_t wb_wasm_ret_count(WbWasmFunction fn) {
  return fn ? m3_GetRetCount((IM3Function)fn) : 0;
}

static int type_to_id(M3ValueType t) {
  switch (t) {
    case c_m3Type_i32: return 1;
    case c_m3Type_i64: return 2;
    case c_m3Type_f32: return 3;
    case c_m3Type_f64: return 4;
    default: return 0;
  }
}

int wb_wasm_arg_type(WbWasmFunction fn, uint32_t index) {
  return fn ? type_to_id(m3_GetArgType((IM3Function)fn, index)) : 0;
}

int wb_wasm_ret_type(WbWasmFunction fn, uint32_t index) {
  return fn ? type_to_id(m3_GetRetType((IM3Function)fn, index)) : 0;
}

uint8_t* wb_wasm_get_memory(WbWasmModule module,
                            uint32_t memory_index,
                            size_t* out_size_bytes) {
  if (!module) return NULL;
  size_t sz = 0;
  uint8_t* mem = m3_GetMemory((IM3Module)module, &sz, memory_index);
  if (out_size_bytes) *out_size_bytes = sz;
  return mem;
}

uint32_t wb_wasm_grow_memory(WbWasmModule module, uint32_t delta_pages) {
  /* Memory growth is not required by our wasm modules (opus/webp use a fixed
   * preallocated memory). wasm3 does not expose a public grow-memory call in
   * this build, so return the current page count as a benign no-op signal. */
  return wb_wasm_memory_pages(module);
}

uint32_t wb_wasm_memory_pages(WbWasmModule module) {
  if (!module) return 0;
  size_t bytes = m3_GetMemorySize((IM3Module)module, 0);
  return (uint32_t)(bytes / 65536);
}
