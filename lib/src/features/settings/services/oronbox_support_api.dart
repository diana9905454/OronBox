import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oronbox/src/commands/command_protocol.dart';
import 'package:oronbox/src/core/constants/app_constants.dart';
import 'package:oronbox/src/core/constants/oronbox_server.dart';
import 'package:oronbox/src/core/network/dio_provider.dart';
import 'package:oronbox/src/core/network/github_release.dart';
import 'package:oronbox/src/host/application_host_provider.dart';

final oronBoxSupportApiProvider = Provider<OronBoxSupportApi>(
  (ref) => OronBoxSupportApi(
    ref.watch(appDioProvider),
    ref.watch(applicationHostProvider),
  ),
);

class OronBoxSupportApi {
  OronBoxSupportApi(this._dio, this._host);
  final Dio _dio;
  final OronBoxCommandBus _host;

  Future<String> legalDocument(String id, {required String language}) async =>
      (await _dio.get<String>(
        '$oronBoxServerBaseUrl/api/v1/meta/legal/$id',
        queryParameters: {'lang': language},
        options: Options(responseType: ResponseType.plain),
      )).data ??
      '';

  Future<AppReleaseInfo> latestRelease({
    required String language,
    required String currentVersion,
  }) async {
    try {
      final response = await _dio.get<Object?>(
        '$oronBoxServerBaseUrl/api/v1/app/releases',
        queryParameters: {
          'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
          'arch': '',
          'channel': 'stable',
          'lang': language,
          'version': currentVersion,
        },
      );
      return AppReleaseInfo.fromJson(_map(response.data));
    } on DioException {
      final response = await _dio.get<Object?>(
        'https://api.github.com/repos/OronCanopy/OronBox/releases/latest',
        options: Options(headers: {'Accept': 'application/vnd.github+json'}),
      );
      final release = GitHubRelease.fromJson(_map(response.data));
      if (release.tagName.isEmpty) rethrow;
      return AppReleaseInfo(
        latestVersion: release.tagName,
        tag: release.tagName,
        serverPolicyAvailable: false,
        releaseNotes: release.body,
        sourceUrl:
            _map(response.data)['html_url']?.toString() ??
            '${AppConstants.githubRepoUrl}/releases/latest',
      );
    }
  }

  Future<List<FeedbackTicket>> feedback() async {
    final root = _map(await _execute('support.feedback.list'));
    return (root['tickets'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => FeedbackTicket.fromJson(e.cast<String, Object?>()))
        .toList();
  }

  Future<FeedbackTicket> feedbackDetail(String id) async {
    return FeedbackTicket.fromJson(
      _map(await _execute('support.feedback.get', {'ticket': id})),
    );
  }

  Future<FeedbackTicket> createFeedback({
    required String kind,
    required String subject,
    required String message,
    String targetSource = '',
    String targetId = '',
    String targetUrl = '',
  }) async {
    return FeedbackTicket.fromJson(
      _map(
        await _execute('support.feedback.create', {
          'kind': kind,
          'subject': subject,
          'message': message,
          'targetSource': targetSource,
          'targetId': targetId,
          'targetUrl': targetUrl,
        }),
      ),
    );
  }

  Future<FeedbackTicket> replyFeedback(String id, String message) async {
    return FeedbackTicket.fromJson(
      _map(
        await _execute('support.feedback.reply', {
          'ticket': id,
          'message': message,
        }),
      ),
    );
  }

  Future<Object?> _execute(
    String method, [
    Map<String, Object?> params = const {},
  ]) async {
    final result = await _host.execute(
      OronBoxCommand(method: method, params: params),
    );
    if (!result.ok) {
      throw result.error!;
    }
    return result.value;
  }

  Map<String, Object?> _map(Object? value) =>
      value is Map ? value.cast<String, Object?>() : const {};
}

class AppReleaseInfo {
  const AppReleaseInfo({
    required this.latestVersion,
    this.minimumVersion = '',
    this.releaseNotes = '',
    this.tag = '',
    this.serverPolicyAvailable = true,
    this.sourceUrl = '',
  });
  final String latestVersion, minimumVersion, releaseNotes, tag, sourceUrl;
  final bool serverPolicyAvailable;
  factory AppReleaseInfo.fromJson(Map<String, Object?> j) => AppReleaseInfo(
    latestVersion: j['latest_version']?.toString() ?? '',
    minimumVersion: j['minimum_version']?.toString() ?? '',
    releaseNotes: j['release_notes']?.toString() ?? '',
    tag: j['tag']?.toString() ?? '',
    sourceUrl:
        '${AppConstants.githubRepoUrl}/releases/tag/${Uri.encodeComponent(j['tag']?.toString() ?? '')}',
  );
}

class FeedbackTicket {
  const FeedbackTicket({
    required this.id,
    required this.kind,
    required this.subject,
    required this.message,
    required this.status,
    required this.createdAt,
    this.targetSource = '',
    this.targetId = '',
    this.resolution = '',
    this.replies = const [],
    required this.updatedAt,
  });
  final String id,
      kind,
      subject,
      message,
      status,
      targetSource,
      targetId,
      resolution;
  final DateTime createdAt, updatedAt;
  final List<FeedbackReply> replies;
  factory FeedbackTicket.fromJson(Map<String, Object?> j) => FeedbackTicket(
    id: j['id']?.toString() ?? '',
    kind: j['kind']?.toString() ?? '',
    subject: j['subject']?.toString() ?? '',
    message: j['message']?.toString() ?? '',
    status: j['status']?.toString() ?? 'open',
    targetSource: j['target_source']?.toString() ?? '',
    targetId: j['target_id']?.toString() ?? '',
    resolution: j['resolution']?.toString() ?? '',
    createdAt:
        DateTime.tryParse(j['created_at']?.toString() ?? '') ?? DateTime.now(),
    updatedAt:
        DateTime.tryParse(j['updated_at']?.toString() ?? '') ?? DateTime.now(),
    replies: (j['replies'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => FeedbackReply.fromJson(e.cast<String, Object?>()))
        .toList(),
  );
}

class FeedbackReply {
  const FeedbackReply({
    required this.author,
    required this.message,
    required this.createdAt,
  });
  final String author, message;
  final DateTime createdAt;
  factory FeedbackReply.fromJson(Map<String, Object?> j) => FeedbackReply(
    author: j['author']?.toString() ?? '',
    message: j['message']?.toString() ?? '',
    createdAt:
        DateTime.tryParse(j['created_at']?.toString() ?? '') ?? DateTime.now(),
  );
}
