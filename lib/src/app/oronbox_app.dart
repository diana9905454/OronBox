import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:oronbox/src/app/router/app_router.dart';
import 'package:oronbox/src/app/window/desktop_window_host.dart';
import 'package:oronbox/src/app/theme/app_theme.dart';
import 'package:oronbox/src/app/theme/dynamic_color_adapter.dart';
import 'package:oronbox/src/app/theme/system_accent_color.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/core/providers/theme_locale_providers.dart';
import 'package:oronbox/src/features/devices/services/xiaomi_automatic_sync_service.dart';
import 'package:oronbox/src/features/devices/widgets/device_deep_link_handler.dart';
import 'package:oronbox/src/features/devices/widgets/file_open_handler.dart';
import 'package:oronbox/src/features/devices/widgets/xms_wearable_bridge.dart';
import 'package:oronbox/src/features/plugins/widgets/plugin_host_request_handler.dart';
import 'package:oronbox/src/features/settings/services/update_check_service.dart';
import 'package:oronbox/src/app/widgets/app_error_gate.dart';
// material_ui resolves to package:flutter/material.dart on this Flutter fork.
import 'package:flutter/material.dart' as material_ui;

final _desktopAccentColorProvider = FutureProvider<Color?>((ref) {
  final source = ref.watch(
    themeSettingsProvider.select((settings) {
      return settings.desktopAccentColorSource;
    }),
  );
  return loadDesktopAccentColor(source);
});

class OronBoxApp extends ConsumerWidget {
  const OronBoxApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeSettings = ref.watch(themeSettingsProvider);
    final localeSettings = ref.watch(localeSettingsProvider);
    final desktopAccentColor = ref
        .watch(_desktopAccentColorProvider)
        .maybeWhen(data: (color) => color, orElse: () => null);

    return DynamicColorBuilder(
      builder:
          (
            material_ui.ColorScheme? lightDynamic,
            material_ui.ColorScheme? darkDynamic,
          ) {
            final lightFlutterDynamic = toFlutterColorScheme(lightDynamic);
            final darkFlutterDynamic = toFlutterColorScheme(darkDynamic);
            final useDynamicColor = themeSettings.useDynamicColor;
            final lightColorScheme = useDynamicColor
                ? lightFlutterDynamic ??
                      _desktopColorScheme(desktopAccentColor, Brightness.light)
                : _seedColorScheme(
                    themeSettings.customSeedColor,
                    Brightness.light,
                  );
            final darkColorScheme = useDynamicColor
                ? darkFlutterDynamic ??
                      _desktopColorScheme(desktopAccentColor, Brightness.dark)
                : _seedColorScheme(
                    themeSettings.customSeedColor,
                    Brightness.dark,
                  );

            return MaterialApp.router(
              title: 'OronBox',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.buildLightTheme(colorScheme: lightColorScheme),
              darkTheme: themeSettings.isOledDark
                  ? AppTheme.buildOledDarkTheme(colorScheme: darkColorScheme)
                  : AppTheme.buildDarkTheme(colorScheme: darkColorScheme),
              themeMode: themeSettings.materialThemeMode,
              locale: localeSettings.materialLocale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              scaffoldMessengerKey: appScaffoldMessengerKey,
              routerConfig: router,
              builder: (context, child) => DesktopWindowHost(
                child: AppErrorGate(
                  child: PluginHostRequestHandler(
                    child: XmsWearableBridge(
                      child: ConditionalUpdateCheckHandler(
                        child: FileOpenHandler(
                          child: XiaomiAutomaticSyncScheduler(
                            child: DeviceDeepLinkHandler(
                              child: child ?? const SizedBox.shrink(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
    );
  }

  ColorScheme? _desktopColorScheme(Color? accentColor, Brightness brightness) {
    if (accentColor == null) {
      return null;
    }
    return _seedColorScheme(accentColor, brightness);
  }

  ColorScheme _seedColorScheme(Color seedColor, Brightness brightness) {
    return ColorScheme.fromSeed(seedColor: seedColor, brightness: brightness);
  }
}
