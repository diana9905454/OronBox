import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:oronbox/src/app/app_localizations_delegates.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/features/settings/application/app_data_backup.dart';
import 'package:oronbox/src/features/settings/pages/app_data_backup_dialog.dart';

void main() {
  testWidgets(
    'export requires explicit opt-in for device and Xiaomi credentials',
    (tester) async {
      BackupSelection? selected;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  selected = await showBackupSelectionDialog(context);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final options = tester
          .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
          .toList();
      expect(options.map((e) => e.value), [true, true, true, false, false]);
      await tester.ensureVisible(find.text('Device pairing and keys'));
      await tester.tap(find.text('Device pairing and keys'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Export backup'));
      await tester.pumpAndSettle();
      expect(selected!.devices, true);
      expect(selected!.xiaomi, false);
    },
  );
}
