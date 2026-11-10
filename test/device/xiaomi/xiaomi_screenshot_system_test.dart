import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/device/core/entity.dart';
import 'package:oronbox/src/device/core/event_bus.dart';
import 'package:oronbox/src/device/core/transport.dart';
import 'package:oronbox/src/device/xiaomi/systems/screenshot_system.dart';
import 'package:oronbox/src/device/xiaomi/systems/xiaomi_device_component.dart';
import 'package:oronbox/src/device/xiaomi/protocol/packet/l2_packet.dart';
import 'package:oronbox/src/device/xiaomi/protocol/packet/spp_v1_packet.dart';

void main() {
  test('registers the screenshot capability before wearable capture', () async {
    final transport = _FakeTransport();
    final entity = DeviceEntity(
      id: 'test-device',
      kind: 'xiaomi',
      transport: transport,
      eventBus: DeviceEventBus(),
    );
    final component = XiaomiDeviceComponent(transport: transport, sppV1: true);
    final system = XiaomiScreenshotSystem();
    entity.set(component);
    entity.registerSystem(system);

    await system.negotiateAfterAuthentication();

    final codec = XiaomiSppV1Codec();
    final packets = <XiaomiSppV1Packet>[];
    for (final write in transport.writes) {
      packets.addAll(codec.add(write));
    }
    expect(packets, hasLength(2));
    expect(packets[0].channel, XiaomiSppV1Channel.protobuf);
    expect(packets[0].dataType, XiaomiSppV1Packet.plain);
    expect(packets[0].payload, [
      0x08,
      0x01,
      0x10,
      0x1f,
      0x1a,
      0x08,
      0xaa,
      0x02,
      0x05,
      0x08,
      0x80,
      0x80,
      0x80,
      0x08,
    ]);
    expect(packets[1].channel, XiaomiSppV1Channel.protobuf);
    expect(packets[1].dataType, XiaomiSppV1Packet.plain);
    expect(packets[1].payload, [0x08, 0x02, 0x10, 0x6c]);

    await entity.dispose();
  });

  test('reassembles Xiaomi screenshot segments and validates CRC', () async {
    final transport = _FakeTransport();
    final eventBus = DeviceEventBus();
    final entity = DeviceEntity(
      id: 'test-device',
      kind: 'xiaomi',
      transport: transport,
      eventBus: eventBus,
    );
    final component = XiaomiDeviceComponent(transport: transport, sppV1: true);
    final system = XiaomiScreenshotSystem();
    entity.set(component);
    entity.registerSystem(system);

    final screenshotEvent = eventBus.stream
        .where((event) => event is XiaomiScreenshotReceived)
        .cast<XiaomiScreenshotReceived>()
        .first;
    final image = Uint8List.fromList(const [
      0x89,
      0x50,
      0x4e,
      0x47,
      0x0d,
      0x0a,
      0x1a,
      0x0a,
    ]);
    final content = Uint8List.fromList([0, ...List.filled(5, 0), ...image]);
    final merged = Uint8List.fromList([
      ...content,
      ..._uint32Le(_crc32(content)),
    ]);
    final split = merged.length ~/ 2;
    system.onLayer2Packet(
      L2Channel.mass,
      L2OpCode.write,
      _segment(2, 1, Uint8List.sublistView(merged, 0, split)),
    );
    system.onLayer2Packet(
      L2Channel.mass,
      L2OpCode.write,
      _segment(2, 2, Uint8List.sublistView(merged, split)),
    );

    final event = await screenshotEvent;
    expect(event.bytes, image);
    await entity.dispose();
    eventBus.dispose();
  });

  test('rejects a Xiaomi screenshot with an invalid CRC', () async {
    final transport = _FakeTransport();
    final entity = DeviceEntity(
      id: 'test-device',
      kind: 'xiaomi',
      transport: transport,
      eventBus: DeviceEventBus(),
    );
    final component = XiaomiDeviceComponent(transport: transport, sppV1: true);
    final system = XiaomiScreenshotSystem();
    entity.set(component);
    entity.registerSystem(system);

    final screenshotEvent = entity.eventBus.stream
        .where((event) => event is XiaomiScreenshotReceived)
        .cast<XiaomiScreenshotReceived>()
        .first;
    final content = Uint8List.fromList([
      0,
      ...List.filled(5, 0),
      0x89,
      0x50,
      0x4e,
      0x47,
      0x0d,
      0x0a,
      0x1a,
      0x0a,
    ]);
    final merged = Uint8List.fromList([...content, 0, 0, 0, 0]);
    system.onLayer2Packet(
      L2Channel.mass,
      L2OpCode.write,
      _segment(1, 1, merged),
    );

    await expectLater(
      screenshotEvent.timeout(const Duration(milliseconds: 20)),
      throwsA(isA<TimeoutException>()),
    );
    await entity.dispose();
  });

  test(
    'responds to the current field-74 screenshot permission request',
    () async {
      final transport = _FakeTransport();
      final entity = DeviceEntity(
        id: 'test-device',
        kind: 'xiaomi',
        transport: transport,
        eventBus: DeviceEventBus(),
      );
      final component = XiaomiDeviceComponent(
        transport: transport,
        sppV1: true,
      );
      final system = XiaomiScreenshotSystem();
      entity.set(component);
      entity.registerSystem(system);

      final permission = Uint8List.fromList([
        ..._fieldVarint(1, 2),
        ..._fieldVarint(2, 0),
      ]);
      final permissionList = _fieldBytes(1, permission);
      final systemPayload = _fieldBytes(74, permissionList);
      final packet = Uint8List.fromList([
        ..._fieldVarint(1, 2),
        ..._fieldVarint(2, 112),
        ..._fieldBytes(4, systemPayload),
      ]);

      system.onLayer2Packet(L2Channel.pb, L2OpCode.write, packet);
      await Future<void>.delayed(Duration.zero);

      expect(transport.writes, hasLength(1));
      await entity.dispose();
    },
  );

  test(
    'accepts a device-initiated screenshot after granting permission',
    () async {
      final transport = _FakeTransport();
      final eventBus = DeviceEventBus();
      final entity = DeviceEntity(
        id: 'test-device',
        kind: 'xiaomi',
        transport: transport,
        eventBus: eventBus,
      );
      final component = XiaomiDeviceComponent(
        transport: transport,
        sppV1: true,
      );
      final system = XiaomiScreenshotSystem();
      entity.set(component);
      entity.registerSystem(system);

      final screenshotEvent = eventBus.stream
          .where((event) => event is XiaomiScreenshotReceived)
          .cast<XiaomiScreenshotReceived>()
          .first;
      final permission = Uint8List.fromList([
        ..._fieldVarint(1, 2),
        ..._fieldVarint(2, 0),
      ]);
      final permissionList = _fieldBytes(1, permission);
      final systemPayload = _fieldBytes(74, permissionList);
      final packet = Uint8List.fromList([
        ..._fieldVarint(1, 2),
        ..._fieldVarint(2, 112),
        ..._fieldBytes(4, systemPayload),
      ]);

      system.onLayer2Packet(L2Channel.pb, L2OpCode.write, packet);
      await Future<void>.delayed(Duration.zero);

      final image = Uint8List.fromList(const [
        0x89,
        0x50,
        0x4e,
        0x47,
        0x0d,
        0x0a,
        0x1a,
        0x0a,
      ]);
      final content = Uint8List.fromList([0, ...List.filled(5, 0), ...image]);
      final merged = Uint8List.fromList([
        ...content,
        ..._uint32Le(_crc32(content)),
      ]);
      system.onLayer2Packet(
        L2Channel.mass,
        L2OpCode.write,
        _segment(1, 1, merged),
      );

      expect(await screenshotEvent, isA<XiaomiScreenshotReceived>());
      expect(transport.writes, hasLength(1));
      await entity.dispose();
      eventBus.dispose();
    },
  );

  test(
    'keeps a screenshot transfer alive when a segment is retransmitted',
    () async {
      final transport = _FakeTransport();
      final eventBus = DeviceEventBus();
      final entity = DeviceEntity(
        id: 'test-device',
        kind: 'xiaomi',
        transport: transport,
        eventBus: eventBus,
      );
      final component = XiaomiDeviceComponent(
        transport: transport,
        sppV1: true,
      );
      final system = XiaomiScreenshotSystem();
      entity.set(component);
      entity.registerSystem(system);

      final screenshotEvent = eventBus.stream
          .where((event) => event is XiaomiScreenshotReceived)
          .cast<XiaomiScreenshotReceived>()
          .first;
      final permission = Uint8List.fromList([
        ..._fieldVarint(1, 2),
        ..._fieldVarint(2, 0),
      ]);
      final packet = Uint8List.fromList([
        ..._fieldVarint(1, 2),
        ..._fieldVarint(2, 112),
        ..._fieldBytes(4, _fieldBytes(74, _fieldBytes(1, permission))),
      ]);
      system.onLayer2Packet(L2Channel.pb, L2OpCode.write, packet);
      await Future<void>.delayed(Duration.zero);

      final image = Uint8List.fromList(const [
        0x89,
        0x50,
        0x4e,
        0x47,
        0x0d,
        0x0a,
        0x1a,
        0x0a,
      ]);
      final content = Uint8List.fromList([0, ...List.filled(5, 0), ...image]);
      final merged = Uint8List.fromList([
        ...content,
        ..._uint32Le(_crc32(content)),
      ]);
      final split = merged.length ~/ 2;
      final first = _segment(2, 1, Uint8List.sublistView(merged, 0, split));
      system.onLayer2Packet(L2Channel.mass, L2OpCode.write, first);
      system.onLayer2Packet(L2Channel.mass, L2OpCode.write, first);
      system.onLayer2Packet(
        L2Channel.mass,
        L2OpCode.write,
        _segment(2, 2, Uint8List.sublistView(merged, split)),
      );

      expect((await screenshotEvent).bytes, image);
      await entity.dispose();
      eventBus.dispose();
    },
  );
}

Uint8List _segment(int total, int sequence, Uint8List payload) =>
    Uint8List.fromList([
      0,
      133,
      total & 0xff,
      (total >> 8) & 0xff,
      sequence & 0xff,
      (sequence >> 8) & 0xff,
      ...payload,
    ]);

List<int> _uint32Le(int value) => [
  value & 0xff,
  (value >> 8) & 0xff,
  (value >> 16) & 0xff,
  (value >> 24) & 0xff,
];

int _crc32(List<int> bytes) {
  var crc = 0xffffffff;
  for (final byte in bytes) {
    crc ^= byte;
    for (var bit = 0; bit < 8; bit++) {
      crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xedb88320 : crc >> 1;
    }
  }
  return (crc ^ 0xffffffff) & 0xffffffff;
}

List<int> _fieldVarint(int number, int value) => [
  ..._encodeVarint((number << 3) | 0),
  ..._encodeVarint(value),
];

List<int> _fieldBytes(int number, List<int> value) => [
  ..._encodeVarint((number << 3) | 2),
  ..._encodeVarint(value.length),
  ...value,
];

List<int> _encodeVarint(int value) {
  final bytes = <int>[];
  var remaining = value;
  do {
    var byte = remaining & 0x7f;
    remaining >>= 7;
    if (remaining != 0) byte |= 0x80;
    bytes.add(byte);
  } while (remaining != 0);
  return bytes;
}

class _FakeTransport implements Transport {
  final writes = <Uint8List>[];

  @override
  String get deviceId => 'test-device';

  @override
  String get deviceName => 'Test Xiaomi';

  @override
  Stream<Uint8List> get incomingData => const Stream.empty();

  @override
  Stream<bool> get connectionState => const Stream.empty();

  @override
  Future<void> send(Uint8List data) async {
    writes.add(Uint8List.fromList(data));
  }

  @override
  Future<void> dispose() async {}
}
