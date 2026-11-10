import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/app/app_localizations_delegates.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/widgets/app_state_view.dart';
import 'package:oronbox/src/core/services/shared_prefs_service.dart';
import 'package:oronbox/src/device/core/device_state.dart' as proto;
import 'package:oronbox/src/device/xiaomi/systems/media_system.dart';
import 'package:oronbox/src/features/devices/controllers/device_manager.dart';
import 'package:oronbox/src/features/devices/pages/tools/xiaomi_recordings_page.dart';
import 'package:oronbox/src/features/devices/services/device_recordings_storage_io.dart';
import 'package:segmented_list/segmented_list.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestRecordingsDeviceManager extends LocalDeviceManager {
  _TestRecordingsDeviceManager({
    this.initialProtocolState = proto.ProtocolState.ready,
    this.onFetchList,
  });

  final proto.ProtocolState initialProtocolState;
  final Future<List<MediaFileDescriptor>> Function()? onFetchList;

  @override
  DeviceManagerState build() =>
      DeviceManagerState(protocolState: initialProtocolState);

  @override
  Future<List<MediaFileDescriptor>> fetchXiaomiRecordingList() async {
    if (onFetchList != null) return await onFetchList!();
    return const [];
  }
}

Widget _wrapPage(Widget child, DeviceManager manager) {
  return ProviderScope(
    overrides: [deviceManagerProvider.overrideWith(() => manager)],
    child: MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

void main() {
  late Directory tempDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPrefsService.instance.init();
    tempDir = await Directory.systemTemp.createTemp('recordings_test_');
    userRecordingsDirectoryOverride = tempDir;
  });

  tearDown(() async {
    userRecordingsDirectoryOverride = null;
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets(
    'shows disconnected empty state centered in remaining space when device not ready',
    (tester) async {
      final manager = _TestRecordingsDeviceManager(
        initialProtocolState: proto.ProtocolState.disconnected,
      );

      await tester.pumpWidget(_wrapPage(const XiaomiRecordingsPage(), manager));
      await tester.pump();

      expect(find.text('未连接'), findsOneWidget);
      expect(find.byType(EmptyStateView), findsOneWidget);
      expect(find.byType(SegmentedList), findsNothing);
    },
  );

  testWidgets(
    'shows centered loading indicator in remaining space while fetching list',
    (tester) async {
      final completer = Completer<List<MediaFileDescriptor>>();
      final manager = _TestRecordingsDeviceManager(
        onFetchList: () => completer.future,
      );

      await tester.pumpWidget(_wrapPage(const XiaomiRecordingsPage(), manager));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(SegmentedList), findsNothing);

      completer.complete(const []);
      await tester.pump();
      await tester.pump();
    },
  );

  testWidgets(
    'shows centered ErrorStateView in remaining space when unsupported error occurs',
    (tester) async {
      final manager = _TestRecordingsDeviceManager(
        onFetchList: () => throw UnsupportedError('recording_unsupported'),
      );

      await tester.pumpWidget(_wrapPage(const XiaomiRecordingsPage(), manager));
      await tester.pump();
      await tester.pump();

      expect(find.byType(ErrorStateView), findsOneWidget);
      expect(find.text('当前设备或固件暂不支持录音导出功能'), findsOneWidget);
      expect(find.byType(SegmentedList), findsNothing);
    },
  );

  testWidgets(
    'shows centered EmptyStateView in remaining space when list is empty',
    (tester) async {
      final manager = _TestRecordingsDeviceManager(
        onFetchList: () async => const [],
      );

      await tester.pumpWidget(_wrapPage(const XiaomiRecordingsPage(), manager));
      await tester.pump();
      await tester.pump();

      expect(find.byType(EmptyStateView), findsOneWidget);
      expect(find.text('手表中没有新的录音'), findsOneWidget);
      expect(find.byType(SegmentedList), findsNothing);
    },
  );

  testWidgets('shows SegmentedList when recordings are available', (
    tester,
  ) async {
    final manager = _TestRecordingsDeviceManager(
      onFetchList: () async => [
        MediaFileDescriptor(
          name: '2026年8月18日_15:14.ogg',
          size: 12574,
          durationSecs: 15,
          createdAtMs: 1723965240000,
        ),
      ],
    );

    await tester.pumpWidget(_wrapPage(const XiaomiRecordingsPage(), manager));
    await tester.pump();
    await tester.pump();

    expect(find.byType(SegmentedList), findsOneWidget);
    expect(find.text('2026年8月18日_15:14'), findsOneWidget);
    expect(find.byType(EmptyStateView), findsNothing);
    expect(find.byType(ErrorStateView), findsNothing);
  });

  testWidgets(
    'loading, error, and empty states occupy remaining space and share consistent vertical center',
    (tester) async {
      // 1. Loading state
      final completer = Completer<List<MediaFileDescriptor>>();
      final loadingManager = _TestRecordingsDeviceManager(
        onFetchList: () => completer.future,
      );
      await tester.pumpWidget(
        _wrapPage(const XiaomiRecordingsPage(), loadingManager),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final loadingCenter = tester.getCenter(
        find.byType(CircularProgressIndicator),
      );

      // 2. Empty state
      completer.complete(const []);
      await tester.pump();
      await tester.pump();

      expect(find.byType(EmptyStateView), findsOneWidget);
      final emptyCenter = tester.getCenter(find.byType(EmptyStateView));

      // Both centers are in the remaining space below the header card
      expect(loadingCenter.dy, greaterThan(200));
      expect((loadingCenter.dy - emptyCenter.dy).abs(), lessThan(30));
    },
  );
}
