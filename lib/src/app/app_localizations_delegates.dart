import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';

/// Delegates for the extracted Material UI application root.
///
/// Flutter's generated l10n file still emits the legacy Material delegates;
/// keep that generated file untouched and provide the modern delegates at the
/// application boundary instead.
const appLocalizationsDelegates = <LocalizationsDelegate<dynamic>>[
  AppLocalizations.delegate,
  ...GlobalMaterialLocalizations.delegates,
];
