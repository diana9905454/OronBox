import 'dart:convert';
import 'dart:io';

import '../../support/memory_secure_storage.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/core/services/private_app_state.dart';
import 'package:oronbox/src/core/services/shared_prefs_service.dart';
import 'package:oronbox/src/core/storage/app_data_directory_io.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late MemorySecureStorage secure;
  late PrivateAppState store;
  final prefs = SharedPrefsService.instance;
  final device = jsonEncode({
    'addr': 'AA:BB:CC:DD:EE:FF',
    'authkey': 'test-key',
    'extra': 7,
  });
  PrivateAppState reopen() => PrivateAppState(
    secureStorage: secure,
    lock: IoAppDataDirectory(directory),
  );
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('oronbox-private-test-');
    secure = MemorySecureStorage();
    SharedPreferences.setMockInitialValues({
      'mi.account.token': 'current-xiaomi-session',
      'mi_account.session': 'older-xiaomi-session',
      'huami.account.token': 'huami-session',
      'huami.account.username': 'user',
      'paired_devices': [device],
      'app_theme_mode': 'dark',
    });
    await prefs.init();
    await prefs.reload();
    store = reopen();
  });
  tearDown(() async => directory.delete(recursive: true));
  test(
    'migrates exact records before removing only scoped preferences',
    () async {
      await store.initialize();
      expect(
        store.readString(PrivateAppState.miToken),
        'current-xiaomi-session',
      );
      expect(store.readStringList(PrivateAppState.pairedDevices), [device]);
      expect(prefs.value('mi.account.token'), isNull);
      expect(prefs.value('mi_account.session'), isNull);
      expect(prefs.value('paired_devices'), isNull);
      expect(prefs.getString('app_theme_mode'), 'dark');
      final restarted = reopen();
      await restarted.initialize();
      expect(restarted.readString(PrivateAppState.huamiToken), 'huami-session');
      expect(restarted.readStringList(PrivateAppState.pairedDevices), [device]);
    },
  );
  test('failed secure writes retain the original preferences', () async {
    secure.failWrites = true;
    await expectLater(
      store.initialize(),
      throwsA(isA<PrivateStateException>()),
    );
    expect(prefs.getString('mi.account.token'), 'current-xiaomi-session');
    expect(prefs.getStringList('paired_devices'), [device]);
    secure.failWrites = false;
    await store.initialize();
    expect(store.readStringList(PrivateAppState.pairedDevices), [device]);
  });
  test('readback mismatch never deletes the legacy source', () async {
    secure.mismatch = true;
    await expectLater(
      store.initialize(),
      throwsA(isA<PrivateStateException>()),
    );
    expect(prefs.getString('mi.account.token'), 'current-xiaomi-session');
    expect(prefs.getStringList('paired_devices'), [device]);
  });
  test(
    'a partial migration resumes without losing completed or pending groups',
    () async {
      secure.values['oronbox.private.xiaomi.v1'] = jsonEncode({
        'version': 1,
        'values': {PrivateAppState.miToken: 'current-xiaomi-session'},
      });
      await prefs.remove('mi.account.token');
      await prefs.remove('mi_account.session');
      expect(prefs.getStringList('paired_devices'), [device]);

      await store.initialize();
      expect(
        store.readString(PrivateAppState.miToken),
        'current-xiaomi-session',
      );
      expect(store.readString(PrivateAppState.huamiToken), 'huami-session');
      expect(store.readStringList(PrivateAppState.pairedDevices), [device]);
      expect(prefs.getStringList('paired_devices'), isNull);

      final restarted = reopen();
      await restarted.initialize();
      expect(
        restarted.readString(PrivateAppState.miToken),
        'current-xiaomi-session',
      );
      expect(restarted.readString(PrivateAppState.huamiToken), 'huami-session');
      expect(restarted.readStringList(PrivateAppState.pairedDevices), [device]);
    },
  );
  test(
    'corrupt protected state does not fall back to or erase legacy data',
    () async {
      secure.values['oronbox.private.vault.v1'] = 'corrupt';
      await expectLater(
        store.initialize(),
        throwsA(isA<PrivateStateException>()),
      );
      expect(prefs.getString('mi.account.token'), 'current-xiaomi-session');
    },
  );
  test('logout tombstones prevent reimport and keep other accounts', () async {
    await store.initialize();
    await store.update({PrivateAppState.miToken: null});
    await prefs.setString('mi_account.session', 'stale-session');
    final restarted = reopen();
    await restarted.initialize();
    expect(restarted.readString(PrivateAppState.miToken), isNull);
    expect(restarted.readString(PrivateAppState.huamiToken), 'huami-session');
    expect(restarted.readStringList(PrivateAppState.pairedDevices), [device]);
  });
  test('separate instances merge serialized account updates', () async {
    await store.initialize();
    final other = reopen();
    await other.initialize();
    await Future.wait([
      store.update({PrivateAppState.huamiToken: 'new-session'}),
      other.update({PrivateAppState.huamiUsername: 'new-user'}),
    ]);
    final restarted = reopen();
    await restarted.initialize();
    expect(restarted.readString(PrivateAppState.huamiToken), 'new-session');
    expect(restarted.readString(PrivateAppState.huamiUsername), 'new-user');
  });
  test(
    'reloading with corrupt vault throws and preserves in-memory state',
    () async {
      await store.initialize();
      secure.values['oronbox.private.vault.v1'] = 'corrupt';
      await expectLater(
        store.reload(key: PrivateAppState.huamiToken),
        throwsA(isA<PrivateStateException>()),
      );
      expect(
        store.readString(PrivateAppState.miToken),
        'current-xiaomi-session',
      );
    },
  );
  test(
    'missing protected records cannot be mistaken for a new installation',
    () async {
      await store.initialize();
      secure.values.remove('oronbox.private.vault.v1');
      final restarted = reopen();
      await expectLater(
        restarted.initialize(),
        throwsA(isA<PrivateStateException>()),
      );
      expect(secure.values.containsKey('oronbox.private.vault.v1'), false);
    },
  );
  test(
    'conditional invalidation cannot delete a newly replaced session',
    () async {
      await store.initialize();
      final other = reopen();
      await other.initialize();
      await other.update({PrivateAppState.miToken: 'new-session'});
      final removed = await store.update(
        {PrivateAppState.miToken: null},
        when: (current) =>
            current[PrivateAppState.miToken] == 'current-xiaomi-session',
      );
      expect(removed, false);
      await store.reload();
      expect(store.readString(PrivateAppState.miToken), 'new-session');
    },
  );
  test(
    'failed updates preserve the previous in-memory and durable state',
    () async {
      await store.initialize();
      secure.failWrites = true;
      await expectLater(
        store.update({PrivateAppState.pairedDevices: <String>[]}),
        throwsA(isA<PrivateStateException>()),
      );
      expect(store.readStringList(PrivateAppState.pairedDevices), [device]);
      secure.failWrites = false;
      final restarted = reopen();
      await restarted.initialize();
      expect(restarted.readStringList(PrivateAppState.pairedDevices), [device]);
    },
  );
  test('keystore read failure auto-rescues legacy preferences', () async {
    secure.failReadCount = 1;
    await store.initialize();
    expect(
      store.readString(PrivateAppState.miToken),
      'current-xiaomi-session',
    );
    expect(store.readString(PrivateAppState.huamiToken), 'huami-session');
    expect(store.readStringList(PrivateAppState.pairedDevices), [device]);
  });
  test('resetCorruptedState wipes vault and tombstones, leaving store clean and ready', () async {
    await store.initialize();
    await store.resetCorruptedState();
    expect(store.isReady, isTrue);
    expect(store.readString(PrivateAppState.miToken), isNull);
    expect(store.readStringList(PrivateAppState.pairedDevices), isNull);
    expect(await File('${directory.path}/vault.present').exists(), isFalse);
  });
}
