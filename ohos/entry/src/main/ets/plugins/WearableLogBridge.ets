import { FlutterEngine, MethodChannel, MethodCall, MethodResult, BinaryMessenger } from '@ohos/flutter_ohos';
import { picker, fileIo as fs } from '@kit.CoreFileKit';
import common from '@ohos.app.ability.common';
import { BusinessError } from '@ohos.base';

const CHANNEL = 'oronbox/wearable_log';
const MAX_BYTES = 64 * 1024 * 1024;
const CHUNK_BYTES = 1024 * 1024;

export class WearableLogBridge {
  private context: common.UIAbilityContext;
  private selectedUris: Set<string> = new Set<string>();

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
    switch (call.method) {
      case 'pickLogs':
        this.pickLogs(result);
        break;
      case 'readLog':
        this.readLog(call, result);
        break;
      default:
        result.notImplemented();
    }
  }

  private async pickLogs(result: MethodResult): Promise<void> {
    this.selectedUris.clear();
    try {
      const docPicker = new picker.DocumentViewPicker(this.context);
      // Let users select the entire folder's contents, including rotated logs
      // whose numeric suffixes would otherwise be filtered out.
      const options: picker.DocumentSelectOptions = { maxSelectNumber: 500 };
      const uris = await docPicker.select(options);
      for (const uri of uris) {
        this.selectedUris.add(uri);
      }
      result.success(uris);
    } catch (e) {
      const error = e as BusinessError;
      if (error.code === 13900042) {
        result.error('CANCELLED', 'wearable log selection cancelled', null);
      } else {
        result.error('READ_FAILED', error.message, null);
      }
    }
  }

  private async readLog(call: MethodCall, result: MethodResult): Promise<void> {
    const uri: string = call.argument('uri');
    const maxBytes: number = call.argument('maxBytes');
    if (!this.selectedUris.delete(uri) || !Number.isInteger(maxBytes) ||
      maxBytes <= 0 || maxBytes > MAX_BYTES) {
      result.error('READ_FAILED', 'invalid wearable log request', null);
      return;
    }

    try {
      const file = await fs.open(uri, fs.OpenMode.READ_ONLY);
      let data: Uint8Array;
      try {
        const stat = await fs.stat(file.fd);
        if (stat.size <= 0 || stat.size > maxBytes) {
          throw new Error('wearable log size out of range');
        }
        data = new Uint8Array(stat.size);
        const chunk = new ArrayBuffer(Math.min(CHUNK_BYTES, data.length));
        let offset = 0;
        while (offset < data.length) {
          const n = await fs.read(file.fd, chunk, {
            length: Math.min(chunk.byteLength, data.length - offset)
          });
          if (n <= 0) throw new Error('incomplete wearable log');
          data.set(new Uint8Array(chunk, 0, n), offset);
          offset += n;
        }
      } finally {
        await fs.close(file);
      }
      result.success(data);
    } catch (e) {
      result.error('READ_FAILED', (e as BusinessError).message, null);
    }
  }
}
