import 'dart:typed_data';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oronbox/src/core/services/private_app_state.dart';
import 'package:oronbox/src/core/services/shared_prefs_service.dart';
import 'package:oronbox/src/core/storage/app_data_directory_io.dart';
import 'package:oronbox/src/core/storage/data_archive.dart';
import 'package:oronbox/src/features/devices/health/health_store.dart';
import 'package:oronbox/src/features/settings/application/app_data_backup.dart';
import 'package:oronbox/src/features/settings/application/app_private_backup.dart';

import '../../../support/memory_secure_storage.dart';

class _FailOnce extends AppPrivateBackupStore {
  _FailOnce(PrivateAppState state, this.journal) : super(state: state);
  final IoAppDataDirectory journal;
  bool fail = true;
  @override
  Future<void> restore(Map<String, Object?> data) async {
    await super.restore(data);
    if (fail) {
      fail = false;
      final raw = utf8.decode((await journal.read('pending.json'))!);
      expect(raw, isNot(contains('old-secret')));
      expect(raw, isNot(contains('new-secret')));
      throw StateError('interrupted private restore');
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late PrivateAppState state;
  late AppPrivateBackupStore private;
  late IoAppDataDirectory journal;
  late AppDataBackupService service;
  Map<String, Object?> session(String secret) => {
    'user_id': '123',
    'device_id': 'd',
    'ssecurity': secret,
    'service_token': 'service',
    'c_user_id': 'u',
    'pass_token': 'p',
    'psecurity': 's',
  };
  setUp(() async {
    root = await Directory.systemTemp.createTemp('oronbox-private-backup-');
    SharedPreferences.setMockInitialValues({
      'oronbox.session.token': 'oronbox-secret',
      'bandbbs.token': 'bandbbs-secret',
    });
    await SharedPrefsService.instance.init();
    await SharedPrefsService.instance.reload();
    state = PrivateAppState(
      secureStorage: MemorySecureStorage(),
      lock: IoAppDataDirectory(Directory('${root.path}/private')),
    );
    await state.initialize();
    await state.update({
      PrivateAppState.miToken: jsonEncode(session('old-secret')),
    });
    await state.update({
      PrivateAppState.pairedDevices: [
        jsonEncode({
          'name': 'watch',
          'addr': 'AA:BB:CC:DD:EE:FF',
          'connectType': 'BLE',
          'authkey': 'device-secret',
          'disconnected': false,
        }),
      ],
    });
    private = AppPrivateBackupStore(state: state);
    HealthStore.activityStorageForTesting = IoAppDataDirectory(
      Directory('${root.path}/health'),
    );
    HealthStore.clearCache();
    journal = IoAppDataDirectory(Directory('${root.path}/journal'));
    service = AppDataBackupService(journal: journal, privateStore: private);
  });
  tearDown(() async {
    HealthStore.activityStorageForTesting = null;
    HealthStore.clearCache();
    await root.delete(recursive: true);
  });
  test('exports private categories only when selected and never includes other accounts', () async {
    expect(
      (await service.inspect(await service.export())).privateData,
      isEmpty,
    );
    final bytes = await service.export(
      selection: const BackupSelection(
        settings: false,
        health: false,
        extensions: false,
        devices: true,
        xiaomi: true,
      ),
    );
    final backup = await service.inspect(bytes);
    expect(backup.settings, isEmpty);
    expect(backup.health, isEmpty);
    expect(backup.privateData.keys, unorderedEquals(['devices', 'xiaomi']));
    final device = jsonDecode(
      (backup.privateData['devices'] as List).single as String,
    );
    expect(device['authkey'], 'device-secret');
    expect(device['disconnected'], true);
    final raw = utf8.decode(readDataArchive(bytes)['private.json']!);
    expect(raw, isNot(contains('oronbox-secret')));
    expect(raw, isNot(contains('bandbbs-secret')));
    expect(
      jsonDecode(
        utf8.decode(readDataArchive(bytes)['manifest.json']!),
      )['version'],
      1,
    );
    await state.update({PrivateAppState.miToken: null});
    await service.restore(backup);
    expect(state.readString(PrivateAppState.miToken), contains('old-secret'));
    expect(await state.readBackupRecovery(), isNull);
  });
  test(
    'exports Xiaomi and Huami credentials without OAuth session stores',
    () async {
      await state.update({
        PrivateAppState.huamiToken: jsonEncode({
          'app_token': 'app-token',
          'user_id': 'huami-user',
          'country_code': 'CN',
          'raw': <String, Object?>{},
        }),
      });
      await SharedPrefsService.instance.setBool(
        'mi_account.remember_credentials',
        true,
      );
      await SharedPrefsService.instance.setString(
        'mi_account.username',
        'mi-user',
      );
      await SharedPrefsService.instance.setString(
        'mi_account.password',
        'mi-password',
      );
      await SharedPrefsService.instance.setBool(
        'huami_account.remember_credentials',
        true,
      );
      await SharedPrefsService.instance.setString(
        'huami_account.username',
        'huami-user',
      );
      await SharedPrefsService.instance.setString(
        'huami_account.password',
        'huami-password',
      );

      final bytes = await service.export(
        selection: const BackupSelection(
          settings: false,
          health: false,
          extensions: false,
          accounts: true,
        ),
      );
      final backup = await service.inspect(bytes);
      expect(backup.privateData.keys, unorderedEquals(['xiaomi', 'huami']));
      expect(backup.settings['mi_account.password'], 'mi-password');
      expect(backup.settings['huami_account.password'], 'huami-password');
      expect(backup.settings, isNot(contains('oronbox.session.token')));
      expect(backup.settings, isNot(contains('bandbbs.oauth.token')));
    },
  );
  test(
    'rejects account categories outside the explicit allowlist before writing',
    () async {
      await expectLater(
        service.restore(const AppDataBackup(privateData: {'oronbox': 'bad'})),
        throwsFormatException,
      );
      expect(state.readString(PrivateAppState.miToken), contains('old-secret'));
      expect(await service.hasPendingRecovery, false);
    },
  );
  test('partial private restore rolls back through secure storage', () async {
    private = _FailOnce(state, journal);
    service = AppDataBackupService(journal: journal, privateStore: private);
    await expectLater(
      service.restore(
        AppDataBackup(
          privateData: {'xiaomi': jsonEncode(session('new-secret'))},
        ),
      ),
      throwsStateError,
    );
    expect(state.readString(PrivateAppState.miToken), contains('old-secret'));
    expect(await state.readBackupRecovery(), isNull);
    expect(await service.hasPendingRecovery, false);
  });
  test('malformed private records never expose their source in errors', () {
    const secret = 'sensitive-authkey-do-not-log';
    try {
      decodePrivateBackup(utf8.encode('{"devices":["$secret"]}'));
      fail('Expected validation failure');
    } catch (error) {
      expect(error, isFormatException);
      expect(error.toString(), isNot(contains(secret)));
    }
  });
  test(
    'interrupted credential restore recovers without plaintext journal secrets',
    () async {
      await private.stageRecovery(await private.export(xiaomi: true));
      await state.update({
        PrivateAppState.miToken: jsonEncode(session('new-secret')),
      });
      await journal.write(
        'pending.json',
        Uint8List.fromList(
          utf8.encode(
            jsonEncode({
              'privateRecovery': true,
              'restoreHealth': false,
              'settings': <String, Object?>{},
              'health': <String, String>{},
            }),
          ),
        ),
      );
      await service.recover();
      expect(state.readString(PrivateAppState.miToken), contains('old-secret'));
      expect(await state.readBackupRecovery(), isNull);
      expect(await service.hasPendingRecovery, false);
    },
  );
}
