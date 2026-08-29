import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/core/services/ble_gatt_driver.dart';
import 'package:oronbox/src/core/services/default_bluetooth_platform.dart';
import 'package:oronbox/src/core/services/rfcomm_driver.dart';
import 'package:oronbox/src/device/core/bluetooth_platform.dart';

void main() {
  test('requests native RFCOMM permission before BLE permission', () async {
    final calls = <String>[];
    final platform = DefaultBluetoothPlatform(
      _FakeBleGattDriver(calls),
      _FakeRfcommDriver(calls),
    );

    await platform.requestPermissions();

    expect(calls, ['rfcomm', 'ble']);
    await platform.dispose();
  });
}

class _FakeBleGattDriver extends BleGattDriver {
  _FakeBleGattDriver(this.calls);

  final List<String> calls;

  @override
  Stream<BluetoothEndpoint> get scanStream => const Stream.empty();

  @override
  Future<void> requestPermissions() async {
    calls.add('ble');
  }
}

class _FakeRfcommDriver implements RfcommDriver {
  _FakeRfcommDriver(this.calls);

  final List<String> calls;

  @override
  Stream<BluetoothEndpoint> get scanStream => const Stream.empty();

  @override
  Future<void> requestPermissions() async {
    calls.add('rfcomm');
  }

  @override
  Future<RfcommConnection> connect(
    String deviceId,
    String deviceName, {
    String? serviceUuid,
    List<int> fallbackChannels = const [5, 1],
    bool removeBond = false,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> send(Uint8List data) async {}

  @override
  Future<void> startScan({
    Duration timeout = const Duration(seconds: 15),
  }) async {}

  @override
  Future<List<BluetoothEndpoint>> stopScan() async => const [];
}
