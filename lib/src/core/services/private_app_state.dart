import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:oronbox/src/core/errors/coded_error.dart';
import 'package:oronbox/src/core/logging/logging_service.dart';
import 'package:oronbox/src/core/storage/app_data_directory.dart';

import 'shared_prefs_service.dart';

class PrivateStateException implements CodedError {
  const PrivateStateException(this.code, [this.detail = '']);
  @override
  final String code;

  /// Underlying platform/IO cause, kept out of [message] so the UI keeps using
  /// the localized text for [code]. It is appended to the visible error because
  /// a bare "could not save" gives neither the user nor a bug report anything
  /// to work with.
  final String detail;

  @override
  String get message => '';
  @override
  Object? get details => detail.isEmpty ? null : {'detail': detail};
  @override
  String toString() => code;
}

/// Condenses an arbitrary failure into one short line suitable for logs and for
/// the error detail shown next to the localized message.
String describePrivateStateFailure(Object error) {
  String text;
  if (error is PlatformException) {
    text = [
      if (error.code.isNotEmpty) error.code,
      if ((error.message ?? '').isNotEmpty) error.message!,
    ].join(': ');
  } else {
    text = error.toString();
  }
  text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (text.isEmpty) text = error.runtimeType.toString();
  return text.length <= 240 ? text : '${text.substring(0, 237)}...';
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

  static final _log = getLogger('PrivateAppState');

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

  // Single root vault key to minimize OS keychain prompts and aggregate storage.
  static const _vaultKey = 'oronbox.private.vault.v1';
  static const _vaultPresent = 'vault.present';
  static const _backupRecoveryKey = 'oronbox.private.backup-recovery.v1';

  final FlutterSecureStorage _secure;
  Future<AppDataDirectory>? _lock;
  Future<AppDataDirectory> get _directory =>
      _lock ??= openAppDataDirectory('private');
  final _prefs = SharedPrefsService.instance;

  Map<String, Map<String, Object?>> _vaultGroups = {};
  String? _backupRecoveryValue;
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
        await _loadVaultInsideLock();
        _syncValues();
        _ready = true;
      });
    } on PrivateStateException {
      rethrow;
    } catch (error, stackTrace) {
      _log.severe(
        'Private state read failed: ${describePrivateStateFailure(error)}',
        error,
        stackTrace,
      );
      throw PrivateStateException(
        'private_state_read_failed',
        describePrivateStateFailure(error),
      );
    }
  }

  Future<void> _loadVaultInsideLock() async {
    String? rawVault;
    try {
      rawVault = await _secure.read(key: _vaultKey);
    } catch (error, stackTrace) {
      _log.warning('Secure storage vault read failed', error, stackTrace);
      rawVault = null;
    }

    if (rawVault != null) {
      _unpackVault(rawVault);
      await _markVaultPresent();
      return;
    }

    final recovered = await _recoverOrMigrateData();
    if (recovered != null) {
      _vaultGroups = recovered.$1;
      _backupRecoveryValue = recovered.$2;
      await _commitVault();
      for (final group in _groups.keys) {
        try {
          await _secure.delete(key: 'oronbox.private.$group.v1');
        } catch (_) {}
        await _removeLegacy(group);
      }
      try {
        await _secure.delete(key: _backupRecoveryKey);
      } catch (_) {}
      return;
    }

    if (await _isAnyPresent()) {
      throw const PrivateStateException('private_state_read_failed');
    }

    _vaultGroups = {for (final group in _groups.keys) group: {}};
    _backupRecoveryValue = null;
    await _commitVault();
  }

  Future<(Map<String, Map<String, Object?>>, String?)?> _recoverOrMigrateData() async {
    final groups = <String, Map<String, Object?>>{};
    var hasAnyData = false;

    for (final group in _groups.keys) {
      Map<String, Object?> groupData = {};
      String? raw;
      try {
        raw = await _secure.read(key: 'oronbox.private.$group.v1');
      } catch (error, stackTrace) {
        _log.warning('Failed to read legacy group $group', error, stackTrace);
        raw = null;
      }

      if (raw != null) {
        groupData = _decodeLegacyGroup(group, raw);
        hasAnyData = true;
      } else {
        groupData = _loadLegacyGroup(group);
        if (groupData.isNotEmpty) {
          hasAnyData = true;
        }
      }
      groups[group] = groupData;
    }

    String? recovery;
    try {
      recovery = await _secure.read(key: _backupRecoveryKey);
      if (recovery != null) hasAnyData = true;
    } catch (_) {}

    if (!hasAnyData) return null;
    return (groups, recovery);
  }

  void _unpackVault(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map || decoded['version'] != 1 || decoded['groups'] is! Map) {
      throw const PrivateStateException('private_state_read_failed');
    }
    final groupsMap = (decoded['groups'] as Map).cast<String, Object?>();
    final groups = <String, Map<String, Object?>>{};
    for (final groupKey in _groups.keys) {
      final rawGroup = groupsMap[groupKey];
      if (rawGroup != null) {
        if (rawGroup is! Map) {
          throw const PrivateStateException('private_state_read_failed');
        }
        final groupValues = rawGroup.cast<String, Object?>();
        _validate(groupKey, groupValues);
        groups[groupKey] = {
          for (final entry in groupValues.entries)
            entry.key: entry.key == pairedDevices
                ? List<String>.from(entry.value! as List)
                : entry.value,
        };
      } else {
        groups[groupKey] = {};
      }
    }
    _vaultGroups = groups;
    final recovery = decoded['backup_recovery'];
    _backupRecoveryValue = recovery is String ? recovery : null;
  }

  void _syncValues() {
    final flat = <String, Object?>{};
    for (final group in _vaultGroups.values) {
      flat.addAll(group);
    }
    _values = flat;
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

  Map<String, Object?> _loadLegacyGroup(String group) => {
    for (final key in _groups[group]!)
      if (_legacy(key) case final value?) key: value,
  };

  Object? _legacy(String key) => key == pairedDevices
      ? _prefs.getStringList(key)
      : _prefs.getString(key) ??
            (key == miToken ? _prefs.getString(_miLegacy) : null);

  Map<String, Object?> _decodeLegacyGroup(String group, String raw) {
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

  Future<void> _commitVault() async {
    for (final entry in _vaultGroups.entries) {
      _validate(entry.key, entry.value);
    }
    final payload = jsonEncode({
      'version': 1,
      'groups': _vaultGroups,
      'backup_recovery': _backupRecoveryValue,
    });
    await _writeVaultPayload(payload);
    if (await _readVaultPayload() != payload) {
      // A secure storage that is still initializing (or a chunked write that
      // raced with the manifest) can read back stale data once; one retry
      // turns those into a success instead of breaking device pairing.
      _log.warning(
        'Vault readback mismatch after write '
        '(${payload.length} chars); retrying once',
      );
      await _writeVaultPayload(payload);
      final second = await _readVaultPayload();
      if (second != payload) {
        _log.severe(
          'Vault readback mismatch persists: expected ${payload.length} '
          'chars, read ${second?.length ?? -1}',
        );
        throw PrivateStateException(
          'private_state_write_failed',
          'vault readback mismatch: expected ${payload.length} chars, '
              'read ${second?.length ?? -1}',
        );
      }
    }
    await _markVaultPresent();
  }

  Future<void> _writeVaultPayload(String payload) async {
    try {
      await _secure.write(key: _vaultKey, value: payload);
    } catch (error, stackTrace) {
      _log.severe(
        'Secure storage vault write failed '
        '(${payload.length} chars): ${describePrivateStateFailure(error)}',
        error,
        stackTrace,
      );
      rethrow;
    }
  }

  Future<String?> _readVaultPayload() async {
    try {
      return await _secure.read(key: _vaultKey);
    } catch (error, stackTrace) {
      _log.severe(
        'Secure storage vault read failed: ${describePrivateStateFailure(error)}',
        error,
        stackTrace,
      );
      rethrow;
    }
  }

  Future<void> _markVaultPresent() async {
    final directory = await _directory;
    if (await directory.read(_vaultPresent) == null) {
      await directory.write(_vaultPresent, Uint8List.fromList([1]));
    }
  }

  Future<bool> _isAnyPresent() async {
    final directory = await _directory;
    if (await directory.read(_vaultPresent) != null) return true;
    for (final group in _groups.keys) {
      if (await directory.read('$group.present') != null) return true;
    }
    return false;
  }

  Future<void> _removeLegacy(String group) async {
    for (final key in [..._groups[group]!, if (group == 'xiaomi') _miLegacy]) {
      if (_prefs.value(key) != null && !await _prefs.remove(key)) {
        throw const PrivateStateException('private_state_write_failed');
      }
    }
  }

  Future<String?> readBackupRecovery() async {
    await initialize();
    return _backupRecoveryValue;
  }

  Future<void> writeBackupRecovery(String? value) async {
    await initialize();
    try {
      await (await _directory).exclusive(() async {
        await _loadVaultInsideLock();
        _backupRecoveryValue = value;
        await _commitVault();
        try {
          await _secure.delete(key: _backupRecoveryKey);
        } catch (_) {}
      });
    } on PrivateStateException {
      rethrow;
    } catch (error, stackTrace) {
      _log.severe(
        'Private state write failed: ${describePrivateStateFailure(error)}',
        error,
        stackTrace,
      );
      throw PrivateStateException(
        'private_state_write_failed',
        describePrivateStateFailure(error),
      );
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
        await _loadVaultInsideLock();
        final currentGroup = Map<String, Object?>.from(
          _vaultGroups[group] ?? {},
        );
        if (when != null && !when(Map.unmodifiable(currentGroup))) {
          _syncValues();
          return false;
        }
        for (final entry in changes.entries) {
          if (entry.value == null) {
            currentGroup.remove(entry.key);
          } else {
            currentGroup[entry.key] = entry.value is List<String>
                ? List<String>.from(entry.value! as List<String>)
                : entry.value;
          }
        }
        _validate(group, currentGroup);
        _vaultGroups[group] = currentGroup;
        await _commitVault();
        await _removeLegacy(group);
        _syncValues();
        return true;
      });
    } on PrivateStateException {
      rethrow;
    } catch (error, stackTrace) {
      _log.severe(
        'Private state write failed: ${describePrivateStateFailure(error)}',
        error,
        stackTrace,
      );
      throw PrivateStateException(
        'private_state_write_failed',
        describePrivateStateFailure(error),
      );
    }
  }

  Future<void> resetCorruptedState() async {
    try {
      await (await _directory).exclusive(() async {
        try {
          await _secure.delete(key: _vaultKey);
        } catch (_) {}
        for (final group in _groups.keys) {
          try {
            await _secure.delete(key: 'oronbox.private.$group.v1');
          } catch (_) {}
        }
        try {
          await _secure.delete(key: _backupRecoveryKey);
        } catch (_) {}

        final directory = await _directory;
        try {
          await directory.remove(_vaultPresent);
        } catch (_) {}
        for (final group in _groups.keys) {
          try {
            await directory.remove('$group.present');
          } catch (_) {}
        }

        _vaultGroups = {for (final group in _groups.keys) group: {}};
        _backupRecoveryValue = null;
        _values = {};
        _ready = true;
      });
    } catch (e, st) {
      _log.severe('Failed to reset corrupted private state', e, st);
      throw const PrivateStateException('private_state_write_failed');
    }
  }
}
