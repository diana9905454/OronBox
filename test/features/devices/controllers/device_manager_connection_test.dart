import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:oronbox/src/core/services/private_app_state.dart';
import 'package:oronbox/src/core/storage/app_data_directory_io.dart';

import 'dart:convert';

import 'package:oronbox/src/core/models/bt_models.dart';
import 'package:oronbox/src/features/accounts/models/mi_account_models.dart';

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/core/providers/bluetooth_platform_provider.dart';
import 'package:oronbox/src/core/services/shared_prefs_service.dart';
import 'package:oronbox/src/device/core/bluetooth_platform.dart';
import 'package:oronbox/src/device/core/connect_type.dart';
import 'package:oronbox/src/features/devices/controllers/device_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPrefsService.instance.init();
    await SharedPrefsService.instance.reload();
    FlutterSecureStorage.setMockInitialValues({});
    final root = await Directory.systemTemp.createTemp('oronbox-paired-test-');
    PrivateAppState.instanceForTesting = PrivateAppState(
      lock: IoAppDataDirectory(root),
    );
    await PrivateAppState.instance.initialize();
    addTearDown(() async {
      PrivateAppState.instanceForTesting = null;
      await root.delete(recursive: true);
    });
  });

  for (final address in [
    'AA:BB:CC:DD:EE:FF',
    'aa:bb:cc:dd:ee:ff',
    'aa-bb-cc-dd-ee-ff',
  ]) {
    test(
      'cloud import refreshes persisted and selected credentials for $address',
      () async {
        final container = ProviderContainer(
          overrides: [
            bluetoothPlatformProvider.overrideWithValue(
              _BlockingBluetoothPlatform(),
            ),
          ],
        );
        addTearDown(container.dispose);
        final manager = container.read(deviceManagerProvider.notifier);
        await manager.importSharedDevice(
          MiWearState(
            name: 'Xiaomi Watch S5',
            addr: address,
            connectType: 'spp',
            authkey: '11111111111111111111111111111111',
          ),
        );
        final imported = await manager.importMiCloudDevices(const [
          MiCloudDevice(
            name: 'Xiaomi Watch S5',
            model: 'miwear.watch.p62',
            mac: 'AA:BB:CC:DD:EE:FF',
            authKey: '22222222222222222222222222222222',
            firmwareVersion: '',
            serialNumber: '',
          ),
        ]);
        expect(imported, 1);
        final state = container.read(deviceManagerProvider);
        expect(state.pairedDevices, hasLength(1));
        expect(
          state.pairedDevices.single.authkey,
          '22222222222222222222222222222222',
        );
        expect(
          state.currentDevice?.authkey,
          '22222222222222222222222222222222',
        );
        final saved = PrivateAppState.instance.readStringList(
          'paired_devices',
        )!;
        expect(saved, hasLength(1));
        expect(
          (jsonDecode(saved.single) as Map)['authkey'],
          '22222222222222222222222222222222',
        );
      },
    );
  }

  test(
    'cloud import repairs duplicate MAC records and preserves the endpoint',
    () async {
      final container = ProviderContainer(
        overrides: [
          deviceManagerProvider.overrideWith(_LegacyPairedDeviceManager.new),
          bluetoothPlatformProvider.overrideWithValue(
            _BlockingBluetoothPlatform(),
          ),
        ],
      );
      addTearDown(container.dispose);
      final manager = container.read(deviceManagerProvider.notifier);
      expect(container.read(deviceManagerProvider).pairedDevices, hasLength(2));
      await manager.importMiCloudDevices(const [
        MiCloudDevice(
          name: 'Xiaomi Watch S5',
          model: 'miwear.watch.p62',
          mac: 'AA:BB:CC:DD:EE:FF',
          authKey: '22222222222222222222222222222222',
          firmwareVersion: '',
          serialNumber: '',
        ),
      ]);
      final state = container.read(deviceManagerProvider);
      expect(state.pairedDevices, hasLength(1));
      expect(state.currentDevice?.addr, 'aa-bb-cc-dd-ee-ff');
      expect(state.currentDevice?.connectType, 'ble');
      expect(state.currentDevice?.authkey, '22222222222222222222222222222222');
    },
  );

  test(
    'refreshing another device preserves selection and ignores empty keys',
    () async {
      final container = ProviderContainer(
        overrides: [
          bluetoothPlatformProvider.overrideWithValue(
            _BlockingBluetoothPlatform(),
          ),
        ],
      );
      addTearDown(container.dispose);
      final manager = container.read(deviceManagerProvider.notifier);
      await manager.importSharedDevice(
        const MiWearState(
          name: 'Xiaomi Watch S5',
          addr: '11:22:33:44:55:66',
          connectType: 'spp',
          authkey: '33333333333333333333333333333333',
        ),
      );
      await manager.importSharedDevice(
        const MiWearState(
          name: 'Xiaomi Watch S5',
          addr: 'aa:bb:cc:dd:ee:ff',
          connectType: 'spp',
          authkey: '11111111111111111111111111111111',
        ),
      );
      final count = await manager.importMiCloudDevices(const [
        MiCloudDevice(
          name: 'Xiaomi Watch S5',
          model: 'miwear.watch.p62',
          mac: 'AA:BB:CC:DD:EE:FF',
          authKey: '22222222222222222222222222222222',
          firmwareVersion: '',
          serialNumber: '',
        ),
        MiCloudDevice(
          name: 'Xiaomi Watch S5',
          model: 'miwear.watch.p62',
          mac: '11:22:33:44:55:66',
          authKey: '',
          firmwareVersion: '',
          serialNumber: '',
        ),
      ]);
      final state = container.read(deviceManagerProvider);
      expect(count, 1);
      expect(state.pairedDevices, hasLength(2));
      expect(state.currentDevice?.addr, '11:22:33:44:55:66');
      expect(state.currentDevice?.authkey, '33333333333333333333333333333333');
      expect(
        state.pairedDevices.last.authkey,
        '22222222222222222222222222222222',
      );
    },
  );

  test(
    'shared device import updates the existing MAC without losing transport',
    () async {
      final container = ProviderContainer(
        overrides: [
          bluetoothPlatformProvider.overrideWithValue(
            _BlockingBluetoothPlatform(),
          ),
        ],
      );
      addTearDown(container.dispose);
      final manager = container.read(deviceManagerProvider.notifier);
      await manager.importSharedDevice(
        const MiWearState(
          name: 'Xiaomi Watch S5',
          addr: 'aa-bb-cc-dd-ee-ff',
          connectType: 'ble',
          authkey: '11111111111111111111111111111111',
        ),
      );
      await manager.importSharedDevice(
        const MiWearState(
          name: 'Xiaomi Watch S5',
          addr: 'AA:BB:CC:DD:EE:FF',
          connectType: 'spp',
          authkey: '22222222222222222222222222222222',
        ),
      );
      var state = container.read(deviceManagerProvider);
      expect(state.pairedDevices, hasLength(1));
      expect(state.currentDevice?.authkey, '22222222222222222222222222222222');
      expect(state.currentDevice?.addr, 'aa-bb-cc-dd-ee-ff');
      expect(state.currentDevice?.connectType, 'ble');
      await manager.importSharedDevice(
        const MiWearState(
          name: 'Xiaomi Watch S5',
          addr: 'AA:BB:CC:DD:EE:FF',
          connectType: 'spp',
          authkey: '',
        ),
      );
      state = container.read(deviceManagerProvider);
      expect(state.pairedDevices, hasLength(1));
      expect(state.currentDevice?.authkey, '22222222222222222222222222222222');
    },
  );

  test(
    'joins an in-flight connection to the same device and transport',
    () async {
      final bluetooth = _BlockingBluetoothPlatform();
      final container = ProviderContainer(
        overrides: [bluetoothPlatformProvider.overrideWithValue(bluetooth)],
      );
      addTearDown(container.dispose);
      final manager = container.read(deviceManagerProvider.notifier);
      addTearDown(() async {
        await manager.cancelConnect();
      });

      final first = manager.connect(
        'AA:BB:CC:DD:EE:FF',
        'Xiaomi Watch S5',
        'test-auth-key',
        connectType: ConnectType.spp.name,
      );
      await _waitFor(() => bluetooth.connectCalls == 1);

      final second = manager.connect(
        'AA:BB:CC:DD:EE:FF',
        'Xiaomi Watch S5',
        'test-auth-key',
        connectType: ConnectType.spp.name,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(second, same(first));
      expect(bluetooth.connectCalls, 1);

      await manager.cancelConnect();
      await Future.wait([first, second]);
    },
  );
}

Future<void> _waitFor(bool Function() condition) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(condition(), isTrue, reason: 'condition did not become true');
}

class _BlockingBluetoothPlatform implements BluetoothPlatform {
  final _pendingConnections = <Completer<BluetoothConnection>>[];
  var connectCalls = 0;

  @override
  Stream<BluetoothEndpoint> get scanStream => const Stream.empty();

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<void> requestPermissions() async {}

  @override
  Future<void> startScan(BluetoothScanOptions options) async {}

  @override
  Future<List<BluetoothEndpoint>> stopScan() async => const [];

  @override
  Future<BluetoothConnection> connect(
    String address,
    String name,
    BluetoothConnectOptions options,
  ) {
    connectCalls++;
    final completer = Completer<BluetoothConnection>();
    _pendingConnections.add(completer);
    return completer.future;
  }

  @override
  Future<void> cancelPendingSppConnection() async {
    for (final pending in _pendingConnections) {
      if (!pending.isCompleted) {
        pending.completeError(StateError('connection cancelled by test'));
      }
    }
  }

  @override
  Future<void> disconnect(String address) async {}

  @override
  Future<void> disconnectAll() async {}
}

class _LegacyPairedDeviceManager extends LocalDeviceManager {
  @override
  DeviceManagerState build() {
    final initial = super.build();
    const devices = [
      MiWearState(
        name: 'Xiaomi Watch S5',
        addr: 'aa-bb-cc-dd-ee-ff',
        connectType: 'ble',
        authkey: '11111111111111111111111111111111',
        disconnected: true,
      ),
      MiWearState(
        name: 'Xiaomi Watch S5',
        addr: 'AA:BB:CC:DD:EE:FF',
        connectType: 'spp',
        authkey: '11111111111111111111111111111111',
        disconnected: true,
      ),
    ];
    return initial.copyWith(
      pairedDevices: devices,
      currentDevice: devices.first,
    );
  }
}
