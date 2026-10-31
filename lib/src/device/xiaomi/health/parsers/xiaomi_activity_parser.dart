import 'dart:typed_data';

import 'package:oronbox/src/core/logging/logging_service.dart';
import 'package:oronbox/src/device/core/device_state.dart';

import '../models/xiaomi_activity_models.dart';
import 'xiaomi_daily_parser.dart';
import 'xiaomi_sleep_parser.dart';
import 'xiaomi_workout_parser.dart';

export '../models/xiaomi_activity_models.dart';
export 'xiaomi_daily_parser.dart';
export 'xiaomi_sleep_parser.dart';
export 'xiaomi_workout_parser.dart';

final _log = getLogger('XiaomiActivityParser');

/// Converts a timestamp from Xiaomi's activity-file protocol.
///
/// Activity-file timestamps are local wall-clock values represented as an
/// epoch-shaped integer. The file ID carries the device timezone in signed
/// 15-minute units. When that value is available, add it to the wire instant
/// and expose the resulting device-local wall-clock fields. Calls without the
/// file timezone retain the historical wall-clock behavior for
/// compatibility with stored/replayed data.
DateTime xiaomiActivityTimestamp(int seconds, {int? timezoneOffset15Min}) {
  final encoded = DateTime.fromMillisecondsSinceEpoch(
    seconds * 1000,
    isUtc: true,
  );
  // The device writes the record timestamp in UTC. The matching timezone field
  // is the offset in 15-minute blocks, so the device's local wall-clock value
  // is `encoded + offset` (Mi Fitness `FitnessDateUtils.changeTo0TimeIn0TzOneDay`
  // and Gadgetbridge both treat the raw seconds as an instant, not as a
  // pre-localized wall clock). Building the result from the shifted UTC fields
  // yields a local DateTime that already carries the device wall clock, so a
  // phone in the same timezone as the device shows exactly what the watch does.
  final shifted = timezoneOffset15Min == null
      ? encoded
      : encoded.add(Duration(minutes: timezoneOffset15Min * 15));
  return DateTime(
    shifted.year,
    shifted.month,
    shifted.day,
    shifted.hour,
    shifted.minute,
    shifted.second,
    shifted.millisecond,
    shifted.microsecond,
  );
}

int crc32(Uint8List data) {
  var crc = 0xffffffff;
  for (final byte in data) {
    crc ^= byte;
    for (var bit = 0; bit < 8; bit++) {
      crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xedb88320 : crc >> 1;
    }
  }
  return (crc ^ 0xffffffff) & 0xffffffff;
}

Uint8List normalizeXiaomiActivityFile(Uint8List data) {
  // The shortest valid transfer is a seven-byte FitnessDataId followed by
  // its four-byte CRC. It intentionally contains no parseable data body.
  if (data.length < 11) {
    throw ProtocolException('Xiaomi activity file is too short');
  }
  final view = ByteData.sublistView(data);
  final expected = view.getUint32(data.length - 4, Endian.little);
  final actual = crc32(Uint8List.sublistView(data, 0, data.length - 4));
  if (expected == actual) return data;
  throw ProtocolException(
    'Xiaomi activity CRC mismatch: ${actual.toRadixString(16)} != '
    '${expected.toRadixString(16)}',
  );
}

XiaomiParsedActivityFile parseXiaomiActivityFile(Uint8List data) {
  if (data.length < 11) {
    throw ProtocolException('Xiaomi activity file is too short to parse');
  }
  final view = ByteData.sublistView(data);
  final timestamp = view.getUint32(0, Endian.little);
  final timezoneOffset15Min = data[4].toSigned(8);
  final version = data[5];
  final flags = data[6];
  final type = (flags >> 7) & 1;
  final subtype = (flags & 0x7f) >> 2;
  final detail = flags & 3;

  final dailyParser = XiaomiDailyParser(
    timezoneOffset15Min: timezoneOffset15Min,
  );
  final sleepParser = XiaomiSleepParser(
    timezoneOffset15Min: timezoneOffset15Min,
  );
  final workoutParser = XiaomiWorkoutParser(
    timezoneOffset15Min: timezoneOffset15Min,
  );

  if (type == 0 && subtype == 0 && detail == 1) {
    return XiaomiParsedActivityFile(
      daily: dailyParser.parseDaily(data, timestamp, version),
    );
  }
  if (type == 0 && subtype == 0 && detail == 0) {
    return XiaomiParsedActivityFile(
      samples: dailyParser.parseDailyDetails(data, timestamp, version),
    );
  }
  // Mi Fitness routes dailyType=6 to ManualMeasureParser.  These files are
  // the source of the manually measured heart-rate, SpO2 and stress points;
  // they are separate from the minute-level daily detail file above.
  if (type == 0 && subtype == 6) {
    return XiaomiParsedActivityFile(
      samples: dailyParser.parseManualMeasures(data, timestamp, version),
    );
  }
  if (type == 0 && (subtype == 3 || subtype == 8)) {
    final sleep = sleepParser
        .parseSleep(data, timestamp, version, subtype)
        .map((record) => record.copyWith(sourceSubtype: subtype))
        .toList(growable: false);
    return XiaomiParsedActivityFile(sleep: sleep);
  }
  if (type == 0 && subtype == 9) {
    return XiaomiParsedActivityFile(
      abnormalHealthRecords: dailyParser.parseAbnormalHealth(data, version),
    );
  }
  if (type == 1 && detail == 1) {
    final workout = workoutParser.parseWorkoutSummary(
      data,
      timestamp,
      subtype,
      version,
    );
    return XiaomiParsedActivityFile(
      workouts: workout == null ? const [] : [workout],
    );
  }
  if (type == 1 && detail == 0) {
    final workout = workoutParser.parseWorkoutSamples(
      data,
      timestamp,
      subtype,
      version,
    );
    return XiaomiParsedActivityFile(
      workouts: workout == null ? const [] : [workout],
    );
  }
  if (type == 1 && detail == 2) {
    final workout = workoutParser.parseWorkoutRoute(
      data,
      timestamp,
      subtype,
      version,
    );
    return XiaomiParsedActivityFile(
      workouts: workout == null ? const [] : [workout],
    );
  }
  if (type == 1 && detail == 3) {
    final workout = workoutParser.parseWorkoutRecovery(
      data,
      timestamp,
      subtype,
      version,
    );
    return XiaomiParsedActivityFile(
      workouts: workout == null ? const [] : [workout],
    );
  }
  _log.fine(
    'unsupported Xiaomi activity file '
    'type=$type subtype=$subtype detail=$detail version=$version',
  );
  return const XiaomiParsedActivityFile();
}
