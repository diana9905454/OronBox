import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'app_data_directory.dart';
import 'app_data_lock_io.dart';

Future<AppDataDirectory> openAppDataDirectory(
  String namespace,
  AppStorageLocation location,
) async {
  final root = await switch (location) {
    AppStorageLocation.data => getApplicationSupportDirectory(),
    AppStorageLocation.cache => getApplicationCacheDirectory(),
    AppStorageLocation.temporary => getTemporaryDirectory(),
  };
  return IoAppDataDirectory(Directory('${root.path}/$namespace'));
}

class IoAppDataDirectory implements AppDataDirectory {
  IoAppDataDirectory(this.root);
  final Directory root;
  @override
  Future<T> exclusive<T>(Future<T> Function() action) async {
    final release = await acquireAppDataLock(root.absolute.path, wait: true);
    try {
      return await action();
    } finally {
      await release!();
    }
  }

  @override
  Future<bool> tryExclusive(Future<void> Function() action) async {
    final release = await acquireAppDataLock(root.absolute.path, wait: false);
    if (release == null) return false;
    try {
      await action();
      return true;
    } finally {
      await release();
    }
  }

  Future<File> _file(String path) async {
    validateDataPath(path);
    var current = root.path;
    // Never follow a pre-existing link into another storage domain.
    for (final part in path.split('/')) {
      current = '$current/$part';
      if (await FileSystemEntity.type(current, followLinks: false) ==
          FileSystemEntityType.link) {
        throw const FileSystemException('Application data contains a link');
      }
    }
    return File(current);
  }

  @override
  Future<Uint8List?> read(String path) async {
    final file = await _file(path);
    return await file.exists() ? file.readAsBytes() : null;
  }

  @override
  Future<void> write(String path, Uint8List bytes) async {
    final target = await _file(path);
    await target.parent.create(recursive: true);
    final staging = File('${target.path}.${const Uuid().v4()}.part');
    try {
      await staging.writeAsBytes(bytes, flush: true);
      await staging.rename(target.path);
    } finally {
      if (await staging.exists()) await staging.delete();
    }
  }

  @override
  Future<void> remove(String path) async {
    final file = await _file(path);
    if (await file.exists()) await file.delete();
    var parent = file.parent;
    while (parent.path != root.path && await parent.exists()) {
      if (!await parent.list(followLinks: false).isEmpty) break;
      await parent.delete();
      parent = parent.parent;
    }
  }

  @override
  Stream<List<int>> readStream(String path) async* {
    yield* (await _file(path)).openRead();
  }

  @override
  Future<void> writeStream(
    String path,
    Stream<List<int>> stream, {
    bool append = false,
  }) async {
    final target = await _file(path);
    await target.parent.create(recursive: true);
    final output = append
        ? target
        : File('${target.path}.${const Uuid().v4()}.part');
    final handle = await output.open(
      mode: append ? FileMode.append : FileMode.write,
    );
    try {
      await for (final chunk in stream) {
        await handle.writeFrom(chunk);
      }
      await handle.flush();
    } catch (_) {
      await handle.close();
      if (!append && await output.exists()) await output.delete();
      rethrow;
    }
    await handle.close();
    if (!append) await output.rename(target.path);
  }

  @override
  Future<void> move(String from, String to) async {
    final source = await _file(from);
    final target = await _file(to);
    await target.parent.create(recursive: true);
    await source.rename(target.path);
  }

  @override
  Future<List<AppDataFile>> files({bool includeTemporary = false}) async {
    if (!await root.exists()) return const [];
    final result = <AppDataFile>[];
    await for (final entry in root.list(recursive: true, followLinks: false)) {
      if (await FileSystemEntity.type(entry.path, followLinks: false) !=
          FileSystemEntityType.file) {
        continue;
      }
      final path = entry.path
          .substring(root.path.length + 1)
          .replaceAll(Platform.pathSeparator, '/');
      if (path == '.lock' ||
          path.endsWith('/.lock') ||
          (!includeTemporary && path.endsWith('.part'))) {
        continue;
      }
      try {
        final stat = await entry.stat();
        result.add(AppDataFile(path, stat.size, modifiedAt: stat.modified));
      } on FileSystemException {
        if (await entry.exists()) rethrow;
      }
    }
    return result;
  }
}
