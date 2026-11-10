import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/app/app_localizations_delegates.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/widgets/app_scaffold_messenger.dart';
import 'package:oronbox/src/core/models/bt_models.dart';
import 'package:oronbox/src/features/devices/controllers/device_manager.dart';
import 'package:oronbox/src/features/devices/widgets/device_import_dialog.dart';

const device = MiWearState(
  name: 'Xiaomi Watch S5',
  addr: 'AA:BB:CC:DD:EE:FF',
  connectType: 'spp',
  authkey: '11111111111111111111111111111111',
);

void main() {
  Future<_ImportManager> open(WidgetTester tester) async {
    final manager = _ImportManager();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [deviceManagerProvider.overrideWith(() => manager)],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => OronBoxScaffoldMessenger(child: child!),
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () =>
                      showSharedDeviceImportDialog(context, ref, device),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return manager;
  }

  testWidgets('canceling a detected device leaves stored devices untouched', (
    tester,
  ) async {
    final manager = await open(tester);
    expect(manager.imported, isNull);
    expect(find.text('识别到 1 个设备，点击以导入'), findsOneWidget);
    expect(find.text('AA:BB:CC:DD:EE:FF'), findsOneWidget);
    expect(find.text('11111111111111111111111111111111'), findsNothing);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(manager.imported, isNull);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets(
    'tapping the detected device imports it and shows the shared toast',
    (tester) async {
      final manager = await open(tester);
      await tester.tap(find.text(device.name));
      await tester.pumpAndSettle();
      expect(manager.imported, device);
      expect(find.text('已导入 Xiaomi Watch S5'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

class _ImportManager extends LocalDeviceManager {
  MiWearState? imported;
  @override
  DeviceManagerState build() => const DeviceManagerState();
  @override
  Future<void> importSharedDevice(MiWearState device) async {
    imported = device;
  }
}
