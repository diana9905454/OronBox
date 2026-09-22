// The legacy roles are still passed through for themes that read them, but
// they are deprecated in the current Material color API.
// ignore_for_file: deprecated_member_use

// material_ui is now package:flutter/material.dart (Dart 3.11.5 / Flutter 3.41.9
// ships with the in-tree Material library; the externally extracted material_ui
// package only became available for Dart 3.12+).
import 'package:flutter/material.dart' as flutter;
import 'package:flutter/material.dart' as material_ui;

/// Converts the `material_ui` color scheme returned by dynamic_color 2.x to
/// Flutter's Material color scheme used by the rest of OronBox.
///
/// dynamic_color 2.x follows Flutter's extracted Material library, while the
/// application still uses `package:flutter/material.dart`. Keeping this
/// boundary in one place lets the app adopt the newer dynamic-color plugin
/// without mixing two incompatible ColorScheme types throughout the UI.
flutter.ColorScheme? toFlutterColorScheme(material_ui.ColorScheme? scheme) {
  if (scheme == null) return null;

  return flutter.ColorScheme(
    brightness: scheme.brightness,
    primary: scheme.primary,
    onPrimary: scheme.onPrimary,
    primaryContainer: scheme.primaryContainer,
    onPrimaryContainer: scheme.onPrimaryContainer,
    primaryFixed: scheme.primaryFixed,
    primaryFixedDim: scheme.primaryFixedDim,
    onPrimaryFixed: scheme.onPrimaryFixed,
    onPrimaryFixedVariant: scheme.onPrimaryFixedVariant,
    secondary: scheme.secondary,
    onSecondary: scheme.onSecondary,
    secondaryContainer: scheme.secondaryContainer,
    onSecondaryContainer: scheme.onSecondaryContainer,
    secondaryFixed: scheme.secondaryFixed,
    secondaryFixedDim: scheme.secondaryFixedDim,
    onSecondaryFixed: scheme.onSecondaryFixed,
    onSecondaryFixedVariant: scheme.onSecondaryFixedVariant,
    tertiary: scheme.tertiary,
    onTertiary: scheme.onTertiary,
    tertiaryContainer: scheme.tertiaryContainer,
    onTertiaryContainer: scheme.onTertiaryContainer,
    tertiaryFixed: scheme.tertiaryFixed,
    tertiaryFixedDim: scheme.tertiaryFixedDim,
    onTertiaryFixed: scheme.onTertiaryFixed,
    onTertiaryFixedVariant: scheme.onTertiaryFixedVariant,
    error: scheme.error,
    onError: scheme.onError,
    errorContainer: scheme.errorContainer,
    onErrorContainer: scheme.onErrorContainer,
    surface: scheme.surface,
    onSurface: scheme.onSurface,
    surfaceDim: scheme.surfaceDim,
    surfaceBright: scheme.surfaceBright,
    surfaceContainerLowest: scheme.surfaceContainerLowest,
    surfaceContainerLow: scheme.surfaceContainerLow,
    surfaceContainer: scheme.surfaceContainer,
    surfaceContainerHigh: scheme.surfaceContainerHigh,
    surfaceContainerHighest: scheme.surfaceContainerHighest,
    onSurfaceVariant: scheme.onSurfaceVariant,
    outline: scheme.outline,
    outlineVariant: scheme.outlineVariant,
    shadow: scheme.shadow,
    scrim: scheme.scrim,
    inverseSurface: scheme.inverseSurface,
    onInverseSurface: scheme.onInverseSurface,
    inversePrimary: scheme.inversePrimary,
    surfaceTint: scheme.surfaceTint,
    background: scheme.background,
    onBackground: scheme.onBackground,
    surfaceVariant: scheme.surfaceVariant,
  );
}
