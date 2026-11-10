import 'package:oronbox/src/core/logging/logging_service.dart';
import 'package:oronbox/src/device/core/event_bus.dart';
import 'package:oronbox/src/device/xiaomi/systems/xiaomi_system.dart';
import 'package:oronbox/src/device/xiaomi/protocol/generated/wear.pb.dart' as pb;
import 'package:oronbox/src/device/xiaomi/protocol/generated/wear_system.pb.dart'
    as pb_system;

class XiaomiWifiConfigHandler extends XiaomiPbSystem {
  static final _log = getLogger('XiaomiWifiConfigHandler');

  @override
  void onWearPacket(pb.WearPacket packet) {
    if (packet.type != pb.WearPacket_Type.SYSTEM ||
        packet.id != pb_system.System_SystemID.REQUEST_WIFI_CONFIG.value ||
        packet.whichPayload() != pb.WearPacket_Payload.system ||
        packet.system.whichPayload() !=
            pb_system.System_Payload.wifiBasicInfo) {
      return;
    }

    final basicInfo = packet.system.wifiBasicInfo;
    final ssid = basicInfo.ssid;
    final authMode = basicInfo.authMode.value;
    final frequency = basicInfo.frequency.value;
    if (ssid.trim().isEmpty ||
        pb_system.WiFiConfig_AuthMode.valueOf(authMode) == null ||
        pb_system.WiFiConfig_Frequency.valueOf(frequency) == null) {
      _log.warning('[${entity.id}] invalid Wi-Fi credential request');
      return;
    }

    _log.info(
      '[${entity.id}] Wi-Fi password requested: ssid=$ssid, '
      'authMode=$authMode, frequency=$frequency',
    );
    entity.emit(
      XiaomiWifiPasswordRequested(
        deviceId: entity.id,
        ssid: ssid,
        authMode: authMode,
        frequency: frequency,
      ),
    );
  }

  Future<void> sendWifiConfig({
    required String ssid,
    required int authMode,
    required int frequency,
    required String password,
    String identity = '',
  }) async {
    await component.sendPbPacket(
      buildXiaomiWifiConfigPacket(
        ssid: ssid,
        authMode: authMode,
        frequency: frequency,
        password: password,
        identity: identity,
      ),
      waitForAck: true,
    );
  }
}

/// Builds the exact SYSTEM/56 payload used by Mi Fitness' addWifiConfig().
pb.WearPacket buildXiaomiWifiConfigPacket({
  required String ssid,
  required int authMode,
  required int frequency,
  required String password,
  String identity = '',
}) {
  final mode = pb_system.WiFiConfig_AuthMode.valueOf(authMode);
  final band = pb_system.WiFiConfig_Frequency.valueOf(frequency);
  if (ssid.trim().isEmpty) {
    throw ArgumentError.value(ssid, 'ssid', 'SSID must not be empty');
  }
  if (mode == null) {
    throw ArgumentError.value(authMode, 'authMode', 'Unsupported auth mode');
  }
  if (band == null) {
    throw ArgumentError.value(frequency, 'frequency', 'Unsupported frequency');
  }
  if (password.isEmpty) {
    throw ArgumentError.value(
      password,
      'password',
      'Password must not be empty',
    );
  }
  if (mode == pb_system.WiFiConfig_AuthMode.WPA_EAP &&
      identity.trim().isEmpty) {
    throw ArgumentError.value(
      identity,
      'identity',
      'Identity must not be empty',
    );
  }

  final basicInfo = pb_system.WiFiConfig_BasicInfo(
    ssid: ssid,
    authMode: mode,
    frequency: band,
  );
  final wifiConfig = pb_system.WiFiConfig(basicInfo: basicInfo);
  switch (mode) {
    case pb_system.WiFiConfig_AuthMode.WPA_NONE:
      break;
    case pb_system.WiFiConfig_AuthMode.WPA_PSK:
      wifiConfig.pskInfo = pb_system.WiFiConfig_PSKInfo(password: password);
    case pb_system.WiFiConfig_AuthMode.WPA_EAP:
      wifiConfig.eapInfo = pb_system.WiFiConfig_EAPInfo(
        identity: identity.trim(),
        password: password,
      );
  }

  return pb.WearPacket(
    type: pb.WearPacket_Type.SYSTEM,
    id: pb_system.System_SystemID.ADD_WIFI_CONFIG.value,
    system: pb_system.System(wifiConfig: wifiConfig),
  );
}
