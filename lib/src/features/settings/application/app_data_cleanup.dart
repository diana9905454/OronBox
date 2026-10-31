import 'package:oronbox/src/core/asr/asr_runtime.dart';

import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/painting.dart';
import 'package:oronbox/src/features/plugins/storage/plugin_storage.dart';
import 'package:oronbox/src/features/plugins/storage/plugin_storage_factory.dart';

import 'package:oronbox/src/core/asr/asr_model_store.dart';

import 'package:oronbox/src/core/storage/app_data_directory.dart';
import 'package:oronbox/src/core/storage/managed_temporary_files.dart';
import 'package:oronbox/src/core/services/shared_prefs_service.dart';
import 'package:oronbox/src/features/devices/health/health_store.dart';

import 'app_data_inventory.dart';

Future<void> cleanupApplicationDataCategory(AppDataCategory category) async {
  switch (category) {
    case AppDataCategory.health:
      await HealthStore.maintenance(() async {
        await HealthStore.clearActivityFiles();
        final prefs = SharedPrefsService.instance;
        for (final key
            in prefs.keys
                .where((key) => key.startsWith('health_data_v'))
                .toList()) {
          await prefs.remove(key);
        }
        await HealthStore.deleteLegacyDatabaseFiles();
        HealthStore.clearCache();
        healthDataRevision.value++;
      });
    case AppDataCategory.cache:
      await _clearPluginCache();
    case AppDataCategory.images:
      await CachedNetworkImageProvider.defaultCacheManager.emptyCache();
      PaintingBinding.instance.imageCache.clear();
    case AppDataCategory.models:
      await AsrModelStore.cleanupUnused();
      await cleanupAsrRuntimes();
    case AppDataCategory.documents:
      await _clearDirectory(
        await openAppDataDirectory(
          'documents/legal',
          location: AppStorageLocation.cache,
        ),
      );
    case AppDataCategory.downloads:
      await _clearUnusedDownloads();
    case AppDataCategory.plugins:
    case AppDataCategory.zeppos:
    case AppDataCategory.logs:
    case AppDataCategory.recovery:
    case AppDataCategory.tasks:
      throw UnsupportedError('This application data category is protected');
  }
}

Future<void> _clearDirectory(AppDataDirectory directory) async {
  await directory.exclusive(() async {
    for (final file in await directory.files(includeTemporary: true)) {
      await directory.remove(file.path);
    }
  });
}

Future<void> _clearPluginCache() async {
  final plugins = await createPluginStorage();
  try {
    for (final plugin in await plugins.loadInstalled()) {
      for (final file in await plugins.listDirectory(
        plugin.manifest.id,
        PluginStoragePath.parse('/cache'),
      )) {
        await plugins.removeFile(
          plugin.manifest.id,
          PluginStoragePath.parse(file.path),
        );
      }
    }
  } finally {
    await plugins.close();
  }
}

/// Only expired, unowned files are reclaimable. Queued paths remain intact.
Future<void> cleanupApplicationCache() async {
  await CachedNetworkImageProvider.defaultCacheManager.emptyCache();
  PaintingBinding.instance.imageCache.clear();
  final plugins = await createPluginStorage();
  try {
    for (final plugin in await plugins.loadInstalled()) {
      for (final area in ['cache', 'temp']) {
        for (final file in await plugins.listDirectory(
          plugin.manifest.id,
          PluginStoragePath.parse('/$area'),
        )) {
          await plugins.removeFile(
            plugin.manifest.id,
            PluginStoragePath.parse(file.path),
          );
        }
      }
    }
  } finally {
    await plugins.close();
  }
  await AsrModelStore.cleanupUnused();
  await cleanupAsrRuntimes();
  await _clearUnusedDownloads();
  await _clearDirectory(
    await openAppDataDirectory(
      'documents/legal',
      location: AppStorageLocation.cache,
    ),
  );
}

Future<void> _clearUnusedDownloads() async {
  final tasks = await openAppDataDirectory('tasks');
  final paths = <String>{};
  await tasks.exclusive(() async {
    final bytes = await tasks.read('state.json');
    void visit(Object? value) {
      if (value is String) {
        paths.add(value);
        if (value.trimLeft().startsWith('{') ||
            value.trimLeft().startsWith('[')) {
          visit(jsonDecode(value));
        }
      }
      if (value is Map) value.values.forEach(visit);
      if (value is List) value.forEach(visit);
    }

    if (bytes != null) visit(jsonDecode(utf8.decode(bytes)));
    await ManagedTemporaryFiles.cleanup(protectedPaths: paths);
  });
}
