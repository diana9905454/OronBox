import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:oronbox/src/app/app_localizations_delegates.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/core/services/shared_prefs_service.dart';
import 'package:oronbox/src/features/settings/application/auto_backup_service.dart';
import 'package:oronbox/src/features/settings/pages/app_data_backup_dialog.dart';
import 'package:oronbox/src/features/settings/pages/auto_backup_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPrefsService.instance.init();
    await SharedPrefsService.instance.reload();
  });

  testWidgets('showAutoBackupConfigDialog toggles and saves preferences', (
    tester,
  ) async {
    late BuildContext targetContext;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              targetContext = context;
              return const Scaffold(body: SizedBox());
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    showAutoBackupConfigDialog(targetContext);
    await tester.pumpAndSettle();

    expect(find.text('定时备份'), findsOneWidget);
    expect(find.text('启用定时备份'), findsOneWidget);
    expect(find.text('备份频率'), findsNothing);

    // Toggle switch on
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(find.text('备份频率'), findsOneWidget);
    expect(find.text('保留份数（0 为不限制）'), findsOneWidget);
    expect(find.text('份'), findsOneWidget);
    expect(find.text('备份范围'), findsOneWidget);
    expect(find.text('小米与华米账号信息'), findsOneWidget);

    // Modify retention to 0
    final retentionField = find.widgetWithText(TextField, '5');
    expect(retentionField, findsOneWidget);
    await tester.enterText(retentionField, '0');
    await tester.pumpAndSettle();

    // Save
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(AutoBackupPreferences.enabled, isTrue);
    expect(AutoBackupPreferences.retention, 0);
  });

  testWidgets('showPublicBackupPickerDialog selects public or external', (
    tester,
  ) async {
    late BuildContext targetContext;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              targetContext = context;
              return const Scaffold(body: SizedBox());
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    RestoreSourceSelection? result;
    showPublicBackupPickerDialog(targetContext, [
      'OronBox-Backup-1.zip',
      'OronBox-Backup-2.zip',
    ]).then((v) => result = v);
    await tester.pumpAndSettle();

    expect(find.text('选择要恢复的备份'), findsOneWidget);
    expect(find.text('OronBox-Backup-1.zip'), findsOneWidget);
    expect(find.text('选择其他外部文件...'), findsOneWidget);

    // Tap the first backup
    await tester.tap(find.text('OronBox-Backup-1.zip'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.fileName, 'OronBox-Backup-1.zip');
    expect(result!.pickExternal, isFalse);
  });
}
