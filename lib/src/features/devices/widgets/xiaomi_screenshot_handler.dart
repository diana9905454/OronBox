import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/widgets/app_scaffold_messenger.dart';
import 'package:oronbox/src/commands/command_protocol.dart';
import 'package:oronbox/src/core/logging/logging_service.dart';
import 'package:oronbox/src/features/devices/services/xiaomi_screenshot_storage.dart';
import 'package:oronbox/src/host/application_host_provider.dart';

final xiaomiScreenshotSaverProvider =
    Provider<Future<String?> Function(Uint8List)>(
      (ref) => saveXiaomiScreenshot,
    );

class XiaomiScreenshotHandler extends ConsumerStatefulWidget {
  const XiaomiScreenshotHandler({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<XiaomiScreenshotHandler> createState() =>
      _XiaomiScreenshotHandlerState();
}

class _XiaomiScreenshotHandlerState
    extends ConsumerState<XiaomiScreenshotHandler> {
  static final _log = getLogger('XiaomiScreenshotHandler');
  StreamSubscription<CommandEvent>? _subscription;
  Future<void> _saveTail = Future<void>.value();

  @override
  void initState() {
    super.initState();
    final save = ref.read(xiaomiScreenshotSaverProvider);
    _subscription = ref.read(applicationHostProvider).events.listen((event) {
      if (event.event != 'device.xiaomi.screenshot.received') return;
      _saveTail = _saveTail.then((_) => _save(event.data, save));
    });
  }

  Future<void> _save(
    Map<String, Object?> data,
    Future<String?> Function(Uint8List) save,
  ) async {
    String? path;
    try {
      final raw = data['bytes'];
      if (raw is! List ||
          raw.isEmpty ||
          raw.any((value) => value is! int || value < 0 || value > 255)) {
        throw const FormatException('Invalid screenshot event bytes');
      }
      path = await save(Uint8List.fromList(raw.cast<int>()));
      if (path == null || path.isEmpty) {
        throw UnsupportedError('Screenshot storage returned no saved path');
      }
      _log.info('Wearable screenshot saved: $path');
    } catch (error, stackTrace) {
      _log.warning('Saving wearable screenshot failed', error, stackTrace);
      path = null;
    }
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    appScaffoldMessengerOf(context).showSnackBar(
      SnackBar(
        content: Text(
          path == null
              ? l10n.xiaomiScreenshotSaveFailed
              : kIsWeb
              ? l10n.xiaomiScreenshotDownloadStarted
              : l10n.xiaomiScreenshotSaved(path),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
