import 'dart:typed_data';


/// A single activity file that could not be completely synchronized.
///
/// A failed file must not discard the other files returned by the wearable.
/// The error is kept as text so callers can log or present it without making
/// the protocol exception types part of the health model API.
class XiaomiActivityFileFailure {
  const XiaomiActivityFileFailure({
    required this.id,
    required this.attempts,
    required this.error,
  });

  final String id;
  final int attempts;
  final String error;
}

/// A CRC-validated activity file returned by the wearable.
///
/// Keeping the file id together with the bytes makes diagnostics useful even
/// when the current parser does not recognize the file type yet.
class XiaomiActivityRawFile {
  const XiaomiActivityRawFile({required this.id, required this.data});

  final String id;
  final Uint8List data;
}

class XiaomiActivityFileSyncResult {
  const XiaomiActivityFileSyncResult({
    required this.daily,
    required this.samples,
    required this.sleep,
    required this.workouts,
    required this.filesReceived,
    this.abnormalHealthRecords = const [],
    this.rawFiles = const [],
    this.failedFiles = const [],
    this.filesSkipped = 0,
  });

  final List<XiaomiActivityDailyRecord> daily;
  final List<XiaomiActivitySampleRecord> samples;
  final List<XiaomiActivitySleepRecord> sleep;
  final List<XiaomiActivityWorkoutRecord> workouts;
  final List<XiaomiActivityAbnormalHealthRecord> abnormalHealthRecords;
  final List<XiaomiActivityRawFile> rawFiles;
  final int filesReceived;

  /// Files for which all transfer attempts or the final acknowledgement
  /// failed. Other files in the same sync are still usable.
  final List<XiaomiActivityFileFailure> failedFiles;

  /// Empty/placeholder files advertised by the device and intentionally
  /// ignored because they contain no health payload.
  final int filesSkipped;
}

class XiaomiActivityDailyRecord {
  const XiaomiActivityDailyRecord({
    required this.date,
    this.steps,
    this.activeCalories,
    this.calories,
    this.restingHeartRate,
    this.minHeartRate,
    this.minHeartRateAt,
    this.maxHeartRate,
    this.maxHeartRateAt,
    this.averageHeartRate,
    this.minStress,
    this.maxStress,
    this.averageStress,
    this.standingBitmap,
    this.minBloodOxygen,
    this.maxBloodOxygen,
    this.averageBloodOxygen,
    this.currentBloodOxygen,
    this.minBloodOxygenAt,
    this.maxBloodOxygenAt,
    this.floorsClimbed,
    this.remainingRecoveryHours,
    this.trainingLoadToday,
    this.trainingLoadLast7Days,
    this.trainingLoadLevel,
    this.vitalityIncreaseLight,
    this.vitalityIncreaseModerate,
    this.vitalityIncreaseHigh,
    this.vitalityCurrent,
    this.vitalityLast7Days,
    this.vitalityNextTargetType,
    this.vitalityNextTargetMinutes,
    this.fitnessBalance,
    this.fitnessLevel,
    this.fatigueLevel,
    this.trainingStressScore,
  });

  final DateTime date;
  final int? steps;
  final int? activeCalories;
  final int? calories;
  final int? restingHeartRate;
  final int? minHeartRate;
  final DateTime? minHeartRateAt;
  final int? maxHeartRate;
  final DateTime? maxHeartRateAt;
  final int? averageHeartRate;
  final int? minStress;
  final int? maxStress;
  final int? averageStress;
  final int? standingBitmap;
  final int? minBloodOxygen;
  final int? maxBloodOxygen;
  final int? averageBloodOxygen;
  final int? currentBloodOxygen;
  final DateTime? minBloodOxygenAt;
  final DateTime? maxBloodOxygenAt;
  final int? floorsClimbed;
  final int? remainingRecoveryHours;
  final int? trainingLoadToday;
  final int? trainingLoadLast7Days;
  final int? trainingLoadLevel;
  final int? vitalityIncreaseLight;
  final int? vitalityIncreaseModerate;
  final int? vitalityIncreaseHigh;
  final int? vitalityCurrent;
  final int? vitalityLast7Days;
  final int? vitalityNextTargetType;
  final int? vitalityNextTargetMinutes;
  final int? fitnessBalance;
  final int? fitnessLevel;
  final int? fatigueLevel;
  final int? trainingStressScore;
}

class XiaomiActivitySampleRecord {
  const XiaomiActivitySampleRecord({
    required this.timestamp,
    this.activityType,
    this.activityStrength,
    this.sportType,
    this.steps,
    this.activeCalories,
    this.distanceMeters,
    this.heartRate,
    this.energy,
    this.caloriesDelta,
    this.energyStatus,
    this.energyStatusValue,
    this.bloodOxygen,
    this.pressure,
    this.lightSensation,
    this.volumeMomentum,
    this.floors,
    this.stress,
  });

  final DateTime timestamp;
  final int? activityType;
  final int? activityStrength;
  final int? sportType;
  final int? steps;
  final int? activeCalories;
  final int? distanceMeters;
  final int? heartRate;
  final int? energy;

  /// Per-record increment from `daily_activity/record`, not the daily total.
  /// The daily total lives in the separate `daily_activity/report` file.
  final int? caloriesDelta;
  final int? energyStatus;
  final int? energyStatusValue;
  final int? bloodOxygen;
  final int? pressure;
  final int? lightSensation;
  final int? volumeMomentum;
  final int? floors;
  final int? stress;
}

enum XiaomiActivityAbnormalHealthKind {
  highHeartRate,
  lowHeartRate,
  lowBloodOxygen,
  highStress,
  irregularHeartbeat,
}

/// One event from the Vela daily-type-9 abnormal-health file.
///
/// Mi Fitness maps types 1/2/3/4 to high/low heart rate, low blood oxygen,
/// and high stress. Type 5 is the separate heart-health irregular-heartbeat
/// (ABNORMAL_FIB) event and has no sample value or configured threshold.
class XiaomiActivityAbnormalHealthRecord {
  const XiaomiActivityAbnormalHealthRecord({
    required this.timestamp,
    required this.kind,
    this.value,
    this.threshold,
    this.startedAt,
    this.endedAt,
  });

  final DateTime timestamp;
  final XiaomiActivityAbnormalHealthKind kind;
  final int? value;
  final int? threshold;
  final DateTime? startedAt;
  final DateTime? endedAt;
}

/// Compatibility view for callers that only consume high/low heart-rate
/// alerts. New code should use [XiaomiActivityAbnormalHealthRecord].
enum XiaomiActivityAbnormalHeartRateKind { high, low }

/// One sample from the Vela daily-type-9 abnormal-health file.
///
/// The file contains a segment header (start/end, type, configured threshold)
/// followed by timestamp/value pairs. Keeping the segment bounds here makes it
/// possible to reproduce Mi Fitness' event list without treating every value
/// as an independently detected event.
class XiaomiActivityAbnormalHeartRateRecord {
  const XiaomiActivityAbnormalHeartRateRecord({
    required this.timestamp,
    required this.value,
    required this.kind,
    required this.threshold,
    this.startedAt,
    this.endedAt,
  });

  final DateTime timestamp;
  final int value;
  final XiaomiActivityAbnormalHeartRateKind kind;
  final int threshold;
  final DateTime? startedAt;
  final DateTime? endedAt;
}

class XiaomiActivitySleepRecord {
  const XiaomiActivitySleepRecord({
    required this.startedAt,
    required this.endedAt,
    required this.durationSeconds,
    this.averageHeartRate,
    this.averageBloodOxygen,
    this.minimumHeartRate,
    this.maximumHeartRate,
    this.minimumBloodOxygen,
    this.maximumBloodOxygen,
    this.quality,
    this.sleepEfficiency,
    this.bedDurationSeconds,
    this.goBedAt,
    this.leaveBedAt,
    this.awakeDurationSeconds,
    this.lightSleepDurationSeconds,
    this.deepSleepDurationSeconds,
    this.remSleepDurationSeconds,
    this.averageHrv,
    this.hrvMin,
    this.hrvMax,
    this.hrvBaselineMin,
    this.hrvBaselineMax,
    this.hrvStandardDeviation,
    this.hrvMedian,
    this.hrvLowerQuantile,
    this.hrvMiddleQuantile,
    this.hrvUpperQuantile,
    this.hrvTimestamp,
    this.sleepIndex,
    this.wakeCount,
    this.hasRem,
    this.hasStage,
    this.sleepScoreVersion,
    this.hrvPoints = const [],
    this.heartRatePoints = const [],
    this.bloodOxygenPoints = const [],
    this.stages = const [],
  });

  final DateTime startedAt;
  final DateTime endedAt;
  final int durationSeconds;
  final int? averageHeartRate;
  final int? averageBloodOxygen;
  final int? minimumHeartRate;
  final int? maximumHeartRate;
  final int? minimumBloodOxygen;
  final int? maximumBloodOxygen;
  final int? quality;
  final int? sleepEfficiency;
  final int? bedDurationSeconds;
  final DateTime? goBedAt;
  final DateTime? leaveBedAt;
  final int? awakeDurationSeconds;
  final int? lightSleepDurationSeconds;
  final int? deepSleepDurationSeconds;
  final int? remSleepDurationSeconds;
  final int? averageHrv;
  final int? hrvMin;
  final int? hrvMax;
  final int? hrvBaselineMin;
  final int? hrvBaselineMax;
  final int? hrvStandardDeviation;
  final int? hrvMedian;
  final int? hrvLowerQuantile;
  final int? hrvMiddleQuantile;
  final int? hrvUpperQuantile;
  final DateTime? hrvTimestamp;

  /// The device-provided sleep summary index.  Mi Fitness prefers index 1 as
  /// the main night when a report contains more than one sleep segment.
  final int? sleepIndex;
  final int? wakeCount;
  final bool? hasRem;
  final bool? hasStage;
  final int? sleepScoreVersion;
  final List<XiaomiActivitySleepHrvPoint> hrvPoints;
  final List<XiaomiActivitySleepVitalPoint> heartRatePoints;
  final List<XiaomiActivitySleepVitalPoint> bloodOxygenPoints;
  final List<XiaomiActivitySleepStageRecord> stages;

  XiaomiActivitySleepRecord copyWith({
    DateTime? startedAt,
    DateTime? endedAt,
    int? durationSeconds,
    int? averageHeartRate,
    int? averageBloodOxygen,
    int? minimumHeartRate,
    int? maximumHeartRate,
    int? minimumBloodOxygen,
    int? maximumBloodOxygen,
    int? quality,
    int? sleepEfficiency,
    int? bedDurationSeconds,
    DateTime? goBedAt,
    DateTime? leaveBedAt,
    int? awakeDurationSeconds,
    int? lightSleepDurationSeconds,
    int? deepSleepDurationSeconds,
    int? remSleepDurationSeconds,
    int? averageHrv,
    int? hrvMin,
    int? hrvMax,
    int? hrvBaselineMin,
    int? hrvBaselineMax,
    int? hrvStandardDeviation,
    int? hrvMedian,
    int? hrvLowerQuantile,
    int? hrvMiddleQuantile,
    int? hrvUpperQuantile,
    DateTime? hrvTimestamp,
    int? sleepIndex,
    int? wakeCount,
    bool? hasRem,
    bool? hasStage,
    int? sleepScoreVersion,
    List<XiaomiActivitySleepHrvPoint>? hrvPoints,
    List<XiaomiActivitySleepVitalPoint>? heartRatePoints,
    List<XiaomiActivitySleepVitalPoint>? bloodOxygenPoints,
    List<XiaomiActivitySleepStageRecord>? stages,
  }) => XiaomiActivitySleepRecord(
    startedAt: startedAt ?? this.startedAt,
    endedAt: endedAt ?? this.endedAt,
    durationSeconds: durationSeconds ?? this.durationSeconds,
    averageHeartRate: averageHeartRate ?? this.averageHeartRate,
    averageBloodOxygen: averageBloodOxygen ?? this.averageBloodOxygen,
    minimumHeartRate: minimumHeartRate ?? this.minimumHeartRate,
    maximumHeartRate: maximumHeartRate ?? this.maximumHeartRate,
    minimumBloodOxygen: minimumBloodOxygen ?? this.minimumBloodOxygen,
    maximumBloodOxygen: maximumBloodOxygen ?? this.maximumBloodOxygen,
    quality: quality ?? this.quality,
    sleepEfficiency: sleepEfficiency ?? this.sleepEfficiency,
    bedDurationSeconds: bedDurationSeconds ?? this.bedDurationSeconds,
    goBedAt: goBedAt ?? this.goBedAt,
    leaveBedAt: leaveBedAt ?? this.leaveBedAt,
    awakeDurationSeconds: awakeDurationSeconds ?? this.awakeDurationSeconds,
    lightSleepDurationSeconds:
        lightSleepDurationSeconds ?? this.lightSleepDurationSeconds,
    deepSleepDurationSeconds:
        deepSleepDurationSeconds ?? this.deepSleepDurationSeconds,
    remSleepDurationSeconds:
        remSleepDurationSeconds ?? this.remSleepDurationSeconds,
    averageHrv: averageHrv ?? this.averageHrv,
    hrvMin: hrvMin ?? this.hrvMin,
    hrvMax: hrvMax ?? this.hrvMax,
    hrvBaselineMin: hrvBaselineMin ?? this.hrvBaselineMin,
    hrvBaselineMax: hrvBaselineMax ?? this.hrvBaselineMax,
    hrvStandardDeviation: hrvStandardDeviation ?? this.hrvStandardDeviation,
    hrvMedian: hrvMedian ?? this.hrvMedian,
    hrvLowerQuantile: hrvLowerQuantile ?? this.hrvLowerQuantile,
    hrvMiddleQuantile: hrvMiddleQuantile ?? this.hrvMiddleQuantile,
    hrvUpperQuantile: hrvUpperQuantile ?? this.hrvUpperQuantile,
    hrvTimestamp: hrvTimestamp ?? this.hrvTimestamp,
    sleepIndex: sleepIndex ?? this.sleepIndex,
    wakeCount: wakeCount ?? this.wakeCount,
    hasRem: hasRem ?? this.hasRem,
    hasStage: hasStage ?? this.hasStage,
    sleepScoreVersion: sleepScoreVersion ?? this.sleepScoreVersion,
    hrvPoints: hrvPoints ?? this.hrvPoints,
    heartRatePoints: heartRatePoints ?? this.heartRatePoints,
    bloodOxygenPoints: bloodOxygenPoints ?? this.bloodOxygenPoints,
    stages: stages ?? this.stages,
  );
}

class XiaomiActivitySleepHrvPoint {
  const XiaomiActivitySleepHrvPoint({
    required this.timestamp,
    required this.value,
  });

  final DateTime timestamp;
  final int value;
}

class XiaomiActivitySleepVitalPoint {
  const XiaomiActivitySleepVitalPoint({
    required this.timestamp,
    required this.value,
  });

  final DateTime timestamp;
  final int value;
}

class XiaomiActivitySleepStageRecord {
  const XiaomiActivitySleepStageRecord({
    required this.timestamp,
    required this.stage,
    this.endedAt,
  });

  final DateTime timestamp;

  /// Xiaomi's display-stage values: 2 deep, 3 light, 4 REM, 5 awake.
  ///
  /// The native packet decoder can also preserve 0/1 for undocumented or
  /// algorithm-only states; the UI intentionally omits those states.
  final int stage;

  /// The device's stage stream may provide the end of a stage as a duration.
  /// Older compact files only expose a start point and leave this null.
  final DateTime? endedAt;
}

class XiaomiActivityWorkoutRecord {
  const XiaomiActivityWorkoutRecord({
    required this.startedAt,
    required this.endedAt,
    required this.activityType,
    this.distanceMeters,
    this.calories,
    this.averageHeartRate,
    this.maximumHeartRate,
    this.minimumHeartRate,
    this.subSportType,
    this.totalDurationSeconds,
    this.effectiveDurationSeconds,
    this.activeCalories,
    this.averagePaceSecondsPerKilometer,
    this.bestPaceSecondsPerKilometer,
    this.worstPaceSecondsPerKilometer,
    this.averageSpeedKph,
    this.bestSpeedKph,
    this.totalSteps,
    this.averageStrideCentimeters,
    this.averageCadence,
    this.maximumCadence,
    this.averageBloodOxygen,
    this.maximumBloodOxygen,
    this.minimumBloodOxygen,
    this.averageStress,
    this.maximumStress,
    this.minimumStress,
    this.totalAscentMeters,
    this.totalDescentMeters,
    this.averageAltitudeMeters,
    this.maximumAltitudeMeters,
    this.minimumAltitudeMeters,
    this.aerobicTrainingEffect,
    this.anaerobicTrainingEffect,
    this.peakTrainingEffect,
    this.vo2Max,
    this.bodyEnergyConsumption,
    this.expectedRecoveryHours,
    this.trainingLoad,
    this.earnedVitality,
    this.heartRateZoneMethod,
    this.heartRateZones = const [],
    this.averagePowerWatts,
    this.maximumPowerWatts,
    this.totalArmPulls,
    this.mainSwimmingStroke,
    this.averageStrokeFrequency,
    this.maximumStrokeFrequency,
    this.turnCount,
    this.averageSwolf,
    this.bestSwolf,
    this.poolWidthMeters,
    this.totalJumps,
    this.averageJumpFrequency,
    this.bestJumpFrequency,
    this.tripCount,
    this.setCount,
    this.totalStrokes,
    this.averageRowingFrequency,
    this.bestRowingFrequency,
    this.samples = const [],
    this.route = const [],
    this.recovery,
  });

  final DateTime startedAt;
  final DateTime endedAt;
  final int activityType;
  final int? distanceMeters;
  final int? calories;
  final int? averageHeartRate;
  final int? maximumHeartRate;
  final int? minimumHeartRate;
  final int? subSportType;
  final int? totalDurationSeconds;
  final int? effectiveDurationSeconds;
  final int? activeCalories;
  final int? averagePaceSecondsPerKilometer;
  final int? bestPaceSecondsPerKilometer;
  final int? worstPaceSecondsPerKilometer;
  final double? averageSpeedKph;
  final double? bestSpeedKph;
  final int? totalSteps;
  final int? averageStrideCentimeters;
  final int? averageCadence;
  final int? maximumCadence;
  final int? averageBloodOxygen;
  final int? maximumBloodOxygen;
  final int? minimumBloodOxygen;
  final int? averageStress;
  final int? maximumStress;
  final int? minimumStress;
  final double? totalAscentMeters;
  final double? totalDescentMeters;
  final double? averageAltitudeMeters;
  final double? maximumAltitudeMeters;
  final double? minimumAltitudeMeters;
  final double? aerobicTrainingEffect;
  final double? anaerobicTrainingEffect;
  final double? peakTrainingEffect;
  final int? vo2Max;
  final int? bodyEnergyConsumption;
  final int? expectedRecoveryHours;
  final int? trainingLoad;
  final int? earnedVitality;
  final int? heartRateZoneMethod;
  final List<XiaomiWorkoutHeartRateZone> heartRateZones;
  final int? averagePowerWatts;
  final int? maximumPowerWatts;
  final int? totalArmPulls;
  final int? mainSwimmingStroke;
  final int? averageStrokeFrequency;
  final int? maximumStrokeFrequency;
  final int? turnCount;
  final int? averageSwolf;
  final int? bestSwolf;
  final int? poolWidthMeters;
  final int? totalJumps;
  final int? averageJumpFrequency;
  final int? bestJumpFrequency;
  final int? tripCount;
  final int? setCount;
  final int? totalStrokes;
  final int? averageRowingFrequency;
  final int? bestRowingFrequency;
  final List<XiaomiWorkoutSampleRecord> samples;
  final List<XiaomiWorkoutRoutePoint> route;
  final XiaomiWorkoutHeartRateRecovery? recovery;
}

class XiaomiWorkoutHeartRateZone {
  const XiaomiWorkoutHeartRateZone({
    required this.zone,
    required this.durationSeconds,
    this.lowerLimit,
  });

  final int zone;
  final int durationSeconds;
  final int? lowerLimit;
}

class XiaomiWorkoutSampleRecord {
  const XiaomiWorkoutSampleRecord({
    required this.timestamp,
    this.heartRate,
    this.bloodOxygen,
    this.stress,
    this.calories,
    this.steps,
    this.distanceMeters,
    this.altitudeMeters,
    this.paceSecondsPerKilometer,
    this.speedKph,
    this.cadence,
    this.powerWatts,
    this.strideCentimeters,
    this.jumpFrequency,
    this.jumpHeightCentimeters,
    this.strokeFrequency,
    this.swimmingStroke,
    this.swolf,
    this.swimmingPaceSecondsPer100Meters,
  });

  final DateTime timestamp;
  final int? heartRate;
  final int? bloodOxygen;
  final int? stress;
  final int? calories;
  final int? steps;
  final int? distanceMeters;
  final double? altitudeMeters;
  final int? paceSecondsPerKilometer;
  final double? speedKph;
  final int? cadence;
  final int? powerWatts;
  final int? strideCentimeters;
  final int? jumpFrequency;
  final int? jumpHeightCentimeters;
  final int? strokeFrequency;
  final int? swimmingStroke;
  final int? swolf;
  final int? swimmingPaceSecondsPer100Meters;
}

class XiaomiWorkoutRoutePoint {
  const XiaomiWorkoutRoutePoint({
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    this.altitudeMeters,
    this.speedMetersPerSecond,
    this.horizontalAccuracyMeters,
  });

  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final double? altitudeMeters;
  final double? speedMetersPerSecond;
  final double? horizontalAccuracyMeters;
}

class XiaomiWorkoutHeartRateRecovery {
  const XiaomiWorkoutHeartRateRecovery({
    required this.startedAt,
    this.recoveredHeartRate,
    this.recoveryRate,
    this.heartRates = const [],
  });

  final DateTime startedAt;
  final int? recoveredHeartRate;
  final int? recoveryRate;
  final List<int> heartRates;
}

class XiaomiParsedActivityFile {
  const XiaomiParsedActivityFile({
    this.daily,
    this.samples = const [],
    this.sleep = const [],
    this.workouts = const [],
    this.abnormalHealthRecords = const [],
  });

  final XiaomiActivityDailyRecord? daily;
  final List<XiaomiActivitySampleRecord> samples;
  final List<XiaomiActivitySleepRecord> sleep;
  final List<XiaomiActivityWorkoutRecord> workouts;
  final List<XiaomiActivityAbnormalHealthRecord> abnormalHealthRecords;
}
