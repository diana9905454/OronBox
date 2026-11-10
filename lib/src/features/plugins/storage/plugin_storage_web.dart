import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;
import 'package:oronbox/src/features/plugins/domain/plugin_package.dart';

import 'plugin_storage.dart';

Future<PluginStorage> createPluginStorage() async {
  final storage = _WebPluginStorage();
  await storage.initialize();
  return storage;
}

class _WebPluginStorage implements PluginStorage {
  static const _databaseName = 'oronbox.plugins';
  static const _databaseVersion = 2;
  static const _filesStore = 'files';
  static const _sizesStore = 'sizes';
  static const _separator = '\u0001';
  static const _configFile = '.oronbox/config.json';
  static const _permissionsFile = '.oronbox/permissions.json';

  web.IDBDatabase? _database;

  Future<void> initialize() async {
    final request = web.window.indexedDB.open(_databaseName, _databaseVersion);
    request.onupgradeneeded = ((web.Event _) {
      final database = request.result as web.IDBDatabase;
      if (!database.objectStoreNames.contains(_filesStore)) {
        database.createObjectStore(_filesStore);
      }
      if (!database.objectStoreNames.contains(_sizesStore)) {
        final sizes = database.createObjectStore(_sizesStore);
        final cursor = request.transaction!
            .objectStore(_filesStore)
            .openCursor();
        cursor.onsuccess = ((web.Event _) {
          final value = cursor.result;
          if (value.isUndefinedOrNull) return;
          final entry = value as web.IDBCursorWithValue;
          sizes.put(
            (entry.value as JSUint8Array).toDart.length.toJS,
            entry.key,
          );
          entry.continue_();
        }).toJS;
      }
    }).toJS;
    _database = await _request(request) as web.IDBDatabase;
  }

  @override
  Future<List<InstalledPlugin>> loadInstalled() async {
    final entries = await _allEntries();
    final manifestSuffix =
        '$_separator${PluginStorageArea.package.name}'
        '${_separator}manifest.json';
    final plugins = <InstalledPlugin>[];
    for (final entry in entries.entries.where(
      (entry) => entry.key.endsWith(manifestSuffix),
    )) {
      try {
        final id = entry.key.substring(
          0,
          entry.key.length - manifestSuffix.length,
        );
        final manifest = const PluginPackageReader().readManifest(entry.value);
        if (manifest.id != id) {
          throw const FormatException(
            'Plugin storage ID does not match manifest',
          );
        }
        final source =
            entries[_fileKey(id, PluginStorageArea.package, manifest.entry)];
        if (source == null) {
          throw FormatException('Plugin entry is missing: ${manifest.entry}');
        }
        final icon = manifest.iconPath == null
            ? null
            : entries[_fileKey(
                id,
                PluginStorageArea.package,
                manifest.iconPath!,
              )];
        final configBytes =
            entries[_fileKey(id, PluginStorageArea.data, _configFile)];
        plugins.add(
          InstalledPlugin(
            manifest: manifest,
            entryBytes: source,
            config: _decodeConfig(configBytes),
            iconBase64: icon == null ? null : base64Encode(icon),
          ),
        );
      } catch (_) {
        // A damaged plugin is isolated from the rest of the registry
      }
    }
    return plugins;
  }

  @override
  Future<InstalledPlugin> install(
    PluginPackage package, {
    required Map<String, Object?> config,
  }) async {
    final id = package.manifest.id;
    final packagePrefix = _areaPrefix(id, PluginStorageArea.package);
    final existingKeys = await _allKeys();
    final transaction = _db.transaction(
      [_filesStore.toJS, _sizesStore.toJS].toJS,
      'readwrite',
    );
    for (final key in existingKeys.where(
      (key) => key.startsWith(packagePrefix),
    )) {
      _delete(transaction, key);
    }
    for (final entry in package.files.entries) {
      _put(
        transaction,
        entry.value,
        _fileKey(id, PluginStorageArea.package, entry.key),
      );
    }
    _put(
      transaction,
      Uint8List.fromList(utf8.encode(jsonEncode(config))),
      _fileKey(id, PluginStorageArea.data, _configFile),
    );
    await _transaction(transaction);
    return package.installed(config: config);
  }

  @override
  Future<void> writeConfig(String pluginId, Map<String, Object?> config) async {
    final transaction = _db.transaction(
      [_filesStore.toJS, _sizesStore.toJS].toJS,
      'readwrite',
    );
    _put(
      transaction,
      Uint8List.fromList(utf8.encode(jsonEncode(config))),
      _fileKey(pluginId, PluginStorageArea.data, _configFile),
    );
    await _transaction(transaction);
  }

  @override
  Future<Set<String>> readPermissionGrants(String pluginId) async {
    final transaction = _db.transaction(_filesStore.toJS, 'readonly');
    final value = await _request(
      transaction
          .objectStore(_filesStore)
          .get(
            _fileKey(pluginId, PluginStorageArea.data, _permissionsFile).toJS,
          ),
    );
    if (value == null) return <String>{};
    final raw = value.dartify();
    final bytes = raw is Uint8List
        ? raw
        : Uint8List.fromList((raw as List).cast<int>());
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! List) {
      throw const FormatException('Invalid plugin permission grants');
    }
    return decoded.map((item) => item.toString()).toSet();
  }

  @override
  Future<void> writePermissionGrants(
    String pluginId,
    Set<String> grants,
  ) async {
    final bytes = Uint8List.fromList(
      utf8.encode(jsonEncode(grants.toList()..sort())),
    );
    final transaction = _db.transaction(
      [_filesStore.toJS, _sizesStore.toJS].toJS,
      'readwrite',
    );
    _put(
      transaction,
      bytes,
      _fileKey(pluginId, PluginStorageArea.data, _permissionsFile),
    );
    await _transaction(transaction);
  }

  @override
  Future<void> removePlugin(String pluginId) async {
    final keys = await _allKeys();
    final prefix = '$pluginId$_separator';
    final transaction = _db.transaction(
      [_filesStore.toJS, _sizesStore.toJS].toJS,
      'readwrite',
    );
    for (final key in keys.where((key) => key.startsWith(prefix))) {
      _delete(transaction, key);
    }
    await _transaction(transaction);
  }

  @override
  Future<void> clearPluginData(String pluginId) async {
    final keys = await _allKeys();
    final packagePrefix = _areaPrefix(pluginId, PluginStorageArea.package);
    final pluginPrefix = '$pluginId$_separator';
    final transaction = _db.transaction(
      [_filesStore.toJS, _sizesStore.toJS].toJS,
      'readwrite',
    );
    for (final key in keys.where(
      (key) => key.startsWith(pluginPrefix) && !key.startsWith(packagePrefix),
    )) {
      _delete(transaction, key);
    }
    await _transaction(transaction);
  }

  @override
  Future<Uint8List> readFile(String pluginId, PluginStoragePath path) async {
    if (path.relativePath.isEmpty) {
      throw const FormatException('A file path is required');
    }
    final transaction = _db.transaction(_filesStore.toJS, 'readonly');
    final value = await _request(
      transaction
          .objectStore(_filesStore)
          .get(_fileKey(pluginId, path.area, path.relativePath).toJS),
    );
    if (value == null) {
      throw StateError('Plugin file does not exist: ${path.virtualPath}');
    }
    final dartValue = value.dartify();
    if (dartValue is Uint8List) return dartValue;
    if (dartValue is List) {
      return Uint8List.fromList(
        dartValue.whereType<num>().map((v) => v.toInt()).toList(),
      );
    }
    throw StateError('Invalid plugin file: ${path.virtualPath}');
  }

  @override
  Future<void> writeFile(
    String pluginId,
    PluginStoragePath path,
    Uint8List bytes,
  ) async {
    if (path.area == PluginStorageArea.package) {
      throw UnsupportedError('/plugin is read-only');
    }
    if (path.relativePath.isEmpty) {
      throw const FormatException('A file path is required');
    }
    final transaction = _db.transaction(
      [_filesStore.toJS, _sizesStore.toJS].toJS,
      'readwrite',
    );
    _put(transaction, bytes, _fileKey(pluginId, path.area, path.relativePath));
    await _transaction(transaction);
  }

  @override
  Future<int> writeFileStream(
    String pluginId,
    PluginStoragePath path,
    Stream<List<int>> stream, {
    bool append = false,
  }) async {
    final builder = BytesBuilder(copy: false);
    if (append) {
      final existing = await stat(pluginId, path);
      if (existing != null && !existing.isDirectory) {
        builder.add(await readFile(pluginId, path));
      }
    }
    var written = 0;
    await for (final chunk in stream) {
      builder.add(chunk);
      written += chunk.length;
    }
    await writeFile(pluginId, path, builder.takeBytes());
    return written;
  }

  @override
  Future<List<PluginFileStat>> listDirectory(
    String pluginId,
    PluginStoragePath path,
  ) async {
    final entries = await _allEntries();
    final key = _fileKey(pluginId, path.area, path.relativePath);
    final directoryPrefix = path.relativePath.isEmpty ? key : '$key/';
    final children = <String, PluginFileStat>{};
    for (final entry in entries.entries) {
      if (!entry.key.startsWith(directoryPrefix)) continue;
      final remainder = entry.key.substring(directoryPrefix.length);
      if (remainder.isEmpty) continue;
      final slash = remainder.indexOf('/');
      final name = slash < 0 ? remainder : remainder.substring(0, slash);
      if (name.startsWith('.oronbox')) continue;
      final virtual = '${path.virtualPath}/$name';
      children[name] = PluginFileStat(
        path: virtual,
        size: slash < 0 ? entry.value.length : 0,
        isDirectory: slash >= 0,
      );
    }
    final result = children.values.toList();
    result.sort((a, b) => a.path.compareTo(b.path));
    return result;
  }

  @override
  Future<void> createDirectory(String pluginId, PluginStoragePath path) async {
    if (path.area == PluginStorageArea.package) {
      throw UnsupportedError('/plugin is read-only');
    }
    if (path.relativePath.isEmpty) return;
    final marker = '${path.relativePath}/.oronbox-directory';
    final transaction = _db.transaction(
      [_filesStore.toJS, _sizesStore.toJS].toJS,
      'readwrite',
    );
    _put(transaction, Uint8List(0), _fileKey(pluginId, path.area, marker));
    await _transaction(transaction);
  }

  @override
  Future<PluginFileStat?> stat(String pluginId, PluginStoragePath path) async {
    if (path.relativePath.isEmpty) {
      return PluginFileStat(path: path.virtualPath, size: 0, isDirectory: true);
    }
    final entries = await _allEntries();
    final key = _fileKey(pluginId, path.area, path.relativePath);
    final bytes = entries[key];
    if (bytes != null) {
      return PluginFileStat(
        path: path.virtualPath,
        size: bytes.length,
        isDirectory: false,
      );
    }
    if (entries.keys.any((candidate) => candidate.startsWith('$key/'))) {
      return PluginFileStat(path: path.virtualPath, size: 0, isDirectory: true);
    }
    return null;
  }

  @override
  Future<void> removeFile(String pluginId, PluginStoragePath path) async {
    if (path.area == PluginStorageArea.package) {
      throw UnsupportedError('/plugin is read-only');
    }
    if (path.relativePath.isEmpty) {
      throw const FormatException('Cannot remove a storage root');
    }
    final keys = await _allKeys();
    final key = _fileKey(pluginId, path.area, path.relativePath);
    final transaction = _db.transaction(
      [_filesStore.toJS, _sizesStore.toJS].toJS,
      'readwrite',
    );
    for (final candidate in keys.where(
      (candidate) => candidate == key || candidate.startsWith('$key/'),
    )) {
      _delete(transaction, candidate);
    }
    await _transaction(transaction);
  }

  @override
  String? nativePath(String pluginId, PluginStoragePath path) => null;

  void _put(web.IDBTransaction transaction, Uint8List bytes, String key) {
    transaction.objectStore(_filesStore).put(bytes.toJS, key.toJS);
    transaction.objectStore(_sizesStore).put(bytes.length.toJS, key.toJS);
  }

  void _delete(web.IDBTransaction transaction, String key) {
    transaction.objectStore(_filesStore).delete(key.toJS);
    transaction.objectStore(_sizesStore).delete(key.toJS);
  }

  Future<Map<PluginStorageArea, int>> usage() async {
    final tx = _db.transaction(_sizesStore.toJS, 'readonly');
    final store = tx.objectStore(_sizesStore);
    final keys = _request(store.getAllKeys());
    final sizes = _request(store.getAll());
    final names = ((await keys)?.dartify() as List).cast<String>();
    final bytes = ((await sizes)?.dartify() as List).cast<num>();
    final result = {for (final area in PluginStorageArea.values) area: 0};
    for (var i = 0; i < names.length; i++) {
      final parts = names[i].split(_separator);
      if (parts.length != 3) continue;
      for (final area in PluginStorageArea.values) {
        if (parts[1] == area.name) {
          result[area] = result[area]! + bytes[i].toInt();
        }
      }
    }
    return result;
  }

  Future<List<String>> _allKeys() async {
    final transaction = _db.transaction(_filesStore.toJS, 'readonly');
    final value = await _request(
      transaction.objectStore(_filesStore).getAllKeys(),
    );
    return (value?.dartify() as List? ?? const [])
        .map((key) => key.toString())
        .toList(growable: false);
  }

  Future<Map<String, Uint8List>> _allEntries() async {
    final transaction = _db.transaction(_filesStore.toJS, 'readonly');
    final store = transaction.objectStore(_filesStore);
    final keysRequest = _request(store.getAllKeys());
    final valuesRequest = _request(store.getAll());
    final keysValue = await keysRequest;
    final valuesValue = await valuesRequest;
    final keys = keysValue?.dartify() as List? ?? const [];
    final values = valuesValue?.dartify() as List? ?? const [];
    final result = <String, Uint8List>{};
    for (var index = 0; index < keys.length && index < values.length; index++) {
      final value = values[index];
      if (value is Uint8List) result[keys[index].toString()] = value;
    }
    return result;
  }

  String _fileKey(String id, PluginStorageArea area, String relativePath) =>
      '$id$_separator${area.name}$_separator$relativePath';

  String _areaPrefix(String id, PluginStorageArea area) =>
      '$id$_separator${area.name}$_separator';

  Map<String, Object?> _decodeConfig(Uint8List? bytes) {
    if (bytes == null) return const {};
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map) throw const FormatException('Invalid plugin config');
    return decoded.cast<String, Object?>();
  }

  Future<JSAny?> _request(web.IDBRequest request) {
    final completer = Completer<JSAny?>();
    request.onsuccess = ((web.Event _) {
      if (!completer.isCompleted) completer.complete(request.result);
    }).toJS;
    request.onerror = ((web.Event _) {
      if (!completer.isCompleted) {
        completer.completeError(
          StateError(request.error?.message ?? 'IndexedDB request failed'),
        );
      }
    }).toJS;
    return completer.future;
  }

  Future<void> _transaction(web.IDBTransaction transaction) {
    final completer = Completer<void>();
    transaction.oncomplete = ((web.Event _) {
      if (!completer.isCompleted) completer.complete();
    }).toJS;
    transaction.onabort = transaction.onerror = ((web.Event _) {
      if (!completer.isCompleted) {
        completer.completeError(
          StateError(
            transaction.error?.message ?? 'IndexedDB transaction failed',
          ),
        );
      }
    }).toJS;
    return completer.future;
  }

  web.IDBDatabase get _db {
    final database = _database;
    if (database == null) throw StateError('Plugin storage is closed');
    return database;
  }

  @override
  Future<void> close() async {
    _database?.close();
    _database = null;
  }
}

Future<Map<PluginStorageArea, int>> collectWebPluginStorageUsage() async {
  final storage = _WebPluginStorage();
  try {
    await storage.initialize();
    return await storage.usage();
  } finally {
    await storage.close();
  }
}
