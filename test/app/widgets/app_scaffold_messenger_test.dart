import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/app/widgets/app_scaffold_messenger.dart';

void main() {
  testWidgets(
    'OronBoxScaffoldMessenger deduplicates rapid identical snackbars',
    (tester) async {
      BuildContext? innerContext;

      await tester.pumpWidget(
        MaterialApp(
          home: OronBoxScaffoldMessenger(
            child: Scaffold(
              body: Builder(
                builder: (context) {
                  innerContext = context;
                  return const Center(child: Text('Body'));
                },
              ),
            ),
          ),
        ),
      );

      expect(innerContext, isNotNull);
      final messenger = ScaffoldMessenger.of(innerContext!);

      // Rapidly trigger 3 identical snackbars
      messenger.showSnackBar(const SnackBar(content: Text('Duplicate Error')));
      messenger.showSnackBar(const SnackBar(content: Text('Duplicate Error')));
      messenger.showSnackBar(const SnackBar(content: Text('Duplicate Error')));

      await tester.pump();

      // Verify only 1 SnackBar widget is in the tree
      expect(find.text('Duplicate Error'), findsOneWidget);
    },
  );
  testWidgets(
    'global callbacks use the page messenger and custom root fallback',
    (tester) async {
      late BuildContext callbackContext;
      late BuildContext pageContext;
      var hasShell = true;
      Widget app() => MaterialApp(
        builder: (context, child) => OronBoxScaffoldMessenger(
          child: Builder(
            builder: (context) {
              callbackContext = context;
              return child!;
            },
          ),
        ),
        home: hasShell
            ? Scaffold(
                body: OronBoxScaffoldMessenger(
                  key: appScaffoldMessengerKey,
                  child: Scaffold(
                    body: Builder(
                      builder: (context) {
                        pageContext = context;
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
              )
            : const Scaffold(body: SizedBox.shrink()),
      );
      await tester.pumpWidget(app());
      expect(
        appScaffoldMessengerOf(callbackContext),
        same(ScaffoldMessenger.of(pageContext)),
      );
      final messenger = appScaffoldMessengerOf(callbackContext);
      final first = messenger.showSnackBar(
        const SnackBar(content: Text('Signed in')),
      );
      final duplicate = messenger.showSnackBar(
        const SnackBar(content: Text('Signed in')),
      );
      expect(duplicate, same(first));
      await tester.pumpAndSettle();
      expect(
        tester.widget<SnackBar>(find.byType(SnackBar)).duration,
        appSnackBarDuration,
      );
      messenger.removeCurrentSnackBar();
      await tester.pumpAndSettle();
      hasShell = false;
      await tester.pumpWidget(app());
      final fallback = appScaffoldMessengerOf(callbackContext);
      expect(fallback.widget, isA<OronBoxScaffoldMessenger>());
      fallback.showSnackBar(const SnackBar(content: Text('First run')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<SnackBar>(find.byType(SnackBar)).duration,
        appSnackBarDuration,
      );
      fallback.removeCurrentSnackBar();
      await tester.pumpAndSettle();
    },
  );
}
