import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
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
}

class _UnavailableStore extends PrivateAppState {
  bool available = false;
  @override
  Future<void> initialize() async {
    if (!available) {
      throw const PrivateStateException('private_state_read_failed');
    }
  }
}
