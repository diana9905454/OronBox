import 'dart:async';
import 'dart:typed_data';

import 'zeppos_app_side_storage_stub.dart'
    if (dart.library.io) 'zeppos_app_side_storage_io.dart';

abstract interface class ZeppOsAppSideStorage {
  factory ZeppOsAppSideStorage() => createZeppOsAppSideStorage();

  Future<void> save(int appId, Uint8List source);
  Future<void> saveSetting(
    int appId,
    Uint8List source, {
    Map<String, Uint8List> assets = const {},
    String? appName,
  });
  Future<String?> read(int appId);
  Future<String?> readSetting(int appId);
  Future<Map<String, Uint8List>> readSettingAssets(int appId);
  Future<String?> readAppName(int appId);
  Future<Map<String, String>> readSettings(int appId);
  Future<void> writeSettings(int appId, Map<String, String> values);
  Future<List<int>> listAppIds();
  Future<bool> exists(int appId);
  Future<bool> settingExists(int appId);
}

abstract final class ZeppOsLocalDataGuard {
  static bool active = false;
}

class ZeppOsSettingsChange {
  const ZeppOsSettingsChange(this.appId, this.values, this.origin);

  final int appId;
  final Map<String, String> values;
  final Object? origin;
}

class ZeppOsSettingsCoordinator {
  ZeppOsSettingsCoordinator._();

  static final instance = ZeppOsSettingsCoordinator._();
  final _storage = ZeppOsAppSideStorage();
  final _changes = StreamController<ZeppOsSettingsChange>.broadcast();
  final _queues = <int, Future<void>>{};

  Stream<ZeppOsSettingsChange> changesFor(int appId) =>
      _changes.stream.where((change) => change.appId == appId);

  Future<void> settle() async => Future.wait(_queues.values.toList());

  Future<Map<String, String>> read(int appId) => _storage.readSettings(appId);

  Future<void> set(int appId, String key, String value, {Object? origin}) =>
      mutate(appId, (values) => values[key] = value, origin: origin);

  Future<void> remove(int appId, String key, {Object? origin}) =>
      mutate(appId, (values) => values.remove(key), origin: origin);

  Future<void> clear(int appId, {Object? origin}) =>
      mutate(appId, (values) => values.clear(), origin: origin);

  Future<void> replace(
    int appId,
    Map<String, String> values, {
    Object? origin,
  }) => mutate(appId, (current) {
    current
      ..clear()
      ..addAll(values);
  }, origin: origin);

  Future<void> mutate(
    int appId,
    void Function(Map<String, String> values) update, {
    Object? origin,
  }) {
    if (ZeppOsLocalDataGuard.active) {
      throw StateError('Data maintenance is active');
    }
    final previous = _queues[appId] ?? Future.value();
    final operation = previous.then((_) async {
      final values = await _storage.readSettings(appId);
      update(values);
      await _storage.writeSettings(appId, values);
      _changes.add(
        ZeppOsSettingsChange(appId, Map.unmodifiable(values), origin),
      );
    });
    _queues[appId] = operation.whenComplete(() {
      if (identical(_queues[appId], operation)) _queues.remove(appId);
    });
    return operation;
  }
}
