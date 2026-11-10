import 'dart:async';
import 'dart:typed_data';

import 'package:oronbox/src/device/core/bluetooth_platform.dart';

export 'rfcomm_driver_native.dart'
    if (dart.library.html) 'rfcomm_driver_web.dart';

class SppBondRemovalFailed implements Exception {
  const SppBondRemovalFailed([this.details]);

  final String? details;

  @override
  String toString() => details == null || details!.isEmpty
      ? 'SPP bond removal failed'
      : 'SPP bond removal failed: $details';
}

abstract class RfcommConnection {
  String get deviceId;
  String get deviceName;
  Stream<Uint8List> get incomingData;
  Stream<bool> get connectionState;
  Future<void> send(Uint8List data);
  Future<void> start();
  Future<void> dispose();
}

abstract class RfcommDriver {
  Stream<BluetoothEndpoint> get scanStream;

  Future<void> requestPermissions();
  Future<void> startScan({Duration timeout = const Duration(seconds: 15)});
  Future<List<BluetoothEndpoint>> stopScan();
  Future<RfcommConnection> connect(
    String deviceId,
    String deviceName, {
    String? serviceUuid,
    List<int> fallbackChannels = const [5, 1],
    bool removeBond = false,
  });
  Future<void> send(Uint8List data);
  Future<void> disconnect();
}
