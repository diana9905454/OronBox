import 'dart:convert';

enum XiaomiHealthMetric {
  activity,
  activeCalories,
  heartRate,
  restingHeartRate,
  bloodOxygen,
  stress,
  vitality,
  sleep,
  workout,
}

class HealthSample {
  const HealthSample({
    required this.timestamp,
    required this.metric,
    required this.value,
  });

  final DateTime timestamp;
  final XiaomiHealthMetric metric;
  final double value;

  bool get isUsable {
    if (!value.isFinite) return false;
    return switch (metric) {
      XiaomiHealthMetric.heartRate ||
      XiaomiHealthMetric.restingHeartRate => value >= 30 && value <= 240,
      XiaomiHealthMetric.bloodOxygen => value >= 50 && value <= 100,
      XiaomiHealthMetric.stress => value > 0 && value <= 100,
      XiaomiHealthMetric.vitality => value >= 0,
      XiaomiHealthMetric.activity ||
      XiaomiHealthMetric.activeCalories => value >= 0,
      XiaomiHealthMetric.sleep || XiaomiHealthMetric.workout => false,
    };
  }

  Map<String, Object?> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'metric': metric.name,
    'value': value,
  };

  factory HealthSample.fromJson(Map<String, Object?> json) => HealthSample(
    timestamp: DateTime.parse(json['timestamp']!.toString()),
    metric: XiaomiHealthMetric.values.firstWhere(
      (value) => value.name == json['metric'],
      orElse: () => XiaomiHealthMetric.heartRate,
    ),
    value: (json['value'] as num).toDouble(),
  );
}

/// One raw daily-activity sample. Unlike [HealthSample], this keeps all
/// measurements that arrived at the same timestamp together. The UI can pick
/// one metric for a chart without losing the other raw fields or inventing
/// joins between independent series.
class HealthActivitySample {
  const HealthActivitySample({
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

  /// Per-sample increment from Xiaomi's daily-activity record. It is not a
  /// daily total; totals come from [HealthDailySummary.calories] or
  /// [HealthDailySummary.activeCalories].
  final int? caloriesDelta;
  final int? energyStatus;
  final int? energyStatusValue;
  final int? bloodOxygen;
  final int? pressure;
  final int? lightSensation;
  final int? volumeMomentum;
  final int? floors;
  final int? stress;

  Map<String, Object?> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    if (activityType != null) 'activityType': activityType,
    if (activityStrength != null) 'activityStrength': activityStrength,
    if (sportType != null) 'sportType': sportType,
    if (steps != null) 'steps': steps,
    if (activeCalories != null) 'activeCalories': activeCalories,
    if (distanceMeters != null) 'distanceMeters': distanceMeters,
    if (heartRate != null) 'heartRate': heartRate,
    if (energy != null) 'energy': energy,
    if (caloriesDelta != null) 'caloriesDelta': caloriesDelta,
    if (energyStatus != null) 'energyStatus': energyStatus,
    if (energyStatusValue != null) 'energyStatusValue': energyStatusValue,
    if (bloodOxygen != null) 'bloodOxygen': bloodOxygen,
    if (pressure != null) 'pressure': pressure,
    if (lightSensation != null) 'lightSensation': lightSensation,
    if (volumeMomentum != null) 'volumeMomentum': volumeMomentum,
    if (floors != null) 'floors': floors,
    if (stress != null) 'stress': stress,
  };

  factory HealthActivitySample.fromJson(Map<String, Object?> json) =>
      HealthActivitySample(
        timestamp: DateTime.parse(json['timestamp']!.toString()),
        activityType: _int(json['activityType']),
        activityStrength: _int(json['activityStrength']),
        sportType: _int(json['sportType']),
        steps: _int(json['steps']),
        activeCalories: _int(json['activeCalories']),
        distanceMeters: _int(json['distanceMeters']),
        heartRate: _int(json['heartRate']),
        energy: _int(json['energy']),
        caloriesDelta: _int(json['caloriesDelta'] ?? json['totalCalories']),
        energyStatus: _int(json['energyStatus']),
        energyStatusValue: _int(json['energyStatusValue']),
        bloodOxygen: _int(json['bloodOxygen']),
        pressure: _int(json['pressure']),
        lightSensation: _int(json['lightSensation']),
        volumeMomentum: _int(json['volumeMomentum']),
        floors: _int(json['floors']),
        stress: _int(json['stress']),
      );
}

class HealthDailySummary {
  const HealthDailySummary({
    required this.date,
    this.steps,
    this.activeCalories,
    this.calories,
    this.distanceMeters,
    this.currentHeartRate,
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

  /// Device-provided `totalSteps` from the daily-activity report when present.
  /// If the report is absent, the adapter derives this from sample deltas.
  final int? steps;

  /// Device-provided `totalactiveCalories` from the daily-activity report when
  /// present; otherwise derived from `activityCalories` sample deltas.
  final int? activeCalories;

  /// Device-provided `totalCalories` from the daily-activity report. This is
  /// distinct from [HealthActivitySample.caloriesDelta].
  final int? calories;
  final int? distanceMeters;

  /// Legacy daily-report slot 2. New Xiaomi reports reserve this slot; it is
  /// retained only so older snapshots can still be decoded.
  @Deprecated('Use averageHeartRate or a timestamped heart-rate sample')
  final int? currentHeartRate;
  final int? restingHeartRate;
  final int? minHeartRate;
  final DateTime? minHeartRateAt;
  final int? maxHeartRate;
  final DateTime? maxHeartRateAt;
  final int? averageHeartRate;
  final int? minStress;
  final int? maxStress;
  final int? averageStress;

  /// One bit per hour, starting at 00:00, as defined by Xiaomi's daily
  /// report format.
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

  int? get standingHours {
    final value = standingBitmap;
    if (value == null) return null;
    var bits = value;
    var count = 0;
    while (bits != 0) {
      count += bits & 1;
      bits >>= 1;
    }
    return count;
  }

  Map<String, Object?> toJson() => {
    'date': date.toIso8601String(),
    if (steps != null) 'steps': steps,
    if (activeCalories != null) 'activeCalories': activeCalories,
    if (calories != null) 'calories': calories,
    if (distanceMeters != null) 'distanceMeters': distanceMeters,
    if (currentHeartRate != null) 'currentHeartRate': currentHeartRate,
    if (restingHeartRate != null) 'restingHeartRate': restingHeartRate,
    if (minHeartRate != null) 'minHeartRate': minHeartRate,
    if (minHeartRateAt != null)
      'minHeartRateAt': minHeartRateAt!.toIso8601String(),
    if (maxHeartRate != null) 'maxHeartRate': maxHeartRate,
    if (maxHeartRateAt != null)
      'maxHeartRateAt': maxHeartRateAt!.toIso8601String(),
    if (averageHeartRate != null) 'averageHeartRate': averageHeartRate,
    if (minStress != null) 'minStress': minStress,
    if (maxStress != null) 'maxStress': maxStress,
    if (averageStress != null) 'averageStress': averageStress,
    if (standingBitmap != null) 'standingBitmap': standingBitmap,
    if (minBloodOxygen != null) 'minBloodOxygen': minBloodOxygen,
    if (maxBloodOxygen != null) 'maxBloodOxygen': maxBloodOxygen,
    if (averageBloodOxygen != null) 'averageBloodOxygen': averageBloodOxygen,
    if (currentBloodOxygen != null) 'currentBloodOxygen': currentBloodOxygen,
    if (minBloodOxygenAt != null)
      'minBloodOxygenAt': minBloodOxygenAt!.toIso8601String(),
    if (maxBloodOxygenAt != null)
      'maxBloodOxygenAt': maxBloodOxygenAt!.toIso8601String(),
    if (floorsClimbed != null) 'floorsClimbed': floorsClimbed,
    if (remainingRecoveryHours != null)
      'remainingRecoveryHours': remainingRecoveryHours,
    if (trainingLoadToday != null) 'trainingLoadToday': trainingLoadToday,
    if (trainingLoadLast7Days != null)
      'trainingLoadLast7Days': trainingLoadLast7Days,
    if (trainingLoadLevel != null) 'trainingLoadLevel': trainingLoadLevel,
    if (vitalityIncreaseLight != null)
      'vitalityIncreaseLight': vitalityIncreaseLight,
    if (vitalityIncreaseModerate != null)
      'vitalityIncreaseModerate': vitalityIncreaseModerate,
    if (vitalityIncreaseHigh != null)
      'vitalityIncreaseHigh': vitalityIncreaseHigh,
    if (vitalityCurrent != null) 'vitalityCurrent': vitalityCurrent,
    if (vitalityLast7Days != null) 'vitalityLast7Days': vitalityLast7Days,
    if (vitalityNextTargetType != null)
      'vitalityNextTargetType': vitalityNextTargetType,
    if (vitalityNextTargetMinutes != null)
      'vitalityNextTargetMinutes': vitalityNextTargetMinutes,
    if (fitnessBalance != null) 'fitnessBalance': fitnessBalance,
    if (fitnessLevel != null) 'fitnessLevel': fitnessLevel,
    if (fatigueLevel != null) 'fatigueLevel': fatigueLevel,
    if (trainingStressScore != null) 'trainingStressScore': trainingStressScore,
  };

  factory HealthDailySummary.fromJson(Map<String, Object?> json) =>
      HealthDailySummary(
        date: DateTime.parse(json['date']!.toString()),
        steps: _int(json['steps']),
        activeCalories: _int(json['activeCalories']),
        calories: _int(json['calories']),
        distanceMeters: _int(json['distanceMeters']),
        currentHeartRate: _int(json['currentHeartRate']),
        restingHeartRate: _int(json['restingHeartRate']),
        minHeartRate: _int(json['minHeartRate']),
        minHeartRateAt: _dateTime(json['minHeartRateAt']),
        maxHeartRate: _int(json['maxHeartRate']),
        maxHeartRateAt: _dateTime(json['maxHeartRateAt']),
        averageHeartRate: _int(json['averageHeartRate']),
        minStress: _int(json['minStress']),
        maxStress: _int(json['maxStress']),
        averageStress: _int(json['averageStress']),
        standingBitmap: _int(json['standingBitmap']),
        minBloodOxygen: _int(json['minBloodOxygen']),
        maxBloodOxygen: _int(json['maxBloodOxygen']),
        averageBloodOxygen: _int(json['averageBloodOxygen']),
        currentBloodOxygen: _int(json['currentBloodOxygen']),
        minBloodOxygenAt: _dateTime(json['minBloodOxygenAt']),
        maxBloodOxygenAt: _dateTime(json['maxBloodOxygenAt']),
        floorsClimbed: _int(json['floorsClimbed']),
        remainingRecoveryHours: _int(json['remainingRecoveryHours']),
        trainingLoadToday: _int(json['trainingLoadToday']),
        trainingLoadLast7Days: _int(json['trainingLoadLast7Days']),
        trainingLoadLevel: _int(json['trainingLoadLevel']),
        vitalityIncreaseLight: _int(json['vitalityIncreaseLight']),
        vitalityIncreaseModerate: _int(json['vitalityIncreaseModerate']),
        vitalityIncreaseHigh: _int(json['vitalityIncreaseHigh']),
        vitalityCurrent: _int(json['vitalityCurrent']),
        vitalityLast7Days: _int(json['vitalityLast7Days']),
        vitalityNextTargetType: _int(json['vitalityNextTargetType']),
        vitalityNextTargetMinutes: _int(json['vitalityNextTargetMinutes']),
        fitnessBalance: _int(json['fitnessBalance']),
        fitnessLevel: _int(json['fitnessLevel']),
        fatigueLevel: _int(json['fatigueLevel']),
        trainingStressScore: _int(json['trainingStressScore']),
      );
}

enum HealthAbnormalHealthKind {
  highHeartRate,
  lowHeartRate,
  lowBloodOxygen,
  highStress,
  irregularHeartbeat,
}

class HealthAbnormalHealthRecord {
  const HealthAbnormalHealthRecord({
    required this.timestamp,
    required this.kind,
    this.value,
    this.threshold,
    this.startedAt,
    this.endedAt,
  });

  final DateTime timestamp;
  final HealthAbnormalHealthKind kind;
  final int? value;
  final int? threshold;
  final DateTime? startedAt;
  final DateTime? endedAt;

  Map<String, Object?> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'kind': kind.name,
    if (value != null) 'value': value,
    if (threshold != null) 'threshold': threshold,
    if (startedAt != null) 'startedAt': startedAt!.toIso8601String(),
    if (endedAt != null) 'endedAt': endedAt!.toIso8601String(),
  };

  factory HealthAbnormalHealthRecord.fromJson(Map<String, Object?> json) =>
      HealthAbnormalHealthRecord(
        timestamp: DateTime.parse(json['timestamp']!.toString()),
        kind: HealthAbnormalHealthKind.values.firstWhere(
          (value) => value.name == json['kind'],
          orElse: () => HealthAbnormalHealthKind.irregularHeartbeat,
        ),
        value: _int(json['value']),
        threshold: _int(json['threshold']),
        startedAt: _dateTime(json['startedAt']),
        endedAt: _dateTime(json['endedAt']),
      );
}

/// Compatibility model for callers that only consume high/low heart-rate
/// alerts. New code should use [HealthAbnormalHealthRecord].
enum HealthAbnormalHeartRateKind { high, low, unknown }

class HealthAbnormalHeartRateRecord {
  const HealthAbnormalHeartRateRecord({
    required this.timestamp,
    required this.value,
    required this.kind,
    required this.threshold,
    this.startedAt,
    this.endedAt,
  });

  final DateTime timestamp;
  final int value;
  final HealthAbnormalHeartRateKind kind;
  final int threshold;
  final DateTime? startedAt;
  final DateTime? endedAt;

  Map<String, Object?> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'value': value,
    'kind': kind.name,
    'threshold': threshold,
    if (startedAt != null) 'startedAt': startedAt!.toIso8601String(),
    if (endedAt != null) 'endedAt': endedAt!.toIso8601String(),
  };

  factory HealthAbnormalHeartRateRecord.fromJson(Map<String, Object?> json) =>
      HealthAbnormalHeartRateRecord(
        timestamp: DateTime.parse(json['timestamp']!.toString()),
        value: (json['value'] as num).toInt(),
        kind: HealthAbnormalHeartRateKind.values.firstWhere(
          (value) => value.name == json['kind'],
          orElse: () => HealthAbnormalHeartRateKind.unknown,
        ),
        threshold: (json['threshold'] as num?)?.toInt() ?? 0,
        startedAt: _dateTime(json['startedAt']),
        endedAt: _dateTime(json['endedAt']),
      );
}

class HealthSleepSummary {
  static const longSleepThreshold = Duration(hours: 3);

  const HealthSleepSummary({
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
  final int? sleepIndex;
  final int? wakeCount;
  final bool? hasRem;
  final bool? hasStage;
  final int? sleepScoreVersion;
  final List<HealthSleepHrvPoint> hrvPoints;
  final List<HealthSleepVitalPoint> heartRatePoints;
  final List<HealthSleepVitalPoint> bloodOxygenPoints;
  final List<HealthSleepStageSegment> stages;

  bool get isLongSleep => durationSeconds >= longSleepThreshold.inSeconds;

  Map<String, Object?> toJson() => {
    'startedAt': startedAt.toIso8601String(),
    'endedAt': endedAt.toIso8601String(),
    'durationSeconds': durationSeconds,
    if (averageHeartRate != null) 'averageHeartRate': averageHeartRate,
    if (averageBloodOxygen != null) 'averageBloodOxygen': averageBloodOxygen,
    if (minimumHeartRate != null) 'minimumHeartRate': minimumHeartRate,
    if (maximumHeartRate != null) 'maximumHeartRate': maximumHeartRate,
    if (minimumBloodOxygen != null) 'minimumBloodOxygen': minimumBloodOxygen,
    if (maximumBloodOxygen != null) 'maximumBloodOxygen': maximumBloodOxygen,
    if (quality != null) 'quality': quality,
    if (sleepEfficiency != null) 'sleepEfficiency': sleepEfficiency,
    if (bedDurationSeconds != null) 'bedDurationSeconds': bedDurationSeconds,
    if (goBedAt != null) 'goBedAt': goBedAt!.toIso8601String(),
    if (leaveBedAt != null) 'leaveBedAt': leaveBedAt!.toIso8601String(),
    if (awakeDurationSeconds != null)
      'awakeDurationSeconds': awakeDurationSeconds,
    if (lightSleepDurationSeconds != null)
      'lightSleepDurationSeconds': lightSleepDurationSeconds,
    if (deepSleepDurationSeconds != null)
      'deepSleepDurationSeconds': deepSleepDurationSeconds,
    if (remSleepDurationSeconds != null)
      'remSleepDurationSeconds': remSleepDurationSeconds,
    if (averageHrv != null) 'averageHrv': averageHrv,
    if (hrvMin != null) 'hrvMin': hrvMin,
    if (hrvMax != null) 'hrvMax': hrvMax,
    if (hrvBaselineMin != null) 'hrvBaselineMin': hrvBaselineMin,
    if (hrvBaselineMax != null) 'hrvBaselineMax': hrvBaselineMax,
    if (hrvStandardDeviation != null)
      'hrvStandardDeviation': hrvStandardDeviation,
    if (hrvMedian != null) 'hrvMedian': hrvMedian,
    if (hrvLowerQuantile != null) 'hrvLowerQuantile': hrvLowerQuantile,
    if (hrvMiddleQuantile != null) 'hrvMiddleQuantile': hrvMiddleQuantile,
    if (hrvUpperQuantile != null) 'hrvUpperQuantile': hrvUpperQuantile,
    if (hrvTimestamp != null) 'hrvTimestamp': hrvTimestamp!.toIso8601String(),
    if (sleepIndex != null) 'sleepIndex': sleepIndex,
    if (wakeCount != null) 'wakeCount': wakeCount,
    if (hasRem != null) 'hasRem': hasRem,
    if (hasStage != null) 'hasStage': hasStage,
    if (sleepScoreVersion != null) 'sleepScoreVersion': sleepScoreVersion,
    'hrvPoints': hrvPoints
        .map((value) => value.toJson())
        .toList(growable: false),
    'heartRatePoints': heartRatePoints
        .map((value) => value.toJson())
        .toList(growable: false),
    'bloodOxygenPoints': bloodOxygenPoints
        .map((value) => value.toJson())
        .toList(growable: false),
    'stages': stages.map((value) => value.toJson()).toList(growable: false),
  };

  factory HealthSleepSummary.fromJson(Map<String, Object?> json) =>
      HealthSleepSummary(
        startedAt: DateTime.parse(json['startedAt']!.toString()),
        endedAt: DateTime.parse(json['endedAt']!.toString()),
        durationSeconds: (json['durationSeconds'] as num).toInt(),
        averageHeartRate: _int(json['averageHeartRate']),
        averageBloodOxygen: _int(json['averageBloodOxygen']),
        minimumHeartRate: _int(json['minimumHeartRate']),
        maximumHeartRate: _int(json['maximumHeartRate']),
        minimumBloodOxygen: _int(json['minimumBloodOxygen']),
        maximumBloodOxygen: _int(json['maximumBloodOxygen']),
        quality: _int(json['quality']),
        sleepEfficiency: _int(json['sleepEfficiency']),
        bedDurationSeconds: _int(json['bedDurationSeconds']),
        goBedAt: _dateTime(json['goBedAt']),
        leaveBedAt: _dateTime(json['leaveBedAt']),
        awakeDurationSeconds: _int(json['awakeDurationSeconds']),
        lightSleepDurationSeconds: _int(json['lightSleepDurationSeconds']),
        deepSleepDurationSeconds: _int(json['deepSleepDurationSeconds']),
        remSleepDurationSeconds: _int(json['remSleepDurationSeconds']),
        averageHrv: _int(json['averageHrv']),
        hrvMin: _int(json['hrvMin']),
        hrvMax: _int(json['hrvMax']),
        hrvBaselineMin: _int(json['hrvBaselineMin']),
        hrvBaselineMax: _int(json['hrvBaselineMax']),
        hrvStandardDeviation: _int(json['hrvStandardDeviation']),
        hrvMedian: _int(json['hrvMedian']),
        hrvLowerQuantile: _int(json['hrvLowerQuantile']),
        hrvMiddleQuantile: _int(json['hrvMiddleQuantile']),
        hrvUpperQuantile: _int(json['hrvUpperQuantile']),
        hrvTimestamp: _dateTime(json['hrvTimestamp']),
        sleepIndex: _int(json['sleepIndex']),
        wakeCount: _int(json['wakeCount']),
        hasRem: _bool(json['hasRem']),
        hasStage: _bool(json['hasStage']),
        sleepScoreVersion: _int(json['sleepScoreVersion']),
        hrvPoints: _list(json['hrvPoints'], HealthSleepHrvPoint.fromJson),
        heartRatePoints: _list(
          json['heartRatePoints'],
          HealthSleepVitalPoint.fromJson,
        ),
        bloodOxygenPoints: _list(
          json['bloodOxygenPoints'],
          HealthSleepVitalPoint.fromJson,
        ),
        stages: _list(json['stages'], HealthSleepStageSegment.fromJson),
      );
}

class HealthSleepHrvPoint {
  const HealthSleepHrvPoint({required this.timestamp, required this.value});

  final DateTime timestamp;
  final int value;

  Map<String, Object?> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'value': value,
  };

  factory HealthSleepHrvPoint.fromJson(Map<String, Object?> json) =>
      HealthSleepHrvPoint(
        timestamp: DateTime.parse(json['timestamp']!.toString()),
        value: (json['value'] as num).toInt(),
      );
}

class HealthSleepVitalPoint {
  const HealthSleepVitalPoint({required this.timestamp, required this.value});

  final DateTime timestamp;
  final int value;

  Map<String, Object?> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'value': value,
  };

  factory HealthSleepVitalPoint.fromJson(Map<String, Object?> json) =>
      HealthSleepVitalPoint(
        timestamp: DateTime.parse(json['timestamp']!.toString()),
        value: (json['value'] as num).toInt(),
      );
}

enum HealthSleepStageKind { awake, light, deep, rem, unknown }

class HealthSleepStageSegment {
  const HealthSleepStageSegment({
    required this.startedAt,
    required this.endedAt,
    required this.kind,
  });

  final DateTime startedAt;
  final DateTime endedAt;
  final HealthSleepStageKind kind;

  int get durationSeconds => endedAt.difference(startedAt).inSeconds;

  Map<String, Object?> toJson() => {
    'startedAt': startedAt.toIso8601String(),
    'endedAt': endedAt.toIso8601String(),
    'kind': kind.name,
  };

  factory HealthSleepStageSegment.fromJson(Map<String, Object?> json) =>
      HealthSleepStageSegment(
        startedAt: DateTime.parse(json['startedAt']!.toString()),
        endedAt: DateTime.parse(json['endedAt']!.toString()),
        kind: HealthSleepStageKind.values.firstWhere(
          (value) => value.name == json['kind'],
          orElse: () => HealthSleepStageKind.unknown,
        ),
      );
}

class HealthWorkoutSummary {
  const HealthWorkoutSummary({
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
  final List<HealthWorkoutHeartRateZone> heartRateZones;
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
  final List<HealthWorkoutSample> samples;
  final List<HealthWorkoutRoutePoint> route;
  final HealthWorkoutHeartRateRecovery? recovery;

  List<int> _sampleHeartRates() => samples
      .map((sample) => sample.heartRate)
      .whereType<int>()
      .where((value) => value > 0)
      .toList(growable: false);

  /// The reported average, or one derived from the per-record heart-rate
  /// samples. Some firmware reports carry heart rate only in the record
  /// stream, never in the compact summary, so the card must fall back to the
  /// samples instead of showing no heart rate at all.
  int? get effectiveAverageHeartRate {
    final reported = averageHeartRate;
    if (reported != null && reported > 0) return reported;
    final values = _sampleHeartRates();
    if (values.isEmpty) return null;
    final total = values.fold<int>(0, (sum, value) => sum + value);
    return (total / values.length).round();
  }

  int? get effectiveMaximumHeartRate {
    final reported = maximumHeartRate;
    if (reported != null && reported > 0) return reported;
    final values = _sampleHeartRates();
    if (values.isEmpty) return null;
    return values.reduce((left, right) => left > right ? left : right);
  }

  int? get effectiveMinimumHeartRate {
    final reported = minimumHeartRate;
    if (reported != null && reported > 0) return reported;
    final values = _sampleHeartRates();
    if (values.isEmpty) return null;
    return values.reduce((left, right) => left < right ? left : right);
  }

  Map<String, Object?> toJson() => {
    'startedAt': startedAt.toIso8601String(),
    'endedAt': endedAt.toIso8601String(),
    'activityType': activityType,
    if (distanceMeters != null) 'distanceMeters': distanceMeters,
    if (calories != null) 'calories': calories,
    if (averageHeartRate != null) 'averageHeartRate': averageHeartRate,
    if (maximumHeartRate != null) 'maximumHeartRate': maximumHeartRate,
    if (minimumHeartRate != null) 'minimumHeartRate': minimumHeartRate,
    if (subSportType != null) 'subSportType': subSportType,
    if (totalDurationSeconds != null)
      'totalDurationSeconds': totalDurationSeconds,
    if (effectiveDurationSeconds != null)
      'effectiveDurationSeconds': effectiveDurationSeconds,
    if (activeCalories != null) 'activeCalories': activeCalories,
    if (averagePaceSecondsPerKilometer != null)
      'averagePaceSecondsPerKilometer': averagePaceSecondsPerKilometer,
    if (bestPaceSecondsPerKilometer != null)
      'bestPaceSecondsPerKilometer': bestPaceSecondsPerKilometer,
    if (worstPaceSecondsPerKilometer != null)
      'worstPaceSecondsPerKilometer': worstPaceSecondsPerKilometer,
    if (averageSpeedKph != null) 'averageSpeedKph': averageSpeedKph,
    if (bestSpeedKph != null) 'bestSpeedKph': bestSpeedKph,
    if (totalSteps != null) 'totalSteps': totalSteps,
    if (averageStrideCentimeters != null)
      'averageStrideCentimeters': averageStrideCentimeters,
    if (averageCadence != null) 'averageCadence': averageCadence,
    if (maximumCadence != null) 'maximumCadence': maximumCadence,
    if (averageBloodOxygen != null) 'averageBloodOxygen': averageBloodOxygen,
    if (maximumBloodOxygen != null) 'maximumBloodOxygen': maximumBloodOxygen,
    if (minimumBloodOxygen != null) 'minimumBloodOxygen': minimumBloodOxygen,
    if (averageStress != null) 'averageStress': averageStress,
    if (maximumStress != null) 'maximumStress': maximumStress,
    if (minimumStress != null) 'minimumStress': minimumStress,
    if (totalAscentMeters != null) 'totalAscentMeters': totalAscentMeters,
    if (totalDescentMeters != null) 'totalDescentMeters': totalDescentMeters,
    if (averageAltitudeMeters != null)
      'averageAltitudeMeters': averageAltitudeMeters,
    if (maximumAltitudeMeters != null)
      'maximumAltitudeMeters': maximumAltitudeMeters,
    if (minimumAltitudeMeters != null)
      'minimumAltitudeMeters': minimumAltitudeMeters,
    if (aerobicTrainingEffect != null)
      'aerobicTrainingEffect': aerobicTrainingEffect,
    if (anaerobicTrainingEffect != null)
      'anaerobicTrainingEffect': anaerobicTrainingEffect,
    if (peakTrainingEffect != null) 'peakTrainingEffect': peakTrainingEffect,
    if (vo2Max != null) 'vo2Max': vo2Max,
    if (bodyEnergyConsumption != null)
      'bodyEnergyConsumption': bodyEnergyConsumption,
    if (expectedRecoveryHours != null)
      'expectedRecoveryHours': expectedRecoveryHours,
    if (trainingLoad != null) 'trainingLoad': trainingLoad,
    if (earnedVitality != null) 'earnedVitality': earnedVitality,
    if (heartRateZoneMethod != null) 'heartRateZoneMethod': heartRateZoneMethod,
    if (heartRateZones.isNotEmpty)
      'heartRateZones': heartRateZones.map((value) => value.toJson()).toList(),
    if (averagePowerWatts != null) 'averagePowerWatts': averagePowerWatts,
    if (maximumPowerWatts != null) 'maximumPowerWatts': maximumPowerWatts,
    if (totalArmPulls != null) 'totalArmPulls': totalArmPulls,
    if (mainSwimmingStroke != null) 'mainSwimmingStroke': mainSwimmingStroke,
    if (averageStrokeFrequency != null)
      'averageStrokeFrequency': averageStrokeFrequency,
    if (maximumStrokeFrequency != null)
      'maximumStrokeFrequency': maximumStrokeFrequency,
    if (turnCount != null) 'turnCount': turnCount,
    if (averageSwolf != null) 'averageSwolf': averageSwolf,
    if (bestSwolf != null) 'bestSwolf': bestSwolf,
    if (poolWidthMeters != null) 'poolWidthMeters': poolWidthMeters,
    if (totalJumps != null) 'totalJumps': totalJumps,
    if (averageJumpFrequency != null)
      'averageJumpFrequency': averageJumpFrequency,
    if (bestJumpFrequency != null) 'bestJumpFrequency': bestJumpFrequency,
    if (tripCount != null) 'tripCount': tripCount,
    if (setCount != null) 'setCount': setCount,
    if (totalStrokes != null) 'totalStrokes': totalStrokes,
    if (averageRowingFrequency != null)
      'averageRowingFrequency': averageRowingFrequency,
    if (bestRowingFrequency != null) 'bestRowingFrequency': bestRowingFrequency,
    if (samples.isNotEmpty)
      'samples': samples.map((value) => value.toJson()).toList(),
    if (route.isNotEmpty)
      'route': route.map((value) => value.toJson()).toList(),
    if (recovery != null) 'recovery': recovery!.toJson(),
  };

  factory HealthWorkoutSummary.fromJson(Map<String, Object?> json) =>
      HealthWorkoutSummary(
        startedAt: DateTime.parse(json['startedAt']!.toString()),
        endedAt: DateTime.parse(json['endedAt']!.toString()),
        activityType: (json['activityType'] as num).toInt(),
        distanceMeters: _int(json['distanceMeters']),
        calories: _int(json['calories']),
        averageHeartRate: _int(json['averageHeartRate']),
        maximumHeartRate: _int(json['maximumHeartRate']),
        minimumHeartRate: _int(json['minimumHeartRate']),
        subSportType: _int(json['subSportType']),
        totalDurationSeconds: _int(json['totalDurationSeconds']),
        effectiveDurationSeconds: _int(json['effectiveDurationSeconds']),
        activeCalories: _int(json['activeCalories']),
        averagePaceSecondsPerKilometer: _int(
          json['averagePaceSecondsPerKilometer'],
        ),
        bestPaceSecondsPerKilometer: _int(json['bestPaceSecondsPerKilometer']),
        worstPaceSecondsPerKilometer: _int(
          json['worstPaceSecondsPerKilometer'],
        ),
        averageSpeedKph: _double(json['averageSpeedKph']),
        bestSpeedKph: _double(json['bestSpeedKph']),
        totalSteps: _int(json['totalSteps']),
        averageStrideCentimeters: _int(json['averageStrideCentimeters']),
        averageCadence: _int(json['averageCadence']),
        maximumCadence: _int(json['maximumCadence']),
        averageBloodOxygen: _int(json['averageBloodOxygen']),
        maximumBloodOxygen: _int(json['maximumBloodOxygen']),
        minimumBloodOxygen: _int(json['minimumBloodOxygen']),
        averageStress: _int(json['averageStress']),
        maximumStress: _int(json['maximumStress']),
        minimumStress: _int(json['minimumStress']),
        totalAscentMeters: _double(json['totalAscentMeters']),
        totalDescentMeters: _double(json['totalDescentMeters']),
        averageAltitudeMeters: _double(json['averageAltitudeMeters']),
        maximumAltitudeMeters: _double(json['maximumAltitudeMeters']),
        minimumAltitudeMeters: _double(json['minimumAltitudeMeters']),
        aerobicTrainingEffect: _double(json['aerobicTrainingEffect']),
        anaerobicTrainingEffect: _double(json['anaerobicTrainingEffect']),
        peakTrainingEffect: _double(json['peakTrainingEffect']),
        vo2Max: _int(json['vo2Max']),
        bodyEnergyConsumption: _int(json['bodyEnergyConsumption']),
        expectedRecoveryHours: _int(json['expectedRecoveryHours']),
        trainingLoad: _int(json['trainingLoad']),
        earnedVitality: _int(json['earnedVitality']),
        heartRateZoneMethod: _int(json['heartRateZoneMethod']),
        heartRateZones: _list(
          json['heartRateZones'],
          HealthWorkoutHeartRateZone.fromJson,
        ),
        averagePowerWatts: _int(json['averagePowerWatts']),
        maximumPowerWatts: _int(json['maximumPowerWatts']),
        totalArmPulls: _int(json['totalArmPulls']),
        mainSwimmingStroke: _int(json['mainSwimmingStroke']),
        averageStrokeFrequency: _int(json['averageStrokeFrequency']),
        maximumStrokeFrequency: _int(json['maximumStrokeFrequency']),
        turnCount: _int(json['turnCount']),
        averageSwolf: _int(json['averageSwolf']),
        bestSwolf: _int(json['bestSwolf']),
        poolWidthMeters: _int(json['poolWidthMeters']),
        totalJumps: _int(json['totalJumps']),
        averageJumpFrequency: _int(json['averageJumpFrequency']),
        bestJumpFrequency: _int(json['bestJumpFrequency']),
        tripCount: _int(json['tripCount']),
        setCount: _int(json['setCount']),
        totalStrokes: _int(json['totalStrokes']),
        averageRowingFrequency: _int(json['averageRowingFrequency']),
        bestRowingFrequency: _int(json['bestRowingFrequency']),
        samples: _list(json['samples'], HealthWorkoutSample.fromJson),
        route: _list(json['route'], HealthWorkoutRoutePoint.fromJson),
        recovery: json['recovery'] is Map<String, Object?>
            ? HealthWorkoutHeartRateRecovery.fromJson(
                json['recovery']! as Map<String, Object?>,
              )
            : null,
      );
}

bool healthWorkoutSupportsPace(HealthWorkoutSummary workout) =>
    workout.averagePaceSecondsPerKilometer != null &&
    switch (workout.activityType) {
      1 || 2 || 3 || 4 || 5 || 15 || 22 => true,
      _ => false,
    };

class HealthWorkoutHeartRateZone {
  const HealthWorkoutHeartRateZone({
    required this.zone,
    required this.durationSeconds,
    this.lowerLimit,
  });

  final int zone;
  final int durationSeconds;
  final int? lowerLimit;

  Map<String, Object?> toJson() => {
    'zone': zone,
    'durationSeconds': durationSeconds,
    if (lowerLimit != null) 'lowerLimit': lowerLimit,
  };

  factory HealthWorkoutHeartRateZone.fromJson(Map<String, Object?> json) =>
      HealthWorkoutHeartRateZone(
        zone: _int(json['zone']) ?? 0,
        durationSeconds: _int(json['durationSeconds']) ?? 0,
        lowerLimit: _int(json['lowerLimit']),
      );
}

class HealthWorkoutSample {
  const HealthWorkoutSample({
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

  Map<String, Object?> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    if (heartRate != null) 'heartRate': heartRate,
    if (bloodOxygen != null) 'bloodOxygen': bloodOxygen,
    if (stress != null) 'stress': stress,
    if (calories != null) 'calories': calories,
    if (steps != null) 'steps': steps,
    if (distanceMeters != null) 'distanceMeters': distanceMeters,
    if (altitudeMeters != null) 'altitudeMeters': altitudeMeters,
    if (paceSecondsPerKilometer != null)
      'paceSecondsPerKilometer': paceSecondsPerKilometer,
    if (speedKph != null) 'speedKph': speedKph,
    if (cadence != null) 'cadence': cadence,
    if (powerWatts != null) 'powerWatts': powerWatts,
    if (strideCentimeters != null) 'strideCentimeters': strideCentimeters,
    if (jumpFrequency != null) 'jumpFrequency': jumpFrequency,
    if (jumpHeightCentimeters != null)
      'jumpHeightCentimeters': jumpHeightCentimeters,
    if (strokeFrequency != null) 'strokeFrequency': strokeFrequency,
    if (swimmingStroke != null) 'swimmingStroke': swimmingStroke,
    if (swolf != null) 'swolf': swolf,
    if (swimmingPaceSecondsPer100Meters != null)
      'swimmingPaceSecondsPer100Meters': swimmingPaceSecondsPer100Meters,
  };

  factory HealthWorkoutSample.fromJson(Map<String, Object?> json) =>
      HealthWorkoutSample(
        timestamp: DateTime.parse(json['timestamp']!.toString()),
        heartRate: _int(json['heartRate']),
        bloodOxygen: _int(json['bloodOxygen']),
        stress: _int(json['stress']),
        calories: _int(json['calories']),
        steps: _int(json['steps']),
        distanceMeters: _int(json['distanceMeters']),
        altitudeMeters: _double(json['altitudeMeters']),
        paceSecondsPerKilometer: _int(json['paceSecondsPerKilometer']),
        speedKph: _double(json['speedKph']),
        cadence: _int(json['cadence']),
        powerWatts: _int(json['powerWatts']),
        strideCentimeters: _int(json['strideCentimeters']),
        jumpFrequency: _int(json['jumpFrequency']),
        jumpHeightCentimeters: _int(json['jumpHeightCentimeters']),
        strokeFrequency: _int(json['strokeFrequency']),
        swimmingStroke: _int(json['swimmingStroke']),
        swolf: _int(json['swolf']),
        swimmingPaceSecondsPer100Meters: _int(
          json['swimmingPaceSecondsPer100Meters'],
        ),
      );
}

class HealthWorkoutRoutePoint {
  const HealthWorkoutRoutePoint({
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

  Map<String, Object?> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'latitude': latitude,
    'longitude': longitude,
    if (altitudeMeters != null) 'altitudeMeters': altitudeMeters,
    if (speedMetersPerSecond != null)
      'speedMetersPerSecond': speedMetersPerSecond,
    if (horizontalAccuracyMeters != null)
      'horizontalAccuracyMeters': horizontalAccuracyMeters,
  };

  factory HealthWorkoutRoutePoint.fromJson(Map<String, Object?> json) =>
      HealthWorkoutRoutePoint(
        timestamp: DateTime.parse(json['timestamp']!.toString()),
        latitude: _double(json['latitude']) ?? 0,
        longitude: _double(json['longitude']) ?? 0,
        altitudeMeters: _double(json['altitudeMeters']),
        speedMetersPerSecond: _double(json['speedMetersPerSecond']),
        horizontalAccuracyMeters: _double(json['horizontalAccuracyMeters']),
      );
}

class HealthWorkoutHeartRateRecovery {
  const HealthWorkoutHeartRateRecovery({
    required this.startedAt,
    this.recoveredHeartRate,
    this.recoveryRate,
    this.heartRates = const [],
  });

  final DateTime startedAt;
  final int? recoveredHeartRate;
  final int? recoveryRate;
  final List<int> heartRates;

  Map<String, Object?> toJson() => {
    'startedAt': startedAt.toIso8601String(),
    if (recoveredHeartRate != null) 'recoveredHeartRate': recoveredHeartRate,
    if (recoveryRate != null) 'recoveryRate': recoveryRate,
    'heartRates': heartRates,
  };

  factory HealthWorkoutHeartRateRecovery.fromJson(Map<String, Object?> json) =>
      HealthWorkoutHeartRateRecovery(
        startedAt: DateTime.parse(json['startedAt']!.toString()),
        recoveredHeartRate: _int(json['recoveredHeartRate']),
        recoveryRate: _int(json['recoveryRate']),
        heartRates: (json['heartRates'] as List<Object?>? ?? const [])
            .map(_int)
            .whereType<int>()
            .toList(growable: false),
      );
}

class XiaomiHealthCapabilities {
  const XiaomiHealthCapabilities({
    this.heartRate = false,
    this.bloodOxygen = false,
    this.stress = false,
    this.vitality = false,
    this.sleep = false,
    this.workouts = false,
  });

  final bool heartRate;
  final bool bloodOxygen;
  final bool stress;
  final bool vitality;
  final bool sleep;
  final bool workouts;

  Map<String, Object?> toJson() => {
    'heartRate': heartRate,
    'bloodOxygen': bloodOxygen,
    'stress': stress,
    'vitality': vitality,
    'sleep': sleep,
    'workouts': workouts,
  };

  factory XiaomiHealthCapabilities.fromJson(Map<String, Object?> json) =>
      XiaomiHealthCapabilities(
        heartRate: json['heartRate'] == true,
        bloodOxygen: json['bloodOxygen'] == true,
        stress: json['stress'] == true,
        vitality: json['vitality'] == true,
        sleep: json['sleep'] == true,
        workouts: json['workouts'] == true,
      );
}

class XiaomiHealthData {
  const XiaomiHealthData({
    this.daily = const [],
    this.samples = const [],
    this.activitySamples = const [],
    this.sleep = const [],
    this.workouts = const [],
    this.abnormalHealthRecords = const [],
    this.capabilities = const XiaomiHealthCapabilities(),
    this.lastSyncedAt,
  });

  final List<HealthDailySummary> daily;
  final List<HealthSample> samples;
  final List<HealthActivitySample> activitySamples;
  final List<HealthSleepSummary> sleep;
  final List<HealthWorkoutSummary> workouts;
  final List<HealthAbnormalHealthRecord> abnormalHealthRecords;
  final XiaomiHealthCapabilities capabilities;
  final DateTime? lastSyncedAt;

  /// Compatibility view for old callers and data consumers. New code should
  /// use [abnormalHealthRecords] so blood oxygen, stress, and heart-health
  /// events are not mislabeled as ordinary heart-rate alerts.
  List<HealthAbnormalHeartRateRecord> get abnormalHeartRates =>
      abnormalHealthRecords
          .where(
            (record) =>
                record.kind == HealthAbnormalHealthKind.highHeartRate ||
                record.kind == HealthAbnormalHealthKind.lowHeartRate,
          )
          .where((record) => record.value != null && record.threshold != null)
          .map(
            (record) => HealthAbnormalHeartRateRecord(
              timestamp: record.timestamp,
              value: record.value!,
              kind: record.kind == HealthAbnormalHealthKind.highHeartRate
                  ? HealthAbnormalHeartRateKind.high
                  : HealthAbnormalHeartRateKind.low,
              threshold: record.threshold!,
              startedAt: record.startedAt,
              endedAt: record.endedAt,
            ),
          )
          .toList(growable: false);

  HealthDailySummary? get latestDay {
    if (daily.isEmpty) return null;
    return daily.reduce(
      (left, right) => left.date.isAfter(right.date) ? left : right,
    );
  }

  /// Calendar-window vitality total for the seven days ending on [anchor].
  ///
  /// The device's embedded 7-day field is computed over the last seven
  /// *non-zero* days on some firmwares, so summing the per-day earned values
  /// locally is the only way to keep zero days in the window. Days without a
  /// daily record contribute zero rather than being skipped.
  int? vitalitySevenDayTotal(HealthDailySummary anchor) {
    final local = anchor.date.toLocal();
    final start = DateTime(
      local.year,
      local.month,
      local.day,
    ).subtract(const Duration(days: 6));
    var found = false;
    var total = 0;
    for (var offset = 0; offset < 7; offset++) {
      final date = start.add(Duration(days: offset));
      for (final day in daily) {
        final value = day.date.toLocal();
        if (value.year == date.year &&
            value.month == date.month &&
            value.day == date.day) {
          found = true;
          total += day.vitalityCurrent ?? 0;
        }
      }
    }
    return found ? total : null;
  }

  HealthDailySummary? get activitySummary => _cache.activitySummary;

  HealthDailySummary? _computeActivitySummary(
    Map<XiaomiHealthMetric, List<HealthSample>> samplesByMetric,
  ) {
    // The synchronizer normally projects raw records into HealthSample. Keep
    // the raw activitySamples fallback here as well so old snapshots and
    // partial parsers can still derive a summary without inventing a total.
    final byKey = <int, HealthSample>{};
    DateTime? latestTimestamp;
    void add(HealthSample sample) {
      if (!sample.isUsable) return;
      final key = (sample.metric.index << 48) |
          (sample.timestamp.millisecondsSinceEpoch & 0xffffffffffff);
      if (byKey.containsKey(key)) return;
      byKey[key] = sample;
      if (latestTimestamp == null || sample.timestamp.isAfter(latestTimestamp!)) {
        latestTimestamp = sample.timestamp;
      }
    }

    for (final metric in [
      XiaomiHealthMetric.activity,
      XiaomiHealthMetric.activeCalories,
    ]) {
      for (final sample in samplesByMetric[metric] ?? const []) {
        add(sample);
      }
    }
    for (final sample in activitySamples) {
      if (sample.steps != null) {
        add(
          HealthSample(
            timestamp: sample.timestamp,
            metric: XiaomiHealthMetric.activity,
            value: sample.steps!.toDouble(),
          ),
        );
      }
      if (sample.activeCalories != null) {
        add(
          HealthSample(
            timestamp: sample.timestamp,
            metric: XiaomiHealthMetric.activeCalories,
            value: sample.activeCalories!.toDouble(),
          ),
        );
      }
    }
    final sampleDate =
        latestTimestamp == null ? null : _dateOnly(latestTimestamp!);
    final day = latestDay;
    final referenceDate =
        day == null || (sampleDate != null && sampleDate.isAfter(day.date))
        ? sampleDate
        : day.date;
    if (referenceDate == null) return null;

    final daySummary = day != null && _sameDate(day.date, referenceDate)
        ? day
        : null;

    var stepSum = 0.0;
    var hasSteps = false;
    var calorieSum = 0.0;
    var hasCalories = false;
    var standingBitmap = daySummary?.standingBitmap;
    var computedStandingBitmap = 0;
    var foundStanding = false;

    for (final sample in byKey.values) {
      if (!_sameDate(sample.timestamp, referenceDate)) continue;
      if (sample.metric == XiaomiHealthMetric.activity) {
        stepSum += sample.value;
        hasSteps = true;
        if (standingBitmap == null && sample.value > 0) {
          computedStandingBitmap |= 1 << sample.timestamp.toLocal().hour;
          foundStanding = true;
        }
      } else if (sample.metric == XiaomiHealthMetric.activeCalories) {
        calorieSum += sample.value;
        hasCalories = true;
      }
    }

    standingBitmap ??= foundStanding ? computedStandingBitmap : null;
    final steps = daySummary?.steps ?? (hasSteps ? stepSum.round() : null);
    final activeCalories =
        daySummary?.activeCalories ?? (hasCalories ? calorieSum.round() : null);
    if (steps == null && activeCalories == null && standingBitmap == null) {
      return day;
    }
    return HealthDailySummary(
      date: referenceDate,
      steps: steps,
      activeCalories: activeCalories,
      calories: daySummary?.calories,
      distanceMeters: daySummary?.distanceMeters,
      currentHeartRate: daySummary?.currentHeartRate,
      restingHeartRate: daySummary?.restingHeartRate,
      minHeartRate: daySummary?.minHeartRate,
      minHeartRateAt: daySummary?.minHeartRateAt,
      maxHeartRate: daySummary?.maxHeartRate,
      maxHeartRateAt: daySummary?.maxHeartRateAt,
      averageHeartRate: daySummary?.averageHeartRate,
      minStress: daySummary?.minStress,
      maxStress: daySummary?.maxStress,
      averageStress: daySummary?.averageStress,
      standingBitmap: standingBitmap,
      minBloodOxygen: daySummary?.minBloodOxygen,
      maxBloodOxygen: daySummary?.maxBloodOxygen,
      averageBloodOxygen: daySummary?.averageBloodOxygen,
      currentBloodOxygen: daySummary?.currentBloodOxygen,
      minBloodOxygenAt: daySummary?.minBloodOxygenAt,
      maxBloodOxygenAt: daySummary?.maxBloodOxygenAt,
      floorsClimbed: daySummary?.floorsClimbed,
      remainingRecoveryHours: daySummary?.remainingRecoveryHours,
      trainingLoadToday: daySummary?.trainingLoadToday,
      trainingLoadLast7Days: daySummary?.trainingLoadLast7Days,
      trainingLoadLevel: daySummary?.trainingLoadLevel,
      vitalityIncreaseLight: daySummary?.vitalityIncreaseLight,
      vitalityIncreaseModerate: daySummary?.vitalityIncreaseModerate,
      vitalityIncreaseHigh: daySummary?.vitalityIncreaseHigh,
      vitalityCurrent: daySummary?.vitalityCurrent,
      vitalityLast7Days: daySummary?.vitalityLast7Days,
      vitalityNextTargetType: daySummary?.vitalityNextTargetType,
      vitalityNextTargetMinutes: daySummary?.vitalityNextTargetMinutes,
      fitnessBalance: daySummary?.fitnessBalance,
      fitnessLevel: daySummary?.fitnessLevel,
      fatigueLevel: daySummary?.fatigueLevel,
      trainingStressScore: daySummary?.trainingStressScore,
    );
  }

  HealthSleepSummary? get latestSleep {
    if (sleep.isEmpty) return null;
    return sleep.reduce((left, right) {
      final endComparison = left.endedAt.compareTo(right.endedAt);
      if (endComparison != 0) {
        return endComparison > 0 ? left : right;
      }
      return left.startedAt.isAfter(right.startedAt) ? left : right;
    });
  }

  /// Segments assigned to the most recent sleep day, following Mi Fitness's
  /// wake-time day boundary and long-sleep-first ordering.
  List<HealthSleepSummary> get latestSleepDay {
    final latest = latestSleep;
    if (latest == null) return const [];
    final localEnd = latest.endedAt.toLocal();
    final dayStart = DateTime(localEnd.year, localEnd.month, localEnd.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final result = sleep
        .where((value) {
          final endedAt = value.endedAt.toLocal();
          return !endedAt.isBefore(dayStart) && endedAt.isBefore(dayEnd);
        })
        .toList(growable: false);
    return [...result]..sort((left, right) {
      if (left.isLongSleep != right.isLongSleep) {
        return left.isLongSleep ? -1 : 1;
      }
      return right.startedAt.compareTo(left.startedAt);
    });
  }

  HealthSleepSummary? get latestPrimarySleep {
    final segments = latestSleepDay;
    return segments.isEmpty ? null : segments.first;
  }

  int? get latestSleepDayDurationSeconds {
    final segments = latestSleepDay;
    if (segments.isEmpty) return null;
    return segments.fold<int>(
      0,
      (total, value) => total + value.durationSeconds,
    );
  }

  List<HealthSample> samplesFor(XiaomiHealthMetric metric) =>
      _cache.samplesByMetric[metric] ?? const <HealthSample>[];

  HealthSample? latestSample(XiaomiHealthMetric metric) {
    final values = samplesFor(metric).where((sample) => sample.isUsable);
    if (values.isEmpty) return null;
    return values.reduce(
      (left, right) => left.timestamp.isAfter(right.timestamp) ? left : right,
    );
  }

  Map<String, Object?> toJson() {
    List<Map<String, Object?>>? cachedSamples = _samplesJsonCache[samples];
    if (cachedSamples == null) {
      cachedSamples = samples.map((value) => value.toJson()).toList(growable: false);
      _samplesJsonCache[samples] = cachedSamples;
    }

    List<Map<String, Object?>>? cachedActivity = _activitySamplesJsonCache[activitySamples];
    if (cachedActivity == null) {
      cachedActivity = activitySamples.map((value) => value.toJson()).toList(growable: false);
      _activitySamplesJsonCache[activitySamples] = cachedActivity;
    }

    return {
      'schema': 2,
      'daily': daily.map((value) => value.toJson()).toList(growable: false),
      'samples': cachedSamples,
      'activitySamples': cachedActivity,
      'sleep': sleep.map((value) => value.toJson()).toList(growable: false),
      'workouts': workouts.map((value) => value.toJson()).toList(growable: false),
      'abnormalHealthRecords': abnormalHealthRecords
          .map((value) => value.toJson())
          .toList(growable: false),
      'capabilities': capabilities.toJson(),
      'lastSyncedAt': lastSyncedAt?.toIso8601String(),
    };
  }

  String encode() => jsonEncode(toJson());

  factory XiaomiHealthData.fromJson(Map<String, Object?> json) =>
      XiaomiHealthData(
        daily: _list(json['daily'], HealthDailySummary.fromJson),
        samples: _list(json['samples'], HealthSample.fromJson),
        activitySamples: _list(
          json['activitySamples'],
          HealthActivitySample.fromJson,
        ),
        sleep: _list(json['sleep'], HealthSleepSummary.fromJson),
        workouts: _list(json['workouts'], HealthWorkoutSummary.fromJson),
        abnormalHealthRecords: _abnormalHealthRecords(json),
        capabilities: json['capabilities'] is Map
            ? XiaomiHealthCapabilities.fromJson(
                (json['capabilities'] as Map).cast(),
              )
            : const XiaomiHealthCapabilities(),
        lastSyncedAt: json['lastSyncedAt'] == null
            ? null
            : DateTime.parse(json['lastSyncedAt']!.toString()),
      );

  factory XiaomiHealthData.decode(String value) =>
      XiaomiHealthData.fromJson((jsonDecode(value) as Map).cast());

  static bool _sameDate(DateTime left, DateTime right) {
    final localLeft = left.toLocal();
    final localRight = right.toLocal();
    return localLeft.year == localRight.year &&
        localLeft.month == localRight.month &&
        localLeft.day == localRight.day;
  }

  static DateTime _dateOnly(DateTime value) {
    final local = value.toLocal();
    return DateTime(local.year, local.month, local.day);
  }
}

final _healthDataCaches = Expando<_XiaomiHealthDataCache>();
final _samplesJsonCache = Expando<List<Map<String, Object?>>>();
final _activitySamplesJsonCache = Expando<List<Map<String, Object?>>>();
final _sampleListCaches = Expando<Map<XiaomiHealthMetric, List<HealthSample>>>();

extension on XiaomiHealthData {
  _XiaomiHealthDataCache get _cache =>
      _healthDataCaches[this] ??= _XiaomiHealthDataCache(this);
}

class _XiaomiHealthDataCache {
  _XiaomiHealthDataCache(XiaomiHealthData data) {
    final indexed = _indexSamples(data.samples);
    samplesByMetric = indexed;
    activitySummary = data._computeActivitySummary(indexed);
  }

  late final Map<XiaomiHealthMetric, List<HealthSample>> samplesByMetric;
  late final HealthDailySummary? activitySummary;
}

Map<XiaomiHealthMetric, List<HealthSample>> _indexSamples(
  List<HealthSample> samples,
) {
  final cached = _sampleListCaches[samples];
  if (cached != null) return cached;
  final indexed = <XiaomiHealthMetric, List<HealthSample>>{};
  for (final sample in samples) {
    indexed.putIfAbsent(sample.metric, () => <HealthSample>[]).add(sample);
  }
  final result = {
    for (final metric in XiaomiHealthMetric.values)
      metric: List<HealthSample>.unmodifiable(indexed[metric] ?? const []),
  };
  _sampleListCaches[samples] = result;
  return result;
}

class XiaomiHealthSyncResult {
  const XiaomiHealthSyncResult({
    required this.data,
    required this.updatedDaily,
    required this.updatedSamples,
    required this.updatedSleep,
    required this.updatedWorkouts,
    this.warning,
  });

  final XiaomiHealthData data;
  final bool updatedDaily;
  final bool updatedSamples;
  final bool updatedSleep;
  final bool updatedWorkouts;
  final String? warning;

  Map<String, Object?> toJson() => {
    'data': data.toJson(),
    'updatedDaily': updatedDaily,
    'updatedSamples': updatedSamples,
    'updatedSleep': updatedSleep,
    'updatedWorkouts': updatedWorkouts,
    if (warning != null) 'warning': warning,
  };

  factory XiaomiHealthSyncResult.fromJson(Map<String, Object?> json) =>
      XiaomiHealthSyncResult(
        data: XiaomiHealthData.fromJson((json['data'] as Map).cast()),
        updatedDaily: json['updatedDaily'] == true,
        updatedSamples: json['updatedSamples'] == true,
        updatedSleep: json['updatedSleep'] == true,
        updatedWorkouts: json['updatedWorkouts'] == true,
        warning: json['warning']?.toString(),
      );
}

Map<String, Object?> healthStatusSurfaceData(XiaomiHealthData data) {
  final activity = data.activitySummary ?? data.latestDay;
  final heartRate = data.latestSample(XiaomiHealthMetric.heartRate);
  final bloodOxygen = data.latestSample(XiaomiHealthMetric.bloodOxygen);
  final stress = data.latestSample(XiaomiHealthMetric.stress);
  final sleep = data.latestPrimarySleep;
  return {
    'steps': activity?.steps ?? -1,
    // `calories` is total energy (basal + active), not the activity ring.
    'activeCalories': activity?.activeCalories ?? -1,
    'standingHours': activity?.standingHours ?? -1,
    'heartRate': heartRate?.value.round() ?? activity?.averageHeartRate ?? -1,
    'heartRateAt': heartRate?.timestamp.millisecondsSinceEpoch ?? -1,
    'bloodOxygen':
        bloodOxygen?.value.round() ?? activity?.averageBloodOxygen ?? -1,
    'bloodOxygenAt': bloodOxygen?.timestamp.millisecondsSinceEpoch ?? -1,
    'stress': stress?.value.round() ?? activity?.averageStress ?? -1,
    'stressAt': stress?.timestamp.millisecondsSinceEpoch ?? -1,
    'vitality': activity?.vitalityCurrent ?? -1,
    'sleepDuration': data.latestSleepDayDurationSeconds ?? -1,
    'sleepStart': sleep?.startedAt.millisecondsSinceEpoch ?? -1,
    'sleepEnd': sleep?.endedAt.millisecondsSinceEpoch ?? -1,
    'updatedAt':
        data.lastSyncedAt?.millisecondsSinceEpoch ??
        DateTime.now().millisecondsSinceEpoch,
  };
}

int? _int(Object? value) => (value as num?)?.toInt();

double? _double(Object? value) => (value as num?)?.toDouble();

List<HealthAbnormalHealthRecord> _abnormalHealthRecords(
  Map<String, Object?> json,
) {
  final current = _list(
    json['abnormalHealthRecords'],
    HealthAbnormalHealthRecord.fromJson,
  );
  if (current.isNotEmpty || json.containsKey('abnormalHealthRecords')) {
    return current;
  }
  return _list(
        json['abnormalHeartRates'],
        HealthAbnormalHeartRateRecord.fromJson,
      )
      .map(
        (record) => HealthAbnormalHealthRecord(
          timestamp: record.timestamp,
          value: record.value,
          kind: record.kind == HealthAbnormalHeartRateKind.low
              ? HealthAbnormalHealthKind.lowHeartRate
              : HealthAbnormalHealthKind.highHeartRate,
          threshold: record.threshold,
          startedAt: record.startedAt,
          endedAt: record.endedAt,
        ),
      )
      .toList(growable: false);
}

bool? _bool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  return null;
}

DateTime? _dateTime(Object? value) =>
    value == null ? null : DateTime.tryParse(value.toString());

List<T> _list<T>(Object? value, T Function(Map<String, Object?> json) decode) =>
    (value as List? ?? const [])
        .whereType<Map>()
        .map((item) => decode(item.cast()))
        .toList(growable: false);
