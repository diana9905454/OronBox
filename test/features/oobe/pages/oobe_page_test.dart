import 'package:material_ui/material_ui.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/app_localizations_delegates.dart';
import 'package:oronbox/src/commands/command_protocol.dart';
import 'package:oronbox/src/core/services/shared_prefs_service.dart';
import 'package:oronbox/src/features/oobe/oobe_state.dart';
import 'package:oronbox/src/features/oobe/pages/oobe_page.dart';
import 'package:oronbox/src/host/application_host_provider.dart';

class _FakeHostBus implements OronBoxCommandBus {
  @override
  Stream<CommandEvent> get events => const Stream.empty();

  @override
  Future<CommandResult> execute(OronBoxCommand command) async {
    if (command.method == 'account.list') {
      return const CommandResult.success(<Object?>[]);
    }
    return const CommandResult.success();
  }

  @override
  Future<void> close() async {}
}

Widget _wrap(Widget child, {GoRouter? router}) {
  final effectiveRouter =
      router ??
      GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => child),
          GoRoute(
            path: '/resources',
            builder: (_, _) => const Scaffold(body: Text('resources-page')),
          ),
        ],
      );
  addTearDown(effectiveRouter.dispose);
  return ProviderScope(
    overrides: [applicationHostProvider.overrideWithValue(_FakeHostBus())],
    child: MaterialApp.router(
      locale: const Locale('zh'),
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: effectiveRouter,
    ),
  );
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPrefsService.instance.init();
  });

  setUp(() async {
    await SharedPrefsService.instance.remove('legal.agreementsAcceptedVersion');
    await SharedPrefsService.instance.remove('oobe.completed');
  });

  testWidgets('oobe walks through all steps and records completion', (
    tester,
  ) async {
    await markLegalAccepted();
    await tester.pumpWidget(_wrap(const OobePage()));
    await tester.pumpAndSettle();

    expect(isOobeCompleted(), isFalse);
    expect(find.text('设备连接'), findsOneWidget);
    expect(find.text('资源中心'), findsOneWidget);
    expect(find.text('JavaScript 插件'), findsOneWidget);
    expect(find.text('多端适配'), findsOneWidget);
    expect(find.text('完全开源'), findsOneWidget);
    expect(find.textContaining('AGPL-3.0'), findsOneWidget);
    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();

    // Terms: pre-accepted, next enabled.
    var nextBtn = find.widgetWithText(FilledButton, '下一步');
    expect(tester.widget<FilledButton>(nextBtn).onPressed, isNotNull);
    await tester.tap(nextBtn);
    await tester.pumpAndSettle();

    // Privacy: pre-accepted.
    nextBtn = find.widgetWithText(FilledButton, '下一步');
    expect(tester.widget<FilledButton>(nextBtn).onPressed, isNotNull);
    await tester.tap(nextBtn);
    await tester.pumpAndSettle();

    expect(isLegalAccepted(), isTrue);

    // Accounts.
    expect(find.text('登录账号'), findsWidgets);
    expect(find.text('从备份恢复'), findsOneWidget);
    expect(find.text('登录小米账号以同步已绑定的小米设备'), findsOneWidget);
    expect(find.text('登录华米账号以访问华米应用商店资源'), findsOneWidget);
    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();

    // Done.
    expect(find.text('一切就绪'), findsWidgets);
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();

    expect(isOobeCompleted(), isTrue);
    expect(find.text('resources-page'), findsOneWidget);
  });

  testWidgets('next is disabled until checkbox is checked', (tester) async {
    await tester.pumpWidget(_wrap(const OobePage()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();

    // Button should be disabled without checkbox.
    var nextBtn = find.widgetWithText(FilledButton, '下一步');
    expect(tester.widget<FilledButton>(nextBtn).onPressed, isNull);
  });

  testWidgets('agreement checkbox unlocks after scrolling to the bottom', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const OobePage()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();

    // The terms document is long enough to scroll in the test window, so the
    // checkbox stays disabled until the reader reaches the bottom.
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).onChanged, isNull);
    expect(find.text('请阅读并滚动到底部'), findsOneWidget);

    for (var i = 0; i < 20; i++) {
      await tester.drag(find.byType(Markdown), const Offset(0, -400));
      await tester.pumpAndSettle();
      if (tester.widget<Checkbox>(find.byType(Checkbox)).onChanged != null) {
        break;
      }
    }

    expect(tester.widget<Checkbox>(find.byType(Checkbox)).onChanged, isNotNull);
    expect(find.text('请阅读并滚动到底部'), findsNothing);

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    final nextBtn = find.widgetWithText(FilledButton, '下一步');
    expect(tester.widget<FilledButton>(nextBtn).onPressed, isNotNull);
  });
}
