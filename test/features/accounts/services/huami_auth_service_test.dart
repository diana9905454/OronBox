import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/core/services/private_app_state.dart';
import 'package:oronbox/src/core/services/shared_prefs_service.dart';
import 'package:oronbox/src/core/storage/app_data_directory_io.dart';
import 'package:oronbox/src/features/accounts/services/huami_auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/memory_secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('restores, replaces and signs out Huami credentials without affecting Xiaomi', () async {
    final directory = await Directory.systemTemp.createTemp(
      'oronbox-huami-test-',
    );
    final secure = MemorySecureStorage();
    final lock = IoAppDataDirectory(directory);
    final store = PrivateAppState(secureStorage: secure, lock: lock);
    PrivateAppState.instanceForTesting = store;
    addTearDown(() async {
      PrivateAppState.instanceForTesting = null;
      await directory.delete(recursive: true);
    });
    SharedPreferences.setMockInitialValues({
      'mi.account.token': 'xiaomi-session',
      'huami.account.username': 'old-user',
      'huami.account.token': jsonEncode({
        'app_token': 'old-app-token',
        'user_id': '42',
        'country_code': 'CN',
      }),
    });
    await SharedPrefsService.instance.init();
    await store.initialize();
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            final body = options.uri.host == 'api-user.huami.com'
                ? <String, Object?>{'access': 'test-access'}
                : options.uri.host == 'account.huami.com'
                ? <String, Object?>{
                    'token_info': {
                      'app_token': 'new-app-token',
                      'user_id': '43',
                    },
                  }
                : <String, Object?>{};
            handler.resolve(
              Response<Object?>(
                requestOptions: options,
                statusCode: 200,
                data: body,
              ),
            );
          },
        ),
      );
    ProviderContainer open() => ProviderContainer(
      overrides: [
        huamiAuthProvider.overrideWith(() => HuamiAuthNotifier(dio: dio)),
      ],
    );
    final container = open();
    addTearDown(container.dispose);
    expect(container.read(huamiAuthProvider).token?.appToken, 'old-app-token');
    await container
        .read(huamiAuthProvider.notifier)
        .login(username: 'new-user', password: 'test-password');
    final restarted = PrivateAppState(secureStorage: secure, lock: lock);
    await restarted.initialize();
    PrivateAppState.instanceForTesting = restarted;
    final restored = open();
    addTearDown(restored.dispose);
    expect(restored.read(huamiAuthProvider).token?.appToken, 'new-app-token');
    expect(restored.read(huamiAuthProvider).username, 'new-user');
    await restored.read(huamiAuthProvider.notifier).signOut();
    final signedOut = PrivateAppState(secureStorage: secure, lock: lock);
    await signedOut.initialize();
    expect(signedOut.readString(PrivateAppState.huamiToken), isNull);
    expect(signedOut.readString(PrivateAppState.huamiUsername), isNull);
    expect(signedOut.readString(PrivateAppState.miToken), 'xiaomi-session');
    expect(
      SharedPrefsService.instance.getString('huami.account.token'),
      isNull,
    );
  });
}
