import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/app_localizations_delegates.dart';
import 'package:oronbox/src/core/services/shared_prefs_service.dart';
import 'package:oronbox/src/commands/command_protocol.dart';
import 'package:oronbox/src/host/application_host_provider.dart';
import 'package:oronbox/src/features/resources/pages/resource_detail_page.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPrefsService.instance.init();
  });
  testWidgets(
    'message opens a reply beyond the first viewport and reveals it',
    (tester) async {
      final host = _ThreadHost();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [applicationHostProvider.overrideWithValue(host)],
          child: MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const CommentThreadPage(
              resourceId: 'resource',
              commentId: 'reply-19',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(host.requested, 'reply-19');
      final target = find.text('target reply 19');
      expect(target, findsOneWidget);
      final bounds = tester.getRect(target);
      expect(bounds.bottom, lessThanOrEqualTo(600));
      expect(bounds.top, greaterThanOrEqualTo(0));
      expect(tester.takeException(), isNull);
    },
  );
}

class _ThreadHost implements OronBoxCommandBus {
  String? requested;
  @override
  Stream<CommandEvent> get events => const Stream.empty();
  @override
  Future<void> close() async {}
  @override
  Future<CommandResult> execute(OronBoxCommand c) async {
    if (c.method != 'comment.thread') return const CommandResult.success({});
    requested = c.params['comment']?.toString();
    Map<String, Object?> comment(String id, String text) => {
      'id': id,
      'body': text,
      'username': 'author',
      'bandbbs_user_id': 123,
      'created_at': '2026-10-16T00:00:00Z',
    };
    return CommandResult.success({
      'resource_id': 'resource',
      'root': comment('root', 'root comment'),
      'replies': [
        for (var i = 0; i < 20; i++) comment('reply-$i', 'target reply $i'),
      ],
      'next_cursor': '',
      'previous_cursor': '',
    });
  }
}
