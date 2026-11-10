import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
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
  Widget build(BuildContext context) {
    if (PrivateAppState.instance.isReady) {
      return widget.child;
    }
    return FutureBuilder<void>(
      future: _ready,
      builder: (context, snapshot) {
        if ((snapshot.connectionState == ConnectionState.done &&
                !snapshot.hasError) ||
            PrivateAppState.instance.isReady) {
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
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: () => _confirmReset(context, l10n),
                                  child: Text(l10n.resetPrivateStorageAction),
                                ),
                              ],
                            )
                          : _PrivateStateLoadingIndicator(l10n: l10n),
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

  Future<void> _confirmReset(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.resetPrivateStorageTitle),
        content: Text(l10n.resetPrivateStorageMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.confirmReset),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await PrivateAppState.instance.resetCorruptedState();
      if (mounted) {
        setState(() {
          _ready = Future.value();
        });
      }
    }
  }
}

class _PrivateStateLoadingIndicator extends StatefulWidget {
  const _PrivateStateLoadingIndicator({required this.l10n});
  final AppLocalizations l10n;

  @override
  State<_PrivateStateLoadingIndicator> createState() =>
      _PrivateStateLoadingIndicatorState();
}

class _PrivateStateLoadingIndicatorState
    extends State<_PrivateStateLoadingIndicator> {
  Timer? _timer;
  bool _showNotice = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 350), () {
      if (mounted) {
        setState(() => _showNotice = true);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final platformDetail = switch (defaultTargetPlatform) {
      TargetPlatform.macOS => widget.l10n.privateStateAccessPromptMacOs,
      TargetPlatform.linux => widget.l10n.privateStateAccessPromptLinux,
      _ => null,
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(),
        AnimatedOpacity(
          opacity: _showNotice ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 250),
          child: _showNotice
              ? Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.l10n.privateStateAccessPromptTitle,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        if (platformDetail != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            platformDetail,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
