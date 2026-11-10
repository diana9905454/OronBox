import 'dart:typed_data';

import 'xiaomi_activity_parser.dart';

class XiaomiSleepParser {
  const XiaomiSleepParser({this.timezoneOffset15Min});

  final int? timezoneOffset15Min;

  DateTime _activityTimestamp(int seconds) => xiaomiActivityTimestamp(
    seconds,
    timezoneOffset15Min: timezoneOffset15Min,
  );

  static XiaomiActivitySleepRecord? primarySleepRecord(
    List<XiaomiActivitySleepRecord> records,
  ) {
    if (records.isEmpty) return null;
    final indexed = records.where((value) => value.sleepIndex == 1);
    final candidates = indexed.isEmpty ? records : indexed;
    return candidates.reduce(
      (left, right) =>
          left.durationSeconds >= right.durationSeconds ? left : right,
    );
  }

  List<XiaomiActivitySleepRecord> parseSleepDetails(
    Uint8List data,
    int version,
    int limit,
  ) => _parseSleepDetails(data, version, limit);

  List<XiaomiActivitySleepRecord> parseSleep(
    Uint8List data,
    int timestamp,
    int version,
    int subtype,
  ) {
    if (subtype == 3 && version == 2) {
      final record = _parseSleepStages(data);
      return record == null ? const [] : [record];
    }
    final limit = data.length - 4;
    if (subtype == 8) {
      return _parseSleepDetails(data, version, limit);
    }
    if (limit < 37) return const [];
    final view = ByteData.sublistView(data);
    final offset = 8 + 7;
    final durationMinutes = view.getUint16(offset, Endian.little);
    final started = view.getUint32(offset + 2, Endian.little);
    final ended = view.getUint32(offset + 6, Endian.little);
    if (started == 0 || ended == 0 || durationMinutes == 0) return const [];
    return [
      XiaomiActivitySleepRecord(
        startedAt: _activityTimestamp(started),
        endedAt: _activityTimestamp(ended),
        durationSeconds: durationMinutes * 60,
      ),
    ];
  }

  List<XiaomiActivitySleepRecord> _parseSleepDetails(
    Uint8List data,
    int version,
    int limit,
  ) {
    // Versions 1–4 use the older compact all-day-sleep layout.  The schema
    // files shipped by Mi Fitness define the report layout used by versions 5
    // and 6; do not apply that layout to the compact files.
    if (version < 5) {
      return _parseLegacySleepDetails(data, version, limit);
    }
    if (version > 6) return const [];
    final validityLength = _sleepValidityLength(version);
    // sleepFull(1) + start/end(8) + quality/efficiency(2) + four u32
    // duration/time fields(16). v6 appends eleven HRV summary fields:
    // six u16 values, one u32 timestamp, and four more u16 values.
    const fixedRecordLength = 27;
    const hrvSummaryLength = 24;
    final minimumRecordLength =
        fixedRecordLength + (version == 6 ? hrvSummaryLength : 0);
    if (validityLength == 0 ||
        limit < 8 + validityLength + minimumRecordLength) {
      return const [];
    }
    final view = ByteData.sublistView(data);
    final validity = data.sublist(8, 8 + validityLength);
    var offset = 8 + validityLength;

    // Mi Fitness's schema parser consumes the fixed record in this order. The
    // validity bits only mark a value as usable; they do not remove the value
    // from the body.
    int? readUint8() {
      if (offset + 1 > limit) return null;
      return data[offset++];
    }

    int? readUint32() {
      if (offset + 4 > limit) return null;
      final value = view.getUint32(offset, Endian.little);
      offset += 4;
      return value;
    }

    int? readUint16() {
      if (offset + 2 > limit) return null;
      final value = view.getUint16(offset, Endian.little);
      offset += 2;
      return value;
    }

    final sleepFullRaw = readUint8();
    final startedRaw = readUint32();
    final endedRaw = readUint32();
    final qualityRaw = readUint8();
    final efficiencyRaw = readUint8();
    final asleepDurationRaw = readUint32();
    final bedDurationRaw = readUint32();
    final goBedRaw = readUint32();
    final leaveBedRaw = readUint32();
    if ([
      sleepFullRaw,
      startedRaw,
      endedRaw,
      qualityRaw,
      efficiencyRaw,
      asleepDurationRaw,
      bedDurationRaw,
      goBedRaw,
      leaveBedRaw,
    ].any((value) => value == null)) {
      return const [];
    }

    int? hrvAverageRaw;
    int? hrvStandardDeviationRaw;
    int? hrvMedianRaw;
    int? hrvLowerQuantileRaw;
    int? hrvUpperQuantileRaw;
    int? hrvMiddleQuantileRaw;
    int? hrvTimestampRaw;
    int? hrvMaximumRaw;
    int? hrvMinimumRaw;
    int? hrvBaselineMaximumRaw;
    int? hrvBaselineMinimumRaw;
    if (version == 6) {
      hrvAverageRaw = readUint16();
      hrvStandardDeviationRaw = readUint16();
      hrvMedianRaw = readUint16();
      hrvLowerQuantileRaw = readUint16();
      hrvUpperQuantileRaw = readUint16();
      hrvMiddleQuantileRaw = readUint16();
      hrvTimestampRaw = readUint32();
      hrvMaximumRaw = readUint16();
      hrvMinimumRaw = readUint16();
      hrvBaselineMaximumRaw = readUint16();
      hrvBaselineMinimumRaw = readUint16();
      if ([
        hrvAverageRaw,
        hrvStandardDeviationRaw,
        hrvMedianRaw,
        hrvLowerQuantileRaw,
        hrvUpperQuantileRaw,
        hrvMiddleQuantileRaw,
        hrvTimestampRaw,
        hrvMaximumRaw,
        hrvMinimumRaw,
        hrvBaselineMaximumRaw,
        hrvBaselineMinimumRaw,
      ].any((value) => value == null)) {
        return const [];
      }
    }

    final heartRate = _readSleepRecordSeries(
      view: view,
      limit: limit,
      offset: offset,
      version: version,
      valid: _sleepValidity(validity, version, _SleepValidityField.heartRate),
    );
    offset = heartRate.offset;
    final bloodOxygen = _readSleepRecordSeries(
      view: view,
      limit: limit,
      offset: offset,
      version: version,
      valid: _sleepValidity(validity, version, _SleepValidityField.bloodOxygen),
    );
    offset = bloodOxygen.offset;

    final hrv = _readSleepRecordSeries(
      view: view,
      limit: limit,
      offset: offset,
      version: version,
      valid:
          version == 6 &&
          _sleepValidity(validity, version, _SleepValidityField.hrvSeries),
      sampleWidth: 2,
    );
    offset = hrv.offset;

    final snore = _readSleepRecordSeries(
      view: view,
      limit: limit,
      offset: offset,
      version: version,
      valid: _sleepValidity(validity, version, _SleepValidityField.snore),
      sampleWidth: 4,
    );
    offset = snore.offset;

    // Mi Fitness calls the remaining bytes featureData and passes them to its
    // native sleep algorithm. The known packet stream is decoded when
    // present; other feature-data records remain opaque.
    final stagePackets = _parseSleepStagePackets(data, offset, limit);
    final packetSummary = stagePackets.summary;
    final startedValue =
        _sleepValidity(validity, version, _SleepValidityField.start) &&
            startedRaw! > 0
        ? startedRaw
        : null;
    final endedValue =
        _sleepValidity(validity, version, _SleepValidityField.end) &&
            endedRaw! > 0
        ? endedRaw
        : null;
    final goBedValue =
        _sleepValidity(validity, version, _SleepValidityField.goBed) &&
            goBedRaw! > 0
        ? goBedRaw
        : null;
    final leaveBedValue =
        _sleepValidity(validity, version, _SleepValidityField.leaveBed) &&
            leaveBedRaw! > 0
        ? leaveBedRaw
        : null;

    var resolvedStarted = startedValue ?? goBedValue;
    var resolvedEnded = endedValue ?? leaveBedValue;
    final reportedDuration =
        _sleepValidity(validity, version, _SleepValidityField.asleepDuration) &&
            asleepDurationRaw! > 0
        ? asleepDurationRaw
        : null;
    if (resolvedStarted == null &&
        resolvedEnded != null &&
        reportedDuration != null) {
      resolvedStarted = resolvedEnded - reportedDuration;
    }
    if (resolvedEnded == null &&
        resolvedStarted != null &&
        reportedDuration != null) {
      resolvedEnded = resolvedStarted + reportedDuration;
    }
    // The device summary carries one entry per real sleep segment; a single
    // file may legitimately contain a main night plus a following segment.
    // Expand them below instead of collapsing to the file header. Progressive
    // snapshots of the same segment are reconciled by bedtime in HealthStore.
    if (packetSummary != null &&
        packetSummary.startedAtSeconds > 0 &&
        packetSummary.endedAtSeconds > packetSummary.startedAtSeconds) {
      resolvedStarted = packetSummary.startedAtSeconds;
      resolvedEnded = packetSummary.endedAtSeconds;
    }
    if (resolvedStarted == null || resolvedEnded == null) return const [];
    if (resolvedEnded <= resolvedStarted) return const [];
    final heartRateStats = heartRate.statsBetween(
      resolvedStarted,
      resolvedEnded,
    );
    final bloodOxygenStats = bloodOxygen.statsBetween(
      resolvedStarted,
      resolvedEnded,
    );
    final hrvPoints = hrv.firstRecordTimeSeconds <= 0
        ? const <XiaomiActivitySleepHrvPoint>[]
        : hrv.values
              .asMap()
              .entries
              .where((entry) => entry.value != null && entry.value! > 0)
              .map(
                (entry) => XiaomiActivitySleepHrvPoint(
                  timestamp: _activityTimestamp(
                    hrv.firstRecordTimeSeconds +
                        entry.key * hrv.intervalSeconds,
                  ),
                  value: entry.value!,
                ),
              )
              .toList(growable: false);
    final heartRatePoints = _sleepVitalPoints(
      heartRate,
      startedAtSeconds: resolvedStarted,
      endedAtSeconds: resolvedEnded,
      useSleepStartWhenFirstTimeMissing: version < 2,
      includeOutsideSleepWindow: true,
    );
    final bloodOxygenPoints = _sleepVitalPoints(
      bloodOxygen,
      startedAtSeconds: resolvedStarted,
      endedAtSeconds: resolvedEnded,
      useSleepStartWhenFirstTimeMissing: version < 2,
      includeOutsideSleepWindow: true,
    );
    final packetDuration = packetSummary?.durationMinutes;
    final duration = packetDuration != null && packetDuration > 0
        ? packetDuration * 60
        : reportedDuration ?? resolvedEnded - resolvedStarted;
    final base = XiaomiActivitySleepRecord(
      startedAt: _activityTimestamp(resolvedStarted),
      endedAt: _activityTimestamp(resolvedEnded),
      durationSeconds: duration,
      averageHeartRate: heartRateStats?.average,
      averageBloodOxygen: bloodOxygenStats?.average,
      minimumHeartRate: heartRateStats?.minimum,
      maximumHeartRate: heartRateStats?.maximum,
      minimumBloodOxygen: bloodOxygenStats?.minimum,
      maximumBloodOxygen: bloodOxygenStats?.maximum,
      quality:
          _sleepValidity(validity, version, _SleepValidityField.quality) &&
              qualityRaw! >= 0
          ? qualityRaw
          : null,
      sleepEfficiency:
          _sleepValidity(validity, version, _SleepValidityField.efficiency) &&
              efficiencyRaw! >= 0
          ? efficiencyRaw
          : null,
      bedDurationSeconds:
          _sleepValidity(validity, version, _SleepValidityField.bedDuration) &&
              bedDurationRaw! > 0
          ? bedDurationRaw
          : null,
      goBedAt: goBedValue == null ? null : _activityTimestamp(goBedValue),
      leaveBedAt: leaveBedValue == null
          ? null
          : _activityTimestamp(leaveBedValue),
      awakeDurationSeconds: packetSummary == null
          ? null
          : packetSummary.awakeDurationMinutes * 60,
      lightSleepDurationSeconds: packetSummary == null
          ? null
          : packetSummary.lightDurationMinutes * 60,
      deepSleepDurationSeconds: packetSummary == null
          ? null
          : packetSummary.deepDurationMinutes * 60,
      remSleepDurationSeconds: packetSummary == null
          ? null
          : packetSummary.remDurationMinutes * 60,
      sleepIndex: packetSummary?.sleepIndex,
      wakeCount: packetSummary?.wakeCount,
      hasRem: packetSummary?.hasRem,
      hasStage:
          packetSummary?.hasStage ??
          (stagePackets.stages.isEmpty ? null : true),
      sleepScoreVersion: packetSummary?.sleepScoreVersion,
      averageHrv:
          version == 6 &&
              _sleepValidity(
                validity,
                version,
                _SleepValidityField.hrvAverage,
              ) &&
              hrvAverageRaw! > 0
          ? hrvAverageRaw
          : null,
      hrvStandardDeviation:
          version == 6 &&
              _sleepValidity(
                validity,
                version,
                _SleepValidityField.hrvStandardDeviation,
              )
          ? hrvStandardDeviationRaw
          : null,
      hrvMedian:
          version == 6 &&
              _sleepValidity(validity, version, _SleepValidityField.hrvMedian)
          ? hrvMedianRaw
          : null,
      hrvLowerQuantile:
          version == 6 &&
              _sleepValidity(
                validity,
                version,
                _SleepValidityField.hrvLowerQuantile,
              )
          ? hrvLowerQuantileRaw
          : null,
      hrvUpperQuantile:
          version == 6 &&
              _sleepValidity(
                validity,
                version,
                _SleepValidityField.hrvUpperQuantile,
              )
          ? hrvUpperQuantileRaw
          : null,
      hrvMiddleQuantile:
          version == 6 &&
              _sleepValidity(
                validity,
                version,
                _SleepValidityField.hrvMiddleQuantile,
              )
          ? hrvMiddleQuantileRaw
          : null,
      hrvTimestamp:
          version == 6 &&
              _sleepValidity(
                validity,
                version,
                _SleepValidityField.hrvTimestamp,
              ) &&
              hrvTimestampRaw! > 0
          ? _activityTimestamp(hrvTimestampRaw)
          : null,
      hrvMax:
          version == 6 &&
              _sleepValidity(
                validity,
                version,
                _SleepValidityField.hrvMaximum,
              ) &&
              hrvMaximumRaw! > 0
          ? hrvMaximumRaw
          : null,
      hrvMin:
          version == 6 &&
              _sleepValidity(
                validity,
                version,
                _SleepValidityField.hrvMinimum,
              ) &&
              hrvMinimumRaw! > 0
          ? hrvMinimumRaw
          : null,
      hrvBaselineMax:
          version == 6 &&
              _sleepValidity(
                validity,
                version,
                _SleepValidityField.hrvBaselineMaximum,
              )
          ? hrvBaselineMaximumRaw
          : null,
      hrvBaselineMin:
          version == 6 &&
              _sleepValidity(
                validity,
                version,
                _SleepValidityField.hrvBaselineMinimum,
              )
          ? hrvBaselineMinimumRaw
          : null,
      hrvPoints: hrvPoints,
      heartRatePoints: heartRatePoints,
      bloodOxygenPoints: bloodOxygenPoints,
      stages: stagePackets.stages,
    );
    return _expandSleepPacketSummaries(
      base: base,
      packets: stagePackets,
      heartRate: heartRate,
      bloodOxygen: bloodOxygen,
    );
  }

  /// Expands the device summaries instead of collapsing the packet stream to
  /// the main night. Mi Fitness's native parser returns every
  /// [SleepStageSummary]; index 1 is only the preferred summary when a caller
  /// needs one representative night.
  List<XiaomiActivitySleepRecord> _expandSleepPacketSummaries({
    required XiaomiActivitySleepRecord base,
    required _SleepPacketParseResult packets,
    required _SleepByteSeries heartRate,
    required _SleepByteSeries bloodOxygen,
  }) {
    if (packets.summaries.isEmpty) {
      return [
        base.copyWith(
          heartRatePoints: _sleepVitalPointsInInterval(
            base.heartRatePoints,
            base.startedAt,
            base.endedAt,
          ),
          bloodOxygenPoints: _sleepVitalPointsInInterval(
            base.bloodOxygenPoints,
            base.startedAt,
            base.endedAt,
          ),
        ),
      ];
    }
    final segmentSummaries = packets.summaries
        .where(
          (summary) =>
              summary.startedAtSeconds > 0 &&
              summary.endedAtSeconds > summary.startedAtSeconds,
        )
        .toList(growable: false);
    // The nightly aggregates on `base` (quality, sleep efficiency, bed times
    // and the HRV summary) describe the main night only. Xiaomi numbers the
    // main segment with sleepIndex 1; when the firmware does not number
    // segments, the longest one is the main night. Copying these fields onto
    // every segment would make a nap inherit the night's score.
    var mainIndex = segmentSummaries.indexWhere(
      (summary) => summary.sleepIndex == 1,
    );
    if (mainIndex < 0) {
      mainIndex = 0;
      for (var index = 1; index < segmentSummaries.length; index++) {
        if (segmentSummaries[index].durationMinutes >
            segmentSummaries[mainIndex].durationMinutes) {
          mainIndex = index;
        }
      }
    }
    final records = segmentSummaries.indexed
        .map((entry) {
          final summary = entry.$2;
          final isMainSleep = entry.$1 == mainIndex;
          final startedAt = _activityTimestamp(summary.startedAtSeconds);
          final endedAt = _activityTimestamp(summary.endedAtSeconds);
          // Mi Fitness only attaches assist data to a segment for which the
          // device supplied stage data. Each statistic is recomputed inside
          // that segment's own interval; a segment with no matching samples
          // must not inherit the all-day/first-segment value.
          final heartRateStats = summary.hasStage
              ? heartRate.statsBetween(
                  summary.startedAtSeconds,
                  summary.endedAtSeconds,
                )
              : null;
          final bloodOxygenStats = summary.hasStage
              ? bloodOxygen.statsBetween(
                  summary.startedAtSeconds,
                  summary.endedAtSeconds,
                )
              : null;
          final hrvPoints = base.hrvPoints
              .where(
                (point) =>
                    !point.timestamp.isBefore(startedAt) &&
                    point.timestamp.isBefore(endedAt),
              )
              .toList(growable: false);
          final heartRatePoints = summary.hasStage
              ? _sleepVitalPointsInInterval(
                  base.heartRatePoints,
                  startedAt,
                  endedAt,
                )
              : const <XiaomiActivitySleepVitalPoint>[];
          final bloodOxygenPoints = summary.hasStage
              ? _sleepVitalPointsInInterval(
                  base.bloodOxygenPoints,
                  startedAt,
                  endedAt,
                )
              : const <XiaomiActivitySleepVitalPoint>[];
          final stages = summary.hasStage
              ? packets.stages
                    .where(
                      (stage) =>
                          !stage.timestamp.isBefore(startedAt) &&
                          stage.timestamp.isBefore(endedAt),
                    )
                    .toList(growable: false)
              : const <XiaomiActivitySleepStageRecord>[];
          return XiaomiActivitySleepRecord(
            startedAt: startedAt,
            endedAt: endedAt,
            durationSeconds: summary.durationMinutes * 60,
            averageHeartRate: heartRateStats?.average,
            minimumHeartRate: heartRateStats?.minimum,
            maximumHeartRate: heartRateStats?.maximum,
            averageBloodOxygen: bloodOxygenStats?.average,
            minimumBloodOxygen: bloodOxygenStats?.minimum,
            maximumBloodOxygen: bloodOxygenStats?.maximum,
            quality: isMainSleep ? base.quality : null,
            sleepEfficiency: isMainSleep ? base.sleepEfficiency : null,
            bedDurationSeconds: isMainSleep ? base.bedDurationSeconds : null,
            goBedAt: isMainSleep ? base.goBedAt : null,
            leaveBedAt: isMainSleep ? base.leaveBedAt : null,
            awakeDurationSeconds: summary.awakeDurationMinutes * 60,
            lightSleepDurationSeconds: summary.lightDurationMinutes * 60,
            deepSleepDurationSeconds: summary.deepDurationMinutes * 60,
            remSleepDurationSeconds: summary.remDurationMinutes * 60,
            averageHrv: isMainSleep ? base.averageHrv : null,
            hrvMin: isMainSleep ? base.hrvMin : null,
            hrvMax: isMainSleep ? base.hrvMax : null,
            hrvBaselineMin: isMainSleep ? base.hrvBaselineMin : null,
            hrvBaselineMax: isMainSleep ? base.hrvBaselineMax : null,
            hrvStandardDeviation: isMainSleep
                ? base.hrvStandardDeviation
                : null,
            hrvMedian: isMainSleep ? base.hrvMedian : null,
            hrvLowerQuantile: isMainSleep ? base.hrvLowerQuantile : null,
            hrvMiddleQuantile: isMainSleep ? base.hrvMiddleQuantile : null,
            hrvUpperQuantile: isMainSleep ? base.hrvUpperQuantile : null,
            hrvTimestamp: isMainSleep ? base.hrvTimestamp : null,
            sleepIndex: summary.sleepIndex,
            wakeCount: summary.wakeCount,
            hasRem: summary.hasRem,
            hasStage: summary.hasStage,
            sleepScoreVersion: summary.sleepScoreVersion,
            hrvPoints: hrvPoints,
            heartRatePoints: heartRatePoints,
            bloodOxygenPoints: bloodOxygenPoints,
            stages: stages,
          );
        })
        .toList(growable: false);
    return records.isEmpty ? [base] : records;
  }

  List<XiaomiActivitySleepRecord> _parseLegacySleepDetails(
    Uint8List data,
    int version,
    int limit,
  ) {
    final headerSize = version >= 5 ? 2 : 1;
    if (version < 1 || version > 4 || limit < 8 + headerSize + 9) {
      return const [];
    }
    final view = ByteData.sublistView(data);
    final header = data.sublist(8, 8 + headerSize);
    var offset = 8 + headerSize;
    if (offset >= limit) return const [];
    offset++; // compact sleep-finished/awake flag
    if (offset + 8 > limit) return const [];
    final started = view.getUint32(offset, Endian.little);
    final ended = view.getUint32(offset + 4, Endian.little);
    offset += 8;
    if (started == 0 || ended <= started) return const [];

    int? quality;
    var headerIndex = 3;
    if (version >= 4) {
      if (offset >= limit) return const [];
      if (_validHeaderBit(header, headerIndex)) {
        quality = view.getUint8(offset);
      }
      offset++;
      headerIndex++;
    }

    final heartRate = _readSleepByteSeries(
      view,
      data,
      limit,
      offset,
      version,
      _validHeaderBit(header, headerIndex),
    );
    offset = heartRate.offset;
    headerIndex++;
    final bloodOxygen = _readSleepByteSeries(
      view,
      data,
      limit,
      offset,
      version,
      _validHeaderBit(header, headerIndex),
    );
    offset = bloodOxygen.offset;
    headerIndex++;
    if (version >= 3) {
      final snore = _readSleepByteSeries(
        view,
        data,
        limit,
        offset,
        version,
        _validHeaderBit(header, headerIndex),
        sampleWidth: 4,
      );
      offset = snore.offset;
    }
    final stagePackets = _parseSleepStagePackets(data, offset, limit);
    final packetSummary = stagePackets.summary;
    var resolvedStarted = started;
    var resolvedEnded = ended;
    if (packetSummary != null &&
        packetSummary.startedAtSeconds > 0 &&
        packetSummary.endedAtSeconds > packetSummary.startedAtSeconds) {
      resolvedStarted = packetSummary.startedAtSeconds;
      resolvedEnded = packetSummary.endedAtSeconds;
    }
    final heartRateStats = heartRate.statsBetween(
      resolvedStarted,
      resolvedEnded,
    );
    final bloodOxygenStats = bloodOxygen.statsBetween(
      resolvedStarted,
      resolvedEnded,
    );
    final durationSeconds =
        packetSummary != null && packetSummary.durationMinutes > 0
        ? packetSummary.durationMinutes * 60
        : resolvedEnded - resolvedStarted;
    final heartRatePoints = _sleepVitalPoints(
      heartRate,
      startedAtSeconds: resolvedStarted,
      endedAtSeconds: resolvedEnded,
      useSleepStartWhenFirstTimeMissing: version < 2,
      includeOutsideSleepWindow: true,
    );
    final bloodOxygenPoints = _sleepVitalPoints(
      bloodOxygen,
      startedAtSeconds: resolvedStarted,
      endedAtSeconds: resolvedEnded,
      useSleepStartWhenFirstTimeMissing: version < 2,
      includeOutsideSleepWindow: true,
    );
    final base = XiaomiActivitySleepRecord(
      startedAt: _activityTimestamp(resolvedStarted),
      endedAt: _activityTimestamp(resolvedEnded),
      durationSeconds: durationSeconds,
      averageHeartRate: heartRateStats?.average,
      averageBloodOxygen: bloodOxygenStats?.average,
      minimumHeartRate: heartRateStats?.minimum,
      maximumHeartRate: heartRateStats?.maximum,
      minimumBloodOxygen: bloodOxygenStats?.minimum,
      maximumBloodOxygen: bloodOxygenStats?.maximum,
      quality: quality,
      awakeDurationSeconds: packetSummary == null
          ? null
          : packetSummary.awakeDurationMinutes * 60,
      lightSleepDurationSeconds: packetSummary == null
          ? null
          : packetSummary.lightDurationMinutes * 60,
      deepSleepDurationSeconds: packetSummary == null
          ? null
          : packetSummary.deepDurationMinutes * 60,
      remSleepDurationSeconds: packetSummary == null
          ? null
          : packetSummary.remDurationMinutes * 60,
      sleepIndex: packetSummary?.sleepIndex,
      wakeCount: packetSummary?.wakeCount,
      hasRem: packetSummary?.hasRem,
      hasStage:
          packetSummary?.hasStage ??
          (stagePackets.stages.isEmpty ? null : true),
      sleepScoreVersion: packetSummary?.sleepScoreVersion,
      heartRatePoints: heartRatePoints,
      bloodOxygenPoints: bloodOxygenPoints,
      stages: stagePackets.stages,
    );
    return _expandSleepPacketSummaries(
      base: base,
      packets: stagePackets,
      heartRate: heartRate,
      bloodOxygen: bloodOxygen,
    );
  }

  XiaomiActivitySleepRecord? _parseSleepStages(Uint8List data) {
    final limit = data.length - 4;
    if (limit < 37) return null;
    final view = ByteData.sublistView(data);
    var offset = 8 + 7;
    final durationMinutes = view.getUint16(offset, Endian.little);
    final started = view.getUint32(offset + 2, Endian.little);
    final ended = view.getUint32(offset + 6, Endian.little);
    offset += 10;
    if (started == 0 || ended <= started || durationMinutes == 0) return null;
    final totalsOffset = offset + 3;
    if (totalsOffset + 8 > limit) return null;
    final deepDurationMinutes = view.getUint16(totalsOffset, Endian.little);
    final lightDurationMinutes = view.getUint16(
      totalsOffset + 2,
      Endian.little,
    );
    final remDurationMinutes = view.getUint16(totalsOffset + 4, Endian.little);
    final awakeDurationMinutes = view.getUint16(
      totalsOffset + 6,
      Endian.little,
    );
    // Three reserved bytes, four stage totals, then one trailing reserved
    // byte precede the five-byte stage records.
    offset += 3 + 8 + 1;
    final stages = <XiaomiActivitySleepStageRecord>[];
    while (offset + 5 <= limit) {
      final timestamp = view.getUint32(offset, Endian.little);
      final stage = _sleepStageFileValue(data[offset + 4]);
      if (timestamp != 0 && stage >= 0) {
        stages.add(
          XiaomiActivitySleepStageRecord(
            timestamp: _activityTimestamp(timestamp),
            stage: stage,
          ),
        );
      }
      offset += 5;
    }
    return XiaomiActivitySleepRecord(
      startedAt: _activityTimestamp(started),
      endedAt: _activityTimestamp(ended),
      durationSeconds: durationMinutes * 60,
      awakeDurationSeconds: awakeDurationMinutes * 60,
      lightSleepDurationSeconds: lightDurationMinutes * 60,
      deepSleepDurationSeconds: deepDurationMinutes * 60,
      remSleepDurationSeconds: remDurationMinutes * 60,
      hasRem: remDurationMinutes > 0,
      hasStage: stages.isNotEmpty,
      stages: stages,
    );
  }

  _SleepPacketParseResult _parseSleepStagePackets(
    Uint8List data,
    int offset,
    int limit,
  ) {
    // The feature-data tail uses the packet stream consumed by Mi Fitness:
    // magic 0xfb 0xfa 0xfc 0xff, a five-byte header prefix, a little-endian
    // timestamp, parity, type, and a big-endian payload length. Type 16 is a
    // compact summary record; type 17 contains big-endian stage/duration
    // points. The device has already performed stage classification before
    // this stream is sent, so this parser only decodes the wire records.
    final view = ByteData.sublistView(data);
    final stages = <XiaomiActivitySleepStageRecord>[];
    // Type-16 packets are progressive snapshots of the same sleep source.
    // Keep the last cumulative packet for each source timestamp; the official
    // parser exposes only the final SleepStageSummary list.
    final summaryPackets = <int, List<_SleepPacketSummary>>{};
    var sleepScoreVersion = 0;
    while (offset + 17 <= limit) {
      if (view.getUint32(offset, Endian.little) != 0xfffcfafb) {
        offset++;
        continue;
      }
      final type = data[offset + 14];
      final dataLength = (data[offset + 15] << 8) | data[offset + 16];
      final timestamp = view.getUint64(offset + 5, Endian.little);
      final payloadOffset = offset + 17;
      if (type == 2 ||
          type == 3 ||
          type == 9 ||
          type == 12 ||
          type == 13 ||
          type == 14 ||
          type == 15) {
        // These packet types carry flags in the two bytes that otherwise look
        // like a length. They have no payload in the sleep stream.
        offset = payloadOffset;
        continue;
      }
      if (payloadOffset + dataLength > limit) break;
      offset = payloadOffset;
      if (type == 19) {
        // Mi Fitness's native parser marks device-provided summaries as
        // score-version 1 when this marker is present.
        sleepScoreVersion = 1;
      } else if (type == 16 && dataLength >= 13) {
        // Native Mi Fitness accepts N consecutive 13-byte summaries in one
        // type-16 payload. The first starts at the packet timestamp; each
        // following summary starts after the previous interval plus its
        // trailing one-byte gap.
        var currentTimestamp = timestamp;
        final payloadEnd = offset + dataLength;
        final packetSummaries = <_SleepPacketSummary>[];
        for (
          var recordOffset = offset;
          recordOffset + 13 <= payloadEnd;
          recordOffset += 13
        ) {
          final sleepIndexAndWakeCount = data[recordOffset];
          final sleepIndex = sleepIndexAndWakeCount >> 4;
          final wakeCount = sleepIndexAndWakeCount & 0x0f;
          final durationMinutes = view.getUint16(recordOffset + 1, Endian.big);
          final awakeDurationMinutes = view.getUint16(
            recordOffset + 3,
            Endian.big,
          );
          final lightDurationMinutes = view.getUint16(
            recordOffset + 5,
            Endian.big,
          );
          final remDurationMinutes = view.getUint16(
            recordOffset + 7,
            Endian.big,
          );
          final deepDurationMinutes = view.getUint16(
            recordOffset + 9,
            Endian.big,
          );
          final flags = data[recordOffset + 11];
          final remState = (flags >> 4) & 0x03;
          final stageState = (flags >> 2) & 0x03;
          final unknownDurationMinutes = data[recordOffset + 12];
          final endedTimestamp =
              currentTimestamp + (durationMinutes + awakeDurationMinutes) * 60;
          packetSummaries.add(
            _SleepPacketSummary(
              startedAtSeconds: currentTimestamp,
              endedAtSeconds: endedTimestamp,
              durationMinutes: durationMinutes,
              awakeDurationMinutes: awakeDurationMinutes,
              lightDurationMinutes: lightDurationMinutes,
              remDurationMinutes: remDurationMinutes,
              deepDurationMinutes: deepDurationMinutes,
              sleepIndex: sleepIndex,
              wakeCount: wakeCount,
              hasRem: remState == 1,
              hasStage: stageState == 1,
              unknownDurationMinutes: unknownDurationMinutes,
              sleepScoreVersion: sleepScoreVersion == 0
                  ? null
                  : sleepScoreVersion,
            ),
          );
          currentTimestamp = endedTimestamp + unknownDurationMinutes * 60;
        }
        summaryPackets[timestamp] = packetSummaries;
      } else if (type == 17) {
        var current = timestamp * 1000;
        for (var index = 0; index + 1 < dataLength; index += 2) {
          final value = view.getUint16(offset + index, Endian.big);
          final durationMinutes = value & 0xfff;
          final stage = _sleepStageDetailValue(value >> 12);
          if (stage >= 0) {
            stages.add(
              XiaomiActivitySleepStageRecord(
                timestamp: _activityTimestamp(current ~/ 1000),
                stage: stage,
                endedAt: durationMinutes == 0
                    ? null
                    : _activityTimestamp(
                        current ~/ 1000 + durationMinutes * 60,
                      ),
              ),
            );
          }
          current += durationMinutes * 60 * 1000;
        }
      }
      offset += dataLength;
    }
    final summaries = summaryPackets.values.expand((value) => value).toList();
    final finalSummaries = sleepScoreVersion == 0
        ? summaries
        : summaries
              .map(
                (summary) =>
                    summary.copyWith(sleepScoreVersion: sleepScoreVersion),
              )
              .toList(growable: false);
    return _SleepPacketParseResult(stages: stages, summaries: finalSummaries);
  }

  int _sleepValidityLength(int version) => switch (version) {
    5 => 2,
    6 => 3,
    _ => 0,
  };

  bool _sleepValidity(
    Uint8List validity,
    int version,
    _SleepValidityField field,
  ) {
    final index = switch (version) {
      5 => switch (field) {
        _SleepValidityField.start => 0,
        _SleepValidityField.end => 1,
        _SleepValidityField.quality => 2,
        _SleepValidityField.efficiency => 3,
        _SleepValidityField.asleepDuration => 4,
        _SleepValidityField.bedDuration => 5,
        _SleepValidityField.goBed => 6,
        _SleepValidityField.leaveBed => 7,
        _SleepValidityField.heartRate => 8,
        _SleepValidityField.bloodOxygen => 9,
        _SleepValidityField.snore => 10,
        _ => -1,
      },
      6 => switch (field) {
        _SleepValidityField.start => 0,
        _SleepValidityField.end => 1,
        _SleepValidityField.quality => 2,
        _SleepValidityField.efficiency => 3,
        _SleepValidityField.asleepDuration => 4,
        _SleepValidityField.bedDuration => 5,
        _SleepValidityField.goBed => 6,
        _SleepValidityField.leaveBed => 7,
        _SleepValidityField.hrvAverage => 8,
        _SleepValidityField.hrvStandardDeviation => 9,
        _SleepValidityField.hrvMedian => 10,
        _SleepValidityField.hrvLowerQuantile => 11,
        _SleepValidityField.hrvUpperQuantile => 12,
        _SleepValidityField.hrvMiddleQuantile => 13,
        _SleepValidityField.hrvTimestamp => 14,
        _SleepValidityField.hrvMaximum => 15,
        _SleepValidityField.hrvMinimum => 16,
        _SleepValidityField.hrvBaselineMaximum => 17,
        _SleepValidityField.hrvBaselineMinimum => 18,
        _SleepValidityField.heartRate => 19,
        _SleepValidityField.bloodOxygen => 20,
        _SleepValidityField.hrvSeries => 21,
        _SleepValidityField.snore => 22,
      },
      _ => -1,
    };
    return _validHeaderBit(validity, index);
  }

  _SleepByteSeries _readSleepRecordSeries({
    required ByteData view,
    required int limit,
    required int offset,
    required int version,
    required bool valid,
    int sampleWidth = 1,
    int validMinimum = 1,
    int validMaximum = 254,
  }) {
    // The record block is conditional on its validity bit in the official
    // v5/v6 schema.  Do not consume bytes for an absent block.
    if (!valid) return _SleepByteSeries(offset: offset);
    if (offset + 4 > limit) return _SleepByteSeries(offset: limit);
    final interval = view.getUint16(offset, Endian.little);
    final count = view.getUint16(offset + 2, Endian.little);
    offset += 4;
    if (count == 0) return _SleepByteSeries(offset: offset);
    var firstRecordTime = 0;
    if (version >= 2) {
      if (offset + 4 > limit) return _SleepByteSeries(offset: limit);
      firstRecordTime = view.getUint32(offset, Endian.little);
      offset += 4;
    }
    final remaining = limit - offset;
    if (sampleWidth <= 0 || count > remaining ~/ sampleWidth) {
      return _SleepByteSeries(offset: limit);
    }
    final end = offset + count * sampleWidth;
    final values = <int?>[];
    for (var index = 0; index < count; index++) {
      final value = switch (sampleWidth) {
        1 => view.getUint8(offset + index),
        2 => view.getUint16(offset + index * 2, Endian.little),
        4 => view.getUint32(offset + index * 4, Endian.little),
        _ => null,
      };
      if (value == null) {
        values.add(null);
      } else if (sampleWidth == 1 &&
          (value < validMinimum || value > validMaximum)) {
        values.add(null);
      } else {
        values.add(value);
      }
    }
    // Keep the read of interval and firstRecordTime explicit: both are part
    // of the wire format even though the summary model only needs averages.
    if (interval < 0 || firstRecordTime < 0) {
      return _SleepByteSeries(offset: end);
    }
    return _SleepByteSeries(
      offset: end,
      average: _SleepByteSeries._stats(values)?.average,
      minimum: _SleepByteSeries._stats(values)?.minimum,
      maximum: _SleepByteSeries._stats(values)?.maximum,
      intervalSeconds: interval,
      firstRecordTimeSeconds: firstRecordTime,
      values: values,
    );
  }

  List<XiaomiActivitySleepVitalPoint> _sleepVitalPoints(
    _SleepByteSeries series, {
    required int startedAtSeconds,
    required int endedAtSeconds,
    required bool useSleepStartWhenFirstTimeMissing,
    bool includeOutsideSleepWindow = false,
  }) {
    if (series.values.isEmpty || series.intervalSeconds <= 0) {
      return const [];
    }
    final firstRecordTime = series.firstRecordTimeSeconds > 0
        ? series.firstRecordTimeSeconds
        : useSleepStartWhenFirstTimeMissing
        ? startedAtSeconds
        : 0;
    if (firstRecordTime <= 0) return const [];
    final points = <XiaomiActivitySleepVitalPoint>[];
    for (var index = 0; index < series.values.length; index++) {
      final value = series.values[index];
      if (value == null) continue;
      final timestamp = firstRecordTime + index * series.intervalSeconds;
      if (!includeOutsideSleepWindow &&
          (timestamp < startedAtSeconds || timestamp >= endedAtSeconds)) {
        continue;
      }
      points.add(
        XiaomiActivitySleepVitalPoint(
          timestamp: _activityTimestamp(timestamp),
          value: value,
        ),
      );
    }
    return List.unmodifiable(points);
  }

  List<XiaomiActivitySleepVitalPoint> _sleepVitalPointsInInterval(
    List<XiaomiActivitySleepVitalPoint> points,
    DateTime startedAt,
    DateTime endedAt,
  ) => List.unmodifiable(
    points.where(
      (point) =>
          !point.timestamp.isBefore(startedAt) &&
          point.timestamp.isBefore(endedAt),
    ),
  );

  int _sleepStageFileValue(int raw) => switch (raw) {
    2 || 3 || 4 || 5 => raw,
    _ => -1,
  };

  int _sleepStageDetailValue(int raw) => switch (raw) {
    0 => 5,
    1 => 3,
    2 => 2,
    3 => 4,
    4 => 0,
    _ => 1,
  };

  _SleepByteSeries _readSleepByteSeries(
    ByteData view,
    Uint8List data,
    int limit,
    int offset,
    int version,
    bool valid, {
    int sampleWidth = 1,
  }) {
    if (!valid) return _SleepByteSeries(offset: offset);
    if (offset + 4 > limit) return _SleepByteSeries(offset: limit);
    final interval = view.getUint16(offset, Endian.little);
    offset += 2;
    final count = view.getUint16(offset, Endian.little);
    offset += 2;
    var firstRecordTime = 0;
    if (version >= 2) {
      if (offset + 4 > limit) return _SleepByteSeries(offset: limit);
      firstRecordTime = view.getUint32(offset, Endian.little);
      offset += 4;
    }
    final available = (limit - offset) ~/ sampleWidth;
    final samplesToRead = available.clamp(0, count);
    if (samplesToRead == 0) {
      return _SleepByteSeries(offset: offset + available * sampleWidth);
    }
    final values = <int?>[];
    for (var index = 0; index < samplesToRead; index++) {
      if (sampleWidth == 1) {
        final value = data[offset + index];
        values.add(value == 0 || value == 255 ? null : value);
      }
    }
    final end = offset + samplesToRead * sampleWidth;
    final stats = _SleepByteSeries._stats(values);
    return _SleepByteSeries(
      offset: end,
      average: stats?.average,
      minimum: stats?.minimum,
      maximum: stats?.maximum,
      intervalSeconds: interval,
      firstRecordTimeSeconds: firstRecordTime,
      values: values,
    );
  }

  bool _validHeaderBit(Uint8List header, int index) =>
      index >= 0 && index < header.length * 8
      ? (header[index ~/ 8] & (1 << (7 - index % 8))) != 0
      : false;
}

class _SleepByteSeries {
  const _SleepByteSeries({
    required this.offset,
    this.average,
    this.minimum,
    this.maximum,
    this.intervalSeconds = 0,
    this.firstRecordTimeSeconds = 0,
    this.values = const [],
  });

  final int offset;
  final int? average;
  final int? minimum;
  final int? maximum;
  final int intervalSeconds;
  final int firstRecordTimeSeconds;
  final List<int?> values;

  _SleepSeriesStats? statsBetween(int startedAt, int endedAt) {
    if (values.isEmpty) {
      if (average == null || minimum == null || maximum == null) return null;
      return _SleepSeriesStats(
        average: average!,
        minimum: minimum!,
        maximum: maximum!,
      );
    }
    if (intervalSeconds <= 0 || firstRecordTimeSeconds <= 0) {
      return _stats(values);
    }
    final selected = <int?>[];
    for (var index = 0; index < values.length; index++) {
      final timestamp = firstRecordTimeSeconds + index * intervalSeconds;
      if (timestamp >= startedAt && timestamp <= endedAt) {
        selected.add(values[index]);
      }
    }
    // A timestamped series with no samples inside this segment must stay
    // empty. Falling back to the whole file leaks another sleep segment's
    // vitals into this one's summary.
    return _stats(selected);
  }

  static _SleepSeriesStats? _stats(Iterable<int?> input) {
    var count = 0;
    var total = 0;
    int? minimum;
    int? maximum;
    for (final value in input) {
      if (value == null) continue;
      count++;
      total += value;
      minimum = minimum == null || value < minimum ? value : minimum;
      maximum = maximum == null || value > maximum ? value : maximum;
    }
    if (count == 0 || minimum == null || maximum == null) return null;
    return _SleepSeriesStats(
      average: (total / count).round(),
      minimum: minimum,
      maximum: maximum,
    );
  }
}

class _SleepSeriesStats {
  const _SleepSeriesStats({
    required this.average,
    required this.minimum,
    required this.maximum,
  });

  final int average;
  final int minimum;
  final int maximum;
}

enum _SleepValidityField {
  start,
  end,
  quality,
  efficiency,
  asleepDuration,
  bedDuration,
  goBed,
  leaveBed,
  hrvAverage,
  hrvStandardDeviation,
  hrvMedian,
  hrvLowerQuantile,
  hrvUpperQuantile,
  hrvMiddleQuantile,
  hrvTimestamp,
  hrvMaximum,
  hrvMinimum,
  hrvBaselineMaximum,
  hrvBaselineMinimum,
  heartRate,
  bloodOxygen,
  hrvSeries,
  snore,
}

class _SleepPacketParseResult {
  const _SleepPacketParseResult({
    required this.stages,
    this.summaries = const [],
  });

  final List<XiaomiActivitySleepStageRecord> stages;
  final List<_SleepPacketSummary> summaries;

  /// Mi Fitness keeps the night with sleepIndex 1 when several summaries are
  /// present. If no indexed night exists, use the longest device summary.
  _SleepPacketSummary? get summary {
    if (summaries.isEmpty) return null;
    final indexed = summaries.where((value) => value.sleepIndex == 1);
    final candidates = indexed.isEmpty ? summaries : indexed;
    return candidates.reduce(
      (left, right) =>
          left.durationMinutes >= right.durationMinutes ? left : right,
    );
  }
}

class _SleepPacketSummary {
  const _SleepPacketSummary({
    required this.startedAtSeconds,
    required this.endedAtSeconds,
    required this.durationMinutes,
    required this.awakeDurationMinutes,
    required this.lightDurationMinutes,
    required this.remDurationMinutes,
    required this.deepDurationMinutes,
    required this.sleepIndex,
    required this.wakeCount,
    required this.hasRem,
    required this.hasStage,
    required this.unknownDurationMinutes,
    required this.sleepScoreVersion,
  });

  final int startedAtSeconds;
  final int endedAtSeconds;
  final int durationMinutes;
  final int awakeDurationMinutes;
  final int lightDurationMinutes;
  final int remDurationMinutes;
  final int deepDurationMinutes;
  final int sleepIndex;
  final int wakeCount;
  final bool hasRem;
  final bool hasStage;
  final int unknownDurationMinutes;
  final int? sleepScoreVersion;

  _SleepPacketSummary copyWith({int? sleepScoreVersion}) => _SleepPacketSummary(
    startedAtSeconds: startedAtSeconds,
    endedAtSeconds: endedAtSeconds,
    durationMinutes: durationMinutes,
    awakeDurationMinutes: awakeDurationMinutes,
    lightDurationMinutes: lightDurationMinutes,
    remDurationMinutes: remDurationMinutes,
    deepDurationMinutes: deepDurationMinutes,
    sleepIndex: sleepIndex,
    wakeCount: wakeCount,
    hasRem: hasRem,
    hasStage: hasStage,
    unknownDurationMinutes: unknownDurationMinutes,
    sleepScoreVersion: sleepScoreVersion ?? this.sleepScoreVersion,
  );
}
