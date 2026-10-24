import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
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
      if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(file.id)) {
        throw const FormatException('Invalid snapshot file id');
      }
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
    if (bytes.length > 128 * 1024 * 1024) {
      throw const FormatException('Snapshot archive is too large');
    }
    final directory = ZipDirectory()..read(InputMemoryStream(bytes));
    final names = <String>{};
    var declaredBytes = 0;
    for (final header in directory.fileHeaders) {
      final name = header.filename;
      declaredBytes += header.uncompressedSize;
      if (!names.add(name) ||
          name.contains('/') ||
          name.contains('\\') ||
          name.contains('..') ||
          ((header.externalFileAttributes >> 16) & 0xf000) == 0xa000 ||
          directory.fileHeaders.length > 512 ||
          declaredBytes > 128 * 1024 * 1024) {
        throw const FormatException('Invalid snapshot archive directory');
      }
    }
    final archive = ZipDecoder().decodeBytes(bytes);
    if (archive.length > 512 ||
        archive.files.fold<int>(0, (size, entry) => size + entry.size) >
            128 * 1024 * 1024) {
      throw const FormatException('Snapshot archive expands beyond its limit');
    }
    Map<String, Object?>? manifest;
    final files = <XiaomiActivityRawFile>[];
    for (final entry in archive) {
      if (!entry.isFile) continue;
      final name = entry.name;
      if (name.contains('/') || name.contains('\\') || name.contains('..')) {
        throw const FormatException('Invalid snapshot archive entry');
      }
      final data = entry.content;
      if (data.length != entry.size || getCrc32(data) != entry.crc32) {
        throw const FormatException('Snapshot archive checksum mismatch');
      }
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
        if (files.any((file) => '${file.id}.bin' == name)) {
          throw const FormatException('Duplicate snapshot file');
        }
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
    if (rawFiles is! List ||
        rawFiles.isEmpty ||
        json['id'] is! String ||
        json['deviceId'] is! String ||
        json['capturedAt'] is! String) {
      throw const FormatException('Invalid Xiaomi health snapshot');
    }
    final files = rawFiles
        .map((file) {
          if (file is! Map ||
              file['id'] is! String ||
              file['data'] is! String) {
            throw const FormatException('Invalid Xiaomi health snapshot file');
          }
          return XiaomiActivityRawFile(
            id: file['id'] as String,
            data: base64Decode(file['data'] as String),
          );
        })
        .toList(growable: false);
    return XiaomiHealthRawSnapshot(
      id: json['id'] as String,
      deviceId: json['deviceId'] as String,
      deviceCode: json['deviceCode'] as String?,
      capturedAt: DateTime.parse(json['capturedAt'] as String),
      files: files,
    );
  }
}

DateTime? _tryParseDate(String? value) =>
    value == null || value.isEmpty ? null : DateTime.tryParse(value);

String _archiveId(DateTime capturedAt) =>
    'imported-${capturedAt.microsecondsSinceEpoch}';

class HealthSnapshotFile {
  const HealthSnapshotFile({
    required this.id,
    required this.path,
    required this.bytes,
    required this.digest,
  });
  final String id;
  final String path;
  final int bytes;
  final String digest;
  Map<String, Object?> toJson() => {
    'id': id,
    'path': path,
    'bytes': bytes,
    'sha256': digest,
  };
  factory HealthSnapshotFile.fromJson(Map<String, Object?> json) =>
      HealthSnapshotFile(
        id: json['id'] as String,
        path: json['path'] as String,
        bytes: json['bytes'] as int,
        digest: json['sha256'] as String,
      );
}

class HealthSnapshotSummary {
  const HealthSnapshotSummary({
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
  final List<HealthSnapshotFile> files;
  int get totalBytes => files.fold(0, (total, file) => total + file.bytes);
  Map<String, Object?> toJson() => {
    'id': id,
    'deviceId': deviceId,
    'deviceCode': deviceCode,
    'capturedAt': capturedAt.toIso8601String(),
    'files': files.map((file) => file.toJson()).toList(),
  };
  factory HealthSnapshotSummary.fromJson(Map<String, Object?> json) =>
      HealthSnapshotSummary(
        id: json['id'] as String,
        deviceId: json['deviceId'] as String,
        deviceCode: json['deviceCode'] as String?,
        capturedAt: DateTime.parse(json['capturedAt'] as String),
        files: (json['files'] as List)
            .map(
              (file) => HealthSnapshotFile.fromJson(
                (file as Map).cast<String, Object?>(),
              ),
            )
            .toList(growable: false),
      );
}
