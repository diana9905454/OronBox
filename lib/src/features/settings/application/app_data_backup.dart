import 'app_private_backup.dart';

import 'dart:convert';

import 'app_extension_backup.dart';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:oronbox/src/core/services/shared_prefs_service.dart';
import 'package:oronbox/src/core/storage/app_data_directory.dart';
import 'package:oronbox/src/core/storage/data_archive.dart';
import 'package:oronbox/src/features/devices/health/health_database.dart';
import 'package:oronbox/src/features/devices/health/health_models.dart';
import 'package:oronbox/src/features/devices/health/health_store.dart';

part 'app_data_backup_codec.dart';

typedef BackupMaintenance = Future<T> Function<T>(Future<T> Function() action);

const backupPreferenceKeys = {
  'app_theme_mode',
  'app_dynamic_color',
  'app_desktop_accent_color_source',
  'app_custom_seed_color',
  'app_locale',
  'github_cdn',
  'community_source',
  'auto_install',
  'disable_auto_clean',
  'auto_reconnect',
  'auto_reconnect_on_disconnect',
  'wide_navigation_rail_position',
  'bandbbs_load_previews',
  'check_update_on_launch',
  'bandbbs_show_all_categories',
  'resource_grid_view',
  'clean_announcements',
  'clean_bandbbs_login',
  'clean_comments',
  'clean_creator',
  'clean_explore',
  'clean_explore_entry',
  'clean_github_login',
  'clean_home_banner',
  'clean_home_editor_sections',
  'clean_home_featured',
  'clean_home_feed',
  'clean_home_latest',
  'clean_home_recommended',
  'clean_inbox',
  'clean_plugins_entry',
  'clean_source_astrobox',
  'clean_source_bandbbs',
  'clean_source_huami_app_store',
  'clean_source_oronbox',
  'desktop.exit_behavior',
};

class BackupSelection {
  const BackupSelection({
    this.settings = true,
    this.health = true,
    this.extensions = true,
    this.devices = false,
    this.xiaomi = false,
  });
  final bool settings, health, extensions, devices, xiaomi;
  bool get any => settings || health || extensions || devices || xiaomi;
}

class AppDataBackup {
  const AppDataBackup(
    this.settings,
    this.health, {
    this.extensions = const {},
    this.privateData = const {},
  });
  final Map<String, Object?> settings;
  final Map<String, XiaomiHealthData> health;
  final Map<String, Object?> extensions;
  final Map<String, Object?> privateData;
}

class AppDataBackupService {
  AppDataBackupService({
    HealthDatabase? database,
    AppDataDirectory? journal,
    this.extensions,
    this.maintenance,
    AppPrivateBackupStore? privateStore,
  }) : privateStore = privateStore ?? AppPrivateBackupStore(),
       _database = database ?? healthDatabase,
       _journal = journal == null ? null : Future.value(journal);
  final AppPrivateBackupStore privateStore;
  final AppExtensionBackupStore? extensions;
  final BackupMaintenance? maintenance;
  Future<T> _guard<T>(Future<T> Function() action) =>
      maintenance?.call<T>(action) ?? action();
  final HealthDatabase _database;
  Future<AppDataDirectory>? _journal;
  Future<AppDataDirectory> get _storage =>
      _journal ??= openAppDataDirectory('storage/restore');
  final _prefs = SharedPrefsService.instance;

  Map<String, Object?> _settings() => {
    for (final key in backupPreferenceKeys) key: _prefs.value(key),
  };

  Future<Map<String, String>> _health() async {
    await HealthStore.flush();
    return _database.exportData();
  }

  Future<Uint8List> export({
    BackupSelection selection = const BackupSelection(),
  }) => _guard(() async {
    if (!selection.any) {
      throw const FormatException('No backup categories selected');
    }
    return compute(_encodeBackup, (
      selection.settings ? _settings() : <String, Object?>{},
      selection.health ? await _health() : <String, String>{},
      selection.extensions
          ? await extensions?.export() ?? <String, Object?>{}
          : <String, Object?>{},
      selection.devices || selection.xiaomi
          ? await privateStore.export(
              devices: selection.devices,
              xiaomi: selection.xiaomi,
            )
          : <String, Object?>{},
    ));
  });

  Future<AppDataBackup> inspect(Uint8List bytes) =>
      compute(_decodeBackup, bytes);

  Future<void> restore(AppDataBackup backup) => _guard(() => _restore(backup));

  Future<void> _restore(AppDataBackup backup) async {
    if (backup.extensions.isNotEmpty) {
      if (extensions == null) {
        throw StateError('Extension backup storage is unavailable');
      }
      await extensions!.validateTargets(backup.extensions);
    }
    _validateSettings(backup.settings);
    validatePrivateBackup(backup.privateData);
    final journal = await _storage;
    await HealthStore.maintenance(
      () => journal.exclusive(() async {
        if (await journal.read('pending.json') != null) {
          throw StateError('A previous restore requires user recovery');
        }
        final before = {
          'privateRecovery': backup.privateData.isNotEmpty,
          'settings': _settings(),
          'restoreHealth': backup.health.isNotEmpty,
          'health': backup.health.isEmpty
              ? const <String, String>{}
              : await _health(),
          'extensions': backup.extensions.isEmpty
              ? const {}
              : await extensions?.export() ?? const {},
        };
        if (backup.privateData.isNotEmpty) {
          await privateStore.stageRecovery(
            await privateStore.export(
              devices: backup.privateData.containsKey('devices'),
              xiaomi: backup.privateData.containsKey('xiaomi'),
            ),
          );
        }
        await journal.write(
          'pending.json',
          Uint8List.fromList(utf8.encode(jsonEncode(before))),
        );
        try {
          await _database.transaction(() async {
            await _database.importData(backup.health);
            await _applySettings(backup.settings);
            if (backup.extensions.isNotEmpty) {
              await extensions!.restore(backup.extensions);
            }
            if (backup.privateData.isNotEmpty) {
              await privateStore.restore(backup.privateData);
            }
          });
          await journal.remove('pending.json');
          HealthStore.clearCache();
          healthDataRevision.value++;
        } catch (_) {
          await _recover(journal);
          rethrow;
        }
        if (backup.privateData.isNotEmpty) await privateStore.clearRecovery();
      }),
    );
  }

  Future<bool> get hasPendingRecovery async =>
      await (await _storage).read('pending.json') != null;

  Future<void> recover() => _guard(_recoverPending);

  Future<void> _recoverPending() async {
    final journal = await _storage;
    await HealthStore.maintenance(
      () => journal.exclusive(() => _recover(journal)),
    );
  }

  Future<void> _recover(AppDataDirectory journal) async {
    final bytes = await journal.read('pending.json');
    if (bytes == null) return;
    final before = jsonDecode(utf8.decode(bytes)) as Map;
    final health = (before['health'] as Map).cast<String, String>();
    if (before['restoreHealth'] != false) {
      await _database.replaceData({
        for (final entry in health.entries)
          entry.key: await compute(_decodeHealth, entry.value),
      });
    }
    await _applySettings((before['settings'] as Map).cast<String, Object?>());
    final savedExtensions = (before['extensions'] as Map? ?? {})
        .cast<String, Object?>();
    if (savedExtensions.isNotEmpty) {
      if (extensions == null) {
        throw StateError('Extension recovery storage is unavailable');
      }
      await extensions!.restore(savedExtensions);
    }
    if (before['privateRecovery'] == true) await privateStore.recover();
    await journal.remove('pending.json');
    if (before['privateRecovery'] == true) await privateStore.clearRecovery();
    HealthStore.clearCache();
  }

  Future<void> _applySettings(Map<String, Object?> settings) async {
    for (final entry in settings.entries) {
      if (!backupPreferenceKeys.contains(entry.key)) {
        throw const FormatException('Invalid preference');
      }
      final value = entry.value;
      final ok = switch (value) {
        null => await _prefs.remove(entry.key),
        bool() => await _prefs.setBool(entry.key, value),
        int() => await _prefs.setInt(entry.key, value),
        String() => await _prefs.setString(entry.key, value),
        _ => false,
      };
      if (!ok) throw StateError('Unable to restore preferences');
    }
  }
}
