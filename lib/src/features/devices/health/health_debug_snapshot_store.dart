import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:oronbox/src/core/storage/app_data_directory.dart';
import 'package:oronbox/src/device/xiaomi/systems/health_system.dart';

import 'health_debug_snapshot.dart';
export 'health_debug_snapshot.dart';

class HealthDebugSnapshotStore {
  HealthDebugSnapshotStore({AppDataDirectory? storage})
    : _storage = storage == null ? null : Future.value(storage);

  static const _maxSnapshots = 20;
  static const _maxStoredBytes = 100 * 1024 * 1024;
  Future<AppDataDirectory>? _storage;

  Future<T> _locked<T>(Future<T> Function(AppDataDirectory) action) async {
    final storage = await (_storage ??= openAppDataDirectory('health/raw'));
    return storage.exclusive(() async {
      return action(storage);
    });
  }

  Future<List<HealthSnapshotSummary>> list() => _locked(_index);

  // Kept for callers explicitly requesting complete captures, not list views.
  Future<List<XiaomiHealthRawSnapshot>> read() => _locked(
    (storage) async => [
      for (final summary in await _index(storage))
        await _load(storage, summary),
    ],
  );

  Future<XiaomiHealthRawSnapshot> load(String id) => _locked((storage) async {
    final summary = (await _index(storage))
        .where((item) => item.id == id)
        .firstOrNull;
    if (summary == null) throw StateError('Health snapshot no longer exists');
    return _load(storage, summary);
  });

  Future<Uint8List> export(String id) async =>
      compute(_encodeArchive, await load(id));

  Future<Uint8List> exportCollection() async {
    final captures = await _locked((storage) async {
      final summaries = await _index(storage);
      if (summaries.fold<int>(0, (sum, item) => sum + item.totalBytes) >
          128 * 1024 * 1024) {
        throw const SnapshotArchiveTooLarge();
      }
      return [for (final summary in summaries) await _load(storage, summary)];
    });
    return compute(_encodeCollection, captures);
  }

  Future<void> add({
    required String deviceId,
    String? deviceCode,
    required List<XiaomiActivityRawFile> files,
  }) async {
    if (files.isEmpty) return;
    final snapshot = XiaomiHealthRawSnapshot(
      id: const Uuid().v4(),
      deviceId: deviceId,
      deviceCode: deviceCode,
      capturedAt: DateTime.now(),
      files: List.unmodifiable(
        files.map(
          (file) => XiaomiActivityRawFile(
            id: file.id,
            data: Uint8List.fromList(file.data),
          ),
        ),
      ),
    );
    await _locked((storage) => _save(storage, snapshot));
  }

  Future<XiaomiHealthRawSnapshot> import(Uint8List bytes) async {
    final snapshot = await compute(_decodeArchive, bytes);
    await _locked((storage) => _save(storage, snapshot));
    return snapshot;
  }

  Future<void> _save(
    AppDataDirectory storage,
    XiaomiHealthRawSnapshot snapshot,
  ) async {
    if (snapshot.files.fold<int>(0, (sum, file) => sum + file.data.length) >
        _maxStoredBytes) {
      throw const SnapshotArchiveTooLarge();
    }
    final previous = await _index(storage);
    final summary = await _writeFiles(storage, snapshot);
    final next = [summary, ...previous.where((item) => item.id != snapshot.id)];
    var bytes = next.fold<int>(0, (sum, item) => sum + item.totalBytes);
    while (next.length > _maxSnapshots || bytes > _maxStoredBytes) {
      bytes -= next.removeLast().totalBytes;
    }
    await _commit(storage, next);
  }

  Future<void> delete(String id) => _locked((storage) async {
    final next = (await _index(storage))
        .where((item) => item.id != id)
        .toList();
    await _commit(storage, next);
  });

  Future<void> clear() => _locked((storage) => _commit(storage, const []));

  Future<int> storedBytes() => _locked(
    (storage) async =>
        (await storage.files()).fold<int>(0, (sum, file) => sum + file.bytes),
  );

  Future<List<HealthSnapshotSummary>> _index(AppDataDirectory storage) async {
    final bytes = await storage.read('index.json');
    if (bytes == null) return [];
    final decoded = jsonDecode(utf8.decode(bytes)) as Map;
    if (decoded['version'] != 1) {
      throw const FormatException('Unknown snapshot format');
    }
    final result = (decoded['snapshots'] as List)
        .map(
          (item) => HealthSnapshotSummary.fromJson(
            (item as Map).cast<String, Object?>(),
          ),
        )
        .toList();
    if (result.map((item) => item.id).toSet().length != result.length) {
      throw const FormatException('Duplicate health snapshot id');
    }
    for (final item in result) {
      final directory = sha256.convert(utf8.encode(item.id)).toString();
      if (item.files.isEmpty ||
          item.files.map((file) => file.id).toSet().length !=
              item.files.length ||
          item.files.any(
            (file) =>
                file.bytes < 0 ||
                !RegExp(r'^[a-f0-9]{64}$').hasMatch(file.digest) ||
                (file.path != '$directory/files/${file.digest}.bin' &&
                    file.path != _rawPath(item.deviceId, file.id, file.digest)),
          )) {
        throw const FormatException('Invalid health snapshot index');
      }
    }
    return result..sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
  }

  Future<HealthSnapshotSummary> _writeFiles(
    AppDataDirectory storage,
    XiaomiHealthRawSnapshot snapshot,
  ) async {
    if (snapshot.files.isEmpty ||
        snapshot.files.map((file) => file.id).toSet().length !=
            snapshot.files.length) {
      throw const FormatException('Invalid health snapshot files');
    }
    final files = <HealthSnapshotFile>[];
    for (final file in snapshot.files) {
      final digest = sha256.convert(file.data).toString();
      final path = _rawPath(snapshot.deviceId, file.id, digest);
      final existing = await storage.read(path);
      if (existing == null || sha256.convert(existing).toString() != digest) {
        await storage.write(path, file.data);
      }
      files.add(
        HealthSnapshotFile(
          id: file.id,
          path: path,
          bytes: file.data.length,
          digest: digest,
        ),
      );
    }
    final summary = HealthSnapshotSummary(
      id: snapshot.id,
      deviceId: snapshot.deviceId,
      deviceCode: snapshot.deviceCode,
      capturedAt: snapshot.capturedAt,
      files: files,
    );
    // Verify persisted bytes before a new record can become visible.
    await _load(storage, summary);
    return summary;
  }

  Future<XiaomiHealthRawSnapshot> _load(
    AppDataDirectory storage,
    HealthSnapshotSummary summary,
  ) async {
    final files = <XiaomiActivityRawFile>[];
    for (final file in summary.files) {
      final data = await storage.read(file.path);
      if (data == null ||
          data.length != file.bytes ||
          sha256.convert(data).toString() != file.digest) {
        throw const FormatException(
          'Health snapshot file is missing or damaged',
        );
      }
      files.add(XiaomiActivityRawFile(id: file.id, data: data));
    }
    return XiaomiHealthRawSnapshot(
      id: summary.id,
      deviceId: summary.deviceId,
      deviceCode: summary.deviceCode,
      capturedAt: summary.capturedAt,
      files: files,
    );
  }

  Future<void> _commit(
    AppDataDirectory storage,
    List<HealthSnapshotSummary> summaries,
  ) async {
    await storage.write(
      'index.json',
      Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'version': 1,
            'snapshots': summaries.map((item) => item.toJson()).toList(),
          }),
        ),
      ),
    );
    final keep = {
      'index.json',
      for (final item in summaries)
        for (final file in item.files) file.path,
    };
    for (final file in await storage.files()) {
      if (!keep.contains(file.path)) await storage.remove(file.path);
    }
  }
}

String _rawPath(String deviceId, String fileId, String digest) =>
    '${sha256.convert(utf8.encode(deviceId))}/'
    '${sha256.convert(utf8.encode(fileId))}/$digest.bin';

Uint8List _encodeArchive(XiaomiHealthRawSnapshot snapshot) =>
    snapshot.encodeArchive();
XiaomiHealthRawSnapshot _decodeArchive(Uint8List bytes) =>
    XiaomiHealthRawSnapshot.decodeArchive(bytes);

class SnapshotArchiveTooLarge implements Exception {
  const SnapshotArchiveTooLarge();
}

Uint8List _encodeCollection(List<XiaomiHealthRawSnapshot> snapshots) {
  final archive = Archive();
  final entries = <Map<String, Object?>>[];
  for (var i = 0; i < snapshots.length; i++) {
    final snapshot = snapshots[i];
    final files = <Map<String, Object?>>[];
    for (var j = 0; j < snapshot.files.length; j++) {
      final file = snapshot.files[j];
      final path = 'snapshots/$i/files/$j.bin';
      archive.addFile(ArchiveFile(path, file.data.length, file.data));
      files.add({
        'id': file.id,
        'path': path,
        'bytes': file.data.length,
        'sha256': sha256.convert(file.data).toString(),
      });
    }
    entries.add({
      'id': snapshot.id,
      'deviceId': snapshot.deviceId,
      'deviceCode': snapshot.deviceCode,
      'capturedAt': snapshot.capturedAt.toIso8601String(),
      'files': files,
    });
  }
  final manifest = utf8.encode(
    jsonEncode({
      'format': 'oronbox-health-snapshots',
      'version': 1,
      'snapshots': entries,
    }),
  );
  archive.addFile(ArchiveFile('manifest.json', manifest.length, manifest));
  return Uint8List.fromList(ZipEncoder().encode(archive));
}
