import 'dart:convert';

import 'package:oronbox/src/device/zeppos/app_side/zeppos_app_side_storage.dart';
import 'package:oronbox/src/features/plugins/storage/plugin_storage.dart';
import 'package:oronbox/src/features/plugins/storage/plugin_storage_factory.dart';

class ExtensionBackupTargetMissing implements Exception {
  const ExtensionBackupTargetMissing();
}

/// Restores data only to matching installed apps; never installs code or grants.
class AppExtensionBackupStore {
  AppExtensionBackupStore({
    PluginStorage? plugins,
    ZeppOsAppSideStorage? zeppos,
  }) : _plugins = plugins == null ? null : Future.value(plugins),
       _zeppos = zeppos ?? ZeppOsAppSideStorage();
  Future<PluginStorage>? _plugins;
  Future<PluginStorage> get _storage => _plugins ??= createPluginStorage();
  final ZeppOsAppSideStorage _zeppos;

  Future<Map<String, Object?>> export() async {
    final storage = await _storage;
    final plugins = <String, Object?>{};
    var bytes = 0;
    for (final plugin in await storage.loadInstalled()) {
      final files = <String, String>{};
      Future<void> visit(String path) async {
        for (final file in await storage.listDirectory(
          plugin.manifest.id,
          PluginStoragePath.parse(path),
        )) {
          if (file.isDirectory) {
            await visit(file.path);
          } else {
            bytes += file.size;
            if (bytes > 64 * 1024 * 1024) {
              throw const FormatException('Extension backup size exceeded');
            }
            files[file.path] = base64Encode(
              await storage.readFile(
                plugin.manifest.id,
                PluginStoragePath.parse(file.path),
              ),
            );
          }
        }
      }

      await visit('/data');
      plugins[plugin.manifest.id] = {
        'version': plugin.manifest.version,
        'config': plugin.config,
        'files': files,
      };
    }
    return {
      'plugins': plugins,
      'zeppos': {
        for (final id in await _zeppos.listAppIds())
          '$id': await _zeppos.readSettings(id),
      },
    };
  }

  Future<void> validateTargets(Map<String, Object?> data) async {
    validateExtensionBackup(data);
    final installed = {
      for (final app in await (await _storage).loadInstalled())
        app.manifest.id: app.manifest.version,
    };
    for (final entry in (data['plugins'] as Map? ?? {}).entries) {
      if (installed[entry.key] != (entry.value as Map)['version']) {
        throw const ExtensionBackupTargetMissing();
      }
    }
    final ids = await _zeppos.listAppIds();
    for (final key in (data['zeppos'] as Map? ?? {}).keys) {
      if (!ids.contains(int.parse(key as String))) {
        throw const ExtensionBackupTargetMissing();
      }
    }
  }

  Future<void> restore(Map<String, Object?> data) async {
    await validateTargets(data);
    final storage = await _storage;
    for (final entry in (data['plugins'] as Map? ?? {}).entries) {
      final id = entry.key as String;
      final value = entry.value as Map;
      // Metadata, including permission grants, is outside the public /data tree.
      for (final file in await storage.listDirectory(
        id,
        PluginStoragePath.parse('/data'),
      )) {
        await storage.removeFile(id, PluginStoragePath.parse(file.path));
      }
      await storage.writeConfig(
        id,
        (value['config'] as Map).cast<String, Object?>(),
      );
      for (final file in (value['files'] as Map).entries) {
        await storage.writeFile(
          id,
          PluginStoragePath.parse(file.key as String),
          base64Decode(file.value as String),
        );
      }
    }
    for (final entry in (data['zeppos'] as Map? ?? {}).entries) {
      await _zeppos.writeSettings(
        int.parse(entry.key as String),
        (entry.value as Map).cast<String, String>(),
      );
    }
  }

  Future<void> close() async => (await _storage).close();
}

void validateExtensionBackup(Map<String, Object?> data) {
  if (data.keys.any((key) => key != 'plugins' && key != 'zeppos')) {
    throw const FormatException('Invalid extension backup');
  }
  final plugins = data['plugins'] as Map? ?? {};
  var bytes = 0;
  var count = 0;
  for (final entry in plugins.entries) {
    if (entry.key is! String ||
        !RegExp(r'^[a-z0-9][a-z0-9.-]{0,127}$').hasMatch(entry.key as String)) {
      throw const FormatException('Invalid plugin identity');
    }
    final value = entry.value as Map;
    if (value['version'] is! String ||
        value['config'] is! Map ||
        value['files'] is! Map ||
        value.length != 3) {
      throw const FormatException('Invalid plugin backup');
    }
    for (final file in (value['files'] as Map).entries) {
      final path = PluginStoragePath.parse(file.key as String);
      if (path.area != PluginStorageArea.data || path.relativePath.isEmpty) {
        throw const FormatException('Invalid plugin data path');
      }
      bytes += base64Decode(file.value as String).length;
      if (++count > 10000 || bytes > 64 * 1024 * 1024) {
        throw const FormatException('Extension backup size exceeded');
      }
    }
  }
  for (final entry in (data['zeppos'] as Map? ?? {}).entries) {
    final id = int.tryParse(entry.key as String);
    if (id == null || id < 0 || id > 0xffffffff) {
      throw const FormatException('Invalid device app identity');
    }
    (entry.value as Map).cast<String, String>().forEach((key, value) {});
  }
}
