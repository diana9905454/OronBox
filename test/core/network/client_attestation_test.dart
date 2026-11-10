import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/core/network/client_attestation_interceptor.dart';
import 'package:oronbox/src/features/accounts/services/bandbbs_auth_service.dart';

void main() {
  test('signature covers actual JSON/binary wire bytes and query, with fresh nonces', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://ob.example'));
    dio.interceptors.add(
      ClientAttestationInterceptor(
        config: ClientAttestationConfig(
          tag: '1.1.3',
          commit: 'abcdef0123',
          releaseKeyHex: List.filled(32, '11').join(),
        ),
        serverBaseUrl: 'https://ob.example',
        clock: () => DateTime.fromMillisecondsSinceEpoch(1760000000000),
      ),
    );
    final nonces = <String>{};
    var count = 0;
    dio.httpClientAdapter = _Adapter((options, body) {
      final nonce = options.headers['X-OB-Nonce'] as String;
      expect(nonces.add(nonce), isTrue);
      final canonical =
          '${options.method}\n${options.uri.path}?${options.uri.query}\n1760000000\n$nonce\n${sha256.convert(body)}';
      final signature = base64UrlEncode(
        Hmac(sha256, List.filled(32, 17)).convert(utf8.encode(canonical)).bytes,
      ).replaceAll('=', '');
      expect(options.headers['X-OB-Signature'], signature);
      if (count == 0) expect(jsonDecode(utf8.decode(body)), {'text': '米坛'});
      if (count == 1) expect(body, [0, 255, 12]);
      expect(options.followRedirects, isFalse);
      count++;
    });
    await dio.post<void>('/api/v1/test?q=a%20b', data: {'text': '米坛'});
    await dio.post<void>(
      '/api/v1/test?q=a%20b',
      data: Uint8List.fromList([0, 255, 12]),
    );
    await dio.get<void>('/api/v1/test?q=a%20b');
    expect(count, 3);
  });

  test(
    'never signs third-party, different-port or public delivery requests',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://ob.example'));
      dio.interceptors.add(
        ClientAttestationInterceptor(
          config: ClientAttestationConfig(
            tag: '1.1.3',
            commit: 'abcdef0123',
            releaseKeyHex: List.filled(32, '11').join(),
          ),
          serverBaseUrl: 'https://ob.example',
        ),
      );
      dio.httpClientAdapter = _Adapter(
        (options, _) =>
            expect(options.headers.containsKey('X-OB-Signature'), isFalse),
      );
      for (final path in [
        'https://github.com/api/v1/x',
        'https://ob.example:8080/api/v1/x',
        '/api/v1/blobs/hash',
        '/api/v1/plugins/id/package',
      ]) {
        await dio.get<void>(path);
      }
    },
  );

  test('build/clock rejection never expires user credentials', () {
    for (final code in [
      'client_attestation_missing',
      'request_expired',
      'nonce_replayed',
      'signature_mismatch',
    ]) {
      final r = RequestOptions();
      expect(
        isSessionAuthenticationFailure(
          DioException(
            requestOptions: r,
            response: Response(
              requestOptions: r,
              statusCode: 401,
              data: {'code': code},
            ),
          ),
        ),
        isFalse,
      );
    }
  });
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.check);
  final void Function(RequestOptions, List<int>) check;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final bytes = <int>[];
    if (requestStream != null) {
      await for (final chunk in requestStream) {
        bytes.addAll(chunk);
      }
    }
    check(options, bytes);
    return ResponseBody.fromString('', 204);
  }

  @override
  void close({bool force = false}) {}
}
