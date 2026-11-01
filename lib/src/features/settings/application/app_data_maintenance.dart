import 'dart:async';

import 'package:uuid/uuid.dart';
import 'package:oronbox/src/commands/command_protocol.dart';
import 'package:oronbox/src/features/devices/health/health_store.dart';
import 'package:oronbox/src/core/storage/app_data_directory.dart';
import 'package:oronbox/src/device/core/device_state.dart'
    show ProtocolException;
import 'package:oronbox/src/device/zeppos/app_side/zeppos_app_side_storage.dart';
import 'package:oronbox/src/features/devices/controllers/device_manager.dart';

/// Stops writers while another engine snapshots or restores local app data.
class AppDataMaintenance {
  AppDataMaintenance({
    required this.deviceManager,
    required this.initialize,
    required this.stopRuntimes,
    required this.reload,
  });
  final DeviceManager deviceManager;
  final Future<void> Function() initialize, stopRuntimes, reload;
  String? _token;
  DateTime? _grantedAt;
  bool _beginning = false;
  bool owns(String token) => _token == token;
  final _calls = <Future<void>>{};
  bool get active => _token != null;

  Future<T> hostCall<T>(Future<T> Function() action) async {
    if (active) throw StateError('Data maintenance is active');
    final completion = Completer<void>();
    _calls.add(completion.future);
    try {
      return await action();
    } finally {
      completion.complete();
      _calls.remove(completion.future);
    }
  }

  Future<String> begin() async {
    await initialize();
    if (active) {
      if (_beginning ||
          DateTime.now().difference(_grantedAt!) < const Duration(seconds: 5)) {
        throw StateError('Data maintenance is active');
      }
      final previous = await openAppDataDirectory(
        'storage/maintenance/app-data',
      );
      if (!await previous.tryExclusive(() async {})) {
        throw StateError('Data maintenance is active');
      }
    }
    final token = const Uuid().v4();
    _token = token;
    _grantedAt = DateTime.now();
    _beginning = true;
    ZeppOsLocalDataGuard.active = true;
    try {
      await stopRuntimes();
      List<int> appIds;
      try {
        appIds = (await deviceManager.zeppOsAppSideSessions())
            .map((session) => session.appId)
            .toList();
      } on UnsupportedError {
        appIds = [];
      } on ProtocolException {
        appIds = [];
      }
      for (final id in appIds) {
        await deviceManager.stopZeppOsAppSide(id);
      }
      await Future.wait(_calls.toList()).timeout(const Duration(seconds: 15));
      await ZeppOsSettingsCoordinator.instance.settle();
      await HealthStore.pauseForOwner(token, deviceManager.waitForHealthSync);
      _grantedAt = DateTime.now();
      return token;
    } catch (_) {
      HealthStore.resumeForOwner(token);
      _token = null;
      ZeppOsLocalDataGuard.active = false;
      rethrow;
    } finally {
      _beginning = false;
    }
  }

  Future<void> end(String token) async {
    if (token != _token) throw StateError('Invalid data maintenance owner');
    try {
      await deviceManager.reloadSavedDevices();
      await reload();
    } finally {
      HealthStore.resumeForOwner(token);
      _token = null;
      ZeppOsLocalDataGuard.active = false;
    }
  }
}

/// Acquires host data maintenance, runs [action] under exclusive lock, then releases it.
Future<T> runWithAppDataMaintenance<T>(
  OronBoxCommandBus host,
  Future<T> Function() action,
) async {
  final acquired = await host.execute(
    const OronBoxCommand(method: 'appdata.maintenance.begin'),
  );
  if (!acquired.ok || acquired.value is! String) {
    throw StateError('Unable to acquire data maintenance');
  }
  final token = acquired.value as String;
  var ended = false;
  Future<void> end() async {
    ended = true;
    final released = await host.execute(
      OronBoxCommand(
        method: 'appdata.maintenance.end',
        params: {'token': token},
      ),
    );
    if (!released.ok) {
      throw StateError('Unable to release data maintenance');
    }
  }

  try {
    final lease = await openAppDataDirectory('storage/maintenance/app-data');
    return await lease.exclusive(() async {
      final valid = await host.execute(
        OronBoxCommand(
          method: 'appdata.maintenance.validate',
          params: {'token': token},
        ),
      );
      if (!valid.ok || valid.value != true) {
        throw StateError('Data maintenance ownership changed');
      }
      try {
        return await action();
      } finally {
        await end();
      }
    });
  } finally {
    if (!ended) await end();
  }
}
