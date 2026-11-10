// Minimal WebP encoder module for OronBox (wasi libc provides malloc).
// ABI: zb_alloc -> write RGBA -> zb_webp_encode -> zb_webp_output -> zb_free.
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>

#include "webp/encode.h"

static uint8_t *last_output;

__attribute__((export_name("zb_alloc"))) uint8_t *zb_alloc(size_t n) {
  return malloc(n);
}

__attribute__((export_name("zb_free"))) void zb_free(void *p) { free(p); }

__attribute__((export_name("zb_webp_encode"))) int zb_webp_encode(
    const uint8_t *rgba, int width, int height, float quality) {
  uint8_t *output = NULL;
  size_t size = WebPEncodeRGBA(rgba, width, height, width * 4, quality, &output);
  last_output = output;
  return (int)size;
}

__attribute__((export_name("zb_webp_output"))) uint8_t *zb_webp_output(void) {
  return last_output;
}

int main(void) { return 0; }
