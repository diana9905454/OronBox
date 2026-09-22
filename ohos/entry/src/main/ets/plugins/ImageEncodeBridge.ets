import { FlutterEngine, MethodChannel, MethodCall, MethodResult, BinaryMessenger } from '@ohos/flutter_ohos';
import { image } from '@kit.ImageKit';
import common from '@ohos.app.ability.common';

/**
 * OronBox 鸿蒙图片编码桥接层。
 *
 * wasm3 解释器无法加载 webp_encoder.wasm（zig 编译的 freestanding wasm 把
 * data 段放在 0x08000000 高地址，超出声明的 16MB 线性内存，wasm3 的
 * InitDataSegments 严格越界检查直接失败）。鸿蒙原生 ImagePacker 能直接编码
 * WebP，故在鸿蒙端用原生编码替代 wasm3。
 *
 * MethodChannel "oronbox/image_encode" 方法：
 *   encodeWebp {rgba, width, height, quality} → Uint8List WebP 字节
 */

const TAG = 'OronBoxImageEncodeBridge';
const CHANNEL = 'oronbox/image_encode';

export class ImageEncodeBridge {
  private context: common.UIAbilityContext;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  register(flutterEngine: FlutterEngine): void {
    const messenger: BinaryMessenger = flutterEngine.getDartExecutor().getBinaryMessenger();
    const channel = new MethodChannel(messenger, CHANNEL);
    channel.setMethodCallHandler({
      onMethodCall: (call: MethodCall, result: MethodResult): void => {
        this.handle(call, result);
      }
    });
  }

  private handle(call: MethodCall, result: MethodResult): void {
    try {
      switch (call.method) {
        case 'encodeWebp':
          this.encodeWebp(call, result);
          break;
        default:
          result.notImplemented();
      }
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      result.error('image_encode_error', msg, null);
    }
  }

  private async encodeWebp(call: MethodCall, result: MethodResult): Promise<void> {
    const rgba: Uint8Array = call.argument('rgba');
    const width: number = call.argument('width');
    const height: number = call.argument('height');
    const quality: number = call.argument('quality') ?? 75;

    if (!rgba || width <= 0 || height <= 0) {
      result.error('bad_arg', 'rgba/width/height are required', null);
      return;
    }

    try {
      // 从 RGBA 字节构建 PixelMap。
      const opts: image.InitializationOptions = {
        size: { width: width, height: height },
        srcPixelFormat: image.PixelMapFormat.RGBA_8888,
        editable: true,
      };
      const buffer = rgba.buffer.slice(rgba.byteOffset, rgba.byteOffset + rgba.byteLength) as ArrayBuffer;
      const pixelMap = await image.createPixelMap(buffer, opts);

      const packer = image.createImagePacker();
      const packOpts: image.PackingOption = {
        format: 'image/webp',
        quality: quality,
      };
      const packed = await packer.packing(pixelMap, packOpts);

      await pixelMap.release();
      await packer.release();
      result.success(new Uint8Array(packed));
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      result.error('encode_webp_error', msg, null);
    }
  }
}
