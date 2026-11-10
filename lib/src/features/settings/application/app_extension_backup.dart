import 'dart:typed_data';

import 'package:oronbox/src/device/zeppos/app_side/zeppos_app_side_storage.dart';
import 'package:oronbox/src/features/plugins/domain/plugin_package.dart';
import 'package:oronbox/src/features/plugins/storage/plugin_storage.dart';
import 'package:oronbox/src/features/plugins/storage/plugin_storage_factory.dart';

class ExtensionBackupTargetMissing implements Exception {
  const ExtensionBackupTargetMissing();
}

class AppExtensionBackupPayload {
  const AppExtensionBackupPayload({
    required this.metadata,
    required this.files,
  });

  final Map<String, Object?> metadata;
  final Map<String, Uint8List> files;
}

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
    final payload = await exportPayload();
    return payload.metadata;
  }

  Future<AppExtensionBackupPayload> exportPayload() async {
    final storage = await _storage;
    final plugins = <String, Object?>{};
    final filesMap = <String, Uint8List>{};
    var totalBytes = 0;

    for (final plugin in await storage.loadInstalled()) {
      final id = plugin.manifest.id;

      Future<void> visit(String rootPath, String areaKey) async {
        final entries = await storage.listDirectory(
          id,
          PluginStoragePath.parse(rootPath),
        );
        for (final file in entries) {
          if (file.isDirectory) {
            await visit(file.path, areaKey);
          } else {
            totalBytes += file.size;
            if (totalBytes > 128 * 1024 * 1024) {
              throw const FormatException('Extension backup size exceeded');
            }
            final bytes = await storage.readFile(
              id,
              PluginStoragePath.parse(file.path),
            );
            final rel = file.path.startsWith('$rootPath/')
                ? file.path.substring(rootPath.length + 1)
                : file.path.replaceFirst(RegExp('^/+'), '');
            filesMap['plugins/$id/$areaKey/$rel'] = bytes;
          }
        }
      }

      await visit('/plugin', 'package');
      await visit('/data', 'data');

      plugins[id] = {
        'version': plugin.manifest.version,
        'config': plugin.config,
        'permissions': (await storage.readPermissionGrants(id)).toList(),
      };
    }

    return AppExtensionBackupPayload(
      metadata: {
        'plugins': plugins,
        'zeppos': {
          for (final id in await _zeppos.listAppIds())
            '$id': await _zeppos.readSettings(id),
        },
      },
      files: filesMap,
    );
  }

  Future<void> validateTargets(
    Map<String, Object?> data, {
    Map<String, Uint8List> files = const {},
  }) async {
    validateExtensionBackup(data);
    final storage = await _storage;
    final installed = {
      for (final app in await storage.loadInstalled())
        app.manifest.id: app.manifest.version,
    };

    final hasManifestInFiles = <String>{};
    for (final key in files.keys) {
      if (key.startsWith('plugins/') &&
          key.endsWith('/package/manifest.json')) {
        final parts = key.split('/');
        if (parts.length >= 4) {
          hasManifestInFiles.add(parts[1]);
        }
      }
    }

    for (final entry in (data['plugins'] as Map? ?? {}).entries) {
      final pluginId = entry.key as String;
      final targetVersion = (entry.value as Map)['version'];
      final isInstalled = installed[pluginId] == targetVersion;
      final canInstallFromFiles = hasManifestInFiles.contains(pluginId);
      if (!isInstalled && !canInstallFromFiles) {
        throw const ExtensionBackupTargetMissing();
      }
    }

    final ids = await _zeppos.listAppIds();
    for (final key in (data['zeppos'] as Map? ?? {}).keys) {
      final appId = int.tryParse(key as String);
      if (appId == null || !ids.contains(appId)) {
        throw const ExtensionBackupTargetMissing();
      }
    }
  }

  Future<void> restore(
    Map<String, Object?> data, {
    Map<String, Uint8List> files = const {},
  }) async {
    await validateTargets(data, files: files);
    final storage = await _storage;

    final packageFilesByPlugin = <String, Map<String, Uint8List>>{};
    final dataFilesByPlugin = <String, Map<String, Uint8List>>{};

    for (final entry in files.entries) {
      final key = entry.key;
      if (!key.startsWith('plugins/')) continue;
      final parts = key.split('/');
      if (parts.length < 4) continue;
      final pluginId = parts[1];
      final area = parts[2];
      final rel = parts.skip(3).join('/');
      if (area == 'package') {
        packageFilesByPlugin.putIfAbsent(pluginId, () => {})[rel] = entry.value;
      } else if (area == 'data') {
        dataFilesByPlugin.putIfAbsent(pluginId, () => {})[rel] = entry.value;
      }
    }

    final installedList = await storage.loadInstalled();
    final installedMap = {
      for (final app in installedList) app.manifest.id: app,
    };

    for (final entry in (data['plugins'] as Map? ?? {}).entries) {
      final id = entry.key as String;
      final value = entry.value as Map;
      final config = (value['config'] as Map? ?? {}).cast<String, Object?>();
      final permissions = (value['permissions'] as List? ?? [])
          .map((p) => p.toString())
          .toSet();

      final pkgFiles = packageFilesByPlugin[id];
      if (installedMap[id] == null &&
          pkgFiles != null &&
          pkgFiles.containsKey('manifest.json')) {
        final manifest = const PluginPackageReader().readManifest(
          pkgFiles['manifest.json']!,
        );
        final package = PluginPackage(manifest: manifest, files: pkgFiles);
        await storage.install(package, config: config);
        await storage.writePermissionGrants(id, permissions);
      } else if (installedMap[id] != null) {
        await storage.writeConfig(id, config);
        await storage.writePermissionGrants(id, permissions);
      }

      for (final file in await storage.listDirectory(
        id,
        PluginStoragePath.parse('/data'),
      )) {
        await storage.removeFile(id, PluginStoragePath.parse(file.path));
      }

      final dFiles = dataFilesByPlugin[id];
      if (dFiles != null && dFiles.isNotEmpty) {
        for (final fileEntry in dFiles.entries) {
          await storage.writeFile(
            id,
            PluginStoragePath.parse('/data/${fileEntry.key}'),
            fileEntry.value,
          );
        }
      }
    }

    for (final entry in (data['zeppos'] as Map? ?? {}).entries) {
      final appId = int.tryParse(entry.key as String);
      if (appId != null) {
        await _zeppos.writeSettings(
          appId,
          (entry.value as Map).cast<String, String>(),
        );
      }
    }
  }

  Future<void> close() async => (await _storage).close();
}

void validateExtensionBackup(Map<String, Object?> data) {
  if (data.keys.any((key) => key != 'plugins' && key != 'zeppos')) {
    throw const FormatException('Invalid extension backup');
  }
  final plugins = data['plugins'] as Map? ?? {};
  for (final entry in plugins.entries) {
    if (entry.key is! String ||
        !RegExp(r'^[a-z0-9][a-z0-9.-]{0,127}$').hasMatch(entry.key as String)) {
      throw const FormatException('Invalid plugin identity');
    }
    final value = entry.value as Map;
    if (value['version'] is! String ||
        value['config'] is! Map ||
        (value.containsKey('permissions') && value['permissions'] is! List)) {
      throw const FormatException('Invalid plugin backup');
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
