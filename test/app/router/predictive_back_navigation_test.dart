import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:oronbox/src/app/theme/app_theme.dart';

Future<void> _gesture(WidgetTester tester, {bool cancel = false}) async {
  Future<void> send(MethodCall call) async {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter/backgesture',
      const StandardMethodCodec().encodeMethodCall(call),
      (_) {},
    );
  }

  await send(
    const MethodCall('startBackGesture', {
      'touchOffset': <double>[0.0, 250.0],
      'progress': 0.0,
      'swipeEdge': 0,
    }),
  );
  await tester.pump();
  await send(MethodCall(cancel ? 'cancelBackGesture' : 'commitBackGesture'));
  await tester.pumpAndSettle();
}

void main() {
  for (final mode in ['gesture', 'cancel then gesture', 'arrow']) {
    testWidgets(
      'root DevTools returns once and preserves secondary route: $mode',
      (tester) async {
        final router = GoRouter(
          initialLocation: '/settings/voice',
          routes: [
            GoRoute(
              path: '/debug',
              builder: (_, _) =>
                  Scaffold(appBar: AppBar(), body: const Text('DevTools')),
            ),
            StatefulShellRoute.indexedStack(
              builder: (_, _, shell) => shell,
              branches: [
                StatefulShellBranch(
                  routes: [
                    GoRoute(
                      path: '/settings',
                      builder: (_, _) => const Scaffold(body: Text('settings')),
                      routes: [
                        GoRoute(
                          path: 'voice',
                          builder: (context, _) => Scaffold(
                            body: TextButton(
                              onPressed: () => context.push('/debug'),
                              child: const Text('voice'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          MaterialApp.router(
            theme: AppTheme.buildLightTheme(),
            routerConfig: router,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('voice'));
        await tester.pumpAndSettle();
        if (mode == 'cancel then gesture') {
          await _gesture(tester, cancel: true);
          expect(find.text('DevTools'), findsOneWidget);
          expect(find.text('voice'), findsNothing);
        }
        if (mode == 'arrow') {
          await tester.tap(find.byType(BackButton));
          await tester.pumpAndSettle();
        } else {
          await _gesture(tester);
        }
        expect(find.text('voice'), findsOneWidget);
        expect(find.text('settings'), findsNothing);
        expect(
          router.routeInformationProvider.value.uri.path,
          '/settings/voice',
        );
        await _gesture(tester);
        expect(find.text('settings'), findsOneWidget);
        expect(router.routeInformationProvider.value.uri.path, '/settings');
      },
    );
  }
}
