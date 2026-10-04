import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/app/widgets/app_scaffold_messenger.dart';

void main() {
  testWidgets('OronBoxScaffoldMessenger deduplicates rapid identical snackbars',
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
    messenger.showSnackBar(
      const SnackBar(content: Text('Duplicate Error')),
    );
    messenger.showSnackBar(
      const SnackBar(content: Text('Duplicate Error')),
    );
    messenger.showSnackBar(
      const SnackBar(content: Text('Duplicate Error')),
    );

    await tester.pump();

    // Verify only 1 SnackBar widget is in the tree
    expect(find.text('Duplicate Error'), findsOneWidget);
  });
}
