import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oronbox/src/app/router/app_router.dart';
import 'package:oronbox/src/core/services/shared_prefs_service.dart';
import 'package:oronbox/src/commands/command_protocol.dart';
import 'package:oronbox/src/host/application_host_provider.dart';
import 'package:oronbox/src/features/messages/application/message_center.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPrefsService.instance.init();
  });
  test(
    'message targets match actual application routes and keep case identity',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final router = container.read(appRouterProvider);
      addTearDown(router.dispose);
      final examples = <Map<String, Object?>>[
        {
          'event': 'review.approved',
          'data': {
            'resource_id': 'res',
            'review_case_id': 'case',
            'revision_id': 'revision',
          },
        },
        {
          'event': 'comment.replied',
          'data': {'resource_id': 'res', 'comment_id': 'reply'},
        },
        {
          'event': 'comment.replied',
          'data': {'comment_id': 'reply'},
        },
        {
          'event': 'comment.hidden',
          'data': {'resource_id': 'res', 'comment_id': 'hidden'},
        },
        {
          'event': 'collection.approved',
          'data': {'collection_id': 'collection'},
        },
        {
          'event': 'plugin.approved',
          'data': {'plugin_id': 'org.example.plugin'},
        },
        {
          'event': 'report.updated',
          'data': {'ticket_id': 'ticket', 'resource_id': 'res'},
        },
        {
          'event': 'resource.suspended',
          'data': {'resource_id': 'res'},
        },
      ];
      for (final json in examples) {
        final message = UserMessage.fromJson(json);
        final location = message.targetLocation!;
        expect(
          router.configuration.findMatch(Uri.parse(location)).error,
          isNull,
          reason: location,
        );
      }
      expect(
        UserMessage.fromJson(examples.first).targetLocation,
        '/resources/creator/reviews/case',
      );
      expect(
        Uri.parse(UserMessage.fromJson(examples[3]).targetLocation!)
            .queryParameters
            .containsKey('comment'),
        isFalse,
      );
    },
  );
  test(
    'loads past 100 messages using opaque cursors, clears actual list',
    () async {
      final host = _PagedHost();
      final c = ProviderContainer(
        overrides: [applicationHostProvider.overrideWithValue(host)],
      );
      addTearDown(c.dispose);
      await c.read(messageCenterProvider.future);
      for (var i = 0; i < 5; i++) {
        await c.read(messageCenterProvider.notifier).loadMore();
      }
      final state = c.read(messageCenterProvider).requireValue;
      expect(state.messages.length, 120);
      expect(state.hasMore, isFalse);
      expect(host.cursors, [
        '',
        'cursor-20',
        'cursor-40',
        'cursor-60',
        'cursor-80',
        'cursor-100',
      ]);
      expect(await c.read(messageCenterProvider.notifier).clear(), isTrue);
      expect(c.read(messageCenterProvider).requireValue.messages, isEmpty);
    },
  );
}

class _PagedHost implements OronBoxCommandBus {
  final cursors = <String>[];
  @override
  Stream<CommandEvent> get events => const Stream.empty();
  @override
  Future<void> close() async {}
  @override
  Future<CommandResult> execute(OronBoxCommand c) async {
    if (c.method == 'message.clear') return const CommandResult.success({});
    final before = c.params['before']?.toString() ?? '';
    cursors.add(before);
    final start = before.isEmpty ? 0 : int.parse(before.substring(7));
    return CommandResult.success({
      'messages': [
        for (var i = start; i < start + 20; i++)
          {'id': 'm$i', 'data': {}, 'created_at': '2026-10-16T00:00:00Z'},
      ],
      'unread': 120,
      'has_more': start < 100,
      'next_cursor': start < 100 ? 'cursor-${start + 20}' : '',
    });
  }
}
