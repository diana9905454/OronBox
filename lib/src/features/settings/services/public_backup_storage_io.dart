import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:oronbox/src/core/logging/logging_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path_provider_windows/path_provider_windows.dart';

const _channel = MethodChannel('oronbox/public_backups');
final _log = getLogger('PublicBackupStorage');

/// 最近一次保存失败的原因，供界面在失败提示里带出可诊断的信息。
String? _lastPublicBackupSaveError;

String? getLastPublicBackupSaveError() => _lastPublicBackupSaveError;

String _describeError(Object error) {
  if (error is PlatformException) {
    return '${error.code}: ${error.message ?? ''}'.trim();
  }
  return error.toString();
}

/// Android 走 MediaStore 通道；OpenHarmony 走本地 PublicBackupsBridge（写入
/// 公共下载目录 OronBox/Backups），两者都由原生侧实现同名通道。
bool get _usesPlatformChannel =>
    Platform.isAndroid || defaultTargetPlatform == TargetPlatform.ohos;
const _subDirectoryName = 'Backups';

@visibleForTesting
Directory? userBackupsDirectoryOverride;

Future<Directory> _userBackupsDirectory() async {
  if (userBackupsDirectoryOverride != null) {
    final dir = userBackupsDirectoryOverride!;
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }
  if (Platform.isWindows) {
    try {
      final Future<String?> lookup = PathProviderWindows().getPath(
        '{FDD39AD0-238F-46AF-ADB4-6C85480369C7}', // FOLDERID_Documents
      );
      final path = await lookup;
      if (path != null && path.isNotEmpty) {
        final dir = Directory(
          '$path${Platform.pathSeparator}OronBox${Platform.pathSeparator}$_subDirectoryName',
        );
        if (!await dir.exists()) await dir.create(recursive: true);
        return dir;
      }
    } catch (_) {}
    final profile = Platform.environment['USERPROFILE'];
    final base = (profile != null && profile.trim().isNotEmpty)
        ? '$profile${Platform.pathSeparator}Documents'
        : '.';
    final dir = Directory(
      '$base${Platform.pathSeparator}OronBox${Platform.pathSeparator}$_subDirectoryName',
    );
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  final environment = Platform.environment;
  if (Platform.isLinux) {
    final configured = await _linuxDocumentsDirectory(environment);
    if (configured != null) {
      final dir = Directory(
        '$configured${Platform.pathSeparator}OronBox${Platform.pathSeparator}$_subDirectoryName',
      );
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir;
    }
  }

  final home = environment['HOME'];
  final base = (home != null && home.trim().isNotEmpty)
      ? '$home${Platform.pathSeparator}Documents'
      : '.';
  final dir = Directory(
    '$base${Platform.pathSeparator}OronBox${Platform.pathSeparator}$_subDirectoryName',
  );
  if (!await dir.exists()) await dir.create(recursive: true);
  return dir;
}

Future<String?> _linuxDocumentsDirectory(
  Map<String, String> environment,
) async {
  final home = environment['HOME'];
  if (home == null || home.trim().isEmpty) return null;
  final configHome = environment['XDG_CONFIG_HOME'];
  final configPath = configHome == null || configHome.trim().isEmpty
      ? '$home${Platform.pathSeparator}.config${Platform.pathSeparator}user-dirs.dirs'
      : '$configHome${Platform.pathSeparator}user-dirs.dirs';
  final config = File(configPath);
  if (!await config.exists()) return null;
  for (final line in await config.readAsLines()) {
    final match = RegExp(r'^\s*XDG_DOCUMENTS_DIR="([^"]+)"\s*$')
        .firstMatch(line);
    if (match == null) continue;
    var path = match.group(1)!;
    path = path.replaceAll(r'${HOME}', home).replaceAll(r'$HOME', home);
    if (!path.startsWith(Platform.pathSeparator)) {
      path = '$home${Platform.pathSeparator}$path';
    }
    return path;
  }
  return null;
}

Future<String?> savePublicBackupFile({
  required String fileName,
  required Uint8List bytes,
  // 手动导出可使用鸿蒙系统的下载模式。后台自动备份继续使用公共目录。
  bool useDownloadsOnOhos = false,
}) async {
  if (bytes.isEmpty) return null;
  final sanitizedName = fileName
      .replaceAll(RegExp(r'[\x00-\x1F<>:"/\\|?*]'), '_')
      .trim();
  final targetName = sanitizedName.isEmpty ? 'backup.zip' : sanitizedName;

  if (_usesPlatformChannel && userBackupsDirectoryOverride == null) {
    _lastPublicBackupSaveError = null;
    File? temp;
    try {
      // 备份 zip 可能几十 MB：先落沙箱临时文件，再让原生侧按路径复制，
      // 避免整个 zip 走 MethodChannel 传输。
      final tempDir = await getTemporaryDirectory();
      temp = File(
        '${tempDir.path}${Platform.pathSeparator}oronbox-backup-'
        '${DateTime.now().microsecondsSinceEpoch}.zip',
      );
      await temp.writeAsBytes(bytes, flush: true);
      final method =
          useDownloadsOnOhos && defaultTargetPlatform == TargetPlatform.ohos
          ? 'saveToDownloads'
          : 'saveFromPath';
      try {
        final path = await _channel.invokeMethod<String>(
          method,
          <String, Object?>{'fileName': targetName, 'sourcePath': temp.path},
        );
        if (path != null && path.isNotEmpty) return path;
        _lastPublicBackupSaveError = 'empty path from bridge';
        _log.warning('Public backup bridge returned no path');
      } catch (error, stackTrace) {
        _lastPublicBackupSaveError = _describeError(error);
        _log.warning('Public backup bridge save failed', error, stackTrace);
      }
      return null;
    } catch (error, stackTrace) {
      _lastPublicBackupSaveError = 'temp file: ${_describeError(error)}';
      _log.warning('Public backup temp file failed', error, stackTrace);
      return null;
    } finally {
      try {
        await temp?.delete();
      } catch (_) {}
    }
  }

  final directory = await _userBackupsDirectory();
  final target = File('${directory.path}${Platform.pathSeparator}$targetName');
  await target.writeAsBytes(bytes, flush: true);
  return target.path;
}

Future<List<String>> listPublicBackupFiles() async {
  if (_usesPlatformChannel && userBackupsDirectoryOverride == null) {
    try {
      final list = await _channel.invokeListMethod<String>('list');
      return list ?? const [];
    } catch (error, stackTrace) {
      _log.warning('Public backup list failed', error, stackTrace);
      return const [];
    }
  }

  try {
    final directory = await _userBackupsDirectory();
    final names = <String>[];
    for (final entity in directory.listSync()) {
      if (entity is File) {
        names.add(entity.uri.pathSegments.last);
      }
    }
    return names;
  } catch (_) {
    return const [];
  }
}

Future<Uint8List?> readPublicBackupFile(String fileName) async {
  if (_usesPlatformChannel && userBackupsDirectoryOverride == null) {
    try {
      final bytes = await _channel.invokeMethod<Uint8List>(
        'read',
        <String, Object?>{'fileName': fileName},
      );
      return bytes;
    } catch (error, stackTrace) {
      _log.warning('Public backup read failed', error, stackTrace);
      return null;
    }
  }

  try {
    final directory = await _userBackupsDirectory();
    final file = File('${directory.path}${Platform.pathSeparator}$fileName');
    if (await file.exists()) {
      return await file.readAsBytes();
    }
    return null;
  } catch (_) {
    return null;
  }
}

Future<bool> deletePublicBackupFile(String fileName) async {
  if (_usesPlatformChannel && userBackupsDirectoryOverride == null) {
    try {
      final ok = await _channel.invokeMethod<bool>('delete', <String, Object?>{
        'fileName': fileName,
      });
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  try {
    final directory = await _userBackupsDirectory();
    final file = File('${directory.path}${Platform.pathSeparator}$fileName');
    if (await file.exists()) {
      await file.delete();
      return true;
    }
    return false;
  } catch (_) {
    return false;
  }
}

Future<void> openPublicBackupDirectory() async {
  if (_usesPlatformChannel && userBackupsDirectoryOverride == null) {
    try {
      await _channel.invokeMethod<void>('open');
    } catch (_) {}
    return;
  }

  try {
    final directory = await _userBackupsDirectory();
    if (Platform.isMacOS) {
      await Process.run('open', [directory.path]);
    } else if (Platform.isWindows) {
      await Process.run('explorer.exe', [directory.path]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [directory.path]);
    }
  } catch (_) {}
}

Future<String> getPublicBackupDisplayPath() async {
  if (_usesPlatformChannel && userBackupsDirectoryOverride == null) {
    try {
      final path = await _channel.invokeMethod<String>('getPath');
      if (path != null && path.isNotEmpty) return path;
    } catch (_) {}
    return 'Documents/OronBox/Backups';
  }

  try {
    final directory = await _userBackupsDirectory();
    return directory.path;
  } catch (_) {
    return 'Documents/OronBox/Backups';
  }
}

/// Prunes old auto backup files (matching prefix `OronBox-AutoBackup-`)
/// keeping only the newest [maxRetention] files.
/// If [maxRetention] is <= 0, no pruning is performed.
Future<void> pruneAutoBackups({required int maxRetention}) async {
  if (maxRetention <= 0) return;
  const prefix = 'OronBox-AutoBackup-';
  final files = await listPublicBackupFiles();
  final autoBackups = files.where((name) => name.startsWith(prefix)).toList();
  if (autoBackups.length <= maxRetention) return;

  // Sort descending by name (names contain timestamp yyyyMMdd-HHmmss)
  autoBackups.sort((a, b) => b.compareTo(a));

  for (var i = maxRetention; i < autoBackups.length; i++) {
    await deletePublicBackupFile(autoBackups[i]);
  }
}
