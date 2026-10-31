import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:oronbox/src/core/errors/coded_error.dart';
import 'package:oronbox/src/core/storage/app_data_directory.dart';

import 'shared_prefs_service.dart';

class PrivateStateException implements CodedError {
  const PrivateStateException(this.code);
  @override
  final String code;
  @override
  String get message => '';
  @override
  Object? get details => null;
  @override
  String toString() => code;
}

/// Small account and pairing records; bulk data belongs in application files.
class PrivateAppState {
  PrivateAppState({FlutterSecureStorage? secureStorage, AppDataDirectory? lock})
    : _secure =
          secureStorage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(resetOnError: false),
            mOptions: MacOsOptions(usesDataProtectionKeychain: false),
          ),
      _lock = lock == null ? null : Future.value(lock);

  static PrivateAppState _instance = PrivateAppState();
  static PrivateAppState get instance => _instance;
  @visibleForTesting
  static set instanceForTesting(PrivateAppState? value) =>
      _instance = value ?? PrivateAppState();

  static const miToken = 'mi.account.token';
  static const huamiToken = 'huami.account.token';
  static const huamiUsername = 'huami.account.username';
  static const pairedDevices = 'paired_devices';
  static const _groups = {
    'xiaomi': [miToken],
    'huami': [huamiToken, huamiUsername],
    'devices': [pairedDevices],
  };
  static const _miLegacy = 'mi_account.session';
  final FlutterSecureStorage _secure;
  Future<AppDataDirectory>? _lock;
  Future<AppDataDirectory> get _directory =>
      _lock ??= openAppDataDirectory('private');
  final _prefs = SharedPrefsService.instance;
  Map<String, Object?> _values = {};
  Future<void>? _initializing;
  bool _ready = false;
  bool get isReady => _ready;

  Future<void> initialize() {
    if (_ready) return Future.value();
    return _initializing ??= _reload().whenComplete(() => _initializing = null);
  }

  Future<void> reload({String? key}) async {
    await initialize();
    await _reload(key: key);
  }

  Future<void> _reload({String? key}) async {
    try {
      await _prefs.init();
      await (await _directory).exclusive(() async {
        await _prefs.reload();
        final next = key == null ? <String, Object?>{} : Map.of(_values);
        for (final group in key == null ? _groups.keys : [_group(key)]) {
          for (final name in _groups[group]!) {
            next.remove(name);
          }
          next.addAll(await _load(group));
        }
        _values = next;
        _ready = true;
      });
    } on PrivateStateException {
      rethrow;
    } catch (_) {
      throw const PrivateStateException('private_state_read_failed');
    }
  }

  String? readString(String key) {
    _checkReady();
    _group(key);
    return _values[key] as String?;
  }

  List<String>? readStringList(String key) {
    _checkReady();
    _group(key);
    final value = _values[key] as List<String>?;
    return value == null ? null : List.of(value);
  }

  void _checkReady() {
    if (!_ready) throw const PrivateStateException('private_state_read_failed');
  }

  String _group(String key) => _groups.entries
      .firstWhere(
        (group) => group.value.contains(key),
        orElse: () => throw ArgumentError('Unknown private state key'),
      )
      .key;

  Future<Map<String, Object?>> _load(String group) async {
    final raw = await _secure.read(key: 'oronbox.private.$group.v1');
    Map<String, Object?> values;
    if (raw == null) {
      if (await (await _directory).read('$group.present') != null) {
        throw const PrivateStateException('private_state_read_failed');
      }
      values = {
        for (final key in _groups[group]!)
          if (_legacy(key) case final value?) key: value,
      };
      await _commit(group, values);
    } else {
      values = _decode(group, raw);
      await _markPresent(group);
    }
    // A durable empty record is intentional and must not resurrect old prefs.
    await _removeLegacy(group);
    return values;
  }

  Object? _legacy(String key) => key == pairedDevices
      ? _prefs.getStringList(key)
      : _prefs.getString(key) ??
            (key == miToken ? _prefs.getString(_miLegacy) : null);

  Map<String, Object?> _decode(String group, String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map ||
        decoded['version'] != 1 ||
        decoded['values'] is! Map) {
      throw const PrivateStateException('private_state_read_failed');
    }
    final values = (decoded['values'] as Map).cast<String, Object?>();
    _validate(group, values);
    return {
      for (final entry in values.entries)
        entry.key: entry.key == pairedDevices
            ? List<String>.from(entry.value! as List)
            : entry.value,
    };
  }

  void _validate(String group, Map<String, Object?> values) {
    for (final entry in values.entries) {
      final value = entry.value;
      if (!_groups[group]!.contains(entry.key) ||
          (entry.key == pairedDevices
              ? value is! List || value.any((row) => row is! String)
              : value is! String)) {
        throw const PrivateStateException('private_state_read_failed');
      }
    }
  }

  Future<void> _commit(String group, Map<String, Object?> values) async {
    _validate(group, values);
    final raw = jsonEncode({'version': 1, 'values': values});
    final key = 'oronbox.private.$group.v1';
    await _secure.write(key: key, value: raw);
    if (await _secure.read(key: key) != raw) {
      throw const PrivateStateException('private_state_write_failed');
    }
    await _markPresent(group);
  }

  Future<void> _markPresent(String group) async {
    final directory = await _directory;
    if (await directory.read('$group.present') == null) {
      await directory.write('$group.present', Uint8List.fromList([1]));
    }
  }

  Future<void> _removeLegacy(String group) async {
    for (final key in [..._groups[group]!, if (group == 'xiaomi') _miLegacy]) {
      if (_prefs.value(key) != null && !await _prefs.remove(key)) {
        throw const PrivateStateException('private_state_write_failed');
      }
    }
  }

  static const _backupRecoveryKey = 'oronbox.private.backup-recovery.v1';

  Future<String?> readBackupRecovery() => _secure.read(key: _backupRecoveryKey);
  Future<void> writeBackupRecovery(String? value) async {
    await _secure.write(key: _backupRecoveryKey, value: value);
    if (await _secure.read(key: _backupRecoveryKey) != value) {
      throw const PrivateStateException('private_state_write_failed');
    }
  }

  Future<bool> update(
    Map<String, Object?> changes, {
    bool Function(Map<String, Object?> current)? when,
  }) async {
    if (changes.isEmpty) return true;
    final group = _group(changes.keys.first);
    if (changes.keys.any((key) => _group(key) != group)) {
      throw ArgumentError('Private state updates must belong to one account');
    }
    await initialize();
    try {
      return await (await _directory).exclusive(() async {
        await _prefs.reload();
        final next = await _load(group);
        if (when != null && !when(Map.unmodifiable(next))) {
          for (final key in _groups[group]!) {
            _values.remove(key);
          }
          _values.addAll(next);
          return false;
        }
        for (final entry in changes.entries) {
          if (entry.value == null) {
            next.remove(entry.key);
          } else {
            next[entry.key] = entry.value is List<String>
                ? List<String>.from(entry.value! as List<String>)
                : entry.value;
          }
        }
        await _commit(group, next);
        await _removeLegacy(group);
        for (final key in _groups[group]!) {
          _values.remove(key);
        }
        _values.addAll(next);
        return true;
      });
    } on PrivateStateException {
      rethrow;
    } catch (_) {
      throw const PrivateStateException('private_state_write_failed');
    }
  }
}
