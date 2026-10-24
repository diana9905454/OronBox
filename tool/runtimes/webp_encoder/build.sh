#!/bin/sh
# Builds assets/wasm/webp_encoder.wasm from libwebp with zig (wasm32-wasi,
# musl libc, reactor module, lossy + lossless encoder only, -Os + strip).
# Downloads zig and libwebp into .build/ on first run.
set -e
cd "$(dirname "$0")"
ZIG_VER=0.14.0
WEBP_VER=1.4.0
mkdir -p .build && cd .build
[ -d zig ] || { curl -sL "https://ziglang.org/download/$ZIG_VER/zig-linux-x86_64-$ZIG_VER.tar.xz" | tar xJ; mv "zig-linux-x86_64-$ZIG_VER" zig; }
[ -d "libwebp-$WEBP_VER" ] || curl -sL "https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-$WEBP_VER.tar.gz" | tar xz
SRC="libwebp-$WEBP_VER/src"

# Decoder-only sources the encoder never needs (verified by link errors:
# dec.c, ssim.c, dec_clip_tables.c, lossless.c, yuv.c, upsampling.c ARE needed).
DEC_ONLY="
dsp/dec_mips32.c dsp/dec_mips_dsp_r2.c dsp/dec_msa.c
dsp/dec_neon.c dsp/dec_sse2.c dsp/dec_sse41.c
dsp/upsampling_mips_dsp_r2.c dsp/upsampling_msa.c dsp/upsampling_neon.c
dsp/upsampling_sse2.c dsp/upsampling_sse41.c dsp/ssim_sse2.c
dsp/lossless_mips_dsp_r2.c dsp/lossless_msa.c dsp/lossless_neon.c
dsp/lossless_sse2.c dsp/lossless_sse41.c
dsp/yuv_mips32.c dsp/yuv_mips_dsp_r2.c dsp/yuv_neon.c dsp/yuv_sse2.c dsp/yuv_sse41.c
enc/picture_psnr_enc.c
utils/bit_reader_utils.c utils/huffman_utils.c utils/quant_levels_dec_utils.c
"

rm -f obj_*.o
FILES="$SRC/enc/*.c $SRC/dsp/*.c $SRC/utils/*.c libwebp-$WEBP_VER/sharpyuv/*.c"
for f in $FILES; do
  rel="${f#$SRC/}"
  skip=0
  for d in $DEC_ONLY; do [ "$rel" = "$d" ] && skip=1; done
  [ $skip = 1 ] && continue
  ./zig/zig cc -target wasm32-wasi -Os -DNDEBUG -I"libwebp-$WEBP_VER" -I"$SRC" -c "$f" -o "obj_$(basename "$f" .c).o"
done
./zig/zig cc -target wasm32-wasi -Os -DNDEBUG -I"libwebp-$WEBP_VER" -I"$SRC" -c ../webp_encoder.c -o obj_wrapper.o
./zig/zig cc -target wasm32-wasi -Os -nostdlib \
  -Wl,--no-entry -Wl,--strip-all \
  -Wl,--export=zb_alloc -Wl,--export=zb_free \
  -Wl,--export=zb_webp_encode -Wl,--export=zb_webp_output -Wl,--export-memory \
  obj_*.o -o ../../../../assets/wasm/webp_encoder.wasm -lc
echo "built assets/wasm/webp_encoder.wasm ($(wc -c < ../../../../assets/wasm/webp_encoder.wasm) bytes)"
