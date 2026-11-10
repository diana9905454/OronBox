import 'dart:convert';
import 'dart:math' as math;

import 'health_models.dart';

/// Encodes a Xiaomi workout as a standards-compatible FIT activity file.
///
/// The exporter deliberately contains only the FIT messages that can be
/// populated from [HealthWorkoutSummary].  It does not invent sensor values:
/// fields that are absent from the source record are written with FIT's
/// invalid-value sentinel.
class HealthWorkoutFitExporter {
  HealthWorkoutFitExporter._();

  static const int _fitEpochSeconds = 631065600;
  static const int _profileVersion = 0x52ba; // FIT profile 21.178
  static const int _protocolVersion = 0x20; // FIT protocol 2.0
  static const int _syntheticProduct = 1;

  /// Returns the bytes of an FIT activity file for [workout].
  static List<int> encode(HealthWorkoutSummary workout) {
    final sport = _sportFor(workout);
    final start = _fitTimestamp(workout.startedAt);
    final duration = math
        .max(
          0,
          workout.totalDurationSeconds ??
              workout.endedAt.difference(workout.startedAt).inSeconds,
        )
        .toInt();
    final timerDuration = math
        .max(0, workout.effectiveDurationSeconds ?? duration)
        .toInt();
    final end = math.max(start, _fitTimestamp(workout.endedAt)).toInt();
    final endTimestamp = math.max(end, start + duration).toInt();
    final localStartTimestamp =
        start + workout.startedAt.timeZoneOffset.inSeconds;
    final localEndTimestamp =
        endTimestamp + workout.endedAt.timeZoneOffset.inSeconds;
    final points = _points(workout);
    final heartRateZoneDurations = _heartRateZoneDurations(workout);

    final data = <int>[];

    final fileId = _fileIdDefinition;
    data.addAll(fileId.bytes);
    data.add(fileId.localType);
    data.addAll(
      _FitMessage(fileId, {
        0: 4, // activity
        1: 255, // development manufacturer; this file is synthesized
        2: _syntheticProduct,
        3: 1,
        4: start,
        5: 0,
        8: 'OronBox',
      }).dataBytes(),
    );

    final deviceInfo = _deviceInfoDefinition;
    data.addAll(deviceInfo.bytes);
    data.add(deviceInfo.localType);
    data.addAll(
      _FitMessage(deviceInfo, {
        0: 0, // creator
        2: 255, // development manufacturer
        3: 1,
        4: _syntheticProduct,
        27: 'OronBox',
        253: start,
      }).dataBytes(),
    );

    final fileCreator = _fileCreatorDefinition;
    data.addAll(fileCreator.bytes);
    data.add(fileCreator.localType);
    data.addAll(
      _FitMessage(fileCreator, {0: 1, 1: 0, 2: 'OronBox'}).dataBytes(),
    );

    final timestampCorrelation = _timestampCorrelationDefinition;
    data.addAll(timestampCorrelation.bytes);
    data.add(timestampCorrelation.localType);
    data.addAll(
      _FitMessage(timestampCorrelation, {
        253: start,
        1: start,
        3: localStartTimestamp,
      }).dataBytes(),
    );

    final event = _eventDefinition;
    data.addAll(event.bytes);
    data.add(event.localType);
    data.addAll(
      _FitMessage(event, {
        253: start,
        0: 0, // timer
        1: 0, // start
        4: 0,
      }).dataBytes(),
    );

    if (points.isNotEmpty) {
      final record = _recordDefinition;
      data.addAll(record.bytes);
      for (final point in points) {
        data.add(record.localType);
        data.addAll(
          _FitMessage(record, {
            253: _fitTimestamp(point.timestamp),
            0: point.latitude,
            1: point.longitude,
            2: point.altitudeMeters,
            3: point.heartRate,
            4: point.cadence,
            5: point.distanceMeters,
            6: point.speedMetersPerSecond,
            7: point.powerWatts,
            19: point.steps,
            31: point.horizontalAccuracyMeters,
            33: point.calories,
            49: _swimStrokeFor(point.swimmingStroke),
            73: point.speedMetersPerSecond,
            78: point.altitudeMeters,
            85: point.stepLengthMillimeters,
            116: point.stress,
          }).dataBytes(),
        );
      }
    }

    final summary = _summaryMetrics(workout, points, duration);
    final lap = _lapDefinition;
    data.addAll(lap.bytes);
    data.add(lap.localType);
    data.addAll(
      _FitMessage(lap, {
        253: endTimestamp,
        0: 0, // timer
        1: 1, // stop
        2: start,
        3: summary.startLatitude,
        4: summary.startLongitude,
        5: summary.endLatitude,
        6: summary.endLongitude,
        7: duration,
        8: timerDuration,
        9: summary.distanceMeters,
        11: _totalCaloriesFor(workout),
        13: summary.averageSpeedMetersPerSecond,
        14: summary.maximumSpeedMetersPerSecond,
        15: workout.effectiveAverageHeartRate,
        16: workout.effectiveMaximumHeartRate,
        17: _averageCadenceFor(workout),
        18: _maximumCadenceFor(workout),
        19: workout.averagePowerWatts,
        20: workout.maximumPowerWatts,
        21: workout.totalAscentMeters,
        22: workout.totalDescentMeters,
        23: 0, // active
        24: 0, // manual lap trigger
        25: sport.sport,
        26: 0,
        39: sport.subSport,
        42: workout.averageAltitudeMeters,
        43: workout.maximumAltitudeMeters,
        57: heartRateZoneDurations,
        62: workout.minimumAltitudeMeters,
        63: workout.effectiveMinimumHeartRate,
        10: _totalCyclesFor(workout),
        75: _totalStrokeCountFor(workout),
        120: _stepLengthMillimeters(workout.averageStrideCentimeters),
        151: workout.totalJumps,
        38: _swimStrokeFor(workout.mainSwimmingStroke),
      }).dataBytes(),
    );

    final session = _sessionDefinition;
    data.addAll(session.bytes);
    data.add(session.localType);
    data.addAll(
      _FitMessage(session, {
        253: endTimestamp,
        0: 0, // timer
        1: 1, // stop
        2: start,
        3: summary.startLatitude,
        4: summary.startLongitude,
        5: sport.sport,
        6: sport.subSport,
        7: duration,
        8: timerDuration,
        9: summary.distanceMeters,
        10: _totalCyclesFor(workout),
        11: _totalCaloriesFor(workout),
        14: summary.averageSpeedMetersPerSecond,
        15: summary.maximumSpeedMetersPerSecond,
        16: workout.effectiveAverageHeartRate,
        17: workout.effectiveMaximumHeartRate,
        18: _averageCadenceFor(workout),
        19: _maximumCadenceFor(workout),
        20: workout.averagePowerWatts,
        21: workout.maximumPowerWatts,
        22: workout.totalAscentMeters,
        23: workout.totalDescentMeters,
        24: workout.aerobicTrainingEffect,
        25: 0,
        26: 1,
        27: 0,
        28: 0, // activity end
        38: summary.endLatitude,
        39: summary.endLongitude,
        43: _swimStrokeFor(workout.mainSwimmingStroke),
        44: workout.poolWidthMeters,
        49: workout.averageAltitudeMeters,
        50: workout.maximumAltitudeMeters,
        64: workout.effectiveMinimumHeartRate,
        65: heartRateZoneDurations,
        71: workout.minimumAltitudeMeters,
        134: _stepLengthMillimeters(workout.averageStrideCentimeters),
        137: workout.anaerobicTrainingEffect,
        183: workout.totalJumps,
        194: workout.averageBloodOxygen,
        195: workout.averageStress,
      }).dataBytes(),
    );

    data.add(event.localType);
    data.addAll(
      _FitMessage(event, {
        253: endTimestamp,
        0: 0,
        1: 9, // stop all
        4: 0,
      }).dataBytes(),
    );

    final activity = _activityDefinition;
    data.addAll(activity.bytes);
    data.add(activity.localType);
    data.addAll(
      _FitMessage(activity, {
        0: timerDuration,
        1: 1,
        2: 0, // manual
        3: 26, // activity
        4: 1, // stop
        5: localEndTimestamp,
        6: 0,
        253: endTimestamp,
      }).dataBytes(),
    );

    return _withHeader(data);
  }

  static const _fileIdDefinition = _FitDefinition(
    localType: 0,
    globalType: 0,
    fields: [
      _FitField(0, 1, _FitBaseType.enumType),
      _FitField(1, 2, _FitBaseType.uint16),
      _FitField(2, 2, _FitBaseType.uint16),
      _FitField(3, 4, _FitBaseType.uint32z),
      _FitField(4, 4, _FitBaseType.uint32),
      _FitField(5, 2, _FitBaseType.uint16),
      _FitField(8, 20, _FitBaseType.string),
    ],
  );

  static const _deviceInfoDefinition = _FitDefinition(
    localType: 1,
    globalType: 23,
    fields: [
      _FitField(253, 4, _FitBaseType.uint32),
      _FitField(0, 1, _FitBaseType.uint8),
      _FitField(2, 2, _FitBaseType.uint16),
      _FitField(3, 4, _FitBaseType.uint32z),
      _FitField(4, 2, _FitBaseType.uint16),
      _FitField(27, 16, _FitBaseType.string),
    ],
  );

  static const _fileCreatorDefinition = _FitDefinition(
    localType: 2,
    globalType: 49,
    fields: [
      _FitField(0, 2, _FitBaseType.uint16),
      _FitField(1, 1, _FitBaseType.uint8),
      _FitField(2, 16, _FitBaseType.string),
    ],
  );

  static const _timestampCorrelationDefinition = _FitDefinition(
    localType: 3,
    globalType: 162,
    fields: [
      _FitField(253, 4, _FitBaseType.uint32),
      _FitField(1, 4, _FitBaseType.uint32),
      _FitField(3, 4, _FitBaseType.uint32),
    ],
  );

  static const _eventDefinition = _FitDefinition(
    localType: 4,
    globalType: 21,
    fields: [
      _FitField(253, 4, _FitBaseType.uint32),
      _FitField(0, 1, _FitBaseType.enumType),
      _FitField(1, 1, _FitBaseType.enumType),
      _FitField(4, 1, _FitBaseType.uint8),
    ],
  );

  static const _recordDefinition = _FitDefinition(
    localType: 5,
    globalType: 20,
    fields: [
      _FitField(253, 4, _FitBaseType.uint32),
      _FitField(0, 4, _FitBaseType.sint32, coordinate: true),
      _FitField(1, 4, _FitBaseType.sint32, coordinate: true),
      _FitField(2, 2, _FitBaseType.uint16, scale: 5, offset: 500),
      _FitField(3, 1, _FitBaseType.uint8),
      _FitField(4, 1, _FitBaseType.uint8),
      _FitField(5, 4, _FitBaseType.uint32, scale: 100),
      _FitField(6, 2, _FitBaseType.uint16, scale: 1000),
      _FitField(7, 2, _FitBaseType.uint16),
      _FitField(19, 4, _FitBaseType.uint32),
      _FitField(31, 1, _FitBaseType.uint8),
      _FitField(33, 2, _FitBaseType.uint16),
      _FitField(49, 1, _FitBaseType.enumType),
      _FitField(73, 4, _FitBaseType.uint32, scale: 1000),
      _FitField(78, 4, _FitBaseType.uint32, scale: 5, offset: 500),
      _FitField(85, 2, _FitBaseType.uint16, scale: 10),
      _FitField(116, 2, _FitBaseType.uint16, scale: 100),
    ],
  );

  static const _lapDefinition = _FitDefinition(
    localType: 6,
    globalType: 19,
    fields: [
      _FitField(253, 4, _FitBaseType.uint32),
      _FitField(0, 1, _FitBaseType.enumType),
      _FitField(1, 1, _FitBaseType.enumType),
      _FitField(2, 4, _FitBaseType.uint32),
      _FitField(3, 4, _FitBaseType.sint32, coordinate: true),
      _FitField(4, 4, _FitBaseType.sint32, coordinate: true),
      _FitField(5, 4, _FitBaseType.sint32, coordinate: true),
      _FitField(6, 4, _FitBaseType.sint32, coordinate: true),
      _FitField(7, 4, _FitBaseType.uint32, scale: 1000),
      _FitField(8, 4, _FitBaseType.uint32, scale: 1000),
      _FitField(9, 4, _FitBaseType.uint32, scale: 100),
      _FitField(10, 4, _FitBaseType.uint32),
      _FitField(11, 2, _FitBaseType.uint16),
      _FitField(13, 2, _FitBaseType.uint16, scale: 1000),
      _FitField(14, 2, _FitBaseType.uint16, scale: 1000),
      _FitField(15, 1, _FitBaseType.uint8),
      _FitField(16, 1, _FitBaseType.uint8),
      _FitField(17, 1, _FitBaseType.uint8),
      _FitField(18, 1, _FitBaseType.uint8),
      _FitField(19, 2, _FitBaseType.uint16),
      _FitField(20, 2, _FitBaseType.uint16),
      _FitField(21, 2, _FitBaseType.uint16),
      _FitField(22, 2, _FitBaseType.uint16),
      _FitField(23, 1, _FitBaseType.enumType),
      _FitField(24, 1, _FitBaseType.enumType),
      _FitField(25, 1, _FitBaseType.enumType),
      _FitField(26, 1, _FitBaseType.uint8),
      _FitField(38, 1, _FitBaseType.enumType),
      _FitField(39, 1, _FitBaseType.enumType),
      _FitField(42, 2, _FitBaseType.uint16, scale: 5, offset: 500),
      _FitField(43, 2, _FitBaseType.uint16, scale: 5, offset: 500),
      _FitField(57, 4, _FitBaseType.uint32, scale: 1000, arrayLength: 5),
      _FitField(62, 2, _FitBaseType.uint16, scale: 5, offset: 500),
      _FitField(63, 1, _FitBaseType.uint8),
      _FitField(75, 2, _FitBaseType.uint16),
      _FitField(120, 2, _FitBaseType.uint16, scale: 10),
      _FitField(151, 2, _FitBaseType.uint16),
    ],
  );

  static const _sessionDefinition = _FitDefinition(
    localType: 7,
    globalType: 18,
    fields: [
      _FitField(253, 4, _FitBaseType.uint32),
      _FitField(0, 1, _FitBaseType.enumType),
      _FitField(1, 1, _FitBaseType.enumType),
      _FitField(2, 4, _FitBaseType.uint32),
      _FitField(3, 4, _FitBaseType.sint32, coordinate: true),
      _FitField(4, 4, _FitBaseType.sint32, coordinate: true),
      _FitField(5, 1, _FitBaseType.enumType),
      _FitField(6, 1, _FitBaseType.enumType),
      _FitField(7, 4, _FitBaseType.uint32, scale: 1000),
      _FitField(8, 4, _FitBaseType.uint32, scale: 1000),
      _FitField(9, 4, _FitBaseType.uint32, scale: 100),
      _FitField(10, 4, _FitBaseType.uint32),
      _FitField(11, 2, _FitBaseType.uint16),
      _FitField(14, 2, _FitBaseType.uint16, scale: 1000),
      _FitField(15, 2, _FitBaseType.uint16, scale: 1000),
      _FitField(16, 1, _FitBaseType.uint8),
      _FitField(17, 1, _FitBaseType.uint8),
      _FitField(18, 1, _FitBaseType.uint8),
      _FitField(19, 1, _FitBaseType.uint8),
      _FitField(20, 2, _FitBaseType.uint16),
      _FitField(21, 2, _FitBaseType.uint16),
      _FitField(22, 2, _FitBaseType.uint16),
      _FitField(23, 2, _FitBaseType.uint16),
      _FitField(24, 1, _FitBaseType.uint8, scale: 10),
      _FitField(25, 2, _FitBaseType.uint16),
      _FitField(26, 2, _FitBaseType.uint16),
      _FitField(27, 1, _FitBaseType.uint8),
      _FitField(28, 1, _FitBaseType.enumType),
      _FitField(38, 4, _FitBaseType.sint32, coordinate: true),
      _FitField(39, 4, _FitBaseType.sint32, coordinate: true),
      _FitField(43, 1, _FitBaseType.enumType),
      _FitField(44, 2, _FitBaseType.uint16, scale: 100),
      _FitField(49, 2, _FitBaseType.uint16, scale: 5, offset: 500),
      _FitField(50, 2, _FitBaseType.uint16, scale: 5, offset: 500),
      _FitField(64, 1, _FitBaseType.uint8),
      _FitField(65, 4, _FitBaseType.uint32, scale: 1000, arrayLength: 5),
      _FitField(71, 2, _FitBaseType.uint16, scale: 5, offset: 500),
      _FitField(134, 2, _FitBaseType.uint16, scale: 10),
      _FitField(137, 1, _FitBaseType.uint8, scale: 10),
      _FitField(183, 2, _FitBaseType.uint16),
      _FitField(194, 1, _FitBaseType.uint8),
      _FitField(195, 1, _FitBaseType.uint8),
    ],
  );

  static const _activityDefinition = _FitDefinition(
    localType: 8,
    globalType: 34,
    fields: [
      _FitField(0, 4, _FitBaseType.uint32, scale: 1000),
      _FitField(1, 2, _FitBaseType.uint16),
      _FitField(2, 1, _FitBaseType.enumType),
      _FitField(3, 1, _FitBaseType.enumType),
      _FitField(4, 1, _FitBaseType.enumType),
      _FitField(5, 4, _FitBaseType.uint32),
      _FitField(6, 1, _FitBaseType.uint8),
      _FitField(253, 4, _FitBaseType.uint32),
    ],
  );

  static List<_WorkoutPoint> _points(HealthWorkoutSummary workout) {
    final samples = [...workout.samples]
      ..sort((left, right) => left.timestamp.compareTo(right.timestamp));
    final route = [...workout.route]
      ..sort((left, right) => left.timestamp.compareTo(right.timestamp));
    final points = <_WorkoutPoint>[];
    for (final sample in samples) {
      final routePoint = _nearestRoutePoint(route, sample.timestamp);
      points.add(_WorkoutPoint.fromSample(sample, routePoint));
    }
    for (final routePoint in route) {
      final hasSample = samples.any(
        (sample) =>
            (sample.timestamp.difference(routePoint.timestamp).inMilliseconds)
                .abs() <=
            2000,
      );
      if (!hasSample) points.add(_WorkoutPoint.fromRoute(routePoint));
    }
    points.sort((left, right) => left.timestamp.compareTo(right.timestamp));
    return points.where(_hasRecordValue).toList(growable: false);
  }

  static bool _hasRecordValue(_WorkoutPoint point) =>
      point.latitude != null ||
      point.longitude != null ||
      point.altitudeMeters != null ||
      point.heartRate != null ||
      point.distanceMeters != null ||
      point.speedMetersPerSecond != null ||
      point.cadence != null ||
      point.powerWatts != null ||
      point.calories != null ||
      point.steps != null ||
      point.horizontalAccuracyMeters != null ||
      point.stepLengthMillimeters != null ||
      point.stress != null ||
      _swimStrokeFor(point.swimmingStroke) != null;

  static HealthWorkoutRoutePoint? _nearestRoutePoint(
    List<HealthWorkoutRoutePoint> route,
    DateTime timestamp,
  ) {
    HealthWorkoutRoutePoint? nearest;
    var distance = 2001;
    for (final point in route) {
      final candidate = point.timestamp
          .difference(timestamp)
          .inMilliseconds
          .abs();
      if (candidate <= distance) {
        distance = candidate;
        nearest = point;
      }
    }
    return nearest;
  }

  static List<int>? _heartRateZoneDurations(HealthWorkoutSummary workout) {
    if (workout.heartRateZones.isEmpty) return null;
    final durations = List<int>.filled(5, 0);
    var hasValue = false;
    for (final zone in workout.heartRateZones) {
      if (zone.zone < 1 || zone.zone > durations.length) continue;
      final duration = math.max(0, zone.durationSeconds);
      durations[zone.zone - 1] += duration;
      hasValue = true;
    }
    return hasValue ? durations : null;
  }

  static double? _stepLengthMillimeters(int? centimeters) =>
      centimeters == null ? null : centimeters * 10.0;

  static int? _swimStrokeFor(int? raw) => switch (raw) {
    0 || 1 || 2 || 3 => raw,
    4 => 5, // Xiaomi mixed -> FIT mixed (FIT 4 is drill)
    _ => null,
  };

  static int? _totalCyclesFor(HealthWorkoutSummary workout) {
    if (workout.totalSteps != null) return workout.totalSteps;
    final sport = _sportFor(workout).sport;
    if (sport == 5 || sport == 15) return _totalStrokeCountFor(workout);
    return null;
  }

  static int? _totalStrokeCountFor(HealthWorkoutSummary workout) =>
      workout.totalStrokes ?? workout.totalArmPulls;

  static int? _totalCaloriesFor(HealthWorkoutSummary workout) =>
      workout.calories ?? workout.activeCalories;

  static int? _averageCadenceFor(HealthWorkoutSummary workout) {
    if (workout.averageCadence != null) return workout.averageCadence;
    final sport = _sportFor(workout).sport;
    return sport == 15 ? workout.averageRowingFrequency : null;
  }

  static int? _maximumCadenceFor(HealthWorkoutSummary workout) {
    if (workout.maximumCadence != null) return workout.maximumCadence;
    final sport = _sportFor(workout).sport;
    return sport == 15 ? workout.bestRowingFrequency : null;
  }

  static _SummaryMetrics _summaryMetrics(
    HealthWorkoutSummary workout,
    List<_WorkoutPoint> points,
    int duration,
  ) {
    final speeds = points
        .map((point) => point.speedMetersPerSecond)
        .whereType<double>()
        .where((value) => value >= 0)
        .toList(growable: false);
    final distance =
        workout.distanceMeters?.toDouble() ??
        points
            .map((point) => point.distanceMeters)
            .whereType<double>()
            .fold<double?>(
              null,
              (max, value) => max == null || value > max ? value : max,
            );
    final averageSpeed = workout.averageSpeedKph != null
        ? workout.averageSpeedKph! / 3.6
        : workout.averagePaceSecondsPerKilometer != null &&
              workout.averagePaceSecondsPerKilometer! > 0
        ? 1000 / workout.averagePaceSecondsPerKilometer!
        : (distance == null || duration <= 0 ? null : distance / duration);
    final coordinatePoints = points
        .where((point) => point.latitude != null && point.longitude != null)
        .toList(growable: false);
    return _SummaryMetrics(
      distanceMeters: distance,
      averageSpeedMetersPerSecond: averageSpeed,
      maximumSpeedMetersPerSecond: workout.bestSpeedKph != null
          ? workout.bestSpeedKph! / 3.6
          : workout.bestPaceSecondsPerKilometer != null &&
                workout.bestPaceSecondsPerKilometer! > 0
          ? 1000 / workout.bestPaceSecondsPerKilometer!
          : (speeds.isEmpty ? null : speeds.reduce((a, b) => a > b ? a : b)),
      startLatitude: coordinatePoints.firstOrNull?.latitude,
      startLongitude: coordinatePoints.firstOrNull?.longitude,
      endLatitude: coordinatePoints.lastOrNull?.latitude,
      endLongitude: coordinatePoints.lastOrNull?.longitude,
    );
  }

  static ({int sport, int subSport}) _sportFor(HealthWorkoutSummary workout) {
    if (workout.activityType == 22) {
      return switch (workout.subSportType) {
        2 || 207 => (sport: 11, subSport: 0),
        4 => (sport: 16, subSport: 0),
        15 => (sport: 17, subSport: 0),
        5 => (sport: 1, subSport: 3),
        _ => (sport: 1, subSport: 0),
      };
    }
    return switch (workout.activityType) {
      1 => (sport: 1, subSport: 2),
      2 => (sport: 11, subSport: 0),
      3 => (sport: 1, subSport: 1),
      4 => (sport: 16, subSport: 0),
      5 => (sport: 1, subSport: 3),
      6 => (sport: 2, subSport: 7),
      7 => (sport: 2, subSport: 6),
      8 => (sport: 10, subSport: 0),
      9 => (sport: 5, subSport: 17),
      10 => (sport: 5, subSport: 18),
      11 => (sport: 4, subSport: 15),
      13 => (sport: 15, subSport: 14),
      14 => (sport: 84, subSport: 0),
      15 => (sport: 17, subSport: 0),
      23 => (sport: 2, subSport: 7),
      _ => (sport: 0, subSport: 0),
    };
  }

  static int _fitTimestamp(DateTime value) {
    final seconds = value.toUtc().millisecondsSinceEpoch ~/ 1000;
    return math.max(0, seconds - _fitEpochSeconds);
  }

  static List<int> _withHeader(List<int> data) {
    final header = <int>[
      14,
      _protocolVersion,
      _profileVersion & 0xff,
      (_profileVersion >> 8) & 0xff,
      data.length & 0xff,
      (data.length >> 8) & 0xff,
      (data.length >> 16) & 0xff,
      (data.length >> 24) & 0xff,
      0x2e,
      0x46,
      0x49,
      0x54,
    ];
    final headerCrc = _crc(header);
    header.add(headerCrc & 0xff);
    header.add((headerCrc >> 8) & 0xff);
    final fileCrc = _crc([...header, ...data]);
    return [...header, ...data, fileCrc & 0xff, (fileCrc >> 8) & 0xff];
  }

  static int _crc(List<int> bytes) {
    const constants = <int>[
      0x0000,
      0xcc01,
      0xd801,
      0x1400,
      0xf001,
      0x3c00,
      0x2800,
      0xe401,
      0xa001,
      0x6c00,
      0x7800,
      0xb401,
      0x5000,
      0x9c01,
      0x8801,
      0x4400,
    ];
    var crc = 0;
    for (final value in bytes) {
      final byte = value & 0xff;
      crc =
          (((crc >> 4) & 0xfff) ^ constants[crc & 0xf]) ^ constants[byte & 0xf];
      crc =
          (((crc >> 4) & 0xfff) ^ constants[crc & 0xf]) ^
          constants[(byte >> 4) & 0xf];
    }
    return crc & 0xffff;
  }
}

class _FitMessage {
  const _FitMessage(this.definition, this.values);

  final _FitDefinition definition;
  final Map<int, Object?> values;

  List<int> dataBytes() => [
    for (final field in definition.fields)
      ...field.encode(values[field.number]),
  ];
}

class _FitDefinition {
  const _FitDefinition({
    required this.localType,
    required this.globalType,
    required this.fields,
  });

  final int localType;
  final int globalType;
  final List<_FitField> fields;

  List<int> get bytes => [
    0x40 | localType,
    0,
    0,
    globalType & 0xff,
    (globalType >> 8) & 0xff,
    fields.length,
    for (final field in fields) ...[
      field.number,
      field.encodedSize,
      field.baseType.identifier,
    ],
  ];
}

class _FitField {
  const _FitField(
    this.number,
    this.size,
    this.baseType, {
    this.scale,
    this.offset,
    this.coordinate = false,
    this.arrayLength = 1,
  });

  final int number;
  final int size;
  final _FitBaseType baseType;
  final double? scale;
  final double? offset;
  final bool coordinate;
  final int arrayLength;

  int get encodedSize => size * arrayLength;

  List<int> encode(Object? value) {
    if (arrayLength > 1) {
      final values = value is Iterable ? value.toList() : const <Object?>[];
      return [
        for (var index = 0; index < arrayLength; index++)
          ..._encodeScalar(index < values.length ? values[index] : null),
      ];
    }
    return _encodeScalar(value);
  }

  List<int> _encodeScalar(Object? value) {
    if (baseType == _FitBaseType.string) {
      final bytes = value == null
          ? const <int>[]
          : utf8.encode(value.toString());
      return [
        ...bytes.take(size > 0 ? size - 1 : 0),
        0,
        ...List<int>.filled(math.max(0, size - bytes.length - 1).toInt(), 0),
      ].take(size).toList(growable: false);
    }
    if (value == null) return baseType.invalidBytes(size);
    final number = value is num ? value.toDouble() : double.tryParse('$value');
    if (number == null || !number.isFinite) {
      return baseType.invalidBytes(size);
    }
    final raw = coordinate
        ? (number * 2147483648 / 180).round()
        : ((number + (offset ?? 0)) * (scale ?? 1)).round();
    if (!_isValidRaw(raw)) return baseType.invalidBytes(size);
    return baseType.encode(raw, size);
  }

  bool _isValidRaw(int raw) {
    final bits = size * 8;
    return switch (baseType) {
      _FitBaseType.sint8 || _FitBaseType.sint16 || _FitBaseType.sint32 =>
        raw >= -(1 << (bits - 1)) && raw < (1 << (bits - 1)) - 1,
      _FitBaseType.uint32z => raw > 0 && raw <= (1 << bits) - 1,
      _FitBaseType.enumType ||
      _FitBaseType.uint8 ||
      _FitBaseType.uint16 ||
      _FitBaseType.uint32 => raw >= 0 && raw < (1 << bits) - 1,
      _FitBaseType.string => false,
    };
  }
}

enum _FitBaseType {
  enumType(0x00),
  sint8(0x01),
  uint8(0x02),
  sint16(0x83),
  uint16(0x84),
  sint32(0x85),
  uint32(0x86),
  string(0x07),
  uint32z(0x8c);

  const _FitBaseType(this.identifier);

  final int identifier;

  List<int> encode(int value, int size) {
    switch (this) {
      case _FitBaseType.sint8:
      case _FitBaseType.uint8:
      case _FitBaseType.enumType:
      case _FitBaseType.string:
        return [value & 0xff];
      case _FitBaseType.sint16:
      case _FitBaseType.uint16:
        return [value & 0xff, (value >> 8) & 0xff];
      case _FitBaseType.sint32:
      case _FitBaseType.uint32:
      case _FitBaseType.uint32z:
        return [
          value & 0xff,
          (value >> 8) & 0xff,
          (value >> 16) & 0xff,
          (value >> 24) & 0xff,
        ];
    }
  }

  List<int> invalidBytes(int size) {
    final raw = switch (this) {
      _FitBaseType.sint8 => 0x7f,
      _FitBaseType.sint16 => 0x7fff,
      _FitBaseType.sint32 => 0x7fffffff,
      _FitBaseType.enumType ||
      _FitBaseType.uint8 ||
      _FitBaseType.uint16 ||
      _FitBaseType.uint32 => (1 << (size * 8)) - 1,
      _FitBaseType.uint32z => 0,
      _FitBaseType.string => 0,
    };
    return encode(raw, size);
  }
}

class _WorkoutPoint {
  const _WorkoutPoint({
    required this.timestamp,
    this.latitude,
    this.longitude,
    this.altitudeMeters,
    this.heartRate,
    this.bloodOxygen,
    this.stress,
    this.distanceMeters,
    this.speedMetersPerSecond,
    this.cadence,
    this.powerWatts,
    this.calories,
    this.steps,
    this.horizontalAccuracyMeters,
    this.stepLengthMillimeters,
    this.swimmingStroke,
  });

  factory _WorkoutPoint.fromSample(
    HealthWorkoutSample sample,
    HealthWorkoutRoutePoint? route,
  ) => _WorkoutPoint(
    timestamp: sample.timestamp,
    latitude: route?.latitude,
    longitude: route?.longitude,
    altitudeMeters: sample.altitudeMeters ?? route?.altitudeMeters,
    heartRate: sample.heartRate,
    bloodOxygen: sample.bloodOxygen,
    stress: sample.stress,
    calories: sample.calories,
    steps: sample.steps,
    distanceMeters: sample.distanceMeters?.toDouble(),
    speedMetersPerSecond: sample.speedKph != null
        ? sample.speedKph! / 3.6
        : sample.paceSecondsPerKilometer != null &&
              sample.paceSecondsPerKilometer! > 0
        ? 1000 / sample.paceSecondsPerKilometer!
        : sample.swimmingPaceSecondsPer100Meters != null &&
              sample.swimmingPaceSecondsPer100Meters! > 0
        ? 100 / sample.swimmingPaceSecondsPer100Meters!
        : route?.speedMetersPerSecond,
    cadence: sample.cadence ?? sample.strokeFrequency,
    powerWatts: sample.powerWatts,
    horizontalAccuracyMeters: route?.horizontalAccuracyMeters,
    stepLengthMillimeters: HealthWorkoutFitExporter._stepLengthMillimeters(
      sample.strideCentimeters,
    ),
    swimmingStroke: sample.swimmingStroke,
  );

  factory _WorkoutPoint.fromRoute(HealthWorkoutRoutePoint point) =>
      _WorkoutPoint(
        timestamp: point.timestamp,
        latitude: point.latitude,
        longitude: point.longitude,
        altitudeMeters: point.altitudeMeters,
        speedMetersPerSecond: point.speedMetersPerSecond,
        horizontalAccuracyMeters: point.horizontalAccuracyMeters,
      );

  final DateTime timestamp;
  final double? latitude;
  final double? longitude;
  final double? altitudeMeters;
  final int? heartRate;
  final int? bloodOxygen;
  final int? stress;
  final double? distanceMeters;
  final double? speedMetersPerSecond;
  final int? cadence;
  final int? powerWatts;
  final int? calories;
  final int? steps;
  final double? horizontalAccuracyMeters;
  final double? stepLengthMillimeters;
  final int? swimmingStroke;
}

class _SummaryMetrics {
  const _SummaryMetrics({
    this.distanceMeters,
    this.averageSpeedMetersPerSecond,
    this.maximumSpeedMetersPerSecond,
    this.startLatitude,
    this.startLongitude,
    this.endLatitude,
    this.endLongitude,
  });

  final double? distanceMeters;
  final double? averageSpeedMetersPerSecond;
  final double? maximumSpeedMetersPerSecond;
  final double? startLatitude;
  final double? startLongitude;
  final double? endLatitude;
  final double? endLongitude;
}
