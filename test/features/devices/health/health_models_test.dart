import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/device/xiaomi/systems/health_system.dart';
import 'package:oronbox/src/features/devices/health/health_models.dart';
import 'package:oronbox/src/features/devices/health/health_store.dart';
import 'package:oronbox/src/features/devices/health/xiaomi_health_sync_service.dart';

void main() {
  test('Xiaomi activity timestamps stay in local wall-clock semantics', () {
    const encodedSeconds = 1_787_472_000;
    final timestamp = xiaomiActivityTimestamp(encodedSeconds);
    final encodedWallClock = DateTime.fromMillisecondsSinceEpoch(
      encodedSeconds * 1000,
      isUtc: true,
    );

    expect(timestamp.isUtc, isFalse);
    expect(
      timestamp,
      DateTime(
        encodedWallClock.year,
        encodedWallClock.month,
        encodedWallClock.day,
        encodedWallClock.hour,
        encodedWallClock.minute,
        encodedWallClock.second,
      ),
    );
  });

  test('parses Xiaomi Fitness manual heart, SpO2 and stress measurements', () {
    const fileTimestamp = 1_787_472_000;
    const sampleTimestamp = fileTimestamp + 60;
    final body = BytesBuilder()
      ..add(_u32(sampleTimestamp))
      ..add(const [0x11, 78])
      ..add(_u32(sampleTimestamp))
      ..add(const [0x12, 97])
      ..add(_u32(sampleTimestamp))
      ..add(const [0x13, 24]);
    const deviceTimezoneOffset15Min = 32; // UTC+8.
    final prefix = <int>[
      ..._u32(fileTimestamp),
      deviceTimezoneOffset15Min,
      2,
      6 << 2,
      0,
    ];
    prefix.addAll(body.toBytes());
    final file = _activityFile(prefix);

    final result = XiaomiHealthSystem().parseActivityFilesForDebug([
      XiaomiActivityRawFile(id: 'manual', data: file),
    ]);

    expect(result.samples, hasLength(1));
    expect(
      result.samples.single.timestamp,
      xiaomiActivityTimestamp(
        sampleTimestamp,
        timezoneOffset15Min: deviceTimezoneOffset15Min,
      ),
    );
    expect(result.samples.single.heartRate, 78);
    expect(result.samples.single.bloodOxygen, 97);
    expect(result.samples.single.stress, 24);
  });

  test('parses Xiaomi Fitness daily report fields by version and validity', () {
    const timestamp = 1_787_472_000;
    const fieldSizes = [
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
    final payload = BytesBuilder();
    for (var field = 0; field < fieldSizes.length; field++) {
      final size = fieldSizes[field];
      final value = switch (field) {
        0 => 321,
        1 => 222,
        2 => 81,
        3 => 56,
        4 => 170,
        5 => timestamp + 100,
        6 => 48,
        7 => timestamp + 200,
        8 => 74,
        13 => 555,
        15 => 97,
        16 => 99,
        17 => timestamp + 300,
        18 => 92,
        19 => timestamp + 400,
        20 => 96,
        21 => 33,
        22 => 155,
        23 => 2,
        24 => 3,
        25 => 4,
        26 => 5,
        27 => 42,
        28 => 1,
        29 => 18,
        30 => -8,
        31 => 66,
        32 => 72,
        33 => 51,
        34 => 7,
        _ => 0,
      };
      if (size == 1) {
        payload.addByte(value);
      } else if (size == 2) {
        final bytes = ByteData(2);
        if (field == 30) {
          bytes.setInt16(0, value, Endian.little);
        } else {
          bytes.setUint16(0, value, Endian.little);
        }
        payload.add(bytes.buffer.asUint8List());
      } else if (size == 3) {
        payload.add(<int>[value, value >> 8, value >> 16]);
      } else {
        final bytes = ByteData(4)..setUint32(0, value, Endian.little);
        payload.add(bytes.buffer.asUint8List());
      }
    }
    final validity = Uint8List(5);
    for (final bit in [
      0,
      1,
      2,
      3,
      4,
      5,
      6,
      7,
      8,
      13,
      15,
      16,
      17,
      18,
      19,
      20,
      21,
      22,
      23,
      24,
      25,
      26,
      27,
      28,
      29,
      30,
      31,
      32,
      33,
      34,
    ]) {
      _setValidityBit(validity, bit);
    }
    final prefix = <int>[
      ..._u32(timestamp),
      0,
      7,
      1,
      0,
      ...validity,
      ...payload.toBytes(),
    ];
    final file = _activityFile(prefix);

    final result = XiaomiHealthSystem().parseActivityFilesForDebug([
      XiaomiActivityRawFile(id: 'daily-report', data: file),
    ]);

    expect(result.daily, hasLength(1));
    expect(result.daily.single.steps, 321);
    expect(result.daily.single.activeCalories, 222);
    expect(result.daily.single.calories, 555);
    expect(result.daily.single.floorsClimbed, 7);
    expect(result.daily.single.restingHeartRate, 56);
    expect(result.daily.single.maxHeartRate, 170);
    expect(
      result.daily.single.maxHeartRateAt,
      xiaomiActivityTimestamp(timestamp + 100),
    );
    expect(result.daily.single.minHeartRate, 48);
    expect(result.daily.single.averageHeartRate, 74);
    expect(result.daily.single.currentBloodOxygen, 97);
    expect(result.daily.single.minBloodOxygen, 92);
    expect(result.daily.single.averageBloodOxygen, 96);
    expect(result.daily.single.trainingLoadToday, 33);
    expect(result.daily.single.trainingLoadLast7Days, 155);
    expect(result.daily.single.vitalityIncreaseLight, 3);
    expect(result.daily.single.vitalityIncreaseModerate, 4);
    expect(result.daily.single.vitalityIncreaseHigh, 5);
    // The day's earned value is the sum of the intensity buckets; the device's
    // field 27 is only the running 7-day total (vitalityLast7Days).
    expect(result.daily.single.vitalityCurrent, 12);
    expect(result.daily.single.vitalityLast7Days, 42);
    expect(result.daily.single.vitalityNextTargetMinutes, 18);
    expect(result.daily.single.fitnessBalance, -8);
    expect(result.daily.single.fitnessLevel, 66);
    expect(result.daily.single.fatigueLevel, 72);
    expect(result.daily.single.trainingStressScore, 51);
  });

  test('parses Xiaomi Fitness packed daily records', () {
    const timestamp = 1_787_472_000;
    final prefix = <int>[
      ..._u32(timestamp),
      0,
      3,
      0,
      0,
      0xa9,
      0x0c,
      0xcc,
      0x8c,
      0xc0,
    ];
    final body = BytesBuilder()
      ..add(_u16(1234))
      ..addByte(42)
      ..add(_u16(1000))
      ..addByte(80)
      ..addByte(10)
      ..add(_u16(0))
      ..addByte(97)
      ..addByte(24);
    prefix.addAll(body.toBytes());
    final file = _activityFile(prefix);

    final result = XiaomiHealthSystem().parseActivityFilesForDebug([
      XiaomiActivityRawFile(id: 'daily-record', data: file),
    ]);

    expect(result.samples, hasLength(1));
    expect(result.samples.single.steps, 1234);
    expect(result.samples.single.activeCalories, 42);
    expect(result.samples.single.distanceMeters, 1000);
    expect(result.samples.single.heartRate, 80);
    expect(result.samples.single.bloodOxygen, 97);
    expect(result.samples.single.pressure, 24);
  });

  test('parses Mi Fitness outdoor workout report summary fields', () {
    const startedSeconds = 1_787_472_000;
    const endedSeconds = startedSeconds + 45 * 60;
    final body = BytesBuilder()
      ..add(_u32(startedSeconds)) // start time
      ..add(_u32(endedSeconds)) // end time
      ..add(_u32(0)) // type 3
      ..add(_u32(3500)) // distance
      ..add(_u16(420)) // calories
      ..add(_u32(0)) // type 8
      ..add(_u32(0)) // type 9
      ..add(_u32(0)) // type 12
      ..add(_u32(0)) // type 13
      ..add(_u16(0)) // type 14
      ..addByte(143) // average heart rate
      ..addByte(168) // maximum heart rate
      ..addByte(61); // minimum heart rate
    final prefix = <int>[
      ..._u32(startedSeconds),
      0,
      1,
      0x85, // sport report, outdoor subtype 1
      0, // reserved header byte
      0xff,
      0xf8,
      0,
      0,
      ...body.toBytes(),
    ];
    final file = _activityFile(prefix);

    final result = XiaomiHealthSystem().parseActivityFilesForDebug([
      XiaomiActivityRawFile(id: 'outdoor-workout', data: file),
    ]);

    expect(result.workouts, hasLength(1));
    final workout = result.workouts.single;
    expect(workout.activityType, 1);
    expect(workout.startedAt, xiaomiActivityTimestamp(startedSeconds));
    expect(workout.endedAt, xiaomiActivityTimestamp(endedSeconds));
    expect(workout.distanceMeters, 3500);
    expect(workout.calories, 420);
    expect(workout.averageHeartRate, 143);
    expect(workout.maximumHeartRate, 168);
    expect(workout.minimumHeartRate, 61);
  });

  test('parses and merges modern workout report, samples, GPS and HRR', () {
    const startedSeconds = 1_787_472_000;
    const endedSeconds = startedSeconds + 1800;

    final reportValidity = Uint8List(13);
    for (final bit in [
      0,
      1,
      2,
      3,
      4,
      5,
      6,
      7,
      8,
      11,
      13,
      14,
      15,
      16,
      17,
      18,
      19,
      25,
      34,
      35,
      36,
      40,
      41,
      45,
      61,
      70,
    ]) {
      _setValidityBit(reportValidity, bit);
    }
    final reportBody = ByteData(197)
      ..setUint16(0, 1, Endian.little)
      ..setUint32(2, startedSeconds, Endian.little)
      ..setUint32(6, endedSeconds, Endian.little)
      ..setUint32(10, 1800, Endian.little)
      ..setUint32(14, 1720, Endian.little)
      ..setUint32(18, 5000, Endian.little)
      ..setUint16(22, 360, Endian.little)
      ..setUint16(24, 300, Endian.little)
      ..setUint32(26, 344, Endian.little)
      ..setFloat32(38, 10.4, Endian.little)
      ..setUint32(46, 6200, Endian.little)
      ..setUint16(50, 88, Endian.little)
      ..setUint16(52, 168, Endian.little)
      ..setUint16(54, 186, Endian.little)
      ..setUint8(56, 148)
      ..setUint8(57, 177)
      ..setUint8(58, 78)
      ..setFloat32(79, 3.2, Endian.little)
      ..setUint16(97, 18, Endian.little)
      ..setUint8(99, 1)
      ..setUint32(100, 240, Endian.little)
      ..setUint32(116, 300, Endian.little)
      ..setUint8(120, 170)
      ..setUint8(124, 100)
      ..setUint16(179, 72, Endian.little)
      ..setUint8(196, 8);
    final report = _activityFile([
      ..._u32(startedSeconds),
      0,
      9,
      0xd9,
      0,
      ...reportValidity,
      ...reportBody.buffer.asUint8List(),
    ]);

    final recordValidity = Uint8List(7);
    for (final bit in [0, 1, 2, 4, 5, 8, 9, 12, 14, 16, 17, 28, 29, 32, 33]) {
      _setValidityBit(recordValidity, bit);
    }
    final recordBody = BytesBuilder();
    final segment = ByteData(27)
      ..setFloat32(0, 120, Endian.little)
      ..setUint32(4, 2, Endian.little)
      ..setUint32(8, startedSeconds, Endian.little);
    recordBody.add(segment.buffer.asUint8List());
    recordBody
      ..addByte(0x23)
      ..addByte(140)
      ..add(_i32(1234))
      ..add(_u16(5))
      ..addByte(90)
      ..addByte(160)
      ..add(_u16(300))
      ..addByte(0x12)
      ..addByte(145)
      ..add(_i32(1240))
      ..add(_u16(10))
      ..addByte(92)
      ..addByte(165)
      ..add(_u16(290));
    final record = _activityFile([
      ..._u32(startedSeconds),
      0,
      9,
      0xd8,
      0,
      ...recordValidity,
      ...recordBody.toBytes(),
    ]);

    final gpsBody = BytesBuilder()..add(_u32(2));
    for (final (timestamp, longitude, latitude, altitude) in [
      (startedSeconds, 121.4737, 31.2304, 8.0),
      (startedSeconds + 60, 121.4740, 31.2310, 9.5),
    ]) {
      final point = ByteData(27)
        ..setUint32(0, timestamp, Endian.little)
        ..setFloat32(4, longitude, Endian.little)
        ..setFloat32(8, latitude, Endian.little)
        ..setFloat32(12, 3, Endian.little)
        ..setUint16(16, 80, Endian.little)
        ..setFloat32(18, altitude, Endian.little);
      gpsBody.add(point.buffer.asUint8List());
    }
    final gps = _activityFile([
      ..._u32(startedSeconds),
      0,
      5,
      0xda,
      0,
      0xff,
      0xff,
      ...gpsBody.toBytes(),
    ]);

    final recovery = _activityFile([
      ..._u32(startedSeconds),
      0,
      1,
      0xdb,
      0,
      ..._u32(endedSeconds),
      118,
      22,
      ..._u16(3),
      150,
      132,
      118,
    ]);

    final result = XiaomiHealthSystem().parseActivityFilesForDebug([
      XiaomiActivityRawFile(id: 'report', data: report),
      XiaomiActivityRawFile(id: 'record', data: record),
      XiaomiActivityRawFile(id: 'gps', data: gps),
      XiaomiActivityRawFile(id: 'hrr', data: recovery),
    ]);

    expect(result.failedFiles, isEmpty);
    expect(result.workouts, hasLength(1));
    final workout = result.workouts.single;
    expect(workout.distanceMeters, 5000);
    expect(workout.totalDurationSeconds, 1800);
    expect(workout.averageSpeedKph, closeTo(10.4, 0.001));
    expect(workout.aerobicTrainingEffect, closeTo(3.2, 0.001));
    expect(workout.trainingLoad, 72);
    expect(workout.earnedVitality, 8);
    expect(workout.heartRateZones, hasLength(2));
    expect(workout.samples, hasLength(2));
    expect(workout.samples.last.steps, 5);
    expect(workout.samples.last.distanceMeters, 15);
    expect(workout.samples.last.altitudeMeters, 124);
    expect(workout.route, hasLength(2));
    expect(workout.route.last.latitude, closeTo(31.231, 0.0001));
    expect(workout.recovery?.recoveredHeartRate, 118);
    expect(workout.recovery?.heartRates, [150, 132, 118]);
  });

  test('parses swimming sections and their heart-rate series', () {
    const startedSeconds = 1_787_472_000;
    const endedSeconds = startedSeconds + 60;
    final body = BytesBuilder()
      ..add(_u32(1))
      ..add(_u32(startedSeconds))
      ..addByte(0)
      ..add(_u32(endedSeconds))
      ..addByte(2)
      ..add(_u16(95))
      ..add(_u16(42))
      ..add(_u16(50))
      ..add(_u16(10))
      ..add(_u16(20))
      ..add(_u16(1))
      ..add(const [30, 0, 0, 30, 0, 0])
      ..add(_u16(12))
      ..add(const [0, 0, 0])
      ..add(_u16(0))
      ..add(_u32(3))
      ..add(const [100, 110, 105]);
    final file = _activityFile([
      ..._u32(startedSeconds),
      0,
      3,
      0xa4,
      0,
      0xff,
      0xff,
      0xf0,
      ...body.toBytes(),
    ]);

    final result = XiaomiHealthSystem().parseActivityFilesForDebug([
      XiaomiActivityRawFile(id: 'swimming-record', data: file),
    ]);

    expect(result.failedFiles, isEmpty);
    expect(result.workouts, hasLength(1));
    final samples = result.workouts.single.samples;
    expect(samples.where((sample) => sample.heartRate != null), hasLength(3));
    final section = samples.singleWhere((sample) => sample.swolf != null);
    expect(section.swimmingStroke, 2);
    expect(section.swimmingPaceSecondsPer100Meters, 95);
    expect(section.swolf, 42);
    expect(section.distanceMeters, 50);
    expect(section.strokeFrequency, 30);
  });

  test('parses Vela daily-type-9 high and low heart-rate records', () {
    const startedSeconds = 1_787_472_000;
    const endedSeconds = startedSeconds + 5 * 60;
    final body = BytesBuilder();

    void u8(int value) => body.addByte(value);
    void u16(int value) {
      final bytes = ByteData(2)..setUint16(0, value, Endian.little);
      body.add(bytes.buffer.asUint8List());
    }

    void u32(int value) => body.add(_u32(value));

    u32(startedSeconds);
    u32(endedSeconds);
    u8(1); // HR_HIGH
    u16(120); // configured threshold
    u16(2); // two samples in this segment
    u32(startedSeconds + 60);
    u8(125);
    u32(startedSeconds + 120);
    u8(121);

    u32(startedSeconds + 10 * 60);
    u32(startedSeconds + 15 * 60);
    u8(2); // HR_LOW
    u16(45);
    u16(1);
    u32(startedSeconds + 11 * 60);
    u8(42);

    u32(startedSeconds + 20 * 60);
    u32(startedSeconds + 25 * 60);
    u8(3); // SPO2_LOW
    u16(90);
    u16(1);
    u32(startedSeconds + 21 * 60);
    u8(88);

    u32(startedSeconds + 30 * 60);
    u32(startedSeconds + 35 * 60);
    u8(4); // STRESS_HIGH
    u16(80);
    u16(1);
    u32(startedSeconds + 31 * 60);
    u8(82);

    u32(startedSeconds + 40 * 60);
    u32(startedSeconds + 45 * 60);
    u8(5); // ABNORMAL_FIB / heart-health irregular heartbeat
    u16(0);
    u16(1);
    u32(startedSeconds + 41 * 60);
    u8(0);

    // dailyType=9, v1: the native parser has a zero-byte validity header, so
    // the first abnormal record starts immediately after the 7-byte ID.
    final prefix = <int>[
      ..._u32(startedSeconds),
      0,
      1,
      9 << 2,
      ...body.toBytes(),
    ];
    final file = _activityFile(prefix);
    final records = XiaomiHealthSystem()
        .parseActivityAbnormalHeartRateFileForTesting(file);

    expect(records, hasLength(3));
    expect(records[0].kind, XiaomiActivityAbnormalHeartRateKind.high);
    expect(records[0].threshold, 120);
    expect(records[0].value, 125);
    expect(records[0].timestamp, xiaomiActivityTimestamp(startedSeconds + 60));
    expect(records[0].startedAt, xiaomiActivityTimestamp(startedSeconds));
    expect(records[2].kind, XiaomiActivityAbnormalHeartRateKind.low);
    expect(records[2].threshold, 45);
    expect(records[2].value, 42);

    final abnormalHealthRecords = XiaomiHealthSystem()
        .parseActivityAbnormalHealthFileForTesting(file);
    expect(abnormalHealthRecords, hasLength(6));
    expect(
      abnormalHealthRecords[3].kind,
      XiaomiActivityAbnormalHealthKind.lowBloodOxygen,
    );
    expect(abnormalHealthRecords[3].value, 88);
    expect(abnormalHealthRecords[3].threshold, 90);
    expect(
      abnormalHealthRecords[4].kind,
      XiaomiActivityAbnormalHealthKind.highStress,
    );
    expect(abnormalHealthRecords[4].value, 82);
    expect(
      abnormalHealthRecords[5].kind,
      XiaomiActivityAbnormalHealthKind.irregularHeartbeat,
    );
    expect(abnormalHealthRecords[5].value, isNull);
    expect(
      abnormalHealthRecords[5].startedAt,
      xiaomiActivityTimestamp(startedSeconds + 40 * 60),
    );
    expect(
      abnormalHealthRecords[5].endedAt,
      xiaomiActivityTimestamp(startedSeconds + 45 * 60),
    );
  });

  test('parses Vela v2 daily-type-9 abnormal heart-rate records with 1-byte threshold', () {
    const startedSeconds = 1_790_933_297;
    const endedSeconds = 1_790_933_897;
    final body = BytesBuilder()
      ..add(_u32(startedSeconds))
      ..add(_u32(endedSeconds))
      ..addByte(1) // HR_HIGH
      ..addByte(100) // 1-byte threshold
      ..add(_u16(2)) // count: 2
      ..add(_u32(startedSeconds + 16))
      ..addByte(107)
      ..add(_u32(startedSeconds + 17))
      ..addByte(109);

    final prefix = <int>[
      ..._u32(startedSeconds),
      32,
      2, // version 2
      9 << 2,
      0, // padding
      ...body.toBytes(),
    ];
    final file = _activityFile(prefix);
    final records = XiaomiHealthSystem()
        .parseActivityAbnormalHeartRateFileForTesting(file);

    expect(records, hasLength(2));
    expect(records[0].kind, XiaomiActivityAbnormalHeartRateKind.high);
    expect(records[0].threshold, 100);
    expect(records[0].value, 107);
    expect(records[1].value, 109);
  });

  test('parses the Mi Fitness v5 sleep record and stage packets', () {
    const startedSeconds = 1_787_472_000;
    const endedSeconds = startedSeconds + 7 * 60 * 60;
    final body = BytesBuilder();

    void u8(int value) => body.addByte(value);
    void u16(int value) {
      final bytes = ByteData(2)..setUint16(0, value, Endian.little);
      body.add(bytes.buffer.asUint8List());
    }

    void u32(int value) {
      final bytes = ByteData(4)..setUint32(0, value, Endian.little);
      body.add(bytes.buffer.asUint8List());
    }

    u8(1); // sleepFull
    u32(startedSeconds);
    u32(endedSeconds);
    u8(82); // sleep quality
    u8(91); // sleep efficiency
    u32(7 * 60 * 60); // asleep duration
    u32(8 * 60 * 60); // in-bed duration
    u32(startedSeconds - 15 * 60);
    u32(endedSeconds + 15 * 60);

    u16(60); // heart-rate interval, seconds
    u16(452);
    u32(startedSeconds);
    u8(60);
    for (var index = 0; index < 450; index++) {
      u8(0); // no sample during the gap between sleep segments
    }
    u8(70); // a sample in the second sleep segment
    u16(60); // blood-oxygen interval, seconds
    u16(452);
    u32(startedSeconds);
    u8(96);
    for (var index = 0; index < 450; index++) {
      u8(0); // no sample during the gap between sleep segments
    }
    u8(98); // a sample in the second sleep segment

    u16(300); // snore interval, seconds
    u16(0); // no snore samples in this fixture

    void packetHeader({
      required int timestamp,
      required int type,
      required int dataLength,
    }) {
      body.add(const [0xfb, 0xfa, 0xfc, 0xff]);
      u8(17);
      final timestampBytes = ByteData(8)
        ..setUint64(0, timestamp, Endian.little);
      body.add(timestampBytes.buffer.asUint8List());
      u8(0); // parity
      u8(type);
      final lengthBytes = ByteData(2)..setUint16(0, dataLength, Endian.big);
      body.add(lengthBytes.buffer.asUint8List());
    }

    packetHeader(timestamp: startedSeconds, type: 16, dataLength: 13);
    u8(0x11); // sleep index and wake count
    void packetU16(int value) {
      final bytes = ByteData(2)..setUint16(0, value, Endian.big);
      body.add(bytes.buffer.asUint8List());
    }

    packetU16(420); // total sleep minutes
    packetU16(30); // awake minutes
    packetU16(120); // light minutes
    packetU16(90); // REM minutes
    packetU16(180); // deep minutes
    u8(0x14); // has REM and device stages
    u8(0); // reserved duration

    packetHeader(
      timestamp: startedSeconds + (420 + 30) * 60,
      type: 16,
      dataLength: 13,
    );
    u8(0x20); // a second, indexed sleep summary
    packetU16(30); // total sleep minutes
    packetU16(5); // awake minutes
    packetU16(20); // light minutes
    packetU16(0); // REM minutes
    packetU16(10); // deep minutes
    u8(0x04); // device stages, no REM
    u8(0); // reserved duration

    packetHeader(timestamp: startedSeconds, type: 17, dataLength: 4);
    packetU16(0x203c); // deep, next change in 60 minutes
    packetU16(0x303c); // light, next change in 60 minutes

    final prefix = <int>[
      ..._u32(startedSeconds),
      0, // reserved byte after the seven-byte file id
      5, // v5
      8 << 2, // all-day sleep report
      0, // no encryption/compression
      0xff,
      0xe0, // v5 validity: fixed fields, HR, SpO2 and snore
      ...body.toBytes(),
    ];
    final file = _activityFile(prefix);
    final system = XiaomiHealthSystem();
    final records = system.parseActivitySleepFilesForTesting(file);
    final parsed = system.parseActivitySleepFileForTesting(file);

    expect(parsed, isNotNull);
    expect(records, hasLength(2));
    expect(records.first.sleepIndex, 1);
    expect(records.last.sleepIndex, 2);
    expect(parsed!.durationSeconds, 7 * 60 * 60);
    expect(parsed.startedAt, xiaomiActivityTimestamp(startedSeconds));
    // The device type-16 summary includes the 30-minute awake interval in
    // the report end, while durationSeconds remains sleep duration.
    expect(
      parsed.endedAt,
      xiaomiActivityTimestamp(startedSeconds + (420 + 30) * 60),
    );
    expect(parsed.sleepEfficiency, 91);
    expect(parsed.bedDurationSeconds, 8 * 60 * 60);
    expect(parsed.averageHeartRate, 60);
    expect(parsed.averageBloodOxygen, 96);
    expect(parsed.heartRatePoints, hasLength(1));
    expect(parsed.heartRatePoints.first.value, 60);
    expect(
      parsed.heartRatePoints.first.timestamp,
      xiaomiActivityTimestamp(startedSeconds),
    );
    expect(parsed.bloodOxygenPoints, hasLength(1));
    expect(parsed.bloodOxygenPoints.first.value, 96);
    expect(records.last.averageHeartRate, 70);
    expect(records.last.averageBloodOxygen, 98);
    expect(records.last.heartRatePoints.single.value, 70);
    expect(records.last.bloodOxygenPoints.single.value, 98);
    expect(parsed.minimumHeartRate, 60);
    expect(parsed.maximumHeartRate, 60);
    expect(parsed.minimumBloodOxygen, 96);
    expect(parsed.maximumBloodOxygen, 96);
    expect(parsed.averageHrv, isNull);
    expect(parsed.hrvPoints, isEmpty);
    expect(parsed.durationSeconds, 420 * 60);
    expect(parsed.awakeDurationSeconds, 30 * 60);
    expect(parsed.lightSleepDurationSeconds, 120 * 60);
    expect(parsed.deepSleepDurationSeconds, 180 * 60);
    expect(parsed.remSleepDurationSeconds, 90 * 60);
    expect(parsed.sleepIndex, 1);
    expect(parsed.wakeCount, 1);
    expect(parsed.hasRem, true);
    expect(parsed.hasStage, true);
    expect(parsed.stages, hasLength(2));
    expect(parsed.stages.first.stage, 2);
    expect(parsed.stages.last.stage, 4);
    expect(
      parsed.stages.first.endedAt,
      xiaomiActivityTimestamp(startedSeconds + 60 * 60),
    );
    expect(
      parsed.stages.last.timestamp,
      xiaomiActivityTimestamp(startedSeconds + 60 * 60),
    );
    expect(
      parsed.stages.last.endedAt,
      xiaomiActivityTimestamp(startedSeconds + 120 * 60),
    );
  });

  test('parses the Mi Fitness v6 HRV summary and sample series', () {
    const startedSeconds = 1_787_472_000;
    final body = BytesBuilder();

    void u8(int value) => body.addByte(value);

    void u16(int value) {
      final bytes = ByteData(2)..setUint16(0, value, Endian.little);
      body.add(bytes.buffer.asUint8List());
    }

    void u16be(int value) {
      final bytes = ByteData(2)..setUint16(0, value, Endian.big);
      body.add(bytes.buffer.asUint8List());
    }

    void u32(int value) {
      final bytes = ByteData(4)..setUint32(0, value, Endian.little);
      body.add(bytes.buffer.asUint8List());
    }

    void packetHeader({
      required int timestamp,
      required int type,
      required int dataLength,
    }) {
      body.add(const [0xfb, 0xfa, 0xfc, 0xff]);
      u8(17);
      final timestampBytes = ByteData(8)
        ..setUint64(0, timestamp, Endian.little);
      body.add(timestampBytes.buffer.asUint8List());
      u8(0);
      u8(type);
      final lengthBytes = ByteData(2)..setUint16(0, dataLength, Endian.big);
      body.add(lengthBytes.buffer.asUint8List());
    }

    u8(1); // sleepFull
    u32(startedSeconds);
    u32(startedSeconds + 7 * 60 * 60);
    u8(82); // sleep quality
    u8(91); // sleep efficiency
    u32(7 * 60 * 60); // asleep duration
    u32(8 * 60 * 60); // in-bed duration
    u32(startedSeconds - 15 * 60);
    u32(startedSeconds + 7 * 60 * 60 + 15 * 60);

    // v6 HRV summary fields from full_day_sleep_report_v6.json.
    u16(42); // average
    u16(8); // standard deviation
    u16(40); // median
    u16(24); // lower percentile
    u16(62); // upper percentile
    u16(39); // middle percentile
    u32(startedSeconds + 60 * 60); // HRV summary timestamp
    u16(70); // max
    u16(18); // min
    u16(55); // baseline max
    u16(25); // baseline min

    u16(60); // heart-rate interval
    u16(2);
    u32(startedSeconds);
    u8(60);
    u8(70);
    u16(60); // blood-oxygen interval
    u16(2);
    u32(startedSeconds);
    u8(96);
    u8(97);
    u16(300); // HRV interval
    u16(3);
    u32(startedSeconds + 5 * 60);
    u16(40);
    u16(44);
    u16(48);
    u16(300); // snore interval
    u16(0);

    // Two summaries in one type-16 payload exercise the native gap walk.
    packetHeader(timestamp: startedSeconds, type: 16, dataLength: 26);
    u8(0x11); // sleep index 1, one wake
    u16be(420); // sleep minutes
    u16be(30); // awake minutes
    u16be(120); // light minutes
    u16be(90); // REM minutes
    u16be(180); // deep minutes
    u8(0x14); // has REM and device stages
    u8(5); // gap before the next summary
    u8(0x20); // sleep index 2, no wakes
    u16be(30);
    u16be(5);
    u16be(20);
    u16be(0);
    u16be(10);
    u8(0x00); // no stages and no REM
    u8(0);

    final prefix = <int>[
      ..._u32(startedSeconds),
      0,
      6, // v6
      8 << 2, // all-day sleep report
      0,
      0xff,
      0xff,
      0xfe, // all v6 fields except the reserved validity bit
      ...body.toBytes(),
    ];
    final file = _activityFile(prefix);
    final system = XiaomiHealthSystem();
    final records = system.parseActivitySleepFilesForTesting(file);
    final parsed = system.parseActivitySleepFileForTesting(file);

    expect(records, hasLength(2));
    expect(parsed, isNotNull);
    expect(parsed!.averageHrv, 42);
    expect(parsed.hrvStandardDeviation, 8);
    expect(parsed.hrvMedian, 40);
    expect(parsed.hrvLowerQuantile, 24);
    expect(parsed.hrvMiddleQuantile, 39);
    expect(parsed.hrvUpperQuantile, 62);
    expect(
      parsed.hrvTimestamp,
      xiaomiActivityTimestamp(startedSeconds + 60 * 60),
    );
    expect(parsed.hrvMax, 70);
    expect(parsed.hrvMin, 18);
    expect(parsed.hrvBaselineMax, 55);
    expect(parsed.hrvBaselineMin, 25);
    expect(parsed.hrvPoints, hasLength(3));
    expect(parsed.hrvPoints.first.value, 40);
    expect(
      parsed.hrvPoints.first.timestamp,
      xiaomiActivityTimestamp(startedSeconds + 5 * 60),
    );
    expect(parsed.heartRatePoints, hasLength(2));
    expect(parsed.heartRatePoints.first.value, 60);
    expect(parsed.heartRatePoints.last.value, 70);
    expect(parsed.bloodOxygenPoints, hasLength(2));
    expect(parsed.bloodOxygenPoints.first.value, 96);
    expect(parsed.bloodOxygenPoints.last.value, 97);
    expect(records.last.hrvPoints, isEmpty);
    expect(records.last.heartRatePoints, isEmpty);
    expect(records.last.bloodOxygenPoints, isEmpty);
    expect(records.last.hasStage, isFalse);
    expect(records.last.averageHeartRate, isNull);
    expect(records.last.minimumHeartRate, isNull);
    expect(records.last.maximumHeartRate, isNull);
    expect(records.last.averageBloodOxygen, isNull);
    expect(records.last.minimumBloodOxygen, isNull);
    expect(records.last.maximumBloodOxygen, isNull);
    expect(parsed.averageHeartRate, 65);
    expect(parsed.averageBloodOxygen, 97);
    expect(parsed.sleepIndex, 1);
    expect(parsed.awakeDurationSeconds, 30 * 60);
  });

  test('uses the v6 validity positions for heart rate without HRV', () {
    const startedSeconds = 1_787_472_000;
    final body = BytesBuilder();

    void u8(int value) => body.addByte(value);

    void u16(int value) {
      final bytes = ByteData(2)..setUint16(0, value, Endian.little);
      body.add(bytes.buffer.asUint8List());
    }

    void u32(int value) {
      final bytes = ByteData(4)..setUint32(0, value, Endian.little);
      body.add(bytes.buffer.asUint8List());
    }

    u8(1);
    u32(startedSeconds);
    u32(startedSeconds + 7 * 60 * 60);
    u8(82);
    u8(91);
    u32(7 * 60 * 60);
    u32(8 * 60 * 60);
    u32(startedSeconds - 15 * 60);
    u32(startedSeconds + 7 * 60 * 60 + 15 * 60);

    // The v6 fixed HRV summary block is present in the body even when all
    // eleven HRV summary validity bits are clear.
    for (var index = 0; index < 6; index++) {
      u16(0);
    }
    u32(0);
    for (var index = 0; index < 4; index++) {
      u16(0);
    }

    u16(60);
    u16(2);
    u32(startedSeconds);
    u8(60);
    u8(70);
    u16(60);
    u16(2);
    u32(startedSeconds);
    u8(96);
    u8(97);
    u16(300); // snore block is valid, but has no records
    u16(0);

    final prefix = <int>[
      ..._u32(startedSeconds),
      0,
      6,
      8 << 2,
      0,
      0xff, // fixed fields
      0,
      0x1a, // heart rate, blood oxygen, and snore only
      ...body.toBytes(),
    ];
    final file = _activityFile(prefix);
    final parsed = XiaomiHealthSystem().parseActivitySleepFileForTesting(file);

    expect(parsed, isNotNull);
    expect(parsed!.averageHeartRate, 65);
    expect(parsed.averageBloodOxygen, 97);
    expect(parsed.averageHrv, isNull);
    expect(parsed.hrvPoints, isEmpty);
  });

  test('parses the v2 device sleep-stage file and its stage totals', () {
    const startedSeconds = 1_787_472_000;
    const endedSeconds = startedSeconds + 8 * 60 * 60;
    final body = BytesBuilder();

    void u16(int value) {
      final bytes = ByteData(2)..setUint16(0, value, Endian.little);
      body.add(bytes.buffer.asUint8List());
    }

    body.add(const [0, 0, 0, 0, 0, 0, 0]); // reserved file prefix
    u16(480); // total sleep minutes
    body.add(_u32(startedSeconds));
    body.add(_u32(endedSeconds));
    body.add(const [0, 0, 0]); // reserved
    u16(180); // deep
    u16(210); // light
    u16(60); // REM
    u16(30); // awake
    body.addByte(0); // reserved
    body.add(_u32(startedSeconds));
    body.addByte(2); // deep
    body.add(_u32(startedSeconds + 180 * 60));
    body.addByte(3); // light

    final prefix = <int>[..._u32(startedSeconds), 0, 2, 3 << 2, 0];
    prefix.addAll(body.toBytes());
    final file = _activityFile(prefix);
    final parsed = XiaomiHealthSystem().parseActivitySleepFileForTesting(file);

    expect(parsed, isNotNull);
    expect(parsed!.durationSeconds, 480 * 60);
    expect(parsed.awakeDurationSeconds, 30 * 60);
    expect(parsed.lightSleepDurationSeconds, 210 * 60);
    expect(parsed.deepSleepDurationSeconds, 180 * 60);
    expect(parsed.remSleepDurationSeconds, 60 * 60);
    expect(parsed.stages, hasLength(2));
    expect(parsed.stages.first.stage, 2);
    expect(parsed.stages.last.stage, 3);
  });

  test('health data survives the rewritten local serialization', () {
    final data = XiaomiHealthData(
      daily: [
        HealthDailySummary(
          date: DateTime(2026, 8, 15),
          steps: 1234,
          activeCalories: 321,
          calories: 456,
          floorsClimbed: 7,
          restingHeartRate: 55,
          currentHeartRate: 81,
          minHeartRateAt: DateTime(2026, 8, 15, 4),
          maxHeartRateAt: DateTime(2026, 8, 15, 18),
          averageHeartRate: 78,
          averageStress: 24,
          averageBloodOxygen: 97,
          standingBitmap: 0x15,
          vitalityCurrent: 42,
          vitalityLast7Days: 42,
          trainingLoadLast7Days: 180,
          fitnessBalance: -8,
        ),
      ],
      samples: [
        HealthSample(
          timestamp: DateTime(2026, 8, 15, 8),
          metric: XiaomiHealthMetric.heartRate,
          value: 78,
        ),
      ],
      activitySamples: [
        HealthActivitySample(
          timestamp: DateTime(2026, 8, 15, 8),
          steps: 12,
          activeCalories: 2,
          caloriesDelta: 3,
          pressure: 42,
          lightSensation: 55,
          volumeMomentum: 4,
          floors: 1,
        ),
      ],
      sleep: [
        HealthSleepSummary(
          startedAt: DateTime(2026, 8, 14, 23),
          endedAt: DateTime(2026, 8, 15, 7),
          durationSeconds: 8 * 60 * 60,
          averageHeartRate: 61,
          averageBloodOxygen: 97,
          awakeDurationSeconds: 20 * 60,
          lightSleepDurationSeconds: 4 * 60 * 60,
          deepSleepDurationSeconds: 2 * 60 * 60,
          remSleepDurationSeconds: 1 * 60 * 60,
          averageHrv: 42,
          hrvMin: 18,
          hrvMax: 70,
          hrvPoints: [
            HealthSleepHrvPoint(timestamp: DateTime(2026, 8, 15, 1), value: 42),
          ],
          heartRatePoints: [
            HealthSleepVitalPoint(
              timestamp: DateTime(2026, 8, 15, 2),
              value: 63,
            ),
          ],
          bloodOxygenPoints: [
            HealthSleepVitalPoint(
              timestamp: DateTime(2026, 8, 15, 3),
              value: 97,
            ),
          ],
          stages: [
            HealthSleepStageSegment(
              startedAt: DateTime(2026, 8, 15, 0),
              endedAt: DateTime(2026, 8, 15, 1),
              kind: HealthSleepStageKind.deep,
            ),
          ],
        ),
      ],
      abnormalHealthRecords: [
        HealthAbnormalHealthRecord(
          timestamp: DateTime(2026, 8, 15, 9),
          value: 126,
          kind: HealthAbnormalHealthKind.highHeartRate,
          threshold: 120,
        ),
      ],
      workouts: [
        HealthWorkoutSummary(
          startedAt: DateTime(2026, 8, 15, 18),
          endedAt: DateTime(2026, 8, 15, 18, 30),
          activityType: 9,
          distanceMeters: 1000,
          averageSwolf: 42,
          heartRateZones: const [
            HealthWorkoutHeartRateZone(
              zone: 3,
              durationSeconds: 600,
              lowerLimit: 145,
            ),
          ],
          samples: [
            HealthWorkoutSample(
              timestamp: DateTime(2026, 8, 15, 18, 1),
              heartRate: 146,
              swimmingStroke: 2,
              swolf: 42,
              swimmingPaceSecondsPer100Meters: 95,
            ),
          ],
          route: [
            HealthWorkoutRoutePoint(
              timestamp: DateTime(2026, 8, 15, 18),
              latitude: 31.23,
              longitude: 121.47,
            ),
          ],
          recovery: HealthWorkoutHeartRateRecovery(
            startedAt: DateTime(2026, 8, 15, 18, 30),
            recoveredHeartRate: 112,
            recoveryRate: 20,
            heartRates: const [140, 124, 112],
          ),
        ),
      ],
      capabilities: const XiaomiHealthCapabilities(
        heartRate: true,
        bloodOxygen: true,
        stress: true,
        vitality: true,
        sleep: true,
      ),
      lastSyncedAt: DateTime(2026, 8, 15, 8),
    );

    final decoded = XiaomiHealthData.decode(data.encode());

    expect(decoded.latestDay?.steps, 1234);
    expect(decoded.latestDay?.calories, 456);
    expect(decoded.latestDay?.floorsClimbed, 7);
    expect(decoded.latestDay?.restingHeartRate, 55);
    expect(decoded.latestDay?.currentHeartRate, 81);
    expect(decoded.latestDay?.fitnessBalance, -8);
    expect(decoded.latestDay?.standingHours, 3);
    expect(decoded.samplesFor(XiaomiHealthMetric.heartRate), hasLength(1));
    expect(decoded.activitySamples.single.steps, 12);
    expect(decoded.activitySamples.single.caloriesDelta, 3);
    expect(decoded.activitySamples.single.pressure, 42);
    expect(decoded.activitySamples.single.floors, 1);
    expect(decoded.latestSleep?.durationSeconds, 8 * 60 * 60);
    expect(decoded.latestSleep?.deepSleepDurationSeconds, 2 * 60 * 60);
    expect(decoded.latestSleep?.averageHrv, 42);
    expect(decoded.latestSleep?.hrvPoints.single.value, 42);
    expect(decoded.latestSleep?.heartRatePoints.single.value, 63);
    expect(decoded.latestSleep?.bloodOxygenPoints.single.value, 97);
    expect(decoded.latestSleep?.stages.single.kind, HealthSleepStageKind.deep);
    expect(decoded.abnormalHealthRecords.single.value, 126);
    expect(
      decoded.abnormalHealthRecords.single.kind,
      HealthAbnormalHealthKind.highHeartRate,
    );
    expect(decoded.abnormalHeartRates.single.value, 126);
    expect(decoded.workouts.single.averageSwolf, 42);
    expect(decoded.workouts.single.heartRateZones.single.lowerLimit, 145);
    expect(decoded.workouts.single.samples.single.swimmingStroke, 2);
    expect(decoded.workouts.single.route.single.latitude, 31.23);
    expect(decoded.workouts.single.recovery?.heartRates, [140, 124, 112]);
    expect(decoded.capabilities.vitality, isTrue);
    expect(decoded.lastSyncedAt, DateTime(2026, 8, 15, 8));
  });

  test('latest sleep is selected by end time', () {
    final data = XiaomiHealthData(
      sleep: [
        HealthSleepSummary(
          startedAt: DateTime(2026, 8, 24, 23),
          endedAt: DateTime(2026, 8, 26, 8),
          durationSeconds: 9 * 60 * 60,
        ),
        HealthSleepSummary(
          startedAt: DateTime(2026, 8, 25, 12),
          endedAt: DateTime(2026, 8, 25, 14),
          durationSeconds: 2 * 60 * 60,
        ),
      ],
    );

    expect(data.latestSleep?.endedAt, DateTime(2026, 8, 26, 8));
  });

  test('latest sleep day keeps long sleep before later naps', () {
    final longSleep = HealthSleepSummary(
      startedAt: DateTime(2026, 8, 25, 23),
      endedAt: DateTime(2026, 8, 26, 7),
      durationSeconds: 7 * 60 * 60,
      sleepIndex: 1,
    );
    final nap = HealthSleepSummary(
      startedAt: DateTime(2026, 8, 26, 13),
      endedAt: DateTime(2026, 8, 26, 14),
      durationSeconds: 60 * 60,
      sleepIndex: 2,
    );
    final previousDay = HealthSleepSummary(
      startedAt: DateTime(2026, 8, 24, 23),
      endedAt: DateTime(2026, 8, 25, 7),
      durationSeconds: 7 * 60 * 60,
    );
    final data = XiaomiHealthData(sleep: [nap, previousDay, longSleep]);

    expect(data.latestSleep, same(nap));
    expect(data.latestSleepDay, [same(longSleep), same(nap)]);
    expect(data.latestPrimarySleep, same(longSleep));
    expect(data.latestSleepDayDurationSeconds, 8 * 60 * 60);
  });

  test('vitality 7-day total keeps zero days in the calendar window', () {
    HealthDailySummary day(int year, int month, int day, int? vitality) =>
        HealthDailySummary(
          date: DateTime(year, month, day),
          vitalityCurrent: vitality,
        );
    final anchor = day(2026, 9, 10, 5);
    final data = XiaomiHealthData(
      daily: [
        anchor,
        // Zero-earned days must contribute 0, not be skipped.
        day(2026, 9, 9, 0),
        day(2026, 9, 8, 0),
        day(2026, 9, 7, 7),
        // Outside the 7-day window and must not be counted.
        day(2026, 9, 3, 100),
      ],
    );

    expect(data.vitalitySevenDayTotal(anchor), 12);
  });

  test(
    'uses recent valid measurements and fills activity from detail samples',
    () {
      final data = XiaomiHealthData(
        samples: [
          HealthSample(
            timestamp: DateTime(2026, 8, 21, 8),
            metric: XiaomiHealthMetric.activity,
            value: 100,
          ),
          HealthSample(
            timestamp: DateTime(2026, 8, 21, 10),
            metric: XiaomiHealthMetric.activity,
            value: 200,
          ),
          HealthSample(
            timestamp: DateTime(2026, 8, 21, 8),
            metric: XiaomiHealthMetric.activeCalories,
            value: 20,
          ),
          HealthSample(
            timestamp: DateTime(2026, 8, 21, 10),
            metric: XiaomiHealthMetric.activeCalories,
            value: 50,
          ),
          HealthSample(
            timestamp: DateTime(2026, 8, 21, 9),
            metric: XiaomiHealthMetric.heartRate,
            value: 255,
          ),
          HealthSample(
            timestamp: DateTime(2026, 8, 21, 10),
            metric: XiaomiHealthMetric.heartRate,
            value: 79,
          ),
        ],
      );

      expect(data.latestSample(XiaomiHealthMetric.heartRate)?.value, 79);
      expect(data.activitySummary?.steps, 300);
      expect(data.activitySummary?.activeCalories, 70);
      expect(data.activitySummary?.standingHours, 2);
    },
  );

  test(
    'derives activity totals from raw record deltas when samples are absent',
    () {
      final data = XiaomiHealthData(
        activitySamples: [
          HealthActivitySample(
            timestamp: DateTime(2026, 8, 21, 8),
            steps: 100,
            activeCalories: 20,
          ),
          HealthActivitySample(
            timestamp: DateTime(2026, 8, 21, 10),
            steps: 200,
            activeCalories: 50,
          ),
        ],
      );

      expect(data.activitySummary?.steps, 300);
      expect(data.activitySummary?.activeCalories, 70);
      expect(data.activitySummary?.standingHours, 2);
    },
  );

  test('prefers daily report totals over record deltas', () {
    final data = XiaomiHealthData(
      daily: [
        HealthDailySummary(
          date: DateTime(2026, 8, 21),
          steps: 1234,
          activeCalories: 321,
          calories: 999,
        ),
      ],
      activitySamples: [
        HealthActivitySample(
          timestamp: DateTime(2026, 8, 21, 8),
          steps: 100,
          activeCalories: 20,
        ),
      ],
    );

    expect(data.activitySummary?.steps, 1234);
    expect(data.activitySummary?.activeCalories, 321);
  });

  test('sync stores Xiaomi summary and timestamped samples', () async {
    final store = _MemoryHealthStore(const XiaomiHealthData());
    final service = XiaomiHealthSyncService(
      system: _FakeHealthSystem(
        XiaomiActivityFileSyncResult(
          daily: [
            XiaomiActivityDailyRecord(
              date: DateTime(2026, 8, 15),
              steps: 1500,
              activeCalories: 300,
              averageHeartRate: 72,
              averageStress: 18,
              averageBloodOxygen: 97,
              vitalityCurrent: 36,
            ),
          ],
          samples: [
            XiaomiActivitySampleRecord(
              timestamp: DateTime(2026, 8, 15, 10),
              heartRate: 72,
              bloodOxygen: 97,
              stress: 18,
              activeCalories: 12,
            ),
          ],
          sleep: const [],
          workouts: const [],
          filesReceived: 2,
        ),
      ),
      deviceId: 'test-device',
      store: store,
    );

    final result = await service.sync();

    expect(result.updatedDaily, isTrue);
    expect(result.updatedSamples, isTrue);
    expect(result.data.latestDay?.steps, 1500);
    expect(result.data.samplesFor(XiaomiHealthMetric.stress), hasLength(1));
    expect(
      result.data.samplesFor(XiaomiHealthMetric.activeCalories),
      hasLength(1),
    );
    expect(result.data.activitySamples.single.activeCalories, 12);
    expect(result.data.capabilities.vitality, isTrue);
    expect(result.data.capabilities.sleep, isFalse);
    expect(result.data.capabilities.workouts, isFalse);
  });

  test(
    'does not infer health capabilities from an empty activity file',
    () async {
      final store = _MemoryHealthStore(const XiaomiHealthData());
      final service = XiaomiHealthSyncService(
        system: _FakeHealthSystem(
          const XiaomiActivityFileSyncResult(
            daily: [],
            samples: [],
            sleep: [],
            workouts: [],
            filesReceived: 1,
          ),
        ),
        deviceId: 'test-device',
        store: store,
      );

      final result = await service.sync();

      expect(result.data.capabilities.heartRate, isFalse);
      expect(result.data.capabilities.bloodOxygen, isFalse);
      expect(result.data.capabilities.stress, isFalse);
      expect(result.data.capabilities.vitality, isFalse);
      expect(result.data.capabilities.sleep, isFalse);
      expect(result.data.capabilities.workouts, isFalse);
    },
  );

  test('persists successful health files when another file fails', () async {
    final store = _MemoryHealthStore(const XiaomiHealthData());
    final service = XiaomiHealthSyncService(
      system: _FakeHealthSystem(
        XiaomiActivityFileSyncResult(
          daily: [
            XiaomiActivityDailyRecord(date: DateTime(2026, 8, 15), steps: 42),
          ],
          samples: const [],
          sleep: const [],
          workouts: const [],
          filesReceived: 1,
          failedFiles: const [
            XiaomiActivityFileFailure(
              id: '03000000000500',
              attempts: 2,
              error: 'ProtocolException: timed out',
            ),
          ],
        ),
      ),
      deviceId: 'test-device',
      store: store,
    );

    final result = await service.sync();

    expect(result.data.latestDay?.steps, 42);
    expect(result.warning, contains('1 failed activity file'));
    expect(store.value.latestDay?.steps, 42);
  });

  test(
    'does not turn a missing activity file into a successful no-op',
    () async {
      final previous = XiaomiHealthData(
        sleep: [
          HealthSleepSummary(
            startedAt: DateTime(2026, 8, 14, 23),
            endedAt: DateTime(2026, 8, 15, 7),
            durationSeconds: 8 * 60 * 60,
          ),
        ],
        lastSyncedAt: DateTime(2026, 8, 15, 8),
      );
      final store = _MemoryHealthStore(previous);
      final service = XiaomiHealthSyncService(
        system: _FakeHealthSystem(
          const XiaomiActivityFileSyncResult(
            daily: [],
            samples: [],
            sleep: [],
            workouts: [],
            filesReceived: 0,
          ),
        ),
        deviceId: 'test-device',
        store: store,
      );

      await expectLater(service.sync(), throwsA(isA<StateError>()));
      expect(store.value, previous);
    },
  );

  test(
    'propagates activity-file failures without requesting sleep again',
    () async {
      final store = _MemoryHealthStore(const XiaomiHealthData());
      final system = _FakeHealthSystem(
        const XiaomiActivityFileSyncResult(
          daily: [],
          samples: [],
          sleep: [],
          workouts: [],
          filesReceived: 0,
        ),
        activityError: StateError('activity transfer failed'),
      );
      final service = XiaomiHealthSyncService(
        system: system,
        deviceId: 'test-device',
        store: store,
      );

      await expectLater(service.sync(), throwsA(isA<StateError>()));
      expect(system.sleepRequests, 0);
      expect(store.value, const XiaomiHealthData());
    },
  );

  test('does not request an unverified protocol sleep summary', () async {
    final store = _MemoryHealthStore(const XiaomiHealthData());
    final system = _FakeHealthSystem(
      const XiaomiActivityFileSyncResult(
        daily: [],
        samples: [],
        sleep: [],
        workouts: [],
        filesReceived: 1,
      ),
    );
    final service = XiaomiHealthSyncService(
      system: system,
      deviceId: 'test-device',
      store: store,
    );

    final result = await service.sync();
    expect(system.sleepRequests, 0);
    expect(result.data.latestSleep, isNull);
  });
}

List<int> _u32(int value) {
  final bytes = ByteData(4)..setUint32(0, value, Endian.little);
  return bytes.buffer.asUint8List();
}

List<int> _u16(int value) {
  final bytes = ByteData(2)..setUint16(0, value, Endian.little);
  return bytes.buffer.asUint8List();
}

List<int> _i32(int value) {
  final bytes = ByteData(4)..setInt32(0, value, Endian.little);
  return bytes.buffer.asUint8List();
}

void _setValidityBit(Uint8List bytes, int index) {
  bytes[index ~/ 8] |= 1 << (7 - index % 8);
}

Uint8List _activityFile(List<int> prefix) {
  final bytes = Uint8List.fromList(prefix);
  // FitnessDataId byte 4 is the device timezone in signed 15-minute units.
  // Keep the value supplied by each fixture: zero means a UTC device and 32
  // is the explicit UTC+8 case exercised by the timezone regression.
  return Uint8List.fromList([...bytes, ..._u32(_crc32(bytes))]);
}

int _crc32(Uint8List data) {
  var crc = 0xffffffff;
  for (final byte in data) {
    crc ^= byte;
    for (var bit = 0; bit < 8; bit++) {
      crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xedb88320 : crc >> 1;
    }
  }
  return (crc ^ 0xffffffff) & 0xffffffff;
}

class _MemoryHealthStore extends HealthStore {
  _MemoryHealthStore(this.value);

  XiaomiHealthData value;

  @override
  Future<XiaomiHealthData> read(String deviceId) async => value;

  @override
  Future<XiaomiHealthData> write(
    String deviceId,
    XiaomiHealthData data, {
    bool flushImmediately = false,
  }) async {
    value = data;
    return data;
  }
}

class _FakeHealthSystem extends XiaomiHealthSystem {
  _FakeHealthSystem(this.result, {this.activityError});

  final XiaomiActivityFileSyncResult result;
  final Object? activityError;
  var sleepRequests = 0;

  @override
  Future<XiaomiActivityFileSyncResult> syncActivityFiles() async {
    if (activityError != null) throw activityError!;
    return result;
  }
}
