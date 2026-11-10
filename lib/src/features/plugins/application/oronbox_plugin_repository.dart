import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:oronbox/src/core/constants/oronbox_server.dart';
import 'package:oronbox/src/core/network/app_http_transport.dart';
import 'package:oronbox/src/features/accounts/services/bandbbs_auth_service.dart';
import 'package:oronbox/src/features/accounts/services/oronbox_session_client.dart';
import 'package:oronbox/src/features/plugins/application/plugin_repository.dart';

/// OronBox 原生插件源，由 OronBox-Server 提供目录、下载与发布。
class OronBoxPluginRepository implements PluginRepository {
  OronBoxPluginRepository({
    Dio? dio,
    this.baseUrl = oronBoxServerBaseUrl,
    this.accessToken,
  }) : _dio = dio ?? createAppHttpTransport();

  final Dio _dio;
  final String baseUrl;

  /// 可选的会话 token：带上后服务端会在目录里标注 owned。
  final String? Function()? accessToken;

  List<Map<String, Object?>>? _cache;

  @override
  String get id => 'oronbox';

  @override
  String get displayName => 'OronBox';

  @override
  bool get isLegacy => false;

  @override
  Future<List<PluginCatalogEntry>> load({bool force = false}) async {
    if (!force && _cache != null) return _entries(_cache!);
    final token = accessToken?.call();
    final response = await _dio.get<Object?>(
      '$baseUrl/api/v1/plugins',
      options: token == null
          ? null
          : Options(headers: {'Authorization': 'Bearer $token'}),
    );
    final root = response.data;
    if (root is! Map) {
      throw const FormatException('Invalid plugin catalog response');
    }
    final plugins = (root['plugins'] as List? ?? const [])
        .whereType<Map>()
        .map((row) => row.cast<String, Object?>())
        .toList(growable: false);
    _cache = plugins;
    return _entries(plugins);
  }

  @override
  Future<Uint8List> download(PluginCatalogEntry entry) async {
    final raw = await _raw(entry.id);
    final url = raw['packageUrl']?.toString() ?? '';
    if (url.isEmpty) {
      throw StateError('Plugin has no package URL: ${entry.id}');
    }
    final response = await _dio.get<List<int>>(
      _absolute(url),
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(response.data ?? const []);
  }

  Future<Map<String, Object?>> _raw(String id) async {
    if (_cache == null) await load();
    for (final plugin in _cache!) {
      if (plugin['id']?.toString() == id) return plugin;
    }
    throw StateError('Plugin not found in OronBox repository: $id');
  }

  List<PluginCatalogEntry> _entries(List<Map<String, Object?>> plugins) =>
      plugins
          .map((plugin) {
            final uploader =
                (plugin['uploader'] as Map?)?.cast<String, Object?>() ??
                const {};
            final icon = plugin['iconUrl']?.toString() ?? '';
            return PluginCatalogEntry(
              source: id,
              id: plugin['id']?.toString() ?? '',
              installedId: plugin['id']?.toString() ?? '',
              name: plugin['name']?.toString() ?? '',
              version: plugin['version']?.toString() ?? '',
              author: plugin['author']?.toString() ?? '',
              description: plugin['description']?.toString() ?? '',
              permissions: (plugin['permissions'] as List? ?? const [])
                  .map((value) => value.toString())
                  .toList(growable: false),
              iconUrl: icon.isEmpty ? null : _absolute(icon),
              uploaderId: uploader['id']?.toString(),
              uploaderName: uploader['username']?.toString(),
              owned: plugin['owned'] == true,
              moderationState: plugin['state']?.toString(),
              moderationReason: plugin['moderationReason']?.toString(),
            );
          })
          .toList(growable: false);

  String _absolute(String path) =>
      path.startsWith('http') ? path : '$baseUrl$path';
}

/// OronBox 源的发布端（上传/下架），需要 BandBBS 会话。
class OronBoxPluginPublisher {
  OronBoxPluginPublisher({required OronBoxSessionAccess sessions, Dio? dio})
    : _sessions = OronBoxSessionClient(sessions),
      _dio =
          dio ??
          createAppHttpTransport(
            options: BaseOptions(baseUrl: oronBoxServerBaseUrl),
          );

  final OronBoxSessionClient _sessions;
  final Dio _dio;

  Future<Map<String, Object?>> upload(Uint8List bytes) async {
    final response = await _sessions.send<Object?>(
      (authorization) => _dio.post<Object?>(
        '/api/v1/plugins',
        data: bytes,
        options: authorization.copyWith(
          contentType: 'application/octet-stream',
        ),
      ),
    );
    final data = response.data;
    if (data is! Map) {
      throw const FormatException('Invalid plugin upload response');
    }
    return data.cast<String, Object?>();
  }

  Future<void> remove(String id) async {
    await _sessions.send<Object?>(
      (authorization) => _dio.delete<Object?>(
        '/api/v1/plugins/${Uri.encodeComponent(id)}',
        options: authorization,
      ),
    );
  }
}
