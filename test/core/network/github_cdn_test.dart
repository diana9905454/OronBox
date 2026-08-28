import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/core/network/github_cdn.dart';

class _RecordingAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody(Stream<Uint8List>.fromIterable([Uint8List(0)]), 200);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('uses the shared bounded timeout for an injected Dio', () async {
    final adapter = _RecordingAdapter();
    final dio = Dio()..httpClientAdapter = adapter;

    final results = await testGithubCdns(dio: dio);

    expect(results, hasLength(3));
    expect(results.every((result) => result.$2 != null), isTrue);
    expect(adapter.requests, hasLength(3));
    for (final request in adapter.requests) {
      expect(request.method, 'HEAD');
      expect(request.connectTimeout, githubCdnProbeTimeout);
      expect(request.sendTimeout, githubCdnProbeTimeout);
      expect(request.receiveTimeout, githubCdnProbeTimeout);
    }
  });
}
