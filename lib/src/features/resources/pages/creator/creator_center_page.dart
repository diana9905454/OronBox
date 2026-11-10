import 'dart:async';

import 'package:oronbox/src/features/settings/services/legal_agreements.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:segmented_list/segmented_list.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/widgets/page_container.dart';
import 'package:oronbox/src/app/widgets/sys_app_bar.dart';
import 'package:oronbox/src/app/widgets/stable_fab.dart';
import 'package:oronbox/src/app/widgets/markdown_style_sheet.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:oronbox/src/core/services/shared_prefs_service.dart';
import 'package:oronbox/src/features/accounts/application/host_accounts.dart';
import 'package:oronbox/src/features/resources/application/creator/creator_workspace_controller.dart';
import 'package:oronbox/src/features/resources/pages/creator/creator_resource_list.dart';
import 'package:oronbox/src/features/resources/pages/creator/creator_review_list_page.dart';
import 'package:oronbox/src/features/resources/pages/creator/creator_shared.dart';
import 'package:oronbox/src/features/settings/pages/legal_documents_page.dart';

class CreatorCenterPage extends ConsumerStatefulWidget {
  const CreatorCenterPage({
    super.key,
    this.initialTab = 1,
    this.initialReviewFilter,
  });
  final int initialTab;
  final String? initialReviewFilter;

  @override
  ConsumerState<CreatorCenterPage> createState() => _CreatorCenterPageState();
}

class _CreatorCenterPageState extends ConsumerState<CreatorCenterPage> {
  int get _tab => widget.initialTab;
  Set<String> _selectedResourceIds = const {};
  var _authorizingBandBbs = false;
  var _authorizingGitHub = false;

  Future<void> _refresh(CreatorWorkspaceController controller) async {
    await Future.wait([
      controller.refresh(),
      ref.read(hostAccountsProvider.notifier).refresh(),
    ]);
  }

  void _handleBack() {
    if (_tab == 1) {
      context.pop();
    } else {
      context.replace('/resources/creator/resources');
    }
  }

  void _switchTab(int index, {String? reviewFilter}) {
    final targetTab = index == 0 ? 1 : 2;
    if (targetTab == _tab && reviewFilter == null) return;
    final location = switch (index) {
      0 => '/resources/creator/resources',
      1 =>
        '/resources/creator/reviews'
            '${reviewFilter == null ? '' : '?filter=${Uri.encodeComponent(reviewFilter)}'}',
      _ => '/resources/creator/resources',
    };
    context.replace(location);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(creatorWorkspaceProvider);
    final controller = ref.read(creatorWorkspaceProvider.notifier);
    final bandBbs = ref.watch(hostAccountsProvider).bandbbs;
    final l10n = AppLocalizations.of(context)!;
    ref.listen(
      hostAccountsProvider.select((value) => value.bandbbs.isSignedIn),
      (previous, current) {
        if (previous != current && current) {
          unawaited(_refresh(controller));
        }
      },
    );
    return PopScope(
      canPop: _tab == 1,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        appBar: SysAppBar(
          secondary: true,
          leading: BackButton(onPressed: _handleBack),
          title: Text(l10n.creatorCenter),
          actions: [
            IconButton(
              tooltip: l10n.refresh,
              icon: const Icon(Icons.refresh),
              onPressed: state.loading
                  ? null
                  : () => unawaited(_refresh(controller)),
            ),
            IconButton(
              tooltip: l10n.notifications,
              icon: const Icon(Icons.notifications_none_outlined),
              onPressed: () => context.push('/inbox'),
            ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab == 2 ? 1 : 0,
          onDestinationSelected: _switchTab,
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.apps_outlined),
              selectedIcon: const Icon(Icons.apps),
              label: l10n.resources,
            ),
            NavigationDestination(
              icon: const Icon(Icons.edit_outlined),
              selectedIcon: const Icon(Icons.edit),
              label: l10n.creatorReviewTab,
            ),
          ],
        ),
        body: state.governance != null
            ? _CreatorGovernanceGate(code: state.governance!)
            : _tab == 2
            ? CreatorReviewListPage(
                embedded: true,
                initialFilter: widget.initialReviewFilter,
              )
            : _CreatorTermsGate(
                loading: state.loading,
                onCreate: () => _openCreateWizard(context, controller),
                selectionActive: _selectedResourceIds.isNotEmpty,
                onMoveSelection: () => _moveSelection(state, controller),
                floatingAccess: null,
                child: CreatorResourceList(
                  state: state,
                  controller: controller,
                  collections: state.collections,
                  collectionsLoading: false,
                  onRefresh: () => _refresh(controller),
                  topContent: SegmentedSection(
                    margin: const EdgeInsetsDirectional.only(bottom: 12),
                    tiles: _accountTiles(
                      l10n: l10n,
                      state: state,
                      bandBbs: bandBbs,
                      onAuthorizeBandBbs: () => _authorizeBandBbs(controller),
                      onConnectGitHub: () => _authorizeGitHub(controller),
                      bandBbsBusy: _authorizingBandBbs,
                      githubBusy: _authorizingGitHub,
                    ),
                  ),
                  onOpenCollection: (item) => context.push(
                    '/resources/creator/collection/${item['id']}',
                    extra: item,
                  ),
                  onOpen: (workspace) {
                    controller.select(workspace);
                    context.push(
                      '/resources/creator/resources/${workspace.resource.id}',
                    );
                  },
                  selectedResourceIds: _selectedResourceIds,
                  onSelectionChanged: (value) =>
                      setState(() => _selectedResourceIds = value),
                  onDissolveCollection: (item) =>
                      _dissolveCollection(item, controller),
                  bottomPadding: bottomContentPadding(context, extra: 96),
                ),
              ),
      ),
    );
  }

  Future<void> _authorizeBandBbs(CreatorWorkspaceController controller) async {
    if (_authorizingBandBbs) return;
    setState(() => _authorizingBandBbs = true);
    try {
      final account = ref.read(hostAccountsProvider).bandbbs;
      if (!account.isSignedIn) {
        await ref.read(hostAccountsProvider.notifier).startBandBbsLogin();
      } else {
        await ref
            .read(hostAccountsProvider.notifier)
            .startBandBbsPublishingAuthorization();
      }
      await controller.refresh();
    } catch (error) {
      if (mounted) showCreatorFailure(context, error);
    } finally {
      if (mounted) setState(() => _authorizingBandBbs = false);
    }
  }

  Future<void> _authorizeGitHub(CreatorWorkspaceController controller) async {
    if (_authorizingGitHub) return;
    setState(() => _authorizingGitHub = true);
    try {
      final started = await controller.startGitHubAuthorization();
      final flowId = started['flow_id']?.toString() ?? '';
      final uri = Uri.tryParse(started['authorization_url']?.toString() ?? '');
      if (flowId.isEmpty || uri == null || !await launchUrl(uri)) {
        throw StateError('githubAuthorizationFailed');
      }
      for (var attempt = 0; attempt < 60 && mounted; attempt++) {
        await Future<void>.delayed(const Duration(seconds: 2));
        if (await controller.pollGitHubAuthorization(flowId)) return;
      }
      throw StateError('githubAuthorizationTimedOut');
    } catch (error) {
      controller.finishAuthorization();
      if (mounted) showCreatorFailure(context, error);
    } finally {
      if (mounted) setState(() => _authorizingGitHub = false);
    }
  }

  List<AbstractSegmentedTile> _accountTiles({
    required AppLocalizations l10n,
    required CreatorWorkspaceState state,
    required HostAccount bandBbs,
    required VoidCallback onAuthorizeBandBbs,
    required VoidCallback onConnectGitHub,
    required bool bandBbsBusy,
    required bool githubBusy,
  }) {
    final bandBbsReady = state.grants['bandbbs_publish'] == true;
    final github = state.grants['github_login']?.toString() ?? '';
    return [
      SegmentedTile.navigation(
        leading: const CreatorBrandLogo(
          asset: 'assets/images/brands/github.svg',
          label: 'GitHub',
        ),
        title: const Text('GitHub'),
        description: Text(
          github.isNotEmpty
              ? l10n.creatorGitHubOwnPublishReady
              : l10n.creatorGitHubOwnPublishMissing,
        ),
        value: githubBusy
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : (github.isEmpty ? Text(l10n.creatorConnect) : null),
        onPressed: githubBusy ? null : (_) => onConnectGitHub(),
        enabled: !githubBusy,
      ),
      SegmentedTile.navigation(
        leading: const CreatorBrandLogo(
          asset: 'assets/images/brands/bandbbs.svg',
          label: 'BandBBS',
        ),
        title: Text(l10n.bandbbs),
        description: Text(
          bandBbsReady
              ? l10n.creatorBandBbsWriteReady
              : l10n.creatorBandBbsWriteMissing,
        ),
        value: bandBbsBusy
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : (!bandBbsReady ? Text(l10n.creatorAuthorize) : null),
        onPressed: bandBbsBusy ? null : (_) => onAuthorizeBandBbs(),
        enabled: !bandBbsBusy,
      ),
    ];
  }

  Future<void> _moveSelection(
    CreatorWorkspaceState state,
    CreatorWorkspaceController controller,
  ) async {
    final selected = state.resources
        .where((item) => _selectedResourceIds.contains(item.resource.id))
        .toList();
    if (selected.isEmpty) return;
    final kind = selected.first.resource.kind.name;
    final choices = state.collections
        .where((item) => item['kind']?.toString() == kind)
        .toList();
    final target = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(AppLocalizations.of(context)!.creatorCollectionAddResource),
        children: [
          for (final item in choices)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, item),
              child: Text(
                ((item['pending_revision'] ?? item['current_revision'])
                            as Map?)?['name']
                        ?.toString() ??
                    '',
              ),
            ),
        ],
      ),
    );
    if (target == null || !mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.creatorCollectionAddResource),
        content: Text(l10n.creatorMoveToCollectionConfirm(selected.length)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.creatorConfirm),
          ),
        ],
      ),
    );
    if (accepted != true) return;
    final collectionId = target['id']!.toString();
    final existing = state.resources
        .where((item) => item.resource.collectionId == collectionId)
        .map((item) => item.resource.id);
    try {
      await controller.setCollectionResources(
        collectionId: collectionId,
        resourceIds: {...existing, ..._selectedResourceIds}.toList(),
        representativeResourceId:
            target['representative_resource_id']?.toString() ?? '',
      );
      setState(() => _selectedResourceIds = const {});
      await _refresh(controller);
    } catch (error) {
      if (mounted) showCreatorFailure(context, error);
    }
  }

  Future<void> _dissolveCollection(
    Map<String, Object?> item,
    CreatorWorkspaceController controller,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.creatorDissolveCollection),
        content: Text(l10n.creatorCollectionDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.creatorDissolveCollection),
          ),
        ],
      ),
    );
    if (accepted != true) return;
    try {
      await controller.deleteCollection(item['id']!.toString());
    } catch (error) {
      if (mounted) showCreatorFailure(context, error);
    }
  }

  Future<void> _openCreateWizard(
    BuildContext context,
    CreatorWorkspaceController controller,
  ) async {
    await context.push('/resources/creator/resources/create');
    if (context.mounted) await _refresh(controller);
  }
}

class _CreatorGovernanceGate extends StatelessWidget {
  const _CreatorGovernanceGate({required this.code});
  final String code;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final banned = code == 'banned';
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Card(
          color: colors.surfaceContainerHigh,
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  banned ? Icons.block : Icons.lock_outline,
                  size: 56,
                  color: colors.error,
                ),
                const SizedBox(height: 20),
                Text(
                  banned ? l10n.creatorBannedTitle : l10n.creatorFrozenTitle,
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  banned
                      ? l10n.creatorBannedDescription
                      : l10n.creatorFrozenDescription,
                  style: Theme.of(context).textTheme.bodyLarge
                      ?.copyWith(color: colors.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CreatorTermsGate extends ConsumerStatefulWidget {
  const _CreatorTermsGate({
    required this.child,
    required this.loading,
    required this.onCreate,
    required this.selectionActive,
    required this.onMoveSelection,
    required this.floatingAccess,
  });

  final Widget child;
  final bool loading;
  final VoidCallback onCreate;
  final bool selectionActive;
  final VoidCallback onMoveSelection;
  final Widget? floatingAccess;

  @override
  ConsumerState<_CreatorTermsGate> createState() => _CreatorTermsGateState();
}

class _CreatorTermsGateState extends ConsumerState<_CreatorTermsGate> {
  static const keyAccepted = 'creator.terms.accepted';
  bool _accepted = false;
  bool _checked = false;
  bool _bottomReached = false;
  final _termsScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _accepted = LegalAgreements.accepted('resource-publishing');
    _termsScrollController.addListener(_markBottomReached);
  }

  @override
  void dispose() {
    _termsScrollController.dispose();
    super.dispose();
  }

  void _markBottomReached() {
    if (_bottomReached || !_termsScrollController.hasClients) return;
    final position = _termsScrollController.position;
    if (position.maxScrollExtent - position.pixels <= 1) {
      setState(() => _bottomReached = true);
    }
  }

  Future<void> _continue() async {
    if (!await LegalAgreements.acceptShown('resource-publishing')) return;
    await SharedPrefsService.instance.setBool(keyAccepted, true);
    if (mounted) setState(() => _accepted = true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_accepted) {
      return Stack(
        children: [
          widget.child,
          if (widget.floatingAccess != null)
            Positioned(
              left: 16,
              right: 196,
              bottom: 16,
              child: Align(
                alignment: AlignmentDirectional.bottomStart,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: widget.floatingAccess,
                ),
              ),
            ),
          Positioned(
            right: 16,
            bottom: 16,
            child: StableFabSwitcher(
              child: widget.selectionActive
                  ? StableExtendedFab(
                      key: const ValueKey('creator-move-selection'),
                      heroTag: 'creator-move-selection',
                      onPressed: widget.loading ? null : widget.onMoveSelection,
                      icon: const Icon(Icons.drive_file_move_outline),
                      label: Text(l10n.creatorMoveToCollection),
                    )
                  : StableExtendedFab(
                      key: const ValueKey('creator-new-resource'),
                      heroTag: 'creator-new-resource',
                      onPressed: widget.loading ? null : widget.onCreate,
                      icon: const Icon(Icons.add),
                      label: Text(l10n.creatorNewResource),
                    ),
            ),
          ),
        ],
      );
    }
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final language = Localizations.localeOf(context).languageCode == 'en'
        ? 'en'
        : 'zh';
    return Column(
      children: [
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 840),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: FutureBuilder<String>(
                            future: loadLegalDocument(
                              ref,
                              'resource-publishing',
                              language,
                            ),
                            builder: (context, snapshot) {
                              if (snapshot.hasError) {
                                return Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(l10n.creatorTermsLoadFailed),
                                      TextButton(
                                        onPressed: () => setState(() {}),
                                        child: Text(l10n.retry),
                                      ),
                                    ],
                                  ),
                                );
                              }
                              if (!snapshot.hasData) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }
                              WidgetsBinding.instance.addPostFrameCallback(
                                (_) => _markBottomReached(),
                              );
                              return Markdown(
                                data: snapshot.data!,
                                controller: _termsScrollController,
                                selectable: true,
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  12,
                                  20,
                                  16,
                                ),
                                styleSheet: markdownStyleSheetFromTheme(theme)
                                    .copyWith(
                                      p: theme.textTheme.bodyMedium?.copyWith(
                                        height: 1.5,
                                      ),
                                      pPadding: const EdgeInsets.only(
                                        bottom: 12,
                                      ),
                                      h1: theme.textTheme.headlineSmall
                                          ?.copyWith(
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
                                onTapLink: (_, href, _) {
                                  final uri = Uri.tryParse(href ?? '');
                                  if (uri != null && uri.hasScheme) {
                                    launchUrl(uri);
                                  }
                                },
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        CreatorBottomBar(
          children: [
            Expanded(
              child: MouseRegion(
                cursor: _bottomReached
                    ? SystemMouseCursors.click
                    : SystemMouseCursors.basic,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _bottomReached
                      ? () => setState(() => _checked = !_checked)
                      : null,
                  child: Row(
                    children: [
                      Checkbox(
                        value: _checked,
                        onChanged: _bottomReached
                            ? (value) =>
                                  setState(() => _checked = value == true)
                            : null,
                      ),
                      Flexible(
                        child: Text(
                          _bottomReached
                              ? l10n.creatorTermsAccept
                              : l10n.oobeAgreementHint,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            FilledButton(
              onPressed: _checked ? _continue : null,
              child: Text(l10n.creatorTermsContinue),
            ),
          ],
        ),
      ],
    );
  }
}
