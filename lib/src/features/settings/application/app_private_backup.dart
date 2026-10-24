import 'dart:convert';

import 'package:oronbox/src/core/models/bt_models.dart';
import 'package:oronbox/src/core/services/private_app_state.dart';
import 'package:oronbox/src/features/accounts/models/mi_account_models.dart';

/// An explicit allowlist: OronBox, BandBBS and other account stores are never read.
class AppPrivateBackupStore {
  AppPrivateBackupStore({PrivateAppState? state})
    : state = state ?? PrivateAppState.instance;
  final PrivateAppState state;
  Future<Map<String, Object?>> export({
    bool devices = false,
    bool xiaomi = false,
  }) async {
    final result = <String, Object?>{};
    if (devices) {
      await state.reload(key: PrivateAppState.pairedDevices);
      try {
        result['devices'] =
            (state.readStringList(PrivateAppState.pairedDevices) ?? <String>[])
                .map(
                  (raw) => jsonEncode(
                    MiWearState.fromJson(
                      (jsonDecode(raw) as Map).cast<String, dynamic>(),
                    ).copyWith(disconnected: true).toJson(),
                  ),
                )
                .toList();
      } catch (_) {
        throw const PrivateStateException('private_state_read_failed');
      }
    }
    if (xiaomi) {
      await state.reload(key: PrivateAppState.miToken);
      result['xiaomi'] = state.readString(PrivateAppState.miToken);
    }
    validatePrivateBackup(result);
    return result;
  }

  Future<void> restore(Map<String, Object?> data) async {
    validatePrivateBackup(data);
    if (data.containsKey('devices')) {
      await state.update({
        PrivateAppState.pairedDevices: List<String>.from(
          data['devices']! as List,
        ),
      });
    }
    if (data.containsKey('xiaomi')) {
      await state.update({PrivateAppState.miToken: data['xiaomi']});
    }
  }

  Future<void> stageRecovery(Map<String, Object?> before) async {
    validatePrivateBackup(before);
    await state.writeBackupRecovery(jsonEncode(before));
  }

  Future<void> recover() async {
    final raw = await state.readBackupRecovery();
    if (raw == null) throw StateError('Private backup recovery is missing');
    await restore(decodePrivateBackup(utf8.encode(raw)));
  }

  Future<void> clearRecovery() => state.writeBackupRecovery(null);
}

Map<String, Object?> decodePrivateBackup(List<int> bytes) {
  try {
    final data = (jsonDecode(utf8.decode(bytes)) as Map)
        .cast<String, Object?>();
    validatePrivateBackup(data);
    return data;
  } catch (_) {
    throw const FormatException('Invalid private backup records');
  }
}

void validatePrivateBackup(Map<String, Object?> data) {
  try {
    _validatePrivateBackup(data);
  } catch (_) {
    throw const FormatException('Invalid private backup records');
  }
}

void _validatePrivateBackup(Map<String, Object?> data) {
  if (data.keys.any((key) => key != 'devices' && key != 'xiaomi')) {
    throw const FormatException('Invalid private backup category');
  }
  if (data.containsKey('devices')) {
    final rows = data['devices'];
    if (rows is! List || rows.length > 1000) {
      throw const FormatException('Invalid paired devices');
    }
    final seen = <String>{};
    for (final raw in rows) {
      if (raw is! String || raw.length > 8192) {
        throw const FormatException('Invalid paired device');
      }
      final json = (jsonDecode(raw) as Map).cast<String, dynamic>();
      if (json.keys.any(
        (key) => !const [
          'name',
          'addr',
          'connectType',
          'authkey',
          'codename',
          'disconnected',
        ].contains(key),
      )) {
        throw const FormatException('Invalid paired device fields');
      }
      final device = MiWearState.fromJson(json);
      if (device.addr.isEmpty ||
          device.name.isEmpty ||
          !seen.add(device.addr.toUpperCase())) {
        throw const FormatException('Invalid paired device identity');
      }
    }
  }
  if (data['xiaomi'] case final Object raw) {
    if (raw is! String || raw.length > 65536) {
      throw const FormatException('Invalid Xiaomi session');
    }
    final json = (jsonDecode(raw) as Map).cast<String, Object?>();
    if (json.keys.any(
          (key) => !const [
            'user_id',
            'device_id',
            'ssecurity',
            'service_token',
            'c_user_id',
            'pass_token',
            'psecurity',
          ].contains(key),
        ) ||
        json.values.any((value) => value is! String) ||
        MiAccountToken.fromJson(json) == null) {
      throw const FormatException('Invalid Xiaomi session');
    }
  }
}
