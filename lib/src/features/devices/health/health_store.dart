import 'dart:async';
import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:oronbox/src/core/services/shared_prefs_service.dart';
import 'package:oronbox/src/core/storage/app_data_directory.dart';
import 'package:oronbox/src/core/storage/data_archive.dart';
import 'package:oronbox/src/device/xiaomi/systems/health_system.dart';
import 'package:oronbox/src/features/devices/health/health_models.dart';
import 'package:oronbox/src/features/devices/health/xiaomi_health_sync_service.dart';
import 'package:uuid/uuid.dart';

/// Single activity file entry recorded in the health store.
class HealthActivityFile {
  const HealthActivityFile({
    required this.id,
    required this.path,
    required this.bytes,
    required this.digest,
  });

  final String id;
  final String path;
  final int bytes;
  final String digest;

  /// Extracts the capture timestamp from the 14-hex-character activity file ID.
  /// Xiaomi file IDs store a 32-bit little-endian Unix timestamp in bytes 0..3.
  DateTime? get timestamp {
    if (id.length < 8) return null;
    try {
      final data = Uint8List(4);
      for (var i = 0; i < 4; i++) {
        data[i] = int.parse(id.substring(i * 2, i * 2 + 2), radix: 16);
      }
      final seconds = ByteData.sublistView(data).getInt32(0, Endian.little);
      return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
    } catch (_) {
      return null;
    }
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'path': path,
    'bytes': bytes,
    'sha256': digest,
  };

  factory HealthActivityFile.fromJson(Map<String, Object?> json) =>
      HealthActivityFile(
        id: json['id'] as String,
        path: json['path'] as String,
        bytes: json['bytes'] as int,
        digest: json['sha256'] as String,
      );
}

/// Metadata batch for a set of synchronized activity files.
class HealthActivityBatch {
  const HealthActivityBatch({
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
  final List<HealthActivityFile> files;

  int get totalBytes => files.fold(0, (total, file) => total + file.bytes);

  Map<String, Object?> toJson() => {
    'id': id,
    'deviceId': deviceId,
    'deviceCode': deviceCode,
    'capturedAt': capturedAt.toIso8601String(),
    'files': files.map((file) => file.toJson()).toList(),
  };

  factory HealthActivityBatch.fromJson(Map<String, Object?> json) =>
      HealthActivityBatch(
        id: json['id'] as String,
        deviceId: json['deviceId'] as String,
        deviceCode: json['deviceCode'] as String?,
        capturedAt: DateTime.parse(json['capturedAt'] as String),
        files: (json['files'] as List)
            .map(
              (file) => HealthActivityFile.fromJson(
                (file as Map).cast<String, Object?>(),
              ),
            )
            .toList(growable: false),
      );
}

/// Backward compatibility aliases.
typedef HealthSnapshotFile = HealthActivityFile;
typedef HealthSnapshotSummary = HealthActivityBatch;

class SnapshotArchiveTooLarge implements Exception {
  const SnapshotArchiveTooLarge();
}

/// Incremental persistence for health summaries and activity files.
class HealthStore {
  static final _persisted = <String, XiaomiHealthData>{};
  static final _persistErrors = <String, Object>{};
  static bool _maintenance = false;

  static String? _maintenanceOwner;
  static bool _externallyPaused = false;
  static bool get maintenanceRequested =>
      _maintenance || _maintenanceOwner != null;

  static Future<void> pauseForOwner(
    String owner,
    Future<void> Function() drain,
  ) async {
    if (_maintenanceOwner != null) {
      if (!_externallyPaused) {
        throw StateError('Health data maintenance is active');
      }
      _maintenanceOwner = owner;
      return;
    }
    _maintenanceOwner = owner;
    try {
      await drain();
      _externallyPaused = true;
    } catch (_) {
      _maintenanceOwner = null;
      rethrow;
    }
  }

  static void resumeForOwner(String owner) {
    if (_maintenanceOwner != owner) return;
    if (_externallyPaused) {
      clearCache();
      healthDataRevision.value++;
    }
    _externallyPaused = false;
    _maintenanceOwner = null;
  }

  static Future<T> maintenance<T>(Future<T> Function() action) async {
    if (_maintenance) throw StateError('Health data maintenance is active');
    _maintenance = true;
    try {
      return await action();
    } finally {
      _maintenance = false;
    }
  }

  static const _keyPrefix = 'health_data_v6_';
  static const _migrationKey =
      'migration.health_storage.v7_drop_legacy_files_once';
  static const _maxDailyRecords = 90;
  static const _maxActivitySampleRecords = 30 * 24 * 12;
  static const _maxSleepRecords = 90;
  static const _maxWorkoutRecords = 90;
  static const _maxAbnormalHealthRecords = 90;

  static final _memoryCache = <String, XiaomiHealthData>{};
  static final _decodedThrough = <String, DateTime>{};

  static XiaomiHealthData? getCached(String deviceId) => _memoryCache[deviceId];

  static void clearCache() {
    _memoryCache.clear();
    _decodedThrough.clear();
    _persisted.clear();
    _persistErrors.clear();
  }

  final _prefs = SharedPrefsService.instance;

  static Future<void> deleteLegacyDatabaseFiles() async {
    final dir =
        activityStorageForTesting ?? await openAppDataDirectory('health');
    final allFiles = await dir.files(includeTemporary: true);
    for (final f in allFiles) {
      if (f.path.contains('health.sqlite') ||
          f.path.contains('.db') ||
          f.path.contains('drift')) {
        await dir.remove(f.path);
      }
    }
  }

  Future<void> resetForStorageMigration() async {
    if (!_prefs.isInitialized || (_prefs.getBool(_migrationKey) ?? false)) {
      return;
    }
    await deleteLegacyDatabaseFiles();

    for (final key
        in _prefs.keys
            .where(
              (key) =>
                  key.startsWith(_keyPrefix) ||
                  key.startsWith('health_data_v1_') ||
                  key.startsWith('health_data_v2_') ||
                  key.startsWith('health_data_v3_') ||
                  key.startsWith('health_data_v4_') ||
                  key.startsWith('health_data_v5_') ||
                  key == 'xiaomi_health_debug_snapshots_v1',
            )
            .toList()) {
      await _prefs.remove(key);
    }
    await _prefs.remove('xiaomi.health.debug_mode');
    await _prefs.setBool(_migrationKey, true);
    clearCache();
  }

  Future<void> markStorageMigrationComplete() async {
    if (!_prefs.isInitialized) return;
    await _prefs.setBool(_migrationKey, true);
  }

  Future<XiaomiHealthData> query(
    String deviceId, {
    required DateTime start,
    required DateTime end,
    List<String>? kinds,
    int? limit,
    int offset = 0,
    XiaomiHealthData? seed,
  }) async {
    if (seed != null) {
      return _filterCached(
        seed,
        start: start,
        end: end,
        kinds: kinds,
        limit: limit,
        offset: offset,
      );
    }

    final cached = _memoryCache[deviceId] ?? _persisted[deviceId];
    final coverage = _decodedThrough[deviceId];
    if (cached != null && coverage != null && !start.isBefore(coverage)) {
      return _filterCached(
        cached,
        start: start,
        end: end,
        kinds: kinds,
        limit: limit,
        offset: offset,
      );
    }

    if (cached != null) {
      final decoded = await _decodeRecentActivities(deviceId, since: start);
      final normalized = await write(
        deviceId,
        _mergeHealthData(cached, decoded),
      );
      _decodedThrough[deviceId] = coverage == null || start.isBefore(coverage)
          ? start
          : coverage;
      return _filterCached(
        normalized,
        start: start,
        end: end,
        kinds: kinds,
        limit: limit,
        offset: offset,
      );
    }

    // Lazy backward streaming decoding of activity files from disk
    final decoded = await _decodeRecentActivities(deviceId, since: start);
    final normalized = await write(deviceId, decoded);
    _decodedThrough[deviceId] = start;
    return _filterCached(
      normalized,
      start: start,
      end: end,
      kinds: kinds,
      limit: limit,
      offset: offset,
    );
  }

  XiaomiHealthData _filterCached(
    XiaomiHealthData data, {
    required DateTime start,
    required DateTime end,
    List<String>? kinds,
    int? limit,
    required int offset,
  }) {
    final include = kinds?.toSet();
    bool selected(String kind) => include == null || include.contains(kind);
    bool point(DateTime value) => !value.isBefore(start) && value.isBefore(end);
    bool overlap(DateTime from, DateTime? until) =>
        from.isBefore(end) && !(until ?? from).isBefore(start);

    var workouts = selected('workouts')
        ? data.workouts
              .where((item) => overlap(item.startedAt, item.endedAt))
              .toList(growable: false)
        : const <HealthWorkoutSummary>[];
    if (limit != null) {
      workouts = workouts.skip(offset).take(limit).toList(growable: false);
    }
    return XiaomiHealthData(
      daily: selected('daily')
          ? data.daily.where((item) => point(item.date)).toList(growable: false)
          : const [],
      samples: selected('samples')
          ? data.samples
                .where((item) => point(item.timestamp))
                .toList(growable: false)
          : const [],
      activitySamples: selected('activitySamples')
          ? data.activitySamples
                .where((item) => point(item.timestamp))
                .toList(growable: false)
          : const [],
      sleep: selected('sleep')
          ? data.sleep
                .where((item) => overlap(item.startedAt, item.endedAt))
                .toList(growable: false)
          : const [],
      workouts: workouts,
      abnormalHealthRecords: selected('abnormalHealthRecords')
          ? data.abnormalHealthRecords
                .where((item) => overlap(item.timestamp, item.endedAt))
                .toList(growable: false)
          : const [],
      capabilities: data.capabilities,
      lastSyncedAt: data.lastSyncedAt,
    );
  }

  Future<XiaomiHealthData> overview(String deviceId) async {
    final now = DateTime.now();
    final recent = await query(
      deviceId,
      start: DateTime(now.year, now.month, now.day - 7),
      end: DateTime(now.year, now.month, now.day + 1),
    );
    if (recent.workouts.isNotEmpty) return recent;
    final latest = await _decodeLatestWorkout(deviceId);
    if (latest == null) return recent;
    return write(deviceId, _mergeHealthData(recent, latest));
  }

  Future<HealthWorkoutTotals> workoutTotals(
    String deviceId,
    DateTime start,
    DateTime end,
  ) async {
    await query(deviceId, start: start, end: end, kinds: const ['workouts']);
    final cached = _memoryCache[deviceId];
    if (cached != null) {
      final inRange = cached.workouts.where(
        (w) => w.startedAt.isBefore(end) && w.endedAt.isAfter(start),
      );
      var duration = 0;
      var distance = 0;
      var calories = 0;
      var hrSum = 0;
      var hrCount = 0;
      for (final w in inRange) {
        duration += w.totalDurationSeconds ?? 0;
        distance += w.distanceMeters ?? 0;
        calories += w.calories ?? 0;
        if (w.averageHeartRate != null && w.averageHeartRate! > 0) {
          hrSum += w.averageHeartRate!;
          hrCount++;
        }
      }
      return HealthWorkoutTotals(
        durationSeconds: duration,
        distanceMeters: distance == 0 ? null : distance,
        calories: calories == 0 ? null : calories,
        averageHeartRate: hrCount == 0 ? null : (hrSum / hrCount).round(),
      );
    }
    return const HealthWorkoutTotals();
  }

  static XiaomiHealthData _mergeHealthData(
    XiaomiHealthData left,
    XiaomiHealthData right,
  ) => XiaomiHealthData(
    daily: [...left.daily, ...right.daily],
    samples: [...left.samples, ...right.samples],
    activitySamples: [...left.activitySamples, ...right.activitySamples],
    sleep: [...left.sleep, ...right.sleep],
    workouts: [...left.workouts, ...right.workouts],
    abnormalHealthRecords: [
      ...left.abnormalHealthRecords,
      ...right.abnormalHealthRecords,
    ],
    capabilities: XiaomiHealthCapabilities(
      heartRate: left.capabilities.heartRate || right.capabilities.heartRate,
      bloodOxygen:
          left.capabilities.bloodOxygen || right.capabilities.bloodOxygen,
      stress: left.capabilities.stress || right.capabilities.stress,
      vitality: left.capabilities.vitality || right.capabilities.vitality,
      sleep: left.capabilities.sleep || right.capabilities.sleep,
      workouts: left.capabilities.workouts || right.capabilities.workouts,
    ),
    lastSyncedAt: left.lastSyncedAt ?? right.lastSyncedAt,
  );

  Future<HealthWorkoutSummary?> workout(String deviceId, String routeId) async {
    var cached = _memoryCache[deviceId];
    if (cached == null) {
      await read(deviceId);
      cached = _memoryCache[deviceId];
    }
    if (cached != null) {
      final split = routeId.lastIndexOf('-');
      if (split >= 0) {
        final timestamp = int.tryParse(routeId.substring(0, split));
        final type = int.tryParse(routeId.substring(split + 1));
        if (timestamp != null && type != null) {
          for (final w in cached.workouts) {
            if (w.startedAt.millisecondsSinceEpoch == timestamp &&
                w.activityType == type) {
              return w;
            }
          }
        }
      }
    }
    return null;
  }

  Future<XiaomiHealthData> read(String deviceId) async {
    final cached = _memoryCache[deviceId];
    if (cached != null) return cached;
    final now = DateTime.now();
    final decoded = await query(
      deviceId,
      start: DateTime(now.year, now.month, now.day - 30),
      end: DateTime(now.year, now.month, now.day + 1),
    );
    _memoryCache[deviceId] = decoded;
    return decoded;
  }

  Future<XiaomiHealthData> write(
    String deviceId,
    XiaomiHealthData data, {
    bool flushImmediately = false,
  }) async {
    if (_maintenance || _externallyPaused) {
      throw StateError('Health data maintenance is active');
    }
    final cached = _memoryCache[deviceId];

    final bool samplesUnchanged =
        cached != null && identical(data.samples, cached.samples);
    final bool activityUnchanged =
        cached != null &&
        identical(data.activitySamples, cached.activitySamples);
    final bool dailyUnchanged =
        cached != null && identical(data.daily, cached.daily);
    final bool sleepUnchanged =
        cached != null && identical(data.sleep, cached.sleep);
    final bool workoutsUnchanged =
        cached != null && identical(data.workouts, cached.workouts);
    final bool abnormalUnchanged =
        cached != null &&
        identical(data.abnormalHealthRecords, cached.abnormalHealthRecords);

    if (samplesUnchanged &&
        activityUnchanged &&
        dailyUnchanged &&
        sleepUnchanged &&
        workoutsUnchanged &&
        abnormalUnchanged &&
        cached.capabilities == data.capabilities &&
        cached.lastSyncedAt == data.lastSyncedAt) {
      return cached;
    }

    final daily = dailyUnchanged
        ? cached.daily
        : ([..._deduplicateDaily(data.daily)]..sort(
                (a, b) => b.date.microsecondsSinceEpoch.compareTo(
                  a.date.microsecondsSinceEpoch,
                ),
              ))
              .take(_maxDailyRecords)
              .toList(growable: false);

    final samples = samplesUnchanged
        ? cached.samples
        : _capSamplesPerMetric(
            [..._deduplicateSamples(data.samples)]..sort(
              (a, b) => b.timestamp.microsecondsSinceEpoch.compareTo(
                a.timestamp.microsecondsSinceEpoch,
              ),
            ),
          );

    final activitySamples = activityUnchanged
        ? cached.activitySamples
        : _compactActivitySamples(data.activitySamples);

    final sleep = sleepUnchanged
        ? cached.sleep
        : ([..._deduplicateSleep(data.sleep)]..sort((a, b) {
                final endComparison = b.endedAt.microsecondsSinceEpoch
                    .compareTo(a.endedAt.microsecondsSinceEpoch);
                if (endComparison != 0) return endComparison;
                return b.startedAt.microsecondsSinceEpoch.compareTo(
                  a.startedAt.microsecondsSinceEpoch,
                );
              }))
              .take(_maxSleepRecords)
              .toList(growable: false);

    final workouts = workoutsUnchanged
        ? cached.workouts
        : [
            for (final workout
                in ([..._deduplicateWorkouts(data.workouts)]..sort(
                      (a, b) => b.startedAt.microsecondsSinceEpoch.compareTo(
                        a.startedAt.microsecondsSinceEpoch,
                      ),
                    ))
                    .take(_maxWorkoutRecords))
              workout,
          ];

    final abnormalHealthRecords = abnormalUnchanged
        ? cached.abnormalHealthRecords
        : ([..._deduplicateAbnormalHealthRecords(data.abnormalHealthRecords)]
                ..sort(
                  (a, b) => b.timestamp.microsecondsSinceEpoch.compareTo(
                    a.timestamp.microsecondsSinceEpoch,
                  ),
                ))
              .take(_maxAbnormalHealthRecords)
              .toList(growable: false);

    final normalized = XiaomiHealthData(
      daily: daily,
      samples: samples,
      activitySamples: activitySamples,
      sleep: sleep,
      workouts: workouts,
      abnormalHealthRecords: abnormalHealthRecords,
      capabilities: data.capabilities,
      lastSyncedAt: data.lastSyncedAt,
    );
    _memoryCache[deviceId] = normalized;
    _persisted[deviceId] = normalized;
    healthDataRevision.value++;

    return normalized;
  }

  // --- Activity File Storage & Flat Path Management ---

  static String _normalizeDeviceId(String deviceId) {
    final clean = deviceId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
    return clean.isEmpty ? 'default' : clean.toLowerCase();
  }

  static String _activityFilePath(String deviceId, String fileId) =>
      '${_normalizeDeviceId(deviceId)}/$fileId.bin';

  @visibleForTesting
  static AppDataDirectory? activityStorageForTesting;

  static Future<AppDataDirectory> _openActivityStorage() async =>
      activityStorageForTesting ?? await openAppDataDirectory('health/raw');

  static Future<List<HealthActivityBatch>> _loadActivityIndex(
    AppDataDirectory storage,
  ) async {
    final bytes = await storage.read('index.json');
    if (bytes == null) return [];
    final decoded = jsonDecode(utf8.decode(bytes)) as Map;
    if (decoded['version'] != 1) {
      throw const FormatException('Unknown activity index format');
    }
    final rawBatches =
        decoded['snapshots'] as List? ?? decoded['batches'] as List? ?? [];
    final result = rawBatches
        .map(
          (item) => HealthActivityBatch.fromJson(
            (item as Map).cast<String, Object?>(),
          ),
        )
        .toList();

    var migrated = false;
    final batches = <HealthActivityBatch>[];
    for (final batch in result) {
      final updatedFiles = <HealthActivityFile>[];
      for (final file in batch.files) {
        final flatPath = _activityFilePath(batch.deviceId, file.id);
        if (file.path != flatPath) {
          final oldData = await storage.read(file.path);
          if (oldData != null &&
              sha256.convert(oldData).toString() == file.digest) {
            await storage.write(flatPath, oldData);
            await storage.remove(file.path);
            updatedFiles.add(
              HealthActivityFile(
                id: file.id,
                path: flatPath,
                bytes: file.bytes,
                digest: file.digest,
              ),
            );
            migrated = true;
            continue;
          }
        }
        updatedFiles.add(file);
      }
      batches.add(
        HealthActivityBatch(
          id: batch.id,
          deviceId: batch.deviceId,
          deviceCode: batch.deviceCode,
          capturedAt: batch.capturedAt,
          files: updatedFiles,
        ),
      );
    }

    if (migrated) {
      await _commitActivityIndex(storage, batches);
    }
    return batches..sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
  }

  static Future<void> _commitActivityIndex(
    AppDataDirectory storage,
    List<HealthActivityBatch> batches,
  ) async {
    await storage.write(
      'index.json',
      Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'version': 1,
            'snapshots': batches.map((item) => item.toJson()).toList(),
          }),
        ),
      ),
    );
    final keep = {
      'index.json',
      for (final b in batches)
        for (final f in b.files) f.path,
    };
    for (final file in await storage.files()) {
      if (!keep.contains(file.path)) await storage.remove(file.path);
    }
  }

  /// Persists synchronized activity files to flat storage without truncation.
  Future<void> saveActivityFiles({
    required String deviceId,
    String? deviceCode,
    required List<XiaomiActivityRawFile> files,
  }) async {
    if (files.isEmpty) return;
    final storage = await _openActivityStorage();
    await storage.exclusive(() async {
      final fileEntries = <HealthActivityFile>[];
      for (final file in files) {
        final digest = sha256.convert(file.data).toString();
        final path = _activityFilePath(deviceId, file.id);
        final existing = await storage.read(path);
        if (existing == null || sha256.convert(existing).toString() != digest) {
          await storage.write(path, file.data);
        }
        fileEntries.add(
          HealthActivityFile(
            id: file.id,
            path: path,
            bytes: file.data.length,
            digest: digest,
          ),
        );
      }
      final previous = await _loadActivityIndex(storage);
      final batch = HealthActivityBatch(
        id: const Uuid().v4(),
        deviceId: deviceId,
        deviceCode: deviceCode,
        capturedAt: DateTime.now(),
        files: fileEntries,
      );
      final next = [batch, ...previous.where((item) => item.id != batch.id)];
      await _commitActivityIndex(storage, next);
    });
  }

  /// Streams and lazily parses activity files backwards until [since] is met.
  Future<XiaomiHealthData> _decodeRecentActivities(
    String deviceId, {
    required DateTime since,
  }) async {
    final rawFiles = await _readActivityFiles(deviceId, since: since);
    if (rawFiles.isEmpty) return const XiaomiHealthData();
    return _parseRawFilesToHealthData(rawFiles);
  }

  Future<XiaomiHealthData?> _decodeLatestWorkout(String deviceId) async {
    final rawFiles = await _readActivityFiles(deviceId);
    for (final rawFile in rawFiles) {
      final decoded = _parseRawFilesToHealthData([rawFile]);
      if (decoded.workouts.isNotEmpty) return decoded;
    }
    return null;
  }

  Future<List<XiaomiActivityRawFile>> _readActivityFiles(
    String deviceId, {
    DateTime? since,
  }) async {
    final storage = await _openActivityStorage();
    return storage.exclusive(() async {
      final batches = await _loadActivityIndex(storage);
      final uniqueFiles = <String, HealthActivityFile>{};
      for (final batch in batches.where((b) => b.deviceId == deviceId)) {
        for (final file in batch.files) {
          uniqueFiles.putIfAbsent(file.id, () => file);
        }
      }
      final sorted = uniqueFiles.values.toList()
        ..sort((a, b) {
          final left = a.timestamp?.millisecondsSinceEpoch ?? 0;
          final right = b.timestamp?.millisecondsSinceEpoch ?? 0;
          return right.compareTo(left);
        });
      final safeBoundary = since?.subtract(const Duration(days: 1));
      final rawFiles = <XiaomiActivityRawFile>[];
      for (final entry in sorted) {
        final timestamp = entry.timestamp;
        if (safeBoundary != null &&
            timestamp != null &&
            timestamp.isBefore(safeBoundary)) {
          break;
        }
        final bytes = await storage.read(entry.path);
        if (bytes != null && bytes.length == entry.bytes) {
          rawFiles.add(XiaomiActivityRawFile(id: entry.id, data: bytes));
        }
      }
      return rawFiles;
    });
  }

  /// Pure in-memory activity file parsing and model construction.
  static XiaomiHealthData _parseRawFilesToHealthData(
    Iterable<XiaomiActivityRawFile> files,
  ) {
    final parsedResult = XiaomiHealthSystem().parseActivityFilesForDebug(files);
    return XiaomiHealthSyncService.mapActivityFiles(parsedResult);
  }

  // --- External Activity Export & Maintenance API ---

  static Future<List<HealthActivityBatch>> listActivityBatches() async {
    final storage = await _openActivityStorage();
    return storage.exclusive(() => _loadActivityIndex(storage));
  }

  static Future<int> activityStoredBytes() async {
    final storage = await _openActivityStorage();
    return storage.exclusive(() async {
      final files = await storage.files();
      return files.fold<int>(0, (sum, f) => sum + f.bytes);
    });
  }

  static Future<void> clearActivityFiles() async {
    final storage = await _openActivityStorage();
    await storage.exclusive(() => _commitActivityIndex(storage, const []));
  }

  static Future<void> deleteActivityBatch(String id) async {
    final storage = await _openActivityStorage();
    await storage.exclusive(() async {
      final current = await _loadActivityIndex(storage);
      final next = current.where((item) => item.id != id).toList();
      await _commitActivityIndex(storage, next);
    });
  }

  static Future<HealthActivityBatch> importActivityBatch(
    Uint8List bytes,
  ) async {
    final archive = readDataArchive(
      bytes,
      maxBytes: 128 * 1024 * 1024,
      maxFiles: 4096,
    );
    final filesByDevice = <String, List<XiaomiActivityRawFile>>{};
    String? deviceId;
    String? deviceCode;
    for (final entry in archive.entries) {
      if (entry.key == 'manifest.json') {
        try {
          final decoded = jsonDecode(utf8.decode(entry.value)) as Map;
          deviceId = decoded['deviceId']?.toString();
          deviceCode = decoded['deviceCode']?.toString();
        } catch (_) {}
        continue;
      }
      if (entry.key.endsWith('.bin')) {
        final parts = entry.key.split('/');
        final id = parts.last.substring(0, parts.last.length - 4);
        final target =
            deviceId ??
            (parts.length >= 2 ? parts[parts.length - 2] : 'imported');
        filesByDevice
            .putIfAbsent(target, () => [])
            .add(XiaomiActivityRawFile(id: id, data: entry.value));
      }
    }
    for (final entry in filesByDevice.entries) {
      await HealthStore().saveActivityFiles(
        deviceId: entry.key,
        deviceCode: deviceCode,
        files: entry.value,
      );
    }
    final targetDevice =
        deviceId ?? filesByDevice.keys.firstOrNull ?? 'imported';
    final batches = await listActivityBatches();
    return batches.firstWhere(
      (b) => b.deviceId == targetDevice,
      orElse: () => HealthActivityBatch(
        id: const Uuid().v4(),
        deviceId: targetDevice,
        deviceCode: deviceCode,
        capturedAt: DateTime.now(),
        files: const [],
      ),
    );
  }

  static Future<Uint8List> exportActivityBatch(String id) async {
    final storage = await _openActivityStorage();
    return storage.exclusive(() async {
      final current = await _loadActivityIndex(storage);
      final batch = current.where((item) => item.id == id).firstOrNull;
      if (batch == null) throw StateError('Activity batch no longer exists');
      final archive = Archive();
      archive.addFile(
        ArchiveFile.string(
          'manifest.json',
          jsonEncode({
            'version': 1,
            'deviceId': batch.deviceId,
            'deviceCode': batch.deviceCode,
          }),
        ),
      );
      for (final file in batch.files) {
        final data = await storage.read(file.path);
        if (data != null) {
          archive.addFile(ArchiveFile('${file.id}.bin', data.length, data));
        }
      }
      return Uint8List.fromList(ZipEncoder().encode(archive));
    });
  }

  static Future<Uint8List> exportAllActivityBatches() async {
    final storage = await _openActivityStorage();
    return storage.exclusive(() async {
      final batches = await _loadActivityIndex(storage);
      final archive = Archive();
      final seen = <String>{};
      for (final batch in batches) {
        for (final file in batch.files) {
          if (!seen.add(file.path)) continue;
          final data = await storage.read(file.path);
          if (data != null) {
            archive.addFile(ArchiveFile(file.path, data.length, data));
          }
        }
      }
      return Uint8List.fromList(ZipEncoder().encode(archive));
    });
  }

  static Future<Map<String, Uint8List>> exportActivityFiles() async {
    final storage = await _openActivityStorage();
    return storage.exclusive(() async {
      final batches = await _loadActivityIndex(storage);
      final files = <String, Uint8List>{};
      final seen = <String>{};
      for (final batch in batches) {
        for (final file in batch.files) {
          if (!seen.add(file.path)) continue;
          final data = await storage.read(file.path);
          if (data != null) {
            files[file.path] = data;
          }
        }
      }
      return files;
    });
  }

  static Future<Uint8List> exportActivityIndex() async {
    final storage = await _openActivityStorage();
    return storage.exclusive(() async {
      return await storage.read('index.json') ??
          Uint8List.fromList(
            utf8.encode(jsonEncode({'version': 1, 'snapshots': const []})),
          );
    });
  }

  static Future<void> restoreActivityFiles(Map<String, Uint8List> files) async {
    if (files.isEmpty) return;
    final indexEntry = files.entries.where(
      (entry) => entry.key == 'index.json' || entry.key.endsWith('/index.json'),
    );
    if (indexEntry.isNotEmpty) {
      await _restoreActivityArchive(indexEntry.first.value, files);
      clearCache();
      healthDataRevision.value++;
      return;
    }
    final byDevice = <String, List<XiaomiActivityRawFile>>{};
    for (final entry in files.entries) {
      final parts = entry.key.split('/');
      final fileName = parts.last;
      if (!fileName.endsWith('.bin')) continue;
      final fileId = fileName.substring(0, fileName.length - 4);
      final device = parts.length >= 2 ? parts[parts.length - 2] : 'imported';
      byDevice
          .putIfAbsent(device, () => [])
          .add(XiaomiActivityRawFile(id: fileId, data: entry.value));
    }
    for (final entry in byDevice.entries) {
      await HealthStore().saveActivityFiles(
        deviceId: entry.key,
        files: entry.value,
      );
    }
    clearCache();
    healthDataRevision.value++;
  }

  static Future<void> _restoreActivityArchive(
    Uint8List indexBytes,
    Map<String, Uint8List> files,
  ) async {
    final decoded = jsonDecode(utf8.decode(indexBytes)) as Map;
    if (decoded['version'] != 1) {
      throw const FormatException('Unknown activity index format');
    }
    final rawFiles = <String, Uint8List>{};
    for (final entry in files.entries) {
      final path = entry.key.replaceFirst(RegExp(r'^(health/raw/|raw/)'), '');
      if (path == 'index.json' || !path.endsWith('.bin')) continue;
      rawFiles[path] = entry.value;
    }
    final rawBatches =
        decoded['snapshots'] as List? ?? decoded['batches'] as List? ?? [];
    final referenced = <String>{};
    for (final item in rawBatches) {
      final batch = (item as Map).cast<String, Object?>();
      for (final file in (batch['files'] as List? ?? const [])) {
        final descriptor = file as Map;
        final path = (descriptor['path'] ?? '').toString();
        final data = rawFiles[path];
        if (data == null) {
          throw const FormatException('Activity index references missing file');
        }
        if (data.length != descriptor['bytes'] ||
            sha256.convert(data).toString() != descriptor['sha256']) {
          throw const FormatException('Activity file checksum mismatch');
        }
        referenced.add(path);
      }
    }
    if (referenced.length != rawFiles.length) {
      throw const FormatException('Activity archive contains unindexed files');
    }

    final storage = await _openActivityStorage();
    await storage.exclusive(() async {
      final previousIndex = await storage.read('index.json');
      final previousFiles = <String, Uint8List>{};
      for (final file in await storage.files()) {
        if (file.path == 'index.json') continue;
        final data = await storage.read(file.path);
        if (data != null) previousFiles[file.path] = data;
      }
      try {
        for (final entry in rawFiles.entries) {
          await storage.write(entry.key, entry.value);
        }
        await storage.write('index.json', indexBytes);
        final keep = {'index.json', ...rawFiles.keys};
        for (final file in await storage.files()) {
          if (!keep.contains(file.path)) await storage.remove(file.path);
        }
      } catch (_) {
        for (final file in await storage.files()) {
          await storage.remove(file.path);
        }
        for (final entry in previousFiles.entries) {
          await storage.write(entry.key, entry.value);
        }
        if (previousIndex != null) {
          await storage.write('index.json', previousIndex);
        }
        rethrow;
      }
    });
  }

  List<HealthDailySummary> _deduplicateDaily(List<HealthDailySummary> values) {
    final result = <int, HealthDailySummary>{};
    for (final value in values) {
      result[_dateKey(value.date)] ??= value;
    }
    return result.values.toList(growable: false);
  }

  List<HealthSample> _deduplicateSamples(List<HealthSample> values) {
    final result = <int, HealthSample>{};
    for (final value in values) {
      final key =
          (value.metric.index << 48) |
          (value.timestamp.millisecondsSinceEpoch & 0xffffffffffff);
      result[key] ??= value;
    }
    return result.values.toList(growable: false);
  }

  List<HealthActivitySample> _deduplicateActivitySamples(
    List<HealthActivitySample> values,
  ) {
    final result = <int, HealthActivitySample>{};
    for (final value in values) {
      final key = value.timestamp.millisecondsSinceEpoch;
      final existing = result[key];
      result[key] = existing == null
          ? value
          : HealthActivitySample(
              timestamp: value.timestamp,
              activityType: value.activityType ?? existing.activityType,
              activityStrength:
                  value.activityStrength ?? existing.activityStrength,
              sportType: value.sportType ?? existing.sportType,
              steps: value.steps ?? existing.steps,
              activeCalories: value.activeCalories ?? existing.activeCalories,
              distanceMeters: value.distanceMeters ?? existing.distanceMeters,
              heartRate: value.heartRate ?? existing.heartRate,
              energy: value.energy ?? existing.energy,
              caloriesDelta: value.caloriesDelta ?? existing.caloriesDelta,
              energyStatus: value.energyStatus ?? existing.energyStatus,
              energyStatusValue:
                  value.energyStatusValue ?? existing.energyStatusValue,
              bloodOxygen: value.bloodOxygen ?? existing.bloodOxygen,
              pressure: value.pressure ?? existing.pressure,
              lightSensation: value.lightSensation ?? existing.lightSensation,
              volumeMomentum: value.volumeMomentum ?? existing.volumeMomentum,
              floors: value.floors ?? existing.floors,
              stress: value.stress ?? existing.stress,
            );
    }
    return result.values.toList(growable: false);
  }

  List<HealthSleepSummary> _deduplicateSleep(List<HealthSleepSummary> values) {
    final result = <String, HealthSleepSummary>{};
    for (final value in values) {
      final key = [
        value.sourceSubtype ?? 8,
        value.sleepIndex ?? 0,
        value.startedAt.toUtc().millisecondsSinceEpoch ~/ 1000,
      ].join(':');
      final existing = result[key];
      if (existing == null ||
          value.endedAt.isAfter(existing.endedAt) ||
          (value.endedAt == existing.endedAt &&
              value.stages.length > existing.stages.length)) {
        result[key] = value;
      }
    }
    return result.values.toList(growable: false);
  }

  List<HealthWorkoutSummary> _deduplicateWorkouts(
    List<HealthWorkoutSummary> values,
  ) {
    final result = <int, HealthWorkoutSummary>{};
    for (final value in values) {
      final key =
          (value.activityType << 48) |
          (value.startedAt.millisecondsSinceEpoch & 0xffffffffffff);
      final existing = result[key];
      if (existing == null ||
          _workoutRichness(value) > _workoutRichness(existing)) {
        result[key] = value;
      }
    }
    return result.values.toList(growable: false);
  }

  int _workoutRichness(HealthWorkoutSummary value) {
    final summaries = <Object?>[
      value.distanceMeters,
      value.calories,
      value.averageHeartRate,
      value.totalDurationSeconds,
      value.averagePaceSecondsPerKilometer,
      value.averageSpeedKph,
      value.averageCadence,
      value.aerobicTrainingEffect,
      value.trainingLoad,
      value.averageSwolf,
      value.totalJumps,
      value.totalStrokes,
    ].whereType<Object>().length;
    return summaries * 2 +
        value.samples.length +
        value.route.length +
        value.heartRateZones.length +
        (value.recovery == null ? 0 : 4);
  }

  List<HealthAbnormalHealthRecord> _deduplicateAbnormalHealthRecords(
    List<HealthAbnormalHealthRecord> values,
  ) {
    final result = <String, HealthAbnormalHealthRecord>{};
    for (final value in values) {
      final key = [
        value.kind.name,
        value.timestamp.toIso8601String(),
        value.startedAt?.toIso8601String() ?? '',
        value.endedAt?.toIso8601String() ?? '',
      ].join('|');
      result[key] ??= value;
    }
    return result.values.toList(growable: false);
  }

  int _dateKey(DateTime value) {
    final local = value.toLocal();
    return local.year * 10000 + local.month * 100 + local.day;
  }
}

const _healthSampleRecordsPerMetric = 30 * 24 * 12;
const _healthRawSampleWindow = Duration(days: 7);
const _healthSampleBucket = Duration(minutes: 5);

final healthDataRevision = ValueNotifier<int>(0);

List<HealthSample> _capSamplesPerMetric(List<HealthSample> sortedDesc) {
  final newest = sortedDesc.isEmpty ? null : sortedDesc.first.timestamp;
  final remaining = <XiaomiHealthMetric, int>{};
  final buckets = <(XiaomiHealthMetric, int)>{};
  final result = <HealthSample>[];
  for (final sample in sortedDesc) {
    if (newest != null &&
        newest.difference(sample.timestamp) > _healthRawSampleWindow) {
      final bucket =
          sample.timestamp.millisecondsSinceEpoch ~/
          _healthSampleBucket.inMilliseconds;
      if (!buckets.add((sample.metric, bucket))) continue;
    }
    final budget = remaining.update(
      sample.metric,
      (value) => value - 1,
      ifAbsent: () => _healthSampleRecordsPerMetric,
    );
    if (budget <= 0) continue;
    result.add(sample);
  }
  return result;
}

List<HealthActivitySample> _compactActivitySamples(
  List<HealthActivitySample> values,
) {
  final sorted = [...HealthStore()._deduplicateActivitySamples(values)]
    ..sort(
      (a, b) => b.timestamp.microsecondsSinceEpoch.compareTo(
        a.timestamp.microsecondsSinceEpoch,
      ),
    );
  final newest = sorted.isEmpty ? null : sorted.first.timestamp;
  final buckets = <int>{};
  final result = <HealthActivitySample>[];
  for (final sample in sorted) {
    if (newest != null &&
        newest.difference(sample.timestamp) > _healthRawSampleWindow) {
      final bucket =
          sample.timestamp.millisecondsSinceEpoch ~/
          _healthSampleBucket.inMilliseconds;
      if (!buckets.add(bucket)) continue;
    }
    result.add(sample);
    if (result.length >= HealthStore._maxActivitySampleRecords) break;
  }
  return result;
}
