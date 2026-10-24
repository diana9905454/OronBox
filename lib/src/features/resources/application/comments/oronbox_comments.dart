import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oronbox/src/commands/command_protocol.dart';
import 'package:oronbox/src/core/errors/coded_error.dart';
import 'package:oronbox/src/host/application_host_provider.dart';

final oronBoxCommentsApiProvider = Provider(
  (ref) => OronBoxCommentsApi(ref.watch(applicationHostProvider)),
);

class OronBoxCommentsApi {
  OronBoxCommentsApi(this._host);
  final OronBoxCommandBus _host;

  Future<List<OronBoxComment>> list(
    String resourceId, {
    int page = 1,
    int size = 20,
  }) async => (await listPage(resourceId, page: page, size: size)).items;

  Future<OronBoxCommentPage> listPage(
    String resourceId, {
    int page = 1,
    int size = 20,
    String before = '',
  }) async {
    final value = await _execute('comment.list', {
      'resource': resourceId,
      'page': page,
      'size': size,
      if (before.isNotEmpty) 'before': before,
    });
    final root = value is Map
        ? value.cast<String, Object?>()
        : const <String, Object?>{};
    final list = (root['items'] ?? root['comments']) as List? ?? const [];
    final total = (root['total'] as num?)?.toInt();
    final hasMore =
        root['has_more'] as bool? ??
        (total != null ? page * size < total : list.length == size);
    final parsed = list
        .whereType<Map>()
        .map((item) => OronBoxComment.fromJson(item.cast<String, Object?>()))
        .where((comment) => !comment.deleted || comment.replyCount > 0)
        .toList();
    return OronBoxCommentPage(
      items: parsed,
      hasMore: hasMore,
      nextCursor: root['next_cursor']?.toString() ?? '',
    );
  }

  Future<OronBoxComment> create(
    String resourceId,
    String body, {
    String parentId = '',
  }) async {
    final value = await _execute('comment.create', {
      'resource': resourceId,
      'body': body,
      if (parentId.isNotEmpty) 'parentId': parentId,
    });
    final response = value is Map
        ? value.cast<String, Object?>()
        : const <String, Object?>{};
    if (response['content'] != null || response['body'] != null) {
      return OronBoxComment.fromJson(response);
    }
    final commentId =
        response['comment_id']?.toString() ?? response['id']?.toString() ?? '';
    if (commentId.isNotEmpty) {
      return OronBoxComment(
        id: commentId,
        body: body,
        username: response['username']?.toString() ?? '',
        avatarUrl: response['avatar_url']?.toString() ?? '',
        bandBbsUserId:
            (response['bandbbs_uid'] as num?)?.toInt() ??
            (response['user_uid'] as num?)?.toInt() ??
            0,
        createdAt:
            DateTime.tryParse(response['created_at']?.toString() ?? '') ??
            DateTime.now(),
        deleted: false,
        moderationState:
            response['status']?.toString() ??
            response['state']?.toString() ??
            response['moderation_state']?.toString() ??
            'visible',
        moderationAction:
            response['ai_action']?.toString() ??
            response['moderation_action']?.toString() ??
            '',
        replies: const [],
      );
    }
    throw const CommentApiException('comment_create_failed', '');
  }

  Future<OronBoxCommentThread> thread(
    String commentId, {
    String before = '',
    String after = '',
    int? page,
    int size = 20,
  }) async {
    final value = await _execute('comment.thread', {
      'comment': commentId,
      'size': size,
      if (before.isNotEmpty) 'before': before,
      if (after.isNotEmpty) 'after': after,
      if (page != null) 'page': page,
    });
    if (value is! Map || value['root'] is! Map) {
      throw const CommentApiException(
        'invalid_response',
        'Invalid comment thread',
      );
    }
    return OronBoxCommentThread.fromJson(value.cast<String, Object?>());
  }

  Future<void> delete(String commentId) =>
      _execute('comment.delete', {'comment': commentId});

  Future<Object?> _execute(String method, Map<String, Object?> params) async {
    final result = await _host.execute(
      OronBoxCommand(method: method, params: params),
    );
    if (!result.ok) {
      throw CommentApiException(result.error!.code, result.error!.message);
    }
    return result.value;
  }
}

class CommentApiException implements CodedError {
  const CommentApiException(this.code, this.message);

  @override
  final String code, message;

  @override
  Object? get details => null;

  @override
  String toString() => message;
}

class OronBoxComment {
  const OronBoxComment({
    required this.id,
    this.parentId = '',
    this.replyToId = '',
    this.replyToUsername = '',
    this.replyCount = 0,
    required this.body,
    required this.username,
    required this.avatarUrl,
    required this.bandBbsUserId,
    required this.createdAt,
    required this.deleted,
    required this.moderationState,
    required this.moderationAction,
    required this.replies,
  });
  final String id, body, username, avatarUrl, moderationState;
  final String parentId, replyToId, replyToUsername;
  final int replyCount;
  String get rootId => parentId.isEmpty ? id : parentId;
  final String moderationAction;
  final int bandBbsUserId;
  final DateTime createdAt;
  final bool deleted;
  final List<OronBoxComment> replies;

  factory OronBoxComment.fromJson(Map<String, Object?> json) {
    final user = json['user'] is Map
        ? (json['user'] as Map).cast<String, Object?>()
        : null;
    return OronBoxComment(
      id: json['id']?.toString() ?? '',
      parentId: json['parent_id']?.toString() ?? '',
      replyToId: json['reply_to_id']?.toString() ?? '',
      replyToUsername: json['reply_to_username']?.toString() ?? '',
      replyCount:
          (json['reply_count'] as num?)?.toInt() ??
          (json['replies'] as List? ?? const []).length,
      body: json['content']?.toString() ?? json['body']?.toString() ?? '',
      username:
          user?['username']?.toString() ?? json['username']?.toString() ?? '',
      avatarUrl:
          user?['avatar_url']?.toString() ??
          json['avatar_url']?.toString() ??
          '',
      bandBbsUserId:
          (user?['bandbbs_uid'] as num?)?.toInt() ??
          (user?['bandbbs_user_id'] as num?)?.toInt() ??
          (json['bandbbs_uid'] as num?)?.toInt() ??
          (json['bandbbs_user_id'] as num?)?.toInt() ??
          (json['user_uid'] as num?)?.toInt() ??
          0,
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      deleted: json['deleted'] == true || json['is_deleted'] == true,
      moderationState:
          json['state']?.toString() ??
          json['moderation_state']?.toString() ??
          'visible',
      moderationAction:
          json['ai_action']?.toString() ??
          json['moderation_action']?.toString() ??
          '',
      replies: (json['replies'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => OronBoxComment.fromJson(item.cast<String, Object?>()))
          .where((comment) => !comment.deleted)
          .toList(),
    );
  }

  OronBoxComment copyWith({List<OronBoxComment>? replies}) => OronBoxComment(
    id: id,
    parentId: parentId,
    replyToId: replyToId,
    replyToUsername: replyToUsername,
    replyCount: replies == null
        ? replyCount
        : replyCount + replies.length - this.replies.length,
    body: body,
    username: username,
    avatarUrl: avatarUrl,
    bandBbsUserId: bandBbsUserId,
    createdAt: createdAt,
    deleted: deleted,
    moderationState: moderationState,
    moderationAction: moderationAction,
    replies: replies ?? this.replies,
  );
}

class OronBoxCommentPage {
  const OronBoxCommentPage({
    required this.items,
    required this.hasMore,
    this.nextCursor = '',
  });
  final List<OronBoxComment> items;
  final bool hasMore;
  final String nextCursor;
}

List<OronBoxComment> threadOronBoxComments(List<OronBoxComment> comments) {
  final byId = {for (final comment in comments) comment.id: comment};
  final replies = <String, List<OronBoxComment>>{};
  final roots = <OronBoxComment>[];
  for (final comment in comments) {
    var root = comment;
    final visited = <String>{comment.id};
    while (root.parentId.isNotEmpty &&
        byId.containsKey(root.parentId) &&
        visited.add(root.parentId)) {
      root = byId[root.parentId]!;
    }
    if (root.id == comment.id) {
      roots.add(comment);
    } else {
      replies.putIfAbsent(root.id, () => []).add(comment);
    }
  }
  return [
    for (final root in roots)
      root.copyWith(replies: [...root.replies, ...?replies[root.id]]),
  ];
}

class OronBoxCommentThread {
  const OronBoxCommentThread({
    required this.root,
    required this.replies,
    required this.resourceId,
    required this.nextCursor,
    required this.previousCursor,
  });
  final OronBoxComment root;
  final List<OronBoxComment> replies;
  final String resourceId, nextCursor, previousCursor;
  factory OronBoxCommentThread.fromJson(Map<String, Object?> json) =>
      OronBoxCommentThread(
        root: OronBoxComment.fromJson(
          (json['root'] as Map).cast<String, Object?>(),
        ),
        replies: (json['replies'] as List? ?? const [])
            .whereType<Map>()
            .map((v) => OronBoxComment.fromJson(v.cast<String, Object?>()))
            .toList(),
        resourceId: json['resource_id']?.toString() ?? '',
        nextCursor: json['next_cursor']?.toString() ?? '',
        previousCursor: json['previous_cursor']?.toString() ?? '',
      );
}
