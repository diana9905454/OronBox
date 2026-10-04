import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/device/core/entity.dart';
import 'package:oronbox/src/device/core/event_bus.dart';
import 'package:oronbox/src/device/core/transport.dart';
import 'package:oronbox/src/device/xiaomi/systems/sync_system.dart';
import 'package:oronbox/src/device/xiaomi/xiaomi_time.dart';
import 'package:oronbox/src/device/xiaomi/protocol/generated/wear.pb.dart' as pb;
import 'package:oronbox/src/device/xiaomi/protocol/generated/wear_common.pb.dart'
    as pb_common;
import 'package:oronbox/src/device/xiaomi/protocol/generated/wear_system.pb.dart'
    as pb_system;

void main() {
  test('forwards an inbound wearable phone-finder request', () async {
    final eventBus = DeviceEventBus();
    final entity = DeviceEntity(
      id: 'device-a',
      kind: 'xiaomi',
      transport: _UnusedTransport(),
      eventBus: eventBus,
    );
    final system = XiaomiSyncSystem();
    entity.registerSystem(system);
    final event = eventBus.stream
        .where((value) => value is XiaomiFindPhoneRequested)
        .cast<XiaomiFindPhoneRequested>()
        .first;

    system.onWearPacket(
      pb.WearPacket(
        type: pb.WearPacket_Type.SYSTEM,
        id: pb_system.System_SystemID.FIND_PHONE.value,
        system: pb_system.System(findMode: pb_system.FindMode.FIND_START),
      ),
    );

    expect((await event).finding, isTrue);
    await entity.dispose();
    eventBus.dispose();
  });

  test('forwards an inbound wearable finder stop notification', () async {
    final eventBus = DeviceEventBus();
    final entity = DeviceEntity(
      id: 'device-a',
      kind: 'xiaomi',
      transport: _UnusedTransport(),
      eventBus: eventBus,
    );
    final system = XiaomiSyncSystem();
    entity.registerSystem(system);
    final event = eventBus.stream
        .where((value) => value is XiaomiFindWearableRequested)
        .cast<XiaomiFindWearableRequested>()
        .first;

    system.onWearPacket(
      pb.WearPacket(
        type: pb.WearPacket_Type.SYSTEM,
        id: pb_system.System_SystemID.FIND_WEAR.value,
        system: pb_system.System(findMode: pb_system.FindMode.FIND_STOP),
      ),
    );

    expect((await event).finding, isFalse);
    await entity.dispose();
    eventBus.dispose();
  });

  test('encodes timezone offsets as Xiaomi 15-minute sint32 values', () {
    final timezone = pb_common.Timezone(
      offset: 32, // UTC+8, expressed in 15-minute units.
      dstSaving: 0,
      id: 'Asia/Shanghai',
      idSpec: '',
    );

    expect(timezone.writeToBuffer(), <int>[
      0x08,
      0x40, // sint32(32) -> ZigZag 64.
      0x10,
      0x00,
      0x1a,
      0x0d,
      0x41,
      0x73,
      0x69,
      0x61,
      0x2f,
      0x53,
      0x68,
      0x61,
      0x6e,
      0x67,
      0x68,
      0x61,
      0x69,
      0x22,
      0x00,
    ]);
  });

  test(
    'encodes negative and fractional timezone offsets without truncation',
    () {
      for (final (offset, encoded) in <(int, int)>[
        (-16, 0x1f), // UTC-4.
        (22, 0x2c), // UTC+5:30.
        (23, 0x2e), // UTC+5:45.
      ]) {
        final timezone = pb_common.Timezone(
          offset: offset,
          id: 'GMT',
          idSpec: '',
        );
        expect(timezone.writeToBuffer().take(2).toList(), [0x08, encoded]);
      }
    },
  );

  test('does not send ambiguous platform timezone abbreviations', () {
    expect(xiaomiTimeZoneId('CST', const Duration(hours: 8)), 'GMT+08:00');
    expect(xiaomiTimeZoneId('EDT', const Duration(hours: -4)), 'GMT-04:00');
    expect(
      xiaomiTimeZoneId('IST', const Duration(hours: 5, minutes: 30)),
      'GMT+05:30',
    );
    expect(
      xiaomiTimeZoneId('NPT', const Duration(hours: 5, minutes: 45)),
      'GMT+05:45',
    );
    expect(
      xiaomiTimeZoneId('Asia/Shanghai', const Duration(hours: 8)),
      'Asia/Shanghai',
    );
  });
}

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
