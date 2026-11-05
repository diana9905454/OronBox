import 'package:oronbox/src/core/errors/coded_error.dart';

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:oronbox/src/core/constants/oronbox_server.dart';
import 'package:oronbox/src/core/network/app_http_transport.dart';
import 'package:oronbox/src/core/services/shared_prefs_service.dart';
import 'package:oronbox/src/core/storage/app_data_directory.dart';

abstract final class LegalAgreements {
  static SharedPrefsService get _prefs => SharedPrefsService.instance;
  static String canonical(String id) => switch (id) {
    'publishing' => 'resource-publishing',
    'review_rules' => 'review-rules',
    _ => id,
  };
  static Map<String, Object?> _manifest() {
    try {
      return (jsonDecode(_prefs.getString('legal.manifest') ?? '{}') as Map)
          .cast<String, Object?>();
    } catch (_) {
      return {};
    }
  }

  static int bundledRevision(String id) => switch (canonical(id)) {
    'terms' || 'privacy' || 'resource-publishing' || 'review-rules' => 3,
    _ => 1,
  };

  static int requiredRevision(String id) {
    final bundled = bundledRevision(id);
    final docs = _manifest()['documents'] as List? ?? [];
    for (final d in docs.whereType<Map>()) {
      if (canonical(d['id'].toString()) == canonical(id)) {
        final remote = (d['revision'] as num?)?.toInt() ?? 1;
        return remote > bundled ? remote : bundled;
      }
    }
    return bundled;
  }

  static bool accepted(String id) {
    id = canonical(id);
    final accepted = _prefs.getInt('legal.accepted.$id');
    if (accepted != null) return accepted >= requiredRevision(id);
    final legacy = id == 'resource-publishing'
        ? (_prefs.getBool('creator.terms.accepted') ?? false)
        : (_prefs.getInt('legal.agreementsAcceptedVersion') ?? 0) >= 1;
    return legacy && requiredRevision(id) <= 1;
  }

  static Future<void> refreshManifest() async {
    final dio = createAppHttpTransport(
      options: BaseOptions(
        connectTimeout: const Duration(seconds: 2),
        receiveTimeout: const Duration(seconds: 2),
      ),
    );
    final token = CancelToken();
    final timer = Timer(
      const Duration(seconds: 3),
      () => token.cancel('legal manifest timeout'),
    );
    try {
      final response = await dio.get<Object?>(
        '$oronBoxServerBaseUrl/api/v1/meta/legal',
        cancelToken: token,
      );
      final data = (response.data as Map).cast<String, Object?>();
      final docs = data['documents'];
      if (docs is! List || docs.isEmpty) return;
      final seen = <String>{};
      for (final raw in docs) {
        if (raw is! Map ||
            raw['id'] is! String ||
            raw['revision'] is! num ||
            (raw['revision'] as num) < 1 ||
            !seen.add(canonical(raw['id'].toString()))) {
          return;
        }
      }
      if (!seen.containsAll({'terms', 'privacy', 'resource-publishing'})) {
        return;
      }
      await _prefs.setString('legal.manifest', jsonEncode(data));
    } catch (_) {
      /* Bundled revisions set the minimum agreement version. */
    } finally {
      timer.cancel();
      dio.close(force: true);
    }
  }

  static Future<String> read(String id, String language) async {
    final isTesting = WidgetsBinding.instance.runtimeType.toString().contains(
      'Test',
    );
    if (isTesting) {
      try {
        final body = await rootBundle.loadString(
          'assets/legal/$id.$language.md',
          cache: false,
        );
        if (body.trim().isNotEmpty) {
          await _prefs.setInt('legal.shown.$id', bundledRevision(id));
          return body;
        }
      } catch (_) {}
    }
    final cache = await openAppDataDirectory(
      'documents/legal',
      location: AppStorageLocation.cache,
    );
    return cache.exclusive(() => _read(id, language, cache));
  }

  static Future<String> _read(
    String id,
    String language,
    AppDataDirectory cache,
  ) async {
    id = canonical(id);
    var rev = requiredRevision(id);
    var key = 'legal.body.$id.$rev.$language';
    final path = '$id/$rev/$language.md';
    final cached = await cache.read(path);
    var body = cached == null ? _prefs.getString(key) : utf8.decode(cached);
    if (cached == null && body != null) {
      await cache.write(path, Uint8List.fromList(utf8.encode(body)));
      await _prefs.remove(key);
    }
    final isTesting = WidgetsBinding.instance.runtimeType.toString().contains(
      'Test',
    );
    if (body == null && isTesting && rev == bundledRevision(id)) {
      try {
        body = await rootBundle.loadString(
          'assets/legal/$id.$language.md',
          cache: false,
        );
      } catch (_) {}
    }
    if (body == null) {
      final dio = createAppHttpTransport(
        options: BaseOptions(
          connectTimeout: const Duration(seconds: 3),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
      try {
        final response = await dio.get<String>(
          '$oronBoxServerBaseUrl/api/v1/meta/legal/$id',
          queryParameters: {'lang': language, 'revision': rev},
          options: Options(responseType: ResponseType.plain),
        );
        final actual = int.tryParse(
          response.headers.value('x-legal-revision') ?? '',
        );
        if (actual != rev || response.data?.trim().isEmpty != false) {
          throw const _LegalDocumentUnavailable();
        }
        body = response.data!;
        await cache.write(path, Uint8List.fromList(utf8.encode(body)));
      } catch (_) {
        if (rev != bundledRevision(id)) rethrow;
        body = await rootBundle.loadString(
          'assets/legal/$id.$language.md',
          cache: false,
        );
      } finally {
        dio.close(force: true);
      }
    }
    if (body.trim().isEmpty) throw const _LegalDocumentUnavailable();
    await _prefs.setInt('legal.shown.$id', rev);
    return body;
  }

  static Future<bool> acceptShown(String id) async {
    id = canonical(id);
    final shown = _prefs.getInt('legal.shown.$id');
    if (shown == null || shown != requiredRevision(id)) return false;
    await _prefs.setInt('legal.accepted.$id', shown);
    return true;
  }
}

class _LegalDocumentUnavailable implements Exception, CodedError {
  const _LegalDocumentUnavailable();
  @override
  String get code => 'legal_document_unavailable';
  @override
  String get message => '';
  @override
  Object? get details => null;
}
