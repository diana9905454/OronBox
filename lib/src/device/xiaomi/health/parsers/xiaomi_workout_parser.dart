import 'dart:typed_data';

import 'xiaomi_activity_parser.dart';

class XiaomiWorkoutParser {
  const XiaomiWorkoutParser({this.timezoneOffset15Min});

  final int? timezoneOffset15Min;

  DateTime _activityTimestamp(int seconds) => xiaomiActivityTimestamp(
    seconds,
    timezoneOffset15Min: timezoneOffset15Min,
  );

  static List<XiaomiActivityWorkoutRecord> mergeWorkoutRecords(
    List<XiaomiActivityWorkoutRecord> values,
  ) {
    final sorted = [...values]
      ..sort((left, right) => left.startedAt.compareTo(right.startedAt));
    final merged = <XiaomiActivityWorkoutRecord>[];
    for (final value in sorted) {
      final index = merged.indexWhere(
        (candidate) => _sameWorkoutRecord(candidate, value),
      );
      if (index < 0) {
        merged.add(value);
      } else {
        merged[index] = mergeWorkoutRecord(merged[index], value);
      }
    }
    return merged;
  }

  static bool _sameWorkoutRecord(
    XiaomiActivityWorkoutRecord left,
    XiaomiActivityWorkoutRecord right,
  ) {
    if (left.activityType != right.activityType ||
        (isWorkoutSummary(left) && isWorkoutSummary(right))) {
      return false;
    }
    // Report, record, GPS and recovery files for one session normally share
    // the file timestamp. A resumed record can start a few minutes later, so
    // also accept overlapping intervals, but never collapse two adjacent
    // sessions solely because they are within an arbitrary ten-minute window.
    final startsClose =
        left.startedAt.difference(right.startedAt).abs() <=
        const Duration(minutes: 1);
    final overlaps =
        left.startedAt.isBefore(right.endedAt) &&
        right.startedAt.isBefore(left.endedAt);
    return startsClose || overlaps;
  }

  static XiaomiActivityWorkoutRecord mergeWorkoutRecord(
    XiaomiActivityWorkoutRecord left,
    XiaomiActivityWorkoutRecord right,
  ) {
    final leftSummary = isWorkoutSummary(left);
    final rightSummary = isWorkoutSummary(right);
    final primary = rightSummary && !leftSummary ? right : left;
    final secondary = identical(primary, left) ? right : left;
    final samples = [...left.samples, ...right.samples]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final route = [...left.route, ...right.route]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return XiaomiActivityWorkoutRecord(
      startedAt: left.startedAt.isBefore(right.startedAt)
          ? left.startedAt
          : right.startedAt,
      endedAt: left.endedAt.isAfter(right.endedAt)
          ? left.endedAt
          : right.endedAt,
      activityType: primary.activityType,
      subSportType: primary.subSportType ?? secondary.subSportType,
      distanceMeters: primary.distanceMeters ?? secondary.distanceMeters,
      calories: primary.calories ?? secondary.calories,
      averageHeartRate: primary.averageHeartRate ?? secondary.averageHeartRate,
      maximumHeartRate: primary.maximumHeartRate ?? secondary.maximumHeartRate,
      minimumHeartRate: primary.minimumHeartRate ?? secondary.minimumHeartRate,
      totalDurationSeconds:
          primary.totalDurationSeconds ?? secondary.totalDurationSeconds,
      effectiveDurationSeconds:
          primary.effectiveDurationSeconds ??
          secondary.effectiveDurationSeconds,
      activeCalories: primary.activeCalories ?? secondary.activeCalories,
      averagePaceSecondsPerKilometer:
          primary.averagePaceSecondsPerKilometer ??
          secondary.averagePaceSecondsPerKilometer,
      bestPaceSecondsPerKilometer:
          primary.bestPaceSecondsPerKilometer ??
          secondary.bestPaceSecondsPerKilometer,
      worstPaceSecondsPerKilometer:
          primary.worstPaceSecondsPerKilometer ??
          secondary.worstPaceSecondsPerKilometer,
      averageSpeedKph: primary.averageSpeedKph ?? secondary.averageSpeedKph,
      bestSpeedKph: primary.bestSpeedKph ?? secondary.bestSpeedKph,
      totalSteps: primary.totalSteps ?? secondary.totalSteps,
      averageStrideCentimeters:
          primary.averageStrideCentimeters ??
          secondary.averageStrideCentimeters,
      averageCadence: primary.averageCadence ?? secondary.averageCadence,
      maximumCadence: primary.maximumCadence ?? secondary.maximumCadence,
      averageBloodOxygen:
          primary.averageBloodOxygen ?? secondary.averageBloodOxygen,
      maximumBloodOxygen:
          primary.maximumBloodOxygen ?? secondary.maximumBloodOxygen,
      minimumBloodOxygen:
          primary.minimumBloodOxygen ?? secondary.minimumBloodOxygen,
      averageStress: primary.averageStress ?? secondary.averageStress,
      maximumStress: primary.maximumStress ?? secondary.maximumStress,
      minimumStress: primary.minimumStress ?? secondary.minimumStress,
      totalAscentMeters:
          primary.totalAscentMeters ?? secondary.totalAscentMeters,
      totalDescentMeters:
          primary.totalDescentMeters ?? secondary.totalDescentMeters,
      averageAltitudeMeters:
          primary.averageAltitudeMeters ?? secondary.averageAltitudeMeters,
      maximumAltitudeMeters:
          primary.maximumAltitudeMeters ?? secondary.maximumAltitudeMeters,
      minimumAltitudeMeters:
          primary.minimumAltitudeMeters ?? secondary.minimumAltitudeMeters,
      aerobicTrainingEffect:
          primary.aerobicTrainingEffect ?? secondary.aerobicTrainingEffect,
      anaerobicTrainingEffect:
          primary.anaerobicTrainingEffect ?? secondary.anaerobicTrainingEffect,
      peakTrainingEffect:
          primary.peakTrainingEffect ?? secondary.peakTrainingEffect,
      vo2Max: primary.vo2Max ?? secondary.vo2Max,
      bodyEnergyConsumption:
          primary.bodyEnergyConsumption ?? secondary.bodyEnergyConsumption,
      expectedRecoveryHours:
          primary.expectedRecoveryHours ?? secondary.expectedRecoveryHours,
      trainingLoad: primary.trainingLoad ?? secondary.trainingLoad,
      earnedVitality: primary.earnedVitality ?? secondary.earnedVitality,
      heartRateZoneMethod:
          primary.heartRateZoneMethod ?? secondary.heartRateZoneMethod,
      heartRateZones: primary.heartRateZones.isNotEmpty
          ? primary.heartRateZones
          : secondary.heartRateZones,
      averagePowerWatts:
          primary.averagePowerWatts ?? secondary.averagePowerWatts,
      maximumPowerWatts:
          primary.maximumPowerWatts ?? secondary.maximumPowerWatts,
      totalArmPulls: primary.totalArmPulls ?? secondary.totalArmPulls,
      mainSwimmingStroke:
          primary.mainSwimmingStroke ?? secondary.mainSwimmingStroke,
      averageStrokeFrequency:
          primary.averageStrokeFrequency ?? secondary.averageStrokeFrequency,
      maximumStrokeFrequency:
          primary.maximumStrokeFrequency ?? secondary.maximumStrokeFrequency,
      turnCount: primary.turnCount ?? secondary.turnCount,
      averageSwolf: primary.averageSwolf ?? secondary.averageSwolf,
      bestSwolf: primary.bestSwolf ?? secondary.bestSwolf,
      poolWidthMeters: primary.poolWidthMeters ?? secondary.poolWidthMeters,
      totalJumps: primary.totalJumps ?? secondary.totalJumps,
      averageJumpFrequency:
          primary.averageJumpFrequency ?? secondary.averageJumpFrequency,
      bestJumpFrequency:
          primary.bestJumpFrequency ?? secondary.bestJumpFrequency,
      tripCount: primary.tripCount ?? secondary.tripCount,
      setCount: primary.setCount ?? secondary.setCount,
      totalStrokes: primary.totalStrokes ?? secondary.totalStrokes,
      averageRowingFrequency:
          primary.averageRowingFrequency ?? secondary.averageRowingFrequency,
      bestRowingFrequency:
          primary.bestRowingFrequency ?? secondary.bestRowingFrequency,
      samples: samples,
      route: route,
      recovery: primary.recovery ?? secondary.recovery,
    );
  }

  static bool isWorkoutSummary(XiaomiActivityWorkoutRecord value) =>
      value.distanceMeters != null ||
      value.calories != null ||
      value.averageHeartRate != null ||
      value.totalDurationSeconds != null ||
      value.heartRateZones.isNotEmpty;


  XiaomiActivityWorkoutRecord? parseWorkoutSamples(
    Uint8List data,
    int fileTimestamp,
    int subtype,
    int version,
  ) {
    if ((subtype == 9 || subtype == 10) && version == 3) {
      return parseSwimmingSamples(data, fileTimestamp, subtype);
    }
    final layout = _workoutRecordLayout(subtype, version);
    if (layout == null) return null;
    final limit = data.length - 4;
    var offset = 8 + layout.validityBytes;
    if (offset + layout.segmentHeaderBytes > limit) return null;
    final view = ByteData.sublistView(data);
    final validity = data.sublist(8, 8 + layout.validityBytes);
    bool bit(int index) =>
        index ~/ 8 < validity.length &&
        (validity[index ~/ 8] & (1 << (7 - index % 8))) != 0;
    final activeFields = layout.pointFields
        .where((field) => bit(field.existsBit))
        .toList(growable: false);
    final pointBytes = activeFields.fold<int>(
      0,
      (total, field) => total + field.byteSize,
    );
    if (pointBytes == 0) return null;

    final samples = <XiaomiWorkoutSampleRecord>[];
    var cumulativeCalories = 0;
    var cumulativeSteps = 0;
    var cumulativeDistanceTenths = 0;
    double? cumulativeAltitude;
    while (offset + layout.segmentHeaderBytes <= limit) {
      final segmentOffset = offset;
      final count = view.getUint32(
        segmentOffset + layout.recordCountOffset,
        Endian.little,
      );
      final resumeSeconds = view.getUint32(
        segmentOffset + layout.resumeTimestampOffset,
        Endian.little,
      );
      final initialAltitudeOffset = layout.initialAltitudeOffset;
      if (initialAltitudeOffset != null) {
        final initial = view.getFloat32(
          segmentOffset + initialAltitudeOffset,
          Endian.little,
        );
        if (initial.isFinite) cumulativeAltitude = initial;
      }
      if (count == 0 || count > 24 * 60 * 60) break;
      offset += layout.segmentHeaderBytes;
      if (offset + count * pointBytes > limit) break;
      for (var index = 0; index < count; index++) {
        int? heartRate;
        int? bloodOxygen;
        int? stress;
        int? stride;
        int? pace;
        double? speed;
        double? altitude;
        int? cadence;
        int? power;
        int? jumpFrequency;
        int? jumpHeight;
        int? strokeFrequency;
        for (final field in activeFields) {
          final valueOffset = offset;
          offset += field.byteSize;
          final fieldValid = bit(field.validBit);
          switch (field.kind) {
            case _WorkoutPointKind.caloriesAndSteps:
              final packed = view.getUint8(valueOffset);
              if (fieldValid) cumulativeCalories += packed >> 4;
              if (bit(field.validBit + 1)) cumulativeSteps += packed & 0x0f;
            case _WorkoutPointKind.calories:
              if (fieldValid) cumulativeCalories += view.getUint8(valueOffset);
            case _WorkoutPointKind.heartRate:
              if (fieldValid) heartRate = view.getUint8(valueOffset);
            case _WorkoutPointKind.bloodOxygen:
              if (fieldValid) bloodOxygen = view.getUint8(valueOffset);
            case _WorkoutPointKind.stress:
              if (fieldValid) stress = view.getUint8(valueOffset);
            case _WorkoutPointKind.altitudeInt10:
              if (fieldValid) {
                altitude = view.getInt32(valueOffset, Endian.little) / 10;
              }
            case _WorkoutPointKind.altitudeFloat:
              if (fieldValid) {
                altitude = view.getFloat32(valueOffset, Endian.little);
              }
            case _WorkoutPointKind.altitudeDeltaTenths:
              if (fieldValid) {
                final packed = view.getUint8(valueOffset);
                final delta = (packed & 0x3f) / 10;
                cumulativeAltitude =
                    (cumulativeAltitude ?? 0) +
                    ((packed & 0x40) == 0 ? -delta : delta);
                altitude = cumulativeAltitude;
              }
            case _WorkoutPointKind.distance8:
              if (fieldValid) {
                cumulativeDistanceTenths += view.getUint8(valueOffset) * 10;
              }
            case _WorkoutPointKind.distance8Tenths:
              if (fieldValid) {
                cumulativeDistanceTenths += view.getUint8(valueOffset);
              }
            case _WorkoutPointKind.distance15:
              if (fieldValid) {
                cumulativeDistanceTenths +=
                    (view.getUint16(valueOffset, Endian.little) & 0x7fff) * 10;
              }
            case _WorkoutPointKind.stride:
              if (fieldValid) stride = view.getUint8(valueOffset);
            case _WorkoutPointKind.cadence:
              if (fieldValid) cadence = view.getUint8(valueOffset);
            case _WorkoutPointKind.pace:
              if (fieldValid) {
                pace = view.getUint16(valueOffset, Endian.little);
              }
            case _WorkoutPointKind.speed:
              if (fieldValid) {
                speed = view.getUint16(valueOffset, Endian.little) / 10;
              }
            case _WorkoutPointKind.power:
              if (fieldValid) {
                power = view.getUint16(valueOffset, Endian.little);
              }
            case _WorkoutPointKind.jumpFrequency:
              if (fieldValid) {
                jumpFrequency = view.getUint16(valueOffset, Endian.little);
              }
            case _WorkoutPointKind.jumpHeight:
              if (fieldValid) jumpHeight = view.getUint8(valueOffset);
            case _WorkoutPointKind.strokeFrequency:
              if (fieldValid) strokeFrequency = view.getUint8(valueOffset);
            case _WorkoutPointKind.skip:
              break;
          }
        }
        final sampleTimestamp = resumeSeconds == 0
            ? fileTimestamp + index
            : resumeSeconds + index;
        samples.add(
          XiaomiWorkoutSampleRecord(
            timestamp: _activityTimestamp(sampleTimestamp),
            heartRate: heartRate,
            bloodOxygen: bloodOxygen,
            stress: stress,
            calories: cumulativeCalories == 0 ? null : cumulativeCalories,
            steps: cumulativeSteps == 0 ? null : cumulativeSteps,
            distanceMeters: cumulativeDistanceTenths == 0
                ? null
                : (cumulativeDistanceTenths / 10).round(),
            altitudeMeters: altitude,
            paceSecondsPerKilometer: pace,
            speedKph: speed,
            cadence: cadence,
            powerWatts: power,
            strideCentimeters: stride,
            jumpFrequency: jumpFrequency,
            jumpHeightCentimeters: jumpHeight,
            strokeFrequency: strokeFrequency,
          ),
        );
      }
    }
    if (samples.isEmpty) return null;
    return XiaomiActivityWorkoutRecord(
      startedAt: samples.first.timestamp,
      endedAt: samples.last.timestamp.add(const Duration(seconds: 1)),
      activityType: subtype,
      samples: samples,
    );
  }

  _WorkoutRecordLayout? _workoutRecordLayout(int subtype, int version) =>
      switch ((subtype, version)) {
        (22, 5) => _outdoorFootRecordV5,
        (22, 8) => _outdoorFootRecordV8,
        (22, 9) => _outdoorFootRecordV9,
        (23, 5) => _outdoorNonFootRecordV5,
        (23, 6) => _outdoorNonFootRecordV6,
        (23, 7) => _outdoorNonFootRecordV7,
        (3, 9) => _indoorRunRecordV9,
        (3, 10) => _indoorRunRecordV10,
        (7, 6) => _indoorCyclingRecordV6,
        (8, 4) => _freeTrainingRecordV4,
        (8, 5) => _freeTrainingRecordV5,
        (8, 6) => _freeTrainingRecordV6,
        (11, 3) => _ellipticalRecordV3,
        (13, 4) => _rowingRecordV4,
        (14, 6) => _ropeSkippingRecordV6,
        _ => null,
      };

  XiaomiActivityWorkoutRecord? parseSwimmingSamples(
    Uint8List data,
    int fileTimestamp,
    int subtype,
  ) {
    const validityBytes = 3;
    final limit = data.length - 4;
    var offset = 8 + validityBytes;
    if (offset + 8 > limit) return null;
    final view = ByteData.sublistView(data);
    final validity = data.sublist(8, 8 + validityBytes);
    bool valid(int index) =>
        (validity[index ~/ 8] & (1 << (7 - index % 8))) != 0;
    final samples = <XiaomiWorkoutSampleRecord>[];
    while (offset + 8 <= limit) {
      final recordCount = view.getUint32(offset, Endian.little);
      final resumeSeconds = view.getUint32(offset + 4, Endian.little);
      offset += 8;
      if (recordCount == 0 || recordCount > 10000) break;
      for (var recordIndex = 0; recordIndex < recordCount; recordIndex++) {
        if (offset + 10 > limit) break;
        final dataType = view.getUint8(offset);
        final endSeconds = view.getUint32(offset + 1, Endian.little);
        final stroke = view.getUint8(offset + 5);
        final pace = view.getUint16(offset + 6, Endian.little);
        final swolf = view.getUint16(offset + 8, Endian.little);
        offset += 10;
        int? distance;
        int? activeCalories;
        int? strokeFrequency;
        var heartRateCount = 0;
        if (dataType == 0) {
          if (offset + 25 > limit) return null;
          distance = view.getUint16(offset, Endian.little);
          activeCalories = view.getUint16(offset + 2, Endian.little);
          strokeFrequency = view.getUint8(offset + 8);
          heartRateCount = view.getUint32(offset + 21, Endian.little);
          offset += 25;
          if (heartRateCount > 24 * 60 * 60 ||
              offset + heartRateCount > limit) {
            return null;
          }
        }
        final endTimestamp = endSeconds == 0
            ? _activityTimestamp(resumeSeconds + recordIndex)
            : _activityTimestamp(endSeconds);
        samples.add(
          XiaomiWorkoutSampleRecord(
            timestamp: endTimestamp,
            calories: valid(5) ? activeCalories : null,
            distanceMeters: valid(4) ? distance : null,
            strokeFrequency: valid(8) ? strokeFrequency : null,
            swimmingStroke: valid(1) ? stroke : null,
            swolf: valid(3) ? swolf : null,
            swimmingPaceSecondsPer100Meters: valid(2) ? pace : null,
          ),
        );
        for (
          var heartRateIndex = 0;
          heartRateIndex < heartRateCount;
          heartRateIndex++
        ) {
          final heartRate = view.getUint8(offset++);
          samples.add(
            XiaomiWorkoutSampleRecord(
              timestamp: endTimestamp.subtract(
                Duration(seconds: heartRateCount - heartRateIndex - 1),
              ),
              // Zero is a source value, not a parser error. Keep it in the
              // raw workout series so the chart can show an explicit zero
              // sample and let summary/statistics decide whether it is
              // physiologically usable.
              heartRate: heartRate,
            ),
          );
        }
      }
    }
    if (samples.isEmpty) return null;
    samples.sort((left, right) => left.timestamp.compareTo(right.timestamp));
    return XiaomiActivityWorkoutRecord(
      startedAt: _activityTimestamp(fileTimestamp),
      endedAt: samples.last.timestamp,
      activityType: subtype,
      samples: samples,
    );
  }

  XiaomiActivityWorkoutRecord? parseWorkoutRoute(
    Uint8List data,
    int fileTimestamp,
    int subtype,
    int version,
  ) {
    if (version == 2) {
      return _parseWorkoutRouteV2(data, subtype);
    }
    if (version == 3) {
      return _parseWorkoutRouteV3(data, subtype);
    }
    // v4/v5: count-prefixed schema layout (MiFitness parseTgcGps for v4+).
    final validityBytes = switch ((subtype, version)) {
      (22, 5) => 2,
      (22, 4) || (23, 4) => 1,
      _ => null,
    };
    if (validityBytes == null) return null;
    final limit = data.length - 4;
    final bodyOffset = 8 + validityBytes;
    if (bodyOffset + 4 > limit) return null;
    final view = ByteData.sublistView(data);
    final count = view.getUint32(bodyOffset, Endian.little);
    final hasRunway = subtype == 22 && version == 5;
    final pointBytes = hasRunway ? 27 : 26;
    if (count > 100000 || bodyOffset + 4 + count * pointBytes > limit) {
      return null;
    }
    final route = <XiaomiWorkoutRoutePoint>[];
    var offset = bodyOffset + 4;
    for (var index = 0; index < count; index++) {
      final seconds = view.getUint32(offset, Endian.little);
      final longitude = view.getFloat32(offset + 4, Endian.little);
      final latitude = view.getFloat32(offset + 8, Endian.little);
      final accuracy = view.getFloat32(offset + 12, Endian.little);
      final speedAndSource = view.getUint16(offset + 16, Endian.little);
      final altitude = view.getFloat32(offset + 18, Endian.little);
      if (seconds != 0 &&
          latitude.isFinite &&
          longitude.isFinite &&
          latitude.abs() <= 90 &&
          longitude.abs() <= 180) {
        route.add(
          XiaomiWorkoutRoutePoint(
            timestamp: _activityTimestamp(seconds),
            latitude: latitude,
            longitude: longitude,
            altitudeMeters: altitude.isFinite ? altitude : null,
            speedMetersPerSecond: ((speedAndSource >> 4) / 10),
            horizontalAccuracyMeters: accuracy.isFinite ? accuracy : null,
          ),
        );
      }
      offset += pointBytes;
    }
    if (route.isEmpty) return null;
    return XiaomiActivityWorkoutRecord(
      startedAt: route.first.timestamp,
      endedAt: route.last.timestamp,
      activityType: subtype,
      route: route,
    );
  }

  // Workout GPS v2 (Gadgetbridge layout): 1-byte header, then a stream of
  // 18-byte points read to EOF (no leading point count). Point layout:
  // time(u32) | longitude(f32) | latitude(f32) | horizontalAccuracy(f32) |
  // locationSpeedAndGpsSource(u16: high 12 bits = 0.1 m/s). No altitude field.
  XiaomiActivityWorkoutRecord? _parseWorkoutRouteV2(
    Uint8List data,
    int subtype,
  ) {
    const headerBytes = 1;
    const pointBytes = 18;
    final limit = data.length - 4;
    final bodyOffset = 8 + headerBytes;
    if (bodyOffset + pointBytes > limit) return null;
    final view = ByteData.sublistView(data);
    final route = <XiaomiWorkoutRoutePoint>[];
    var offset = bodyOffset;
    while (offset + pointBytes <= limit) {
      final seconds = view.getUint32(offset, Endian.little);
      final longitude = view.getFloat32(offset + 4, Endian.little);
      final latitude = view.getFloat32(offset + 8, Endian.little);
      final accuracy = view.getFloat32(offset + 12, Endian.little);
      final speedAndSource = view.getUint16(offset + 16, Endian.little);
      if (seconds != 0 &&
          latitude.isFinite &&
          longitude.isFinite &&
          latitude.abs() <= 90 &&
          longitude.abs() <= 180) {
        route.add(
          XiaomiWorkoutRoutePoint(
            timestamp: _activityTimestamp(seconds),
            latitude: latitude,
            longitude: longitude,
            speedMetersPerSecond: ((speedAndSource >> 4) / 10),
            horizontalAccuracyMeters: accuracy.isFinite ? accuracy : null,
          ),
        );
      }
      offset += pointBytes;
    }
    if (route.isEmpty) return null;
    return XiaomiActivityWorkoutRecord(
      startedAt: route.first.timestamp,
      endedAt: route.last.timestamp,
      activityType: subtype,
      route: route,
    );
  }

  // Workout GPS v3 (Gadgetbridge layout): 1-byte header, then a stream of
  // 26-byte points read to EOF (no leading point count). Point layout:
  // time(u32) | longitude(f32) | latitude(f32) | horizontalAccuracy(f32) |
  // locationSpeedAndGpsSource(u16: high 12 bits = 0.1 m/s) |
  // altitude(f32) | hdop(f32).
  XiaomiActivityWorkoutRecord? _parseWorkoutRouteV3(
    Uint8List data,
    int subtype,
  ) {
    const headerBytes = 1;
    const pointBytes = 26;
    final limit = data.length - 4;
    final bodyOffset = 8 + headerBytes;
    if (bodyOffset + pointBytes > limit) return null;
    final view = ByteData.sublistView(data);
    final route = <XiaomiWorkoutRoutePoint>[];
    var offset = bodyOffset;
    while (offset + pointBytes <= limit) {
      final seconds = view.getUint32(offset, Endian.little);
      final longitude = view.getFloat32(offset + 4, Endian.little);
      final latitude = view.getFloat32(offset + 8, Endian.little);
      final accuracy = view.getFloat32(offset + 12, Endian.little);
      final speedAndSource = view.getUint16(offset + 16, Endian.little);
      final altitude = view.getFloat32(offset + 18, Endian.little);
      // hdop at offset + 22; not yet exposed in XiaomiWorkoutRoutePoint.
      if (seconds != 0 &&
          latitude.isFinite &&
          longitude.isFinite &&
          latitude.abs() <= 90 &&
          longitude.abs() <= 180) {
        route.add(
          XiaomiWorkoutRoutePoint(
            timestamp: _activityTimestamp(seconds),
            latitude: latitude,
            longitude: longitude,
            altitudeMeters: altitude.isFinite ? altitude : null,
            speedMetersPerSecond: ((speedAndSource >> 4) / 10),
            horizontalAccuracyMeters: accuracy.isFinite ? accuracy : null,
          ),
        );
      }
      offset += pointBytes;
    }
    if (route.isEmpty) return null;
    return XiaomiActivityWorkoutRecord(
      startedAt: route.first.timestamp,
      endedAt: route.last.timestamp,
      activityType: subtype,
      route: route,
    );
  }

  XiaomiActivityWorkoutRecord? parseWorkoutRecovery(
    Uint8List data,
    int fileTimestamp,
    int subtype,
    int version,
  ) {
    if (version != 1) return null;
    final limit = data.length - 4;
    if (limit < 16) return null;
    final view = ByteData.sublistView(data);
    final startSeconds = view.getUint32(8, Endian.little);
    final count = view.getUint16(14, Endian.little);
    if (16 + count > limit) return null;
    final recovery = XiaomiWorkoutHeartRateRecovery(
      startedAt: _activityTimestamp(
        startSeconds == 0 ? fileTimestamp : startSeconds,
      ),
      recoveredHeartRate: data[12] == 0 ? null : data[12],
      recoveryRate: data[13] == 0 ? null : data[13],
      heartRates: data
          .sublist(16, 16 + count)
          .where((value) => value >= 30 && value <= 240)
          .toList(growable: false),
    );
    return XiaomiActivityWorkoutRecord(
      startedAt: _activityTimestamp(fileTimestamp),
      endedAt: recovery.startedAt,
      activityType: subtype,
      recovery: recovery,
    );
  }


  XiaomiActivityWorkoutRecord? parseWorkoutSummary(
    Uint8List data,
    int timestamp,
    int subtype,
    int version,
  ) {
    // Keep the compact report decoder used by HEAD as the compatibility
    // anchor. Some Vela/S5 firmwares advertise a newer schema version while
    // still emitting this older wire layout; rejecting that report makes the
    // whole workout history disappear even though the file transferred
    // successfully. When both decoders recognize a file, merge the richer
    // fields instead of choosing one representation.
    final legacy = _parseLegacyWorkoutSummary(
      data,
      timestamp,
      subtype,
      version,
    );
    final current = _parseWorkoutSummaryCurrent(
      data,
      timestamp,
      subtype,
      version,
    );
    if (legacy != null && current != null) {
      // Field-level conflicts must resolve in favor of the current-schema
      // decoder: `_mergeWorkoutRecord` keeps the left record's non-null
      // values when both sides carry summary fields. Legacy remains the
      // fallback for whole-file decode failures only.
      return mergeWorkoutRecord(current, legacy);
    }
    return current ?? legacy;
  }

  XiaomiActivityWorkoutRecord? _parseWorkoutSummaryCurrent(
    Uint8List data,
    int timestamp,
    int subtype,
    int version,
  ) {
    final modern = _modernWorkoutReportFields(subtype, version);
    if (modern != null) {
      return _parseModernWorkoutSummary(data, subtype, version, modern);
    }
    final fields = _sportReportFields(subtype);
    final validityLength = _sportReportValidityLength(subtype, version);
    final limit = data.length - 4;
    if (fields == null ||
        validityLength == null ||
        limit < 8 + validityLength) {
      return null;
    }
    final view = ByteData.sublistView(data);
    final valid = data.sublist(8, 8 + validityLength);
    final values = <int, int>{};
    var offset = 8 + validityLength;
    var validIndex = 0;
    for (final field in fields) {
      final supported = field.minimumVersion <= version;
      final isValid =
          supported &&
          validIndex ~/ 8 < valid.length &&
          (valid[validIndex ~/ 8] & (1 << (7 - validIndex % 8))) != 0;
      if (supported) validIndex++;
      if (!supported) continue;
      if (offset + field.byteSize > limit) return null;
      final value = switch (field.byteSize) {
        1 => view.getUint8(offset),
        2 => view.getUint16(offset, Endian.little),
        4 => view.getUint32(offset, Endian.little),
        _ => throw StateError('Unsupported Xiaomi sport report field size'),
      };
      offset += field.byteSize;
      if (isValid) values[field.type] = value;
    }

    final started = values[1];
    final ended = values[2];
    if (started == null || ended == null || started == 0 || ended <= started) {
      return null;
    }
    return XiaomiActivityWorkoutRecord(
      startedAt: _activityTimestamp(started),
      endedAt: _activityTimestamp(ended),
      activityType: subtype,
      distanceMeters: values[5],
      calories: values[6],
      averageHeartRate: values[16],
      maximumHeartRate: values[17],
      minimumHeartRate: values[18],
    );
  }

  XiaomiActivityWorkoutRecord? _parseLegacyWorkoutSummary(
    Uint8List data,
    int timestamp,
    int subtype,
    int version,
  ) {
    final headerSize = _legacyWorkoutHeaderSize(subtype, version);
    final limit = data.length - 4;
    if (headerSize == 0 || limit < 8 + headerSize + 8) return null;
    final view = ByteData.sublistView(data);
    var offset = 8 + headerSize;
    if (subtype == 0x16 || subtype == 0x17) {
      if (offset + 2 > limit) return null;
      offset += 2;
    }
    if (offset + 8 > limit) return null;
    final started = view.getUint32(offset, Endian.little);
    final ended = view.getUint32(offset + 4, Endian.little);
    if (started == 0 || ended <= started) return null;

    int? distanceMeters;
    int? calories;
    final commonOffset = offset + 8;
    if (subtype == 0x16 || subtype == 0x17) {
      if (commonOffset + 14 <= limit) {
        distanceMeters = view.getUint32(commonOffset + 8, Endian.little);
        calories = view.getUint16(commonOffset + 12, Endian.little);
      }
    } else if (commonOffset + 6 <= limit) {
      if (subtype == 0x01 || subtype == 0x02) {
        if (commonOffset + 8 <= limit) {
          distanceMeters = view.getUint32(commonOffset + 4, Endian.little);
        }
        if (commonOffset + 10 <= limit) {
          calories = view.getUint16(commonOffset + 8, Endian.little);
        }
      } else {
        calories = view.getUint16(commonOffset + 4, Endian.little);
      }
    }
    return XiaomiActivityWorkoutRecord(
      startedAt: _activityTimestamp(started),
      endedAt: _activityTimestamp(ended),
      activityType: subtype,
      distanceMeters: distanceMeters,
      calories: calories,
    );
  }

  int _legacyWorkoutHeaderSize(int subtype, int version) => switch (subtype) {
    0x01 || 0x02 => version == 4 ? 4 : 0,
    0x03 => switch (version) {
      5 => 4,
      9 => 6,
      10 => 8,
      11 => 9,
      _ => 0,
    },
    0x06 || 0x07 => switch (version) {
      8 => 7,
      9 => 8,
      _ => 0,
    },
    0x08 => switch (version) {
      5 => 3,
      7 => 5,
      8 || 9 || 10 => 6,
      _ => 0,
    },
    0x09 => switch (version) {
      6 => 4,
      7 => 5,
      8 => 8,
      _ => 0,
    },
    0x0b => version >= 3 && version <= 6 ? 4 : 0,
    0x0d => switch (version) {
      4 => 4,
      6 || 7 => 5,
      _ => 0,
    },
    0x0e => version == 3 || version == 5 ? 5 : 0,
    0x10 => version == 5 ? 4 : 0,
    0x16 => switch (version) {
      1 => 5,
      4 => 7,
      5 || 6 => 9,
      9 => 13,
      _ => 0,
    },
    0x17 => version == 4 ? 5 : 0,
    _ => 0,
  };

  XiaomiActivityWorkoutRecord? _parseModernWorkoutSummary(
    Uint8List data,
    int subtype,
    int version,
    List<_ModernSportReportField> fields,
  ) {
    final validityLength = _sportReportValidityLength(subtype, version);
    final limit = data.length - 4;
    if (validityLength == null || limit < 8 + validityLength) return null;
    final validity = data.sublist(8, 8 + validityLength);
    final bodyOffset = 8 + validityLength;
    final view = ByteData.sublistView(data);
    final values = <_WorkoutReportValue, num>{};
    for (final field in fields) {
      final bitSet =
          field.validityIndex ~/ 8 < validity.length &&
          (validity[field.validityIndex ~/ 8] &
                  (1 << (7 - field.validityIndex % 8))) !=
              0;
      if (!bitSet && !field.always) {
        continue;
      }
      final offset = bodyOffset + field.offset;
      if (offset + field.byteSize > limit) return null;
      values[field.value] = switch (field.type) {
        _SportWireType.u8 => view.getUint8(offset),
        _SportWireType.u16 => view.getUint16(offset, Endian.little),
        _SportWireType.u32 => view.getUint32(offset, Endian.little),
        _SportWireType.f32 => view.getFloat32(offset, Endian.little),
      };
    }

    int? integer(_WorkoutReportValue value) => values[value]?.toInt();
    double? decimal(_WorkoutReportValue value) => values[value]?.toDouble();
    final started = integer(_WorkoutReportValue.startedAt);
    final ended = integer(_WorkoutReportValue.endedAt);
    if (started == null || ended == null || started == 0 || ended <= started) {
      return null;
    }
    final zones = <XiaomiWorkoutHeartRateZone>[];
    for (var zone = 1; zone <= 5; zone++) {
      final duration = integer(_heartRateZoneDurationValue(zone));
      if (duration == null) continue;
      zones.add(
        XiaomiWorkoutHeartRateZone(
          zone: zone,
          durationSeconds: duration,
          lowerLimit: integer(_heartRateZoneLowerValue(zone)),
        ),
      );
    }
    return XiaomiActivityWorkoutRecord(
      startedAt: _activityTimestamp(started),
      endedAt: _activityTimestamp(ended),
      activityType: subtype,
      subSportType: integer(_WorkoutReportValue.subSportType),
      totalDurationSeconds: integer(_WorkoutReportValue.totalDuration),
      effectiveDurationSeconds: integer(_WorkoutReportValue.effectiveDuration),
      distanceMeters: integer(_WorkoutReportValue.distance),
      calories:
          integer(_WorkoutReportValue.totalCalories) ??
          integer(_WorkoutReportValue.activeCalories),
      activeCalories: integer(_WorkoutReportValue.activeCalories),
      averagePaceSecondsPerKilometer: integer(_WorkoutReportValue.averagePace),
      bestPaceSecondsPerKilometer: integer(_WorkoutReportValue.bestPace),
      worstPaceSecondsPerKilometer: integer(_WorkoutReportValue.worstPace),
      averageSpeedKph: decimal(_WorkoutReportValue.averageSpeed),
      bestSpeedKph: decimal(_WorkoutReportValue.bestSpeed),
      totalSteps: integer(_WorkoutReportValue.totalSteps),
      averageStrideCentimeters: integer(_WorkoutReportValue.averageStride),
      averageCadence: integer(_WorkoutReportValue.averageCadence),
      maximumCadence: integer(_WorkoutReportValue.maximumCadence),
      averageHeartRate: integer(_WorkoutReportValue.averageHeartRate),
      maximumHeartRate: integer(_WorkoutReportValue.maximumHeartRate),
      minimumHeartRate: integer(_WorkoutReportValue.minimumHeartRate),
      averageBloodOxygen: integer(_WorkoutReportValue.averageBloodOxygen),
      maximumBloodOxygen: integer(_WorkoutReportValue.maximumBloodOxygen),
      minimumBloodOxygen: integer(_WorkoutReportValue.minimumBloodOxygen),
      averageStress: integer(_WorkoutReportValue.averageStress),
      maximumStress: integer(_WorkoutReportValue.maximumStress),
      minimumStress: integer(_WorkoutReportValue.minimumStress),
      totalAscentMeters: decimal(_WorkoutReportValue.totalAscent),
      totalDescentMeters: decimal(_WorkoutReportValue.totalDescent),
      averageAltitudeMeters: decimal(_WorkoutReportValue.averageAltitude),
      maximumAltitudeMeters: decimal(_WorkoutReportValue.maximumAltitude),
      minimumAltitudeMeters: decimal(_WorkoutReportValue.minimumAltitude),
      aerobicTrainingEffect: decimal(_WorkoutReportValue.aerobicEffect),
      anaerobicTrainingEffect: decimal(_WorkoutReportValue.anaerobicEffect),
      peakTrainingEffect: decimal(_WorkoutReportValue.peakEffect),
      vo2Max: integer(_WorkoutReportValue.vo2Max),
      bodyEnergyConsumption: integer(_WorkoutReportValue.bodyEnergy),
      expectedRecoveryHours: integer(_WorkoutReportValue.recoveryHours),
      trainingLoad: integer(_WorkoutReportValue.trainingLoad),
      earnedVitality: integer(_WorkoutReportValue.earnedVitality),
      heartRateZoneMethod: integer(_WorkoutReportValue.heartRateZoneMethod),
      heartRateZones: zones,
      averagePowerWatts: integer(_WorkoutReportValue.averagePower),
      maximumPowerWatts: integer(_WorkoutReportValue.maximumPower),
      totalArmPulls: integer(_WorkoutReportValue.totalArmPulls),
      mainSwimmingStroke: integer(_WorkoutReportValue.mainSwimmingStroke),
      averageStrokeFrequency: integer(_WorkoutReportValue.averageStrokeRate),
      maximumStrokeFrequency: integer(_WorkoutReportValue.maximumStrokeRate),
      turnCount: integer(_WorkoutReportValue.turnCount),
      averageSwolf: integer(_WorkoutReportValue.averageSwolf),
      bestSwolf: integer(_WorkoutReportValue.bestSwolf),
      poolWidthMeters: integer(_WorkoutReportValue.poolWidth),
      totalJumps: integer(_WorkoutReportValue.totalJumps),
      averageJumpFrequency: integer(_WorkoutReportValue.averageJumpRate),
      bestJumpFrequency: integer(_WorkoutReportValue.bestJumpRate),
      tripCount: integer(_WorkoutReportValue.tripCount),
      setCount: integer(_WorkoutReportValue.setCount),
      totalStrokes: integer(_WorkoutReportValue.totalStrokes),
      averageRowingFrequency: integer(_WorkoutReportValue.averageRowingRate),
      bestRowingFrequency: integer(_WorkoutReportValue.bestRowingRate),
    );
  }

  _WorkoutReportValue _heartRateZoneDurationValue(int zone) => switch (zone) {
    1 => _WorkoutReportValue.heartRateZone1Duration,
    2 => _WorkoutReportValue.heartRateZone2Duration,
    3 => _WorkoutReportValue.heartRateZone3Duration,
    4 => _WorkoutReportValue.heartRateZone4Duration,
    _ => _WorkoutReportValue.heartRateZone5Duration,
  };

  _WorkoutReportValue _heartRateZoneLowerValue(int zone) => switch (zone) {
    1 => _WorkoutReportValue.heartRateZone1Lower,
    2 => _WorkoutReportValue.heartRateZone2Lower,
    3 => _WorkoutReportValue.heartRateZone3Lower,
    4 => _WorkoutReportValue.heartRateZone4Lower,
    _ => _WorkoutReportValue.heartRateZone5Lower,
  };

  List<_ModernSportReportField>? _modernWorkoutReportFields(
    int subtype,
    int version,
  ) => switch ((subtype, version)) {
    (22, 8) || (22, 9) => _modernOutdoorFootReportFields,
    (22, 6) => _modernOutdoorFootV6ReportFields,
    (23, 8) => _modernOutdoorNonFootV8ReportFields,
    (23, 9) => _modernOutdoorNonFootV9ReportFields,
    (3, 13) => _modernIndoorRunV13ReportFields,
    (3, 14) => _modernIndoorRunV14ReportFields,
    (7, 10) => _modernIndoorCyclingV10ReportFields,
    (8, 11) || (8, 12) || (8, 13) || (8, 14) => _modernFreeTrainingReportFields,
    (9, 8) || (10, 8) => _modernSwimmingV8ReportFields,
    (11, 7) => _modernEllipticalV7ReportFields,
    (13, 8) => _modernRowingV8ReportFields,
    (14, 7) => _modernRopeSkippingV7ReportFields,
    _ => null,
  };

  List<_SportReportField>? _sportReportFields(int subtype) => switch (subtype) {
    // OutdoorSportReportParser and HikingReportParser share this prefix.
    1 || 2 || 4 || 5 || 15 => _sportOutdoorReportFields,
    3 => _sportIndoorRunReportFields,
    6 => _sportOutdoorBikingReportFields,
    7 => _sportIndoorBikingReportFields,
    8 || 12 || 14 || 16 || 18 || 19 => _sportSimpleReportFields,
    9 || 10 => _sportSwimmingReportFields,
    11 => _sportEllipticalReportFields,
    13 => _sportSimpleReportFields,
    21 => _sportSkiReportFields,
    _ => null,
  };

  int? _sportReportValidityLength(int subtype, int version) {
    if (version <= 0) return null;
    return switch (subtype) {
      1 || 2 || 4 || 5 =>
        version <= 3
            ? 4
            : version == 4
            ? 5
            : null,
      15 =>
        version <= 2
            ? 4
            : version == 3
            ? 5
            : null,
      3 => switch (version) {
        1 || 2 || 3 => 3,
        4 || 5 => 4,
        6 => 5,
        7 || 8 || 9 => 6,
        10 => 8,
        11 => 9,
        12 => 11,
        13 => 12,
        14 => 13,
        _ => null,
      },
      6 =>
        version <= 3
            ? 4
            : version == 4
            ? 5
            : null,
      7 =>
        version <= 2
            ? 2
            : version <= 4
            ? 3
            : version <= 6
            ? 5
            : version == 7
            ? 6
            : version == 8
            ? 7
            : version == 9
            ? 8
            : version == 10
            ? 9
            : null,
      8 =>
        version <= 2
            ? 2
            : version <= 5
            ? 3
            : version == 6
            ? 4
            : version == 7
            ? 5
            : version <= 10
            ? 6
            : version <= 12
            ? 7
            : version <= 14
            ? 8
            : null,
      9 || 10 =>
        version == 1
            ? 2
            : version <= 4
            ? 3
            : version <= 6
            ? 4
            : version == 7
            ? 5
            : version == 8
            ? 8
            : null,
      11 =>
        version <= 2
            ? 3
            : version <= 6
            ? 4
            : version == 7
            ? 6
            : null,
      12 =>
        version == 1
            ? 2
            : version <= 3
            ? 3
            : version <= 6
            ? 4
            : version == 7
            ? 5
            : null,
      13 =>
        version == 1
            ? 3
            : version <= 4
            ? 4
            : version <= 7
            ? 5
            : version == 8
            ? 6
            : null,
      14 =>
        version <= 2
            ? 4
            : version <= 6
            ? 5
            : version == 7
            ? 6
            : null,
      16 =>
        version <= 2
            ? 3
            : version <= 6
            ? 4
            : version == 7
            ? 5
            : null,
      18 =>
        version == 1
            ? 4
            : version <= 4
            ? 5
            : version == 5
            ? 6
            : null,
      19 =>
        version <= 4
            ? 4
            : version == 5
            ? 5
            : null,
      20 =>
        version == 1
            ? 2
            : version <= 4
            ? 3
            : null,
      21 =>
        version == 1
            ? 5
            : version <= 4
            ? 6
            : version <= 6
            ? 7
            : null,
      22 =>
        version == 1
            ? 5
            : version <= 3
            ? 6
            : version == 4
            ? 7
            : version <= 6
            ? 9
            : version <= 8
            ? 12
            : version == 9
            ? 13
            : null,
      23 =>
        version <= 2
            ? 5
            : version <= 5
            ? 6
            : version == 6
            ? 7
            : version <= 8
            ? 8
            : version == 9
            ? 9
            : null,
      24 => version <= 2 ? 7 : null,
      25 => version <= 2 ? 4 : null,
      _ => null,
    };
  }

}

enum _WorkoutPointKind {
  caloriesAndSteps,
  calories,
  heartRate,
  bloodOxygen,
  stress,
  altitudeInt10,
  altitudeFloat,
  altitudeDeltaTenths,
  distance8,
  distance8Tenths,
  distance15,
  stride,
  cadence,
  pace,
  speed,
  power,
  jumpFrequency,
  jumpHeight,
  strokeFrequency,
  skip,
}

class _WorkoutPointField {
  const _WorkoutPointField(
    this.kind,
    this.existsBit,
    this.validBit,
    this.byteSize,
  );

  final _WorkoutPointKind kind;
  final int existsBit;
  final int validBit;
  final int byteSize;
}

class _WorkoutRecordLayout {
  const _WorkoutRecordLayout({
    required this.validityBytes,
    required this.segmentHeaderBytes,
    required this.recordCountOffset,
    required this.resumeTimestampOffset,
    required this.pointFields,
    this.initialAltitudeOffset,
  });

  final int validityBytes;
  final int segmentHeaderBytes;
  final int recordCountOffset;
  final int resumeTimestampOffset;
  final List<_WorkoutPointField> pointFields;
  final int? initialAltitudeOffset;
}

const _outdoorFootRecordV8 = _WorkoutRecordLayout(
  validityBytes: 7,
  segmentHeaderBytes: 27,
  recordCountOffset: 4,
  resumeTimestampOffset: 8,
  initialAltitudeOffset: 0,
  pointFields: [
    _WorkoutPointField(_WorkoutPointKind.caloriesAndSteps, 0, 1, 1),
    _WorkoutPointField(_WorkoutPointKind.heartRate, 4, 5, 1),
    _WorkoutPointField(_WorkoutPointKind.altitudeDeltaTenths, 8, 11, 1),
    _WorkoutPointField(_WorkoutPointKind.distance8Tenths, 12, 13, 1),
    _WorkoutPointField(_WorkoutPointKind.stride, 16, 17, 1),
    _WorkoutPointField(_WorkoutPointKind.skip, 20, 21, 4),
    _WorkoutPointField(_WorkoutPointKind.skip, 24, 25, 1),
    _WorkoutPointField(_WorkoutPointKind.cadence, 28, 29, 1),
    _WorkoutPointField(_WorkoutPointKind.pace, 32, 33, 2),
    _WorkoutPointField(_WorkoutPointKind.skip, 36, 37, 2),
    _WorkoutPointField(_WorkoutPointKind.power, 40, 41, 2),
    _WorkoutPointField(_WorkoutPointKind.skip, 44, 45, 2),
    _WorkoutPointField(_WorkoutPointKind.skip, 48, 49, 2),
  ],
);

const _outdoorFootRecordV9 = _WorkoutRecordLayout(
  validityBytes: 7,
  segmentHeaderBytes: 27,
  recordCountOffset: 4,
  resumeTimestampOffset: 8,
  pointFields: [
    _WorkoutPointField(_WorkoutPointKind.caloriesAndSteps, 0, 1, 1),
    _WorkoutPointField(_WorkoutPointKind.heartRate, 4, 5, 1),
    _WorkoutPointField(_WorkoutPointKind.altitudeInt10, 8, 9, 4),
    _WorkoutPointField(_WorkoutPointKind.distance15, 12, 14, 2),
    _WorkoutPointField(_WorkoutPointKind.stride, 16, 17, 1),
    _WorkoutPointField(_WorkoutPointKind.skip, 20, 21, 4),
    _WorkoutPointField(_WorkoutPointKind.skip, 24, 25, 1),
    _WorkoutPointField(_WorkoutPointKind.cadence, 28, 29, 1),
    _WorkoutPointField(_WorkoutPointKind.pace, 32, 33, 2),
    _WorkoutPointField(_WorkoutPointKind.skip, 36, 37, 2),
    _WorkoutPointField(_WorkoutPointKind.power, 40, 41, 2),
    _WorkoutPointField(_WorkoutPointKind.skip, 44, 45, 2),
    _WorkoutPointField(_WorkoutPointKind.skip, 48, 49, 2),
  ],
);

// SPORTS_OUTDOOR_WALKING_V2 v5 (Gadgetbridge layout). The five signature bytes
// `FF CF F8 BF FF` double as the record-field bitmap: byte 0 is all ones, so the
// eight point fields below are always active. Segment header: 4 pad | int32
// recordCount | int32 startTimestamp | byte phase | int32 totalDistance.
const _outdoorFootRecordV5 = _WorkoutRecordLayout(
  validityBytes: 5,
  segmentHeaderBytes: 17,
  recordCountOffset: 4,
  resumeTimestampOffset: 8,
  pointFields: [
    _WorkoutPointField(_WorkoutPointKind.caloriesAndSteps, 0, 0, 1),
    _WorkoutPointField(_WorkoutPointKind.heartRate, 1, 1, 1),
    _WorkoutPointField(_WorkoutPointKind.altitudeDeltaTenths, 2, 2, 1),
    _WorkoutPointField(_WorkoutPointKind.distance8Tenths, 3, 3, 1),
    _WorkoutPointField(_WorkoutPointKind.stride, 4, 4, 1),
    _WorkoutPointField(_WorkoutPointKind.skip, 5, 5, 5),
    _WorkoutPointField(_WorkoutPointKind.cadence, 6, 6, 1),
    _WorkoutPointField(_WorkoutPointKind.pace, 7, 7, 2),
  ],
);

const _outdoorNonFootRecordV7 = _WorkoutRecordLayout(
  validityBytes: 4,
  segmentHeaderBytes: 23,
  recordCountOffset: 4,
  resumeTimestampOffset: 8,
  pointFields: [
    _WorkoutPointField(_WorkoutPointKind.caloriesAndSteps, 0, 1, 1),
    _WorkoutPointField(_WorkoutPointKind.heartRate, 4, 5, 1),
    _WorkoutPointField(_WorkoutPointKind.altitudeInt10, 8, 9, 4),
    _WorkoutPointField(_WorkoutPointKind.distance15, 12, 14, 2),
    _WorkoutPointField(_WorkoutPointKind.speed, 16, 17, 2),
    _WorkoutPointField(_WorkoutPointKind.cadence, 20, 21, 1),
    _WorkoutPointField(_WorkoutPointKind.power, 24, 25, 2),
  ],
);

const _outdoorNonFootRecordV5 = _WorkoutRecordLayout(
  validityBytes: 3,
  segmentHeaderBytes: 23,
  recordCountOffset: 4,
  resumeTimestampOffset: 8,
  initialAltitudeOffset: 0,
  pointFields: [
    _WorkoutPointField(_WorkoutPointKind.caloriesAndSteps, 0, 1, 1),
    _WorkoutPointField(_WorkoutPointKind.heartRate, 4, 5, 1),
    _WorkoutPointField(_WorkoutPointKind.altitudeDeltaTenths, 8, 11, 1),
    _WorkoutPointField(_WorkoutPointKind.distance8Tenths, 12, 13, 1),
    _WorkoutPointField(_WorkoutPointKind.speed, 16, 17, 2),
    _WorkoutPointField(_WorkoutPointKind.cadence, 20, 21, 1),
  ],
);

const _outdoorNonFootRecordV6 = _WorkoutRecordLayout(
  validityBytes: 3,
  segmentHeaderBytes: 23,
  recordCountOffset: 4,
  resumeTimestampOffset: 8,
  initialAltitudeOffset: 0,
  pointFields: [
    _WorkoutPointField(_WorkoutPointKind.caloriesAndSteps, 0, 1, 1),
    _WorkoutPointField(_WorkoutPointKind.heartRate, 4, 5, 1),
    _WorkoutPointField(_WorkoutPointKind.altitudeInt10, 8, 9, 4),
    _WorkoutPointField(_WorkoutPointKind.distance15, 12, 14, 2),
    _WorkoutPointField(_WorkoutPointKind.speed, 16, 17, 2),
    _WorkoutPointField(_WorkoutPointKind.cadence, 20, 21, 1),
  ],
);

const _indoorRunRecordFields = <_WorkoutPointField>[
  _WorkoutPointField(_WorkoutPointKind.caloriesAndSteps, 0, 1, 1),
  _WorkoutPointField(_WorkoutPointKind.heartRate, 4, 5, 1),
  _WorkoutPointField(_WorkoutPointKind.distance8, 8, 9, 1),
  _WorkoutPointField(_WorkoutPointKind.stride, 12, 13, 1),
  _WorkoutPointField(_WorkoutPointKind.skip, 16, 17, 4),
  _WorkoutPointField(_WorkoutPointKind.skip, 20, 21, 1),
  _WorkoutPointField(_WorkoutPointKind.cadence, 24, 25, 1),
  _WorkoutPointField(_WorkoutPointKind.pace, 28, 29, 2),
  _WorkoutPointField(_WorkoutPointKind.power, 32, 33, 2),
  _WorkoutPointField(_WorkoutPointKind.skip, 36, 37, 2),
  _WorkoutPointField(_WorkoutPointKind.skip, 40, 41, 2),
];

const _indoorRunRecordV9 = _WorkoutRecordLayout(
  validityBytes: 6,
  segmentHeaderBytes: 19,
  recordCountOffset: 0,
  resumeTimestampOffset: 4,
  pointFields: _indoorRunRecordFields,
);

const _indoorRunRecordV10 = _WorkoutRecordLayout(
  validityBytes: 6,
  segmentHeaderBytes: 25,
  recordCountOffset: 0,
  resumeTimestampOffset: 4,
  pointFields: [
    ..._indoorRunRecordFields,
    _WorkoutPointField(_WorkoutPointKind.altitudeInt10, 44, 45, 4),
  ],
);

const _indoorCyclingRecordV6 = _WorkoutRecordLayout(
  validityBytes: 4,
  segmentHeaderBytes: 13,
  recordCountOffset: 0,
  resumeTimestampOffset: 4,
  pointFields: [
    _WorkoutPointField(_WorkoutPointKind.caloriesAndSteps, 0, 1, 1),
    _WorkoutPointField(_WorkoutPointKind.heartRate, 4, 5, 1),
    _WorkoutPointField(_WorkoutPointKind.distance8Tenths, 8, 9, 1),
    _WorkoutPointField(_WorkoutPointKind.skip, 12, 13, 1),
    _WorkoutPointField(_WorkoutPointKind.power, 16, 17, 2),
    _WorkoutPointField(_WorkoutPointKind.speed, 20, 21, 2),
    _WorkoutPointField(_WorkoutPointKind.cadence, 24, 25, 1),
  ],
);

const _freeTrainingRecordV6 = _WorkoutRecordLayout(
  validityBytes: 2,
  segmentHeaderBytes: 26,
  recordCountOffset: 0,
  resumeTimestampOffset: 4,
  pointFields: [
    _WorkoutPointField(_WorkoutPointKind.heartRate, 0, 1, 1),
    _WorkoutPointField(_WorkoutPointKind.calories, 4, 5, 1),
    _WorkoutPointField(_WorkoutPointKind.bloodOxygen, 8, 9, 1),
    _WorkoutPointField(_WorkoutPointKind.stress, 12, 13, 1),
  ],
);

const _freeTrainingPointFields = <_WorkoutPointField>[
  _WorkoutPointField(_WorkoutPointKind.heartRate, 0, 1, 1),
  _WorkoutPointField(_WorkoutPointKind.calories, 4, 5, 1),
  _WorkoutPointField(_WorkoutPointKind.bloodOxygen, 8, 9, 1),
  _WorkoutPointField(_WorkoutPointKind.stress, 12, 13, 1),
];

const _freeTrainingRecordV4 = _WorkoutRecordLayout(
  validityBytes: 2,
  segmentHeaderBytes: 13,
  recordCountOffset: 0,
  resumeTimestampOffset: 4,
  pointFields: _freeTrainingPointFields,
);

const _freeTrainingRecordV5 = _WorkoutRecordLayout(
  validityBytes: 2,
  segmentHeaderBytes: 19,
  recordCountOffset: 0,
  resumeTimestampOffset: 4,
  pointFields: _freeTrainingPointFields,
);

const _ropeSkippingRecordV6 = _WorkoutRecordLayout(
  validityBytes: 3,
  segmentHeaderBytes: 13,
  recordCountOffset: 0,
  resumeTimestampOffset: 4,
  pointFields: [
    _WorkoutPointField(_WorkoutPointKind.heartRate, 0, 1, 1),
    _WorkoutPointField(_WorkoutPointKind.calories, 4, 5, 1),
    _WorkoutPointField(_WorkoutPointKind.jumpFrequency, 8, 9, 2),
    _WorkoutPointField(_WorkoutPointKind.jumpHeight, 12, 13, 1),
    _WorkoutPointField(_WorkoutPointKind.skip, 16, 17, 1),
  ],
);

const _ellipticalRecordV3 = _WorkoutRecordLayout(
  validityBytes: 2,
  segmentHeaderBytes: 9,
  recordCountOffset: 0,
  resumeTimestampOffset: 4,
  pointFields: [
    _WorkoutPointField(_WorkoutPointKind.caloriesAndSteps, 0, 1, 1),
    _WorkoutPointField(_WorkoutPointKind.heartRate, 4, 5, 1),
    _WorkoutPointField(_WorkoutPointKind.cadence, 8, 9, 1),
  ],
);

const _rowingRecordV4 = _WorkoutRecordLayout(
  validityBytes: 2,
  segmentHeaderBytes: 13,
  recordCountOffset: 0,
  resumeTimestampOffset: 4,
  pointFields: [
    _WorkoutPointField(_WorkoutPointKind.heartRate, 0, 1, 1),
    _WorkoutPointField(_WorkoutPointKind.calories, 4, 5, 1),
    _WorkoutPointField(_WorkoutPointKind.strokeFrequency, 8, 9, 1),
  ],
);

/// The one-dimensional sport-report fields used by Mi Fitness' native
/// report parsers. A field remains in the body when its validity bit is
/// clear; the bit only says whether the decoded value can be used.
class _SportReportField {
  const _SportReportField(this.type, this.byteSize, {this.minimumVersion = 1});

  final int type;
  final int byteSize;
  final int minimumVersion;
}

enum _SportWireType { u8, u16, u32, f32 }

enum _WorkoutReportValue {
  subSportType,
  startedAt,
  endedAt,
  totalDuration,
  effectiveDuration,
  distance,
  totalCalories,
  activeCalories,
  averagePace,
  bestPace,
  worstPace,
  averageSpeed,
  bestSpeed,
  totalSteps,
  averageStride,
  averageCadence,
  maximumCadence,
  averageHeartRate,
  maximumHeartRate,
  minimumHeartRate,
  averageBloodOxygen,
  maximumBloodOxygen,
  minimumBloodOxygen,
  averageStress,
  maximumStress,
  minimumStress,
  totalAscent,
  totalDescent,
  averageAltitude,
  maximumAltitude,
  minimumAltitude,
  aerobicEffect,
  anaerobicEffect,
  peakEffect,
  vo2Max,
  bodyEnergy,
  recoveryHours,
  heartRateZoneMethod,
  heartRateZone5Duration,
  heartRateZone4Duration,
  heartRateZone3Duration,
  heartRateZone2Duration,
  heartRateZone1Duration,
  heartRateZone5Lower,
  heartRateZone4Lower,
  heartRateZone3Lower,
  heartRateZone2Lower,
  heartRateZone1Lower,
  trainingLoad,
  earnedVitality,
  averagePower,
  maximumPower,
  totalArmPulls,
  mainSwimmingStroke,
  averageStrokeRate,
  maximumStrokeRate,
  turnCount,
  averageSwolf,
  bestSwolf,
  poolWidth,
  totalJumps,
  averageJumpRate,
  bestJumpRate,
  tripCount,
  setCount,
  totalStrokes,
  averageRowingRate,
  bestRowingRate,
}

class _ModernSportReportField {
  const _ModernSportReportField.u8(
    this.value,
    this.validityIndex,
    this.offset, {
    this.always = false,
  }) : type = _SportWireType.u8,
       byteSize = 1;
  const _ModernSportReportField.u16(
    this.value,
    this.validityIndex,
    this.offset, {
    this.always = false,
  }) : type = _SportWireType.u16,
       byteSize = 2;
  const _ModernSportReportField.u32(
    this.value,
    this.validityIndex,
    this.offset, {
    this.always = false,
  }) : type = _SportWireType.u32,
       byteSize = 4;
  const _ModernSportReportField.f32(
    this.value,
    this.validityIndex,
    this.offset, {
    this.always = false,
  }) : type = _SportWireType.f32,
       byteSize = 4;

  final _WorkoutReportValue value;
  final int validityIndex;
  final int offset;
  final _SportWireType type;
  final int byteSize;

  /// When true the field is read from the fixed body offset even if the
  /// validity bit is clear. The walking-v2 v6 report's 9-byte validity header
  /// uses a different bit order than the v8/v9 schema, so honoring those bits
  /// would drop fields that are actually present; read fixed offsets instead.
  final bool always;
}

const _modernOutdoorFootReportFields = <_ModernSportReportField>[
  _ModernSportReportField.u16(_WorkoutReportValue.subSportType, 0, 0),
  _ModernSportReportField.u32(_WorkoutReportValue.startedAt, 1, 2),
  _ModernSportReportField.u32(_WorkoutReportValue.endedAt, 2, 6),
  _ModernSportReportField.u32(_WorkoutReportValue.totalDuration, 3, 10),
  _ModernSportReportField.u32(_WorkoutReportValue.effectiveDuration, 4, 14),
  _ModernSportReportField.u32(_WorkoutReportValue.distance, 5, 18),
  _ModernSportReportField.u16(_WorkoutReportValue.totalCalories, 6, 22),
  _ModernSportReportField.u16(_WorkoutReportValue.activeCalories, 7, 24),
  _ModernSportReportField.u32(_WorkoutReportValue.averagePace, 8, 26),
  _ModernSportReportField.u32(_WorkoutReportValue.bestPace, 9, 30),
  _ModernSportReportField.u32(_WorkoutReportValue.worstPace, 10, 34),
  _ModernSportReportField.f32(_WorkoutReportValue.averageSpeed, 11, 38),
  _ModernSportReportField.f32(_WorkoutReportValue.bestSpeed, 12, 42),
  _ModernSportReportField.u32(_WorkoutReportValue.totalSteps, 13, 46),
  _ModernSportReportField.u16(_WorkoutReportValue.averageStride, 14, 50),
  _ModernSportReportField.u16(_WorkoutReportValue.averageCadence, 15, 52),
  _ModernSportReportField.u16(_WorkoutReportValue.maximumCadence, 16, 54),
  _ModernSportReportField.u8(_WorkoutReportValue.averageHeartRate, 17, 56),
  _ModernSportReportField.u8(_WorkoutReportValue.maximumHeartRate, 18, 57),
  _ModernSportReportField.u8(_WorkoutReportValue.minimumHeartRate, 19, 58),
  _ModernSportReportField.f32(_WorkoutReportValue.totalAscent, 20, 59),
  _ModernSportReportField.f32(_WorkoutReportValue.totalDescent, 21, 63),
  _ModernSportReportField.f32(_WorkoutReportValue.averageAltitude, 22, 67),
  _ModernSportReportField.f32(_WorkoutReportValue.maximumAltitude, 23, 71),
  _ModernSportReportField.f32(_WorkoutReportValue.minimumAltitude, 24, 75),
  _ModernSportReportField.f32(_WorkoutReportValue.aerobicEffect, 25, 79),
  _ModernSportReportField.f32(_WorkoutReportValue.anaerobicEffect, 27, 84),
  _ModernSportReportField.f32(_WorkoutReportValue.peakEffect, 29, 89),
  _ModernSportReportField.u8(_WorkoutReportValue.vo2Max, 31, 94),
  _ModernSportReportField.u8(_WorkoutReportValue.bodyEnergy, 33, 96),
  _ModernSportReportField.u16(_WorkoutReportValue.recoveryHours, 34, 97),
  _ModernSportReportField.u8(_WorkoutReportValue.heartRateZoneMethod, 35, 99),
  _ModernSportReportField.u32(
    _WorkoutReportValue.heartRateZone5Duration,
    36,
    100,
  ),
  _ModernSportReportField.u32(
    _WorkoutReportValue.heartRateZone4Duration,
    37,
    104,
  ),
  _ModernSportReportField.u32(
    _WorkoutReportValue.heartRateZone3Duration,
    38,
    108,
  ),
  _ModernSportReportField.u32(
    _WorkoutReportValue.heartRateZone2Duration,
    39,
    112,
  ),
  _ModernSportReportField.u32(
    _WorkoutReportValue.heartRateZone1Duration,
    40,
    116,
  ),
  _ModernSportReportField.u8(_WorkoutReportValue.heartRateZone5Lower, 41, 120),
  _ModernSportReportField.u8(_WorkoutReportValue.heartRateZone4Lower, 42, 121),
  _ModernSportReportField.u8(_WorkoutReportValue.heartRateZone3Lower, 43, 122),
  _ModernSportReportField.u8(_WorkoutReportValue.heartRateZone2Lower, 44, 123),
  _ModernSportReportField.u8(_WorkoutReportValue.heartRateZone1Lower, 45, 124),
  _ModernSportReportField.u16(_WorkoutReportValue.trainingLoad, 61, 179),
  _ModernSportReportField.u8(_WorkoutReportValue.earnedVitality, 70, 196),
];

// SPORTS_OUTDOOR_WALKING_V2 v6 report. Unlike the record layout (v5 = the v8
// schema truncated to 13 bytes), the v6 report body does NOT match the v8/v9
// schema: the captured body is 183 bytes (v8 needs 241) and its HR-zone block
// sits at offset 95, not the schema's 100. The server no longer hosts this
// older generation, so the offsets below follow the only calibrated authority
// (Gadgetbridge getOutdoorWalkingV2Parser, headerSize 9). The captured file
// ships a 9-byte validity header whose bit order differs from v8/v9, so every
// field is read from its fixed offset (`always: true`) as GB does.
const _modernOutdoorFootV6ReportFields = <_ModernSportReportField>[
  _ModernSportReportField.u16(
    _WorkoutReportValue.subSportType,
    0,
    0,
    always: true,
  ),
  _ModernSportReportField.u32(
    _WorkoutReportValue.startedAt,
    1,
    2,
    always: true,
  ),
  _ModernSportReportField.u32(_WorkoutReportValue.endedAt, 2, 6, always: true),
  _ModernSportReportField.u32(
    _WorkoutReportValue.effectiveDuration,
    3,
    10,
    always: true,
  ),
  _ModernSportReportField.u32(
    _WorkoutReportValue.distance,
    5,
    18,
    always: true,
  ),
  _ModernSportReportField.u16(
    _WorkoutReportValue.totalCalories,
    6,
    22,
    always: true,
  ),
  _ModernSportReportField.u16(
    _WorkoutReportValue.activeCalories,
    7,
    24,
    always: true,
  ),
  _ModernSportReportField.u32(
    _WorkoutReportValue.averagePace,
    8,
    26,
    always: true,
  ),
  _ModernSportReportField.u32(
    _WorkoutReportValue.bestPace,
    9,
    30,
    always: true,
  ),
  _ModernSportReportField.u32(
    _WorkoutReportValue.worstPace,
    10,
    34,
    always: true,
  ),
  _ModernSportReportField.f32(
    _WorkoutReportValue.averageSpeed,
    11,
    38,
    always: true,
  ),
  _ModernSportReportField.f32(
    _WorkoutReportValue.bestSpeed,
    12,
    42,
    always: true,
  ),
  _ModernSportReportField.u32(
    _WorkoutReportValue.totalSteps,
    13,
    46,
    always: true,
  ),
  _ModernSportReportField.u16(
    _WorkoutReportValue.averageStride,
    14,
    50,
    always: true,
  ),
  _ModernSportReportField.u16(
    _WorkoutReportValue.averageCadence,
    15,
    52,
    always: true,
  ),
  _ModernSportReportField.u16(
    _WorkoutReportValue.maximumCadence,
    16,
    54,
    always: true,
  ),
  _ModernSportReportField.u8(
    _WorkoutReportValue.averageHeartRate,
    17,
    56,
    always: true,
  ),
  _ModernSportReportField.u8(
    _WorkoutReportValue.maximumHeartRate,
    18,
    57,
    always: true,
  ),
  _ModernSportReportField.u8(
    _WorkoutReportValue.minimumHeartRate,
    19,
    58,
    always: true,
  ),
  _ModernSportReportField.f32(
    _WorkoutReportValue.aerobicEffect,
    25,
    79,
    always: true,
  ),
  _ModernSportReportField.f32(
    _WorkoutReportValue.anaerobicEffect,
    27,
    84,
    always: true,
  ),
  _ModernSportReportField.u16(
    _WorkoutReportValue.recoveryHours,
    34,
    92,
    always: true,
  ),
  _ModernSportReportField.u32(
    _WorkoutReportValue.heartRateZone5Duration,
    36,
    95,
    always: true,
  ),
  _ModernSportReportField.u32(
    _WorkoutReportValue.heartRateZone4Duration,
    37,
    99,
    always: true,
  ),
  _ModernSportReportField.u32(
    _WorkoutReportValue.heartRateZone3Duration,
    38,
    103,
    always: true,
  ),
  _ModernSportReportField.u32(
    _WorkoutReportValue.heartRateZone2Duration,
    39,
    107,
    always: true,
  ),
  _ModernSportReportField.u32(
    _WorkoutReportValue.heartRateZone1Duration,
    40,
    111,
    always: true,
  ),
  _ModernSportReportField.u16(
    _WorkoutReportValue.trainingLoad,
    61,
    136,
    always: true,
  ),
  _ModernSportReportField.u8(
    _WorkoutReportValue.earnedVitality,
    70,
    153,
    always: true,
  ),
];

const _modernOutdoorNonFootBaseReportFields = <_ModernSportReportField>[
  _ModernSportReportField.u16(_WorkoutReportValue.subSportType, 0, 0),
  _ModernSportReportField.u32(_WorkoutReportValue.startedAt, 1, 2),
  _ModernSportReportField.u32(_WorkoutReportValue.endedAt, 2, 6),
  _ModernSportReportField.u32(_WorkoutReportValue.totalDuration, 3, 10),
  _ModernSportReportField.u32(_WorkoutReportValue.effectiveDuration, 4, 14),
  _ModernSportReportField.u32(_WorkoutReportValue.distance, 5, 18),
  _ModernSportReportField.u16(_WorkoutReportValue.totalCalories, 6, 22),
  _ModernSportReportField.u16(_WorkoutReportValue.activeCalories, 7, 24),
  _ModernSportReportField.u32(_WorkoutReportValue.bestPace, 8, 26),
  _ModernSportReportField.u32(_WorkoutReportValue.worstPace, 9, 30),
  _ModernSportReportField.f32(_WorkoutReportValue.averageSpeed, 10, 34),
  _ModernSportReportField.f32(_WorkoutReportValue.bestSpeed, 11, 38),
  _ModernSportReportField.u8(_WorkoutReportValue.averageHeartRate, 12, 42),
  _ModernSportReportField.u8(_WorkoutReportValue.maximumHeartRate, 13, 43),
  _ModernSportReportField.u8(_WorkoutReportValue.minimumHeartRate, 14, 44),
  _ModernSportReportField.f32(_WorkoutReportValue.totalAscent, 15, 45),
  _ModernSportReportField.f32(_WorkoutReportValue.totalDescent, 16, 49),
  _ModernSportReportField.f32(_WorkoutReportValue.averageAltitude, 17, 53),
  _ModernSportReportField.f32(_WorkoutReportValue.maximumAltitude, 18, 57),
  _ModernSportReportField.f32(_WorkoutReportValue.minimumAltitude, 19, 61),
  _ModernSportReportField.f32(_WorkoutReportValue.aerobicEffect, 20, 65),
  _ModernSportReportField.f32(_WorkoutReportValue.anaerobicEffect, 22, 70),
  _ModernSportReportField.f32(_WorkoutReportValue.peakEffect, 24, 75),
  _ModernSportReportField.u8(_WorkoutReportValue.vo2Max, 26, 80),
  _ModernSportReportField.u8(_WorkoutReportValue.bodyEnergy, 28, 82),
  _ModernSportReportField.u16(_WorkoutReportValue.recoveryHours, 29, 83),
  _ModernSportReportField.u8(_WorkoutReportValue.heartRateZoneMethod, 30, 85),
  _ModernSportReportField.u32(
    _WorkoutReportValue.heartRateZone5Duration,
    31,
    86,
  ),
  _ModernSportReportField.u32(
    _WorkoutReportValue.heartRateZone4Duration,
    32,
    90,
  ),
  _ModernSportReportField.u32(
    _WorkoutReportValue.heartRateZone3Duration,
    33,
    94,
  ),
  _ModernSportReportField.u32(
    _WorkoutReportValue.heartRateZone2Duration,
    34,
    98,
  ),
  _ModernSportReportField.u32(
    _WorkoutReportValue.heartRateZone1Duration,
    35,
    102,
  ),
  _ModernSportReportField.u8(_WorkoutReportValue.heartRateZone5Lower, 36, 106),
  _ModernSportReportField.u8(_WorkoutReportValue.heartRateZone4Lower, 37, 107),
  _ModernSportReportField.u8(_WorkoutReportValue.heartRateZone3Lower, 38, 108),
  _ModernSportReportField.u8(_WorkoutReportValue.heartRateZone2Lower, 39, 109),
  _ModernSportReportField.u8(_WorkoutReportValue.heartRateZone1Lower, 40, 110),
  _ModernSportReportField.u16(_WorkoutReportValue.trainingLoad, 47, 134),
];

const _modernOutdoorNonFootV8ReportFields = <_ModernSportReportField>[
  ..._modernOutdoorNonFootBaseReportFields,
  _ModernSportReportField.u8(_WorkoutReportValue.earnedVitality, 56, 151),
  _ModernSportReportField.u16(_WorkoutReportValue.averageCadence, 57, 152),
  _ModernSportReportField.u16(_WorkoutReportValue.maximumCadence, 58, 154),
];

const _modernOutdoorNonFootV9ReportFields = <_ModernSportReportField>[
  ..._modernOutdoorNonFootBaseReportFields,
  _ModernSportReportField.u8(_WorkoutReportValue.earnedVitality, 50, 138),
  _ModernSportReportField.u16(_WorkoutReportValue.averageCadence, 51, 139),
  _ModernSportReportField.u16(_WorkoutReportValue.maximumCadence, 52, 141),
  _ModernSportReportField.u16(_WorkoutReportValue.averagePower, 60, 154),
  _ModernSportReportField.u16(_WorkoutReportValue.maximumPower, 61, 156),
];

const _modernIndoorRunBaseReportFields = <_ModernSportReportField>[
  _ModernSportReportField.u32(_WorkoutReportValue.startedAt, 0, 0),
  _ModernSportReportField.u32(_WorkoutReportValue.endedAt, 1, 4),
  _ModernSportReportField.u32(_WorkoutReportValue.totalDuration, 2, 8),
  _ModernSportReportField.u32(_WorkoutReportValue.distance, 3, 12),
  _ModernSportReportField.u16(_WorkoutReportValue.activeCalories, 4, 16),
  _ModernSportReportField.u32(_WorkoutReportValue.averagePace, 5, 18),
  _ModernSportReportField.u32(_WorkoutReportValue.bestPace, 6, 22),
  _ModernSportReportField.u32(_WorkoutReportValue.worstPace, 7, 26),
  _ModernSportReportField.u32(_WorkoutReportValue.totalSteps, 8, 30),
  _ModernSportReportField.u16(_WorkoutReportValue.averageStride, 9, 34),
  _ModernSportReportField.u16(_WorkoutReportValue.averageCadence, 10, 36),
  _ModernSportReportField.u16(_WorkoutReportValue.maximumCadence, 11, 38),
  _ModernSportReportField.u8(_WorkoutReportValue.averageHeartRate, 12, 40),
  _ModernSportReportField.u8(_WorkoutReportValue.maximumHeartRate, 13, 41),
  _ModernSportReportField.u8(_WorkoutReportValue.minimumHeartRate, 14, 42),
  _ModernSportReportField.f32(_WorkoutReportValue.aerobicEffect, 15, 43),
  _ModernSportReportField.u8(_WorkoutReportValue.vo2Max, 17, 48),
  _ModernSportReportField.u8(_WorkoutReportValue.bodyEnergy, 19, 50),
  _ModernSportReportField.u16(_WorkoutReportValue.recoveryHours, 20, 51),
  _ModernSportReportField.u32(
    _WorkoutReportValue.heartRateZone5Duration,
    21,
    53,
  ),
  _ModernSportReportField.u32(
    _WorkoutReportValue.heartRateZone4Duration,
    22,
    57,
  ),
  _ModernSportReportField.u32(
    _WorkoutReportValue.heartRateZone3Duration,
    23,
    61,
  ),
  _ModernSportReportField.u32(
    _WorkoutReportValue.heartRateZone2Duration,
    24,
    65,
  ),
  _ModernSportReportField.u32(
    _WorkoutReportValue.heartRateZone1Duration,
    25,
    69,
  ),
  _ModernSportReportField.u8(_WorkoutReportValue.heartRateZone5Lower, 26, 73),
  _ModernSportReportField.u8(_WorkoutReportValue.heartRateZone4Lower, 27, 74),
  _ModernSportReportField.u8(_WorkoutReportValue.heartRateZone3Lower, 28, 75),
  _ModernSportReportField.u8(_WorkoutReportValue.heartRateZone2Lower, 29, 76),
  _ModernSportReportField.u8(_WorkoutReportValue.heartRateZone1Lower, 30, 77),
  _ModernSportReportField.u16(_WorkoutReportValue.totalCalories, 36, 98),
  _ModernSportReportField.u32(_WorkoutReportValue.effectiveDuration, 37, 100),
  _ModernSportReportField.f32(_WorkoutReportValue.anaerobicEffect, 38, 104),
  _ModernSportReportField.f32(_WorkoutReportValue.peakEffect, 40, 109),
  _ModernSportReportField.u16(_WorkoutReportValue.subSportType, 42, 114),
  _ModernSportReportField.u8(_WorkoutReportValue.heartRateZoneMethod, 45, 125),
];

const _modernIndoorRunV13ReportFields = <_ModernSportReportField>[
  ..._modernIndoorRunBaseReportFields,
  _ModernSportReportField.u16(_WorkoutReportValue.trainingLoad, 53, 150),
  _ModernSportReportField.u8(_WorkoutReportValue.earnedVitality, 62, 167),
];

const _modernIndoorRunV14ReportFields = <_ModernSportReportField>[
  ..._modernIndoorRunBaseReportFields,
  _ModernSportReportField.u16(_WorkoutReportValue.trainingLoad, 54, 152),
  _ModernSportReportField.u8(_WorkoutReportValue.earnedVitality, 63, 169),
];

const _modernFreeTrainingReportFields = <_ModernSportReportField>[
  _ModernSportReportField.u32(_WorkoutReportValue.startedAt, 0, 0),
  _ModernSportReportField.u32(_WorkoutReportValue.endedAt, 1, 4),
  _ModernSportReportField.u32(_WorkoutReportValue.totalDuration, 2, 8),
  _ModernSportReportField.u16(_WorkoutReportValue.activeCalories, 3, 12),
  _ModernSportReportField.u8(_WorkoutReportValue.averageHeartRate, 4, 14),
  _ModernSportReportField.u8(_WorkoutReportValue.maximumHeartRate, 5, 15),
  _ModernSportReportField.u8(_WorkoutReportValue.minimumHeartRate, 6, 16),
  _ModernSportReportField.u8(_WorkoutReportValue.averageBloodOxygen, 7, 17),
  _ModernSportReportField.u8(_WorkoutReportValue.maximumBloodOxygen, 8, 18),
  _ModernSportReportField.u8(_WorkoutReportValue.minimumBloodOxygen, 9, 19),
  _ModernSportReportField.u8(_WorkoutReportValue.averageStress, 10, 20),
  _ModernSportReportField.u8(_WorkoutReportValue.maximumStress, 11, 21),
  _ModernSportReportField.u8(_WorkoutReportValue.minimumStress, 12, 22),
  _ModernSportReportField.f32(_WorkoutReportValue.aerobicEffect, 13, 23),
  _ModernSportReportField.u8(_WorkoutReportValue.bodyEnergy, 15, 28),
  _ModernSportReportField.u16(_WorkoutReportValue.recoveryHours, 16, 29),
  _ModernSportReportField.u32(
    _WorkoutReportValue.heartRateZone5Duration,
    17,
    31,
  ),
  _ModernSportReportField.u32(
    _WorkoutReportValue.heartRateZone4Duration,
    18,
    35,
  ),
  _ModernSportReportField.u32(
    _WorkoutReportValue.heartRateZone3Duration,
    19,
    39,
  ),
  _ModernSportReportField.u32(
    _WorkoutReportValue.heartRateZone2Duration,
    20,
    43,
  ),
  _ModernSportReportField.u32(
    _WorkoutReportValue.heartRateZone1Duration,
    21,
    47,
  ),
  _ModernSportReportField.u8(_WorkoutReportValue.heartRateZone5Lower, 22, 51),
  _ModernSportReportField.u8(_WorkoutReportValue.heartRateZone4Lower, 23, 52),
  _ModernSportReportField.u8(_WorkoutReportValue.heartRateZone3Lower, 24, 53),
  _ModernSportReportField.u8(_WorkoutReportValue.heartRateZone2Lower, 25, 54),
  _ModernSportReportField.u8(_WorkoutReportValue.heartRateZone1Lower, 26, 55),
  _ModernSportReportField.u16(_WorkoutReportValue.totalCalories, 27, 56),
  _ModernSportReportField.u32(_WorkoutReportValue.effectiveDuration, 28, 58),
  _ModernSportReportField.f32(_WorkoutReportValue.anaerobicEffect, 29, 62),
  _ModernSportReportField.f32(_WorkoutReportValue.peakEffect, 31, 67),
  _ModernSportReportField.u16(_WorkoutReportValue.subSportType, 33, 72),
  _ModernSportReportField.u8(_WorkoutReportValue.heartRateZoneMethod, 36, 83),
  _ModernSportReportField.u16(_WorkoutReportValue.trainingLoad, 39, 90),
  _ModernSportReportField.u8(_WorkoutReportValue.earnedVitality, 41, 93),
];

const _modernIndoorCyclingV10ReportFields = <_ModernSportReportField>[
  _ModernSportReportField.u32(_WorkoutReportValue.startedAt, 0, 0),
  _ModernSportReportField.u32(_WorkoutReportValue.endedAt, 1, 4),
  _ModernSportReportField.u32(_WorkoutReportValue.totalDuration, 2, 8),
  _ModernSportReportField.u32(_WorkoutReportValue.distance, 3, 12),
  _ModernSportReportField.u16(_WorkoutReportValue.activeCalories, 4, 16),
  _ModernSportReportField.f32(_WorkoutReportValue.bestSpeed, 5, 18),
  _ModernSportReportField.u8(_WorkoutReportValue.averageHeartRate, 6, 22),
  _ModernSportReportField.u8(_WorkoutReportValue.maximumHeartRate, 7, 23),
  _ModernSportReportField.u8(_WorkoutReportValue.minimumHeartRate, 8, 24),
  _ModernSportReportField.f32(_WorkoutReportValue.aerobicEffect, 9, 25),
  _ModernSportReportField.u8(_WorkoutReportValue.bodyEnergy, 11, 30),
  _ModernSportReportField.u16(_WorkoutReportValue.recoveryHours, 12, 31),
  _ModernSportReportField.u32(
    _WorkoutReportValue.heartRateZone5Duration,
    13,
    33,
  ),
  _ModernSportReportField.u32(
    _WorkoutReportValue.heartRateZone4Duration,
    14,
    37,
  ),
  _ModernSportReportField.u32(
    _WorkoutReportValue.heartRateZone3Duration,
    15,
    41,
  ),
  _ModernSportReportField.u32(
    _WorkoutReportValue.heartRateZone2Duration,
    16,
    45,
  ),
  _ModernSportReportField.u32(
    _WorkoutReportValue.heartRateZone1Duration,
    17,
    49,
  ),
  _ModernSportReportField.u8(_WorkoutReportValue.heartRateZone5Lower, 18, 53),
  _ModernSportReportField.u8(_WorkoutReportValue.heartRateZone4Lower, 19, 54),
  _ModernSportReportField.u8(_WorkoutReportValue.heartRateZone3Lower, 20, 55),
  _ModernSportReportField.u8(_WorkoutReportValue.heartRateZone2Lower, 21, 56),
  _ModernSportReportField.u8(_WorkoutReportValue.heartRateZone1Lower, 22, 57),
  _ModernSportReportField.u16(_WorkoutReportValue.totalCalories, 23, 58),
  _ModernSportReportField.u32(_WorkoutReportValue.effectiveDuration, 24, 60),
  _ModernSportReportField.f32(_WorkoutReportValue.anaerobicEffect, 25, 64),
  _ModernSportReportField.f32(_WorkoutReportValue.peakEffect, 27, 69),
  _ModernSportReportField.u8(_WorkoutReportValue.heartRateZoneMethod, 31, 83),
  _ModernSportReportField.u16(_WorkoutReportValue.averageCadence, 35, 94),
  _ModernSportReportField.u16(_WorkoutReportValue.maximumCadence, 36, 96),
  _ModernSportReportField.u16(_WorkoutReportValue.averagePower, 37, 98),
  _ModernSportReportField.u16(_WorkoutReportValue.maximumPower, 38, 100),
  _ModernSportReportField.u16(_WorkoutReportValue.trainingLoad, 45, 120),
  _ModernSportReportField.u8(_WorkoutReportValue.vo2Max, 54, 137),
  _ModernSportReportField.u8(_WorkoutReportValue.earnedVitality, 56, 139),
];

const _modernSwimmingV8ReportFields = <_ModernSportReportField>[
  _ModernSportReportField.u32(_WorkoutReportValue.startedAt, 0, 0),
  _ModernSportReportField.u32(_WorkoutReportValue.endedAt, 1, 4),
  _ModernSportReportField.u32(_WorkoutReportValue.totalDuration, 2, 8),
  _ModernSportReportField.u32(_WorkoutReportValue.distance, 3, 12),
  _ModernSportReportField.u16(_WorkoutReportValue.activeCalories, 4, 16),
  _ModernSportReportField.u32(_WorkoutReportValue.averagePace, 5, 18),
  _ModernSportReportField.u32(_WorkoutReportValue.bestPace, 6, 22),
  _ModernSportReportField.u32(_WorkoutReportValue.worstPace, 7, 26),
  _ModernSportReportField.u8(_WorkoutReportValue.bodyEnergy, 8, 30),
  _ModernSportReportField.u16(_WorkoutReportValue.recoveryHours, 9, 31),
  _ModernSportReportField.u16(_WorkoutReportValue.totalArmPulls, 10, 33),
  _ModernSportReportField.u8(_WorkoutReportValue.mainSwimmingStroke, 11, 35),
  _ModernSportReportField.u8(_WorkoutReportValue.averageStrokeRate, 12, 36),
  _ModernSportReportField.u8(_WorkoutReportValue.maximumStrokeRate, 13, 37),
  _ModernSportReportField.u16(_WorkoutReportValue.turnCount, 14, 38),
  _ModernSportReportField.u16(_WorkoutReportValue.averageSwolf, 15, 40),
  _ModernSportReportField.u16(_WorkoutReportValue.bestSwolf, 16, 42),
  _ModernSportReportField.u8(_WorkoutReportValue.poolWidth, 17, 44),
  _ModernSportReportField.u16(_WorkoutReportValue.totalCalories, 18, 45),
  _ModernSportReportField.u32(_WorkoutReportValue.effectiveDuration, 19, 47),
  _ModernSportReportField.f32(_WorkoutReportValue.aerobicEffect, 25, 67),
  _ModernSportReportField.f32(_WorkoutReportValue.anaerobicEffect, 27, 72),
  _ModernSportReportField.u16(_WorkoutReportValue.trainingLoad, 29, 77),
  _ModernSportReportField.u8(_WorkoutReportValue.earnedVitality, 31, 80),
  _ModernSportReportField.u8(_WorkoutReportValue.averageHeartRate, 46, 100),
  _ModernSportReportField.u8(_WorkoutReportValue.maximumHeartRate, 47, 101),
  _ModernSportReportField.u8(_WorkoutReportValue.minimumHeartRate, 48, 102),
  _ModernSportReportField.u8(_WorkoutReportValue.heartRateZoneMethod, 49, 103),
  _ModernSportReportField.u32(
    _WorkoutReportValue.heartRateZone5Duration,
    50,
    104,
  ),
  _ModernSportReportField.u32(
    _WorkoutReportValue.heartRateZone4Duration,
    51,
    108,
  ),
  _ModernSportReportField.u32(
    _WorkoutReportValue.heartRateZone3Duration,
    52,
    112,
  ),
  _ModernSportReportField.u32(
    _WorkoutReportValue.heartRateZone2Duration,
    53,
    116,
  ),
  _ModernSportReportField.u32(
    _WorkoutReportValue.heartRateZone1Duration,
    54,
    120,
  ),
  _ModernSportReportField.u8(_WorkoutReportValue.heartRateZone5Lower, 55, 124),
  _ModernSportReportField.u8(_WorkoutReportValue.heartRateZone4Lower, 56, 125),
  _ModernSportReportField.u8(_WorkoutReportValue.heartRateZone3Lower, 57, 126),
  _ModernSportReportField.u8(_WorkoutReportValue.heartRateZone2Lower, 58, 127),
  _ModernSportReportField.u8(_WorkoutReportValue.heartRateZone1Lower, 59, 128),
];

const _modernRopeSkippingV7ReportFields = <_ModernSportReportField>[
  ..._modernSimpleTrainingCoreReportFields,
  _ModernSportReportField.u32(_WorkoutReportValue.totalJumps, 22, 52),
  _ModernSportReportField.u32(_WorkoutReportValue.averageJumpRate, 23, 56),
  _ModernSportReportField.u32(_WorkoutReportValue.bestJumpRate, 24, 60),
  _ModernSportReportField.u8(_WorkoutReportValue.setCount, 31, 88),
  _ModernSportReportField.u32(_WorkoutReportValue.effectiveDuration, 32, 89),
  _ModernSportReportField.f32(_WorkoutReportValue.anaerobicEffect, 33, 93),
  _ModernSportReportField.f32(_WorkoutReportValue.peakEffect, 35, 98),
  _ModernSportReportField.u8(_WorkoutReportValue.heartRateZoneMethod, 39, 112),
  _ModernSportReportField.u16(_WorkoutReportValue.tripCount, 43, 121),
  _ModernSportReportField.u16(_WorkoutReportValue.trainingLoad, 44, 123),
  _ModernSportReportField.u8(_WorkoutReportValue.earnedVitality, 46, 126),
];

const _modernRowingV8ReportFields = <_ModernSportReportField>[
  ..._modernSimpleTrainingCoreReportFields,
  _ModernSportReportField.u32(_WorkoutReportValue.totalStrokes, 22, 52),
  _ModernSportReportField.u32(_WorkoutReportValue.averageRowingRate, 23, 56),
  _ModernSportReportField.u32(_WorkoutReportValue.bestRowingRate, 24, 60),
  _ModernSportReportField.u8(_WorkoutReportValue.setCount, 28, 76),
  _ModernSportReportField.u32(_WorkoutReportValue.effectiveDuration, 29, 77),
  _ModernSportReportField.f32(_WorkoutReportValue.anaerobicEffect, 30, 81),
  _ModernSportReportField.f32(_WorkoutReportValue.peakEffect, 32, 86),
  _ModernSportReportField.u8(_WorkoutReportValue.heartRateZoneMethod, 36, 100),
  _ModernSportReportField.u16(_WorkoutReportValue.trainingLoad, 40, 109),
  _ModernSportReportField.u8(_WorkoutReportValue.earnedVitality, 42, 112),
];

const _modernEllipticalV7ReportFields = <_ModernSportReportField>[
  _ModernSportReportField.u32(_WorkoutReportValue.startedAt, 0, 0),
  _ModernSportReportField.u32(_WorkoutReportValue.endedAt, 1, 4),
  _ModernSportReportField.u32(_WorkoutReportValue.totalDuration, 2, 8),
  _ModernSportReportField.u16(_WorkoutReportValue.activeCalories, 3, 12),
  _ModernSportReportField.u32(_WorkoutReportValue.totalSteps, 4, 14),
  _ModernSportReportField.u16(_WorkoutReportValue.averageCadence, 5, 18),
  _ModernSportReportField.u16(_WorkoutReportValue.maximumCadence, 6, 20),
  _ModernSportReportField.u8(_WorkoutReportValue.averageHeartRate, 7, 22),
  _ModernSportReportField.u8(_WorkoutReportValue.maximumHeartRate, 8, 23),
  _ModernSportReportField.u8(_WorkoutReportValue.minimumHeartRate, 9, 24),
  _ModernSportReportField.f32(_WorkoutReportValue.aerobicEffect, 10, 25),
  _ModernSportReportField.u8(_WorkoutReportValue.bodyEnergy, 12, 30),
  _ModernSportReportField.u16(_WorkoutReportValue.recoveryHours, 13, 31),
  _ModernSportReportField.u32(
    _WorkoutReportValue.heartRateZone5Duration,
    14,
    33,
  ),
  _ModernSportReportField.u32(
    _WorkoutReportValue.heartRateZone4Duration,
    15,
    37,
  ),
  _ModernSportReportField.u32(
    _WorkoutReportValue.heartRateZone3Duration,
    16,
    41,
  ),
  _ModernSportReportField.u32(
    _WorkoutReportValue.heartRateZone2Duration,
    17,
    45,
  ),
  _ModernSportReportField.u32(
    _WorkoutReportValue.heartRateZone1Duration,
    18,
    49,
  ),
  _ModernSportReportField.u8(_WorkoutReportValue.heartRateZone5Lower, 19, 53),
  _ModernSportReportField.u8(_WorkoutReportValue.heartRateZone4Lower, 20, 54),
  _ModernSportReportField.u8(_WorkoutReportValue.heartRateZone3Lower, 21, 55),
  _ModernSportReportField.u8(_WorkoutReportValue.heartRateZone2Lower, 22, 56),
  _ModernSportReportField.u8(_WorkoutReportValue.heartRateZone1Lower, 23, 57),
  _ModernSportReportField.u16(_WorkoutReportValue.totalCalories, 24, 58),
  _ModernSportReportField.u8(_WorkoutReportValue.setCount, 26, 64),
  _ModernSportReportField.u32(_WorkoutReportValue.effectiveDuration, 27, 65),
  _ModernSportReportField.f32(_WorkoutReportValue.anaerobicEffect, 28, 69),
  _ModernSportReportField.f32(_WorkoutReportValue.peakEffect, 30, 74),
  _ModernSportReportField.u8(_WorkoutReportValue.heartRateZoneMethod, 34, 88),
  _ModernSportReportField.u16(_WorkoutReportValue.trainingLoad, 38, 97),
  _ModernSportReportField.u8(_WorkoutReportValue.earnedVitality, 40, 100),
];

const _modernSimpleTrainingCoreReportFields = <_ModernSportReportField>[
  _ModernSportReportField.u32(_WorkoutReportValue.startedAt, 0, 0),
  _ModernSportReportField.u32(_WorkoutReportValue.endedAt, 1, 4),
  _ModernSportReportField.u32(_WorkoutReportValue.totalDuration, 2, 8),
  _ModernSportReportField.u16(_WorkoutReportValue.activeCalories, 3, 12),
  _ModernSportReportField.u8(_WorkoutReportValue.averageHeartRate, 4, 14),
  _ModernSportReportField.u8(_WorkoutReportValue.maximumHeartRate, 5, 15),
  _ModernSportReportField.u8(_WorkoutReportValue.minimumHeartRate, 6, 16),
  _ModernSportReportField.f32(_WorkoutReportValue.aerobicEffect, 7, 17),
  _ModernSportReportField.u8(_WorkoutReportValue.bodyEnergy, 9, 22),
  _ModernSportReportField.u16(_WorkoutReportValue.recoveryHours, 10, 23),
  _ModernSportReportField.u32(
    _WorkoutReportValue.heartRateZone5Duration,
    11,
    25,
  ),
  _ModernSportReportField.u32(
    _WorkoutReportValue.heartRateZone4Duration,
    12,
    29,
  ),
  _ModernSportReportField.u32(
    _WorkoutReportValue.heartRateZone3Duration,
    13,
    33,
  ),
  _ModernSportReportField.u32(
    _WorkoutReportValue.heartRateZone2Duration,
    14,
    37,
  ),
  _ModernSportReportField.u32(
    _WorkoutReportValue.heartRateZone1Duration,
    15,
    41,
  ),
  _ModernSportReportField.u8(_WorkoutReportValue.heartRateZone5Lower, 16, 45),
  _ModernSportReportField.u8(_WorkoutReportValue.heartRateZone4Lower, 17, 46),
  _ModernSportReportField.u8(_WorkoutReportValue.heartRateZone3Lower, 18, 47),
  _ModernSportReportField.u8(_WorkoutReportValue.heartRateZone2Lower, 19, 48),
  _ModernSportReportField.u8(_WorkoutReportValue.heartRateZone1Lower, 20, 49),
  _ModernSportReportField.u16(_WorkoutReportValue.totalCalories, 21, 50),
];

const _sportOutdoorReportFields = <_SportReportField>[
  _SportReportField(1, 4),
  _SportReportField(2, 4),
  _SportReportField(3, 4),
  _SportReportField(5, 4),
  _SportReportField(6, 2),
  _SportReportField(8, 4),
  _SportReportField(9, 4),
  _SportReportField(12, 4),
  _SportReportField(13, 4),
  _SportReportField(14, 2),
  _SportReportField(16, 1),
  _SportReportField(17, 1),
  _SportReportField(18, 1),
];

const _sportOutdoorBikingReportFields = <_SportReportField>[
  _SportReportField(1, 4),
  _SportReportField(2, 4),
  _SportReportField(3, 4),
  _SportReportField(5, 4),
  _SportReportField(6, 2),
  _SportReportField(8, 4),
  _SportReportField(9, 4),
  _SportReportField(12, 4),
  _SportReportField(16, 1),
  _SportReportField(17, 1),
  _SportReportField(18, 1),
];

const _sportIndoorBikingReportFields = <_SportReportField>[
  _SportReportField(1, 4),
  _SportReportField(2, 4),
  _SportReportField(3, 4),
  _SportReportField(5, 4, minimumVersion: 5),
  _SportReportField(6, 2),
  _SportReportField(12, 4, minimumVersion: 5),
  _SportReportField(16, 1),
  _SportReportField(17, 1),
  _SportReportField(18, 1),
];

const _sportIndoorRunReportFields = <_SportReportField>[
  _SportReportField(1, 4),
  _SportReportField(2, 4),
  _SportReportField(3, 4),
  _SportReportField(5, 4),
  _SportReportField(6, 2),
  _SportReportField(10, 4, minimumVersion: 10),
  _SportReportField(8, 4),
  _SportReportField(9, 4),
  _SportReportField(13, 4),
  _SportReportField(148, 2, minimumVersion: 10),
  _SportReportField(15, 2, minimumVersion: 10),
  _SportReportField(14, 2),
  _SportReportField(16, 1),
  _SportReportField(17, 1),
  _SportReportField(18, 1),
];

const _sportSimpleReportFields = <_SportReportField>[
  _SportReportField(1, 4),
  _SportReportField(2, 4),
  _SportReportField(3, 4),
  _SportReportField(6, 2),
  _SportReportField(16, 1),
  _SportReportField(17, 1),
  _SportReportField(18, 1),
];

const _sportSwimmingReportFields = <_SportReportField>[
  _SportReportField(1, 4),
  _SportReportField(2, 4),
  _SportReportField(3, 4),
  _SportReportField(5, 4),
  _SportReportField(6, 2),
  _SportReportField(10, 4, minimumVersion: 7),
  _SportReportField(8, 4),
  _SportReportField(9, 4),
];

const _sportEllipticalReportFields = <_SportReportField>[
  _SportReportField(1, 4),
  _SportReportField(2, 4),
  _SportReportField(3, 4),
  _SportReportField(6, 2),
  _SportReportField(13, 4),
  _SportReportField(15, 2, minimumVersion: 6),
  _SportReportField(14, 2),
  _SportReportField(16, 1),
  _SportReportField(17, 1),
  _SportReportField(18, 1),
];

const _sportSkiReportFields = <_SportReportField>[
  _SportReportField(1, 4),
  _SportReportField(2, 4),
  _SportReportField(3, 4),
  _SportReportField(5, 4),
  _SportReportField(6, 2),
  _SportReportField(11, 4),
  _SportReportField(12, 4),
  _SportReportField(74, 1),
  _SportReportField(16, 1),
  _SportReportField(17, 1),
  _SportReportField(18, 1),
];
