import 'dart:convert';

import 'package:oronbox/src/features/settings/application/app_extension_backup.dart';

import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oronbox/src/core/services/shared_prefs_service.dart';
import 'package:oronbox/src/core/storage/app_data_directory_io.dart';
import 'package:oronbox/src/core/storage/data_archive.dart';
import 'package:oronbox/src/features/devices/health/health_database.dart';
import 'package:oronbox/src/features/devices/health/health_models.dart';
import 'package:oronbox/src/features/devices/health/health_store.dart';
import 'package:oronbox/src/features/settings/application/app_data_backup.dart';

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
  Future<void> validateTargets(Map<String, Object?> data) async =>
      validateExtensionBackup(data);
  @override
  Future<void> restore(Map<String, Object?> data) async {
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
  late HealthDatabase db;
  late IoAppDataDirectory journal;
  late AppDataBackupService service;
  final device = sha1.convert(utf8.encode('device-a')).toString();
  XiaomiHealthData history(int steps) => XiaomiHealthData(
    daily: [HealthDailySummary(date: DateTime(2026, 10, 19), steps: steps)],
  );
  setUp(() async {
    root = await Directory.systemTemp.createTemp('oronbox-backup-test-');
    journal = IoAppDataDirectory(root);
    db = HealthDatabase(NativeDatabase.memory());
    HealthStore.databaseForTesting = db;
    HealthStore.clearCache();
    SharedPreferences.setMockInitialValues({});
    await SharedPrefsService.instance.init();
    await SharedPrefsService.instance.reload();
    service = AppDataBackupService(database: db, journal: journal);
  });
  tearDown(() async {
    await db.close();
    HealthStore.databaseForTesting = null;
    HealthStore.clearCache();
    await root.delete(recursive: true);
  });
  test('v2 archive includes extension data and rolls back a partial extension restore', () async {
    final extensions = _ExtensionStore();
    service = AppDataBackupService(
      database: db,
      journal: journal,
      extensions: extensions,
    );
    await SharedPrefsService.instance.setString('app_theme_mode', 'light');
    await db.writeDevice(device, history(12));
    final bytes = await service.export();
    final inspected = await service.inspect(bytes);
    expect(inspected.extensions, extensions.value);
    expect(
      jsonDecode(
        utf8.decode(readDataArchive(bytes)['manifest.json']!),
      )['version'],
      2,
    );
    extensions.failNextRestore = true;
    await expectLater(
      service.restore(
        AppDataBackup(
          {'app_theme_mode': 'dark'},
          {device: history(99)},
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
    expect((await db.readDevice(device))!.daily.single.steps, 12);
    expect(extensions.value, {
      'zeppos': {
        '123': {'theme': 'dark'},
      },
    });
    expect(await service.hasPendingRecovery, isFalse);
  });
  test('backs up health and allowed settings without credentials', () async {
    final prefs = SharedPrefsService.instance;
    await prefs.setString('app_theme_mode', 'dark');
    await prefs.setString('oronbox.session.token', 'secret-token');
    await db.writeDevice(device, history(123));
    final bytes = await service.export();
    final restored = await service.inspect(bytes);
    expect(restored.settings['app_theme_mode'], 'dark');
    expect(restored.settings, isNot(contains('oronbox.session.token')));
    expect(restored.health[device]!.daily.single.steps, 123);
    expect(
      utf8.decode(readDataArchive(bytes)['settings.json']!),
      isNot(contains('secret-token')),
    );
  });
  test(
    'explicit restore replaces selected devices and retains other devices',
    () async {
      await db.writeDevice(device, history(10));
      final other = sha1.convert(utf8.encode('other')).toString();
      await db.writeDevice(other, history(99));
      await service.restore(
        AppDataBackup({'app_theme_mode': 'dark'}, {device: history(20)}),
      );
      expect((await db.readDevice(device))!.daily.single.steps, 20);
      expect((await db.readDevice(other))!.daily.single.steps, 99);
      expect(await service.hasPendingRecovery, false);
    },
  );
  test('interrupted restore waits for explicit recovery', () async {
    await db.writeDevice(device, history(20));
    await journal.write(
      'pending.json',
      Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'settings': {'app_theme_mode': 'light'},
            'health': {device: history(10).encode()},
          }),
        ),
      ),
    );
    expect(await service.hasPendingRecovery, true);
    expect((await db.readDevice(device))!.daily.single.steps, 20);
    await expectLater(
      service.restore(AppDataBackup({}, {device: history(30)})),
      throwsStateError,
    );
    await service.recover();
    expect((await db.readDevice(device))!.daily.single.steps, 10);
    expect(await service.hasPendingRecovery, false);
  });
  test('checksum mismatch is rejected before restore', () async {
    final files = readDataArchive(await service.export());
    files['health.json'] = Uint8List.fromList(utf8.encode('{"changed":"bad"}'));
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
      await db.writeDevice(device, history(12));
      await expectLater(
        service.restore(
          AppDataBackup({'auto_reconnect': 'true'}, {device: history(99)}),
        ),
        throwsFormatException,
      );
      expect((await db.readDevice(device))!.daily.single.steps, 12);
      expect(await service.hasPendingRecovery, false);
    },
  );
  test('valid checksums cannot hide malformed health records', () async {
    await db.writeDevice(device, history(12));
    final files = readDataArchive(await service.export());
    final health = jsonDecode(utf8.decode(files['health.json']!)) as Map;
    final data = jsonDecode(health[device] as String) as Map;
    data['daily'] = ['invalid record'];
    health[device] = jsonEncode(data);
    files['health.json'] = Uint8List.fromList(utf8.encode(jsonEncode(health)));
    final manifest = jsonDecode(utf8.decode(files['manifest.json']!)) as Map;
    manifest['files']['health.json'] = {
      'bytes': files['health.json']!.length,
      'sha256': sha256.convert(files['health.json']!).toString(),
    };
    files['manifest.json'] = Uint8List.fromList(
      utf8.encode(jsonEncode(manifest)),
    );
    final archive = Archive();
    for (final entry in files.entries) {
      archive.addFile(ArchiveFile(entry.key, entry.value.length, entry.value));
    }
    await expectLater(
      service.inspect(Uint8List.fromList(ZipEncoder().encode(archive))),
      throwsFormatException,
    );
    expect((await db.readDevice(device))!.daily.single.steps, 12);
  });
  test(
    'upgrades old archive indexes without changing original sources',
    () async {
      final sources = ['{"a":1}', '{ "a" : 2 }'];
      await db.close();
      db = HealthDatabase(
        NativeDatabase.memory(
          setup: (sqlite) {
            sqlite.execute(
              'CREATE TABLE health_devices (device TEXT PRIMARY KEY, metadata TEXT NOT NULL)',
            );
            sqlite.execute(
              'CREATE TABLE health_records (device TEXT NOT NULL, kind TEXT NOT NULL, record_key TEXT NOT NULL, payload TEXT NOT NULL, PRIMARY KEY(device, kind, record_key))',
            );
            sqlite.execute(
              'CREATE TABLE health_legacy_archive (device TEXT NOT NULL, source TEXT NOT NULL, PRIMARY KEY(device, source))',
            );
            for (final source in sources) {
              sqlite.execute('INSERT INTO health_legacy_archive VALUES(?, ?)', [
                device,
                source,
              ]);
            }
            sqlite.execute('PRAGMA user_version = 2');
          },
        ),
      );
      final rows = await db
          .customSelect('SELECT source, digest FROM health_legacy_archive')
          .get();
      expect(
        rows.map((row) => row.read<String>('source')),
        unorderedEquals(sources),
      );
      for (final row in rows) {
        expect(
          row.read<String>('digest'),
          sha256.convert(utf8.encode(row.read<String>('source'))).toString(),
        );
      }
    },
  );
  test(
    'legacy source remains byte-exact after structured history changes',
    () async {
      final source = history(12).encode();
      await db.preserveLegacySource(device, source);
      await db.writeDevice(device, history(42));
      final rows = await db
          .customSelect('SELECT source FROM health_legacy_archive')
          .get();
      expect(rows.single.read<String>('source'), source);
      expect((await db.readDevice(device))!.daily.single.steps, 42);
    },
  );
}
