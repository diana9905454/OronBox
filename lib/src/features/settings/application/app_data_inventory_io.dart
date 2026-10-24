import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'app_data_inventory.dart';

Future<Map<AppDataCategory, int>> collectFileUsage() async {
  final support = await getApplicationSupportDirectory();
  final cache = await getApplicationCacheDirectory();
  final temporary = await getTemporaryDirectory();
  final localAppData = Platform.environment['LOCALAPPDATA'];
  final pluginSupport = Platform.isWindows && localAppData != null
      ? '$localAppData/OronBox'
      : support.path;
  final pluginCache = Platform.isWindows && localAppData != null
      ? '$localAppData/OronBox/cache'
      : cache.path;
  final roots = {
    AppDataCategory.health: ['${support.path}/health'],
    AppDataCategory.plugins: ['$pluginSupport/plugins'],
    AppDataCategory.zeppos: ['${support.path}/zeppos'],
    AppDataCategory.logs: ['${support.path}/logs'],
    AppDataCategory.recovery: ['${support.path}/storage/restore'],
    AppDataCategory.downloads: [
      '${temporary.path}/oronbox_downloads',
      '${temporary.path}/oronbox/managed',
      '${support.path}/apk',
    ],
    AppDataCategory.cache: ['$pluginCache/plugins'],
    AppDataCategory.images: ['${temporary.path}/libCachedImageData'],
  };
  final sizes = <AppDataCategory, int>{};
  for (final entry in roots.entries) {
    var bytes = 0;
    for (final root in entry.value) {
      bytes += await _size(Directory(root));
    }
    sizes[entry.key] = bytes;
  }
  // Raw activity files have their own category and share the health root.
  sizes[AppDataCategory.health] =
      (sizes[AppDataCategory.health] ?? 0) -
      await _size(Directory('${support.path}/health/raw'));
  final pluginTemp = Directory('${temporary.path}/oronbox');
  if (await pluginTemp.exists()) {
    await for (final entry in pluginTemp.list(followLinks: false)) {
      if (entry is Directory &&
          entry.uri.pathSegments
              .where((part) => part.isNotEmpty)
              .last
              .startsWith('plugins-')) {
        sizes[AppDataCategory.cache] =
            (sizes[AppDataCategory.cache] ?? 0) + await _size(entry);
      }
    }
  }
  await for (final entry in temporary.list(followLinks: false)) {
    if (entry is File &&
        entry.uri.pathSegments.last.startsWith('oronbox_queue_')) {
      try {
        sizes[AppDataCategory.downloads] =
            (sizes[AppDataCategory.downloads] ?? 0) + await entry.length();
      } on FileSystemException {
        if (await entry.exists()) rethrow;
      }
    }
  }
  return sizes;
}

Future<int> _size(Directory directory) async {
  if (await FileSystemEntity.type(directory.path, followLinks: false) !=
      FileSystemEntityType.directory) {
    return 0;
  }
  var bytes = 0;
  await for (final entry in directory.list(
    recursive: true,
    followLinks: false,
  )) {
    if (await FileSystemEntity.type(entry.path, followLinks: false) !=
        FileSystemEntityType.file) {
      continue;
    }
    try {
      bytes += await File(entry.path).length();
    } on FileSystemException {
      // A download or log may have been removed after directory enumeration.
      if (await entry.exists()) rethrow;
    }
  }
  return bytes;
}
