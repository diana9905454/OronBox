import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oronbox/src/app/oronbox_app.dart';
import 'package:oronbox/src/app/window/desktop_window_bootstrap.dart';
import 'package:oronbox/src/app/window/debug_window_preference.dart';
import 'package:oronbox/src/app/window/window_launch_spec.dart';
import 'package:oronbox/src/app/window/window_launcher.dart';
import 'package:oronbox/src/cli/cli_entrypoint.dart';
import 'package:oronbox/src/core/logging/logging_service.dart';
import 'package:oronbox/src/core/logging/diagnostic_event.dart';
import 'package:oronbox/src/core/services/license_registry_service.dart';
import 'package:oronbox/src/core/services/bluetooth_permission_bootstrap.dart';
import 'package:oronbox/src/core/services/shared_prefs_service.dart';
import 'package:oronbox/src/core/services/ohos_ble_channel.dart';
import 'package:oronbox/src/core/services/ohos_file_picker.dart';
import 'package:file_picker_platform_interface/file_picker_platform_interface.dart';
import 'package:oronbox/src/host/gui_host_overrides.dart';
import 'package:oronbox/src/features/devices/widgets/device_deep_link_handler.dart';
import 'package:oronbox/src/features/debug/pages/debug_window_app.dart';
import 'package:oronbox/src/features/plugins/pages/plugin_window_app.dart';
import 'package:universal_ble/universal_ble.dart';

void main(List<String> args) async {
  final startupStopwatch = Stopwatch()..start();
  WidgetsFlutterBinding.ensureInitialized();
  // 鸿蒙端：universal_ble 无原生实现，注入基于 @ohos.bluetooth.ble 的桥接实现。
  if (defaultTargetPlatform == TargetPlatform.ohos) {
    UniversalBle.setInstance(OhosUniversalBlePlatform.instance);
    // file_picker 同样无鸿蒙实现，注入基于鸿蒙 photoAccessHelper/picker 的桥接。
    FilePickerPlatform.instance = OhosFilePickerPlatform();
  }
  final window = WindowLaunchSpec.parse(args);
  final process = switch (window.role) {
    OronBoxWindowRole.debug => DiagnosticProcess.debugWindow,
    OronBoxWindowRole.plugin => DiagnosticProcess.pluginWindow,
    OronBoxWindowRole.main =>
      args.contains('--nogui')
          ? args.contains('daemon') && args.contains('run')
                ? DiagnosticProcess.backend
                : DiagnosticProcess.cli
          : DiagnosticProcess.frontend,
  };
  await initLogging(arguments: args, process: process);
  installGlobalErrorLogging();
  await SharedPrefsService.instance.init();
  await runCliIfRequested(args);
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
