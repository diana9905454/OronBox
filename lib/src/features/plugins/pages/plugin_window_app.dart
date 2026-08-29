import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/theme/app_theme.dart';
import 'package:oronbox/src/app/theme/dynamic_color_adapter.dart';
import 'package:oronbox/src/app/theme/system_accent_color.dart';
import 'package:oronbox/src/app/window/secondary_window_host.dart';
import 'package:oronbox/src/core/providers/theme_locale_providers.dart';
import 'package:oronbox/src/features/plugins/pages/plugin_detail_page.dart';
import 'package:oronbox/src/features/plugins/widgets/plugin_host_request_handler.dart';
import 'package:flutter/material.dart' as material_ui;

final _desktopAccentColorProvider = FutureProvider<Color?>((ref) {
  final source = ref.watch(
    themeSettingsProvider.select((settings) {
      return settings.desktopAccentColorSource;
    }),
  );
  return loadDesktopAccentColor(source);
});

class PluginWindowApp extends ConsumerWidget {
  const PluginWindowApp({super.key, required this.pluginId});
  final String pluginId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                      _colorScheme(desktopAccentColor, Brightness.light)
                : _colorScheme(themeSettings.customSeedColor, Brightness.light);
            final darkColorScheme = useDynamicColor
                ? darkFlutterDynamic ??
                      _colorScheme(desktopAccentColor, Brightness.dark)
                : _colorScheme(themeSettings.customSeedColor, Brightness.dark);

            return MaterialApp(
              title: 'OronBox Plugin',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.buildLightTheme(colorScheme: lightColorScheme),
              darkTheme: themeSettings.isOledDark
                  ? AppTheme.buildOledDarkTheme(colorScheme: darkColorScheme)
                  : AppTheme.buildDarkTheme(colorScheme: darkColorScheme),
              themeMode: themeSettings.materialThemeMode,
              locale: localeSettings.materialLocale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: SecondaryWindowHost(
                role: 'plugin.$pluginId',
                child: PluginHostRequestHandler(
                  child: PluginDetailPage(
                    pluginId: pluginId,
                    allowDetach: false,
                  ),
                ),
              ),
            );
          },
    );
  }

  ColorScheme? _colorScheme(Color? seedColor, Brightness brightness) {
    if (seedColor == null) return null;
    return ColorScheme.fromSeed(seedColor: seedColor, brightness: brightness);
  }
}
