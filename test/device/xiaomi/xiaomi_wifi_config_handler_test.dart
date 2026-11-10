import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/device/core/entity.dart';
import 'package:oronbox/src/device/core/event_bus.dart';
import 'package:oronbox/src/device/core/transport.dart';
import 'package:oronbox/src/device/xiaomi/systems/wifi_config_handler.dart';
import 'package:oronbox/src/device/xiaomi/protocol/generated/wear.pb.dart' as pb;
import 'package:oronbox/src/device/xiaomi/protocol/generated/wear_system.pb.dart'
    as pb_system;

void main() {
  test('emits a password request for SYSTEM/55 basic Wi-Fi info', () async {
    final eventBus = DeviceEventBus();
    final entity = DeviceEntity(
      id: 'device-a',
      kind: 'xiaomi',
      transport: _UnusedTransport(),
      eventBus: eventBus,
    );
    final system = XiaomiWifiConfigHandler();
    entity.registerSystem(system);
    final event = eventBus.stream
        .where((value) => value is XiaomiWifiPasswordRequested)
        .cast<XiaomiWifiPasswordRequested>()
        .first;

    system.onWearPacket(
      pb.WearPacket.fromBuffer(const [
        0x08,
        0x02,
        0x10,
        0x37,
        0x22,
        0x12,
        0xfa,
        0x01,
        0x0f,
        0x0a,
        0x09,
        0x43,
        0x4d,
        0x43,
        0x43,
        0x2d,
        0x32,
        0x41,
        0x43,
        0x47,
        0x10,
        0x02,
        0x18,
        0x02,
      ]),
    );

    final request = await event;
    expect(request.deviceId, 'device-a');
    expect(request.ssid, 'CMCC-2ACG');
    expect(request.authMode, pb_system.WiFiConfig_AuthMode.WPA_PSK.value);
    expect(request.frequency, pb_system.WiFiConfig_Frequency.F_5G.value);

    await entity.dispose();
    eventBus.dispose();
  });

  test('builds the MiFitness-compatible PSK response packet', () {
    final packet = buildXiaomiWifiConfigPacket(
      ssid: 'CMCC-2ACG',
      authMode: pb_system.WiFiConfig_AuthMode.WPA_PSK.value,
      frequency: pb_system.WiFiConfig_Frequency.F_5G.value,
      password: 'secret-password',
    );

    expect(packet.type, pb.WearPacket_Type.SYSTEM);
    expect(packet.id, pb_system.System_SystemID.ADD_WIFI_CONFIG.value);
    expect(packet.system.wifiConfig.basicInfo.ssid, 'CMCC-2ACG');
    expect(
      packet.system.wifiConfig.basicInfo.authMode,
      pb_system.WiFiConfig_AuthMode.WPA_PSK,
    );
    expect(
      packet.system.wifiConfig.basicInfo.frequency,
      pb_system.WiFiConfig_Frequency.F_5G,
    );
    expect(
      packet.system.wifiConfig.whichAuthInfo(),
      pb_system.WiFiConfig_AuthInfo.pskInfo,
    );
    expect(packet.system.wifiConfig.pskInfo.password, 'secret-password');
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
