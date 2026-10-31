import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/app/app_localizations_delegates.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/widgets/app_state_view.dart';
import 'package:oronbox/src/core/services/shared_prefs_service.dart';
import 'package:oronbox/src/device/core/device_state.dart' as proto;
import 'package:oronbox/src/features/devices/controllers/device_manager.dart';
import 'package:oronbox/src/features/devices/pages/tools/zeppos_music_upload_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestMusicDeviceManager extends LocalDeviceManager {
  _TestMusicDeviceManager({
    this.initialProtocolState = proto.ProtocolState.ready,
    this.onLoadLibrary,
  });

  final proto.ProtocolState initialProtocolState;
  final Future<DeviceMusicLibrary> Function()? onLoadLibrary;

  @override
  DeviceManagerState build() =>
      DeviceManagerState(protocolState: initialProtocolState);

  @override
  Future<DeviceMusicLibrary> loadXiaomiMusicLibrary() async {
    if (onLoadLibrary != null) return await onLoadLibrary!();
    throw UnsupportedError('music unsupported');
  }
}

Widget _wrapPage(Widget child, DeviceManager manager) {
  return ProviderScope(
    overrides: [deviceManagerProvider.overrideWith(() => manager)],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPrefsService.instance.init();
  });

  testWidgets(
    'disables MP3 picking and shows error in library card when Xiaomi music is unsupported',
    (tester) async {
      final manager = _TestMusicDeviceManager(
        initialProtocolState: proto.ProtocolState.ready,
        onLoadLibrary: () => throw UnsupportedError('music unsupported'),
      );

      await tester.pumpWidget(
        _wrapPage(const DeviceMusicUploadPage(xiaomi: true), manager),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ErrorStateView), findsOneWidget);
      expect(
        find.textContaining(
          'Music transfer is not supported by the current device or firmware',
        ),
        findsWidgets,
      );

      final chooseButton = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Select MP3 file'),
      );
      expect(chooseButton.onPressed, isNull);

      final sendButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Start transfer'),
      );
      expect(sendButton.onPressed, isNull);
    },
  );

  testWidgets('shows disconnected state when protocol is not ready', (
    tester,
  ) async {
    final manager = _TestMusicDeviceManager(
      initialProtocolState: proto.ProtocolState.disconnected,
    );

    await tester.pumpWidget(
      _wrapPage(const DeviceMusicUploadPage(xiaomi: true), manager),
    );
    await tester.pumpAndSettle();

    expect(find.text('Not connected'), findsOneWidget);

    final chooseButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Select MP3 file'),
    );
    expect(chooseButton.onPressed, isNull);

    final sendButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Start transfer'),
    );
    expect(sendButton.onPressed, isNull);
  });

  testWidgets(
    'enables MP3 picking when Xiaomi music library loads successfully',
    (tester) async {
      final manager = _TestMusicDeviceManager(
        initialProtocolState: proto.ProtocolState.ready,
        onLoadLibrary: () async => const DeviceMusicLibrary(
          playlists: [
            DeviceMusicPlaylist(id: 1, name: 'My Favorite', songCount: 1),
          ],
          songs: [
            DeviceMusicSong(
              id: [1, 2, 3],
              name: 'Test Song',
              size: 1024 * 1024,
              duration: 180,
              album: 'Album',
              artist: 'Artist',
            ),
          ],
          playlistLimit: 10,
        ),
      );

      await tester.pumpWidget(
        _wrapPage(const DeviceMusicUploadPage(xiaomi: true), manager),
      );
      await tester.pumpAndSettle();

      expect(find.text('My Favorite'), findsOneWidget);
      expect(find.text('Test Song'), findsOneWidget);

      final chooseButton = tester.widget<OutlinedButton>(
        find.byType(OutlinedButton),
      );
      expect(chooseButton.onPressed, isNotNull);
    },
  );
}
