import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oronbox/src/commands/command_protocol.dart';
import 'package:oronbox/src/host/application_host_provider.dart';

final messageCenterProvider =
    AsyncNotifierProvider<MessageCenterController, MessageCenterState>(
      MessageCenterController.new,
    );

class MessageCenterController extends AsyncNotifier<MessageCenterState> {
  int _generation = 0;
  @override
  Future<MessageCenterState> build() => _load();

  Future<MessageCenterState> _load({String before = ''}) async {
    final result = await ref
        .read(applicationHostProvider)
        .execute(
          OronBoxCommand(
            method: 'message.list',
            params: {'size': 20, if (before.isNotEmpty) 'before': before},
          ),
        );
    if (!result.ok) {
      if (result.error?.code == 'auth_required' ||
          result.error?.code == 'unauthorized') {
        return const MessageCenterState();
      }
      throw result.error!;
    }
    final root = (result.value as Map).cast<String, Object?>();
    return MessageCenterState(
      unread: (root['unread'] as num?)?.toInt() ?? 0,
      messages: (root['messages'] as List? ?? const [])
          .whereType<Map>()
          .map((m) => UserMessage.fromJson(m.cast<String, Object?>()))
          .toList(),
      nextCursor: root['next_cursor']?.toString() ?? '',
      hasMore: root['has_more'] == true,
    );
  }

  Future<void> refresh() async {
    final generation = ++_generation;
    final previous = state.value;
    try {
      final next = await _load();
      if (ref.mounted && generation == _generation) state = AsyncData(next);
    } catch (error, stack) {
      if (ref.mounted && generation == _generation) {
        state = previous == null
            ? AsyncError(error, stack)
            : AsyncData(previous);
      }
      rethrow;
    }
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null ||
        !current.hasMore ||
        current.loadingMore ||
        current.nextCursor.isEmpty) {
      return;
    }
    final generation = _generation;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final next = await _load(before: current.nextCursor);
      if (!ref.mounted || generation != _generation) return;
      final latest = state.requireValue;
      final ids = latest.messages.map((m) => m.id).toSet();
      state = AsyncData(
        MessageCenterState(
          messages: [
            ...latest.messages,
            ...next.messages.where((m) => ids.add(m.id)),
          ],
          unread: next.unread,
          hasMore: next.hasMore,
          nextCursor: next.nextCursor,
        ),
      );
    } catch (_) {
      if (ref.mounted && generation == _generation) {
        state = AsyncData(state.requireValue.copyWith(loadingMore: false));
      }
      rethrow;
    }
  }

  Future<void> read(String id) async {
    final current = state.value;
    final generation = _generation;
    final wasUnread =
        current?.messages.any((m) => m.id == id && !m.read) ?? false;
    if (current != null) {
      state = AsyncData(
        current.copyWith(
          unread: wasUnread && current.unread > 0
              ? current.unread - 1
              : current.unread,
          messages: current.messages
              .map((m) => m.id == id ? m.copyWith(read: true) : m)
              .toList(),
        ),
      );
    }
    final result = await ref
        .read(applicationHostProvider)
        .execute(
          OronBoxCommand(method: 'message.read', params: {'message': id}),
        );
    if (!result.ok &&
        wasUnread &&
        ref.mounted &&
        generation == _generation &&
        state.value != null) {
      final latest = state.requireValue;
      state = AsyncData(
        latest.copyWith(
          unread: latest.unread + 1,
          messages: latest.messages
              .map((m) => m.id == id ? m.copyWith(read: false) : m)
              .toList(),
        ),
      );
    }
  }

  Future<bool> clear() async {
    final generation = _generation;
    final result = await ref
        .read(applicationHostProvider)
        .execute(const OronBoxCommand(method: 'message.clear'));
    if (!result.ok) return false;
    if (ref.mounted && generation == _generation) {
      _generation++;
      state = const AsyncData(MessageCenterState());
    }
    return true;
  }
}

class MessageCenterState {
  const MessageCenterState({
    this.messages = const [],
    this.unread = 0,
    this.hasMore = false,
    this.loadingMore = false,
    this.nextCursor = '',
  });
  final List<UserMessage> messages;
  final int unread;
  final bool hasMore, loadingMore;
  final String nextCursor;
  MessageCenterState copyWith({
    List<UserMessage>? messages,
    int? unread,
    bool? loadingMore,
  }) => MessageCenterState(
    messages: messages ?? this.messages,
    unread: unread ?? this.unread,
    loadingMore: loadingMore ?? this.loadingMore,
    hasMore: hasMore,
    nextCursor: nextCursor,
  );
}

class UserMessage {
  const UserMessage({
    required this.id,
    required this.kind,
    required this.event,
    required this.data,
    required this.legacyTitle,
    required this.legacyBody,
    required this.createdAt,
    required this.read,
    required this.targetResourceId,
    required this.targetCommentId,
    required this.targetReviewId,
  });
  final String id, kind, event, legacyTitle, legacyBody;
  final String targetResourceId, targetCommentId, targetReviewId;
  final Map<String, Object?> data;
  final DateTime createdAt;
  final bool read;
  String? get targetLocation {
    String text(String key) => data[key]?.toString() ?? '';
    String path(String value) => Uri.encodeComponent(value);
    if (text('ticket_id').isNotEmpty) {
      return '/settings/feedback/ticket?id=${path(text('ticket_id'))}';
    }
    if (targetReviewId.isNotEmpty) {
      return '/resources/creator/reviews/${path(targetReviewId)}';
    }
    if (text('collection_id').isNotEmpty) {
      return '/resources/creator/collection/${path(text('collection_id'))}';
    }
    if (text('plugin_id').isNotEmpty) {
      return '/plugins?plugin=${path(text('plugin_id'))}';
    }
    if (targetResourceId.isNotEmpty) {
      if (event.startsWith('review.') ||
          event.startsWith('resource.') ||
          text('target_source') == 'creator_resource') {
        return '/resources/creator/resources/${path(targetResourceId)}';
      }
      final query = Uri(
        queryParameters: {
          'source': 'oronBox',
          if (targetCommentId.isNotEmpty && event != 'comment.hidden')
            'comment': targetCommentId,
        },
      ).query;
      return '/resources/detail/${path(targetResourceId)}?$query';
    }
    if (targetCommentId.isNotEmpty) {
      return '/resources/comment/${path(targetCommentId)}';
    }
    return null;
  }

  UserMessage copyWith({bool? read}) => UserMessage(
    id: id,
    kind: kind,
    event: event,
    data: data,
    legacyTitle: legacyTitle,
    legacyBody: legacyBody,
    createdAt: createdAt,
    read: read ?? this.read,
    targetResourceId: targetResourceId,
    targetCommentId: targetCommentId,
    targetReviewId: targetReviewId,
  );

  factory UserMessage.fromJson(Map<String, Object?> json) {
    final data = switch (json['data']) {
      final Map value => value.cast<String, Object?>(),
      _ => const <String, Object?>{},
    };
    String value(String key) => data[key]?.toString() ?? '';
    final targetSource = value('target_source').toLowerCase();
    return UserMessage(
      id: json['id']?.toString() ?? '',
      kind: json['kind']?.toString() ?? '',
      event: json['event']?.toString() ?? '',
      data: data,
      legacyTitle: json['title']?.toString() ?? value('title'),
      legacyBody: json['body']?.toString() ?? value('body'),
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      read: json['read_at']?.toString().isNotEmpty == true,
      targetResourceId: value('resource_id').isNotEmpty
          ? value('resource_id')
          : targetSource == 'resource' || targetSource == 'oronbox'
          ? value('target_id')
          : json['target_resource_id']?.toString() ?? '',
      targetCommentId: value('comment_id').isNotEmpty
          ? value('comment_id')
          : targetSource == 'comment'
          ? value('target_id')
          : json['target_comment_id']?.toString() ?? '',
      targetReviewId: value('review_case_id').isNotEmpty
          ? value('review_case_id')
          : value('review_id').isNotEmpty
          ? value('review_id')
          : json['target_review_id']?.toString() ?? '',
    );
  }
}
