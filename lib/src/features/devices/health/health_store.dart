import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:oronbox/src/core/logging/logging_service.dart';
import 'package:oronbox/src/core/services/shared_prefs_service.dart';
import 'package:oronbox/src/features/devices/health/health_models.dart';

/// Local store for the rewritten Xiaomi health data model.
///
/// This intentionally uses a new key namespace. The previous health model is
/// not migrated: its entry is removed when this store is first opened for a
/// device.
class HealthStore {
  // v2 and v3 were written with activity timestamps shifted by the host
  // timezone. v4 stored the device's running 7-day total in the per-day
  // vitality field, and v5 may contain records written before Xiaomi raw
  // timestamps were corrected to device-local time. Drop older versions so a
  // corrected sync cannot be mixed with records carrying the old clock.
  static const _keyPrefix = 'health_data_v6_';
  static const _legacyKeyPrefixes = [
    'health_data_v1_',
    'health_data_v2_',
    'health_data_v3_',
    'health_data_v4_',
    'health_data_v5_',
  ];
  static const _maxDailyRecords = 90;
  static const _maxActivitySampleRecords = 30 * 24 * 60;
  static const _maxSleepRecords = 90;
  static const _maxWorkoutRecords = 90;
  static const _maxAbnormalHealthRecords = 90;

  static final _memoryCache = <String, XiaomiHealthData>{};
  static final _pendingPersist = <String, XiaomiHealthData>{};
  static final _activePersists = <String, Future<void>>{};
  static final _log = getLogger('HealthStore');

  static XiaomiHealthData? getCached(String deviceId) => _memoryCache[deviceId];

  @visibleForTesting
  static void clearCache() {
    _memoryCache.clear();
    _pendingPersist.clear();
    _activePersists.clear();
  }

  @visibleForTesting
  static Future<void> flush() async {
    final futures = _activePersists.values.toList();
    if (futures.isNotEmpty) {
      await Future.wait(futures);
    }
  }

  final _prefs = SharedPrefsService.instance;

  Future<XiaomiHealthData> read(String deviceId) async {
    final cached = _memoryCache[deviceId];
    if (cached != null) return cached;

    for (final prefix in _legacyKeyPrefixes) {
      final legacyKey = _keyFor(prefix, deviceId);
      if (_prefs.getString(legacyKey) != null) {
        await _prefs.remove(legacyKey);
      }
    }
    final value = _prefs.getString(_key(deviceId));
    if (value == null || value.isEmpty) return const XiaomiHealthData();
    try {
      final decoded = await compute(_decodeHealthData, value);
      _memoryCache[deviceId] = decoded;
      return decoded;
    } catch (_) {
      return const XiaomiHealthData();
    }
  }

  Future<XiaomiHealthData> write(
    String deviceId,
    XiaomiHealthData data, {
    bool flushImmediately = false,
  }) async {
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
        : ([..._deduplicateDaily(data.daily)]
            ..sort((a, b) => b.date.microsecondsSinceEpoch.compareTo(a.date.microsecondsSinceEpoch)))
            .take(_maxDailyRecords)
            .toList(growable: false);

    final samples = samplesUnchanged
        ? cached.samples
        : _capSamplesPerMetric(
            [..._deduplicateSamples(data.samples)]
              ..sort((a, b) => b.timestamp.microsecondsSinceEpoch.compareTo(a.timestamp.microsecondsSinceEpoch)),
          );

    final activitySamples = activityUnchanged
        ? cached.activitySamples
        : ([..._deduplicateActivitySamples(data.activitySamples)]
            ..sort((a, b) => b.timestamp.microsecondsSinceEpoch.compareTo(a.timestamp.microsecondsSinceEpoch)))
            .take(_maxActivitySampleRecords)
            .toList(growable: false);

    final sleep = sleepUnchanged
        ? cached.sleep
        : ([..._deduplicateSleep(data.sleep)]
            ..sort((a, b) {
              final endComparison = b.endedAt.microsecondsSinceEpoch.compareTo(a.endedAt.microsecondsSinceEpoch);
              if (endComparison != 0) return endComparison;
              return b.startedAt.microsecondsSinceEpoch.compareTo(a.startedAt.microsecondsSinceEpoch);
            }))
            .take(_maxSleepRecords)
            .toList(growable: false);

    final workouts = workoutsUnchanged
        ? cached.workouts
        : [
            for (final workout in ([..._deduplicateWorkouts(data.workouts)]
                  ..sort((a, b) => b.startedAt.microsecondsSinceEpoch.compareTo(a.startedAt.microsecondsSinceEpoch)))
                .take(_maxWorkoutRecords))
              _capWorkoutPoints(workout),
          ];

    final abnormalHealthRecords = abnormalUnchanged
        ? cached.abnormalHealthRecords
        : ([..._deduplicateAbnormalHealthRecords(data.abnormalHealthRecords)]
            ..sort((a, b) => b.timestamp.microsecondsSinceEpoch.compareTo(a.timestamp.microsecondsSinceEpoch)))
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
          final encoded = toSave.encode();
          final ok = await _prefs.setString(_key(deviceId), encoded);
          if (!ok) {
            _log.warning('Unable to persist health data for $deviceId');
          }
        } catch (error, stackTrace) {
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

  String _key(String deviceId) =>
      '$_keyPrefix${sha1.convert(utf8.encode(deviceId)).toString()}';

  String _keyFor(String prefix, String deviceId) =>
      '$prefix${sha1.convert(utf8.encode(deviceId)).toString()}';

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
      final key = (value.metric.index << 48) |
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
      final key = (value.activityType << 48) |
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

XiaomiHealthData _decodeHealthData(String value) =>
    XiaomiHealthData.decode(value);

// Retention budget per metric, not per row: each minute-level activity
// record fans out into up to five derived HealthSample rows (heart rate,
// blood oxygen, stress, steps, active calories), so a single global row
// cap would silently truncate the 30-day window to under a week.
const _healthSampleRecordsPerMetric = 30 * 24 * 60;
// Per-point lists inside a workout (1 Hz samples and GPS route) can reach
// tens of thousands of entries; keep them bounded so the single encoded
// blob stays a size SharedPreferences can write without jank.
const _healthWorkoutPointRecords = 2000;

/// Bumped after every successful [HealthStore.write] so open health pages
/// can refresh when a sync (manual, scheduled, or command-bus driven)
/// persists new data while they are mounted.
final healthDataRevision = ValueNotifier<int>(0);

/// Keeps the newest [_healthSampleRecordsPerMetric] rows for every metric
/// independently. [sortedDesc] must be newest-first, per-metric truncation
/// then always drops the oldest rows.
List<HealthSample> _capSamplesPerMetric(List<HealthSample> sortedDesc) {
  final remaining = <XiaomiHealthMetric, int>{};
  final result = <HealthSample>[];
  for (final sample in sortedDesc) {
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

/// Bounds the per-second sample/route lists of one workout with stride
/// downsampling that always preserves the first and last point. Rebuilds
/// through the JSON round-trip so the constructor list does not need a
/// 70-parameter copyWith.
HealthWorkoutSummary _capWorkoutPoints(HealthWorkoutSummary workout) {
  if (workout.samples.length <= _healthWorkoutPointRecords &&
      workout.route.length <= _healthWorkoutPointRecords) {
    return workout;
  }
  final json = workout.toJson();
  json['samples'] = _downsamplePoints(workout.samples)
      .map((HealthWorkoutSample value) => value.toJson())
      .toList();
  json['route'] = _downsamplePoints(workout.route)
      .map((HealthWorkoutRoutePoint value) => value.toJson())
      .toList();
  return HealthWorkoutSummary.fromJson(json);
}

List<T> _downsamplePoints<T>(List<T> points) {
  if (points.length <= _healthWorkoutPointRecords) return points;
  final step = points.length / _healthWorkoutPointRecords;
  final result = <T>[];
  for (var position = 0.0; position < points.length - 1; position += step) {
    result.add(points[position.floor()]);
  }
  result.add(points.last);
  return result;
}
