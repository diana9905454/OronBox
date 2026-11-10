import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/core/services/shared_prefs_service.dart';
import 'package:oronbox/src/core/storage/app_data_directory_io.dart';
import 'package:oronbox/src/features/devices/health/health_store.dart';
import 'package:oronbox/src/features/settings/application/app_data_backup.dart';
import 'package:oronbox/src/features/settings/application/auto_backup_service.dart';
import 'package:oronbox/src/features/settings/services/public_backup_storage.dart';
import 'package:oronbox/src/features/settings/services/public_backup_storage_io.dart'
    show userBackupsDirectoryOverride;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Directory backupsDir;
  late Directory healthDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPrefsService.instance.init();

    tempDir = await Directory.systemTemp.createTemp(
      'auto_backup_service_test_',
    );
    backupsDir = Directory('${tempDir.path}/Backups');
    await backupsDir.create(recursive: true);
    userBackupsDirectoryOverride = backupsDir;

    healthDir = await Directory.systemTemp.createTemp(
      'auto_backup_health_test_',
    );
    HealthStore.activityStorageForTesting = IoAppDataDirectory(healthDir);
    HealthStore.clearCache();
  });

  tearDown(() async {
    HealthStore.activityStorageForTesting = null;
    HealthStore.clearCache();
    userBackupsDirectoryOverride = null;
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
    if (await healthDir.exists()) {
      await healthDir.delete(recursive: true);
    }
  });

  group('AutoBackupPreferences and Units', () {
    test('default preference values', () {
      expect(AutoBackupPreferences.enabled, isFalse);
      expect(AutoBackupPreferences.intervalValue, 1);
      expect(AutoBackupPreferences.intervalUnit, AutoBackupUnit.day);
      expect(AutoBackupPreferences.retention, 5);
      expect(AutoBackupPreferences.passwordProtected, isFalse);
      expect(AutoBackupPreferences.password, isEmpty);
      expect(AutoBackupPreferences.lastBackupTime, isNull);
    });

    test('calculates interval duration across units', () {
      expect(AutoBackupUnit.day.toDuration(1), const Duration(days: 1));
      expect(AutoBackupUnit.day.toDuration(3), const Duration(days: 3));
      expect(AutoBackupUnit.week.toDuration(2), const Duration(days: 14));
      expect(AutoBackupUnit.month.toDuration(1), const Duration(days: 30));
    });

    test('shouldRun returns true when enabled and due', () {
      final now = DateTime(2026, 11, 2, 12, 0, 0);

      // Disabled
      expect(AutoBackupPreferences.shouldRun(now), isFalse);

      AutoBackupPreferences.enabled = true;
      // First run (no lastBackupTime)
      expect(AutoBackupPreferences.shouldRun(now), isTrue);

      // Just backed up
      AutoBackupPreferences.lastBackupTime = now;
      expect(AutoBackupPreferences.shouldRun(now), isFalse);

      // After 23 hours (interval = 1 day)
      expect(
        AutoBackupPreferences.shouldRun(now.add(const Duration(hours: 23))),
        isFalse,
      );

      // After 24 hours
      expect(
        AutoBackupPreferences.shouldRun(now.add(const Duration(hours: 24))),
        isTrue,
      );
    });
  });

  group('AutoBackupService Execution & Retention Pruning', () {
    test(
      'executes backup and cleans up old archives when exceeding retention',
      () async {
        AutoBackupPreferences.enabled = true;
        AutoBackupPreferences.retention = 3;
        AutoBackupPreferences.scopeDevices = false;
        AutoBackupPreferences.passwordProtected = true;
        AutoBackupPreferences.password = 'AutoSecret123';

        final journal = IoAppDataDirectory(tempDir);
        final backupService = AppDataBackupService(journal: journal);
        final service = AutoBackupService(backupService: backupService);

        // Run 1
        final t1 = DateTime(2026, 11, 1, 10, 0, 0);
        final ran1 = await service.executeAutoBackup(nowOverride: t1);
        expect(ran1, isTrue);

        // Run 2
        final t2 = DateTime(2026, 11, 2, 10, 0, 0);
        final ran2 = await service.executeAutoBackup(nowOverride: t2);
        expect(ran2, isTrue);

        // Run 3
        final t3 = DateTime(2026, 11, 3, 10, 0, 0);
        final ran3 = await service.executeAutoBackup(nowOverride: t3);
        expect(ran3, isTrue);

        var files = await listPublicBackupFiles();
        expect(files.length, 3);

        // Run 4: Should trigger pruning of the oldest file (t1)
        final t4 = DateTime(2026, 11, 4, 10, 0, 0);
        final ran4 = await service.executeAutoBackup(nowOverride: t4);
        expect(ran4, isTrue);

        files = await listPublicBackupFiles();
        expect(files.length, 3);
        expect(files.any((f) => f.contains('20261101')), isFalse);
        expect(files.any((f) => f.contains('20261104')), isTrue);

        // Verify that the generated auto backup is encrypted and can be decrypted with password
        final latestFile = File('${backupsDir.path}/${files.first}');
        final bytes = await latestFile.readAsBytes();
        expect(backupService.isEncrypted(bytes), isTrue);

        final backupData = await backupService.inspect(
          bytes,
          password: 'AutoSecret123',
        );
        expect(backupData.settings, isA<Map<String, Object?>>());
      },
    );
  });
}
