import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oronbox/src/app/oronbox_app.dart';
import 'package:oronbox/src/app/window/desktop_window.dart';
import 'package:oronbox/src/core/logging/logging_service.dart';
import 'package:oronbox/src/core/logging/diagnostic_event.dart';
import 'package:oronbox/src/core/services/license_registry_service.dart';
import 'package:oronbox/src/core/services/bluetooth_permission_bootstrap.dart';
import 'package:oronbox/src/core/services/shared_prefs_service.dart';
import 'package:oronbox/src/host/gui_host_overrides.dart';
import 'package:oronbox/src/app/integrations/app_link_handler.dart';
import 'package:oronbox/src/features/debug/pages/debug_window_app.dart';
import 'package:oronbox/src/features/plugins/pages/plugin_window_app.dart';

void main(List<String> args) async {
  final startupStopwatch = Stopwatch()..start();
  WidgetsFlutterBinding.ensureInitialized();
  final window = WindowLaunchSpec.parse(args);
  final process = switch (window.role) {
    OronBoxWindowRole.debug => DiagnosticProcess.debugWindow,
    OronBoxWindowRole.plugin => DiagnosticProcess.pluginWindow,
    OronBoxWindowRole.main => DiagnosticProcess.frontend,
  };
  await initLogging(arguments: args, process: process);
  installGlobalErrorLogging();
  await SharedPrefsService.instance.init();
  if (!await initializeWindowCoordinator(window, launchArguments: args)) return;
  if (window.role == OronBoxWindowRole.main) {
    await requestBluetoothPermissionOnStartup();
  }
  await LicenseRegistryService.registerThirdPartyLicenses();
  await initializeDesktopWindow(spec: window);
  runApp(
    ProviderScope(
      overrides: [
        ...guiHostOverrides(),
        initialDeepLinksProvider.overrideWithValue(args),
      ],
      child: switch (window.role) {
        OronBoxWindowRole.debug => const DebugWindowApp(),
        OronBoxWindowRole.plugin => PluginWindowApp(
          pluginId: window.targetId ?? '',
        ),
        OronBoxWindowRole.main => const OronBoxApp(),
      },
    ),
  );
  startupStopwatch.stop();
  logDiagnostic(
    getLogger('Application'),
    Level.INFO,
    'OronBox startup completed',
    fields: {
      'durationMs': startupStopwatch.elapsedMilliseconds,
      'role': process.name,
    },
  );
  if (window.isSecondary) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(notifySecondaryWindowReady());
    });
  }
  if (window.role == OronBoxWindowRole.main &&
      !args.contains('--nogui') &&
      supportsSecondaryWindows &&
      isDebugWindowEnabled()) {
    unawaited(() async {
      if (!await openDebugWindow()) {
        await setDebugWindowEnabled(false);
      }
    }());
  }
}
