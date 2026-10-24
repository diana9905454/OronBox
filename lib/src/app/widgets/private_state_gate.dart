import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:oronbox/src/app/app_localizations_delegates.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/theme/app_theme.dart';
import 'package:oronbox/src/core/providers/theme_locale_providers.dart';
import 'package:oronbox/src/core/services/private_app_state.dart';

/// Do not initialize account/device providers until protected state is loaded.
class PrivateStateGate extends ConsumerStatefulWidget {
  const PrivateStateGate({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<PrivateStateGate> createState() => _PrivateStateGateState();
}

class _PrivateStateGateState extends ConsumerState<PrivateStateGate> {
  late Future<void> _ready;
  @override
  void initState() {
    super.initState();
    _ready = _initialize();
  }

  Future<void> _initialize() {
    final ready = PrivateAppState.instance.initialize();
    unawaited(ready.catchError((Object _) {}));
    return ready;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _ready,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.done &&
          !snapshot.hasError) {
        return widget.child;
      }
      final theme = ref.watch(themeSettingsProvider);
      return MaterialApp(
        title: 'OronBox',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.buildLightTheme(),
        darkTheme: theme.isOledDark
            ? AppTheme.buildOledDarkTheme()
            : AppTheme.buildDarkTheme(),
        themeMode: theme.materialThemeMode,
        locale: ref.watch(localeSettingsProvider).materialLocale,
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            final l10n = AppLocalizations.of(context)!;
            return Scaffold(
              body: SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: snapshot.hasError
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                l10n.privateStateLoadFailed,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              FilledButton(
                                onPressed: () => setState(() {
                                  _ready = _initialize();
                                }),
                                child: Text(l10n.retry),
                              ),
                            ],
                          )
                        : const CircularProgressIndicator(),
                  ),
                ),
              ),
            );
          },
        ),
      );
    },
  );
}
