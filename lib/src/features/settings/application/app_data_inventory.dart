import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:oronbox/src/features/devices/health/health_database.dart';

import 'package:oronbox/src/core/services/shared_prefs_service.dart';
import 'package:oronbox/src/core/storage/app_data_directory.dart';
import 'package:oronbox/src/features/devices/health/health_debug_snapshot_store.dart';

import 'app_data_inventory_stub.dart'
    if (dart.library.io) 'app_data_inventory_io.dart'
    if (dart.library.js_interop) 'app_data_inventory_web.dart'
    as platform;

enum AppDataCategory {
  health,
  snapshots,
  plugins,
  zeppos,
  logs,
  recovery,
  downloads,
  cache,
  images,
  models,
  tasks,
  documents,
}

class AppDataUsage {
  const AppDataUsage(this.category, this.bytes);
  final AppDataCategory category;
  final int? bytes;
}

Future<List<AppDataUsage>> collectAppDataInventory() async {
  final prefs = SharedPrefsService.instance;
  var healthBytes = 0;
  for (final key in prefs.keys.where(
    (key) => key.startsWith('health_data_v6_'),
  )) {
    healthBytes += utf8.encode(prefs.getString(key) ?? '').length;
  }
  final snapshots = await HealthDebugSnapshotStore().storedBytes();
  final sizes = Map<AppDataCategory, int>.of(await platform.collectFileUsage());
  if (kIsWeb) {
    sizes[AppDataCategory.health] = await healthDatabase.storedBytes();
  }
  for (final entry in {
    AppDataCategory.models: ('ai/models', AppStorageLocation.data),
    AppDataCategory.tasks: ('tasks', AppStorageLocation.data),
    AppDataCategory.documents: ('documents', AppStorageLocation.cache),
    AppDataCategory.recovery: ('storage/restore', AppStorageLocation.data),
  }.entries) {
    final directory = await openAppDataDirectory(
      entry.value.$1,
      location: entry.value.$2,
    );
    sizes[entry.key] = (await directory.files(includeTemporary: true))
        .fold(0, (sum, file) => sum + file.bytes);
  }
  final runtime = await openAppDataDirectory('ai/runtimes');
  sizes[AppDataCategory.models] =
      (sizes[AppDataCategory.models] ?? 0) +
      (await runtime.files(includeTemporary: true))
          .fold<int>(0, (n, f) => n + f.bytes);
  return [
    for (final category in AppDataCategory.values)
      AppDataUsage(category, switch (category) {
        AppDataCategory.health => healthBytes + (sizes[category] ?? 0),
        AppDataCategory.snapshots => snapshots,
        _ => sizes[category],
      }),
  ];
}
