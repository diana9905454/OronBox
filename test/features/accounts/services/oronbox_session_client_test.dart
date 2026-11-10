import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/features/accounts/services/bandbbs_auth_service.dart';
import 'package:oronbox/src/features/accounts/services/oronbox_session_client.dart';

void main() {
  test('injects the current OronBox session', () async {
    final access = _FakeSessionAccess(_session());
    final client = OronBoxSessionClient(access);

    final response = await client.send<String>((authorization) async {
      expect(authorization.headers?['Authorization'], 'Bearer access');
      return Response(requestOptions: RequestOptions(), data: 'ok');
    });

    expect(response.data, 'ok');
    expect(access.expireCalls, 0);
  });

  test('rejects requests without a session before sending', () async {
    final client = OronBoxSessionClient(_FakeSessionAccess(null));
    var sent = false;

    await expectLater(
      client.send<void>((_) async {
        sent = true;
        return Response(requestOptions: RequestOptions());
      }),
      throwsA(isA<OronBoxAuthRequiredException>()),
    );
    expect(sent, isFalse);
  });

  test('preserves the RT when the retried AT is rejected', () async {
    final access = _FakeSessionAccess(_session());
    final client = OronBoxSessionClient(access);
    final request = RequestOptions(path: '/api/v1/coins');

    await expectLater(
      client.send<void>((_) async {
        throw DioException(
          requestOptions: request,
          response: Response(
            requestOptions: request,
            statusCode: 401,
            data: {'error': 'unauthorized'},
          ),
          type: DioExceptionType.badResponse,
        );
      }),
      throwsA(isA<DioException>()),
    );
    expect(access.expireCalls, 0);
  });

  test('does not expire the session for non-authentication failures', () async {
    final access = _FakeSessionAccess(_session());
    final client = OronBoxSessionClient(access);
    final request = RequestOptions(path: '/api/v1/coins');

    await expectLater(
      client.send<void>((_) async {
        throw DioException(
          requestOptions: request,
          response: Response(requestOptions: request, statusCode: 503),
          type: DioExceptionType.badResponse,
        );
      }),
      throwsA(isA<DioException>()),
    );
    expect(access.expireCalls, 0);
  });

  test('does not clear credentials for an unidentified 401', () async {
    final access = _FakeSessionAccess(_session(), expireFailure: true);
    final client = OronBoxSessionClient(access);
    final request = RequestOptions(path: '/api/v1/coins');

    await expectLater(
      client.send<void>((_) async {
        throw DioException(
          requestOptions: request,
          response: Response(requestOptions: request, statusCode: 401),
          type: DioExceptionType.badResponse,
        );
      }),
      throwsA(isA<DioException>()),
    );
    expect(access.expireCalls, 0);
  });
}

OronBoxSession _session() => OronBoxSession(
  accessToken: 'access',
  refreshToken: 'refresh',
  expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
);

class _FakeSessionAccess implements OronBoxSessionAccess {
  _FakeSessionAccess(this.session, {this.expireFailure = false});

  OronBoxSession? session;
  final bool expireFailure;
  int expireCalls = 0;

  @override
  Future<OronBoxSession?> sessionIfNeeded({bool forceRefresh = false}) async =>
      session;

  @override
  Future<void> expireSession() async {
    expireCalls += 1;
    if (expireFailure) throw StateError('host unavailable');
    session = null;
  }
}
