import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'managed_temporary_files.dart';

final _leases = <String, RandomAccessFile>{};
Future<Directory> _root() async =>
    Directory('${(await getTemporaryDirectory()).path}/oronbox/managed');

Future<String> create(
  TemporaryFilePurpose purpose,
  String name,
  Future<void> Function(String) write,
) async {
  if (name.isEmpty ||
      name.contains('/') ||
      name.contains('\\') ||
      name.contains('\x00') ||
      name == '.' ||
      name == '..' ||
      name.startsWith('.')) {
    throw const FormatException('Invalid temporary filename');
  }
  final directory = Directory(
    '${(await _root()).path}/${purpose.name}/${const Uuid().v4()}',
  );
  await directory.create(recursive: true);
  final path = '${directory.path}/$name';
  final lease = await File('${directory.path}/.lease')
      .open(mode: FileMode.append);
  try {
    await lease.lock(FileLock.exclusive);
    await File('${directory.path}/.owner').writeAsString('$pid', flush: true);
    _leases[path] = lease;
    await write(path);
    return path;
  } catch (_) {
    if (_leases.containsKey(path)) {
      await release(path);
    } else {
      await lease.close();
      await directory.delete(recursive: true);
    }
    rethrow;
  }
}

Future<void> release(String path, {bool delete = true}) async {
  final lease = _leases.remove(path);
  if (lease == null) return;
  final directory = File(path).parent;
  try {
    if (delete) {
      await lease.close();
      await directory.delete(recursive: true);
    } else {
      await File('${directory.path}/.owner').writeAsString('0', flush: true);
    }
  } finally {
    if (!delete) await lease.close();
  }
}

Future<int> cleanup(Duration minimumAge, Set<String> protectedPaths) async {
  final root = await _root();
  if (!await root.exists()) return 0;
  final cutoff = DateTime.now().subtract(minimumAge);
  var removed = 0;
  for (final purpose in TemporaryFilePurpose.values) {
    final category = Directory('${root.path}/${purpose.name}');
    if (!await category.exists()) continue;
    await for (final entry in category.list(followLinks: false)) {
      if (entry is! Directory ||
          [
            ..._leases.keys,
            ...protectedPaths,
          ].any((path) => File(path).parent.path == entry.path)) {
        continue;
      }
      RandomAccessFile? lock;
      try {
        final owner = File('${entry.path}/.owner');
        if (!await owner.exists() ||
            (await owner.stat()).modified.isAfter(cutoff)) {
          continue;
        }
        // POSIX locks are process-scoped, so another engine in this process is protected too.
        if (await owner.readAsString() == '$pid') continue;
        lock = await File('${entry.path}/.lease').open(mode: FileMode.append);
        await lock.lock(FileLock.exclusive);
        await owner.writeAsString('$pid', flush: true);
        await lock.close();
        lock = null;
        await entry.delete(recursive: true);
        removed++;
      } on FileSystemException {
        // A live owner or a concurrent cleaner retains ownership.
      } finally {
        await lock?.close();
      }
    }
  }
  return removed;
}
