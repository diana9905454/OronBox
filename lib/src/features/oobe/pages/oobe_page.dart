import 'package:segmented_list/segmented_list.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/utils/error_localization.dart';
import 'package:oronbox/src/app/widgets/sys_app_bar.dart';
import 'package:oronbox/src/app/widgets/app_icon.dart';
import 'package:oronbox/src/commands/command_protocol.dart';
import 'package:oronbox/src/core/constants/style_constants.dart';
import 'package:oronbox/src/core/network/app_http_transport.dart';
import 'package:oronbox/src/core/providers/app_settings_providers.dart';
import 'package:oronbox/src/core/utils/app_exit.dart';
import 'package:oronbox/src/core/network/github_cdn.dart';
import 'package:oronbox/src/features/accounts/application/host_accounts.dart';
import 'package:oronbox/src/features/accounts/services/mi_account_two_factor_resolver.dart';
import 'package:oronbox/src/features/oobe/oobe_state.dart';
import 'package:oronbox/src/features/settings/pages/legal_documents_page.dart';
import 'package:oronbox/src/host/application_host_provider.dart';

/// First-run experience: welcome → terms → privacy → optional account sign-in
/// → done. Uses PageView for smooth animated transitions and Material 3
/// components throughout.
class OobePage extends ConsumerStatefulWidget {
  const OobePage({super.key});

  @override
  ConsumerState<OobePage> createState() => _OobePageState();
}

class _OobePageState extends ConsumerState<OobePage> {
  static const _welcomeStep = 0;
  static const _termsStep = 1;
  static const _privacyStep = 2;

  int _currentStep = _welcomeStep;
  bool _termsAgreed = false;
  bool _privacyAgreed = false;
  late final bool _preAccepted = isLegalAccepted();

  bool get _agreementReady =>
      _preAccepted ||
      (_currentStep == _termsStep ? _termsAgreed : _privacyAgreed);

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _next() async {
    if (_currentStep == _privacyStep && !_preAccepted) {
      await markLegalAccepted();
    }
    if (!mounted) return;
    setState(() => _currentStep += 1);
  }

  void _back() {
    if (_currentStep > _welcomeStep) {
      setState(() => _currentStep -= 1);
    }
  }

  Future<void> _decline() async {
    if (canExitApp) {
      try {
        await ref
            .read(applicationHostProvider)
            .execute(const OronBoxCommand(method: 'daemon.stop'));
      } catch (_) {}
      exitApp();
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(l10n.oobeDeclineWebHint)));
  }

  Future<void> _finish() async {
    await markOobeCompleted();
    if (mounted) {
      context.go('/resources');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    Widget body;
    String title;
    switch (_currentStep) {
      case 0:
        body = const _WelcomeStep();
        title = 'OronBox';
      case 1:
        body = _AgreementStep(
          key: const ValueKey('terms'),
          documentId: 'terms',
          agreed: _termsAgreed,
          onAgreed: (v) => setState(() => _termsAgreed = v),
        );
        title = l10n.termsTitle;
      case 2:
        body = _AgreementStep(
          key: const ValueKey('privacy'),
          documentId: 'privacy',
          agreed: _privacyAgreed,
          onAgreed: (v) => setState(() => _privacyAgreed = v),
        );
        title = l10n.privacyTitle;
      case 3:
        body = const _LoginStep();
        title = l10n.oobeLoginTitle;
      default:
        body = const _DoneStep();
        title = l10n.oobeDoneTitle;
    }

    return Scaffold(
      appBar: SysAppBar(secondary: true, fullWindow: true, title: Text(title)),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(child: body),
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
            onPressed: onDecline,
            style: TextButton.styleFrom(foregroundColor: cs.error),
            child: Text(l10n.oobeDeclineExit),
          )
        : currentStep > 0
        ? TextButton(onPressed: onBack, child: Text(l10n.oobeBack))
        : null;

    final right = currentStep == 4
        ? FilledButton(onPressed: onFinish, child: Text(l10n.oobeFinish))
        : FilledButton(
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
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Row(
        children: [
          SizedBox(width: 88, child: left ?? const SizedBox.shrink()),
          Expanded(child: Center(child: dotsRow)),
          right,
        ],
      ),
    );
  }
}

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final features = [
      (
        Icons.watch_outlined,
        l10n.oobeFeatureDevicesTitle,
        l10n.oobeFeatureDevicesBody,
      ),
      (
        Icons.storefront_outlined,
        l10n.oobeFeatureResourcesTitle,
        l10n.oobeFeatureResourcesBody,
      ),
      (
        Icons.extension_outlined,
        l10n.oobeFeaturePluginsTitle,
        l10n.oobeFeaturePluginsBody,
      ),
      (
        Icons.devices_outlined,
        l10n.oobeFeaturePlatformsTitle,
        l10n.oobeFeaturePlatformsBody,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AppIcon(size: 96),
                      const SizedBox(height: 16),
                      Text(
                        'OronBox',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.oobeWelcomeSlogan,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: cs.onSurfaceVariant,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Open source
                      _FeatureCard(
                        icon: Icons.code,
                        title: l10n.oobeOpenSourceTitle,
                        body: l10n.oobeOpenSourceBody,
                      ),
                      const SizedBox(height: 16),

                      // Feature cards
                      for (final f in features) ...[
                        _FeatureCard(icon: f.$1, title: f.$2, body: f.$3),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: cs.surfaceContainerLow,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(icon, size: 28, color: cs.onPrimaryContainer),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: cs.onSurfaceVariant, height: 1.35),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
  bool _bottomReached = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_markBottomReached);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final language = legalDocumentLanguage(Localizations.localeOf(context));
    final data = await rootBundle.loadString(
      'assets/legal/${widget.documentId}.$language.md',
      // Widget tests hang on the second cached load of the same asset key.
      cache: false,
    );
    if (!mounted) return;
    setState(() => _data = data);
    // A document that fits the viewport without scrolling counts as read.
    WidgetsBinding.instance.addPostFrameCallback((_) => _markBottomReached());
  }

  void _markBottomReached() {
    if (_bottomReached || !_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.maxScrollExtent - position.pixels <= 1) {
      setState(() => _bottomReached = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final data = _data;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 840),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: data == null
                        ? const SizedBox.shrink()
                        : Markdown(
                            data: data,
                            controller: _scrollController,
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                            styleSheet: MarkdownStyleSheet.fromTheme(theme)
                                .copyWith(
                                  p: theme.textTheme.bodyMedium?.copyWith(
                                    height: 1.5,
                                  ),
                                  pPadding: const EdgeInsets.only(bottom: 12),
                                  h1: theme.textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                  h1Padding: const EdgeInsets.only(
                                    top: 16,
                                    bottom: 8,
                                  ),
                                  h2: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                  h2Padding: const EdgeInsets.only(
                                    top: 12,
                                    bottom: 6,
                                  ),
                                ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _bottomReached
                    ? () => widget.onAgreed(!widget.agreed)
                    : null,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 16, 4),
                  child: Row(
                    children: [
                      Checkbox(
                        value: widget.agreed,
                        onChanged: _bottomReached
                            ? (v) => widget.onAgreed(v ?? false)
                            : null,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        l10n.oobeAgreeCheckbox,
                        style: _bottomReached
                            ? null
                            : TextStyle(color: theme.disabledColor),
                      ),
                      if (!_bottomReached) ...[
                        const Spacer(),
                        Text(
                          l10n.oobeAgreementHint,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
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

class _LoginStep extends ConsumerStatefulWidget {
  const _LoginStep();

  @override
  ConsumerState<_LoginStep> createState() => _LoginStepState();
}

class _LoginStepState extends ConsumerState<_LoginStep> {
  final _dio = _createOobeDio();
  final _cdnResults = <GitHubCdn, int?>{};
  bool _cdnTesting = true;

  @override
  void initState() {
    super.initState();
    _runCdnTests();
  }

  Future<void> _runCdnTests() async {
    final results = await testGithubCdns(dio: _dio);
    if (!mounted) return;

    final fastest = fastestGithubCdn(results);
    if (fastest != null &&
        ref.read(appSettingsProvider).cdn == GitHubCdn.auto) {
      await ref.read(appSettingsProvider.notifier).setEffectiveCdn(fastest);
    }
    if (!mounted) return;

    setState(() {
      for (final (cdn, ms) in results) {
        _cdnResults[cdn] = ms;
      }
      _cdnTesting = false;
    });
  }

  @override
  void dispose() {
    _dio.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    final cdnTiles = <SegmentedTile>[];
    final fastest = _cdnResults.entries.where((e) => e.value != null).toList()
      ..sort((a, b) => a.value!.compareTo(b.value!));
    final fastestCdn = fastest.isNotEmpty ? fastest.first.key : null;

    for (final cdn in GitHubCdn.values.where((cdn) => cdn != GitHubCdn.auto)) {
      final ms = _cdnResults[cdn];
      final isFastest = cdn == fastestCdn;
      cdnTiles.add(
        SegmentedTile(
          title: Text(
            cdn.displayName,
            style: isFastest
                ? theme.textTheme.bodyMedium?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w600,
                  )
                : null,
          ),
          enabled: !_cdnTesting,
          trailing: _cdnTesting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  ms == null ? l10n.oobeCdnTestFailed : '${ms}ms',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isFastest ? cs.primary : cs.onSurfaceVariant,
                  ),
                ),
        ),
      );
    }

    final cdnHeaderTile = _cdnTesting
        ? SegmentedTile(
            title: Text(l10n.oobeCdnTesting),
            trailing: const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        : SegmentedTile(
            title: Text(l10n.oobeCdnSelected),
            trailing: Icon(Icons.check, color: cs.primary),
          );

    final list = SegmentedList(
      maxWidth: StyleConstants.pageMaxWidth,
      contentPadding: const EdgeInsets.symmetric(
        vertical: StyleConstants.pagePadding,
      ),
      sections: [
        SegmentedSection(
          title: Text(l10n.oobeLoginTitle),
          tiles: [
            _bandBbsTile(context, ref, l10n),
            _xiaomiTile(context, ref, l10n),
            _huamiTile(context, ref, l10n),
          ],
        ),
        SegmentedSection(
          title: Text(l10n.oobeCdnTitle),
          tiles: [cdnHeaderTile, ...cdnTiles],
        ),
      ],
    );

    final note = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: StyleConstants.pagePadding,
      ),
      child: Text(
        l10n.oobeLoginLocalNote,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );

    return Column(
      children: [
        Expanded(child: list),
        const SizedBox(height: 8),
        note,
      ],
    );
  }
}

Dio _createOobeDio() {
  return createAppHttpTransport(
    options: BaseOptions(
      connectTimeout: githubCdnProbeTimeout,
      sendTimeout: githubCdnProbeTimeout,
      receiveTimeout: githubCdnProbeTimeout,
    ),
  );
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
    leading: _BrandLogo(
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

class _DoneStep extends StatelessWidget {
  const _DoneStep();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check, size: 72, color: cs.primary),
            const SizedBox(height: 16),
            Text(
              l10n.oobeDoneTitle,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.oobeDoneBody,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
