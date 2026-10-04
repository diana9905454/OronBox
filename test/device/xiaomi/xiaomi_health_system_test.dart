import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/core/models/xiaomi_health_models.dart';
import 'package:oronbox/src/device/core/entity.dart';
import 'package:oronbox/src/device/core/event_bus.dart';
import 'package:oronbox/src/device/core/transport.dart';
import 'package:oronbox/src/device/xiaomi/systems/health_system.dart';
import 'package:oronbox/src/device/xiaomi/systems/request_pool_system.dart';
import 'package:oronbox/src/device/xiaomi/systems/xiaomi_device_component.dart';
import 'package:oronbox/src/device/xiaomi/protocol/generated/wear.pb.dart' as pb;
import 'package:oronbox/src/device/xiaomi/protocol/generated/wear_fitness.pb.dart'
    as pb_fitness;
import 'package:oronbox/src/device/xiaomi/protocol/generated/wear_system.pb.dart'
    as pb_system;
import 'package:oronbox/src/device/xiaomi/protocol/packet/l2_packet.dart';
import 'package:oronbox/src/device/xiaomi/protocol/packet/spp_v1_packet.dart';

void main() {
  test('keeps Xiaomi activity timestamps as local wall-clock values', () {
    final timestamp = xiaomiActivityTimestamp(0);

    expect(timestamp.isUtc, isFalse);
    expect(timestamp.year, 1970);
    expect(timestamp.month, 1);
    expect(timestamp.day, 1);
    expect(timestamp.hour, 0);
    expect(timestamp.minute, 0);
  });

  test('converts activity UTC timestamps to the device local wall clock', () {
    final encodedSeconds =
        DateTime.utc(2026, 1, 15, 12, 34, 56).millisecondsSinceEpoch ~/ 1000;
    final timestamp = xiaomiActivityTimestamp(
      encodedSeconds,
      timezoneOffset15Min: 32,
    );

    // UTC 12:34:56 on a UTC+8 device is 20:34:56 local wall clock.
    expect(timestamp, DateTime(2026, 1, 15, 20, 34, 56));

    final utcDeviceTimestamp = xiaomiActivityTimestamp(
      encodedSeconds,
      timezoneOffset15Min: 0,
    );
    expect(utcDeviceTimestamp, DateTime(2026, 1, 15, 12, 34, 56));
  });

  test('health state survives JSON round trip', () {
    const original = XiaomiHealthState(
      isCharging: true,
      isWearing: false,
      isSleeping: true,
      battery: 91,
      chargingStatus: 1,
      wearingStatus: 2,
      sleepingStatus: 1,
      warningStatus: 4,
      sportType: 3,
      sportState: 1,
    );
    expect(XiaomiHealthState.fromJson(original.toJson()), original);
  });

  test('keeps the HEAD workout summary decoder for newer report versions', () {
    final data = Uint8List(53);
    final view = ByteData.sublistView(data);
    view.setUint32(0, 100000, Endian.little);
    data[5] = 9;
    // type=1, subtype=0x16 (outdoor foot), detail=1 (summary report).
    data[6] = 0x80 | (0x16 << 2) | 1;
    view.setUint32(23, 100000, Endian.little);
    view.setUint32(27, 100600, Endian.little);
    view.setUint32(39, 5000, Endian.little);
    view.setUint16(43, 450, Endian.little);
    data.setRange(49, 53, _crc32(Uint8List.sublistView(data, 0, 49)));

    final records = XiaomiHealthSystem().parseActivityWorkoutFilesForTesting(
      data,
    );
    expect(records, hasLength(1));
    expect(records.single.activityType, 0x16);
    expect(records.single.distanceMeters, 5000);
    expect(records.single.calories, 450);
  });

  test('parses a real walking-v2 v5 record capture', () {
    final data = _fixture('8101af6a1005d8.bin');
    final records = XiaomiHealthSystem().parseActivityWorkoutFilesForTesting(
      data,
    );
    expect(records, hasLength(1));
    final record = records.single;
    expect(record.activityType, 0x16);
    expect(record.samples, hasLength(891));
    final heartRates = record.samples
        .map((sample) => sample.heartRate)
        .whereType<int>()
        .where((value) => value > 0)
        .toList();
    expect(heartRates, hasLength(873));
    expect(heartRates.reduce((a, b) => a < b ? a : b), 86);
    expect(heartRates.reduce((a, b) => a > b ? a : b), 154);
    final last = record.samples.last;
    expect(last.steps, 1658);
    expect(last.distanceMeters, 1268);
    expect(last.cadence, 107);
    expect(last.paceSecondsPerKilometer, 680);
    expect(last.strideCentimeters, 82);
  });

  test('parses a real walking-v2 v6 report capture', () {
    final data = _fixture('8101af6a1006d9.bin');
    final records = XiaomiHealthSystem().parseActivityWorkoutFilesForTesting(
      data,
    );
    expect(records, hasLength(1));
    final record = records.single;
    expect(record.activityType, 0x16);
    expect(record.distanceMeters, 1268);
    expect(record.calories, 77);
    expect(record.activeCalories, 56);
    expect(record.totalSteps, 1660);
    expect(record.effectiveDurationSeconds, 891);
    expect(record.averagePaceSecondsPerKilometer, 702);
    expect(record.bestPaceSecondsPerKilometer, 343);
    expect(record.worstPaceSecondsPerKilometer, 819);
    expect(record.averageSpeedKph, closeTo(5.12, 0.01));
    expect(record.bestSpeedKph, closeTo(10.49, 0.01));
    expect(record.averageStrideCentimeters, 82);
    expect(record.averageCadence, 113);
    expect(record.maximumCadence, 136);
    expect(record.averageHeartRate, 117);
    expect(record.maximumHeartRate, 154);
    expect(record.trainingLoad, 6);
    expect(record.earnedVitality, 2);
    expect(record.heartRateZones.map((zone) => zone.durationSeconds).toList(), [
      537,
      160,
      48,
      0,
      0,
    ]);
  });

  test('keeps an explicit zero heart-rate swimming sample', () {
    final records = XiaomiHealthSystem().parseActivityWorkoutFilesForTesting(
      _swimmingZeroHeartRateFixture(),
    );
    expect(records, hasLength(1));
    expect(
      records.single.samples.map((sample) => sample.heartRate).whereType<int>(),
      contains(0),
    );
  });

  test('parses a real daily record capture without desyncing records', () {
    final system = XiaomiHealthSystem();
    final result = system.parseActivityFilesForDebug([
      XiaomiActivityRawFile(
        id: 'c0e9ae6a100400',
        data: _fixture('c0e9ae6a100400.bin'),
      ),
    ]);
    expect(result.samples, hasLength(245));
    final heartRates = result.samples
        .map((sample) => sample.heartRate)
        .whereType<int>()
        .where((value) => value > 0)
        .toList();
    // Every following record must stay aligned: a 1-byte stride error used to
    // produce nonsense heart rates like 32 / 224 bpm.
    expect(heartRates, hasLength(23));
    expect(heartRates.reduce((a, b) => a < b ? a : b), 63);
    expect(heartRates.reduce((a, b) => a > b ? a : b), 146);
    expect(
      (heartRates.reduce((a, b) => a + b) / heartRates.length).round(),
      95,
    );
    final bloodOxygen = result.samples
        .map((sample) => sample.bloodOxygen)
        .whereType<int>()
        .where((value) => value > 0)
        .toList();
    expect(bloodOxygen, isNotEmpty);
    expect(bloodOxygen.every((value) => value >= 90 && value <= 100), isTrue);
  });

  test('ignores a 13-byte placeholder GPS track', () {
    final data = _fixture('8101af6a1002da.bin');
    final records = XiaomiHealthSystem().parseActivityWorkoutFilesForTesting(
      data,
    );
    expect(records, isEmpty);
  });

  test('maps the basic snapshot to health and battery events', () async {
    final eventBus = DeviceEventBus();
    final entity = _entity(eventBus);
    final system = XiaomiHealthSystem();
    entity.registerSystem(system);

    final healthEvent = eventBus.stream
        .where((event) => event is XiaomiHealthStateUpdated)
        .cast<XiaomiHealthStateUpdated>()
        .first;
    final batteryEvent = eventBus.stream
        .where((event) => event is BatteryUpdated)
        .cast<BatteryUpdated>()
        .first;

    system.onWearPacket(
      pb.WearPacket(
        type: pb.WearPacket_Type.SYSTEM,
        id: pb_system.System_SystemID.GET_BASIC_STATUS.value,
        system: pb_system.System(
          presentBasicStatus: pb_system.BasicStatus_Present(
            isCharging: true,
            battery: 87,
            isWearing: true,
            isSleeping: false,
          ),
        ),
      ),
    );

    final health = await healthEvent;
    final battery = await batteryEvent;
    expect(
      health.health,
      const XiaomiHealthState(
        isCharging: true,
        isWearing: true,
        isSleeping: false,
        battery: 87,
        chargingStatus: 1,
        wearingStatus: 1,
        sleepingStatus: 2,
      ),
    );
    expect(battery.battery.capacity, 87);
    eventBus.dispose();
  });

  test('maps partial reports without losing the other health states', () async {
    final eventBus = DeviceEventBus();
    final entity = _entity(eventBus);
    final system = XiaomiHealthSystem();
    entity.registerSystem(system);

    final firstEvent = eventBus.stream
        .where((event) => event is XiaomiHealthStateUpdated)
        .cast<XiaomiHealthStateUpdated>()
        .first;
    system.onWearPacket(
      pb.WearPacket(
        type: pb.WearPacket_Type.SYSTEM,
        id: pb_system.System_SystemID.GET_BASIC_STATUS.value,
        system: pb_system.System(
          presentBasicStatus: pb_system.BasicStatus_Present(
            isCharging: false,
            isWearing: true,
            isSleeping: false,
          ),
        ),
      ),
    );
    await firstEvent;
    final event = eventBus.stream
        .where((event) => event is XiaomiHealthStateUpdated)
        .cast<XiaomiHealthStateUpdated>()
        .first;
    system.onWearPacket(
      pb.WearPacket(
        type: pb.WearPacket_Type.SYSTEM,
        id: pb_system.System_SystemID.REPORT_BASIC_STATUS.value,
        system: pb_system.System(
          reportBasicStatus: pb_system.BasicStatus_Report(
            sleeping: pb_system.BasicStatus_Sleeping.IN,
          ),
        ),
      ),
    );

    final health = await event;
    expect(health.health.isWearing, true);
    expect(health.health.isSleeping, true);
    expect(health.health.sleepingStatus, 1);
    eventBus.dispose();
  });

  test('exposes typed streams for fitness payloads', () async {
    final eventBus = DeviceEventBus();
    final entity = _entity(eventBus);
    final system = XiaomiHealthSystem();
    entity.registerSystem(system);
    final basicData = system.basicDataReports.first;
    final sleepResult = system.sleepResults.first;
    final sensorData = system.sensorReports.first;
    final heartRate = system.heartRateReports.first;
    final bloodOxygen = system.bloodOxygenReports.first;

    system.onWearPacket(
      pb.WearPacket(
        type: pb.WearPacket_Type.FITNESS,
        id: pb_fitness.Fitness_FitnessID.REPORT_BASIC_DATA.value,
        fitness: pb_fitness.Fitness(
          basicData: pb_fitness.BasicData(
            steps: 1200,
            calories: 73,
            heartRate: 72,
          ),
        ),
      ),
    );
    system.onWearPacket(
      pb.WearPacket(
        type: pb.WearPacket_Type.FITNESS,
        id: pb_fitness.Fitness_FitnessID.SYNC_SLEEP_RESULT.value,
        fitness: pb_fitness.Fitness(
          sleepResult: pb_fitness.SleepResult(
            sectionList: [
              pb_fitness.SleepResult_Section(
                averageHeartRate: 61,
                averageBloodOxygen: 96,
              ),
            ],
          ),
        ),
      ),
    );
    system.onWearPacket(
      pb.WearPacket(
        type: pb.WearPacket_Type.FITNESS,
        id: pb_fitness.Fitness_FitnessID.WEAR_SENSOR_DATA.value,
        fitness: pb_fitness.Fitness(
          wearSensorData: pb_fitness.WearSensorData(),
        ),
      ),
    );

    expect((await basicData).steps, 1200);
    expect(await heartRate, 72);
    expect(await bloodOxygen, 96);
    expect(await sleepResult, isA<pb_fitness.SleepResult>());
    expect(await sensorData, isA<pb_fitness.WearSensorData>());
    await entity.dispose();
    eventBus.dispose();
  });

  test('matches fitness requests by response id', () async {
    final eventBus = DeviceEventBus();
    final transport = _UnusedTransport();
    final entity = DeviceEntity(
      id: 'device-a',
      kind: 'xiaomi',
      transport: transport,
      eventBus: eventBus,
    );
    final component = XiaomiDeviceComponent(transport: transport, sppV1: true);
    entity.set(component);
    entity.registerSystem(XiaomiRequestPoolSystem());
    final system = XiaomiHealthSystem();
    entity.registerSystem(system);

    final future = system.fetchBasicData();
    var completed = false;
    future.then((_) => completed = true);
    await Future<void>.delayed(const Duration(milliseconds: 10));

    component.requestPool.onPacket(
      pb.WearPacket(
        type: pb.WearPacket_Type.FITNESS,
        id: pb_fitness.Fitness_FitnessID.GET_HEART_RATE_MONITOR.value,
        fitness: pb_fitness.Fitness(
          basicData: pb_fitness.BasicData(steps: 1, calories: 1),
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(completed, false);

    component.requestPool.onPacket(
      pb.WearPacket(
        type: pb.WearPacket_Type.FITNESS,
        id: pb_fitness.Fitness_FitnessID.GET_BASIC_DATA.value,
        fitness: pb_fitness.Fitness(
          basicData: pb_fitness.BasicData(steps: 42, calories: 7),
        ),
      ),
    );
    expect((await future).steps, 42);
    await entity.dispose();
    eventBus.dispose();
  });

  test(
    'receives and validates an activity file on the dedicated channel',
    () async {
      final eventBus = DeviceEventBus();
      final transport = _RecordingTransport();
      final entity = DeviceEntity(
        id: 'device-a',
        kind: 'xiaomi-spp-v1',
        transport: transport,
        eventBus: eventBus,
      );
      final component = XiaomiDeviceComponent(
        transport: transport,
        sppV1: true,
      );
      entity.set(component);
      entity.registerSystem(XiaomiRequestPoolSystem());
      final system = XiaomiHealthSystem();
      entity.registerSystem(system);

      final fileId = Uint8List.fromList(const [1, 0, 0, 0, 0, 5, 0]);
      final sync = system.syncActivityFiles();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      component.requestPool.onPacket(
        pb.WearPacket(
          type: pb.WearPacket_Type.FITNESS,
          id: pb_fitness.Fitness_FitnessID.GET_TODAY_FITNESS_IDS.value,
          fitness: pb_fitness.Fitness(ids: fileId),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final body = Uint8List.fromList([...fileId, 0, 0, 0, 0, 0]);
      final withCrc = Uint8List.fromList([...body, ..._crc32(body)]);
      Uint8List chunk(int number, int start, int end) {
        final value = Uint8List(end - start + 4);
        final header = ByteData.sublistView(value);
        header.setUint16(0, 2, Endian.little);
        header.setUint16(2, number, Endian.little);
        value.setRange(4, value.length, withCrc.sublist(start, end));
        return value;
      }

      await Future<void>.delayed(const Duration(milliseconds: 10));
      final codec = XiaomiSppV1Codec();
      final packets = <XiaomiSppV1Packet>[];
      for (final frame in transport.sent) {
        packets.addAll(codec.add(frame));
      }
      final protobufPackets = packets
          .where((packet) => packet.channel == XiaomiSppV1Channel.protobuf)
          .map((packet) => pb.WearPacket.fromBuffer(packet.payload))
          .toList(growable: false);
      final fileRequestIndex = protobufPackets.indexWhere(
        (packet) =>
            packet.id ==
                pb_fitness.Fitness_FitnessID.REQUEST_FITNESS_IDS.value &&
            packet.fitness.hasIds(),
      );
      final historyRequestIndex = protobufPackets.indexWhere(
        (packet) =>
            packet.id ==
            pb_fitness.Fitness_FitnessID.GET_HISTORY_FITNESS_IDS.value,
      );
      expect(fileRequestIndex, greaterThanOrEqualTo(0));
      expect(historyRequestIndex, greaterThan(fileRequestIndex));
      final fileRequests = packets
          .where((packet) => packet.channel == XiaomiSppV1Channel.protobuf)
          .map((packet) => pb.WearPacket.fromBuffer(packet.payload))
          .where(
            (packet) =>
                packet.id ==
                pb_fitness.Fitness_FitnessID.REQUEST_FITNESS_IDS.value,
          )
          .toList(growable: false);
      expect(fileRequests, hasLength(1));
      expect(fileRequests.single.fitness.hasIds(), isTrue);
      expect(fileRequests.single.fitness.ids, orderedEquals(fileId));
      expect(
        packets
            .where((packet) => packet.channel == XiaomiSppV1Channel.protobuf)
            .map((packet) => pb.WearPacket.fromBuffer(packet.payload))
            .any(
              (packet) =>
                  packet.id ==
                  pb_fitness.Fitness_FitnessID.GET_HISTORY_FITNESS_IDS.value,
            ),
        isTrue,
      );

      // The official receiver accepts only the next sequence number. Feed
      // the chunks through the real dedicated L2 channel entry point rather
      // than bypassing the transport dispatch in the test.
      system.onLayer2Packet(
        L2Channel.fileFitness,
        L2OpCode.write,
        chunk(1, 0, 8),
      );
      system.onLayer2Packet(
        L2Channel.fileFitness,
        L2OpCode.write,
        chunk(2, 8, withCrc.length),
      );

      component.requestPool.onPacket(
        pb.WearPacket(
          type: pb.WearPacket_Type.FITNESS,
          id: pb_fitness.Fitness_FitnessID.GET_HISTORY_FITNESS_IDS.value,
          fitness: pb_fitness.Fitness(ids: fileId),
        ),
      );

      final result = await sync;
      expect(result.filesReceived, 1);
      expect(transport.sent, isNotEmpty);
      await entity.dispose();
      eventBus.dispose();
    },
  );

  test(
    'interleaves today and history IDs using Gadgetbridge fetch priority',
    () async {
      final eventBus = DeviceEventBus();
      final transport = _RecordingTransport();
      final entity = DeviceEntity(
        id: 'device-a',
        kind: 'xiaomi-spp-v1',
        transport: transport,
        eventBus: eventBus,
      );
      final component = XiaomiDeviceComponent(
        transport: transport,
        sppV1: true,
      );
      entity.set(component);
      entity.registerSystem(XiaomiRequestPoolSystem());
      final system = XiaomiHealthSystem();
      entity.registerSystem(system);

      Uint8List fileId(int timestamp) =>
          Uint8List.fromList([timestamp, 0, 0, 0, 0, 5, 1]);

      final todayIds = [fileId(4), fileId(5), fileId(1)];
      final historyIds = [fileId(0), fileId(2)];
      final sync = system.syncActivityFiles();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      component.requestPool.onPacket(
        pb.WearPacket(
          type: pb.WearPacket_Type.FITNESS,
          id: pb_fitness.Fitness_FitnessID.GET_TODAY_FITNESS_IDS.value,
          fitness: pb_fitness.Fitness(
            ids: Uint8List.fromList(todayIds.expand((id) => id).toList()),
          ),
        ),
      );
      await _waitFor(() => _activityFileRequestCount(transport) == 1);

      // Gadgetbridge keeps a priority queue while the historical list is
      // fetched. Earlier history files should be next after the in-flight ID.
      await _waitFor(
        () => _hasFitnessRequest(
          transport,
          pb_fitness.Fitness_FitnessID.GET_HISTORY_FITNESS_IDS.value,
        ),
      );
      component.requestPool.onPacket(
        pb.WearPacket(
          type: pb.WearPacket_Type.FITNESS,
          id: pb_fitness.Fitness_FitnessID.GET_HISTORY_FITNESS_IDS.value,
          fitness: pb_fitness.Fitness(
            ids: Uint8List.fromList(historyIds.expand((id) => id).toList()),
          ),
        ),
      );

      final requestedIds = <String>[];
      for (var index = 0; index < 5; index++) {
        await _waitFor(() => _activityFileRequestCount(transport) > index);
        final requests = _protobufPackets(transport).where(
          (packet) =>
              packet.id ==
                  pb_fitness.Fitness_FitnessID.REQUEST_FITNESS_IDS.value &&
              packet.fitness.hasIds() &&
              packet.fitness.ids.length == 7,
        );
        final fileId = Uint8List.fromList(
          requests.elementAt(index).fitness.ids,
        );
        requestedIds.add(
          fileId.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(),
        );
        for (final chunk in _emptyActivityFileChunks(fileId)) {
          system.onLayer2Packet(L2Channel.fileFitness, L2OpCode.write, chunk);
        }
      }

      final result = await sync;
      expect(requestedIds, [
        '01000000000501',
        '00000000000501',
        '02000000000501',
        '04000000000501',
        '05000000000501',
      ]);
      expect(result.failedFiles, isEmpty);

      await entity.dispose();
      eventBus.dispose();
    },
  );

  test('processes and confirms the received file ID when it differs from the request', () async {
    final eventBus = DeviceEventBus();
    final transport = _RecordingTransport();
    final entity = DeviceEntity(
      id: 'device-a',
      kind: 'xiaomi-spp-v1',
      transport: transport,
      eventBus: eventBus,
    );
    final component = XiaomiDeviceComponent(transport: transport, sppV1: true);
    entity.set(component);
    entity.registerSystem(XiaomiRequestPoolSystem());
    final system = XiaomiHealthSystem();
    entity.registerSystem(system);

    final requestedId = Uint8List.fromList(const [3, 0, 0, 0, 0, 5, 1]);
    final earlyId = Uint8List.fromList(const [4, 0, 0, 0, 0, 5, 1]);
    final sync = system.syncActivityFiles();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    component.requestPool.onPacket(
      pb.WearPacket(
        type: pb.WearPacket_Type.FITNESS,
        id: pb_fitness.Fitness_FitnessID.GET_TODAY_FITNESS_IDS.value,
        fitness: pb_fitness.Fitness(ids: requestedId),
      ),
    );
    await _waitFor(() => _activityFileRequestCount(transport) == 1);

    for (final chunk in _emptyActivityFileChunks(earlyId)) {
      system.onLayer2Packet(L2Channel.fileFitness, L2OpCode.write, chunk);
    }
    // The complete payload's header is authoritative even when its ID was
    // not in this ID list. Process and confirm it before retrying the still-
    // missing requested ID.
    await _waitFor(() => _activityFileRequestCount(transport) == 2);
    final fileRequests = _protobufPackets(transport)
        .where(
          (packet) =>
              (packet.id ==
                      pb_fitness.Fitness_FitnessID.REQUEST_FITNESS_ID.value &&
                  packet.fitness.hasId()) ||
              (packet.id ==
                      pb_fitness.Fitness_FitnessID.REQUEST_FITNESS_IDS.value &&
                  packet.fitness.hasIds()),
        )
        .toList(growable: false);
    expect(fileRequests, hasLength(2));
    expect(
      fileRequests.map((packet) => packet.id),
      everyElement(pb_fitness.Fitness_FitnessID.REQUEST_FITNESS_IDS.value),
    );
    expect(fileRequests[1].fitness.ids, orderedEquals(requestedId));
    final earlyConfirmations = _protobufPackets(transport)
        .where(
          (packet) =>
              packet.id ==
              pb_fitness.Fitness_FitnessID.CONFIRM_FITNESS_ID.value,
        )
        .map((packet) => packet.fitness.id)
        .toList(growable: false);
    expect(earlyConfirmations, [earlyId]);
    for (final chunk in _emptyActivityFileChunks(requestedId)) {
      system.onLayer2Packet(L2Channel.fileFitness, L2OpCode.write, chunk);
    }

    await _waitFor(
      () => _hasFitnessRequest(
        transport,
        pb_fitness.Fitness_FitnessID.GET_HISTORY_FITNESS_IDS.value,
      ),
    );
    component.requestPool.onPacket(
      pb.WearPacket(
        type: pb.WearPacket_Type.FITNESS,
        id: pb_fitness.Fitness_FitnessID.GET_HISTORY_FITNESS_IDS.value,
        fitness: pb_fitness.Fitness(ids: Uint8List(0)),
      ),
    );

    final result = await sync;
    expect(result.rawFiles.map((file) => file.id), [
      '04000000000501',
      '03000000000501',
    ]);
    expect(
      result.rawFiles.map(
        (file) => file.data
            .take(7)
            .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
            .join(),
      ),
      ['04000000000501', '03000000000501'],
    );
    final confirmations = _protobufPackets(transport)
        .where(
          (packet) =>
              packet.id ==
              pb_fitness.Fitness_FitnessID.CONFIRM_FITNESS_ID.value,
        )
        .map(
          (packet) => packet.fitness.id
              .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
              .join(),
        )
        .toList(growable: false);
    expect(confirmations, ['04000000000501', '03000000000501']);

    await entity.dispose();
    eventBus.dispose();
  });

  test('confirms a CRC-valid empty activity file', () async {
    final eventBus = DeviceEventBus();
    final transport = _RecordingTransport();
    final entity = DeviceEntity(
      id: 'device-a',
      kind: 'xiaomi-spp-v1',
      transport: transport,
      eventBus: eventBus,
    );
    final component = XiaomiDeviceComponent(transport: transport, sppV1: true);
    entity.set(component);
    entity.registerSystem(XiaomiRequestPoolSystem());
    final system = XiaomiHealthSystem();
    entity.registerSystem(system);

    final fileId = Uint8List.fromList(const [5, 0, 0, 0, 0, 6, 0]);
    final sync = system.syncActivityFiles();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    component.requestPool.onPacket(
      pb.WearPacket(
        type: pb.WearPacket_Type.FITNESS,
        id: pb_fitness.Fitness_FitnessID.GET_TODAY_FITNESS_IDS.value,
        fitness: pb_fitness.Fitness(ids: fileId),
      ),
    );

    await _waitFor(() => _activityFileRequestCount(transport) == 1);
    final emptyFile = Uint8List.fromList([...fileId, ..._crc32(fileId)]);
    final chunk = Uint8List(emptyFile.length + 4);
    final header = ByteData.sublistView(chunk);
    header.setUint16(0, 1, Endian.little);
    header.setUint16(2, 1, Endian.little);
    chunk.setRange(4, chunk.length, emptyFile);
    system.onLayer2Packet(L2Channel.fileFitness, L2OpCode.write, chunk);

    await _waitFor(
      () => _hasFitnessRequest(
        transport,
        pb_fitness.Fitness_FitnessID.GET_HISTORY_FITNESS_IDS.value,
      ),
    );
    component.requestPool.onPacket(
      pb.WearPacket(
        type: pb.WearPacket_Type.FITNESS,
        id: pb_fitness.Fitness_FitnessID.GET_HISTORY_FITNESS_IDS.value,
        fitness: pb_fitness.Fitness(ids: Uint8List(0)),
      ),
    );

    final result = await sync;
    final confirmations = _protobufPackets(transport)
        .where(
          (packet) =>
              packet.id ==
              pb_fitness.Fitness_FitnessID.CONFIRM_FITNESS_ID.value,
        )
        .toList(growable: false);
    expect(result.filesReceived, 0);
    expect(result.filesSkipped, 1);
    expect(result.failedFiles, isEmpty);
    expect(confirmations, hasLength(1));
    expect(confirmations.single.fitness.hasId(), isTrue);
    expect(confirmations.single.fitness.id, orderedEquals(fileId));

    await entity.dispose();
    eventBus.dispose();
  });

  test(
    'buffers an activity file emitted before its request future is waiting',
    () async {
      final eventBus = DeviceEventBus();
      final transport = _RecordingTransport();
      final entity = DeviceEntity(
        id: 'device-a',
        kind: 'xiaomi-spp-v1',
        transport: transport,
        eventBus: eventBus,
      );
      final component = XiaomiDeviceComponent(
        transport: transport,
        sppV1: true,
      );
      entity.set(component);
      entity.registerSystem(XiaomiRequestPoolSystem());
      final system = XiaomiHealthSystem();
      entity.registerSystem(system);

      final fileId = Uint8List.fromList(const [2, 0, 0, 0, 0, 5, 0]);
      final body = Uint8List.fromList([...fileId, 0, 0, 0, 0, 0]);
      final withCrc = Uint8List.fromList([...body, ..._crc32(body)]);
      Uint8List chunk(int number, int start, int end) {
        final value = Uint8List(end - start + 4);
        final header = ByteData.sublistView(value);
        header.setUint16(0, 2, Endian.little);
        header.setUint16(2, number, Endian.little);
        value.setRange(4, value.length, withCrc.sublist(start, end));
        return value;
      }

      // This is the interval that used to be logged as "unsolicited" and
      // discarded. The dedicated channel still carries a complete, valid
      // file, so it can be retained until today's ID list identifies it.
      system.onLayer2Packet(
        L2Channel.fileFitness,
        L2OpCode.write,
        chunk(1, 0, 8),
      );
      system.onLayer2Packet(
        L2Channel.fileFitness,
        L2OpCode.write,
        chunk(2, 8, withCrc.length),
      );

      final sync = system.syncActivityFiles();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      component.requestPool.onPacket(
        pb.WearPacket(
          type: pb.WearPacket_Type.FITNESS,
          id: pb_fitness.Fitness_FitnessID.GET_TODAY_FITNESS_IDS.value,
          fitness: pb_fitness.Fitness(ids: fileId),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final codec = XiaomiSppV1Codec();
      final packets = <XiaomiSppV1Packet>[];
      for (final frame in transport.sent) {
        packets.addAll(codec.add(frame));
      }
      final fileRequests = packets
          .where((packet) => packet.channel == XiaomiSppV1Channel.protobuf)
          .map((packet) => pb.WearPacket.fromBuffer(packet.payload))
          .where(
            (packet) =>
                (packet.id ==
                        pb_fitness.Fitness_FitnessID.REQUEST_FITNESS_ID.value &&
                    packet.fitness.hasId()) ||
                (packet.id ==
                        pb_fitness
                            .Fitness_FitnessID
                            .REQUEST_FITNESS_IDS
                            .value &&
                    packet.fitness.hasIds()),
          )
          .toList(growable: false);
      expect(fileRequests, isEmpty);

      component.requestPool.onPacket(
        pb.WearPacket(
          type: pb.WearPacket_Type.FITNESS,
          id: pb_fitness.Fitness_FitnessID.GET_HISTORY_FITNESS_IDS.value,
          fitness: pb_fitness.Fitness(ids: Uint8List(0)),
        ),
      );
      final result = await sync;
      expect(result.filesReceived, 1);
      await entity.dispose();
      eventBus.dispose();
    },
  );

  test(
    'continues with later activity files after a file exhausts its retries',
    () async {
      final eventBus = DeviceEventBus();
      final transport = _RecordingTransport();
      final entity = DeviceEntity(
        id: 'device-a',
        kind: 'xiaomi-spp-v1',
        transport: transport,
        eventBus: eventBus,
      );
      final component = XiaomiDeviceComponent(
        transport: transport,
        sppV1: true,
      );
      entity.set(component);
      entity.registerSystem(XiaomiRequestPoolSystem());
      final system = XiaomiHealthSystem();
      entity.registerSystem(system);

      final failedId = Uint8List.fromList(const [3, 0, 0, 0, 0, 5, 0]);
      final goodId = Uint8List.fromList(const [4, 0, 0, 0, 0, 5, 0]);
      final sync = system.syncActivityFiles();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      component.requestPool.onPacket(
        pb.WearPacket(
          type: pb.WearPacket_Type.FITNESS,
          id: pb_fitness.Fitness_FitnessID.GET_TODAY_FITNESS_IDS.value,
          fitness: pb_fitness.Fitness(
            ids: Uint8List.fromList([...failedId, ...goodId]),
          ),
        ),
      );

      await _waitFor(() => _activityFileRequestCount(transport) == 1);
      await _waitFor(
        () => _hasFitnessRequest(
          transport,
          pb_fitness.Fitness_FitnessID.GET_HISTORY_FITNESS_IDS.value,
        ),
      );
      component.requestPool.onPacket(
        pb.WearPacket(
          type: pb.WearPacket_Type.FITNESS,
          id: pb_fitness.Fitness_FitnessID.GET_HISTORY_FITNESS_IDS.value,
          fitness: pb_fitness.Fitness(ids: Uint8List(0)),
        ),
      );

      // A bad sequence number fails the active transfer immediately. The
      // synchronizer should retry this file once, then move to goodId.
      system.onLayer2Packet(
        L2Channel.fileFitness,
        L2OpCode.write,
        _invalidActivityChunk(),
      );
      await _waitFor(() => _activityFileRequestCount(transport) == 2);
      system.onLayer2Packet(
        L2Channel.fileFitness,
        L2OpCode.write,
        _invalidActivityChunk(),
      );
      await _waitFor(() => _activityFileRequestCount(transport) == 3);

      for (final chunk in _validActivityFileChunks(goodId)) {
        system.onLayer2Packet(L2Channel.fileFitness, L2OpCode.write, chunk);
      }

      final result = await sync;
      expect(result.filesReceived, 1);
      expect(result.failedFiles, hasLength(1));
      expect(result.failedFiles.single.id, '03000000000500');
      expect(result.failedFiles.single.attempts, 2);
      expect(result.filesSkipped, 0);
      await entity.dispose();
      eventBus.dispose();
    },
  );
}

DeviceEntity _entity(DeviceEventBus eventBus) => DeviceEntity(
  id: 'device-a',
  kind: 'xiaomi',
  transport: _UnusedTransport(),
  eventBus: eventBus,
);

class _UnusedTransport implements Transport {
  @override
  String get deviceId => 'device-a';

  @override
  String get deviceName => 'Device A';

  @override
  Stream<Uint8List> get incomingData => const Stream.empty();

  @override
  Stream<bool> get connectionState => const Stream.empty();

  @override
  Future<void> send(Uint8List data) async {}

  @override
  Future<void> dispose() async {}
}

class _RecordingTransport extends _UnusedTransport {
  final sent = <Uint8List>[];

  @override
  Future<void> send(Uint8List data) async {
    sent.add(Uint8List.fromList(data));
  }
}

List<int> _crc32(Uint8List data) {
  var crc = 0xffffffff;
  for (final byte in data) {
    crc ^= byte;
    for (var bit = 0; bit < 8; bit++) {
      crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xedb88320 : crc >> 1;
    }
  }
  final value = (crc ^ 0xffffffff) & 0xffffffff;
  return [
    value & 0xff,
    (value >> 8) & 0xff,
    (value >> 16) & 0xff,
    (value >> 24) & 0xff,
  ];
}

Future<void> _waitFor(bool Function() condition) async {
  for (var attempt = 0; attempt < 150; attempt++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(condition(), isTrue, reason: 'condition did not become true');
}

Uint8List _fixture(String name) {
  final file = File(
    '${Directory.current.path}/test/device/xiaomi/fixtures/$name',
  );
  return file.readAsBytesSync();
}

List<pb.WearPacket> _protobufPackets(_RecordingTransport transport) {
  final codec = XiaomiSppV1Codec();
  final packets = <XiaomiSppV1Packet>[];
  for (final frame in transport.sent) {
    packets.addAll(codec.add(frame));
  }
  return packets
      .where((packet) => packet.channel == XiaomiSppV1Channel.protobuf)
      .map((packet) => pb.WearPacket.fromBuffer(packet.payload))
      .toList(growable: false);
}

int _activityFileRequestCount(_RecordingTransport transport) =>
    _protobufPackets(transport)
        .where(
          (packet) =>
              packet.id ==
                  pb_fitness.Fitness_FitnessID.REQUEST_FITNESS_IDS.value &&
              packet.fitness.hasIds() &&
              packet.fitness.ids.length == 7,
        )
        .length;

bool _hasFitnessRequest(_RecordingTransport transport, int id) =>
    _protobufPackets(transport).any((packet) => packet.id == id);

Uint8List _invalidActivityChunk() {
  final value = Uint8List(4);
  final header = ByteData.sublistView(value);
  header.setUint16(0, 2, Endian.little);
  header.setUint16(2, 2, Endian.little);
  return value;
}

List<Uint8List> _validActivityFileChunks(Uint8List id) {
  final body = Uint8List.fromList([...id, 0, 0, 0, 0, 0]);
  final data = Uint8List.fromList([...body, ..._crc32(body)]);

  Uint8List chunk(int number, int start, int end) {
    final value = Uint8List(end - start + 4);
    final header = ByteData.sublistView(value);
    header.setUint16(0, 2, Endian.little);
    header.setUint16(2, number, Endian.little);
    value.setRange(4, value.length, data.sublist(start, end));
    return value;
  }

  return [chunk(1, 0, 8), chunk(2, 8, data.length)];
}

List<Uint8List> _emptyActivityFileChunks(Uint8List id) {
  final data = Uint8List.fromList([...id, ..._crc32(id)]);
  final chunk = Uint8List(data.length + 4);
  final header = ByteData.sublistView(chunk);
  header.setUint16(0, 1, Endian.little);
  header.setUint16(2, 1, Endian.little);
  chunk.setRange(4, chunk.length, data);
  return [chunk];
}

Uint8List _swimmingZeroHeartRateFixture() {
  final body = Uint8List(55);
  final view = ByteData.sublistView(body);
  view.setUint32(0, 1000, Endian.little);
  body[4] = 0;
  body[5] = 3;
  body[6] = 0x80 | (9 << 2); // swimming samples, detail type
  body[7] = 0;
  body.setRange(8, 11, const [0xff, 0xff, 0xff]);
  var offset = 11;
  view.setUint32(offset, 1, Endian.little);
  view.setUint32(offset + 4, 1001, Endian.little);
  offset += 8;
  body[offset] = 0;
  view.setUint32(offset + 1, 1001, Endian.little);
  body[offset + 5] = 1;
  view.setUint16(offset + 6, 2, Endian.little);
  view.setUint16(offset + 8, 3, Endian.little);
  offset += 10;
  // dataType 0 has a 25-byte extension; its final four bytes are the HR
  // count, followed by the count one-byte heart-rate samples.
  view.setUint32(offset + 21, 1, Endian.little);
  offset += 25;
  body[offset] = 0;
  return Uint8List.fromList([...body, ..._crc32(body)]);
}
