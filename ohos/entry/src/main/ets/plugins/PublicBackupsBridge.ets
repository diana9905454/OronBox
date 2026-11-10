import { FlutterEngine, MethodChannel, MethodCall, MethodResult, BinaryMessenger } from '@ohos/flutter_ohos';
import common from '@ohos.app.ability.common';
import abilityAccessCtrl, { Permissions } from '@ohos.abilityAccessCtrl';
import environment from '@ohos.file.environment';
import fileUri from '@ohos.file.fileuri';
import fs from '@ohos.file.fs';
import { copyDownloadFile, downloadUriPath, getAppDownloadUri } from './DownloadDirectory';
import { BusinessError } from '@ohos.base';

/**
 * OronBox 鸿蒙「公共备份目录」桥接（对应 Dart 侧 MethodChannel
 * "oronbox/public_backups"，实现见
 * lib/src/features/settings/services/public_backup_storage_io.dart）。
 *
 * 上游 1.2.0 的备份功能在 Android 上走 MediaStore/Documents 通道把备份写到
 * 用户可见的 `Documents/OronBox/Backups`，桌面端写家目录 Documents。鸿蒙没有
 * 等价通道，因此这里复用日志导出已经验证过的做法：
 * `ohos.permission.READ_WRITE_DOWNLOAD_DIRECTORY` + `getUserDownloadDir()`，
 * 把备份写到 **公共下载目录下的 `OronBox/Backups`**，用户在「文件管理 → 下载」
 * 里就能看到、拷贝和长期保存，不会被清理沙箱时连带删掉。
 *
 * 方法：
 *   save {fileName, bytes} → string 公共路径
 *   saveToDownloads {fileName, sourcePath} → string 下载路径
 *   list                  → string[] 文件名
 *   read {fileName}       → Uint8Array
 *   delete {fileName}     → boolean
 *   getPath               → string 目录路径（用于界面展示）
 *   open                  → void 尽力拉起文件管理器
 */

const TAG = 'OronBoxPublicBackupsBridge';
const BACKUP_CHANNEL = 'oronbox/public_backups';
/** 公共下载目录下的子目录：OronBox/Backups。 */
const SUB_DIR = 'OronBox/Backups';
const SAVE_PERMISSION: Permissions = 'ohos.permission.READ_WRITE_DOWNLOAD_DIRECTORY';
/** 单次 writeSync 的分块大小。 */
const WRITE_CHUNK_BYTES = 4 * 1024 * 1024;

export class PublicBackupsBridge {
  private context: common.UIAbilityContext;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  register(flutterEngine: FlutterEngine): void {
    const messenger: BinaryMessenger = flutterEngine.getDartExecutor().getBinaryMessenger();
    const channel = new MethodChannel(messenger, BACKUP_CHANNEL);
    channel.setMethodCallHandler({
      onMethodCall: (call: MethodCall, result: MethodResult): void => {
        this.handle(call, result);
      }
    });
  }

  private handle(call: MethodCall, result: MethodResult): void {
    switch (call.method) {
      case 'save':
        this.save(call, result);
        break;
      case 'saveFromPath':
        this.saveFromPath(call, result);
        break;
      case 'saveToDownloads':
        this.saveToDownloads(call, result);
        break;
      case 'list':
        this.list(result);
        break;
      case 'read':
        this.read(call, result);
        break;
      case 'delete':
        this.delete(call, result);
        break;
      case 'getPath':
        this.getPath(result);
        break;
      case 'open':
        this.open(result);
        break;
      default:
        result.notImplemented();
        break;
    }
  }

  /** 只接受纯文件名，挡掉路径穿越。 */
  private static safeName(name: string): string | null {
    if (name == null || name.length === 0) return null;
    if (name.indexOf('/') >= 0 || name.indexOf('\\') >= 0 || name.indexOf('..') >= 0) {
      return null;
    }
    return name;
  }

  private static exists(path: string): boolean {
    try {
      return fs.accessSync(path);
    } catch (e) {
      return false;
    }
  }

  /**
   * 备份目录（不保证存在）。
   *
   * `getUserDownloadDir()` 在缺少 READ_WRITE_DOWNLOAD_DIRECTORY 时抛 201，
   * 这里不再静默退回到一个写不进去的绝对路径——那会把「权限没批」伪装成
   * 「复制失败」，Dart 侧就分不清该走系统保存对话框还是重试。
   */
  private static resolveBackupDir(): string {
    const base = environment.getUserDownloadDir();
    if (base == null || base.length === 0) {
      throw new Error('getUserDownloadDir returned an empty path');
    }
    return base + '/' + SUB_DIR;
  }

  private static isPermissionError(e: BusinessError): boolean {
    return e != null && (e.code === 201 || e.code === 13900012);
  }

  private static describe(e: BusinessError): string {
    const code = e == null ? '?' : e.code;
    const msg = e == null ? String(e) : (e.message == null ? '' : e.message);
    return 'code=' + code + ' ' + msg;
  }

  private static ensureDir(dir: string): void {
    try {
      if (!PublicBackupsBridge.exists(dir)) {
        fs.mkdirSync(dir, true);
      }
    } catch (e) {
      // 已存在或父目录不可写，交给后续写入报错兜底。
    }
  }

  /** 分块写入并校验长度：单次 writeSync 不保证写完整个 buffer。 */
  private static writeBytes(target: string, bytes: Uint8Array): void {
    const file = fs.openSync(target,
      fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
    try {
      let written = 0;
      while (written < bytes.byteLength) {
        const rest = bytes.byteLength - written;
        const size = rest > WRITE_CHUNK_BYTES ? WRITE_CHUNK_BYTES : rest;
        const chunk = new ArrayBuffer(size);
        new Uint8Array(chunk).set(bytes.subarray(written, written + size), 0);
        const n = fs.writeSync(file.fd, chunk);
        if (n <= 0) {
          throw new Error('write returned ' + n);
        }
        written += n;
      }
      if (written !== bytes.byteLength) {
        throw new Error('short write ' + written + '/' + bytes.byteLength);
      }
    } finally {
      fs.closeSync(file);
    }
  }

  private async ensurePermission(): Promise<boolean> {
    try {
      const atManager = abilityAccessCtrl.createAtManager();
      const perms: Array<Permissions> = [SAVE_PERMISSION];
      const res = await atManager.requestPermissionsFromUser(this.context, perms);
      const granted = res.authResults.length > 0 && res.authResults[0] === 0;
      if (!granted) {
        console.warn(TAG + ': permission not granted, authResults=' +
          JSON.stringify(res.authResults));
      }
      return granted;
    } catch (e) {
      const err = e as BusinessError;
      console.error(TAG + ': permission request failed: ' + PublicBackupsBridge.describe(err));
      return false;
    }
  }

  /** 申请目录权限并准备目录；失败时把原因写回 result 并返回 null。 */
  private async prepareDir(result: MethodResult): Promise<string | null> {
    if (!await this.ensurePermission()) {
      result.error('PERMISSION_DENIED', SAVE_PERMISSION + ' (not granted)', null);
      return null;
    }
    try {
      const dir = PublicBackupsBridge.resolveBackupDir();
      PublicBackupsBridge.ensureDir(dir);
      return dir;
    } catch (e) {
      const err = e as BusinessError;
      console.error(TAG + ': resolve backup dir failed: ' + PublicBackupsBridge.describe(err));
      result.error('BACKUP_DIR_FAILED', PublicBackupsBridge.describe(err), null);
      return null;
    }
  }

  private async save(call: MethodCall, result: MethodResult): Promise<void> {
    const rawName: string = call.argument('fileName') as string;
    const name = PublicBackupsBridge.safeName(rawName);
    const bytes: Uint8Array = call.argument('bytes') as Uint8Array;
    if (name == null || bytes == null || bytes.byteLength === 0) {
      result.error('BACKUP_INVALID', 'missing fileName or bytes', null);
      return;
    }
    const dir = await this.prepareDir(result);
    if (dir == null) return;
    const target = dir + '/' + name;
    try {
      PublicBackupsBridge.writeBytes(target, bytes);
      result.success(target);
    } catch (e) {
      const err = e as BusinessError;
      console.error(TAG + ': save failed: ' + PublicBackupsBridge.describe(err));
      result.error('BACKUP_SAVE_FAILED', PublicBackupsBridge.describe(err), null);
    }
  }

  /**
   * 从沙箱文件复制到公共目录。
   *
   * 备份 zip 动辄几十 MB，走 MethodChannel 传 bytes 容易触发 IPC 体积/内存
   * 问题，所以 Dart 侧先把 zip 落到 cache 目录，这里直接按路径复制。
   */
  private async saveFromPath(call: MethodCall, result: MethodResult): Promise<void> {
    const rawName: string = call.argument('fileName') as string;
    const name = PublicBackupsBridge.safeName(rawName);
    const source: string = call.argument('sourcePath') as string;
    if (name == null || source == null || source.length === 0) {
      result.error('BACKUP_INVALID', 'missing fileName or sourcePath', null);
      return;
    }
    const dir = await this.prepareDir(result);
    if (dir == null) return;
    const target = dir + '/' + name;
    try {
      fs.copyFileSync(source, target);
      result.success(target);
      return;
    } catch (e) {
      const err = e as BusinessError;
      console.warn(TAG + ': copyFileSync failed (' + PublicBackupsBridge.describe(err) +
        '), retrying through file descriptors');
      // 某些 provider 对 copyFileSync 的路径解析更严格，退一步用 fd 复制。
      try {
        PublicBackupsBridge.copyThroughFd(source, target);
        result.success(target);
      } catch (inner) {
        const nested = inner as BusinessError;
        console.error(TAG + ': saveFromPath failed: ' + PublicBackupsBridge.describe(nested));
        result.error('BACKUP_SAVE_FAILED', PublicBackupsBridge.describe(nested), null);
      }
    }
  }

  /** 打开源/目标文件描述符做复制，copyFileSync 直接给路径失败时使用。 */
  private static copyThroughFd(source: string, target: string): void {
    const src = fs.openSync(source, fs.OpenMode.READ_ONLY);
    let dstFd = -1;
    try {
      const dst = fs.openSync(target,
        fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      dstFd = dst.fd;
      fs.copyFileSync(src.fd, dstFd);
    } finally {
      try {
        fs.closeSync(src);
      } catch (e) {
        // 忽略关闭失败
      }
      if (dstFd >= 0) {
        try {
          fs.closeSync(dstFd);
        } catch (e) {
          // 忽略关闭失败
        }
      }
    }
  }

  /** 手动导出使用系统授权的应用下载目录，手机不依赖公共目录权限。 */
  private async saveToDownloads(call: MethodCall, result: MethodResult): Promise<void> {
    const name = PublicBackupsBridge.safeName(call.argument('fileName') as string);
    const source: string = call.argument('sourcePath') as string;
    if (name == null || source == null || source.length === 0) {
      result.error('BACKUP_INVALID', 'missing fileName or sourcePath', null);
      return;
    }

    try {
      const uri = await getAppDownloadUri(this.context);
      if (uri == null) {
        result.error('CANCELLED', 'backup save cancelled', null);
        return;
      }
      const target = downloadUriPath(uri) + '/' + name;
      await copyDownloadFile(source, target);
      result.success(target);
    } catch (e) {
      const detail = PublicBackupsBridge.describe(e as BusinessError);
      console.error(TAG + ': saveToDownloads failed: ' + detail);
      result.error('BACKUP_SAVE_FAILED', detail, null);
    }
  }

  private async list(result: MethodResult): Promise<void> {
    if (!await this.ensurePermission()) {
      result.success(new Array<string>());
      return;
    }
    let dir = '';
    try {
      dir = PublicBackupsBridge.resolveBackupDir();
    } catch (e) {
      const err = e as BusinessError;
      console.error(TAG + ': resolve backup dir failed: ' + PublicBackupsBridge.describe(err));
      result.success(new Array<string>());
      return;
    }
    if (!PublicBackupsBridge.exists(dir)) {
      result.success(new Array<string>());
      return;
    }
    try {
      const names = fs.listFileSync(dir);
      result.success(names);
    } catch (e) {
      const err = e as BusinessError;
      console.error(TAG + ': list failed: ' + PublicBackupsBridge.describe(err));
      result.success(new Array<string>());
    }
  }

  private async read(call: MethodCall, result: MethodResult): Promise<void> {
    const rawName: string = call.argument('fileName') as string;
    const name = PublicBackupsBridge.safeName(rawName);
    if (name == null) {
      result.error('BACKUP_INVALID', 'bad fileName', null);
      return;
    }
    if (!await this.ensurePermission()) {
      result.error('PERMISSION_DENIED', SAVE_PERMISSION, null);
      return;
    }
    let dir = '';
    try {
      dir = PublicBackupsBridge.resolveBackupDir();
    } catch (e) {
      result.error('BACKUP_DIR_FAILED',
        PublicBackupsBridge.describe(e as BusinessError), null);
      return;
    }
    const target = dir + '/' + name;
    if (!PublicBackupsBridge.exists(target)) {
      result.success(null);
      return;
    }
    try {
      const stat = fs.statSync(target);
      const total = stat.size;
      const data = new Uint8Array(total);
      const file = fs.openSync(target, fs.OpenMode.READ_ONLY);
      let read = 0;
      try {
        // 单次 readSync 不保证填满 buffer，按已读偏移循环补齐。
        while (read < total) {
          const chunk = new ArrayBuffer(total - read);
          const n = fs.readSync(file.fd, chunk, { offset: read, length: total - read });
          if (n <= 0) break;
          data.set(new Uint8Array(chunk, 0, n), read);
          read += n;
        }
      } finally {
        fs.closeSync(file);
      }
      result.success(read === total ? data : data.slice(0, read));
    } catch (e) {
      const err = e as BusinessError;
      console.error(TAG + ': read failed: ' + PublicBackupsBridge.describe(err));
      result.error('BACKUP_READ_FAILED', PublicBackupsBridge.describe(err), null);
    }
  }

  private async delete(call: MethodCall, result: MethodResult): Promise<void> {
    const rawName: string = call.argument('fileName') as string;
    const name = PublicBackupsBridge.safeName(rawName);
    if (name == null) {
      result.success(false);
      return;
    }
    if (!await this.ensurePermission()) {
      result.success(false);
      return;
    }
    let dir = '';
    try {
      dir = PublicBackupsBridge.resolveBackupDir();
    } catch (e) {
      result.success(false);
      return;
    }
    const target = dir + '/' + name;
    if (!PublicBackupsBridge.exists(target)) {
      result.success(false);
      return;
    }
    try {
      fs.unlinkSync(target);
      result.success(true);
    } catch (e) {
      const err = e as BusinessError;
      console.error(TAG + ': delete failed: ' + PublicBackupsBridge.describe(err));
      result.success(false);
    }
  }

  private getPath(result: MethodResult): void {
    try {
      result.success(PublicBackupsBridge.resolveBackupDir());
    } catch (e) {
      // 拿不到权限时不吹牛：回 null，界面按「未授权」处理。
      console.warn(TAG + ': getPath unavailable: ' +
        PublicBackupsBridge.describe(e as BusinessError));
      result.success(null);
    }
  }

  /** 尽力打开系统文件管理器定位到备份目录（失败静默）。 */
  private async open(result: MethodResult): Promise<void> {
    let dir = '';
    try {
      dir = PublicBackupsBridge.resolveBackupDir();
    } catch (e) {
      result.success(null);
      return;
    }
    PublicBackupsBridge.ensureDir(dir);
    try {
      const uri = fileUri.getUriFromPath(dir);
      await this.context.startAbility({
        action: 'ohos.want.action.viewData',
        uri: uri,
      });
    } catch (e) {
      const err = e as BusinessError;
      console.warn(TAG + ': open dir failed: ' + PublicBackupsBridge.describe(err));
    }
    result.success(null);
  }
}
