import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:oronbox/src/core/constants/oronbox_server.dart';

/// Only a per-build derived key is embedded. The master key belongs on the
/// server/build machine and must never be passed as a Dart define.
class ClientAttestationConfig {
  const ClientAttestationConfig({
    this.tag = const String.fromEnvironment('OB_AUTH_TAG'),
    this.commit = const String.fromEnvironment('OB_AUTH_COMMIT'),
    this.releaseKeyHex = const String.fromEnvironment('OB_RELEASE_KEY'),
  });
  final String tag;
  final String commit;
  final String releaseKeyHex;

  List<int>? get key {
    if (!RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(releaseKeyHex) ||
        tag.isEmpty ||
        commit.isEmpty) {
      return null;
    }
    return [
      for (var i = 0; i < 64; i += 2)
        int.parse(releaseKeyHex.substring(i, i + 2), radix: 16),
    ];
  }
}

class ClientAttestationInterceptor extends Interceptor {
  ClientAttestationInterceptor({
    this.config = const ClientAttestationConfig(),
    String serverBaseUrl = oronBoxServerBaseUrl,
    DateTime Function()? clock,
  }) : _origin = Uri.parse(serverBaseUrl),
       _clock = clock ?? DateTime.now;

  final ClientAttestationConfig config;
  final Uri _origin;
  final DateTime Function() _clock;
  final Random _random = Random.secure();

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final uri = options.uri;
    if (uri.scheme != _origin.scheme ||
        uri.host != _origin.host ||
        uri.port != _origin.port ||
        !uri.path.startsWith('/api/v1/')) {
      handler.next(options);
      return;
    }
    final publicContent = RegExp(
      r'^/api/v1/(blobs/[^/]+|plugins/[^/]+/(icon|package))$',
    ).hasMatch(uri.path);
    if (publicContent &&
        (options.method == 'GET' || options.method == 'HEAD')) {
      handler.next(options);
      return;
    }
    final key = config.key;
    if (key == null) {
      handler.next(options);
      return;
    }
    try {
      final data = options.data;
      late final List<int> body;
      if (data == null) {
        body = const [];
      } else if (data is List<int>) {
        body = data;
      } else if (data is String) {
        body = utf8.encode(data);
      } else if (data is Map || data is List) {
        body = utf8.encode(jsonEncode(data));
        options.contentType = 'application/json';
      } else {
        throw const FormatException('Unsupported signed request body');
      }
      // Pin the actual wire bytes so Dio cannot transform the signed payload.
      if (data != null) options.data = Uint8List.fromList(body);
      options.followRedirects = false;
      final ts = _clock().toUtc().millisecondsSinceEpoch ~/ 1000;
      final nonce = List.generate(
        16,
        (_) => _random.nextInt(256),
      ).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      final path = '${uri.path}${uri.hasQuery ? '?${uri.query}' : ''}';
      final canonical =
          '${options.method.toUpperCase()}\n$path\n$ts\n$nonce\n${sha256.convert(body)}';
      final signature = base64UrlEncode(
        Hmac(sha256, key).convert(utf8.encode(canonical)).bytes,
      ).replaceAll('=', '');
      options.headers.addAll({
        'X-OB-Tag': config.tag,
        'X-OB-Commit': config.commit,
        'X-OB-Timestamp': '$ts',
        'X-OB-Nonce': nonce,
        'X-OB-Signature': signature,
      });
      handler.next(options);
    } catch (error) {
      handler.reject(DioException(requestOptions: options, error: error));
    }
  }
}
