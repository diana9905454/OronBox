import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/features/devices/health/health_fit_exporter.dart';
import 'package:oronbox/src/features/devices/health/health_models.dart';

void main() {
  test('writes a valid FIT activity with session, lap and records', () {
    final start = DateTime.utc(2026, 9, 26, 8);
    final workout = HealthWorkoutSummary(
      startedAt: start,
      endedAt: start.add(const Duration(minutes: 30)),
      activityType: 1,
      distanceMeters: 5_000,
      calories: 420,
      averageHeartRate: 132,
      maximumHeartRate: 164,
      averageSpeedKph: 10,
      bestSpeedKph: 14,
      averageCadence: 172,
      heartRateZones: const [
        HealthWorkoutHeartRateZone(zone: 1, durationSeconds: 30),
        HealthWorkoutHeartRateZone(zone: 3, durationSeconds: 90),
      ],
      samples: [
        HealthWorkoutSample(
          timestamp: start.add(const Duration(seconds: 1)),
          heartRate: 128,
          distanceMeters: 4,
          speedKph: 9.5,
          cadence: 168,
        ),
        HealthWorkoutSample(
          timestamp: start.add(const Duration(seconds: 2)),
          heartRate: 130,
          distanceMeters: 8,
          speedKph: 10,
          cadence: 170,
        ),
      ],
      route: [
        HealthWorkoutRoutePoint(
          timestamp: start.add(const Duration(seconds: 1)),
          latitude: 31.2304,
          longitude: 121.4737,
          altitudeMeters: 8,
        ),
        HealthWorkoutRoutePoint(
          timestamp: start.add(const Duration(seconds: 2)),
          latitude: 31.2305,
          longitude: 121.4738,
          altitudeMeters: 9,
        ),
      ],
    );

    final bytes = HealthWorkoutFitExporter.encode(workout);
    final dataSize = _u32(bytes, 4);
    expect(bytes.sublist(8, 12), [0x2e, 0x46, 0x49, 0x54]);
    expect(bytes[0], 14);
    expect(bytes.length, 14 + dataSize + 2);
    expect(_u16(bytes, 12), _crc(bytes.sublist(0, 12)));
    expect(_u16(bytes, 14 + dataSize), _crc(bytes.sublist(0, 14 + dataSize)));

    final messages = _readMessages(bytes, dataSize);
    expect(messages.map((message) => message.globalType), [
      0,
      23,
      49,
      162,
      21,
      20,
      20,
      19,
      18,
      21,
      34,
    ]);
    expect(messages.where((message) => message.globalType == 20), hasLength(2));
    expect(messages.where((message) => message.globalType == 23), hasLength(1));
    expect(messages.where((message) => message.globalType == 18), hasLength(1));
    expect(messages.where((message) => message.globalType == 19), hasLength(1));
    final fileCreator = messages.firstWhere(
      (message) => message.globalType == 49,
    );
    expect(_stringFieldValue(fileCreator, 2), 'OronBox');
    final record = messages.firstWhere((message) => message.globalType == 20);
    final session = messages.firstWhere((message) => message.globalType == 18);
    final activity = messages.firstWhere((message) => message.globalType == 34);
    expect(record.fields.any((field) => field.$1 == 18), isFalse);
    expect(session.fields.any((field) => field.$1 == 151), isFalse);
    expect(_fieldSize(session, 7), 4);
    expect(_fieldSize(session, 65), 20);
    expect(_fieldSize(activity, 0), 4);
  });

  test('writes a summary-only FIT activity when samples are unavailable', () {
    final start = DateTime.utc(2026, 9, 26, 8);
    final bytes = HealthWorkoutFitExporter.encode(
      HealthWorkoutSummary(
        startedAt: start,
        endedAt: start.add(const Duration(minutes: 20)),
        activityType: 2,
        distanceMeters: 1_200,
      ),
    );
    final dataSize = _u32(bytes, 4);
    final messages = _readMessages(bytes, dataSize);
    expect(messages.where((message) => message.globalType == 20), isEmpty);
    expect(messages.where((message) => message.globalType == 18), hasLength(1));
    expect(_u16(bytes, 14 + dataSize), _crc(bytes.sublist(0, 14 + dataSize)));
  });

  test('does not emit empty records for unsupported sample values', () {
    final start = DateTime.utc(2026, 9, 26, 8);
    final bytes = HealthWorkoutFitExporter.encode(
      HealthWorkoutSummary(
        startedAt: start,
        endedAt: start.add(const Duration(minutes: 1)),
        activityType: 9,
        samples: [
          HealthWorkoutSample(
            timestamp: start.add(const Duration(seconds: 1)),
            swimmingStroke: 99,
          ),
        ],
      ),
    );
    final messages = _readMessages(bytes, _u32(bytes, 4));
    expect(messages.where((message) => message.globalType == 20), isEmpty);
  });

  test('maps Xiaomi activity types to their FIT sport enums', () {
    final start = DateTime.utc(2026, 9, 26, 8);
    final cases = <({int activityType, int? subSportType, int sport})>[
      (activityType: 2, subSportType: null, sport: 11), // walking
      (activityType: 4, subSportType: null, sport: 16), // mountaineering
      (activityType: 8, subSportType: null, sport: 10), // training
      (activityType: 14, subSportType: null, sport: 84), // jump rope
      (activityType: 22, subSportType: 2, sport: 11), // outdoor walking
      (activityType: 22, subSportType: 4, sport: 16), // mountaineering
      (activityType: 22, subSportType: 15, sport: 17), // hiking
    ];

    for (final value in cases) {
      final bytes = HealthWorkoutFitExporter.encode(
        HealthWorkoutSummary(
          startedAt: start,
          endedAt: start.add(const Duration(minutes: 1)),
          activityType: value.activityType,
          subSportType: value.subSportType,
        ),
      );
      final messages = _readMessages(bytes, _u32(bytes, 4));
      final session = messages.firstWhere(
        (message) => message.globalType == 18,
      );
      expect(_fieldValue(session, 5), value.sport);
    }
  });
}

class _Message {
  const _Message(this.globalType, this.fields, [this.data = const []]);

  final int globalType;
  final List<(int number, int size, int type)> fields;
  final List<int> data;
}

List<_Message> _readMessages(List<int> bytes, int dataSize) {
  final definitions = <int, _Message>{};
  final messages = <_Message>[];
  var offset = 14;
  final end = 14 + dataSize;
  while (offset < end) {
    final header = bytes[offset++];
    final local = header & 0x0f;
    if (header & 0x40 != 0) {
      offset += 2;
      final global = _u16(bytes, offset);
      offset += 2;
      final count = bytes[offset++];
      final fields = <(int, int, int)>[];
      for (var index = 0; index < count; index++) {
        fields.add((bytes[offset++], bytes[offset++], bytes[offset++]));
      }
      definitions[local] = _Message(global, fields);
      continue;
    }
    final definition = definitions[local];
    expect(definition, isNotNull);
    final dataStart = offset;
    offset += definition!.fields.fold<int>(0, (sum, field) => sum + field.$2);
    messages.add(
      _Message(
        definition.globalType,
        definition.fields,
        bytes.sublist(dataStart, offset),
      ),
    );
  }
  return messages;
}

int _u16(List<int> bytes, int offset) =>
    bytes[offset] | (bytes[offset + 1] << 8);

int _u32(List<int> bytes, int offset) =>
    bytes[offset] |
    (bytes[offset + 1] << 8) |
    (bytes[offset + 2] << 16) |
    (bytes[offset + 3] << 24);

int _fieldSize(_Message message, int number) =>
    message.fields.firstWhere((field) => field.$1 == number).$2;

int _fieldValue(_Message message, int number) {
  var offset = 0;
  for (final field in message.fields) {
    if (field.$1 == number) return _u32Sized(message.data, offset, field.$2);
    offset += field.$2;
  }
  throw StateError('field $number not found');
}

String _stringFieldValue(_Message message, int number) {
  var offset = 0;
  for (final field in message.fields) {
    if (field.$1 == number) {
      final end = offset + field.$2;
      return utf8
          .decode(message.data.sublist(offset, end))
          .replaceAll('\u0000', '');
    }
    offset += field.$2;
  }
  throw StateError('field $number not found');
}

int _u32Sized(List<int> bytes, int offset, int size) {
  var value = 0;
  for (var index = 0; index < size; index++) {
    value |= bytes[offset + index] << (8 * index);
  }
  return value;
}

int _crc(List<int> bytes) {
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
  for (final byte in bytes) {
    crc = (((crc >> 4) & 0xfff) ^ constants[crc & 0xf]) ^ constants[byte & 0xf];
    crc =
        (((crc >> 4) & 0xfff) ^ constants[crc & 0xf]) ^
        constants[(byte >> 4) & 0xf];
  }
  return crc & 0xffff;
}
