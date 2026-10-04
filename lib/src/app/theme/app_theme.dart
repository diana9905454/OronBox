import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.success,
    required this.warning,
    required this.info,
    required this.healthHeartRate,
    required this.healthRestingHeartRate,
    required this.healthBloodOxygen,
    required this.healthStress,
    required this.healthVitality,
    required this.healthSleep,
    required this.sleepAwake,
    required this.sleepRem,
    required this.sleepLight,
    required this.sleepDeep,
  });

  final Color success;
  final Color warning;
  final Color info;
  final Color healthHeartRate;
  final Color healthRestingHeartRate;
  final Color healthBloodOxygen;
  final Color healthStress;
  final Color healthVitality;
  final Color healthSleep;
  final Color sleepAwake;
  final Color sleepRem;
  final Color sleepLight;
  final Color sleepDeep;

  static AppSemanticColors defaults(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return AppSemanticColors(
      success: dark ? const Color(0xFF8BD49A) : const Color(0xFF2E7D32),
      warning: dark ? const Color(0xFFFFCC80) : const Color(0xFFB26A00),
      info: dark ? const Color(0xFF90CAF9) : const Color(0xFF1565C0),
      healthHeartRate: dark
          ? const Color(0xFFFF8A9A)
          : const Color(0xFFD32F2F),
      healthRestingHeartRate: dark
          ? const Color(0xFFFFAB91)
          : const Color(0xFFC2185B),
      healthBloodOxygen: dark
          ? const Color(0xFF9FA8DA)
          : const Color(0xFF3949AB),
      healthStress: dark ? const Color(0xFFFFCC80) : const Color(0xFFEF6C00),
      healthVitality: Colors.amber,
      healthSleep: dark ? const Color(0xFFB39DDB) : const Color(0xFF5E35B1),
      sleepAwake: const Color(0xFFB8C1D5),
      sleepRem: const Color(0xFF47BEFF),
      sleepLight: const Color(0xFF3986F6),
      sleepDeep: const Color(0xFF2231B6),
    );
  }

  @override
  AppSemanticColors copyWith({
    Color? success,
    Color? warning,
    Color? info,
    Color? healthHeartRate,
    Color? healthRestingHeartRate,
    Color? healthBloodOxygen,
    Color? healthStress,
    Color? healthVitality,
    Color? healthSleep,
    Color? sleepAwake,
    Color? sleepRem,
    Color? sleepLight,
    Color? sleepDeep,
  }) => AppSemanticColors(
    success: success ?? this.success,
    warning: warning ?? this.warning,
    info: info ?? this.info,
    healthHeartRate: healthHeartRate ?? this.healthHeartRate,
    healthRestingHeartRate:
        healthRestingHeartRate ?? this.healthRestingHeartRate,
    healthBloodOxygen: healthBloodOxygen ?? this.healthBloodOxygen,
    healthStress: healthStress ?? this.healthStress,
    healthVitality: healthVitality ?? this.healthVitality,
    healthSleep: healthSleep ?? this.healthSleep,
    sleepAwake: sleepAwake ?? this.sleepAwake,
    sleepRem: sleepRem ?? this.sleepRem,
    sleepLight: sleepLight ?? this.sleepLight,
    sleepDeep: sleepDeep ?? this.sleepDeep,
  );

  @override
  AppSemanticColors lerp(covariant AppSemanticColors? other, double t) {
    if (other == null) return this;
    return AppSemanticColors(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      info: Color.lerp(info, other.info, t)!,
      healthHeartRate: Color.lerp(healthHeartRate, other.healthHeartRate, t)!,
      healthRestingHeartRate: Color.lerp(
        healthRestingHeartRate,
        other.healthRestingHeartRate,
        t,
      )!,
      healthBloodOxygen: Color.lerp(
        healthBloodOxygen,
        other.healthBloodOxygen,
        t,
      )!,
      healthStress: Color.lerp(healthStress, other.healthStress, t)!,
      healthVitality: Color.lerp(healthVitality, other.healthVitality, t)!,
      healthSleep: Color.lerp(healthSleep, other.healthSleep, t)!,
      sleepAwake: Color.lerp(sleepAwake, other.sleepAwake, t)!,
      sleepRem: Color.lerp(sleepRem, other.sleepRem, t)!,
      sleepLight: Color.lerp(sleepLight, other.sleepLight, t)!,
      sleepDeep: Color.lerp(sleepDeep, other.sleepDeep, t)!,
    );
  }
}

extension AppThemeContext on BuildContext {
  AppSemanticColors get appColors =>
      Theme.of(this).extension<AppSemanticColors>() ??
      AppSemanticColors.defaults(Theme.of(this).brightness);

  Color get appSelectionContainer =>
      Theme.of(this).colorScheme.primaryContainer;

  Color get appSelectionForeground =>
      Theme.of(this).colorScheme.onPrimaryContainer;
}

ThemeData oledDarkTheme(ThemeData defaultDarkTheme) {
  return defaultDarkTheme.copyWith(
    scaffoldBackgroundColor: Colors.black,
    colorScheme: defaultDarkTheme.colorScheme.copyWith(
      onPrimary: Colors.black,
      onSecondary: Colors.black,
      surface: Colors.black,
      onSurface: Colors.white,
    ),
  );
}

abstract final class AppTheme {
  static const _windowsFontFallback = <String>[
    'Microsoft YaHei UI',
    'Microsoft YaHei',
    'DengXian',
    'SimSun',
    'Microsoft JhengHei UI',
    'Microsoft JhengHei',
    'Yu Gothic UI',
    'Malgun Gothic',
    'Noto Sans CJK SC',
    'Source Han Sans SC',
  ];

  static final ThemeData light = buildLightTheme();
  static final ThemeData dark = buildDarkTheme();
  static final ThemeData oledDark = oledDarkTheme(dark);

  static const pageTransitionsTheme = PageTransitionsTheme(
    builders: {
      TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
    },
  );

  static Widget buildPlatformPageTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final route = ModalRoute.of(context);
    if (route is! PageRoute<dynamic>) return child;
    final theme = Theme.of(context);
    final builder = theme.pageTransitionsTheme.builders[theme.platform];
    return builder?.buildTransitions(
          route,
          context,
          animation,
          secondaryAnimation,
          child,
        ) ??
        child;
  }

  static ThemeData buildLightTheme({ColorScheme? colorScheme}) {
    return _buildTheme(Brightness.light, colorScheme: colorScheme);
  }

  static ThemeData buildDarkTheme({ColorScheme? colorScheme}) {
    return _buildTheme(Brightness.dark, colorScheme: colorScheme);
  }

  static ThemeData buildOledDarkTheme({ColorScheme? colorScheme}) {
    return oledDarkTheme(buildDarkTheme(colorScheme: colorScheme));
  }

  static ThemeData _buildTheme(
    Brightness brightness, {
    ColorScheme? colorScheme,
  }) {
    final effectiveColorScheme = _withLayeredSurfaces(
      colorScheme ??
          ColorScheme.fromSeed(
            seedColor: const Color(0xFF6750A4),
            brightness: brightness,
          ),
    );

    return ThemeData(
      useMaterial3: true,
      fontFamilyFallback: defaultTargetPlatform == TargetPlatform.windows
          ? _windowsFontFallback
          : null,
      colorScheme: effectiveColorScheme,
      brightness: brightness,
      pageTransitionsTheme: pageTransitionsTheme,
      scaffoldBackgroundColor: effectiveColorScheme.surfaceContainerLowest,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        scrolledUnderElevation: 0,
        backgroundColor: effectiveColorScheme.surfaceContainerLowest,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarDividerColor: Colors.transparent,
          statusBarIconBrightness: brightness == Brightness.dark
              ? Brightness.light
              : Brightness.dark,
          statusBarBrightness: brightness,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: effectiveColorScheme.surfaceContainerHigh,
      ),
      chipTheme: ChipThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        side: BorderSide.none,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: effectiveColorScheme.primaryContainer,
          foregroundColor: effectiveColorScheme.onPrimaryContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: effectiveColorScheme.surfaceContainerHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: effectiveColorScheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 14,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: effectiveColorScheme.surfaceContainer,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: effectiveColorScheme.surfaceContainer,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        clipBehavior: Clip.antiAlias,
        showDragHandle: true,
        backgroundColor: effectiveColorScheme.surface,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        disabledElevation: 0,
      ),
      extensions: [
        AppSemanticColors.defaults(brightness),
      ],
    );
  }

  static ColorScheme _withLayeredSurfaces(ColorScheme colorScheme) {
    final light = colorScheme.brightness == Brightness.light;
    final base = colorScheme.surface;
    final tint = colorScheme.primary;
    final container = _tintedSurface(base, tint, light ? 0.035 : 0.08);
    final containerHigh = _tintedSurface(base, tint, light ? 0.065 : 0.12);
    final containerHighest = _tintedSurface(base, tint, light ? 0.095 : 0.16);

    return colorScheme.copyWith(
      surfaceContainerLowest: base,
      surfaceContainerLow: _tintedSurface(base, tint, light ? 0.02 : 0.055),
      surfaceContainer: container,
      surfaceContainerHigh: containerHigh,
      surfaceContainerHighest: containerHighest,
    );
  }

  static Color _tintedSurface(Color base, Color tint, double alpha) {
    return Color.alphaBlend(tint.withValues(alpha: alpha), base);
  }
}
