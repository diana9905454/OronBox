import 'dart:async';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:segmented_list/segmented_list.dart';

import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/utils/error_localization.dart';
import 'package:oronbox/src/app/utils/picked_file.dart';
import 'package:oronbox/src/app/widgets/app_icon.dart';
import 'package:oronbox/src/app/widgets/app_scaffold_messenger.dart';
import 'package:oronbox/src/app/widgets/markdown_style_sheet.dart';
import 'package:oronbox/src/app/widgets/sys_app_bar.dart';
import 'package:oronbox/src/core/logging/logging_service.dart';
import 'package:oronbox/src/core/network/app_http_transport.dart';
import 'package:oronbox/src/core/network/github_cdn.dart';
import 'package:oronbox/src/core/providers/app_settings_providers.dart';
import 'package:oronbox/src/core/utils/app_exit.dart';
import 'package:oronbox/src/features/accounts/application/host_accounts.dart';
import 'package:oronbox/src/features/accounts/services/mi_account_two_factor_resolver.dart';
import 'package:oronbox/src/features/oobe/oobe_state.dart';
import 'package:oronbox/src/features/settings/application/app_data_backup.dart';
import 'package:oronbox/src/features/settings/application/app_data_maintenance.dart';
import 'package:oronbox/src/features/settings/application/app_extension_backup.dart';
import 'package:oronbox/src/features/settings/pages/app_data_backup_dialog.dart';
import 'package:oronbox/src/features/settings/pages/legal_documents_page.dart';
import 'package:oronbox/src/features/settings/services/legal_agreements.dart';
import 'package:oronbox/src/host/application_host_provider.dart';

Widget _oobeProgressIndicator({double size = 20, double strokeWidth = 2.0}) {
  final isTesting = WidgetsBinding.instance.runtimeType.toString().contains(
    'Test',
  );
  return SizedBox.square(
    dimension: size,
    child: CircularProgressIndicator(
      strokeWidth: strokeWidth,
      value: isTesting ? 0.7 : null,
    ),
  );
}

/// OronBox 初次使用引导流程
class OobePage extends ConsumerStatefulWidget {
  const OobePage({super.key});

  @override
  ConsumerState<OobePage> createState() => _OobePageState();
}

class _OobePageState extends ConsumerState<OobePage> {
  static const _totalSteps = 5;

  final _pageController = PageController();
  int _currentStep = 0;
  bool _termsAgreed = false;
  bool _privacyAgreed = false;
  bool _preAccepted = false;

  @override
  void initState() {
    super.initState();
    _preAccepted = isLegalAccepted();
    if (_preAccepted) {
      _termsAgreed = true;
      _privacyAgreed = true;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  bool get _agreementReady {
    if (_preAccepted) return true;
    if (_currentStep == 1) return _termsAgreed;
    if (_currentStep == 2) return _privacyAgreed;
    return true;
  }

  Future<void> _goToPage(int page) async {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _currentStep = page);
    if (!mounted) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _pageController.jumpToPage(page);
    } else {
      await _pageController.animateToPage(
        page,
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeInOutCubicEmphasized,
      );
    }
  }

  Future<void> _next() async {
    if (!_agreementReady) return;
    if (_currentStep == 2 && !_preAccepted) {
      await markLegalAccepted();
    }
    if (!mounted) return;
    if (_currentStep < _totalSteps - 1) {
      await _goToPage(_currentStep + 1);
    }
  }

  Future<void> _back() async {
    if (_currentStep > 0) {
      await _goToPage(_currentStep - 1);
    }
  }

  Future<void> _decline() async {
    if (canExitApp) {
      exitApp();
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(l10n.oobeDeclineWebHint)));
  }

  Future<void> _finish() async {
    await markOobeCompleted();
    if (!mounted) return;
    context.go('/resources');
  }

  @override
  Widget build(BuildContext context) {
    final steps = [
      const _WelcomeStep(),
      _AgreementStep(
        key: const ValueKey('terms'),
        documentId: 'terms',
        agreed: _termsAgreed,
        onAgreed: (v) => setState(() => _termsAgreed = v),
      ),
      _AgreementStep(
        key: const ValueKey('privacy'),
        documentId: 'privacy',
        agreed: _privacyAgreed,
        onAgreed: (v) => setState(() => _privacyAgreed = v),
      ),
      const _LoginStep(),
      const _DoneStep(),
    ];

    return Scaffold(
      appBar: const SysAppBar(secondary: true, fullWindow: true),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: steps,
              ),
            ),
            _OobeBottomBar(
              currentStep: _currentStep,
              agreementReady: _agreementReady,
              onNext: _next,
              onBack: _back,
              onDecline: _decline,
              onFinish: _finish,
            ),
          ],
        ),
      ),
    );
  }
}

/// 底部栏：统一遵循项目标准三段式（左退出/返回，中指示点，右继续/完成）
class _OobeBottomBar extends StatelessWidget {
  const _OobeBottomBar({
    required this.currentStep,
    required this.agreementReady,
    required this.onNext,
    required this.onBack,
    required this.onDecline,
    required this.onFinish,
  });

  final int currentStep;
  final bool agreementReady;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final VoidCallback onDecline;
  final VoidCallback onFinish;

  bool get _onAgreement => currentStep == 1 || currentStep == 2;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;

    final left = currentStep == 0
        ? TextButton(
            style: TextButton.styleFrom(
              backgroundColor: cs.surfaceContainerLow,
              foregroundColor: cs.error,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              textStyle: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            onPressed: onDecline,
            child: Text(l10n.oobeDeclineExit),
          )
        : TextButton(
            style: TextButton.styleFrom(
              backgroundColor: cs.surfaceContainerLow,
              foregroundColor: cs.onSurfaceVariant,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              textStyle: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            onPressed: onBack,
            child: Text(l10n.oobeBack),
          );

    final right = currentStep == 4
        ? FilledButton(
            style: FilledButton.styleFrom(
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              textStyle: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            onPressed: onFinish,
            child: Text(l10n.oobeFinish),
          )
        : FilledButton(
            style: FilledButton.styleFrom(
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              textStyle: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            onPressed: _onAgreement && !agreementReady ? null : onNext,
            child: Text(l10n.oobeNext),
          );

    final dotsRow = Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final isCurrent = i == currentStep;
        final isPast = i <= currentStep;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isCurrent ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: isPast ? cs.primary : cs.surfaceContainerHighest,
          ),
        );
      }),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Stack(
        alignment: Alignment.center,
        children: [
          dotsRow,
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [left, right],
          ),
        ],
      ),
    );
  }
}

/// 步骤裸图标（无背景容器）
class _StepIcon extends StatelessWidget {
  const _StepIcon({
    required this.icon,
    this.backgroundColor,
    this.foregroundColor,
    this.size = 60,
  });

  final IconData icon;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Icon(icon, size: size, color: foregroundColor ?? cs.primary);
  }
}

/// Step 0: 欢迎页，展示核心能力（上下分明单列，顶栏固定标头 + 底栏弹性列表）
class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final items = [
      (
        icon: Icons.watch_outlined,
        bg: cs.secondaryContainer,
        fg: cs.onSecondaryContainer,
        title: l10n.oobeFeatureDevicesTitle,
        desc: l10n.oobeFeatureDevicesBody,
      ),
      (
        icon: Icons.storefront_outlined,
        bg: cs.tertiaryContainer,
        fg: cs.onTertiaryContainer,
        title: l10n.oobeFeatureResourcesTitle,
        desc: l10n.oobeFeatureResourcesBody,
      ),
      (
        icon: Icons.extension_outlined,
        bg: cs.primaryContainer,
        fg: cs.onPrimaryContainer,
        title: l10n.oobeFeaturePluginsTitle,
        desc: l10n.oobeFeaturePluginsBody,
      ),
      (
        icon: Icons.devices_outlined,
        bg: cs.secondaryContainer,
        fg: cs.onSecondaryContainer,
        title: l10n.oobeFeaturePlatformsTitle,
        desc: l10n.oobeFeaturePlatformsBody,
      ),
      (
        icon: Icons.code_rounded,
        bg: cs.tertiaryContainer,
        fg: cs.onTertiaryContainer,
        title: l10n.oobeOpenSourceTitle,
        desc: l10n.oobeOpenSourceBody,
      ),
    ];

    final contentWidget = DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const SizedBox(height: 16),
                  _WelcomeItem(
                    icon: items[i].icon,
                    iconBg: items[i].bg,
                    iconFg: items[i].fg,
                    title: items[i].title,
                    description: items[i].desc,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 840),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: const AppIcon(size: 72),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'OronBox',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.oobeWelcomeSlogan,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(child: Center(child: contentWidget)),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _RestoreBackupButton extends ConsumerStatefulWidget {
  const _RestoreBackupButton();

  @override
  ConsumerState<_RestoreBackupButton> createState() =>
      _RestoreBackupButtonState();
}

class _RestoreBackupButtonState extends ConsumerState<_RestoreBackupButton> {
  bool _busy = false;

  Future<void> _restore() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _busy = true);
    final extStore = AppExtensionBackupStore();
    final backupService = AppDataBackupService(
      extensions: extStore,
      maintenance: <T>(action) => runWithAppDataMaintenance<T>(
        ref.read(applicationHostProvider),
        action,
      ),
    );
    try {
      final picked = await pickFileData(
        type: FileType.custom,
        allowedExtensions: const ['zip'],
        dialogTitle: l10n.appDataRestore,
        maxBytes: 512 * 1024 * 1024,
        loadBytes: true,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (bytes == null) return;
      final backup = await backupService.inspect(bytes);
      if (!mounted) return;
      final selection = await showBackupSelectionDialog(
        context,
        backup: backup,
      );
      if (selection == null || !mounted) return;
      await backupService.restore(
        AppDataBackup(
          settings: selectBackupSettings(
            backup.settings,
            includeSettings: selection.settings,
            includeAccounts: selection.accountCredentials,
          ),
          activityFiles: selection.health ? backup.activityFiles : const {},
          extensions: selection.extensions ? backup.extensions : const {},
          extensionFiles: selection.extensions
              ? backup.extensionFiles
              : const {},
          privateData: {
            if (selection.devices && backup.privateData.containsKey('devices'))
              'devices': backup.privateData['devices'],
            if (selection.accountCredentials) ...{
              if (backup.privateData.containsKey('xiaomi'))
                'xiaomi': backup.privateData['xiaomi'],
              if (backup.privateData.containsKey('huami'))
                'huami': backup.privateData['huami'],
            },
          },
        ),
      );
      if (!mounted) return;
      ref.invalidate(hostAccountsProvider);
      appScaffoldMessengerOf(context)
          .showSnackBar(SnackBar(content: Text(l10n.oobeRestoreSuccess)));
    } catch (error, stack) {
      getLogger('OobeRestore').warning('Restore failed', error, stack);
      if (mounted) {
        appScaffoldMessengerOf(context).showSnackBar(
          SnackBar(
            content: Text(
              error is PickedFileTooLarge
                  ? l10n.appDataArchiveTooLarge
                  : error is ExtensionBackupTargetMissing
                  ? l10n.appDataExtensionMissing
                  : l10n.appDataRestoreFailed,
            ),
          ),
        );
      }
    } finally {
      await extStore.close();
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return FilledButton.tonalIcon(
      style: FilledButton.styleFrom(
        visualDensity: VisualDensity.compact,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        textStyle: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      onPressed: _busy ? null : _restore,
      icon: _busy
          ? SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: cs.onSecondaryContainer,
              ),
            )
          : const Icon(Icons.settings_backup_restore_outlined, size: 20),
      label: Text(l10n.oobeRestoreAction),
    );
  }
}

class _WelcomeItem extends StatelessWidget {
  const _WelcomeItem({
    required this.icon,
    required this.iconBg,
    required this.iconFg,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconFg;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Center(child: Icon(icon, size: 22, color: iconFg)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Step 1 & 2: 条款与隐私协议（自适应高度，零分割线）
class _AgreementStep extends StatefulWidget {
  const _AgreementStep({
    super.key,
    required this.documentId,
    required this.agreed,
    required this.onAgreed,
  });

  final String documentId;
  final bool agreed;
  final ValueChanged<bool> onAgreed;

  @override
  State<_AgreementStep> createState() => _AgreementStepState();
}

class _AgreementStepState extends State<_AgreementStep> {
  final _scrollController = ScrollController();
  String? _data;
  String? _loadError;
  bool _bottomReached = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_markBottomReached);
    if (widget.agreed) {
      _bottomReached = true;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_markBottomReached);
    _scrollController.dispose();
    super.dispose();
  }

  void _markBottomReached() {
    if (_bottomReached || !_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.maxScrollExtent - position.pixels <= 1) {
      setState(() => _bottomReached = true);
    }
  }

  Future<void> _load() async {
    final language = legalDocumentLanguage(Localizations.localeOf(context));
    setState(() => _loadError = null);
    try {
      final data = await LegalAgreements.read(widget.documentId, language);
      if (!mounted) return;
      setState(() {
        _data = data;
        if (widget.agreed) {
          _bottomReached = true;
        }
      });
    } catch (error) {
      if (mounted) {
        setState(
          () => _loadError = localizedErrorMessage(
            AppLocalizations.of(context)!,
            error,
          ),
        );
      }
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _markBottomReached());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final data = _data;
    final isTerms = widget.documentId == 'terms';

    final contentWidget = DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: data == null
            ? Center(
                child: _loadError == null
                    ? _oobeProgressIndicator()
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_loadError!),
                          const SizedBox(height: 8),
                          FilledButton.tonal(
                            onPressed: _load,
                            child: Text(l10n.retry),
                          ),
                        ],
                      ),
              )
            : Markdown(
                data: data,
                controller: _scrollController,
                padding: const EdgeInsets.all(20),
                styleSheet: markdownStyleSheetFromTheme(theme).copyWith(
                  p: theme.textTheme.bodyMedium?.copyWith(height: 1.55),
                  pPadding: const EdgeInsets.only(bottom: 12),
                  h1: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  h1Padding: const EdgeInsets.only(top: 16, bottom: 8),
                  h2: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  h2Padding: const EdgeInsets.only(top: 12, bottom: 6),
                ),
              ),
      ),
    );

    final checkboxWidget = Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
      child: Row(
        children: [
          Checkbox(
            value: widget.agreed,
            onChanged: _bottomReached
                ? (v) => widget.onAgreed(v ?? false)
                : null,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              l10n.oobeAgreeCheckbox,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (!_bottomReached)
            Text(
              l10n.oobeAgreementHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 840),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _StepIcon(
                    icon: isTerms
                        ? Icons.description_outlined
                        : Icons.shield_outlined,
                    backgroundColor: cs.secondaryContainer,
                    foregroundColor: cs.onSecondaryContainer,
                    size: 60,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isTerms ? l10n.termsTitle : l10n.privacyTitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(child: contentWidget),
              const SizedBox(height: 8),
              checkboxWidget,
            ],
          ),
        ),
      ),
    );
  }
}

/// Step 3: 账号设置（上下单列结构，层级对齐条款页）
class _LoginStep extends ConsumerStatefulWidget {
  const _LoginStep();

  @override
  ConsumerState<_LoginStep> createState() => _LoginStepState();
}

class _LoginStepState extends ConsumerState<_LoginStep> {
  final _dio = createAppHttpTransport(
    options: BaseOptions(
      connectTimeout: githubCdnProbeTimeout,
      sendTimeout: githubCdnProbeTimeout,
      receiveTimeout: githubCdnProbeTimeout,
    ),
  );

  @override
  void initState() {
    super.initState();
    _runSilentCdnTest();
  }

  @override
  void dispose() {
    _dio.close();
    super.dispose();
  }

  Future<void> _runSilentCdnTest() async {
    final results = await testGithubCdns(dio: _dio);
    if (!mounted) return;
    final fastest = fastestGithubCdn(results);
    if (fastest != null &&
        ref.read(appSettingsProvider).cdn == GitHubCdn.auto) {
      await ref.read(appSettingsProvider.notifier).setEffectiveCdn(fastest);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final content = SegmentedList(
      contentPadding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      sections: [
        SegmentedSection(
          tiles: [
            _bandBbsTile(context, ref, l10n),
            _xiaomiTile(context, ref, l10n),
            _huamiTile(context, ref, l10n),
          ],
        ),
      ],
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 840),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _StepIcon(
                    icon: Icons.manage_accounts_outlined,
                    backgroundColor: cs.tertiaryContainer,
                    foregroundColor: cs.onTertiaryContainer,
                    size: 60,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.oobeLoginTitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          content,
                          const SizedBox(height: 16),
                          Text(
                            l10n.oobeLoginLocalNote,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const _RestoreBackupButton(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 具体的三个 Item 完整采用 HEAD 版实现
SegmentedTile _bandBbsTile(
  BuildContext context,
  WidgetRef ref,
  AppLocalizations l10n,
) {
  final account = ref.watch(hostAccountsProvider.select((s) => s.bandbbs));
  return SegmentedTile.navigation(
    onPressed: account.isSignedIn || account.isBusy
        ? null
        : (_) => _startBandBbsLogin(context, ref),
    leading: const _BrandLogo(
      asset: 'assets/images/brands/bandbbs.svg',
      semanticsLabel: 'BandBBS',
    ),
    title: Text(l10n.settingsAccountBandBbsAccount),
    description: Text(
      account.isSignedIn
          ? (account.username?.isNotEmpty == true &&
                    account.userId?.isNotEmpty == true
                ? '${account.username} · ${account.userId}'
                : account.username ?? account.userId ?? l10n.settingsConnected)
          : l10n.oobeLoginBandBbsDesc,
    ),
    value: account.isBusy
        ? const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Text(
            account.isSignedIn
                ? l10n.settingsConnected
                : l10n.settingsTapToSignIn,
          ),
  );
}

SegmentedTile _xiaomiTile(
  BuildContext context,
  WidgetRef ref,
  AppLocalizations l10n,
) {
  final account = ref.watch(hostAccountsProvider.select((s) => s.xiaomi));
  return SegmentedTile.navigation(
    onPressed: account.isSignedIn || account.isBusy
        ? null
        : (_) => _showMiAccountLogin(context, ref),
    leading: const _MiLogo(),
    title: Text(l10n.settingsMiAccount),
    description: Text(
      account.isSignedIn
          ? (account.userId?.isNotEmpty == true
                ? account.userId!
                : l10n.settingsConnected)
          : l10n.oobeLoginXiaomiDesc,
    ),
    value: account.isBusy
        ? const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Text(
            account.isSignedIn
                ? l10n.settingsConnected
                : l10n.settingsTapToSignIn,
          ),
  );
}

SegmentedTile _huamiTile(
  BuildContext context,
  WidgetRef ref,
  AppLocalizations l10n,
) {
  final account = ref.watch(hostAccountsProvider.select((s) => s.amazfit));
  return SegmentedTile.navigation(
    onPressed: account.isSignedIn || account.isBusy
        ? null
        : (_) => _showHuamiAccountLogin(context, ref),
    leading: const SizedBox.square(
      dimension: 40,
      child: Center(child: Icon(Icons.functions)),
    ),
    title: Text(l10n.settingsHuamiAccount),
    description: Text(
      account.isSignedIn
          ? (account.username?.isNotEmpty == true
                ? account.username!
                : l10n.settingsConnected)
          : l10n.oobeLoginHuamiDesc,
    ),
    value: account.isBusy
        ? const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Text(
            account.isSignedIn
                ? l10n.settingsConnected
                : l10n.settingsTapToSignIn,
          ),
  );
}

class _MiLogo extends StatelessWidget {
  const _MiLogo();

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 40,
      child: Center(
        child: SvgPicture.asset(
          'assets/images/brands/xiaomi.svg',
          width: 24,
          height: 24,
          colorFilter: ColorFilter.mode(
            Theme.of(context).colorScheme.onSurface,
            BlendMode.srcIn,
          ),
          semanticsLabel: 'Xiaomi',
        ),
      ),
    );
  }
}

class _BrandLogo extends StatelessWidget {
  const _BrandLogo({required this.asset, required this.semanticsLabel});

  final String asset;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 40,
      child: Center(
        child: SvgPicture.asset(
          asset,
          width: 28,
          height: 28,
          colorFilter: ColorFilter.mode(
            Theme.of(context).colorScheme.onSurface,
            BlendMode.srcIn,
          ),
          semanticsLabel: semanticsLabel,
        ),
      ),
    );
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
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(localizedErrorMessage(l10n, e))));
  }
}

Future<void> _showMiAccountLogin(BuildContext context, WidgetRef ref) async {
  final rootContext = context;
  final l10n = AppLocalizations.of(context)!;
  final accounts = ref.read(hostAccountsProvider.notifier);
  final credentials = await accounts.rememberedCredentials('xiaomi');
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
                    title: Text(
                      l10n.settingsMiAccountRememberCredentials,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
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

Future<void> _showHuamiAccountLogin(BuildContext context, WidgetRef ref) async {
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
                    title: Text(
                      l10n.settingsHuamiAccountRememberCredentials,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
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

/// Step 4: 一切就绪完成页（居中图标 + 标题 + 描述）
class _DoneStep extends StatelessWidget {
  const _DoneStep();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _StepIcon(
              icon: Icons.check_rounded,
              backgroundColor: cs.primaryContainer,
              foregroundColor: cs.onPrimaryContainer,
              size: 80,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.oobeDoneTitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.oobeDoneBody,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
