import common from '@ohos.app.ability.common';
import { BusinessError } from '@ohos.base';
import { fileUri, fileIo as fs, picker } from '@kit.CoreFileKit';

export async function getAppDownloadUri(context: common.UIAbilityContext): Promise<string | null> {
  const options = new picker.DocumentSaveOptions();
  options.pickerMode = picker.DocumentPickerMode.DOWNLOAD;
  const uris = await new picker.DocumentViewPicker(context).save(options);
  return uris.length > 0 && uris[0].length > 0 ? uris[0] : null;
}

export function downloadUriPath(uri: string): string {
  const path = new fileUri.FileUri(uri).path;
  if (path.length === 0) throw new Error('empty download directory');
  return path;
}

/** A failed copy must not replace a previous complete export. */
export async function copyDownloadFile(source: string, target: string): Promise<void> {
  const pending = target + '.' + Date.now() + '.part';
  const dst = await fs.open(pending, fs.OpenMode.WRITE_ONLY | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
  try {
    try {
      await fs.copyFile(source, dst.fd);
    } finally {
      await fs.close(dst);
    }
    await fs.rename(pending, target);
  } catch (error) {
    try {
      await fs.unlink(pending);
    } catch (_) {
      // The temporary file may already be gone.
    }
    throw new Error((error as BusinessError).message);
  }
}
