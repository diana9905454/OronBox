import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/features/devices/health/health_store.dart';
import 'package:oronbox/src/features/devices/health/health_models.dart';
import 'package:oronbox/src/device/zeppos/app_side/zeppos_app_side_storage.dart';
import 'package:oronbox/src/device/zeppos/systems/zeppos_app_side_system.dart';
import 'package:oronbox/src/features/devices/controllers/device_manager.dart';
import 'package:oronbox/src/features/settings/application/app_data_maintenance.dart';

class _Device extends Fake implements DeviceManager {
  _Device({this.healthDrain});
  final Future<void> Function()? healthDrain;
  @override
  Future<void> reloadSavedDevices() async {}
  @override
  Future<void> waitForHealthSync() async => healthDrain?.call();
  @override
  Future<List<ZeppOsAppSideSessionInfo>> zeppOsAppSideSessions() async => [];
}

void main() {
  tearDown(() => ZeppOsLocalDataGuard.active = false);
  test('maintenance drains existing writers and rejects new ones until its owner releases it', () async {
    var reloads = 0;
    final stopped = Completer<void>();
    final maintenance = AppDataMaintenance(
      deviceManager: _Device(),
      initialize: () async {},
      stopRuntimes: () async {
        stopped.complete();
      },
      reload: () async {
        reloads++;
      },
    );
    final gate = Completer<void>();
    final writer = maintenance.hostCall(() => gate.future);
    final acquiring = maintenance.begin();
    await stopped.future;
    expect(maintenance.active, isTrue);
    expect(ZeppOsLocalDataGuard.active, isTrue);
    await expectLater(maintenance.hostCall(() async {}), throwsStateError);
    await expectLater(maintenance.end('other-owner'), throwsStateError);
    expect(maintenance.active, isTrue);
    gate.complete();
    await writer;
    final token = await acquiring;
    await maintenance.end(token);
    expect(reloads, 1);
    expect(maintenance.active, isFalse);
    expect(ZeppOsLocalDataGuard.active, isFalse);
    await maintenance.hostCall(() async {});
  });
  test(
    'maintenance waits for health sync and pauses writes until release',
    () async {
      final entered = Completer<void>();
      final drained = Completer<void>();
      final maintenance = AppDataMaintenance(
        deviceManager: _Device(
          healthDrain: () {
            entered.complete();
            return drained.future;
          },
        ),
        initialize: () async {},
        stopRuntimes: () async {},
        reload: () async {},
      );
      var granted = false;
      final acquiring = maintenance.begin().then((token) {
        granted = true;
        return token;
      });
      await entered.future;
      expect(HealthStore.maintenanceRequested, isTrue);
      expect(granted, isFalse);
      drained.complete();
      final token = await acquiring;
      try {
        await expectLater(
          HealthStore().write('device', const XiaomiHealthData()),
          throwsStateError,
        );
      } finally {
        await maintenance.end(token);
      }
      expect(HealthStore.maintenanceRequested, isFalse);
    },
  );
  test(
    'a failed stop releases maintenance and never starts the snapshot',
    () async {
      final maintenance = AppDataMaintenance(
        deviceManager: _Device(),
        initialize: () async {},
        stopRuntimes: () async => throw StateError('stop failed'),
        reload: () async {},
      );
      await expectLater(maintenance.begin(), throwsStateError);
      expect(maintenance.active, isFalse);
      expect(ZeppOsLocalDataGuard.active, isFalse);
    },
  );
}
