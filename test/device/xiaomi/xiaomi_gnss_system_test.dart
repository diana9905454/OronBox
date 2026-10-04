import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/device/core/entity.dart';
import 'package:oronbox/src/device/core/event_bus.dart';
import 'package:oronbox/src/device/core/transport.dart';
import 'package:oronbox/src/device/xiaomi/systems/gnss_system.dart';
import 'package:oronbox/src/device/xiaomi/systems/xiaomi_device_component.dart';
import 'package:oronbox/src/device/xiaomi/protocol/generated/wear.pb.dart' as pb_wear;
import 'package:oronbox/src/device/xiaomi/protocol/generated/wear_gnss.pb.dart' as pb;
import 'package:oronbox/src/device/xiaomi/protocol/packet/spp_v1_packet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('accepts an outer days GNSS request and applies AGPS defaults', () {
    final request = XiaomiGnssRequest.fromPayload(
      requestId: pb.Gnss_GnssID.REQUEST_ONLINE.value,
      payload: pb.Gnss(days: 7),
      defaultSource: 'ublox',
    );

    expect(request.online, isTrue);
    expect(request.days, 7);
    expect(request.type, 1);
    expect(request.source, 'ublox');
    expect(request.sourceFromDevice, isFalse);
    expect(request.expectedSliceLength, isNull);
    expect(request.needGpsInfo, isFalse);
  });

  test('prefers nested GNSS data when the device provides it', () {
    final request = XiaomiGnssRequest.fromPayload(
      requestId: pb.Gnss_GnssID.REQUEST_OFFLINE.value,
      payload: pb.Gnss(
        data: pb.Data(
          type: pb.Data_Type.BEIDOU,
          source: 'broadcom',
          days: 3,
          expectedSliceLength: 1024,
          needGpsInfo: true,
        ),
      ),
      defaultSource: 'ublox',
    );

    expect(request.online, isFalse);
    expect(request.days, 3);
    expect(request.type, 2);
    expect(request.source, 'broadcom');
    expect(request.sourceFromDevice, isTrue);
    expect(request.expectedSliceLength, 1024);
    expect(request.needGpsInfo, isTrue);
  });

  test('uses the configured source when nested source is empty', () {
    final request = XiaomiGnssRequest.fromPayload(
      requestId: pb.Gnss_GnssID.REQUEST_OFFLINE.value,
      payload: pb.Gnss(
        data: pb.Data(type: pb.Data_Type.AGPS, source: ''),
      ),
      defaultSource: 'ublox',
    );

    expect(request.source, 'ublox');
    expect(request.sourceFromDevice, isFalse);
  });

  test('emits an account-required event for Xiaomi-hosted ephemeris', () async {
    SharedPreferences.setMockInitialValues({});
    final eventBus = DeviceEventBus();
    final transport = _FakeTransport();
    final entity = DeviceEntity(
      id: 'test-device',
      kind: 'xiaomi',
      transport: transport,
      eventBus: eventBus,
    );
    final component = XiaomiDeviceComponent(transport: transport, sppV1: true);
    final system = XiaomiGnssSystem(defaultSource: 'airoha');
    entity.set(component);
    entity.registerSystem(system);

    final eventFuture = eventBus.stream
        .where((event) => event is XiaomiGnssAccountRequired)
        .cast<XiaomiGnssAccountRequired>()
        .first;
    system.onWearPacket(
      pb_wear.WearPacket(
        type: pb_wear.WearPacket_Type.GNSS,
        id: pb.Gnss_GnssID.REQUEST_ONLINE.value,
        gnss: pb.Gnss(data: pb.Data(source: 'airoha')),
      ),
    );

    final event = await eventFuture.timeout(const Duration(seconds: 1));
    expect(event.deviceId, 'test-device');
    await entity.dispose();
    eventBus.dispose();
  });

  test('calls gpsInfoProvider and sends SEND_GPS_INFO on REQUEST_GPS_INFO', () async {
    SharedPreferences.setMockInitialValues({});
    final eventBus = DeviceEventBus();
    final sentPackets = <pb_wear.WearPacket>[];
    final codec = XiaomiSppV1Codec();
    final transport = _FakeTransport(
      onSend: (data) {
        final sppPackets = codec.add(data);
        for (final spp in sppPackets) {
          if (spp.channel == XiaomiSppV1Channel.protobuf) {
            sentPackets.add(pb_wear.WearPacket.fromBuffer(spp.payload));
          }
        }
      },
    );
    final entity = DeviceEntity(
      id: 'test-device',
      kind: 'xiaomi',
      transport: transport,
      eventBus: eventBus,
    );
    final component = XiaomiDeviceComponent(transport: transport, sppV1: true);

    var providerCalled = false;

    final system = XiaomiGnssSystem(
      gpsInfoProvider: () async {
        providerCalled = true;
        return pb.GpsInfo(
          timestamp: 1727000000,
          latitude: 31.2304,
          longitude: 121.4737,
          altitude: 10.5,
        );
      },
    );

    entity.set(component);
    entity.registerSystem(system);

    system.onWearPacket(
      pb_wear.WearPacket(
        type: pb_wear.WearPacket_Type.GNSS,
        id: pb.Gnss_GnssID.REQUEST_GPS_INFO.value,
      ),
    );

    // Allow the async handler to complete.
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(providerCalled, isTrue,
        reason: 'gpsInfoProvider must be called on REQUEST_GPS_INFO');
    expect(sentPackets, hasLength(1));
    expect(sentPackets.first.id, pb.Gnss_GnssID.SEND_GPS_INFO.value);
    final gpsInfo = sentPackets.first.gnss.gpsInfo;
    expect(gpsInfo.latitude, closeTo(31.2304, 1e-6));
    expect(gpsInfo.longitude, closeTo(121.4737, 1e-6));
    expect(gpsInfo.timestamp, 1727000000);

    await entity.dispose();
    eventBus.dispose();
  });

  test('does not crash when gpsInfoProvider returns null', () async {
    SharedPreferences.setMockInitialValues({});
    final eventBus = DeviceEventBus();
    final transport = _FakeTransport();
    final entity = DeviceEntity(
      id: 'test-device',
      kind: 'xiaomi',
      transport: transport,
      eventBus: eventBus,
    );
    final component = XiaomiDeviceComponent(transport: transport, sppV1: true);

    final system = XiaomiGnssSystem(
      gpsInfoProvider: () async => null,
    );
    entity.set(component);
    entity.registerSystem(system);

    // Should not throw
    system.onWearPacket(
      pb_wear.WearPacket(
        type: pb_wear.WearPacket_Type.GNSS,
        id: pb.Gnss_GnssID.REQUEST_GPS_INFO.value,
      ),
    );

    await Future<void>.delayed(const Duration(milliseconds: 100));
    // No assertion needed beyond no exception being thrown.

    await entity.dispose();
    eventBus.dispose();
  });
}

class _FakeTransport implements Transport {
  _FakeTransport({this.onSend});

  final void Function(Uint8List data)? onSend;

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
    onSend?.call(data);
  }

  @override
  Future<void> dispose() async {}
}
