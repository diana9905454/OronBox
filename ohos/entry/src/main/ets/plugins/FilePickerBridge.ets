import { FlutterEngine, MethodChannel, MethodCall, MethodResult, BinaryMessenger } from '@ohos/flutter_ohos';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { picker } from '@kit.CoreFileKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import common from '@ohos.app.ability.common';

/**
 * OronBox 鸿蒙 file_picker 桥接层。
 *
 * OronBox 用 file_picker 选文件/选图/保存，鸿蒙端无原生实现。
 * 本文件用鸿蒙 photoAccessHelper（选图）和 picker（选文件/保存）实现。
 *
 * MethodChannel "oronbox/file_picker" 方法：
 *   pick {isImage, maxSelectNumber, suffixFilter} → string[] uri 列表
 *   saveFile {fileName, bytes, mimeType} → string? savedUri
 *   readFile {path} → Uint8List 文件内容
 */

const TAG = 'OronBoxFilePickerBridge';
const FILE_PICKER_CHANNEL = 'oronbox/file_picker';

/** 用户选择文件/图片的临时读权限，便于后续 readFile 读取。 */
const PICKER_POLICY = 0;

export class FilePickerBridge {
  private context: common.UIAbilityContext;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  register(flutterEngine: FlutterEngine): void {
    const messenger: BinaryMessenger = flutterEngine.getDartExecutor().getBinaryMessenger();
    const channel = new MethodChannel(messenger, FILE_PICKER_CHANNEL);
    channel.setMethodCallHandler({
      onMethodCall: (call: MethodCall, result: MethodResult): void => {
        this.handle(call, result);
      }
    });
  }

  private handle(call: MethodCall, result: MethodResult): void {
    try {
      switch (call.method) {
        case 'pick':
          this.pick(call, result);
          break;
        case 'saveFile':
          this.saveFile(call, result);
          break;
        case 'readFile':
          this.readFile(call, result);
          break;
        default:
          result.notImplemented();
      }
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      result.error('file_picker_error', msg, null);
    }
  }

  private async pick(call: MethodCall, result: MethodResult): Promise<void> {
    const isImage: boolean = call.argument('isImage');
    const maxSelectNumber: number = call.argument('maxSelectNumber') ?? 0;
    const suffixFilter: Array<string> | null = call.argument('suffixFilter');
    let uris: Array<string> = [];

    if (isImage) {
      const photoPicker = new photoAccessHelper.PhotoViewPicker();
      const options: photoAccessHelper.PhotoSelectOptions = {
        MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE,
        maxSelectNumber: maxSelectNumber,
      };
      const photoResult: photoAccessHelper.PhotoSelectResult =
        await photoPicker.select(options);
      uris = photoResult.photoUris;
    } else {
      const docPicker = new picker.DocumentViewPicker(this.context);
      const options: picker.DocumentSelectOptions = {
        maxSelectNumber: maxSelectNumber,
        fileSuffixFilters: suffixFilter ?? [],
      };
      uris = await docPicker.select(options);
    }
    result.success(uris);
  }

  private async saveFile(call: MethodCall, result: MethodResult): Promise<void> {
    const fileName: string = call.argument('fileName');
    const bytes: Uint8Array = call.argument('bytes');
    const docPicker = new picker.DocumentViewPicker(this.context);
    const options: picker.DocumentSaveOptions = {
      newFileNames: [fileName],
    };
    const savedUris: Array<string> = await docPicker.save(options);
    if (savedUris.length === 0) {
      result.success(null);
      return;
    }
    // 把内容写入用户选择的 uri。
    try {
      const target = savedUris[0];
      const file = fs.openSync(target, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      fs.writeSync(file.fd, bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength) as ArrayBuffer);
      fs.closeSync(file);
      result.success(target);
    } catch (e) {
      result.error('save_write_error', e instanceof Error ? e.message : String(e), null);
    }
  }

  private async readFile(call: MethodCall, result: MethodResult): Promise<void> {
    const path: string = call.argument('path');
    try {
      const file = fs.openSync(path, fs.OpenMode.READ_ONLY);
      const stat = fs.statSync(path);
      const buf = new ArrayBuffer(stat.size);
      fs.readSync(file.fd, buf);
      fs.closeSync(file);
      result.success(new Uint8Array(buf));
    } catch (e) {
      result.error('read_error', e instanceof Error ? e.message : String(e), null);
    }
  }
}
