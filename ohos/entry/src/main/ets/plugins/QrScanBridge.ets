import { FlutterEngine, MethodChannel, MethodCall, MethodResult, BinaryMessenger } from '@ohos/flutter_ohos';
import { scanBarcode, scanCore } from '@kit.ScanKit';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@ohos.base';

/**
 * OronBox 鸿蒙「扫一扫」桥接。
 *
 * Dart 侧的扫码页（lib/src/app/widgets/qr_scanner_page.dart）用 flutter_zxing
 * 的 ReaderWidget 取景，底层依赖 camera 插件；鸿蒙没有该实现，所以那套 UI
 * 在鸿蒙上只能"从图片识别"。这里改用系统 **Scan Kit**
 * （@kit.ScanKit → scanBarcode.startScanForResult）拉起华为自带的扫码界面：
 * 由系统负责相机与取景（官方说明该 UI 已预授予相机权限，应用无需再申请），
 * 返回原始字符串，取消时回 null。
 *
 * 通道：oronbox/qr_scan
 * 方法：scan({ title?: string }) -> string | null
 */

const TAG = 'OronBoxQrScan';
const CHANNEL = 'oronbox/qr_scan';
/** Scan Kit 用户取消扫码。 */
const ERROR_USER_CANCELED = 1000500002;

export class QrScanBridge {
  private context: common.UIAbilityContext;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  register(flutterEngine: FlutterEngine): void {
    const messenger: BinaryMessenger = flutterEngine.getDartExecutor().getBinaryMessenger();
    const channel = new MethodChannel(messenger, CHANNEL);
    channel.setMethodCallHandler({
      onMethodCall: (call: MethodCall, result: MethodResult): void => {
        if (call.method === 'scan') {
          this.scan(call, result);
          return;
        }
        result.notImplemented();
      }
    });
  }

  private async scan(call: MethodCall, result: MethodResult): Promise<void> {
    // 标题由系统扫码页自带，ScanOptions 没有 prompt 字段。
    const options: scanBarcode.ScanOptions = {
      scanTypes: [scanCore.ScanType.QR_CODE],
      enableMultiMode: true,
      enableAlbum: true
    };
    try {
      const scanned: scanBarcode.ScanResult = await scanBarcode.startScanForResult(
        this.context, options);
      const value = scanned.originalValue;
      result.success(value == null || value.length === 0 ? null : value);
    } catch (error) {
      const err = error as BusinessError;
      if (err.code === ERROR_USER_CANCELED) {
        // 用户取消：与 Dart 侧「未扫码」同一语义，不当作错误。
        result.success(null);
        return;
      }
      console.error(TAG + ': scan failed: ' + err.code + ' ' + err.message);
      result.error('SCAN_FAILED', err.message, err.code);
    }
  }
}
