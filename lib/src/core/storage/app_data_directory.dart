import 'dart:typed_data';

import 'app_data_directory_stub.dart'
    if (dart.library.io) 'app_data_directory_io.dart'
    if (dart.library.js_interop) 'app_data_directory_web.dart'
    as platform;

class AppDataFile {
  const AppDataFile(this.path, this.bytes, {this.modifiedAt});
  final String path;
  final int bytes;
  final DateTime? modifiedAt;
}

enum AppStorageLocation { data, cache, temporary }

/// A private namespace. Callers own their format and retention policy.
abstract interface class AppDataDirectory {
  Future<T> exclusive<T>(Future<T> Function() action);
  Future<bool> tryExclusive(Future<void> Function() action);
  Future<Uint8List?> read(String path);
  Future<void> write(String path, Uint8List bytes);
  Stream<List<int>> readStream(String path);
  Future<void> writeStream(
    String path,
    Stream<List<int>> stream, {
    bool append = false,
  });
  Future<void> move(String from, String to);
  Future<void> remove(String path);
  Future<List<AppDataFile>> files({bool includeTemporary = false});
}

extension ScopedApplicationData on AppDataDirectory {
  AppDataDirectory scope(String prefix) {
    validateDataPath(prefix);
    return _ScopedDirectory(this, prefix);
  }
}

class _ScopedDirectory implements AppDataDirectory {
  _ScopedDirectory(this.parent, this.prefix);
  final AppDataDirectory parent;
  final String prefix;
  String _path(String path) {
    validateDataPath(path);
    return '$prefix/$path';
  }

  @override
  Future<T> exclusive<T>(Future<T> Function() action) =>
      parent.exclusive(action);
  @override
  Future<bool> tryExclusive(Future<void> Function() action) =>
      parent.tryExclusive(action);
  @override
  Future<Uint8List?> read(String path) => parent.read(_path(path));
  @override
  Future<void> write(String path, Uint8List bytes) =>
      parent.write(_path(path), bytes);
  @override
  Stream<List<int>> readStream(String path) => parent.readStream(_path(path));
  @override
  Future<void> writeStream(
    String path,
    Stream<List<int>> stream, {
    bool append = false,
  }) => parent.writeStream(_path(path), stream, append: append);
  @override
  Future<void> move(String from, String to) =>
      parent.move(_path(from), _path(to));
  @override
  Future<void> remove(String path) => parent.remove(_path(path));
  @override
  Future<List<AppDataFile>> files({bool includeTemporary = false}) async => [
    for (final file in await parent.files(includeTemporary: includeTemporary))
      if (file.path.startsWith('$prefix/'))
        AppDataFile(
          file.path.substring(prefix.length + 1),
          file.bytes,
          modifiedAt: file.modifiedAt,
        ),
  ];
}

Future<AppDataDirectory> openAppDataDirectory(
  String namespace, {
  AppStorageLocation location = AppStorageLocation.data,
}) {
  validateDataPath(namespace);
  return platform.openAppDataDirectory(namespace, location);
}

void validateDataPath(String path) {
  if (path.isEmpty ||
      path
          .split('/')
          .any(
            (part) =>
                part.isEmpty ||
                part == '.' ||
                part == '..' ||
                !RegExp(r'^[a-zA-Z0-9_.-]+$').hasMatch(part),
          )) {
    throw const FormatException('Invalid application data path');
  }
}
