import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:oronbox/src/app/app_localizations_delegates.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/features/settings/application/app_data_backup.dart';
import 'package:oronbox/src/features/settings/pages/app_data_backup_dialog.dart';

void main() {
  testWidgets(
    'device pairing is selected while account credentials stay opt-in',
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
      expect(options.map((e) => e.value), [true, true, true, true, false]);
      expect(
        find.textContaining('unencrypted account credentials'),
        findsNothing,
      );
      await tester.ensureVisible(find.text('Xiaomi and Amazfit credentials'));
      await tester.tap(find.byType(CheckboxListTile).last);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('unencrypted account credentials'),
        findsOneWidget,
      );
      await tester.tap(find.byType(CheckboxListTile).last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Device pairing and keys'));
      await tester.tap(find.widgetWithText(FilledButton, 'Export backup'));
      await tester.pumpAndSettle();
      expect(selected!.devices, true);
      expect(selected!.xiaomi, false);
      expect((selected as BackupExportSelection).saveToDocuments, true);
    },
  );

  testWidgets(
    'showPublicBackupPickerDialog displays parsed backup cards and external button',
    (tester) async {
      RestoreSourceSelection? result;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await showPublicBackupPickerDialog(context, [
                    'OronBox-AutoBackup-20261103-120000.zip',
                    'OronBox-ManualBackup-20261103-130000.zip',
                    'OronBox-Backup-1700000000000.zip',
                  ]);
                },
                child: const Text('pick'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('pick'));
      await tester.pumpAndSettle();

      expect(find.text('Auto Backup'), findsOneWidget);
      expect(find.text('2026-11-03 12:00:00'), findsOneWidget);
      expect(find.text('Manual Backup'), findsNWidgets(2));
      expect(find.text('Choose another external file...'), findsOneWidget);

      await tester.tap(find.text('Choose another external file...'));
      await tester.pumpAndSettle();
      expect(result, isNotNull);
      expect(result!.pickExternal, true);
      expect(result!.fileName, isNull);
    },
  );
}
