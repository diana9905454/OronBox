import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oronbox/src/commands/command_protocol.dart';
import 'package:oronbox/src/host/application_host_provider.dart';

final messageCenterProvider =
    AsyncNotifierProvider<MessageCenterController, MessageCenterState>(
      MessageCenterController.new,
    );

class MessageCenterController extends AsyncNotifier<MessageCenterState> {
  @override
  Future<MessageCenterState> build() => _load();
  Future<MessageCenterState> _load() async {
    final result = await ref
        .read(applicationHostProvider)
        .execute(const OronBoxCommand(method: 'message.list'));
    if (!result.ok) return const MessageCenterState();
    final root = (result.value as Map).cast<String, Object?>();
    return MessageCenterState(
      unread: (root['unread'] as num?)?.toInt() ?? 0,
      messages: (root['messages'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => UserMessage.fromJson(item.cast<String, Object?>()))
          .toList(),
    );
  }

  Future<void> refresh() async {
    final previous = state.value;
    state = const AsyncLoading();
    try {
      state = AsyncData(await _load());
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      if (previous != null) state = AsyncData(previous);
    }
  }

  Future<void> read(String id) async {
    final current = state.value;
    if (current != null) {
      final wasUnread = current.messages.any(
        (message) => message.id == id && !message.read,
      );
      state = AsyncData(
        MessageCenterState(
          unread: wasUnread && current.unread > 0
              ? current.unread - 1
              : current.unread,
          messages: current.messages
              .map(
                (message) =>
                    message.id == id ? message.copyWith(read: true) : message,
              )
              .toList(growable: false),
        ),
      );
    }
    await ref
        .read(applicationHostProvider)
        .execute(
          OronBoxCommand(method: 'message.read', params: {'message': id}),
        );
  }

  Future<bool> clear() async {
    final result = await ref
        .read(applicationHostProvider)
        .execute(const OronBoxCommand(method: 'message.clear'));
    if (!result.ok) return false;
    state = const AsyncData(MessageCenterState());
    return true;
  }
}

class MessageCenterState {
  const MessageCenterState({this.messages = const [], this.unread = 0});
  final List<UserMessage> messages;
  final int unread;
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
  });
  final String id, kind, event, legacyTitle, legacyBody;
  final String targetResourceId, targetCommentId;
  final Map<String, Object?> data;
  final DateTime createdAt;
  final bool read;
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
      read: json['read_at'] != null,
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
    );
  }
}
