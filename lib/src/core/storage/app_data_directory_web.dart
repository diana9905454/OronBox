import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;
import 'package:uuid/uuid.dart';

import 'app_data_directory.dart';

final _directories = <String, Future<AppDataDirectory>>{};
Future<AppDataDirectory> openAppDataDirectory(
  String namespace,
  AppStorageLocation location,
) {
  if (location != AppStorageLocation.data) {
    namespace = '${location.name}/$namespace';
  }
  return _directories.putIfAbsent(namespace, () async {
    final request = web.window.indexedDB.open('oronbox.data', 1);
    request.onupgradeneeded = ((web.Event _) {
      final db = request.result as web.IDBDatabase;
      db.createObjectStore('files');
      db.createObjectStore('sizes');
    }).toJS;
    return _WebAppDataDirectory(
      await _request(request) as web.IDBDatabase,
      namespace,
    );
  });
}

class _WebAppDataDirectory implements AppDataDirectory {
  _WebAppDataDirectory(this.db, this.namespace);
  final web.IDBDatabase db;
  final String namespace;
  String _key(String path) {
    validateDataPath(path);
    return '$namespace/$path';
  }

  @override
  Future<T> exclusive<T>(Future<T> Function() action) async {
    late T result;
    final callback = ((JSAny? _) => (() async {
      result = await action();
      return null;
    })().toJS).toJS;
    await web.window.navigator.locks
        .request('oronbox-data-$namespace', callback)
        .toDart;
    return result;
  }

  @override
  Future<bool> tryExclusive(Future<void> Function() action) async {
    var acquired = false;
    final callback = ((JSAny? lock) => (() async {
      if (lock.isUndefinedOrNull) return null;
      acquired = true;
      await action();
      return null;
    })().toJS).toJS;
    await web.window.navigator.locks
        .request(
          'oronbox-data-$namespace',
          web.LockOptions(ifAvailable: true),
          callback,
        )
        .toDart;
    return acquired;
  }

  Future<JSAny?> _raw(String path) async {
    final tx = db.transaction('files'.toJS, 'readonly');
    final done = _transaction(tx);
    final result = await _request(tx.objectStore('files').get(_key(path).toJS));
    await done;
    return result == null || result.isUndefinedOrNull ? null : result;
  }

  List<String> _parts(JSAny? raw) => raw == null || raw.isA<JSUint8Array>()
      ? []
      : List<String>.from((raw.dartify() as Map)['parts'] as List);
  int _length(JSAny raw) => raw.isA<JSUint8Array>()
      ? (raw as JSUint8Array).toDart.length
      : ((raw.dartify() as Map)['bytes'] as num).toInt();

  @override
  Future<Uint8List?> read(String path) async {
    final raw = await _raw(path);
    if (raw == null) return null;
    if (raw.isA<JSUint8Array>()) {
      return Uint8List.fromList((raw as JSUint8Array).toDart);
    }
    final bytes = BytesBuilder(copy: false);
    await for (final part in _readParts(raw)) {
      bytes.add(part);
    }
    return bytes.takeBytes();
  }

  Stream<List<int>> _readParts(JSAny raw) async* {
    for (final key in _parts(raw)) {
      final tx = db.transaction('files'.toJS, 'readonly');
      final done = _transaction(tx);
      final part = await _request(tx.objectStore('files').get(key.toJS));
      await done;
      if (part == null || part.isUndefinedOrNull) {
        throw StateError('Application data chunk is missing');
      }
      yield (part as JSUint8Array).toDart;
    }
  }

  @override
  Stream<List<int>> readStream(String path) async* {
    final raw = await _raw(path);
    if (raw == null) throw StateError('Application data file is missing');
    if (raw.isA<JSUint8Array>()) {
      yield (raw as JSUint8Array).toDart;
    } else {
      yield* _readParts(raw);
    }
  }

  @override
  Future<void> write(String path, Uint8List bytes) async {
    final old = await _raw(path);
    final tx = db.transaction(['files'.toJS, 'sizes'.toJS].toJS, 'readwrite');
    final done = _transaction(tx);
    for (final part in _parts(old)) {
      tx.objectStore('files').delete(part.toJS);
    }
    tx.objectStore('files').put(bytes.toJS, _key(path).toJS);
    tx.objectStore('sizes').put(_sizeValue(bytes.length), _key(path).toJS);
    await done;
  }

  @override
  Future<void> writeStream(
    String path,
    Stream<List<int>> stream, {
    bool append = false,
  }) async {
    if (!append) {
      final temporary = '$path.${const Uuid().v4()}.part';
      try {
        await writeStream(temporary, stream, append: true);
        await move(temporary, path);
      } catch (_) {
        await remove(temporary);
        rethrow;
      }
      return;
    }
    final old = await _raw(path);
    final parts = append ? _parts(old) : <String>[];
    var length = append && old != null ? _length(old) : 0;
    final prefix = '$namespace/.chunks/${const Uuid().v4()}';
    var next = 0;
    Future<void> save(Uint8List? chunk, {bool clear = false}) async {
      final tx = db.transaction(['files'.toJS, 'sizes'.toJS].toJS, 'readwrite');
      final done = _transaction(tx);
      if (clear) {
        for (final part in _parts(old)) {
          tx.objectStore('files').delete(part.toJS);
        }
      }
      if (chunk != null) {
        final key = '$prefix/${next++}';
        parts.add(key);
        tx.objectStore('files').put(chunk.toJS, key.toJS);
        length += chunk.length;
      }
      tx
          .objectStore('files')
          .put({'parts': parts, 'bytes': length}.jsify(), _key(path).toJS);
      tx.objectStore('sizes').put(_sizeValue(length), _key(path).toJS);
      await done;
    }

    if (append && old != null && old.isA<JSUint8Array>()) {
      length = 0;
      await save((old as JSUint8Array).toDart);
    } else {
      await save(null, clear: !append);
    }
    await for (final chunk in stream) {
      for (var offset = 0; offset < chunk.length; offset += 512 * 1024) {
        final end = (offset + 512 * 1024).clamp(0, chunk.length);
        await save(Uint8List.fromList(chunk.sublist(offset, end)));
      }
    }
  }

  @override
  Future<void> move(String from, String to) async {
    if (from == to) return;
    final source = await _raw(from);
    if (source == null) throw StateError('Application data file is missing');
    final target = await _raw(to);
    final tx = db.transaction(['files'.toJS, 'sizes'.toJS].toJS, 'readwrite');
    final done = _transaction(tx);
    for (final part in _parts(target)) {
      tx.objectStore('files').delete(part.toJS);
    }
    tx.objectStore('files').put(source, _key(to).toJS);
    tx.objectStore('sizes').put(_sizeValue(_length(source)), _key(to).toJS);
    tx.objectStore('files').delete(_key(from).toJS);
    tx.objectStore('sizes').delete(_key(from).toJS);
    await done;
  }

  @override
  Future<void> remove(String path) async {
    final old = await _raw(path);
    final tx = db.transaction(['files'.toJS, 'sizes'.toJS].toJS, 'readwrite');
    final done = _transaction(tx);
    for (final part in _parts(old)) {
      tx.objectStore('files').delete(part.toJS);
    }
    tx.objectStore('files').delete(_key(path).toJS);
    tx.objectStore('sizes').delete(_key(path).toJS);
    await done;
  }

  JSAny? _sizeValue(int bytes) => {
    'bytes': bytes,
    'modifiedAt': DateTime.now().toUtc().toIso8601String(),
  }.jsify();

  @override
  Future<List<AppDataFile>> files({bool includeTemporary = false}) async {
    final result = <AppDataFile>[];
    final tx = db.transaction('sizes'.toJS, 'readonly');
    final done = _transaction(tx);
    final request = tx.objectStore('sizes').openCursor();
    request.onsuccess = ((web.Event _) {
      final value = request.result;
      if (value == null || value.isUndefinedOrNull) return;
      final cursor = value as web.IDBCursorWithValue;
      final key = (cursor.key as JSString).toDart;
      final prefix = '$namespace/';
      if (key.startsWith(prefix)) {
        final path = key.substring(prefix.length);
        if (includeTemporary || !path.endsWith('.part')) {
          final value = cursor.value.dartify();
          final size = value is num
              ? value.toInt()
              : ((value as Map)['bytes'] as num).toInt();
          final modified = value is Map
              ? DateTime.tryParse(value['modifiedAt'] as String? ?? '')
              : null;
          result.add(AppDataFile(path, size, modifiedAt: modified));
        }
      }
      cursor.continue_();
    }).toJS;
    await done;
    return result;
  }
}

Future<JSAny?> _request(web.IDBRequest request) {
  final result = Completer<JSAny?>();
  request.onsuccess = ((web.Event _) => result.complete(request.result)).toJS;
  request.onerror = ((web.Event _) => result.completeError(
    StateError(request.error?.message ?? 'Storage request failed'),
  )).toJS;
  return result.future;
}

Future<void> _transaction(web.IDBTransaction tx) {
  final result = Completer<void>();
  tx.oncomplete = ((web.Event _) {
    if (!result.isCompleted) result.complete();
  }).toJS;
  tx.onabort = tx.onerror = ((web.Event _) {
    if (!result.isCompleted) {
      result.completeError(
        StateError(tx.error?.message ?? 'Storage transaction failed'),
      );
    }
  }).toJS;
  return result.future;
}
