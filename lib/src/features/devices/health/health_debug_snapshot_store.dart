import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:oronbox/src/core/services/shared_prefs_service.dart';
import 'package:oronbox/src/device/xiaomi/systems/health_system.dart';

/// A raw Xiaomi activity-file capture from one health synchronization.
///
/// The capture is deliberately kept before model conversion. This makes a
/// parser fix testable against a real wearable response without asking for a
/// new workout or health measurement.
class XiaomiHealthRawSnapshot {
  const XiaomiHealthRawSnapshot({
    required this.id,
    required this.deviceId,
    this.deviceCode,
    required this.capturedAt,
    required this.files,
  });

  final String id;
  final String deviceId;
  final String? deviceCode;
  final DateTime capturedAt;
  final List<XiaomiActivityRawFile> files;

  Map<String, Object?> toJson() => {
    'id': id,
    'deviceId': deviceId,
    if (deviceCode != null && deviceCode!.isNotEmpty) 'deviceCode': deviceCode,
    'capturedAt': capturedAt.toIso8601String(),
    'files': files
        .map((file) => {'id': file.id, 'data': base64Encode(file.data)})
        .toList(growable: false),
  };

  /// A stable, human-readable file name for the exported capture, e.g.
  /// `xiaomi-health-<code>-20260919-170800.zip`.
  String get exportFileName {
    final local = capturedAt.toLocal();
    final timestamp =
        '${local.year.toString().padLeft(4, '0')}'
        '${local.month.toString().padLeft(2, '0')}'
        '${local.day.toString().padLeft(2, '0')}-'
        '${local.hour.toString().padLeft(2, '0')}'
        '${local.minute.toString().padLeft(2, '0')}'
        '${local.second.toString().padLeft(2, '0')}';
    final code = deviceCode?.trim();
    final suffix = code == null || code.isEmpty ? '' : '-$code';
    return 'xiaomi-health$suffix-$timestamp.zip';
  }

  /// Packs every raw activity file plus a manifest into a zip so the exact
  /// bytes that produced a parser bug can be shared and replayed.
  Uint8List encodeArchive() {
    final archive = Archive();
    for (final file in files) {
      archive.addFile(
        ArchiveFile('${file.id}.bin', file.data.length, file.data),
      );
    }
    final manifest = utf8.encode(
      const JsonEncoder.withIndent('  ').convert({
        'id': id,
        'deviceId': deviceId,
        if (deviceCode != null && deviceCode!.isNotEmpty)
          'deviceCode': deviceCode,
        'capturedAt': capturedAt.toIso8601String(),
        'files': files
            .map(
              (file) => {
                'name': '${file.id}.bin',
                'id': file.id,
                'bytes': file.data.length,
              },
            )
            .toList(growable: false),
      }),
    );
    archive.addFile(ArchiveFile('manifest.json', manifest.length, manifest));
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  /// Reads a zip produced by [encodeArchive] back into a snapshot.
  ///
  /// The manifest carries the original id / device id / capture time; the
  /// `.bin` entries carry the raw activity files. An archive without a manifest
  /// is still accepted: the id and capture time are derived from the zip itself
  /// so an imported capture always lands in the snapshot list.
  factory XiaomiHealthRawSnapshot.decodeArchive(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    Map<String, Object?>? manifest;
    final files = <XiaomiActivityRawFile>[];
    for (final entry in archive) {
      if (!entry.isFile) continue;
      final name = entry.name;
      final data = entry.content;
      if (name == 'manifest.json') {
        try {
          final decoded = jsonDecode(utf8.decode(data));
          if (decoded is Map) manifest = decoded.cast<String, Object?>();
        } catch (_) {
          manifest = null;
        }
        continue;
      }
      if (name.endsWith('.bin')) {
        files.add(
          XiaomiActivityRawFile(
            id: name.substring(0, name.length - 4),
            data: data,
          ),
        );
      }
    }
    if (files.isEmpty) {
      throw const FormatException('Archive contains no activity files');
    }
    final capturedAt =
        _tryParseDate(manifest?['capturedAt']?.toString()) ?? DateTime.now();
    return XiaomiHealthRawSnapshot(
      id: manifest?['id']?.toString() ?? _archiveId(capturedAt),
      deviceId: manifest?['deviceId']?.toString() ?? 'imported',
      deviceCode: manifest?['deviceCode']?.toString(),
      capturedAt: capturedAt,
      files: List.unmodifiable(files),
    );
  }

  factory XiaomiHealthRawSnapshot.fromJson(Map<String, Object?> json) {
    final rawFiles = json['files'];
    if (rawFiles is! List) {
      throw const FormatException('Invalid Xiaomi health snapshot files');
    }
    return XiaomiHealthRawSnapshot(
      id: json['id']!.toString(),
      deviceId: json['deviceId']!.toString(),
      deviceCode: json['deviceCode']?.toString(),
      capturedAt: DateTime.parse(json['capturedAt']!.toString()),
      files: rawFiles
          .whereType<Map>()
          .map(
            (file) => XiaomiActivityRawFile(
              id: file['id'].toString(),
              data: base64Decode(file['data'].toString()),
            ),
          )
          .toList(growable: false),
    );
  }
}

class HealthDebugSnapshotStore {
  static const _key = 'xiaomi_health_debug_snapshots_v1';
  static const _maxSnapshots = 20;

  final SharedPrefsService _prefs;

  HealthDebugSnapshotStore({SharedPrefsService? prefs})
    : _prefs = prefs ?? SharedPrefsService.instance;

  Future<List<XiaomiHealthRawSnapshot>> read() async {
    if (!_prefs.isInitialized) return const [];
    final value = _prefs.getString(_key);
    if (value == null || value.isEmpty) return const [];
    try {
      final decoded = jsonDecode(value);
      if (decoded is! List) return const [];
      final snapshots = decoded
          .whereType<Map>()
          .map(
            (item) =>
                XiaomiHealthRawSnapshot.fromJson(item.cast<String, Object?>()),
          )
          .toList();
      snapshots.sort(
        (left, right) => right.capturedAt.compareTo(left.capturedAt),
      );
      return snapshots;
    } catch (_) {
      return const [];
    }
  }

  Future<void> add({
    required String deviceId,
    String? deviceCode,
    required List<XiaomiActivityRawFile> files,
  }) async {
    if (!_prefs.isInitialized || files.isEmpty) return;
    final snapshots = List<XiaomiHealthRawSnapshot>.of(await read());
    final id = '${DateTime.now().microsecondsSinceEpoch}-$deviceId';
    snapshots.insert(
      0,
      XiaomiHealthRawSnapshot(
        id: id,
        deviceId: deviceId,
        deviceCode: deviceCode,
        capturedAt: DateTime.now(),
        files: List.unmodifiable(files),
      ),
    );
    await _write(snapshots.take(_maxSnapshots).toList(growable: false));
  }

  /// Imports a zip produced by [XiaomiHealthRawSnapshot.encodeArchive] and
  /// adds it to the stored snapshot list. Returns the imported snapshot.
  ///
  /// The manifest id is preserved when present; a duplicate id replaces the
  /// existing entry so re-importing the same archive stays idempotent.
  Future<XiaomiHealthRawSnapshot> import(Uint8List bytes) async {
    if (!_prefs.isInitialized) {
      throw StateError('Xiaomi health snapshots are not initialized');
    }
    final snapshot = XiaomiHealthRawSnapshot.decodeArchive(bytes);
    final snapshots = List<XiaomiHealthRawSnapshot>.of(await read())
      ..removeWhere((item) => item.id == snapshot.id)
      ..insert(0, snapshot);
    await _write(snapshots.take(_maxSnapshots).toList(growable: false));
    return snapshot;
  }

  Future<void> delete(String id) async {
    if (!_prefs.isInitialized) return;
    final snapshots = List<XiaomiHealthRawSnapshot>.of(await read())
      ..removeWhere((item) => item.id == id);
    await _write(snapshots);
  }

  Future<void> clear() async {
    if (!_prefs.isInitialized) return;
    await _prefs.remove(_key);
  }

  Future<void> _write(List<XiaomiHealthRawSnapshot> snapshots) async {
    final ok = await _prefs.setString(
      _key,
      jsonEncode(snapshots.map((item) => item.toJson()).toList()),
    );
    if (!ok) throw StateError('Unable to persist Xiaomi health snapshots');
  }
}

DateTime? _tryParseDate(String? value) {
  if (value == null || value.isEmpty) return null;
  return DateTime.tryParse(value);
}

String _archiveId(DateTime capturedAt) =>
    'imported-${capturedAt.microsecondsSinceEpoch}';
