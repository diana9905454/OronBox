import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:oronbox/src/core/logging/logging_service.dart';

/// Logs failed HTTP operations. Successful requests remain quiet by default.
/// Query strings, headers and request bodies are deliberately excluded because
/// they routinely contain login credentials or private user content.
class HttpObservabilityInterceptor extends Interceptor {
  HttpObservabilityInterceptor({Logger? logger})
    : _log = logger ?? getLogger('HTTP');

  static const _startedAtKey = 'oronbox.http.startedAt';
  final Logger _log;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_startedAtKey] = DateTime.now().microsecondsSinceEpoch;
    handler.next(options);
  }

  @override
  void onResponse(
    Response<Object?> response,
    ResponseInterceptorHandler handler,
  ) {
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final response = err.response;
    final summary = safeHttpErrorSummary(response?.data);
    logDiagnostic(
      _log,
      (response?.statusCode ?? 0) >= 500 || response == null
          ? Level.SEVERE
          : Level.WARNING,
      'HTTP ${err.requestOptions.method} ${safeHttpEndpoint(err.requestOptions.uri)}: '
      '${response?.statusCode ?? err.type.name}'
      '${summary['serverCode'] == null ? '' : ' (${summary['serverCode']})'}',
      fields: {
        'method': err.requestOptions.method,
        'endpoint': safeHttpEndpoint(err.requestOptions.uri),
        if (response?.statusCode case final status?) 'status': status,
        'durationMs': _durationMs(err.requestOptions),
        'errorType': err.type.name,
        if (httpRequestId(response) case final requestId?)
          'requestId': requestId,
        ...summary,
      },
    );
    handler.next(err);
  }

  int _durationMs(RequestOptions options) {
    final started = options.extra[_startedAtKey];
    if (started is! int) return 0;
    return ((DateTime.now().microsecondsSinceEpoch - started) / 1000).round();
  }
}

String? httpRequestId(Response<dynamic>? response) {
  final value = response?.headers.value('x-request-id')?.trim();
  if (value == null || value.isEmpty) return null;
  return value.length <= 128 ? value : '${value.substring(0, 125)}...';
}

void installHttpObservability(Dio dio, {Logger? logger}) {
  if (dio.interceptors.any((item) => item is HttpObservabilityInterceptor)) {
    return;
  }
  dio.interceptors.add(HttpObservabilityInterceptor(logger: logger));
}

String safeHttpEndpoint(Uri uri) {
  final host = uri.host;
  final path = _safeHttpPath(uri);
  if (host.isEmpty) return path;
  final port = uri.hasPort ? ':${uri.port}' : '';
  return '${uri.scheme}://$host$port$path';
}

Map<String, Object?> safeHttpErrorSummary(Object? data) {
  if (data is Map) {
    final root = data.cast<Object?, Object?>();
    final nested = root['error'];
    final nestedMap = nested is Map ? nested.cast<Object?, Object?>() : null;
    final code =
        nestedMap?['code'] ??
        (nested is String ? nested : null) ??
        root['code'];
    final message = nestedMap?['message'] ?? root['message'];
    return {
      if (code != null) 'serverCode': _safeServerText(code.toString()),
      if (message != null) 'serverMessage': _safeServerText(message.toString()),
    };
  }
  if (data is String && data.isNotEmpty) {
    // Arbitrary text and HTML responses are not part of the OronBox error
    // contract and can contain reflected credentials. Keep only their shape.
    return {'responseBody': '<text:${utf8.encode(data).length} bytes>'};
  }
  return const {};
}

String _safeHttpPath(Uri uri) {
  if (uri.pathSegments.isEmpty) return '/';
  final segments = <String>[];
  for (var index = 0; index < uri.pathSegments.length; index++) {
    final segment = uri.pathSegments[index];
    final previous = index == 0
        ? ''
        : uri.pathSegments[index - 1].toLowerCase();
    final containsIdentity =
        segment.contains('@') ||
        RegExp(r'^\+?\d{7,}$').hasMatch(segment) ||
        RegExp(
          r'^(?:bearer\s+)?eyj[a-z0-9._~-]+$',
          caseSensitive: false,
        ).hasMatch(segment);
    final followsSensitiveSegment = const {
      'registrations',
      'ticket',
      'token',
      'secret',
      'password',
      'credential',
    }.contains(previous);
    segments.add(
      containsIdentity || followsSensitiveSegment
          ? ':redacted'
          : Uri.encodeComponent(segment),
    );
  }
  return '/${segments.join('/')}';
}

String _safeServerText(String value) {
  var text = value;
  text = text.replaceAllMapped(
    RegExp(
      r'\b(authorization|access[_-]?token|refresh[_-]?token|token|ticket|secret|password)\b\s*[:=]\s*(?:bearer\s+)?[^\s,;]+',
      caseSensitive: false,
    ),
    (match) => '${match.group(1)}=<redacted>',
  );
  text = text.replaceAll(
    RegExp(r'\bbearer\s+[a-z0-9._~+/=-]+', caseSensitive: false),
    'Bearer <redacted>',
  );
  return _compact(text);
}

String _compact(String value) {
  final text = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  return text.length <= 300 ? text : '${text.substring(0, 297)}...';
}
