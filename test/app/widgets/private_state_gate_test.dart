import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:oronbox/src/app/widgets/private_state_gate.dart';
import 'package:oronbox/src/core/services/private_app_state.dart';
import 'package:oronbox/src/core/services/shared_prefs_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('does not build account/device consumers until retry succeeds', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'app_locale': 'en'});
    await SharedPrefsService.instance.init();
    await SharedPrefsService.instance.reload();
    final storage = _UnavailableStore();
    PrivateAppState.instanceForTesting = storage;
    addTearDown(() => PrivateAppState.instanceForTesting = null);
    var built = false;
    await tester.pumpWidget(
      ProviderScope(
        child: PrivateStateGate(
          child: Builder(
            builder: (_) {
              built = true;
              return const MaterialApp(home: Scaffold(body: Text('Ready')));
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(built, false);
    expect(
      find.textContaining('Unable to read saved accounts'),
      findsOneWidget,
    );
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(built, false);
    expect(tester.takeException(), isNull);
    storage.available = true;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(built, true);
    expect(find.text('Ready'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'builds child synchronously when private state is already ready',
    (tester) async {
      SharedPreferences.setMockInitialValues({'app_locale': 'en'});
      await SharedPrefsService.instance.init();
      await SharedPrefsService.instance.reload();
      final storage = _ReadyStore();
      PrivateAppState.instanceForTesting = storage;
      addTearDown(() => PrivateAppState.instanceForTesting = null);
      var built = false;
      await tester.pumpWidget(
        ProviderScope(
          child: PrivateStateGate(
            child: Builder(
              builder: (_) {
                built = true;
                return const MaterialApp(
                  home: Scaffold(body: Text('Instant Ready')),
                );
              },
            ),
          ),
        ),
      );
      expect(built, true);
      expect(find.text('Instant Ready'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );

  testWidgets('allows user to reset corrupted storage and enter app', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'app_locale': 'en'});
    await SharedPrefsService.instance.init();
    await SharedPrefsService.instance.reload();
    final storage = _UnavailableStore();
    PrivateAppState.instanceForTesting = storage;
    addTearDown(() => PrivateAppState.instanceForTesting = null);
    var built = false;
    await tester.pumpWidget(
      ProviderScope(
        child: PrivateStateGate(
          child: Builder(
            builder: (_) {
              built = true;
              return const MaterialApp(home: Scaffold(body: Text('Recovered')));
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(built, false);
    expect(find.text('Reset local credentials'), findsOneWidget);

    await tester.tap(find.text('Reset local credentials'));
    await tester.pumpAndSettle();
    expect(find.text('Reset local accounts and devices'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(storage.resetCalled, false);
    expect(built, false);

    await tester.tap(find.text('Reset local credentials'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Reset'));
    await tester.pumpAndSettle();
    expect(storage.resetCalled, true);
    expect(built, true);
    expect(find.text('Recovered'), findsOneWidget);
  });
}

class _ReadyStore extends PrivateAppState {
  @override
  bool get isReady => true;

  @override
  Future<void> initialize() async {}
}

class _UnavailableStore extends PrivateAppState {
  bool available = false;
  bool resetCalled = false;
  @override
  bool get isReady => available;

  @override
  Future<void> initialize() async {
    if (!available) {
      throw const PrivateStateException('private_state_read_failed');
    }
  }

  @override
  Future<void> resetCorruptedState() async {
    resetCalled = true;
    available = true;
  }
}
