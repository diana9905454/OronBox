import { FlutterEngine, MethodChannel, MethodCall, MethodResult } from '@ohos/flutter_ohos';
import common from '@ohos.app.ability.common';
import fs from '@ohos.file.fs';
import { BusinessError } from '@ohos.base';
import { copyDownloadFile, downloadUriPath, getAppDownloadUri } from './DownloadDirectory';

const LOGS_CHANNEL = 'oronbox/logs';

export class LogsBridge {
  private context: common.UIAbilityContext;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  register(flutterEngine: FlutterEngine): void {
    const messenger = flutterEngine.getDartExecutor().getBinaryMessenger();
    new MethodChannel(messenger, LOGS_CHANNEL).setMethodCallHandler({
      onMethodCall: (call: MethodCall, result: MethodResult): void => {
        switch (call.method) {
          case 'saveToDownloads':
          case 'exportDirectory':
            this.exportLogs(call, result);
            break;
          default:
            result.notImplemented();
        }
      }
    });
  }

  private static isLogName(name: string): boolean {
    return name != null && !name.includes('/') && !name.includes('\\') &&
      !name.includes('..') && (name.endsWith('.log') || name.endsWith('.zip') || name.endsWith('.tar.gz'));
  }

  private async exportLogs(call: MethodCall, result: MethodResult): Promise<void> {
    try {
      const openDirectory = call.method === 'exportDirectory';
      const sourceDir = this.context.filesDir + '/logs';
      const name = openDirectory ? '' : call.argument('name') as string;
      if (!openDirectory && !LogsBridge.isLogName(name)) {
        result.error('LOG_NOT_FOUND', 'invalid log name', null);
        return;
      }

      const downloadUri = await getAppDownloadUri(this.context);
      if (downloadUri == null) {
        result.success(null);
        return;
      }
      const uri = downloadUri.replace(/\/$/, '') + '/Logs';
      const dir = downloadUriPath(uri);
      try {
        await fs.mkdir(dir, true);
      } catch (e) {
        const error = e as BusinessError;
        if (error.code !== 13900015 || !(await fs.stat(dir)).isDirectory()) {
          throw new Error(error.message);
        }
      }

      if (!openDirectory) {
        const target = dir + '/' + name;
        await copyDownloadFile(sourceDir + '/' + name, target);
        result.success(target);
        return;
      }

      for (const file of await fs.listFile(sourceDir)) {
        if (LogsBridge.isLogName(file)) {
          await copyDownloadFile(sourceDir + '/' + file, dir + '/' + file);
        }
      }
      await this.context.startAbility({
        bundleName: 'com.huawei.hmos.filemanager',
        abilityName: 'MainAbility',
        uri: uri,
        parameters: { fileUri: uri }
      });
      result.success('');
    } catch (e) {
      const message = e instanceof Error ? e.message : String(e);
      console.error('OronBoxLogsBridge: ' + message);
      result.error('LOG_EXPORT_FAILED', message, null);
    }
  }
}
