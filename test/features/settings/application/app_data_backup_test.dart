import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/core/services/shared_prefs_service.dart';
import 'package:oronbox/src/core/storage/app_data_directory_io.dart';
import 'package:oronbox/src/core/storage/data_archive.dart';
import 'package:oronbox/src/device/xiaomi/health/models/xiaomi_activity_models.dart';
import 'package:oronbox/src/features/devices/health/health_store.dart';
import 'package:oronbox/src/features/settings/application/app_data_backup.dart';
import 'package:oronbox/src/features/settings/application/app_extension_backup.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ExtensionStore extends AppExtensionBackupStore {
  Map<String, Object?> value = {
    'zeppos': {
      '123': {'theme': 'dark'},
    },
  };
  bool failNextRestore = false;

  @override
  Future<Map<String, Object?>> export() async =>
      (jsonDecode(jsonEncode(value)) as Map).cast<String, Object?>();

  @override
  Future<AppExtensionBackupPayload> exportPayload() async =>
      AppExtensionBackupPayload(metadata: await export(), files: const {});

  @override
  Future<void> validateTargets(
    Map<String, Object?> data, {
    Map<String, Uint8List> files = const {},
  }) async => validateExtensionBackup(data);

  @override
  Future<void> restore(
    Map<String, Object?> data, {
    Map<String, Uint8List> files = const {},
  }) async {
    value = (jsonDecode(jsonEncode(data)) as Map).cast<String, Object?>();
    if (failNextRestore) {
      failNextRestore = false;
      throw StateError('interrupted extension write');
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late Directory healthDir;
  late IoAppDataDirectory journal;
  late AppDataBackupService service;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('oronbox-backup-test-');
    healthDir = await Directory.systemTemp.createTemp('oronbox-health-test-');
    HealthStore.activityStorageForTesting = IoAppDataDirectory(healthDir);
    journal = IoAppDataDirectory(root);
    HealthStore.clearCache();
    SharedPreferences.setMockInitialValues({});
    await SharedPrefsService.instance.init();
    await SharedPrefsService.instance.reload();
    service = AppDataBackupService(journal: journal);
  });

  tearDown(() async {
    HealthStore.activityStorageForTesting = null;
    HealthStore.clearCache();
    await root.delete(recursive: true);
    await healthDir.delete(recursive: true);
  });

  test('archive includes extension data and rolls back a partial extension restore', () async {
    final extensions = _ExtensionStore();
    service = AppDataBackupService(journal: journal, extensions: extensions);
    await SharedPrefsService.instance.setString('app_theme_mode', 'light');
    final bytes = await service.export();
    final inspected = await service.inspect(bytes);
    expect(inspected.extensions, extensions.value);
    expect(
      jsonDecode(
        utf8.decode(readDataArchive(bytes)['manifest.json']!),
      )['version'],
      1,
    );
    extensions.failNextRestore = true;
    await expectLater(
      service.restore(
        AppDataBackup(
          settings: {'app_theme_mode': 'dark'},
          extensions: {
            'zeppos': {
              '123': {'theme': 'light'},
            },
          },
        ),
      ),
      throwsStateError,
    );
    expect(SharedPrefsService.instance.getString('app_theme_mode'), 'light');
    expect(extensions.value, {
      'zeppos': {
        '123': {'theme': 'dark'},
      },
    });
    expect(await service.hasPendingRecovery, isFalse);
  });

  test('backs up allowed settings without credentials', () async {
    final prefs = SharedPrefsService.instance;
    await prefs.setString('app_theme_mode', 'dark');
    await prefs.setString('oronbox.session.token', 'secret-token');
    final bytes = await service.export();
    final restored = await service.inspect(bytes);
    expect(restored.settings['app_theme_mode'], 'dark');
    expect(restored.settings, isNot(contains('oronbox.session.token')));
    expect(
      utf8.decode(readDataArchive(bytes)['settings.json']!),
      isNot(contains('secret-token')),
    );
  });

  test('interrupted restore waits for explicit recovery', () async {
    await SharedPrefsService.instance.setString('app_theme_mode', 'dark');
    await journal.write(
      'pending.json',
      Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'settings': {'app_theme_mode': 'light'},
          }),
        ),
      ),
    );
    expect(await service.hasPendingRecovery, true);
    expect(SharedPrefsService.instance.getString('app_theme_mode'), 'dark');
    await expectLater(
      service.restore(
        const AppDataBackup(settings: {'app_theme_mode': 'custom'}),
      ),
      throwsStateError,
    );
    await service.recover();
    expect(SharedPrefsService.instance.getString('app_theme_mode'), 'light');
    expect(await service.hasPendingRecovery, false);
  });

  test('checksum mismatch is rejected before restore', () async {
    final files = readDataArchive(await service.export());
    files['settings.json'] = Uint8List.fromList(
      utf8.encode('{"changed":"bad"}'),
    );
    final archive = Archive();
    for (final entry in files.entries) {
      archive.addFile(ArchiveFile(entry.key, entry.value.length, entry.value));
    }
    await expectLater(
      service.inspect(Uint8List.fromList(ZipEncoder().encode(archive))),
      throwsA(isA<FormatException>()),
    );
  });

  test(
    'incorrect setting types are rejected before any restore writes',
    () async {
      await SharedPrefsService.instance.setString('app_theme_mode', 'light');
      await expectLater(
        service.restore(
          const AppDataBackup(settings: {'auto_reconnect': 'true'}),
        ),
        throwsFormatException,
      );
      expect(SharedPrefsService.instance.getString('app_theme_mode'), 'light');
      expect(await service.hasPendingRecovery, false);
    },
  );

  test(
    'archive exports and restores real activity files and plugin files',
    () async {
      final healthStore = HealthStore();
      await healthStore.saveActivityFiles(
        deviceId: 'dev-1',
        files: [
          XiaomiActivityRawFile(
            id: '12345',
            data: Uint8List.fromList([10, 20, 30, 40]),
          ),
        ],
      );

      final extStore = _ExtensionStore();
      extStore.value = {
        'zeppos': {
          '999': {'key': 'val'},
        },
      };
      service = AppDataBackupService(journal: journal, extensions: extStore);

      final bytes = await service.export(
        selection: const BackupSelection(
          settings: true,
          health: true,
          extensions: true,
        ),
      );

      final rawFiles = readDataArchive(bytes);
      final manifest =
          jsonDecode(utf8.decode(rawFiles['manifest.json']!)) as Map;
      expect(manifest['version'], 1);
      expect(rawFiles.containsKey('health/raw/dev-1/12345.bin'), isTrue);
      expect(rawFiles.containsKey('health/raw/index.json'), isTrue);
      expect(rawFiles['health/raw/dev-1/12345.bin'], [10, 20, 30, 40]);

      final inspected = await service.inspect(bytes);
      expect(
        inspected.activityFiles.containsKey('health/raw/dev-1/12345.bin'),
        isTrue,
      );

      await HealthStore.clearActivityFiles();
      HealthStore.clearCache();
      expect(await HealthStore.listActivityBatches(), isEmpty);

      await service.restore(inspected);
      final restoredBatches = await HealthStore.listActivityBatches();
      expect(restoredBatches.length, 1);
      expect(restoredBatches.first.deviceId, 'dev-1');
      expect(restoredBatches.first.files.first.id, '12345');
    },
  );

  test(
    'rolls back activity files when a later extension restore fails',
    () async {
      final healthStore = HealthStore();
      await healthStore.saveActivityFiles(
        deviceId: 'old-device',
        files: [
          XiaomiActivityRawFile(
            id: 'old-file',
            data: Uint8List.fromList([1, 2, 3]),
          ),
        ],
      );
      await healthStore.saveActivityFiles(
        deviceId: 'new-device',
        files: [
          XiaomiActivityRawFile(
            id: 'new-file',
            data: Uint8List.fromList([4, 5, 6]),
          ),
        ],
      );
      final backupFiles = <String, Uint8List>{
        'health/raw/index.json': await HealthStore.exportActivityIndex(),
        for (final entry in await HealthStore.exportActivityFiles().then(
          (value) => value.entries,
        ))
          'health/raw/${entry.key}': entry.value,
      };

      await HealthStore.clearActivityFiles();
      await healthStore.saveActivityFiles(
        deviceId: 'old-device',
        files: [
          XiaomiActivityRawFile(
            id: 'old-file',
            data: Uint8List.fromList([1, 2, 3]),
          ),
        ],
      );

      final extensions = _ExtensionStore()..failNextRestore = true;
      service = AppDataBackupService(journal: journal, extensions: extensions);
      await expectLater(
        service.restore(
          AppDataBackup(
            activityFiles: backupFiles,
            extensions: extensions.value,
          ),
        ),
        throwsStateError,
      );
      final batches = await HealthStore.listActivityBatches();
      expect(batches, hasLength(1));
      expect(batches.single.deviceId, 'old-device');
      expect(
        await HealthStore.activityStorageForTesting!.read(
          'old-device/old-file.bin',
        ),
        [1, 2, 3],
      );
    },
  );

  test(
    'encrypted backup requires password and rejects wrong credentials',
    () async {
      final tempDir = await Directory.systemTemp.createTemp('backup_enc_test_');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final journal = IoAppDataDirectory(tempDir);
      final service = AppDataBackupService(journal: journal);

      final encryptedBytes = await service.export(
        selection: const BackupSelection(
          settings: true,
          health: false,
          extensions: false,
        ),
        password: 'MySecretPassword123',
      );

      expect(service.isEncrypted(encryptedBytes), isTrue);

      // Missing password
      expect(
        () => service.inspect(encryptedBytes),
        throwsA(isA<ArchivePasswordRequiredException>()),
      );

      // Wrong password
      expect(
        () => service.inspect(encryptedBytes, password: 'WrongPassword'),
        throwsA(isA<ArchiveWrongPasswordException>()),
      );

      // Correct password
      final decrypted = await service.inspect(
        encryptedBytes,
        password: 'MySecretPassword123',
      );
      expect(decrypted.settings, isA<Map<String, Object?>>());
    },
  );
}
