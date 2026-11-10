import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:oronbox/src/app/app_localizations_delegates.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/widgets/app_scaffold_messenger.dart';
import 'package:oronbox/src/commands/command_protocol.dart';
import 'package:oronbox/src/features/devices/widgets/xiaomi_screenshot_handler.dart';
import 'package:oronbox/src/host/application_host_provider.dart';

class _Host implements OronBoxCommandBus {
  final controller = StreamController<CommandEvent>.broadcast();
  @override
  Stream<CommandEvent> get events => controller.stream;
  @override
  Future<void> close() => controller.close();
  @override
  Future<CommandResult> execute(OronBoxCommand command) async =>
      const CommandResult.success();

  void screenshot(List<int> bytes) => controller.add(
    CommandEvent('device.xiaomi.screenshot.received', data: {'bytes': bytes}),
  );
}

void main() {
  late _Host host;
  setUp(() => host = _Host());
  tearDown(() => host.close());

  Future<void> mount(
    WidgetTester tester,
    Future<String?> Function(Uint8List) save,
  ) => tester.pumpWidget(
    ProviderScope(
      overrides: [
        applicationHostProvider.overrideWithValue(host),
        xiaomiScreenshotSaverProvider.overrideWithValue(save),
      ],
      child: MaterialApp(
        locale: const Locale('zh'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: appLocalizationsDelegates,
        builder: (context, child) => OronBoxScaffoldMessenger(
          child: XiaomiScreenshotHandler(child: child!),
        ),
        home: const Scaffold(body: Text('Home')),
      ),
    ),
  );

  testWidgets(
    'received screenshot is saved and shown through the custom messenger',
    (tester) async {
      Uint8List? saved;
      await mount(tester, (bytes) async {
        saved = bytes;
        return 'Pictures/WatchScreenshots/image.png';
      });
      host.screenshot([1, 2, 255]);
      await tester.pumpAndSettle();
      expect(saved, [1, 2, 255]);
      expect(
        find.text('手表截图已保存至：Pictures/WatchScreenshots/image.png'),
        findsOneWidget,
      );
      expect(
        ScaffoldMessenger.of(tester.element(find.text('Home'))),
        isA<ScaffoldMessengerState>(),
      );
    },
  );

  testWidgets('consecutive screenshots save in order and survive navigation', (
    tester,
  ) async {
    final firstSave = Completer<String?>();
    final saved = <int>[];
    await mount(tester, (bytes) async {
      saved.add(bytes.first);
      if (bytes.first == 1) return firstSave.future;
      return 'second.png';
    });
    host.screenshot([1]);
    host.screenshot([2]);
    await tester.pump();
    expect(saved, [1]);
    unawaited(
      Navigator.of(tester.element(find.text('Home'))).push<void>(
        MaterialPageRoute(
          builder: (_) => const Scaffold(body: Text('Other page')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    firstSave.complete('first.png');
    await tester.pumpAndSettle();
    expect(saved, [1, 2]);
    expect(find.text('Other page'), findsOneWidget);
    expect(find.text('手表截图已保存至：second.png'), findsOneWidget);
  });

  for (final unsupported in [false, true]) {
    testWidgets(
      'failed save reports failure and allows the next screenshot (null=$unsupported)',
      (tester) async {
        await mount(tester, (bytes) async {
          if (bytes.first == 1) {
            if (unsupported) return null;
            throw StateError('Storage unavailable');
          }
          return 'next.png';
        });
        host.screenshot([1]);
        await tester.pumpAndSettle();
        expect(find.text('保存截图失败'), findsOneWidget);
        host.screenshot([2]);
        await tester.pumpAndSettle();
        expect(find.text('手表截图已保存至：next.png'), findsOneWidget);
      },
    );
  }
}
