import 'package:logging/logging.dart';
import 'package:oronbox/src/core/services/shared_prefs_service.dart';

import '../services/public_backup_storage.dart';
import 'app_data_backup.dart';

final _log = Logger('AutoBackupService');

enum AutoBackupUnit {
  day,
  week,
  month;

  Duration toDuration(int value) {
    final v = value < 1 ? 1 : value;
    switch (this) {
      case AutoBackupUnit.day:
        return Duration(days: v);
      case AutoBackupUnit.week:
        return Duration(days: v * 7);
      case AutoBackupUnit.month:
        return Duration(days: v * 30);
    }
  }

  static AutoBackupUnit fromString(String? raw) {
    switch (raw?.toLowerCase()) {
      case 'week':
        return AutoBackupUnit.week;
      case 'month':
        return AutoBackupUnit.month;
      case 'day':
      default:
        return AutoBackupUnit.day;
    }
  }
}

class AutoBackupPreferences {
  static const keyEnabled = 'auto_backup_enabled';
  static const keyIntervalValue = 'auto_backup_interval_value';
  static const keyIntervalUnit = 'auto_backup_interval_unit';
  static const keyRetention = 'auto_backup_retention';
  static const keyPasswordProtected = 'auto_backup_password_protected';
  static const keyPassword = 'auto_backup_password';
  static const keyScopeSettings = 'auto_backup_scope_settings';
  static const keyScopeHealth = 'auto_backup_scope_health';
  static const keyScopeExtensions = 'auto_backup_scope_extensions';
  static const keyScopeDevices = 'auto_backup_scope_devices';
  static const keyScopeXiaomi = 'auto_backup_scope_xiaomi';
  static const keyLastTimestamp = 'auto_backup_last_timestamp';

  static final _prefs = SharedPrefsService.instance;

  static bool get enabled => _prefs.getBool(keyEnabled) ?? false;
  static set enabled(bool value) => _prefs.setBool(keyEnabled, value);

  static int get intervalValue => _prefs.getInt(keyIntervalValue) ?? 1;
  static set intervalValue(int value) =>
      _prefs.setInt(keyIntervalValue, value < 1 ? 1 : value);

  static AutoBackupUnit get intervalUnit =>
      AutoBackupUnit.fromString(_prefs.getString(keyIntervalUnit));
  static set intervalUnit(AutoBackupUnit unit) =>
      _prefs.setString(keyIntervalUnit, unit.name);

  static int get retention => _prefs.getInt(keyRetention) ?? 5;
  static set retention(int value) => _prefs.setInt(keyRetention, value);

  static bool get passwordProtected =>
      _prefs.getBool(keyPasswordProtected) ?? false;
  static set passwordProtected(bool value) =>
      _prefs.setBool(keyPasswordProtected, value);

  static String get password => _prefs.getString(keyPassword) ?? '';
  static set password(String value) => _prefs.setString(keyPassword, value);

  static bool get scopeSettings => _prefs.getBool(keyScopeSettings) ?? true;
  static set scopeSettings(bool value) =>
      _prefs.setBool(keyScopeSettings, value);

  static bool get scopeHealth => _prefs.getBool(keyScopeHealth) ?? true;
  static set scopeHealth(bool value) => _prefs.setBool(keyScopeHealth, value);

  static bool get scopeExtensions => _prefs.getBool(keyScopeExtensions) ?? true;
  static set scopeExtensions(bool value) =>
      _prefs.setBool(keyScopeExtensions, value);

  static bool get scopeDevices => _prefs.getBool(keyScopeDevices) ?? true;
  static set scopeDevices(bool value) => _prefs.setBool(keyScopeDevices, value);

  static bool get scopeXiaomi => _prefs.getBool(keyScopeXiaomi) ?? false;
  static set scopeXiaomi(bool value) => _prefs.setBool(keyScopeXiaomi, value);

  static DateTime? get lastBackupTime {
    final ms = _prefs.getInt(keyLastTimestamp);
    return ms == null || ms <= 0
        ? null
        : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  static set lastBackupTime(DateTime? time) {
    if (time == null) {
      _prefs.remove(keyLastTimestamp);
    } else {
      _prefs.setInt(keyLastTimestamp, time.millisecondsSinceEpoch);
    }
  }

  static Duration get intervalDuration =>
      intervalUnit.toDuration(intervalValue);

  static bool shouldRun(DateTime now) {
    if (!enabled) return false;
    final last = lastBackupTime;
    if (last == null) return true;
    return now.difference(last) >= intervalDuration;
  }
}

class AutoBackupService {
  AutoBackupService({AppDataBackupService? backupService})
    : _backupService = backupService ?? AppDataBackupService();

  final AppDataBackupService _backupService;
  bool _isExecuting = false;

  bool get isExecuting => _isExecuting;

  Future<bool> runAutoBackupIfDue({DateTime? nowOverride}) async {
    final now = nowOverride ?? DateTime.now();
    if (!AutoBackupPreferences.shouldRun(now)) return false;
    return await executeAutoBackup(nowOverride: now);
  }

  Future<bool> executeAutoBackup({DateTime? nowOverride}) async {
    if (_isExecuting) {
      _log.info('Auto backup already in progress, skipping');
      return false;
    }
    _isExecuting = true;
    final now = nowOverride ?? DateTime.now();
    _log.info('Starting auto backup execution: $now');

    try {
      final selection = BackupSelection(
        settings: AutoBackupPreferences.scopeSettings,
        health: AutoBackupPreferences.scopeHealth,
        extensions: AutoBackupPreferences.scopeExtensions,
        devices: AutoBackupPreferences.scopeDevices,
        accounts: AutoBackupPreferences.scopeXiaomi,
      );

      final password = AutoBackupPreferences.passwordProtected
          ? AutoBackupPreferences.password
          : null;

      final bytes = await _backupService.export(
        selection: selection,
        password: password,
      );

      final year = now.year.toString().padLeft(4, '0');
      final month = now.month.toString().padLeft(2, '0');
      final day = now.day.toString().padLeft(2, '0');
      final hour = now.hour.toString().padLeft(2, '0');
      final minute = now.minute.toString().padLeft(2, '0');
      final second = now.second.toString().padLeft(2, '0');
      final fileName =
          'OronBox-AutoBackup-$year$month$day-$hour$minute$second.zip';

      final savedPath = await savePublicBackupFile(
        fileName: fileName,
        bytes: bytes,
      );

      if (savedPath == null) {
        _log.warning('Failed to save auto backup file to public storage');
        return false;
      }

      _log.info('Auto backup saved to: $savedPath');
      AutoBackupPreferences.lastBackupTime = now;

      // Prune old backups per retention policy
      await pruneAutoBackups(maxRetention: AutoBackupPreferences.retention);
      return true;
    } catch (error) {
      _log.warning('Auto backup failed', error);
      return false;
    } finally {
      _isExecuting = false;
    }
  }
}
