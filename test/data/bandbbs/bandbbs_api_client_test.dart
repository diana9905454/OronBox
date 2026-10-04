import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/data/bandbbs/bandbbs_api_client.dart';
import 'package:oronbox/src/features/accounts/services/bandbbs_auth_service.dart';

class _FakeBandBbsAuthNotifier implements BandBbsAuthNotifier {
  _FakeBandBbsAuthNotifier({
    this.token,
    this.refreshedToken,
  });

  BandBbsToken? token;
  BandBbsToken? refreshedToken;
  int refreshCalls = 0;
  int forceRefreshCalls = 0;
  int expireCalls = 0;

  @override
  Future<BandBbsToken?> refreshIfNeeded({bool forceRefresh = false}) async {
    refreshCalls++;
    if (forceRefresh) {
      forceRefreshCalls++;
      token = refreshedToken;
      return refreshedToken;
    }
    return token;
  }

  @override
  Future<void> expireSession() async {
    expireCalls++;
    token = null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final testToken = BandBbsToken(
    accessToken: 'initial-access-token',
    tokenType: 'bearer',
    expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
    scope: '',
  );

  final freshToken = BandBbsToken(
    accessToken: 'refreshed-access-token',
    tokenType: 'bearer',
    expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
    scope: '',
  );

  test('throws OronBoxAuthRequiredException when user is not signed in', () async {
    final auth = _FakeBandBbsAuthNotifier(token: null);
    final client = BandBbsApiClient(dio: Dio(), auth: auth);

    expect(
      () => client.getResource('123'),
      throwsA(isA<OronBoxAuthRequiredException>()),
    );
  });

  test('retries request on 401 with refreshed token when force refresh succeeds', () async {
    final auth = _FakeBandBbsAuthNotifier(
      token: testToken,
      refreshedToken: freshToken,
    );

    int attempts = 0;
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          attempts++;
          if (attempts == 1) {
            expect(options.headers['Authorization'], 'Bearer initial-access-token');
            handler.reject(
              DioException(
                requestOptions: options,
                response: Response(requestOptions: options, statusCode: 401),
                type: DioExceptionType.badResponse,
              ),
            );
          } else {
            expect(options.headers['Authorization'], 'Bearer refreshed-access-token');
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {'resource_id': '123', 'title': 'Test Resource'},
              ),
            );
          }
        },
      ),
    );

    final client = BandBbsApiClient(dio: dio, auth: auth);
    final result = await client.getResource('123');

    expect(attempts, 2);
    expect(auth.forceRefreshCalls, 1);
    expect(auth.expireCalls, 0);
    expect(result['resource_id'], '123');
  });

  test('expires session and throws BandBbsSessionExpiredException when refresh fails on 401', () async {
    final auth = _FakeBandBbsAuthNotifier(
      token: testToken,
      refreshedToken: null,
    );

    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.reject(
            DioException(
              requestOptions: options,
              response: Response(requestOptions: options, statusCode: 401),
              type: DioExceptionType.badResponse,
            ),
          );
        },
      ),
    );

    bool sessionExpiredCalled = false;
    final client = BandBbsApiClient(
      dio: dio,
      auth: auth,
      onSessionExpired: () async {
        sessionExpiredCalled = true;
      },
    );

    await expectLater(
      () => client.getResource('123'),
      throwsA(isA<BandBbsSessionExpiredException>()),
    );

    expect(auth.forceRefreshCalls, 1);
    expect(auth.expireCalls, 1);
    expect(sessionExpiredCalled, isTrue);
  });
}
