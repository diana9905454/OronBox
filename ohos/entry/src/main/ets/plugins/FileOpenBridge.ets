import { FlutterEngine, MethodChannel, MethodCall, MethodResult, BinaryMessenger } from '@ohos/flutter_ohos';
import common from '@ohos.app.ability.common';
import fs from '@ohos.file.fs';

/**
 * OronBox 鸿蒙「文件打开方式」桥接层（对应 Dart 侧 MethodChannel
 * "oronbox/file_open"，消费端 lib/src/features/devices/widgets/file_open_handler.dart）。
 *
 * module.json5 以 ohos.want.action.viewData + linkFeature "FileOpen" 声明了
 * rpk/obp/abp/zpk/mwz/face 六种文件类型的打开能力（自定义 UTD 类型见
 * resources/rawfile/arkdata/utd/utd.json5）。文件管理器「其他应用打开」
 * 会隐式拉起本应用，want.uri 形如 file://docs/storage/Users/.../xxx.rpk：
 *   - 冷启动 → EntryAbility.onCreate
 *   - 热启动 → EntryAbility.onNewWant
 *
 * 临时 URI 授权只在本次打开期间有效，而 Dart 侧按本地路径读文件，因此这里
 * 先把源文件复制进沙箱 cacheDir/file_open/，再把沙箱路径交给 Dart：
 *   - getInitialFile → string?：冷启动文件路径（Dart 首帧后主动拉取一次）
 *   - openFile(path) → void：热启动推送（Dart 端 handler 已挂时送达）
 *
 * Dart 端对路径做扩展名白名单校验并按内容识别安装（见 file_open_handler），
 * 因此本层只需保证文件名后缀原样保留。
 */

const TAG = 'OronBoxFileOpenBridge';
const FILE_OPEN_CHANNEL = 'oronbox/file_open';
/** 沙箱导入子目录（cacheDir 之下，系统可在磁盘紧张时自动清理）。 */
const IMPORT_DIR_NAME = 'file_open';

export class FileOpenBridge {
  private context: common.UIAbilityContext;
  private channel: MethodChannel | null = null;
  /** 最近一次通过「打开方式」进来的沙箱文件路径（冷启动由 Dart 拉取）。 */
  private initialFile: string | null = null;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  register(flutterEngine: FlutterEngine): void {
    const messenger: BinaryMessenger = flutterEngine.getDartExecutor().getBinaryMessenger();
    const channel = new MethodChannel(messenger, FILE_OPEN_CHANNEL);
    channel.setMethodCallHandler({
      onMethodCall: (call: MethodCall, result: MethodResult): void => {
        try {
          switch (call.method) {
            case 'getInitialFile':
              result.success(this.initialFile);
              break;
            default:
              result.notImplemented();
          }
        } catch (e) {
          const msg = e instanceof Error ? e.message : String(e);
          console.error(TAG + ': ' + msg);
          result.error('file_open_error', msg, null);
        }
      }
    });
    this.channel = channel;
    this.cleanupStaleImports();
  }

  /** EntryAbility 调用：处理一个 file:// URI（onCreate / onNewWant）。 */
  onFileOpen(uri: string): void {
    if (uri == null || uri.length === 0) return;
    let path: string | null = null;
    try {
      path = this.copyIntoSandbox(uri);
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      console.error(TAG + ': import failed (' + uri + '): ' + msg);
      return;
    }
    if (path == null) return;
    this.initialFile = path;
    // 热启动：Dart 端 handler 已挂上，直接推送。冷启动时 Dart 还没就绪，
    // 消息会被静默丢弃，由 Dart 首帧后调用 getInitialFile 兜底拉取。
    if (this.channel != null) {
      try {
        this.channel.invokeMethod('openFile', path);
      } catch (e) {
        const msg = e instanceof Error ? e.message : String(e);
        console.error(TAG + ': push to dart failed: ' + msg);
      }
    }
  }

  /** 把 URI 指向的文件复制进沙箱导入目录，返回沙箱路径。 */
  private copyIntoSandbox(uri: string): string {
    const name = FileOpenBridge.sanitizeName(FileOpenBridge.fileNameOf(uri));
    const dir = this.context.cacheDir + '/' + IMPORT_DIR_NAME;
    FileOpenBridge.ensureDir(dir);
    const target = FileOpenBridge.uniqueTarget(dir, name);
    const src = fs.openSync(uri, fs.OpenMode.READ_ONLY);
    try {
      fs.copyFileSync(src.fd, target);
    } finally {
      fs.closeSync(src);
    }
    console.info(TAG + ': imported ' + uri + ' -> ' + target);
    return target;
  }

  /** 从 file:// URI 提取文件名（保留后缀，供 Dart 端白名单校验）。 */
  private static fileNameOf(uri: string): string {
    let path = uri;
    const query = path.indexOf('?');
    if (query >= 0) {
      path = path.substring(0, query);
    }
    const slash = path.lastIndexOf('/');
    let name = slash >= 0 ? path.substring(slash + 1) : path;
    try {
      name = decodeURIComponent(name);
    } catch (e) {
      // 百分号编码不合法时按原文使用。
    }
    return name;
  }

  /** 去掉路径分隔符等危险字符，其余（含中文/空格）原样保留。 */
  private static sanitizeName(raw: string): string {
    const name = raw.replace(/[\r\n\t\/\\]+/g, '_');
    if (name.length === 0 || name === '.' || name === '..') {
      return 'imported.rpk';
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

  private static ensureDir(dir: string): void {
    try {
      if (!FileOpenBridge.exists(dir)) {
        fs.mkdirSync(dir, true);
      }
    } catch (e) {
      // 已存在或创建失败均由后续 copy 报错兜底。
    }
  }

  /** 同名时追加 " (2)"、" (3)"…，避免覆盖先前导入的文件。 */
  private static uniqueTarget(dir: string, name: string): string {
    const direct = dir + '/' + name;
    if (!FileOpenBridge.exists(direct)) return direct;
    const dot = name.lastIndexOf('.');
    const stem = dot > 0 ? name.substring(0, dot) : name;
    const ext = dot > 0 ? name.substring(dot) : '';
    for (let i = 2; i < 1000; i++) {
      const candidate = dir + '/' + stem + ' (' + i + ')' + ext;
      if (!FileOpenBridge.exists(candidate)) return candidate;
    }
    return direct;
  }

  /** 清理超过 24 小时的历史导入副本，避免导入目录无限增长。 */
  private cleanupStaleImports(): void {
    const dir = this.context.cacheDir + '/' + IMPORT_DIR_NAME;
    if (!FileOpenBridge.exists(dir)) return;
    const threshold = 86400000;
    const now = Date.now();
    let names: Array<string> = [];
    try {
      names = fs.listFileSync(dir);
    } catch (e) {
      return;
    }
    for (const name of names) {
      const full = dir + '/' + name;
      try {
        const stat = fs.statSync(full);
        if (stat.isFile() && now - stat.mtime * 1000 > threshold) {
          fs.unlinkSync(full);
        }
      } catch (e) {
        // 单个文件清理失败忽略。
      }
    }
  }
}
