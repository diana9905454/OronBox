import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:oronbox/src/core/logging/logging_service.dart';
import 'package:oronbox/src/core/services/shared_prefs_service.dart';
import 'package:oronbox/src/core/storage/app_data_directory.dart';
import 'package:oronbox/src/features/devices/health/health_models.dart';

import 'health_database.dart';

/// Incremental persistence for health summaries and indexed records.
class HealthStore {
  @visibleForTesting
  static HealthDatabase? databaseForTesting;
  HealthDatabase get _database => databaseForTesting ?? healthDatabase;
  static final _persisted = <String, XiaomiHealthData>{};
  static final _persistErrors = <String, Object>{};
  static bool _maintenance = false;
  static DateTime? _lastCompaction;

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
      await flush();
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
      await flush();
      return await action();
    } finally {
      _maintenance = false;
    }
  }

  // Health data is rebuilt from the device after the storage reset marker is
  // introduced. The database remains the only runtime source of persisted data.
  static const _keyPrefix = 'health_data_v6_';
  static const _migrationKey = 'migration.health_storage.v3_drop_legacy';
  static const _maxDailyRecords = 90;
  static const _maxActivitySampleRecords = 30 * 24 * 12;
  static const _maxSleepRecords = 90;
  static const _maxWorkoutRecords = 90;
  static const _maxAbnormalHealthRecords = 90;

  static final _memoryCache = <String, XiaomiHealthData>{};
  static final _pendingPersist = <String, XiaomiHealthData>{};
  static final _activePersists = <String, Future<void>>{};
  static final _log = getLogger('HealthStore');

  static XiaomiHealthData? getCached(String deviceId) => _memoryCache[deviceId];

  static void clearCache() {
    _memoryCache.clear();
    _persisted.clear();
    _persistErrors.clear();
    _pendingPersist.clear();
    _activePersists.clear();
  }

  static Future<void> flush() async {
    final futures = _activePersists.values.toList();
    if (futures.isNotEmpty) {
      await Future.wait(futures);
    }
    if (_persistErrors.isNotEmpty) throw _persistErrors.values.first;
  }

  final _prefs = SharedPrefsService.instance;

  Future<void> resetForStorageMigration() async {
    if (!_prefs.isInitialized || (_prefs.getBool(_migrationKey) ?? false)) {
      return;
    }
    final inFlight = _activePersists.values.toList();
    if (inFlight.isNotEmpty) {
      try {
        await Future.wait(inFlight);
      } catch (_) {
        // The reset intentionally discards failed legacy writes as well.
      }
    }
    await _database.clearAll();
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
    for (final path in ['health/raw', 'diagnostics/health']) {
      final directory = await openAppDataDirectory(path);
      await directory.exclusive(() async {
        for (final file in await directory.files(includeTemporary: true)) {
          await directory.remove(file.path);
        }
      });
    }
    await _prefs.remove('xiaomi.health.debug_mode');
    clearCache();
    await _database.compact();
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
    final cached = seed ?? _memoryCache[deviceId] ?? _persisted[deviceId];
    if (cached != null) {
      return _filterCached(
        cached,
        start: start,
        end: end,
        kinds: kinds,
        limit: limit,
        offset: offset,
      );
    }
    return _database.readRange(
      _key(deviceId).substring(_keyPrefix.length),
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

  Future<XiaomiHealthData> overview(String deviceId) {
    final now = DateTime.now();
    return query(
      deviceId,
      start: DateTime(now.year, now.month, now.day - 7),
      end: DateTime(now.year, now.month, now.day + 1),
    );
  }

  Future<HealthWorkoutTotals> workoutTotals(
    String deviceId,
    DateTime start,
    DateTime end,
  ) async {
    return _database.workoutTotals(
      _key(deviceId).substring(_keyPrefix.length),
      start,
      end,
    );
  }

  Future<HealthWorkoutSummary?> workout(String deviceId, String routeId) async {
    return _database.readWorkout(
      _key(deviceId).substring(_keyPrefix.length),
      routeId,
    );
  }

  Future<XiaomiHealthData> read(String deviceId) async {
    final cached = _memoryCache[deviceId];
    if (cached != null) return cached;
    final databaseKey = _key(deviceId).substring(_keyPrefix.length);
    var data = await _database.readDevice(databaseKey);
    final result = data ?? const XiaomiHealthData();
    _memoryCache[deviceId] = result;
    _persisted[deviceId] = result;
    return result;
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

    // If absolutely nothing changed, no-op immediately
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
    healthDataRevision.value++;

    final persistFuture = _schedulePersist(deviceId, normalized);
    if (flushImmediately) {
      await persistFuture;
      if (_persistErrors.containsKey(deviceId)) throw _persistErrors[deviceId]!;
    } else {
      unawaited(persistFuture);
    }
    return normalized;
  }

  Future<void> _schedulePersist(String deviceId, XiaomiHealthData data) {
    _pendingPersist[deviceId] = data;
    if (_activePersists.containsKey(deviceId)) {
      return _activePersists[deviceId]!;
    }
    final future = _runPersistLoop(deviceId);
    _activePersists[deviceId] = future;
    return future;
  }

  Future<void> _runPersistLoop(String deviceId) async {
    try {
      while (_pendingPersist.containsKey(deviceId)) {
        final toSave = _pendingPersist.remove(deviceId)!;
        try {
          final key = _key(deviceId).substring(_keyPrefix.length);
          final previous =
              _persisted[deviceId] ?? await _database.readDevice(key);
          await _database.writeDevice(key, toSave, previous: previous);
          _persisted[deviceId] = toSave;
          _persistErrors.remove(deviceId);
          unawaited(_compactIfNeeded());
        } catch (error, stackTrace) {
          _persistErrors[deviceId] = error;
          _log.warning(
            'Failed to persist health data for $deviceId',
            error,
            stackTrace,
          );
        }
      }
    } finally {
      _activePersists.remove(deviceId);
    }
  }

  Future<void> _compactIfNeeded() async {
    final now = DateTime.now();
    if (_lastCompaction != null &&
        now.difference(_lastCompaction!) < const Duration(hours: 24)) {
      return;
    }
    if (await _database.storedBytes() <= 100 * 1024 * 1024) return;
    _lastCompaction = now;
    await _database.compact();
  }

  String _key(String deviceId) =>
      '$_keyPrefix${sha1.convert(utf8.encode(deviceId)).toString()}';

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

  /// Activity records are composite minute samples. A repeated sync may
  /// contain the same timestamp from a daily-detail file and a later parser
  /// replay may fill in fields that were absent in the first pass. Merge the
  /// newest record field-by-field instead of dropping the richer record or
  /// summing a cumulative value twice.
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
    final result = <int, HealthSleepSummary>{};
    for (final value in values) {
      // Gadgetbridge keys Xiaomi sleep summaries by the exact bedtime. During
      // a night the watch may send that same bedtime repeatedly with
      // progressively later wake times; the later record replaces the
      // earlier one. Do not merge nearby bedtimes or contained intervals:
      // those can be legitimate separate sleep segments.
      final key = value.startedAt.millisecondsSinceEpoch;
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

// Retention budget per metric, not per row: each minute-level activity
// record fans out into up to five derived HealthSample rows (heart rate,
// blood oxygen, stress, steps, active calories), so a single global row
// cap would silently truncate the 30-day window to under a week.
const _healthSampleRecordsPerMetric = 30 * 24 * 12;
const _healthRawSampleWindow = Duration(days: 7);
const _healthSampleBucket = Duration(minutes: 5);

/// Bumped after every successful [HealthStore.write] so open health pages
/// can refresh when a sync (manual, scheduled, or command-bus driven)
/// persists new data while they are mounted.
final healthDataRevision = ValueNotifier<int>(0);

/// Keeps the newest [_healthSampleRecordsPerMetric] rows for every metric
/// independently. [sortedDesc] must be newest-first, per-metric truncation
/// then always drops the oldest rows.
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
