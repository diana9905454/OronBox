import 'package:segmented_list/segmented_list.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/utils/error_localization.dart';
import 'package:oronbox/src/app/window/debug_window_preference.dart';
import 'package:oronbox/src/app/window/window_launcher.dart';
import 'package:oronbox/src/app/widgets/sys_app_bar.dart';
import 'package:oronbox/src/app/widgets/dialog_helper.dart';
import 'package:oronbox/src/core/constants/style_constants.dart';
import 'package:oronbox/src/core/providers/app_settings_providers.dart';
import 'package:oronbox/src/core/providers/theme_locale_providers.dart';
import 'package:oronbox/src/core/services/shared_prefs_service.dart';
import 'package:oronbox/src/core/utils/layout.dart';
import 'package:oronbox/src/core/network/github_cdn.dart';
import 'package:oronbox/src/features/resources/application/resource_catalog_providers.dart';
import 'package:oronbox/src/features/resources/application/creator/creator_workspace_controller.dart';
import 'package:oronbox/src/features/resources/pages/creator/creator_shared.dart';
import 'package:oronbox/src/features/accounts/application/host_accounts.dart';
import 'package:oronbox/src/features/accounts/services/mi_account_two_factor_resolver.dart';

final _desktopExitBehaviorProvider = Provider<int?>((ref) {
  return SharedPrefsService.instance.getInt('desktop.exit_behavior');
});

enum SettingsCategory { accounts, appearance, connection, support, advanced }

String _categoryTitle(AppLocalizations l10n, SettingsCategory category) =>
    switch (category) {
      SettingsCategory.accounts => l10n.settingsCategoryAccounts,
      SettingsCategory.appearance => l10n.settingsCategoryAppearance,
      SettingsCategory.connection => l10n.settingsCategoryConnection,
      SettingsCategory.support => l10n.settingsCategorySupport,
      SettingsCategory.advanced => l10n.settingsCategoryAdvanced,
    };

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key, this.category});

  final SettingsCategory? category;

  static const _colorSchemes = <Color>[
    Color(0xFFE91E63),
    Color(0xFF6750A4),
    Color(0xFF006A6A),
    Color(0xFF006D3F),
    Color(0xFFB3261E),
    Color(0xFF755B00),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final showDesktopAccentSource =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.linux;
    final showWideNavigationPosition = useWideLayout(
      MediaQuery.sizeOf(context).width,
    );
    final showDesktopWindowSettings =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.macOS);
    final showDebugWindowSettings =
        showDesktopWindowSettings ||
        (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);
    final themeSettings = ref.watch(themeSettingsProvider);
    final debugWindowEnabled = ref.watch(debugWindowEnabledProvider);
    final clean = ref.watch(appSettingsProvider).clean;

    return Scaffold(
      appBar: SysAppBar(
        secondary: category != null,
        title: Text(
          category == null ? l10n.settingsTab : _categoryTitle(l10n, category!),
        ),
      ),
      body: SegmentedList(
        maxWidth: StyleConstants.pageMaxWidth,
        contentPadding: const EdgeInsets.only(top: StyleConstants.pagePadding),
        sections: [
          if (category == null || category == SettingsCategory.accounts)
            _buildSection(
              context,
              title: l10n.settingsAccount,
              tiles: [
                SegmentedTile.navigation(
                  onPressed: (_) =>
                      SettingsPage.showMiAccountLoginDialog(context, ref),
                  leading: const MiLogo(),
                  title: Text(l10n.settingsMiAccount),
                  description: Consumer(
                    builder: (context, ref, _) {
                      final account = ref.watch(hostAccountsProvider).xiaomi;
                      if (account.isSignedIn) {
                        return Text(
                          account.userId?.isNotEmpty == true
                              ? account.userId!
                              : l10n.settingsConnected,
                        );
                      }
                      return Text(l10n.settingsMiAccountDesc);
                    },
                  ),
                  value: Consumer(
                    builder: (context, ref, _) {
                      final account = ref.watch(hostAccountsProvider).xiaomi;
                      if (account.isBusy) {
                        return const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        );
                      }
                      return Text(
                        account.isSignedIn
                            ? l10n.settingsConnected
                            : l10n.settingsTapToSignIn,
                      );
                    },
                  ),
                ),
                SegmentedTile.navigation(
                  onPressed: (_) => _showHuamiAccountLogin(context, ref),
                  leading: const _AccountLeading(child: Icon(Icons.functions)),
                  title: Text(l10n.settingsHuamiAccount),
                  description: Consumer(
                    builder: (context, ref, _) {
                      final account = ref.watch(hostAccountsProvider).amazfit;
                      if (account.isBusy) {
                        return Text(l10n.settingsHuamiAccountSigningIn);
                      }
                      if (account.isSignedIn) {
                        return Text(
                          account.username?.isNotEmpty == true
                              ? account.username!
                              : l10n.settingsConnected,
                        );
                      }
                      return Text(l10n.settingsHuamiAccountDesc);
                    },
                  ),
                  value: Consumer(
                    builder: (context, ref, _) {
                      final account = ref.watch(hostAccountsProvider).amazfit;
                      if (account.isBusy) {
                        return const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        );
                      }
                      return Text(
                        account.isSignedIn
                            ? l10n.settingsConnected
                            : l10n.settingsTapToSignIn,
                      );
                    },
                  ),
                ),
                if (clean.bandBbsLoginEnabled)
                  SegmentedTile.navigation(
                    onPressed: (_) {
                      final account = ref.read(hostAccountsProvider).bandbbs;
                      if (account.isSignedIn) {
                        context.push('/settings/bandbbs');
                      } else if (!account.isBusy) {
                        _startBandBbsLogin(context, ref);
                      }
                    },
                    leading: _AccountBrandLogo(
                      asset: 'assets/images/brands/bandbbs.svg',
                      semanticsLabel: 'BandBBS',
                    ),
                    title: Text(l10n.settingsAccountBandBbsAccount),
                    description: Consumer(
                      builder: (context, ref, _) {
                        final account = ref.watch(hostAccountsProvider).bandbbs;
                        if (account.isBusy) {
                          return Text(l10n.settingsAccountBandBbsSigningIn);
                        }
                        if (account.isSignedIn) {
                          final username = account.username?.trim() ?? '';
                          final userId = account.userId?.trim() ?? '';
                          if (username.isNotEmpty && userId.isNotEmpty) {
                            return Text('$username · $userId');
                          }
                          if (username.isNotEmpty) return Text(username);
                          if (userId.isNotEmpty) return Text(userId);
                          return Text(l10n.settingsConnected);
                        }
                        return Text(l10n.settingsAccountLoginBBSDesc);
                      },
                    ),
                    value: Consumer(
                      builder: (context, ref, _) {
                        final account = ref.watch(hostAccountsProvider).bandbbs;
                        if (account.isBusy) {
                          return const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          );
                        }
                        return Text(
                          account.isSignedIn
                              ? l10n.settingsConnected
                              : l10n.settingsTapToSignIn,
                        );
                      },
                    ),
                  ),
                if (clean.githubLoginEnabled)
                  SegmentedTile.navigation(
                    onPressed: (_) => _connectGitHub(context, ref),
                    leading: _AccountBrandLogo(
                      asset: 'assets/images/brands/github.svg',
                      semanticsLabel: 'GitHub',
                    ),
                    title: Text(l10n.settingsAccountGitHub),
                    description: Consumer(
                      builder: (context, ref, _) {
                        final signedIn = ref.watch(
                          hostAccountsProvider.select(
                            (value) => value.bandbbs.isSignedIn,
                          ),
                        );
                        if (!signedIn) {
                          return Text(l10n.githubAccountNeedsBandBbs);
                        }
                        final login =
                            ref
                                .watch(
                                  creatorWorkspaceProvider.select(
                                    (state) => state.grants['github_login'],
                                  ),
                                )
                                ?.toString() ??
                            '';
                        return Text(
                          login.isNotEmpty
                              ? login
                              : l10n.settingsAccountGitHubDesc,
                        );
                      },
                    ),
                    value: Consumer(
                      builder: (context, ref, _) {
                        final workspace = ref.watch(creatorWorkspaceProvider);
                        if (workspace.operation ==
                            CreatorOperation.authorizing) {
                          return const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          );
                        }
                        final connected =
                            (workspace.grants['github_login']?.toString() ?? '')
                                .isNotEmpty;
                        return Text(
                          connected
                              ? l10n.settingsConnected
                              : l10n.settingsTapToSignIn,
                        );
                      },
                    ),
                  ),
              ],
            ),
          if (category == null || category == SettingsCategory.appearance)
            _buildSection(
              context,
              title: l10n.settingsGeneral,
              tiles: [
                SegmentedTile.navigation(
                  onPressed: (context) => _showLanguageSelector(context, ref),
                  leading: const Icon(Icons.language_outlined),
                  title: Text(l10n.settingsGeneralLanguage),
                  description: Text(l10n.settingsGeneralLanguageDesc),
                  value: Consumer(
                    builder: (context, ref, _) {
                      final locale = ref.watch(localeSettingsProvider).locale;
                      return Text(_localeLabel(l10n, locale));
                    },
                  ),
                ),
                SegmentedTile.navigation(
                  onPressed: (context) => _showThemeModeSelector(context, ref),
                  leading: const Icon(Icons.dark_mode_outlined),
                  title: Text(l10n.settingsThemeMode),
                  description: Text(l10n.settingsThemeModeDesc),
                  value: Text(_themeModeLabel(l10n, themeSettings.themeMode)),
                ),
                if (!kIsWeb)
                  SegmentedTile.switchTile(
                    onToggle: (value) async {
                      await ref
                          .read(themeSettingsProvider.notifier)
                          .setDynamicColor(value ?? true);
                    },
                    initialValue: themeSettings.useDynamicColor,
                    leading: const Icon(Icons.palette_outlined),
                    title: Text(l10n.settingsDynamicColor),
                    description: Text(l10n.settingsDynamicColorDesc),
                  ),
                if (!kIsWeb && !themeSettings.useDynamicColor)
                  SegmentedTile.navigation(
                    onPressed: (context) =>
                        _showColorSchemeSelector(context, ref),
                    leading: const Icon(Icons.color_lens_outlined),
                    title: Text(l10n.settingsColorScheme),
                    description: Text(l10n.settingsColorSchemeDesc),
                    value: _ColorDot(color: themeSettings.customSeedColor),
                  ),
                if (showDesktopAccentSource && themeSettings.useDynamicColor)
                  SegmentedTile.navigation(
                    onPressed: (context) =>
                        _showDesktopAccentSourceSelector(context, ref),
                    leading: const Icon(Icons.color_lens_outlined),
                    title: Text(l10n.settingsDesktopAccentSource),
                    description: Text(l10n.settingsDesktopAccentSourceDesc),
                    value: Consumer(
                      builder: (context, ref, _) {
                        final source = ref
                            .watch(themeSettingsProvider)
                            .desktopAccentColorSource;
                        return Text(_desktopAccentSourceLabel(l10n, source));
                      },
                    ),
                  ),
                if (showWideNavigationPosition)
                  SegmentedTile.navigation(
                    onPressed: (context) =>
                        _showWideNavigationPositionSelector(context, ref),
                    leading: const Icon(Icons.vertical_split_outlined),
                    title: Text(l10n.settingsWideNavigationPosition),
                    description: Text(l10n.settingsWideNavigationPositionDesc),
                    value: Consumer(
                      builder: (context, ref, _) {
                        final position = ref
                            .watch(appSettingsProvider)
                            .wideNavigationRailPosition;
                        return Text(
                          _wideNavigationPositionLabel(l10n, position),
                        );
                      },
                    ),
                  ),
                if (showDesktopWindowSettings)
                  SegmentedTile.navigation(
                    onPressed: (context) =>
                        _showDesktopExitBehaviorMenu(context, ref),
                    leading: const Icon(Icons.close_fullscreen_outlined),
                    title: Text(l10n.settingsDesktopCloseBehavior),
                    description: Text(l10n.settingsDesktopCloseBehaviorDesc),
                    value: Text(
                      _desktopExitBehaviorLabel(
                        l10n,
                        ref.watch(_desktopExitBehaviorProvider),
                      ),
                    ),
                  ),
                SegmentedTile.navigation(
                  onPressed: (context) => context.push('/settings/clean-mode'),
                  leading: const Icon(Icons.filter_alt_outlined),
                  title: Text(l10n.cleanMode),
                  description: Text(l10n.cleanModeDescription),
                ),
              ],
            ),
          if (category == null || category == SettingsCategory.connection)
            _buildSection(
              context,
              title: l10n.settingsCategoryConnection,
              tiles: [
                SegmentedTile.switchTile(
                  onToggle: (value) async {
                    await ref
                        .read(appSettingsProvider.notifier)
                        .setAutoReconnect(value ?? false);
                  },
                  initialValue: ref.watch(appSettingsProvider).autoReconnect,
                  leading: const Icon(Icons.bluetooth_connected_outlined),
                  title: Text(l10n.settingsAutoReconnectTitle),
                  description: Text(l10n.settingsAutoReconnectDesc),
                ),
                SegmentedTile.switchTile(
                  onToggle: (value) async {
                    await ref
                        .read(appSettingsProvider.notifier)
                        .setAutoReconnectOnDisconnect(value ?? false);
                  },
                  initialValue: ref
                      .watch(appSettingsProvider)
                      .autoReconnectOnDisconnect,
                  leading: const Icon(Icons.bluetooth_disabled_outlined),
                  title: Text(l10n.settingsAutoReconnectOnDisconnectTitle),
                  description: Text(l10n.settingsAutoReconnectOnDisconnectDesc),
                ),
                SegmentedTile.switchTile(
                  onToggle: (value) async {
                    await ref
                        .read(appSettingsProvider.notifier)
                        .setRemoveBondBeforeSpp(value ?? false);
                  },
                  initialValue: ref
                      .watch(appSettingsProvider)
                      .removeBondBeforeSpp,
                  leading: const Icon(Icons.bluetooth_searching_outlined),
                  title: Text(l10n.settingsRemoveBondBeforeSpp),
                  description: Text(l10n.settingsRemoveBondBeforeSppDesc),
                ),
                SegmentedTile.navigation(
                  onPressed: (context) => _showCdnMenu(context, ref),
                  leading: const Icon(Icons.cloud_outlined),
                  title: Text(l10n.settingsSourceOfficialCdn),
                  description: Text(l10n.settingsSourceOfficialCdnDesc),
                  value: Text(
                    ref.watch(appSettingsProvider).cdn == GitHubCdn.auto
                        ? l10n.settingsGithubCdnAuto
                        : ref.watch(appSettingsProvider).cdn.displayName,
                  ),
                ),
                SegmentedTile.switchTile(
                  onToggle: (value) async {
                    await ref
                        .read(appSettingsProvider.notifier)
                        .setAutoInstall(value ?? true);
                  },
                  initialValue: ref.watch(appSettingsProvider).autoInstall,
                  leading: const Icon(Icons.task_alt_outlined),
                  title: Text(l10n.settingsQueueAutoInstall),
                  description: Text(l10n.settingsQueueAutoInstallDesc),
                ),
                SegmentedTile.switchTile(
                  onToggle: (value) async {
                    await ref
                        .read(appSettingsProvider.notifier)
                        .setDisableAutoClean(value ?? false);
                  },
                  initialValue: ref.watch(appSettingsProvider).disableAutoClean,
                  leading: const Icon(Icons.playlist_add_check_outlined),
                  title: Text(l10n.settingsQueueDontClear),
                  description: Text(l10n.settingsQueueDontClearDesc),
                ),
                // 鸿蒙端不提供实时活动通知（实况窗是系统受控能力，第三方无法接入）。
                if (defaultTargetPlatform != TargetPlatform.ohos)
                  SegmentedTile.switchTile(
                    onToggle: (value) async {
                      await ref
                          .read(appSettingsProvider.notifier)
                          .setRealtimeActivityNotification(value ?? true);
                    },
                    initialValue: ref
                        .watch(appSettingsProvider)
                        .realtimeActivityNotification,
                    leading: const Icon(Icons.notifications_active_outlined),
                    title: Text(l10n.settingsRealtimeActivityNotification),
                    description: Text(
                      l10n.settingsRealtimeActivityNotificationDesc,
                    ),
                  ),
              ],
            ),
          if (category == null || category == SettingsCategory.support)
            _buildSection(
              context,
              title: l10n.settingsAbout,
              tiles: [
                SegmentedTile.navigation(
                  onPressed: (_) => context.push('/settings/about'),
                  leading: const Icon(Icons.info_outline),
                  title: Text(l10n.settingsAboutSoftware),
                  description: Text(l10n.settingsAboutSoftwareDesc),
                ),
                SegmentedTile.navigation(
                  onPressed: (_) => launchUrl(
                    Uri.parse('https://qm.qq.com/q/il3TbmJlKM'),
                    mode: LaunchMode.externalApplication,
                  ),
                  leading: const Icon(Icons.forum_outlined),
                  title: Text(l10n.joinQqGroup),
                  description: Text(l10n.joinQqGroupDesc),
                ),
                SegmentedTile.navigation(
                  onPressed: (_) => context.push('/settings/feedback'),
                  leading: const Icon(Icons.feedback_outlined),
                  title: Text(l10n.feedbackTitle),
                  description: Text(l10n.feedbackDesc),
                ),
                SegmentedTile.navigation(
                  onPressed: (_) => context.push('/settings/advanced'),
                  leading: const Icon(Icons.tune_outlined),
                  title: Text(l10n.settingsCategoryAdvanced),
                  description: Text(l10n.settingsAdvancedDescription),
                ),
              ],
            ),
          if (category == SettingsCategory.advanced)
            _buildSection(
              context,
              title: null,
              tiles: [
                SegmentedTile.navigation(
                  onPressed: (_) => context.push('/oobe?replay=1'),
                  leading: const Icon(Icons.waving_hand_outlined),
                  title: Text(l10n.settingsReplayOobe),
                  description: Text(l10n.settingsReplayOobeDesc),
                ),
                SegmentedTile.navigation(
                  onPressed: (_) => context.push('/settings/logs'),
                  leading: const Icon(Icons.folder_outlined),
                  title: Text(l10n.settingsAboutLogs),
                  description: Text(l10n.settingsAboutLogsDescription),
                ),
                SegmentedTile.navigation(
                  onPressed: (_) => context.push('/settings/debug-server'),
                  leading: const Icon(Icons.developer_mode_outlined),
                  title: Text(l10n.debugServerTitle),
                  description: Text(l10n.debugServerDescription),
                ),
                if (showDebugWindowSettings)
                  SegmentedTile.switchTile(
                    onToggle: (value) =>
                        _setDebugWindowEnabled(context, ref, value ?? false),
                    initialValue: debugWindowEnabled,
                    leading: const Icon(Icons.bug_report_outlined),
                    title: Text(l10n.devTools),
                    description: Text(
                      showDesktopWindowSettings
                          ? l10n.devToolsDescriptionDesktop
                          : l10n.devToolsDescriptionEntry,
                    ),
                  ),
                if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
                  SegmentedTile.switchTile(
                    onToggle: (value) => ref
                        .read(xmsDeveloperModeProvider.notifier)
                        .setEnabled(value ?? false),
                    initialValue: ref.watch(xmsDeveloperModeProvider),
                    leading: const Icon(Icons.phonelink_setup_outlined),
                    title: Text(l10n.xmsDeveloperMode),
                    description: Text(l10n.xmsDeveloperModeDescription),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  SegmentedSection _buildSection(
    BuildContext context, {
    required String? title,
    required List<AbstractSegmentedTile> tiles,
  }) {
    return SegmentedSection(
      title: title == null ? null : Text(title),
      tiles: tiles,
    );
  }

  Future<void> _setDebugWindowEnabled(
    BuildContext context,
    WidgetRef ref,
    bool enabled,
  ) async {
    final notifier = ref.read(debugWindowEnabledProvider.notifier);
    if (showDesktopWindowOnly) {
      final succeeded = enabled
          ? await openDebugWindow()
          : await closeDebugWindow();
      if (!succeeded) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!.devToolsOperationFailed,
              ),
            ),
          );
        }
        return;
      }
    }
    await notifier.setEnabled(enabled);
  }

  bool get showDesktopWindowOnly =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS);

  String _localeLabel(AppLocalizations l10n, AppLocale locale) {
    return switch (locale) {
      AppLocale.en => 'English',
      AppLocale.zh => '简体中文',
      AppLocale.zhHant => '繁體中文',
      AppLocale.ja => '日本語',
      AppLocale.ru => 'Русский',
      _ => l10n.settingsSystem,
    };
  }

  String _themeModeLabel(AppLocalizations l10n, AppThemeMode mode) {
    return switch (mode) {
      AppThemeMode.light => l10n.settingsLight,
      AppThemeMode.dark => l10n.settingsDark,
      AppThemeMode.oledDark => l10n.settingsOledDark,
      _ => l10n.settingsSystem,
    };
  }

  String _desktopAccentSourceLabel(
    AppLocalizations l10n,
    DesktopAccentColorSource source,
  ) {
    return switch (source) {
      DesktopAccentColorSource.gtk => l10n.settingsDesktopAccentSourceGtk,
      DesktopAccentColorSource.qt => l10n.settingsDesktopAccentSourceQt,
      _ => l10n.settingsDesktopAccentSourceSystem,
    };
  }

  String _wideNavigationPositionLabel(
    AppLocalizations l10n,
    WideNavigationRailPosition position,
  ) {
    return switch (position) {
      WideNavigationRailPosition.center =>
        l10n.settingsWideNavigationPositionCenter,
      WideNavigationRailPosition.split =>
        l10n.settingsWideNavigationPositionSplit,
      _ => l10n.settingsWideNavigationPositionBottom,
    };
  }

  Future<void> _showCdnMenu(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final current = ref.read(appSettingsProvider).cdn;
    final tileContext = context;
    final renderBox = tileContext.findRenderObject() as RenderBox?;
    final overlay =
        Navigator.of(tileContext).overlay?.context.findRenderObject()
            as RenderBox?;
    if (renderBox == null || overlay == null) return;

    final tileTopLeft = renderBox.localToGlobal(Offset.zero, ancestor: overlay);
    final tileBottomRight = renderBox.localToGlobal(
      renderBox.size.bottomRight(Offset.zero),
      ancestor: overlay,
    );
    final anchor = Rect.fromLTWH(
      tileBottomRight.dx - 48,
      tileTopLeft.dy,
      48,
      renderBox.size.height,
    );

    final selected = await showMenu<GitHubCdn>(
      context: tileContext,
      position: RelativeRect.fromRect(anchor, Offset.zero & overlay.size),
      initialValue: current,
      items: GitHubCdn.values.map((cdn) {
        return PopupMenuItem<GitHubCdn>(
          value: cdn,
          child: Text(
            cdn == GitHubCdn.auto
                ? l10n.settingsGithubCdnAuto
                : cdn.displayName,
          ),
        );
      }).toList(),
    );
    if (selected != null && selected != current) {
      await ref.read(appSettingsProvider.notifier).setCdn(selected);
      ref.invalidate(communityCatalogDevicesProvider);
    }
  }

  static Future<void> showMiAccountLoginDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final rootContext = context;
    final l10n = AppLocalizations.of(context)!;
    final accounts = ref.read(hostAccountsProvider.notifier);
    final credentials = await accounts.rememberedCredentials('xiaomi');
    final existing = ref.read(hostAccountsProvider).xiaomi;
    var rememberCredentials = credentials['remember'] == true;
    var username = rememberCredentials
        ? credentials['username']?.toString() ?? ''
        : '';
    var password = rememberCredentials
        ? credentials['password']?.toString() ?? ''
        : '';
    var running = false;
    var obscurePassword = true;
    String? error;
    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> submit() async {
              final normalizedUsername = username.trim();
              if (normalizedUsername.isEmpty || password.isEmpty) {
                setState(() {
                  error = l10n.settingsMiAccountMissingCredentials;
                });
                return;
              }
              setState(() {
                running = true;
                error = null;
              });
              try {
                final account = await ref
                    .read(hostAccountsProvider.notifier)
                    .loginXiaomi(
                      username: normalizedUsername,
                      password: password,
                    );
                await accounts.saveCredentials(
                  provider: 'xiaomi',
                  remember: rememberCredentials,
                  username: normalizedUsername,
                  password: password,
                  userId: account.userId ?? '',
                );
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
                if (rootContext.mounted) {
                  ScaffoldMessenger.of(rootContext).showSnackBar(
                    SnackBar(
                      content: Text(
                        l10n.settingsMiAccountSyncedDevices(
                          account.syncedDevices,
                        ),
                      ),
                    ),
                  );
                }
              } on HostTwoFactorRequired catch (e) {
                try {
                  setState(() {
                    error = l10n.settingsMiAccountTwoFactorPrompt;
                  });
                  if (!rootContext.mounted) {
                    throw StateError(l10n.settingsMiAccountLoginWindowClosed);
                  }
                  final cookieHeader = await createMiAccountTwoFactorResolver()
                      .resolve(rootContext, Uri.parse(e.url));
                  final account = await ref
                      .read(hostAccountsProvider.notifier)
                      .completeXiaomiTwoFactor(
                        challenge: e,
                        cookieHeader: cookieHeader,
                      );
                  await accounts.saveCredentials(
                    provider: 'xiaomi',
                    remember: rememberCredentials,
                    username: normalizedUsername,
                    password: password,
                    userId: account.userId ?? '',
                  );
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                  if (rootContext.mounted) {
                    ScaffoldMessenger.of(rootContext).showSnackBar(
                      SnackBar(
                        content: Text(
                          l10n.settingsMiAccountSyncedDevices(
                            account.syncedDevices,
                          ),
                        ),
                      ),
                    );
                  }
                } catch (twoFactorError) {
                  setState(() {
                    running = false;
                    error = localizedErrorMessage(l10n, twoFactorError);
                  });
                }
              } catch (e) {
                setState(() {
                  running = false;
                  error = localizedErrorMessage(l10n, e);
                });
              }
            }

            Future<void> signOut() async {
              setState(() {
                running = true;
                error = null;
              });
              try {
                await accounts.logout('xiaomi');
                await accounts.saveCredentials(
                  provider: 'xiaomi',
                  remember: false,
                  username: '',
                  password: '',
                );
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              } catch (e) {
                setState(() {
                  running = false;
                  error = localizedErrorMessage(l10n, e);
                });
              }
            }

            return AlertDialog(
              title: Text(l10n.settingsMiAccountLoginTitle),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      initialValue: username,
                      onChanged: (value) => username = value,
                      enabled: !running,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: l10n.settingsMiAccountUsername,
                        prefixIcon: const Icon(Icons.account_circle_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: password,
                      onChanged: (value) => password = value,
                      enabled: !running,
                      obscureText: obscurePassword,
                      decoration: InputDecoration(
                        labelText: l10n.settingsMiAccountPassword,
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          onPressed: running
                              ? null
                              : () {
                                  setState(() {
                                    obscurePassword = !obscurePassword;
                                  });
                                },
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      onFieldSubmitted: (_) {
                        if (!running) submit();
                      },
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      value: rememberCredentials,
                      onChanged: running
                          ? null
                          : (value) {
                              setState(() {
                                rememberCredentials = value ?? false;
                              });
                            },
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(l10n.settingsMiAccountRememberCredentials),
                      dense: true,
                    ),
                    if (running) ...[
                      const SizedBox(height: 20),
                      const LinearProgressIndicator(),
                    ],
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                if (existing.isSignedIn)
                  TextButton(
                    onPressed: running ? null : signOut,
                    child: Text(l10n.bandBbsLogout),
                  ),
                TextButton(
                  onPressed: running
                      ? null
                      : () {
                          Navigator.of(dialogContext).pop();
                        },
                  child: Text(l10n.settingsCancel),
                ),
                FilledButton(
                  onPressed: running ? null : submit,
                  child: Text(l10n.settingsMiAccountLoginAndSync),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showHuamiAccountLogin(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final rootContext = context;
    final l10n = AppLocalizations.of(context)!;
    final accounts = ref.read(hostAccountsProvider.notifier);
    final credentials = await accounts.rememberedCredentials('amazfit');
    final existing = ref.read(hostAccountsProvider).amazfit;
    var rememberCredentials = credentials['remember'] == true;
    var username = rememberCredentials
        ? credentials['username']?.toString() ?? existing.username ?? ''
        : existing.username ?? '';
    var password = rememberCredentials
        ? credentials['password']?.toString() ?? ''
        : '';
    var running = false;
    var obscurePassword = true;
    String? error;
    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> submit() async {
              final normalizedUsername = username.trim();
              if (normalizedUsername.isEmpty || password.isEmpty) {
                setState(() {
                  error = l10n.settingsHuamiAccountMissingCredentials;
                });
                return;
              }
              setState(() {
                running = true;
                error = null;
              });
              try {
                await ref
                    .read(hostAccountsProvider.notifier)
                    .loginAmazfit(
                      username: normalizedUsername,
                      password: password,
                    );
                await accounts.saveCredentials(
                  provider: 'amazfit',
                  remember: rememberCredentials,
                  username: normalizedUsername,
                  password: password,
                );
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
                if (rootContext.mounted) {
                  ScaffoldMessenger.of(rootContext).showSnackBar(
                    SnackBar(content: Text(l10n.settingsHuamiAccountSignedIn)),
                  );
                }
              } catch (e) {
                setState(() {
                  running = false;
                  error = localizedErrorMessage(l10n, e);
                });
              }
            }

            Future<void> signOut() async {
              setState(() {
                running = true;
                error = null;
              });
              await ref.read(hostAccountsProvider.notifier).logout('amazfit');
              await accounts.saveCredentials(
                provider: 'amazfit',
                remember: false,
                username: '',
                password: '',
              );
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
            }

            return AlertDialog(
              title: Text(l10n.settingsHuamiAccountLoginTitle),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      initialValue: username,
                      onChanged: (value) => username = value,
                      enabled: !running,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: l10n.settingsHuamiAccountUsername,
                        prefixIcon: const Icon(Icons.account_circle_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: password,
                      onChanged: (value) => password = value,
                      enabled: !running,
                      obscureText: obscurePassword,
                      decoration: InputDecoration(
                        labelText: l10n.settingsHuamiAccountPassword,
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          onPressed: running
                              ? null
                              : () {
                                  setState(() {
                                    obscurePassword = !obscurePassword;
                                  });
                                },
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      onFieldSubmitted: (_) {
                        if (!running) submit();
                      },
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      value: rememberCredentials,
                      onChanged: running
                          ? null
                          : (value) {
                              setState(() {
                                rememberCredentials = value ?? false;
                              });
                            },
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(l10n.settingsHuamiAccountRememberCredentials),
                      dense: true,
                    ),
                    if (running) ...[
                      const SizedBox(height: 20),
                      const LinearProgressIndicator(),
                    ],
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                if (existing.isSignedIn)
                  TextButton(
                    onPressed: running ? null : signOut,
                    child: Text(l10n.bandBbsLogout),
                  ),
                TextButton(
                  onPressed: running
                      ? null
                      : () {
                          Navigator.of(dialogContext).pop();
                        },
                  child: Text(l10n.settingsCancel),
                ),
                FilledButton(
                  onPressed: running ? null : submit,
                  child: Text(l10n.settingsHuamiAccountLoginAndSave),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showLanguageSelector(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final current = ref.read(localeSettingsProvider).locale;
    final l10n = AppLocalizations.of(context)!;
    final tileContext = context;
    final renderBox = tileContext.findRenderObject() as RenderBox?;
    final overlay =
        Navigator.of(tileContext).overlay?.context.findRenderObject()
            as RenderBox?;
    if (renderBox == null || overlay == null) return;

    final tileTopLeft = renderBox.localToGlobal(Offset.zero, ancestor: overlay);
    final tileBottomRight = renderBox.localToGlobal(
      renderBox.size.bottomRight(Offset.zero),
      ancestor: overlay,
    );
    final anchor = Rect.fromLTWH(
      tileBottomRight.dx - 48,
      tileTopLeft.dy,
      48,
      renderBox.size.height,
    );

    final selected = await showMenu<AppLocale>(
      context: tileContext,
      position: RelativeRect.fromRect(anchor, Offset.zero & overlay.size),
      initialValue: current,
      items: AppLocale.values.map((locale) {
        final selected = locale == current;
        return PopupMenuItem<AppLocale>(
          value: locale,
          child: Row(
            children: [
              Expanded(child: Text(_localeLabel(l10n, locale))),
              if (selected) const Icon(Icons.check),
            ],
          ),
        );
      }).toList(),
    );
    if (selected != null && selected != current) {
      await ref.read(localeSettingsProvider.notifier).setLocale(selected);
    }
  }

  Future<void> _showDesktopAccentSourceSelector(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final current = ref.read(themeSettingsProvider).desktopAccentColorSource;
    final l10n = AppLocalizations.of(context)!;
    final tileContext = context;
    final renderBox = tileContext.findRenderObject() as RenderBox?;
    final overlay =
        Navigator.of(tileContext).overlay?.context.findRenderObject()
            as RenderBox?;
    if (renderBox == null || overlay == null) return;

    final tileTopLeft = renderBox.localToGlobal(Offset.zero, ancestor: overlay);
    final tileBottomRight = renderBox.localToGlobal(
      renderBox.size.bottomRight(Offset.zero),
      ancestor: overlay,
    );
    final anchor = Rect.fromLTWH(
      tileBottomRight.dx - 48,
      tileTopLeft.dy,
      48,
      renderBox.size.height,
    );

    final selected = await showMenu<DesktopAccentColorSource>(
      context: tileContext,
      position: RelativeRect.fromRect(anchor, Offset.zero & overlay.size),
      initialValue: current,
      items: DesktopAccentColorSource.values.map((source) {
        final selected = source == current;
        return PopupMenuItem<DesktopAccentColorSource>(
          value: source,
          child: Row(
            children: [
              Expanded(child: Text(_desktopAccentSourceLabel(l10n, source))),
              if (selected) const Icon(Icons.check),
            ],
          ),
        );
      }).toList(),
    );
    if (selected != null && selected != current) {
      await ref
          .read(themeSettingsProvider.notifier)
          .setDesktopAccentColorSource(selected);
    }
  }

  Future<void> _showThemeModeSelector(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final current = ref.read(themeSettingsProvider).themeMode;
    final l10n = AppLocalizations.of(context)!;
    final tileContext = context;
    final renderBox = tileContext.findRenderObject() as RenderBox?;
    final overlay =
        Navigator.of(tileContext).overlay?.context.findRenderObject()
            as RenderBox?;
    if (renderBox == null || overlay == null) return;

    final tileTopLeft = renderBox.localToGlobal(Offset.zero, ancestor: overlay);
    final tileBottomRight = renderBox.localToGlobal(
      renderBox.size.bottomRight(Offset.zero),
      ancestor: overlay,
    );
    final anchor = Rect.fromLTWH(
      tileBottomRight.dx - 48,
      tileTopLeft.dy,
      48,
      renderBox.size.height,
    );

    final selected = await showMenu<AppThemeMode>(
      context: tileContext,
      position: RelativeRect.fromRect(anchor, Offset.zero & overlay.size),
      initialValue: current,
      items: AppThemeMode.values.map((mode) {
        final selected = mode == current;
        return PopupMenuItem<AppThemeMode>(
          value: mode,
          child: Row(
            children: [
              Expanded(child: Text(_themeModeLabel(l10n, mode))),
              if (selected) const Icon(Icons.check),
            ],
          ),
        );
      }).toList(),
    );
    if (selected != null && selected != current) {
      await ref.read(themeSettingsProvider.notifier).setThemeMode(selected);
    }
  }

  Future<void> _showColorSchemeSelector(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final current = ref.read(themeSettingsProvider).customSeedColor;
    final l10n = AppLocalizations.of(context)!;
    final tileContext = context;
    final renderBox = tileContext.findRenderObject() as RenderBox?;
    final overlay =
        Navigator.of(tileContext).overlay?.context.findRenderObject()
            as RenderBox?;
    if (renderBox == null || overlay == null) return;

    final tileTopLeft = renderBox.localToGlobal(Offset.zero, ancestor: overlay);
    final tileBottomRight = renderBox.localToGlobal(
      renderBox.size.bottomRight(Offset.zero),
      ancestor: overlay,
    );
    final anchor = Rect.fromLTWH(
      tileBottomRight.dx - 48,
      tileTopLeft.dy,
      48,
      renderBox.size.height,
    );

    final selected = await showMenu<Color>(
      context: tileContext,
      position: RelativeRect.fromRect(anchor, Offset.zero & overlay.size),
      initialValue: current,
      items: _colorSchemes.map((color) {
        final selected = color.toARGB32() == current.toARGB32();
        return PopupMenuItem<Color>(
          value: color,
          child: Row(
            children: [
              _ColorDot(color: color),
              const SizedBox(width: 12),
              Expanded(child: Text(_colorSchemeLabel(l10n, color))),
              if (selected) const Icon(Icons.check),
            ],
          ),
        );
      }).toList(),
    );
    if (selected != null && selected.toARGB32() != current.toARGB32()) {
      await ref
          .read(themeSettingsProvider.notifier)
          .setCustomSeedColor(selected);
    }
  }

  String _colorSchemeLabel(AppLocalizations l10n, Color color) {
    return switch (color.toARGB32()) {
      0xFFE91E63 => l10n.settingsColorSchemePink,
      0xFF6750A4 => l10n.settingsColorSchemePurple,
      0xFF006A6A => l10n.settingsColorSchemeTeal,
      0xFF006D3F => l10n.settingsColorSchemeGreen,
      0xFFB3261E => l10n.settingsColorSchemeRed,
      0xFF755B00 => l10n.settingsColorSchemeAmber,
      _ =>
        '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
    };
  }

  Future<void> _showWideNavigationPositionSelector(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final current = ref.read(appSettingsProvider).wideNavigationRailPosition;
    final l10n = AppLocalizations.of(context)!;
    final tileContext = context;
    final renderBox = tileContext.findRenderObject() as RenderBox?;
    final overlay =
        Navigator.of(tileContext).overlay?.context.findRenderObject()
            as RenderBox?;
    if (renderBox == null || overlay == null) return;

    final tileTopLeft = renderBox.localToGlobal(Offset.zero, ancestor: overlay);
    final tileBottomRight = renderBox.localToGlobal(
      renderBox.size.bottomRight(Offset.zero),
      ancestor: overlay,
    );
    final anchor = Rect.fromLTWH(
      tileBottomRight.dx - 48,
      tileTopLeft.dy,
      48,
      renderBox.size.height,
    );

    final selected = await showMenu<WideNavigationRailPosition>(
      context: tileContext,
      position: RelativeRect.fromRect(anchor, Offset.zero & overlay.size),
      initialValue: current,
      items: WideNavigationRailPosition.values.map((position) {
        final selected = position == current;
        return PopupMenuItem<WideNavigationRailPosition>(
          value: position,
          child: Row(
            children: [
              Expanded(
                child: Text(_wideNavigationPositionLabel(l10n, position)),
              ),
              if (selected) const Icon(Icons.check),
            ],
          ),
        );
      }).toList(),
    );
    if (selected != null && selected != current) {
      await ref
          .read(appSettingsProvider.notifier)
          .setWideNavigationRailPosition(selected);
    }
  }

  Future<void> _startBandBbsLogin(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await ref.read(hostAccountsProvider.notifier).startBandBbsLogin();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.settingsAccountBandBbsOpenedBrowser)),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(localizedErrorMessage(l10n, e))));
    }
  }

  Future<void> _connectGitHub(BuildContext context, WidgetRef ref) async {
    if (!ref.read(hostAccountsProvider).bandbbs.isSignedIn) return;
    final controller = ref.read(creatorWorkspaceProvider.notifier);
    final state = ref.read(creatorWorkspaceProvider);
    final githubLogin = state.grants['github_login']?.toString() ?? '';
    if (githubLogin.isNotEmpty) {
      await _confirmAccountLogout(
        context,
        accountName: 'GitHub',
        onLogout: controller.disconnectGitHub,
      );
      return;
    }
    if (state.operation == CreatorOperation.authorizing || state.loading) {
      return;
    }
    try {
      final started = await controller.startGitHubAuthorization();
      final flowId = started['flow_id']?.toString() ?? '';
      final uri = Uri.tryParse(started['authorization_url']?.toString() ?? '');
      if (flowId.isEmpty || uri == null || !await launchUrl(uri)) {
        controller.finishAuthorization();
        return;
      }
      for (var attempt = 0; attempt < 60 && context.mounted; attempt++) {
        await Future<void>.delayed(const Duration(seconds: 2));
        if (await controller.pollGitHubAuthorization(flowId)) return;
      }
      controller.finishAuthorization();
    } catch (error) {
      controller.finishAuthorization();
      if (context.mounted) showCreatorFailure(context, error);
    }
  }

  Future<void> _confirmAccountLogout(
    BuildContext context, {
    required String accountName,
    required Future<void> Function() onLogout,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.accountSignOutTitle(accountName)),
        content: Text(l10n.accountSignOutMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.bandBbsLogout),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await onLogout();
      if (context.mounted) {
        OronBoxDialog.showToast(
          message: l10n.bandBbsLoggedOut,
          context: context,
        );
      }
    } catch (error) {
      if (context.mounted) showCreatorFailure(context, error);
    }
  }

  Future<void> _showDesktopExitBehaviorMenu(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final current = ref.read(_desktopExitBehaviorProvider);
    final tileContext = context;
    final renderBox = tileContext.findRenderObject() as RenderBox?;
    final overlay =
        Navigator.of(tileContext).overlay?.context.findRenderObject()
            as RenderBox?;
    if (renderBox == null || overlay == null) return;
    final tileTopLeft = renderBox.localToGlobal(Offset.zero, ancestor: overlay);
    final tileBottomRight = renderBox.localToGlobal(
      renderBox.size.bottomRight(Offset.zero),
      ancestor: overlay,
    );
    final anchor = Rect.fromLTWH(
      tileBottomRight.dx - 48,
      tileTopLeft.dy,
      48,
      renderBox.size.height,
    );
    final selected = await showMenu<int>(
      context: tileContext,
      position: RelativeRect.fromRect(anchor, Offset.zero & overlay.size),
      initialValue: current ?? -1,
      items: [
        PopupMenuItem(value: -1, child: Text(l10n.desktopCloseBehaviorAsk)),
        PopupMenuItem(value: 0, child: Text(l10n.desktopCloseBehaviorExit)),
        PopupMenuItem(value: 1, child: Text(l10n.desktopCloseBehaviorTray)),
      ],
    );
    if (selected == null || !context.mounted) return;
    if (selected == -1) {
      await SharedPrefsService.instance.remove('desktop.exit_behavior');
    } else {
      await SharedPrefsService.instance.setInt(
        'desktop.exit_behavior',
        selected,
      );
    }
    ref.invalidate(_desktopExitBehaviorProvider);
  }
}

String _desktopExitBehaviorLabel(AppLocalizations l10n, int? behavior) =>
    switch (behavior) {
      0 => l10n.desktopCloseBehaviorExit,
      1 => l10n.desktopCloseBehaviorTray,
      _ => l10n.desktopCloseBehaviorAsk,
    };

class _AccountLeading extends StatelessWidget {
  const _AccountLeading({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(dimension: 24, child: Center(child: child));
  }
}

class MiLogo extends StatelessWidget {
  const MiLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return _SettingsSvgLogo(
      asset: 'assets/images/brands/xiaomi.svg',
      semanticsLabel: 'Xiaomi',
    );
  }
}

class _AccountBrandLogo extends StatelessWidget {
  const _AccountBrandLogo({required this.asset, required this.semanticsLabel});

  final String asset;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return _SettingsSvgLogo(asset: asset, semanticsLabel: semanticsLabel);
  }
}

class _SettingsSvgLogo extends StatelessWidget {
  const _SettingsSvgLogo({required this.asset, required this.semanticsLabel});

  final String asset;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 24,
      child: SvgPicture.asset(
        asset,
        fit: BoxFit.contain,
        colorFilter: ColorFilter.mode(
          Theme.of(context).colorScheme.onSurface,
          BlendMode.srcIn,
        ),
        semanticsLabel: semanticsLabel,
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: const SizedBox.square(dimension: 22),
    );
  }
}
