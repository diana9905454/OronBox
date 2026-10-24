import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:oronbox/src/core/services/private_app_state.dart';
import 'package:oronbox/src/core/storage/app_data_directory_io.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/features/accounts/models/mi_account_models.dart';
import 'package:oronbox/src/features/accounts/services/mi_account_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final root = await Directory.systemTemp.createTemp(
      'oronbox-mi-session-test-',
    );
    PrivateAppState.instanceForTesting = PrivateAppState(
      lock: IoAppDataDirectory(root),
    );
    await PrivateAppState.instance.initialize();
    addTearDown(() async {
      PrivateAppState.instanceForTesting = null;
      await root.delete(recursive: true);
    });
  });

  test('clears the stored Xiaomi session after an HTTP auth failure', () async {
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            final response = Response<Object?>(
              requestOptions: options,
              statusCode: 401,
            );
            handler.reject(
              DioException(
                requestOptions: options,
                response: response,
                type: DioExceptionType.badResponse,
              ),
            );
          },
        ),
      );
    final service = MiAccountService(dio: dio);
    final token = _token();
    await service.persistToken(token);

    await expectLater(
      service.fetchBoundDevices(token: token),
      throwsA(
        isA<MiAccountSessionExpired>().having(
          (error) => error.statusCode,
          'statusCode',
          401,
        ),
      ),
    );
    expect(await service.loadStoredToken(), isNull);
  });

  test('refreshes a Xiaomi service session with the pass token', () async {
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.uri.path.endsWith('/serviceLogin')) {
              handler.resolve(
                Response<String>(
                  requestOptions: options,
                  statusCode: 200,
                  data:
                      '&&&START&&&{"code":0,"userId":"10001",'
                      '"ssecurity":"bmV3LXNlY3VyaXR5",'
                      '"location":"https://account.xiaomi.com/sts",'
                      '"psecurity":"new-psecurity"}',
                ),
              );
              return;
            }
            if (options.uri.toString() == 'https://account.xiaomi.com/sts') {
              handler.resolve(
                Response<String>(
                  requestOptions: options,
                  statusCode: 200,
                  headers: Headers.fromMap({
                    'set-cookie': ['serviceToken=new-service-token; Path=/'],
                  }),
                  data: '',
                ),
              );
              return;
            }
            handler.next(options);
          },
        ),
      );
    final service = MiAccountService(dio: dio);
    final token = _token();
    await service.persistToken(token);

    final refreshed = await service.refreshToken(token: token);

    expect(refreshed.ssecurity, 'bmV3LXNlY3VyaXR5');
    expect(refreshed.serviceToken, 'new-service-token');
    expect(refreshed.passToken, token.passToken);
    expect(
      (await service.loadStoredToken())?.serviceToken,
      'new-service-token',
    );
  });

  test(
    'does not clear a newer Xiaomi session after an old request fails',
    () async {
      final service = MiAccountService();
      final oldToken = _token();
      const newToken = MiAccountToken(
        userId: '10002',
        deviceId: 'device-new',
        ssecurity: 'bmV3LXNlY3VyaXR5',
        serviceToken: 'new-service-token',
        cUserId: 'new-c-user-id',
        passToken: 'new-pass-token',
        psecurity: 'new-psecurity',
      );
      await service.persistToken(newToken);

      await service.invalidateStoredToken(oldToken);

      expect((await service.loadStoredToken())?.toJson(), newToken.toJson());
    },
  );
}

const _tokenValue = 'c2VjdXJpdHk=';

MiAccountToken _token() => const MiAccountToken(
  userId: '10001',
  deviceId: 'device-id',
  ssecurity: _tokenValue,
  serviceToken: 'service-token',
  cUserId: 'c-user-id',
  passToken: 'pass-token',
  psecurity: 'psecurity',
);
