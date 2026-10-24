import 'package:oronbox/src/core/logging/logging_service.dart';
import 'package:oronbox/src/device/xiaomi/systems/health_system.dart';
import 'package:oronbox/src/features/devices/health/health_models.dart';
import 'package:oronbox/src/features/devices/health/health_store.dart';
import 'package:oronbox/src/features/devices/health/health_debug_snapshot_store.dart';

/// Xiaomi health synchronizer based on Xiaomi's activity-file protocol.
///
/// Activity files are the source for Xiaomi health history.
class XiaomiHealthSyncService {
  factory XiaomiHealthSyncService({
    required XiaomiHealthSystem system,
    required String deviceId,
    String? deviceCode,
    HealthStore? store,
    HealthDebugSnapshotStore? snapshotStore,
  }) => XiaomiHealthSyncService._(
    system: system,
    deviceId: deviceId,
    deviceCode: deviceCode,
    store: store,
    snapshotStore: snapshotStore,
  );

  XiaomiHealthSyncService._({
    required this._system,
    required this._deviceId,
    required this._deviceCode,
    HealthStore? store,
    HealthDebugSnapshotStore? snapshotStore,
  }) : _store = store ?? HealthStore(),
       _snapshotStore = snapshotStore ?? HealthDebugSnapshotStore(),
       _log = getLogger('XiaomiHealthSyncService');

  final XiaomiHealthSystem _system;
  final String _deviceId;
  final String? _deviceCode;
  final HealthStore _store;
  final HealthDebugSnapshotStore _snapshotStore;
  final Logger _log;

  Future<XiaomiHealthData> read() => _store.read(_deviceId);

  Future<XiaomiHealthSyncResult> sync() async {
    _log.info('Xiaomi health synchronization started for $_deviceId');
    await _store.resetForStorageMigration();
    final results = await Future.wait<Object?>([
      _store.read(_deviceId),
      _system.syncActivityFiles(),
    ]);
    final previous = results[0] as XiaomiHealthData;
    final files = results[1] as XiaomiActivityFileSyncResult;
    _log.info(
      'Xiaomi health activity files received for $_deviceId: '
      'files=${files.filesReceived}, skipped=${files.filesSkipped}, '
      'failed=${files.failedFiles.length}',
    );
    if (files.rawFiles.isNotEmpty) {
      try {
        await _snapshotStore.add(
          deviceId: _deviceId,
          deviceCode: _deviceCode,
          files: files.rawFiles,
        );
      } catch (error, stackTrace) {
        _log.warning(
          'Xiaomi health activity files could not be archived for $_deviceId',
          error,
          stackTrace,
        );
      }
    }

    final mapped = _mapFiles(files, previous: previous);
    final daily = mapped.daily;
    final samples = mapped.samples;
    final activitySamples = mapped.activitySamples;
    final sleep = mapped.sleep;
    final workouts = mapped.workouts;
    final abnormalHealthRecords = mapped.abnormalHealthRecords;

    if (files.filesReceived == 0 &&
        daily.isEmpty &&
        samples.isEmpty &&
        activitySamples.isEmpty &&
        sleep.isEmpty &&
        workouts.isEmpty &&
        abnormalHealthRecords.isEmpty) {
      final failed = files.failedFiles.length;
      throw StateError(
        failed == 0
            ? 'No Xiaomi health activity files returned'
            : 'No Xiaomi health activity files could be synchronized '
                  '($failed failed after retries)',
      );
    }

    final warning = files.failedFiles.isEmpty
        ? null
        : 'Xiaomi health sync completed with '
              '${files.failedFiles.length} failed activity file(s)';

    final data = mapped.data;
    final saved = await _store.write(_deviceId, data, flushImmediately: true);
    await _store.markStorageMigrationComplete();

    _log.info(
      'Xiaomi health synchronization saved for $_deviceId: '
      'files=${files.filesReceived}, daily=${daily.length}, '
      'samples=${samples.length}, activitySamples=${activitySamples.length}, '
      'sleep=${sleep.length}, '
      'workouts=${workouts.length}, abnormalHealth=${abnormalHealthRecords.length}, '
      'failed=${files.failedFiles.length}, '
      'skipped=${files.filesSkipped}',
    );
    return XiaomiHealthSyncResult(
      data: saved,
      updatedDaily: daily.isNotEmpty,
      updatedSamples: samples.isNotEmpty,
      updatedSleep: sleep.isNotEmpty,
      updatedWorkouts: workouts.isNotEmpty,
      warning: warning,
    );
  }

  /// Replays captured activity files over the stored health data. Fresh
  /// records replace matching keys while records outside this snapshot remain
  /// available. No request is sent to the wearable.
  Future<XiaomiHealthData> replayFromRawFiles(
    Iterable<XiaomiActivityRawFile> rawFiles,
  ) async {
    final files = _system.parseActivityFilesForDebug(rawFiles);
    final mapped = _mapFiles(files, previous: await _store.read(_deviceId));
    if (mapped.daily.isEmpty &&
        mapped.samples.isEmpty &&
        mapped.activitySamples.isEmpty &&
        mapped.sleep.isEmpty &&
        mapped.workouts.isEmpty &&
        mapped.abnormalHealthRecords.isEmpty) {
      throw StateError('No Xiaomi health data could be parsed from snapshot');
    }
    await _store.write(_deviceId, mapped.data);
    return _store.read(_deviceId);
  }

  _MappedXiaomiHealthData _mapFiles(
    XiaomiActivityFileSyncResult files, {
    required XiaomiHealthData previous,
  }) {
    final daily = files.daily.map(_daily).toList(growable: false);
    final samples = files.samples.expand(_samples).toList(growable: false);
    final activitySamples = files.samples
        .map(
          (value) => HealthActivitySample(
            timestamp: value.timestamp,
            activityType: value.activityType,
            activityStrength: value.activityStrength,
            sportType: value.sportType,
            steps: value.steps,
            activeCalories: value.activeCalories,
            distanceMeters: value.distanceMeters,
            heartRate: value.heartRate,
            energy: value.energy,
            caloriesDelta: value.caloriesDelta,
            energyStatus: value.energyStatus,
            energyStatusValue: value.energyStatusValue,
            bloodOxygen: value.bloodOxygen,
            pressure: value.pressure,
            lightSensation: value.lightSensation,
            volumeMomentum: value.volumeMomentum,
            floors: value.floors,
            stress: value.stress,
          ),
        )
        .toList(growable: false);
    final fileSleep = files.sleep
        .map(
          (value) => HealthSleepSummary(
            startedAt: value.startedAt,
            endedAt: value.endedAt,
            durationSeconds: value.durationSeconds,
            averageHeartRate: value.averageHeartRate,
            averageBloodOxygen: value.averageBloodOxygen,
            minimumHeartRate: value.minimumHeartRate,
            maximumHeartRate: value.maximumHeartRate,
            minimumBloodOxygen: value.minimumBloodOxygen,
            maximumBloodOxygen: value.maximumBloodOxygen,
            quality: value.quality,
            sleepEfficiency: value.sleepEfficiency,
            bedDurationSeconds: value.bedDurationSeconds,
            goBedAt: value.goBedAt,
            leaveBedAt: value.leaveBedAt,
            awakeDurationSeconds: value.awakeDurationSeconds,
            lightSleepDurationSeconds: value.lightSleepDurationSeconds,
            deepSleepDurationSeconds: value.deepSleepDurationSeconds,
            remSleepDurationSeconds: value.remSleepDurationSeconds,
            averageHrv: value.averageHrv,
            hrvMin: value.hrvMin,
            hrvMax: value.hrvMax,
            hrvBaselineMin: value.hrvBaselineMin,
            hrvBaselineMax: value.hrvBaselineMax,
            hrvStandardDeviation: value.hrvStandardDeviation,
            hrvMedian: value.hrvMedian,
            hrvLowerQuantile: value.hrvLowerQuantile,
            hrvMiddleQuantile: value.hrvMiddleQuantile,
            hrvUpperQuantile: value.hrvUpperQuantile,
            hrvTimestamp: value.hrvTimestamp,
            sleepIndex: value.sleepIndex,
            wakeCount: value.wakeCount,
            hasRem: value.hasRem,
            hasStage: value.hasStage,
            sleepScoreVersion: value.sleepScoreVersion,
            hrvPoints: value.hrvPoints
                .map(
                  (point) => HealthSleepHrvPoint(
                    timestamp: point.timestamp,
                    value: point.value,
                  ),
                )
                .toList(growable: false),
            heartRatePoints: value.heartRatePoints
                .map(
                  (point) => HealthSleepVitalPoint(
                    timestamp: point.timestamp,
                    value: point.value,
                  ),
                )
                .toList(growable: false),
            bloodOxygenPoints: value.bloodOxygenPoints
                .map(
                  (point) => HealthSleepVitalPoint(
                    timestamp: point.timestamp,
                    value: point.value,
                  ),
                )
                .toList(growable: false),
            stages: _stages(value),
          ),
        )
        .toList(growable: false);
    final sleep = fileSleep;
    final workouts = files.workouts
        .map(
          (value) => HealthWorkoutSummary(
            startedAt: value.startedAt,
            endedAt: value.endedAt,
            activityType: value.activityType,
            distanceMeters: value.distanceMeters,
            calories: value.calories,
            averageHeartRate: value.averageHeartRate,
            maximumHeartRate: value.maximumHeartRate,
            minimumHeartRate: value.minimumHeartRate,
            subSportType: value.subSportType,
            totalDurationSeconds: value.totalDurationSeconds,
            effectiveDurationSeconds: value.effectiveDurationSeconds,
            activeCalories: value.activeCalories,
            averagePaceSecondsPerKilometer:
                value.averagePaceSecondsPerKilometer,
            bestPaceSecondsPerKilometer: value.bestPaceSecondsPerKilometer,
            worstPaceSecondsPerKilometer: value.worstPaceSecondsPerKilometer,
            averageSpeedKph: value.averageSpeedKph,
            bestSpeedKph: value.bestSpeedKph,
            totalSteps: value.totalSteps,
            averageStrideCentimeters: value.averageStrideCentimeters,
            averageCadence: value.averageCadence,
            maximumCadence: value.maximumCadence,
            averageBloodOxygen: value.averageBloodOxygen,
            maximumBloodOxygen: value.maximumBloodOxygen,
            minimumBloodOxygen: value.minimumBloodOxygen,
            averageStress: value.averageStress,
            maximumStress: value.maximumStress,
            minimumStress: value.minimumStress,
            totalAscentMeters: value.totalAscentMeters,
            totalDescentMeters: value.totalDescentMeters,
            averageAltitudeMeters: value.averageAltitudeMeters,
            maximumAltitudeMeters: value.maximumAltitudeMeters,
            minimumAltitudeMeters: value.minimumAltitudeMeters,
            aerobicTrainingEffect: value.aerobicTrainingEffect,
            anaerobicTrainingEffect: value.anaerobicTrainingEffect,
            peakTrainingEffect: value.peakTrainingEffect,
            vo2Max: value.vo2Max,
            bodyEnergyConsumption: value.bodyEnergyConsumption,
            expectedRecoveryHours: value.expectedRecoveryHours,
            trainingLoad: value.trainingLoad,
            earnedVitality: value.earnedVitality,
            heartRateZoneMethod: value.heartRateZoneMethod,
            heartRateZones: value.heartRateZones
                .map(
                  (zone) => HealthWorkoutHeartRateZone(
                    zone: zone.zone,
                    durationSeconds: zone.durationSeconds,
                    lowerLimit: zone.lowerLimit,
                  ),
                )
                .toList(growable: false),
            averagePowerWatts: value.averagePowerWatts,
            maximumPowerWatts: value.maximumPowerWatts,
            totalArmPulls: value.totalArmPulls,
            mainSwimmingStroke: value.mainSwimmingStroke,
            averageStrokeFrequency: value.averageStrokeFrequency,
            maximumStrokeFrequency: value.maximumStrokeFrequency,
            turnCount: value.turnCount,
            averageSwolf: value.averageSwolf,
            bestSwolf: value.bestSwolf,
            poolWidthMeters: value.poolWidthMeters,
            totalJumps: value.totalJumps,
            averageJumpFrequency: value.averageJumpFrequency,
            bestJumpFrequency: value.bestJumpFrequency,
            tripCount: value.tripCount,
            setCount: value.setCount,
            totalStrokes: value.totalStrokes,
            averageRowingFrequency: value.averageRowingFrequency,
            bestRowingFrequency: value.bestRowingFrequency,
            samples: value.samples
                .map(
                  (sample) => HealthWorkoutSample(
                    timestamp: sample.timestamp,
                    heartRate: sample.heartRate,
                    bloodOxygen: sample.bloodOxygen,
                    stress: sample.stress,
                    calories: sample.calories,
                    steps: sample.steps,
                    distanceMeters: sample.distanceMeters,
                    altitudeMeters: sample.altitudeMeters,
                    paceSecondsPerKilometer: sample.paceSecondsPerKilometer,
                    speedKph: sample.speedKph,
                    cadence: sample.cadence,
                    powerWatts: sample.powerWatts,
                    strideCentimeters: sample.strideCentimeters,
                    jumpFrequency: sample.jumpFrequency,
                    jumpHeightCentimeters: sample.jumpHeightCentimeters,
                    strokeFrequency: sample.strokeFrequency,
                    swimmingStroke: sample.swimmingStroke,
                    swolf: sample.swolf,
                    swimmingPaceSecondsPer100Meters:
                        sample.swimmingPaceSecondsPer100Meters,
                  ),
                )
                .toList(growable: false),
            route: value.route
                .map(
                  (point) => HealthWorkoutRoutePoint(
                    timestamp: point.timestamp,
                    latitude: point.latitude,
                    longitude: point.longitude,
                    altitudeMeters: point.altitudeMeters,
                    speedMetersPerSecond: point.speedMetersPerSecond,
                    horizontalAccuracyMeters: point.horizontalAccuracyMeters,
                  ),
                )
                .toList(growable: false),
            recovery: value.recovery == null
                ? null
                : HealthWorkoutHeartRateRecovery(
                    startedAt: value.recovery!.startedAt,
                    recoveredHeartRate: value.recovery!.recoveredHeartRate,
                    recoveryRate: value.recovery!.recoveryRate,
                    heartRates: value.recovery!.heartRates,
                  ),
          ),
        )
        .toList(growable: false);
    final abnormalHealthRecords = files.abnormalHealthRecords
        .map(
          (value) => HealthAbnormalHealthRecord(
            timestamp: value.timestamp,
            value: value.value,
            kind: switch (value.kind) {
              XiaomiActivityAbnormalHealthKind.highHeartRate =>
                HealthAbnormalHealthKind.highHeartRate,
              XiaomiActivityAbnormalHealthKind.lowHeartRate =>
                HealthAbnormalHealthKind.lowHeartRate,
              XiaomiActivityAbnormalHealthKind.lowBloodOxygen =>
                HealthAbnormalHealthKind.lowBloodOxygen,
              XiaomiActivityAbnormalHealthKind.highStress =>
                HealthAbnormalHealthKind.highStress,
              XiaomiActivityAbnormalHealthKind.irregularHeartbeat =>
                HealthAbnormalHealthKind.irregularHeartbeat,
            },
            threshold: value.threshold,
            startedAt: value.startedAt,
            endedAt: value.endedAt,
          ),
        )
        .toList(growable: false);
    // Put this sync's records first. HealthStore de-duplicates equal keys
    // using first-wins semantics, so a replay can replace stale values.
    // If incoming sub-lists are empty, preserve the previous list reference
    // so HealthStore can recognize unchanged lists in O(1) and skip deduplication/sorting.
    final mergedDaily = daily.isEmpty
        ? previous.daily
        : [...daily, ...previous.daily];
    final mergedSamples = samples.isEmpty
        ? previous.samples
        : [...samples, ...previous.samples];
    final mergedActivitySamples = activitySamples.isEmpty
        ? previous.activitySamples
        : [...activitySamples, ...previous.activitySamples];
    final mergedSleep = sleep.isEmpty
        ? previous.sleep
        : [...sleep, ...previous.sleep];
    final mergedWorkouts = workouts.isEmpty
        ? previous.workouts
        : [...workouts, ...previous.workouts];
    final mergedAbnormalHealthRecords = abnormalHealthRecords.isEmpty
        ? previous.abnormalHealthRecords
        : [...abnormalHealthRecords, ...previous.abnormalHealthRecords];
    return _MappedXiaomiHealthData(
      daily: daily,
      samples: samples,
      activitySamples: activitySamples,
      sleep: sleep,
      workouts: workouts,
      abnormalHealthRecords: abnormalHealthRecords,
      data: XiaomiHealthData(
        daily: mergedDaily,
        samples: mergedSamples,
        activitySamples: mergedActivitySamples,
        sleep: mergedSleep,
        workouts: mergedWorkouts,
        abnormalHealthRecords: mergedAbnormalHealthRecords,
        // Recomputed from the retained window on every sync instead of OR-ed
        // with the previous flags: a sticky true would keep rendering an
        // empty card forever after the device stops producing that metric.
        capabilities: _capabilities(
          mergedDaily,
          mergedSamples,
          mergedSleep,
          mergedWorkouts,
          mergedAbnormalHealthRecords,
        ),
        lastSyncedAt: DateTime.now(),
      ),
    );
  }

  HealthDailySummary _daily(XiaomiActivityDailyRecord value) =>
      HealthDailySummary(
        date: _dateOnly(value.date),
        steps: value.steps,
        activeCalories: value.activeCalories,
        calories: value.calories,
        restingHeartRate: value.restingHeartRate,
        minHeartRate: value.minHeartRate,
        minHeartRateAt: value.minHeartRateAt,
        maxHeartRate: value.maxHeartRate,
        maxHeartRateAt: value.maxHeartRateAt,
        averageHeartRate: value.averageHeartRate,
        minStress: value.minStress,
        maxStress: value.maxStress,
        averageStress: value.averageStress,
        standingBitmap: value.standingBitmap,
        minBloodOxygen: value.minBloodOxygen,
        maxBloodOxygen: value.maxBloodOxygen,
        averageBloodOxygen: value.averageBloodOxygen,
        currentBloodOxygen: value.currentBloodOxygen,
        minBloodOxygenAt: value.minBloodOxygenAt,
        maxBloodOxygenAt: value.maxBloodOxygenAt,
        floorsClimbed: value.floorsClimbed,
        remainingRecoveryHours: value.remainingRecoveryHours,
        trainingLoadToday: value.trainingLoadToday,
        trainingLoadLast7Days: value.trainingLoadLast7Days,
        trainingLoadLevel: value.trainingLoadLevel,
        vitalityIncreaseLight: value.vitalityIncreaseLight,
        vitalityIncreaseModerate: value.vitalityIncreaseModerate,
        vitalityIncreaseHigh: value.vitalityIncreaseHigh,
        vitalityCurrent: value.vitalityCurrent,
        vitalityLast7Days: value.vitalityLast7Days,
        vitalityNextTargetType: value.vitalityNextTargetType,
        vitalityNextTargetMinutes: value.vitalityNextTargetMinutes,
        fitnessBalance: value.fitnessBalance,
        fitnessLevel: value.fitnessLevel,
        fatigueLevel: value.fatigueLevel,
        trainingStressScore: value.trainingStressScore,
      );

  Iterable<HealthSample> _samples(XiaomiActivitySampleRecord value) sync* {
    if (value.heartRate != null) {
      yield HealthSample(
        timestamp: value.timestamp,
        metric: XiaomiHealthMetric.heartRate,
        value: value.heartRate!.toDouble(),
      );
    }
    if (value.bloodOxygen != null) {
      yield HealthSample(
        timestamp: value.timestamp,
        metric: XiaomiHealthMetric.bloodOxygen,
        value: value.bloodOxygen!.toDouble(),
      );
    }
    if (value.stress != null) {
      yield HealthSample(
        timestamp: value.timestamp,
        metric: XiaomiHealthMetric.stress,
        value: value.stress!.toDouble(),
      );
    }
    if (value.steps != null) {
      yield HealthSample(
        timestamp: value.timestamp,
        metric: XiaomiHealthMetric.activity,
        value: value.steps!.toDouble(),
      );
    }
    if (value.activeCalories != null) {
      yield HealthSample(
        timestamp: value.timestamp,
        metric: XiaomiHealthMetric.activeCalories,
        value: value.activeCalories!.toDouble(),
      );
    }
  }

  XiaomiHealthCapabilities _capabilities(
    List<HealthDailySummary> daily,
    List<HealthSample> samples,
    List<HealthSleepSummary> sleep,
    List<HealthWorkoutSummary> workouts,
    List<HealthAbnormalHealthRecord> abnormalHealthRecords,
  ) {
    bool has(XiaomiHealthMetric metric) =>
        samples.any((value) => value.metric == metric);
    final latest = daily.isEmpty
        ? null
        : daily.reduce(
            (left, right) => left.date.isAfter(right.date) ? left : right,
          );
    return XiaomiHealthCapabilities(
      heartRate:
          has(XiaomiHealthMetric.heartRate) ||
          latest?.averageHeartRate != null ||
          latest?.restingHeartRate != null ||
          abnormalHealthRecords.any(
            (record) =>
                record.kind == HealthAbnormalHealthKind.highHeartRate ||
                record.kind == HealthAbnormalHealthKind.lowHeartRate ||
                record.kind == HealthAbnormalHealthKind.irregularHeartbeat,
          ),
      bloodOxygen:
          has(XiaomiHealthMetric.bloodOxygen) ||
          latest?.averageBloodOxygen != null ||
          abnormalHealthRecords.any(
            (record) => record.kind == HealthAbnormalHealthKind.lowBloodOxygen,
          ),
      stress:
          has(XiaomiHealthMetric.stress) ||
          latest?.averageStress != null ||
          abnormalHealthRecords.any(
            (record) => record.kind == HealthAbnormalHealthKind.highStress,
          ),
      vitality:
          has(XiaomiHealthMetric.vitality) ||
          daily.any(
            (value) =>
                value.vitalityCurrent != null ||
                value.vitalityLast7Days != null,
          ),
      sleep: sleep.isNotEmpty,
      workouts: workouts.isNotEmpty,
    );
  }

  DateTime _dateOnly(DateTime value) {
    final local = value.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  List<HealthSleepStageSegment> _stages(XiaomiActivitySleepRecord value) {
    final points = [...value.stages]
      ..sort((left, right) => left.timestamp.compareTo(right.timestamp));
    final result = <HealthSleepStageSegment>[];
    for (var index = 0; index < points.length; index++) {
      final point = points[index];
      final startedAt = point.timestamp.isBefore(value.startedAt)
          ? value.startedAt
          : point.timestamp;
      final next = index + 1 < points.length
          ? points[index + 1].timestamp
          : value.endedAt;
      final pointEnd = point.endedAt ?? next;
      final endedAt = pointEnd.isAfter(value.endedAt)
          ? value.endedAt
          : pointEnd;
      if (!endedAt.isAfter(startedAt)) continue;
      final kind = switch (point.stage) {
        2 => HealthSleepStageKind.deep,
        3 => HealthSleepStageKind.light,
        4 => HealthSleepStageKind.rem,
        5 => HealthSleepStageKind.awake,
        _ => HealthSleepStageKind.unknown,
      };
      if (kind == HealthSleepStageKind.unknown) continue;
      if (result.isNotEmpty &&
          result.last.kind == kind &&
          result.last.endedAt == startedAt) {
        final previous = result.removeLast();
        result.add(
          HealthSleepStageSegment(
            startedAt: previous.startedAt,
            endedAt: endedAt,
            kind: kind,
          ),
        );
      } else {
        result.add(
          HealthSleepStageSegment(
            startedAt: startedAt,
            endedAt: endedAt,
            kind: kind,
          ),
        );
      }
    }
    return result;
  }
}

class _MappedXiaomiHealthData {
  const _MappedXiaomiHealthData({
    required this.daily,
    required this.samples,
    required this.activitySamples,
    required this.sleep,
    required this.workouts,
    required this.abnormalHealthRecords,
    required this.data,
  });

  final List<HealthDailySummary> daily;
  final List<HealthSample> samples;
  final List<HealthActivitySample> activitySamples;
  final List<HealthSleepSummary> sleep;
  final List<HealthWorkoutSummary> workouts;
  final List<HealthAbnormalHealthRecord> abnormalHealthRecords;
  final XiaomiHealthData data;
}
