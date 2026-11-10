import 'dart:typed_data';

import 'package:oronbox/src/core/logging/logging_service.dart';

import 'xiaomi_activity_parser.dart';

class XiaomiDailyParser {
  const XiaomiDailyParser({this.timezoneOffset15Min});

  final int? timezoneOffset15Min;
  static final _log = getLogger('XiaomiDailyParser');

  DateTime _activityTimestamp(int seconds) => xiaomiActivityTimestamp(
    seconds,
    timezoneOffset15Min: timezoneOffset15Min,
  );

  List<XiaomiActivityAbnormalHealthRecord> parseAbnormalHealth(
    Uint8List data,
    int version,
  ) {
    // Mi Fitness' native AbnormalRecordParser supports only v1/v2 here. The
    // parser's binary body follows the seven-byte FitnessDataId and the
    // reserved header byte. Older captures in the wild omitted that reserved
    // byte, so retain a guarded compatibility fallback for those snapshots.
    if (version != 1 && version != 2) return const [];
    final limit = data.length - 4;
    const officialHeaderSize = 8;
    if (limit < 7 + 11) return const [];

    final view = ByteData.sublistView(data);
    var offset = officialHeaderSize;
    if (!_looksLikeAbnormalSegment(view, data, offset, limit, version)) {
      offset = 7;
    }
    final records = <XiaomiActivityAbnormalHealthRecord>[];
    while (offset + (version == 2 ? 12 : 13) <= limit) {
      final startedSeconds = view.getUint32(offset, Endian.little);
      final endedSeconds = view.getUint32(offset + 4, Endian.little);
      final type = data[offset + 8];
      final int threshold;
      final int count;
      if (version == 2) {
        threshold = data[offset + 9];
        count = view.getUint16(offset + 10, Endian.little);
        offset += 12;
      } else {
        threshold = view.getUint16(offset + 9, Endian.little);
        count = view.getUint16(offset + 11, Endian.little);
        offset += 13;
      }

      if (offset + count * 5 > limit) break;
      final kind = switch (type) {
        1 => XiaomiActivityAbnormalHealthKind.highHeartRate,
        2 => XiaomiActivityAbnormalHealthKind.lowHeartRate,
        3 => XiaomiActivityAbnormalHealthKind.lowBloodOxygen,
        4 => XiaomiActivityAbnormalHealthKind.highStress,
        5 => XiaomiActivityAbnormalHealthKind.irregularHeartbeat,
        _ => null,
      };
      final startedAt = startedSeconds == 0
          ? null
          : _activityTimestamp(startedSeconds);
      final endedAt = endedSeconds == 0
          ? null
          : _activityTimestamp(endedSeconds);
      if (count == 0) {
        if (kind == XiaomiActivityAbnormalHealthKind.irregularHeartbeat) {
          final eventStart = startedAt ?? endedAt;
          if (eventStart != null) {
            records.add(
              XiaomiActivityAbnormalHealthRecord(
                timestamp: eventStart,
                kind: XiaomiActivityAbnormalHealthKind.irregularHeartbeat,
                startedAt: eventStart,
                endedAt: endedAt ?? startedAt,
              ),
            );
          }
        }
        continue;
      }
      DateTime? firstSampleAt;
      DateTime? lastSampleAt;
      for (var index = 0; index < count; index++) {
        final timestampSeconds = view.getUint32(offset, Endian.little);
        final value = data[offset + 4];
        offset += 5;
        if (timestampSeconds == 0) continue;
        final sampleAt = _activityTimestamp(timestampSeconds);
        firstSampleAt ??= sampleAt;
        lastSampleAt = sampleAt;
        if (kind == null ||
            kind == XiaomiActivityAbnormalHealthKind.irregularHeartbeat) {
          continue;
        }
        records.add(
          XiaomiActivityAbnormalHealthRecord(
            timestamp: sampleAt,
            value: value,
            kind: kind,
            threshold: threshold,
            startedAt: startedAt,
            endedAt: endedAt,
          ),
        );
      }
      if (kind == XiaomiActivityAbnormalHealthKind.irregularHeartbeat) {
        final eventStart = startedAt ?? firstSampleAt ?? endedAt;
        final eventEnd = endedAt ?? lastSampleAt ?? startedAt;
        if (eventStart != null) {
          records.add(
            XiaomiActivityAbnormalHealthRecord(
              timestamp: eventStart,
              kind: XiaomiActivityAbnormalHealthKind.irregularHeartbeat,
              startedAt: eventStart,
              endedAt: eventEnd,
            ),
          );
        }
      }
    }
    return records;
  }

  bool _looksLikeAbnormalSegment(
    ByteData view,
    Uint8List data,
    int offset,
    int limit,
    int version,
  ) {
    final headerSize = version == 2 ? 12 : 13;
    if (offset + headerSize > limit) return false;
    final type = data[offset + 8];
    if (type < 1 || type > 5) return false;
    final count = version == 2
        ? view.getUint16(offset + 10, Endian.little)
        : view.getUint16(offset + 11, Endian.little);
    return offset + headerSize + count * 5 <= limit;
  }

  XiaomiActivityDailyRecord? parseDaily(
    Uint8List data,
    int timestamp,
    int version,
  ) {
    // Mi Fitness' dailyType=0/fileType=1 is DailyReportParser.  Its
    // one-dimensional validity bitmap has 35 fields and is followed by the
    // fields in the fixed order below.  This is deliberately separate from
    // the packed minute records handled by _parseDailyDetails.
    const fieldSizes = <int>[
      4,
      2,
      1,
      1,
      1,
      4,
      1,
      4,
      1,
      1,
      1,
      1,
      3,
      2,
      2,
      1,
      1,
      4,
      1,
      4,
      1,
      2,
      2,
      1,
      1,
      1,
      1,
      2,
      1,
      1,
      2,
      2,
      2,
      2,
      2,
    ];
    const fieldSupportVersions = <int>[
      1,
      1,
      1,
      1,
      1,
      1,
      1,
      1,
      1,
      1,
      1,
      1,
      1,
      2,
      2,
      3,
      3,
      3,
      3,
      3,
      3,
      4,
      4,
      4,
      5,
      5,
      5,
      5,
      5,
      5,
      6,
      6,
      6,
      6,
      7,
    ];
    final headerSize = switch (version) {
      1 || 2 => 2,
      3 || 4 => 3,
      5 => 4,
      6 || 7 => 5,
      _ => 0,
    };
    final limit = data.length - 4;
    final payloadSize = fieldSizes
        .asMap()
        .entries
        // Some v7 devices omit the optional trailing floors field entirely
        // when its validity bit is clear. Keep the legacy minimum-size guard
        // for the stable report body and let read(34) validate the tail.
        .where((entry) => entry.key < 34)
        .where((entry) => fieldSupportVersions[entry.key] <= version)
        .fold(0, (sum, entry) => sum + entry.value);
    if (headerSize == 0 || limit < 8 + headerSize + payloadSize) {
      return null;
    }
    final view = ByteData.sublistView(data);
    var offset = 8 + headerSize;
    int? read(int field) {
      if (fieldSupportVersions[field] > version) return null;
      final size = fieldSizes[field];
      if (offset + size > limit) return null;
      final value = switch (size) {
        1 => view.getUint8(offset),
        2 when field == 30 => view.getInt16(offset, Endian.little),
        2 => view.getUint16(offset, Endian.little),
        3 =>
          view.getUint8(offset) |
              (view.getUint8(offset + 1) << 8) |
              (view.getUint8(offset + 2) << 16),
        4 => view.getUint32(offset, Endian.little),
        _ => throw StateError('Unsupported Xiaomi daily report field size'),
      };
      offset += size;
      return value;
    }

    final values = <int, int?>{};
    final validFields = <int, bool>{};
    var validityIndex = 0;
    for (var field = 0; field < fieldSizes.length; field++) {
      if (fieldSupportVersions[field] > version) continue;
      validFields[field] =
          (data[8 + validityIndex ~/ 8] & (1 << (7 - validityIndex % 8))) != 0;
      validityIndex++;
      values[field] = read(field);
    }
    bool valid(int field) => validFields[field] ?? false;
    int? value(int field) => valid(field) ? values[field] : null;
    return XiaomiActivityDailyRecord(
      date: _activityTimestamp(timestamp),
      steps: value(0),
      activeCalories: value(1),
      calories: value(13),
      // Slot 2 is reserved. Its byte is consumed above, but not exposed.
      restingHeartRate: value(3),
      maxHeartRate: value(4),
      maxHeartRateAt: _activityTime(value(5)),
      minHeartRate: value(6),
      minHeartRateAt: _activityTime(value(7)),
      averageHeartRate: value(8),
      averageStress: value(9),
      maxStress: value(10),
      minStress: value(11),
      standingBitmap: value(12),
      remainingRecoveryHours: value(14),
      currentBloodOxygen: value(15),
      maxBloodOxygen: value(16),
      maxBloodOxygenAt: _activityTime(value(17)),
      minBloodOxygen: value(18),
      minBloodOxygenAt: _activityTime(value(19)),
      averageBloodOxygen: value(20),
      floorsClimbed: value(34),
      trainingLoadToday: value(21),
      trainingLoadLast7Days: value(22),
      trainingLoadLevel: value(23),
      vitalityIncreaseLight: value(24),
      vitalityIncreaseModerate: value(25),
      vitalityIncreaseHigh: value(26),
      // Field 27 is the device's running 7-day total. It skips zero days on
      // some firmwares, so the per-day earned value is reconstructed from the
      // intensity buckets and the calendar-window total is summed by the UI.
      vitalityCurrent: _vitalityDayTotal(value(24), value(25), value(26)),
      vitalityLast7Days: value(27),
      vitalityNextTargetType: value(28),
      vitalityNextTargetMinutes: value(29),
      fitnessBalance: value(30),
      fitnessLevel: value(31),
      fatigueLevel: value(32),
      trainingStressScore: value(33),
    );
  }

  DateTime? _activityTime(int? seconds) =>
      seconds == null || seconds == 0 ? null : _activityTimestamp(seconds);

  /// Per-day earned vitality reconstructed from the intensity buckets.
  ///
  /// The daily report only carries a running 7-day total, not the day's own
  /// earned points. Summing the light/moderate/high buckets keeps zero days
  /// explicit so the 7-day window is a real calendar sum.
  int? _vitalityDayTotal(int? light, int? moderate, int? high) {
    if (light == null && moderate == null && high == null) return null;
    return (light ?? 0) + (moderate ?? 0) + (high ?? 0);
  }

  List<XiaomiActivitySampleRecord> parseManualMeasures(
    Uint8List data,
    int timestamp,
    int version,
  ) {
    // FitnessDataHeader is: seven-byte FitnessDataId, one reserved byte and
    // (for v1 only) one validity byte. Mi Fitness' ManualMeasureParser then
    // reads a repeated timestamp/type/value stream.
    final valueOffset = version == 1 ? 9 : 8;
    final limit = data.length - 4;
    if ((version != 1 && version != 2 && version != 3) ||
        limit <= valueOffset) {
      return const [];
    }

    final view = ByteData.sublistView(data);
    var offset = valueOffset;
    final values = <int, _ManualMeasureValues>{};
    while (offset + 5 <= limit) {
      final sampleTimestamp = view.getUint32(offset, Endian.little);
      final encodedType = data[offset + 4];
      offset += 5;

      final type = version == 1 ? encodedType : encodedType & 0x0f;
      final valueLength = version == 1
          ? _manualValueLength(type)
          : encodedType >> 4;
      if (valueLength == null ||
          valueLength <= 0 ||
          offset + valueLength > limit) {
        _log.fine(
          'Xiaomi manual measure stream stopped at '
          'type=$type length=$valueLength',
        );
        break;
      }

      if (type == 1 || type == 2 || type == 3) {
        final value = switch (valueLength) {
          1 => data[offset],
          2 => view.getUint16(offset, Endian.little),
          _ => null,
        };
        if (value != null && sampleTimestamp > 0) {
          final record = values.putIfAbsent(
            sampleTimestamp,
            _ManualMeasureValues.new,
          );
          switch (type) {
            case 1:
              record.heartRate = value;
            case 2:
              record.bloodOxygen = value;
            case 3:
              record.stress = value;
          }
        }
      }
      // Types 4 and 5 are temperature and blood pressure. They are consumed
      // here exactly as Mi Fitness does, even though the current health model
      // has no cards for those measurements yet.
      offset += valueLength;
    }

    final result = values.entries.toList()
      ..sort((left, right) => left.key.compareTo(right.key));
    return result
        .map(
          (entry) => XiaomiActivitySampleRecord(
            timestamp: _activityTimestamp(entry.key),
            heartRate: entry.value.heartRate,
            bloodOxygen: entry.value.bloodOxygen,
            stress: entry.value.stress,
          ),
        )
        .toList(growable: false);
  }

  int? _manualValueLength(int type) => switch (type) {
    1 || 2 || 3 => 1,
    4 => 4,
    5 => 6,
    _ => null,
  };

  List<XiaomiActivitySampleRecord> parseDailyDetails(
    Uint8List data,
    int timestamp,
    int version,
  ) {
    // This is the same four-dimensional record layout used by Mi Fitness'
    // DailyRecordParser.  Each validity nibble describes one packed group;
    // groups that are absent do not occupy bytes in the record.
    final groups = version == 1 ? _dailyRecordV1Groups : _dailyRecordV2Groups;
    final headerSize = switch (version) {
      1 || 2 => 4,
      3 => 5,
      4 || 5 => 6,
      _ => 0,
    };
    final limit = data.length - 4;
    if (headerSize == 0 || limit < 8 + headerSize) {
      return const [];
    }

    final validity = data.sublist(8, 8 + headerSize);
    final samples = <XiaomiActivitySampleRecord>[];
    var offset = 8 + headerSize;
    var sampleIndex = 0;
    while (offset < limit) {
      final values = <int, int>{};
      var validityIndex = 0;
      final dynamicAnchorType = switch (version) {
        1 => 13,
        2 => 11,
        _ => 15,
      };
      var dynamicConsumed = false;
      for (final group in groups) {
        if (group.minimumVersion > version) continue;
        final validityByte = validity[validityIndex ~/ 2];
        final shift = validityIndex.isEven ? 4 : 0;
        final flags = (validityByte >> shift) & 0x0f;
        validityIndex++;
        if ((flags & 8) == 0) continue;
        if (offset + group.byteSize > limit) return samples;

        // A few older Vela files use the high validity bit only and leave the
        // per-field bits in the reserved pattern used by the legacy parser.
        // Mi Fitness consumes the whole group in that case. Keep this narrow
        // compatibility path so those files do not lose steps and samples,
        // while using the official field bits whenever any are present.
        final hasOfficialField = group.fields.any(
          (field) => (flags & field.validityBit) != 0,
        );

        final raw = switch (group.byteSize) {
          1 => data[offset],
          2 => ByteData.sublistView(data).getUint16(offset, Endian.little),
          _ => throw StateError('Unsupported Xiaomi daily record group size'),
        };
        offset += group.byteSize;
        for (final field in group.fields) {
          if (!hasOfficialField && (flags & 8) == 0) continue;
          if (hasOfficialField && (flags & field.validityBit) == 0) continue;
          values[field.type] =
              (raw >> field.startBit) & ((1 << field.bitSize) - 1);
        }

        // The dynamic type-16 byte follows the last fixed data-info entry
        // supported by the version. Unsupported v2 entries for SpO2/stress
        // therefore do not move this boundary earlier than the official
        // parser does.
        if (!dynamicConsumed &&
            group.fields.any((field) => field.type == dynamicAnchorType) &&
            values[1] == 1) {
          if (offset >= limit) return samples;
          offset++;
          dynamicConsumed = true;
        }
      }

      // Mi Fitness consumes this dynamic byte when the daily record says an
      // abnormal-heart-rate value is present. It is not exposed as a minute
      // sample; the dedicated dailyType=9 file supplies the event details.
      if (!dynamicConsumed && values[1] == 1) {
        if (offset >= limit) return samples;
        offset++;
      }

      if (values.isEmpty) {
        if (offset <= 8 + headerSize) break;
        sampleIndex++;
        continue;
      }
      int? steps;
      int? activityType;
      int? activityStrength;
      int? sportType;
      int? activeCalories;
      int? distanceMeters;
      int? heartRate;
      int? energy;
      int? caloriesDelta;
      int? energyStatus;
      int? energyStatusValue;
      int? bloodOxygen;
      int? pressure;
      int? lightSensation;
      int? volumeMomentum;
      int? floors;
      int? stress;

      steps = values[2];
      activityType = values[3];
      activeCalories = values[4];
      activityStrength = values[5];
      sportType = values[6];
      distanceMeters = values[7];
      heartRate = values[8];
      energy = values[9];
      // `newCalories` is an increment for this minute. A total is only
      // available in the daily report (`totalCalories`), parsed separately.
      caloriesDelta = values[10] ?? values[11];
      energyStatus = values[12];
      energyStatusValue = values[13];
      bloodOxygen = values[14];
      // The VelaOS record field is named `curPressure`, but it is the
      // minute-level stress value shown by Mi Fitness. Expose it as both the
      // raw pressure field and the stress metric so the stress series is not
      // empty while the daily summary still has a value.
      pressure = values[15];
      stress = values[15];
      lightSensation = values[17];
      volumeMomentum = values[18];
      floors = values[19];
      samples.add(
        XiaomiActivitySampleRecord(
          timestamp: _activityTimestamp(timestamp + sampleIndex * 60),
          activityType: activityType,
          activityStrength: activityStrength,
          sportType: sportType,
          steps: steps,
          activeCalories: activeCalories,
          distanceMeters: distanceMeters,
          heartRate: heartRate,
          energy: energy,
          caloriesDelta: caloriesDelta,
          energyStatus: energyStatus,
          energyStatusValue: energyStatusValue,
          bloodOxygen: bloodOxygen,
          pressure: pressure,
          lightSensation: lightSensation,
          volumeMomentum: volumeMomentum,
          floors: floors,
          stress: stress,
        ),
      );
      sampleIndex++;
    }
    return samples;
  }

}

class _ManualMeasureValues {
  int? heartRate;
  int? bloodOxygen;
  int? stress;
}


const _dailyRecordV1Groups = <_DailyRecordGroup>[
  _DailyRecordGroup(2, <_DailyRecordField>[
    _DailyRecordField(type: 1, startBit: 14, bitSize: 1, validityBit: 4),
    _DailyRecordField(type: 2, startBit: 0, bitSize: 14, validityBit: 3),
  ]),
  _DailyRecordGroup(1, <_DailyRecordField>[
    _DailyRecordField(type: 3, startBit: 4, bitSize: 4, validityBit: 4),
    _DailyRecordField(type: 4, startBit: 0, bitSize: 4, validityBit: 3),
  ]),
  _DailyRecordGroup(1, <_DailyRecordField>[
    _DailyRecordField(type: 5, startBit: 5, bitSize: 3, validityBit: 4),
    _DailyRecordField(type: 6, startBit: 0, bitSize: 5, validityBit: 3),
  ]),
  _DailyRecordGroup(2, <_DailyRecordField>[
    _DailyRecordField(type: 7, startBit: 0, bitSize: 16, validityBit: 4),
  ]),
  _DailyRecordGroup(1, <_DailyRecordField>[
    _DailyRecordField(type: 8, startBit: 0, bitSize: 8, validityBit: 4),
  ]),
  _DailyRecordGroup(1, <_DailyRecordField>[
    _DailyRecordField(type: 9, startBit: 0, bitSize: 8, validityBit: 4),
  ]),
  _DailyRecordGroup(2, <_DailyRecordField>[
    _DailyRecordField(type: 10, startBit: 13, bitSize: 3, validityBit: 4),
    _DailyRecordField(type: 12, startBit: 11, bitSize: 2, validityBit: 2),
    _DailyRecordField(type: 13, startBit: 0, bitSize: 11, validityBit: 1),
  ]),
];

const _dailyRecordV2Groups = <_DailyRecordGroup>[
  _DailyRecordGroup(2, <_DailyRecordField>[
    _DailyRecordField(type: 1, startBit: 14, bitSize: 1, validityBit: 4),
    _DailyRecordField(type: 2, startBit: 0, bitSize: 14, validityBit: 3),
  ]),
  _DailyRecordGroup(1, <_DailyRecordField>[
    _DailyRecordField(type: 3, startBit: 6, bitSize: 2, validityBit: 4),
    _DailyRecordField(type: 4, startBit: 0, bitSize: 6, validityBit: 3),
  ]),
  _DailyRecordGroup(1, <_DailyRecordField>[
    _DailyRecordField(type: 5, startBit: 5, bitSize: 3, validityBit: 4),
    _DailyRecordField(type: 6, startBit: 0, bitSize: 5, validityBit: 3),
  ]),
  _DailyRecordGroup(2, <_DailyRecordField>[
    _DailyRecordField(type: 7, startBit: 0, bitSize: 16, validityBit: 4),
  ]),
  _DailyRecordGroup(1, <_DailyRecordField>[
    _DailyRecordField(type: 8, startBit: 0, bitSize: 8, validityBit: 4),
  ]),
  _DailyRecordGroup(1, <_DailyRecordField>[
    _DailyRecordField(type: 9, startBit: 0, bitSize: 8, validityBit: 4),
  ]),
  _DailyRecordGroup(2, <_DailyRecordField>[
    _DailyRecordField(type: 11, startBit: 10, bitSize: 6, validityBit: 4),
    _DailyRecordField(type: 12, startBit: 8, bitSize: 2, validityBit: 2),
    _DailyRecordField(type: 13, startBit: 0, bitSize: 8, validityBit: 1),
  ]),
  _DailyRecordGroup(1, <_DailyRecordField>[
    _DailyRecordField(type: 14, startBit: 0, bitSize: 8, validityBit: 4),
  ], minimumVersion: 3),
  _DailyRecordGroup(1, <_DailyRecordField>[
    _DailyRecordField(type: 15, startBit: 0, bitSize: 8, validityBit: 4),
  ], minimumVersion: 3),
  // lightSensation is a full uint16 (bits 15-0), not a single byte. Treating it
  // as 1 byte desynchronizes every following record by one byte, which showed
  // up as nonsense heart rates (32 / 156 / 224 bpm) in the UI.
  _DailyRecordGroup(2, <_DailyRecordField>[
    _DailyRecordField(type: 17, startBit: 0, bitSize: 16, validityBit: 4),
  ], minimumVersion: 4),
  // bodyMomentum is likewise a full uint16.
  _DailyRecordGroup(2, <_DailyRecordField>[
    _DailyRecordField(type: 18, startBit: 0, bitSize: 16, validityBit: 4),
  ], minimumVersion: 4),
  _DailyRecordGroup(1, <_DailyRecordField>[
    _DailyRecordField(type: 19, startBit: 0, bitSize: 8, validityBit: 4),
  ], minimumVersion: 5),
];

class _DailyRecordGroup {
  const _DailyRecordGroup(
    this.byteSize,
    this.fields, {
    this.minimumVersion = 1,
  });

  final int byteSize;
  final List<_DailyRecordField> fields;
  final int minimumVersion;
}

class _DailyRecordField {
  const _DailyRecordField({
    required this.type,
    required this.startBit,
    required this.bitSize,
    required this.validityBit,
  });

  final int type;
  final int startBit;
  final int bitSize;
  final int validityBit;
}
