import { FlutterEngine, MethodChannel, MethodCall, MethodResult, BinaryMessenger } from '@ohos/flutter_ohos';
import asset from '@ohos.security.asset';
import util from '@ohos.util';
import { BusinessError } from '@ohos.base';

/**
 * OronBox 鸿蒙「安全存储」桥接。
 *
 * 上游 1.2.0 引入 flutter_secure_storage 保存账号令牌、配对设备、AI 密钥等
 * 敏感数据（lib/src/core/services/private_app_state.dart、
 * lib/src/core/ai/ai_secret_store.dart、
 * lib/src/core/services/oauth_credential_store.dart、
 * lib/src/core/asr/cloud_asr_protocol.dart）。该插件没有鸿蒙实现，
 * 每次调用都抛 `Unsupported operation: unsupported_platform`，导致
 * PrivateAppState 初始化失败，连「导出备份」这类操作都会在收尾时被打断。
 *
 * 这里直接实现插件注册的 MethodChannel
 * `plugins.it_nomads.com/flutter_secure_storage`
 * （Dart 侧默认实现是 MethodChannelFlutterSecureStorage），
 * 底层落在 **Asset Store Kit**（@ohos.security.asset）——系统级加密存储，
 * 相当于 iOS Keychain / Android Keystore，密钥由系统托管，应用卸载即销毁。
 *
 * Asset 的 SECRET 单条上限 1024 字节，而 PrivateAppState 的 vault 是一个
 * JSON（可能上 KB），因此按 900 字节切片：
 *   <key>                     → 清单 "OBV2:<代号>:<切片数>"
 *   <key>#<代号>#<i>           → 第 i 片数据
 * 保留 OBV1 读取兼容；写入新一代后才切换清单，避免失败损坏旧值。
 * 对 Dart 侧完全透明。
 */

const TAG = 'OronBoxSecureStorage';
const CHANNEL = 'plugins.it_nomads.com/flutter_secure_storage';
/** Asset SECRET 上限 1024 字节，留点余量。 */
const CHUNK_BYTES = 900;
const MANIFEST_PREFIX = 'OBV1:';
const MANIFEST_V2_PREFIX = 'OBV2:';
const CHUNK_MARK = '#';
const ERROR_DUPLICATED = 24000003;

interface VaultManifest {
  generation: string;
  count: number;
}

export class SecureStorageBridge {
  private operationTail: Promise<void> = Promise.resolve();
  register(flutterEngine: FlutterEngine): void {
    const messenger: BinaryMessenger = flutterEngine.getDartExecutor().getBinaryMessenger();
    const channel = new MethodChannel(messenger, CHANNEL);
    channel.setMethodCallHandler({
      onMethodCall: (call: MethodCall, result: MethodResult): void => {
        const operation = this.operationTail.then(() => this.handle(call, result));
        this.operationTail = operation.catch((error: Error) => {
          console.error(TAG + ': operation failed: ' + this.message(error));
          result.error('SECURE_STORAGE_FAILED', this.message(error), null);
        });
      }
    });
  }

  private async handle(call: MethodCall, result: MethodResult): Promise<void> {
    switch (call.method) {
      case 'read':
        await this.read(call, result);
        break;
      case 'write':
        await this.write(call, result);
        break;
      case 'delete':
        await this.delete(call, result);
        break;
      case 'deleteAll':
        await this.deleteAll(result);
        break;
      case 'readAll':
        await this.readAll(result);
        break;
      case 'containsKey':
        await this.containsKey(call, result);
        break;
      default:
        result.notImplemented();
        break;
    }
  }

  // ---------------------------------------------------------------- 编解码

  private encode(value: string): Uint8Array {
    const encoder = new util.TextEncoder();
    const bytes = encoder.encodeInto(value);
    return bytes == null ? new Uint8Array(0) : bytes;
  }

  private decode(bytes: Uint8Array): string {
    const options: util.TextDecoderOptions = { ignoreBOM: true };
    const decoder = util.TextDecoder.create('utf-8', options);
    return decoder.decodeToString(bytes);
  }

  private concat(left: Uint8Array, right: Uint8Array): Uint8Array {
    const out = new Uint8Array(left.length + right.length);
    out.set(left, 0);
    out.set(right, left.length);
    return out;
  }

  private message(error: Object): string {
    const err = error as BusinessError;
    return err.message != null ? err.message : String(error);
  }

  private errorCode(error: Object): number {
    const err = error as BusinessError;
    return err.code;
  }

  // ---------------------------------------------------------------- Asset 原语

  private async readAlias(alias: string): Promise<Uint8Array | null> {
    const query = new Map<asset.Tag, asset.Value>();
    query.set(asset.Tag.ALIAS, this.encode(alias));
    query.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ALL);
    try {
      const results: Array<asset.AssetMap> = await asset.query(query);
      if (results.length === 0) return null;
      const raw = results[0].get(asset.Tag.SECRET);
      if (raw === undefined) return null;
      return raw as Uint8Array;
    } catch (error) {
      if (this.errorCode(error) === asset.ErrorCode.NOT_FOUND) return null;
      throw error as Error;
    }
  }

  private async writeAlias(alias: string, data: Uint8Array): Promise<void> {
    const attributes = new Map<asset.Tag, asset.Value>();
    attributes.set(asset.Tag.SECRET, data);
    try {
      const created = new Map<asset.Tag, asset.Value>();
      created.set(asset.Tag.ALIAS, this.encode(alias));
      created.set(asset.Tag.SECRET, data);
      created.set(asset.Tag.ACCESSIBILITY, asset.Accessibility.DEVICE_FIRST_UNLOCKED);
      await asset.add(created);
    } catch (error) {
      if (this.errorCode(error) !== ERROR_DUPLICATED) {
        throw error as Error;
      }
      const query = new Map<asset.Tag, asset.Value>();
      query.set(asset.Tag.ALIAS, this.encode(alias));
      await asset.update(query, attributes);
    }
  }

  private async removeAlias(alias: string): Promise<void> {
    const query = new Map<asset.Tag, asset.Value>();
    query.set(asset.Tag.ALIAS, this.encode(alias));
    try {
      await asset.remove(query);
    } catch (error) {
      // 不存在即视为删除成功。
      if (this.errorCode(error) !== asset.ErrorCode.NOT_FOUND) {
        throw error as Error;
      }
    }
  }

  /** 查询本应用全部关键资产的别名。 */
  private async allAliases(): Promise<Array<string>> {
    const query = new Map<asset.Tag, asset.Value>();
    query.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ATTRIBUTES);
    const aliases = new Array<string>();
    try {
      const results: Array<asset.AssetMap> = await asset.query(query);
      for (const item of results) {
        const raw = item.get(asset.Tag.ALIAS);
        if (raw !== undefined) {
          aliases.push(this.decode(raw as Uint8Array));
        }
      }
    } catch (error) {
      if (this.errorCode(error) !== asset.ErrorCode.NOT_FOUND) {
        throw error as Error;
      }
    }
    return aliases;
  }

  // ---------------------------------------------------------------- 分片读写

  private chunkAlias(key: string, index: number, generation: string = ''): string {
    return key + CHUNK_MARK + (generation.length > 0 ? generation + CHUNK_MARK : '') + index;
  }

  private parseManifest(text: string): VaultManifest | null {
    if (text.startsWith(MANIFEST_V2_PREFIX)) {
      const fields = text.substring(MANIFEST_V2_PREFIX.length).split(':');
      const count = Number(fields[1]);
      if (fields.length !== 2 || fields[0].length === 0 || !Number.isSafeInteger(count) || count < 0) {
        throw new Error('Invalid secure storage manifest');
      }
      return { generation: fields[0], count: count };
    }
    if (text.startsWith(MANIFEST_PREFIX)) {
      const count = Number(text.substring(MANIFEST_PREFIX.length));
      if (!Number.isSafeInteger(count) || count < 0) throw new Error('Invalid secure storage manifest');
      return { generation: '', count: count };
    }
    return null;
  }

  private async readValue(key: string): Promise<string | null> {
    const raw = await this.readAlias(key);
    if (raw == null) return null;
    const text = this.decode(raw);
    const manifest = this.parseManifest(text);
    if (manifest == null) return text;
    let bytes = new Uint8Array(0);
    for (let i = 0; i < manifest.count; i++) {
      const chunk = await this.readAlias(this.chunkAlias(key, i, manifest.generation));
      if (chunk == null) throw new Error('Missing secure storage chunk ' + i);
      bytes = this.concat(bytes, chunk);
    }
    return this.decode(bytes);
  }

  private async writeValue(key: string, value: string): Promise<void> {
    const bytes = this.encode(value);
    const count = Math.ceil(bytes.length / CHUNK_BYTES);
    const generation = util.generateRandomUUID();
    // Write a separate generation; the old manifest remains readable until commit.
    for (let i = 0; i < count; i++) {
      const slice = bytes.slice(i * CHUNK_BYTES, Math.min((i + 1) * CHUNK_BYTES, bytes.length));
      const alias = this.chunkAlias(key, i, generation);
      await this.writeAlias(alias, slice);
      const check = await this.readAlias(alias);
      if (check == null || check.length !== slice.length || check.some((byte, index) => byte !== slice[index])) {
        throw new Error('Secure storage chunk verification failed at ' + i);
      }
    }
    await this.writeAlias(key, this.encode(MANIFEST_V2_PREFIX + generation + ':' + count));
    // Cleanup is best-effort after commit, including fragments from interrupted writes.
    try {
      const prefix = key + CHUNK_MARK;
      const keepPrefix = prefix + generation + CHUNK_MARK;
      for (const alias of await this.allAliases()) {
        if (alias.startsWith(prefix) && !alias.startsWith(keepPrefix)) await this.removeAlias(alias);
      }
    } catch (error) {
      console.warn(TAG + ': obsolete chunk cleanup failed: ' + this.message(error));
    }
  }

  private async removeValue(key: string): Promise<void> {
    await this.removeAlias(key);
    const prefix = key + CHUNK_MARK;
    for (const alias of await this.allAliases()) {
      if (alias.startsWith(prefix)) await this.removeAlias(alias);
    }
  }

  // ---------------------------------------------------------------- channel 方法

  private async read(call: MethodCall, result: MethodResult): Promise<void> {
    const key = call.argument('key') as string;
    if (key == null) {
      result.success(null);
      return;
    }
    try {
      result.success(await this.readValue(key));
    } catch (error) {
      console.error(TAG + ': read failed for ' + key + ': ' + this.message(error));
      result.error('SECURE_STORAGE_READ_FAILED', this.message(error), null);
    }
  }

  private async write(call: MethodCall, result: MethodResult): Promise<void> {
    const key = call.argument('key') as string;
    const value = call.argument('value') as string;
    if (key == null || value == null) {
      result.error('SECURE_STORAGE_INVALID', 'missing key or value', null);
      return;
    }
    try {
      await this.writeValue(key, value);
      result.success(null);
    } catch (error) {
      const detail = this.message(error);
      console.error(TAG + ': write failed for ' + key + ': ' + detail);
      result.error(
        'SECURE_STORAGE_WRITE_FAILED',
        key + ' (' + value.length + ' chars): ' + detail,
        null
      );
    }
  }

  private async delete(call: MethodCall, result: MethodResult): Promise<void> {
    const key = call.argument('key') as string;
    if (key == null) {
      result.success(null);
      return;
    }
    try {
      await this.removeValue(key);
      result.success(null);
    } catch (error) {
      console.error(TAG + ': delete failed for ' + key + ': ' + this.message(error));
      result.error('SECURE_STORAGE_DELETE_FAILED', this.message(error), null);
    }
  }

  private async deleteAll(result: MethodResult): Promise<void> {
    try {
      const aliases = await this.allAliases();
      for (const alias of aliases) {
        await this.removeAlias(alias);
      }
      result.success(null);
    } catch (error) {
      console.error(TAG + ': deleteAll failed: ' + this.message(error));
      result.error('SECURE_STORAGE_DELETE_FAILED', this.message(error), null);
    }
  }

  private async readAll(result: MethodResult): Promise<void> {
    try {
      const aliases = await this.allAliases();
      const entries = new Map<string, string>();
      for (const alias of aliases) {
        // 分片本身（含 # 的别名）不算一条记录。
        if (alias.indexOf(CHUNK_MARK) >= 0) continue;
        const value = await this.readValue(alias);
        if (value != null) entries.set(alias, value);
      }
      result.success(entries);
    } catch (error) {
      console.error(TAG + ': readAll failed: ' + this.message(error));
      result.error('SECURE_STORAGE_READ_FAILED', this.message(error), null);
    }
  }

  private async containsKey(call: MethodCall, result: MethodResult): Promise<void> {
    const key = call.argument('key') as string;
    if (key == null) {
      result.success(false);
      return;
    }
    try {
      const manifest = await this.readAlias(key);
      result.success(manifest != null);
    } catch (error) {
      console.error(TAG + ': containsKey failed for ' + key + ': ' + this.message(error));
      result.error('SECURE_STORAGE_READ_FAILED', this.message(error), null);
    }
  }
}
