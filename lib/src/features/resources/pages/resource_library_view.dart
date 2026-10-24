import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/theme/app_theme.dart';
import 'package:oronbox/src/app/utils/error_localization.dart';
import 'package:oronbox/src/app/widgets/app_state_view.dart';
import 'package:oronbox/src/app/widgets/page_container.dart';
import 'package:oronbox/src/core/constants/style_constants.dart';
import 'package:oronbox/src/core/providers/app_settings_providers.dart';
import 'package:oronbox/src/core/services/shared_prefs_service.dart';
import 'package:oronbox/src/data/community/community_source.dart';
import 'package:oronbox/src/data/bandbbs/bandbbs_resource_provider.dart';
import 'package:oronbox/src/device/core/device_kind.dart';
import 'package:oronbox/src/device/core/device_profile.dart';
import 'package:oronbox/src/device/core/xiaomi_wearable_catalog.dart';
import 'package:oronbox/src/device/zeppos/zeppos_device_catalog.dart';
import 'package:oronbox/src/features/devices/controllers/device_manager.dart';
import 'package:oronbox/src/features/accounts/application/host_accounts.dart';
import 'package:oronbox/src/features/accounts/services/bandbbs_auth_service.dart';
import 'package:oronbox/src/features/resources/application/resource_catalog_providers.dart';
import 'package:oronbox/src/features/resources/application/oronbox_resource_attributes.dart';
import 'package:oronbox/src/features/resources/controllers/resource_filter_controller.dart';
import 'package:oronbox/src/features/resources/domain/community_resource.dart';
import 'package:oronbox/src/features/resources/domain/resource_catalog.dart';
import 'package:oronbox/src/features/resources/widgets/bandbbs_category_sidebar.dart';
import 'package:oronbox/src/features/resources/widgets/bandbbs_resource_card.dart';
import 'package:oronbox/src/features/resources/widgets/resource_card.dart';
import 'package:oronbox/src/features/resources/widgets/resource_media_hero.dart';

typedef _ResourceCard = ResourceCard;

class ResourceLibraryView extends ConsumerStatefulWidget {
  const ResourceLibraryView({super.key});
  @override
  ConsumerState<ResourceLibraryView> createState() =>
      _ResourceLibraryViewState();
}

/// Marker for the signed-out BandBBS state, so the error view can offer a
/// sign-in action instead of a bare message.
class _BandBbsSignInRequired implements Exception {
  const _BandBbsSignInRequired();
}

class _ResourceLibraryViewState extends ConsumerState<ResourceLibraryView>
    with SingleTickerProviderStateMixin {
  static const _pageSize = 30;
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  var _searchText = '';
  bool? _sidebarExpanded;
  var _gridView =
      SharedPrefsService.instance.getBool('resource_grid_view') ?? true;
  late final AnimationController _layoutAnimation;
  final _resourceLayoutKeys = <String, GlobalKey>{};
  var _resourceLayoutMotions = const <String, _ResourceLayoutMotion>{};
  var _preparingLayoutMotion = false;
  final _items = <CommunityResource>[];
  var _page = 0;
  var _feedSeed = math.Random.secure().nextInt(0x7fffffff) + 1;
  var _hasMore = true;
  var _loading = true;
  var _loadingMore = false;
  var _waitingForSidebarLoad = false;
  var _fillCheckScheduled = false;
  Object? _error;
  var _generation = 0;

  @override
  void initState() {
    super.initState();
    _layoutAnimation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    _scrollController.addListener(_onScroll);
    _searchFocus.addListener(() {
      if (!_searchFocus.hasFocus) _commitSearch();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _reset());
  }

  @override
  void dispose() {
    _layoutAnimation.dispose();
    _searchFocus.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  GlobalKey _resourceLayoutKey(CommunityResource item) => _resourceLayoutKeys
      .putIfAbsent(item.ref.key, () => GlobalKey(debugLabel: item.ref.key));

  Map<String, Rect> _captureResourceRects() {
    final result = <String, Rect>{};
    for (final entry in _resourceLayoutKeys.entries) {
      final renderObject = entry.value.currentContext?.findRenderObject();
      if (renderObject case final RenderBox box when box.hasSize) {
        result[entry.key] = box.localToGlobal(Offset.zero) & box.size;
      }
    }
    return result;
  }

  void _toggleLayout() {
    final sourceRects = _captureResourceRects();
    _layoutAnimation.stop();
    final widthProgress = ((MediaQuery.sizeOf(context).width - 600) / 800)
        .clamp(0.0, 1.0);
    _layoutAnimation.duration = Duration(
      milliseconds: (240 + 240 * widthProgress).round(),
    );
    setState(() {
      _gridView = !_gridView;
      _resourceLayoutMotions = const {};
      _preparingLayoutMotion = true;
    });
    unawaited(
      SharedPrefsService.instance.setBool('resource_grid_view', _gridView),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final targetRects = _captureResourceRects();
      final motions = <String, _ResourceLayoutMotion>{};
      for (final entry in sourceRects.entries) {
        final target = targetRects[entry.key];
        if (target != null && target.width > 0 && target.height > 0) {
          motions[entry.key] = _ResourceLayoutMotion(
            source: entry.value,
            target: target,
          );
        }
      }
      setState(() {
        _resourceLayoutMotions = motions;
        _preparingLayoutMotion = false;
      });
      _layoutAnimation.forward(from: 0);
    });
  }

  Widget _animateResourceLayout(CommunityResource item, Widget child) {
    return _ResourceLayoutTransition(
      key: _resourceLayoutKey(item),
      animation: _layoutAnimation,
      motion: _resourceLayoutMotions[item.ref.key],
      hidden: _preparingLayoutMotion,
      child: child,
    );
  }

  void _commitSearch() {
    final value = _searchController.text;
    if (value == ref.read(resourceFiltersProvider).query) return;
    ref.read(resourceFiltersProvider.notifier).setQuery(value);
  }

  void _onScroll() {
    if (_error != null) return;
    if (_scrollController.hasClients &&
        _scrollController.position.extentAfter < 600) {
      _load(_generation);
    }
  }

  void _scheduleViewportFill(int generation) {
    if (_fillCheckScheduled) return;
    _fillCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fillCheckScheduled = false;
      if (!mounted ||
          generation != _generation ||
          _error != null ||
          !_scrollController.hasClients) {
        return;
      }
      if (_scrollController.position.extentAfter < 600) {
        _load(generation);
      }
    });
  }

  Future<void> _reset() async {
    final generation = ++_generation;
    _feedSeed = math.Random.secure().nextInt(0x7fffffff) + 1;
    setState(() {
      _items.clear();
      _page = 0;
      _hasMore = true;
      _loading = true;
      _loadingMore = false;
      _error = null;
    });
    await _load(generation);
  }

  Future<void> _load(int generation) async {
    if (!_hasMore || _loadingMore) return;
    if (ref.read(selectedCommunitySourceProvider) ==
            CommunitySourceId.bandbbs &&
        !ref.read(bandBbsAuthProvider).isSignedIn) {
      // The daemon rejects every BandBBS request when signed out; short
      // circuit here instead of hammering it from the viewport-fill loop.
      setState(() {
        _items.clear();
        _hasMore = false;
        _loading = false;
        _loadingMore = false;
        _error = const _BandBbsSignInRequired();
      });
      return;
    }
    _ensureBandBbsSidebarLoaded();
    setState(() => _loadingMore = true);
    try {
      final filters = ref.read(resourceFiltersProvider);
      final source = ref.read(selectedCommunitySourceProvider);
      final result = await ref
          .read(communityCatalogProvider)
          .getPage(
            CommunityResourceQuery(
              page: _page,
              pageSize: _pageSize,
              seed: source == CommunitySourceId.oronBox ? _feedSeed : null,
              query: filters.query,
              sort: filters.sort,
              type: filters.type,
              hidePaid: filters.hidePaid,
              hideForcePaid: filters.hideForcePaid,
              featured: filters.featured,
              selectedDevices: filters.selectedDevices,
              selectedAttributes: filters.selectedAttributes,
            ),
          );
      if (!mounted || generation != _generation) return;
      setState(() {
        _items.addAll(
          result.items.where(
            (item) => !_items.any((current) => current.ref == item.ref),
          ),
        );
        _page += 1;
        _hasMore = result.hasMore && result.items.isNotEmpty;
        _loading = false;
        _loadingMore = false;
      });
      _scheduleViewportFill(generation);
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = error;
        _hasMore = false;
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  void _ensureBandBbsSidebarLoaded() {
    if (ref.read(selectedCommunitySourceProvider) !=
        CommunitySourceId.bandbbs) {
      return;
    }
    final tree = ref.read(bandbbsCategoryTreeProvider);
    if (tree.isLoading) {
      if (_waitingForSidebarLoad) return;
      _waitingForSidebarLoad = true;
      unawaited(
        _retryBandBbsSidebarAfter(ref.read(bandbbsCategoryTreeProvider.future)),
      );
      return;
    }
    final roots = tree.value;
    if (roots == null || roots.isEmpty) {
      ref.invalidate(bandbbsCategoryTreeProvider);
    }
  }

  Future<void> _retryBandBbsSidebarAfter(
    Future<List<BandBbsCategoryNode>> request,
  ) async {
    var hasCategories = false;
    try {
      hasCategories = (await request).isNotEmpty;
    } catch (_) {
      // The resource list remains usable when category loading fails
    } finally {
      _waitingForSidebarLoad = false;
    }
    if (!mounted || hasCategories) return;
    if (ref.read(selectedCommunitySourceProvider) ==
        CommunitySourceId.bandbbs) {
      ref.invalidate(bandbbsCategoryTreeProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final filters = ref.watch(resourceFiltersProvider);
    final source = ref.watch(selectedCommunitySourceProvider);
    ref.listen(resourceFiltersProvider, (_, _) => _reset());
    ref.listen(resourceRefreshProvider, (_, _) => _reset());
    ref.listen(bandBbsAuthProvider, (previous, next) {
      if (!(previous?.isSignedIn ?? false) && next.isSignedIn) _reset();
    });
    ref.listen(
      appSettingsProvider.select(
        (settings) => settings.bandbbsShowAllCategories,
      ),
      (_, _) => _reset(),
    );
    final capabilities = ref.watch(communityCatalogProvider).capabilities;
    final forceList =
        source == CommunitySourceId.bandbbs ||
        source == CommunitySourceId.huamiAppStore;
    if (!_searchFocus.hasFocus && _searchController.text != filters.query) {
      _searchController.text = filters.query;
      _searchText = filters.query;
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        _scheduleViewportFill(_generation);
        final isBandBbs = source == CommunitySourceId.bandbbs;
        final expanded =
            isBandBbs && (_sidebarExpanded ?? constraints.maxWidth >= 900);
        final list = _buildList(
          context,
          l10n,
          filters,
          source,
          gridView: !forceList && _gridView,
        );
        return Column(
          children: [
            _buildToolbar(
              context,
              l10n,
              capabilities,
              sidebarExpanded: expanded,
              onToggleSidebar: isBandBbs
                  ? () => setState(() => _sidebarExpanded = !expanded)
                  : null,
              showLayoutToggle: !forceList,
            ),
            Expanded(
              child: !isBandBbs
                  ? list
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOut,
                          width: expanded ? 260 : 0,
                          clipBehavior: Clip.hardEdge,
                          decoration: const BoxDecoration(),
                          child: const OverflowBox(
                            alignment: Alignment.topLeft,
                            minWidth: 260,
                            maxWidth: 260,
                            child: BandBbsCategorySidebar(),
                          ),
                        ),
                        Expanded(child: list),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildToolbar(
    BuildContext context,
    AppLocalizations l10n,
    CommunityCatalogCapabilities capabilities, {
    required bool sidebarExpanded,
    VoidCallback? onToggleSidebar,
    required bool showLayoutToggle,
  }) {
    final colors = Theme.of(context).colorScheme;
    final compact = MediaQuery.sizeOf(context).width < 600;
    final toolbarButtonStyle = IconButton.styleFrom(
      backgroundColor: colors.surfaceContainerHigh,
      foregroundColor: colors.onSurfaceVariant,
      hoverColor: colors.surfaceContainerHighest,
      highlightColor: colors.surfaceContainerHighest,
    );
    return PageContainer(
      padding: EdgeInsets.symmetric(
        horizontal: StyleConstants.pagePadding,
        vertical: compact ? 10 : StyleConstants.pagePadding,
      ),
      child: Column(
        children: [
          Row(
            children: [
              if (onToggleSidebar != null) ...[
                IconButton.filled(
                  style: toolbarButtonStyle,
                  icon: Icon(sidebarExpanded ? Icons.menu_open : Icons.menu),
                  tooltip: l10n.categories,
                  onPressed: onToggleSidebar,
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: SearchBar(
                  constraints: BoxConstraints.tightFor(
                    height: compact ? 48 : 56,
                  ),
                  enabled: capabilities.search,
                  elevation: const WidgetStatePropertyAll(0),
                  controller: _searchController,
                  focusNode: _searchFocus,
                  hintText: l10n.search,
                  leading: const Icon(Icons.search),
                  trailing: [
                    if (_searchText.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchText = '');
                          ref
                              .read(resourceFiltersProvider.notifier)
                              .setQuery('');
                        },
                      ),
                  ],
                  onChanged: (value) => setState(() => _searchText = value),
                  onSubmitted: (_) => _commitSearch(),
                ),
              ),
              if (showLayoutToggle) ...[
                const SizedBox(width: 8),
                IconButton.filled(
                  style: toolbarButtonStyle,
                  tooltip: _gridView
                      ? l10n.resourceListView
                      : l10n.resourceGridView,
                  onPressed: _toggleLayout,
                  icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 140),
                    transitionBuilder: (child, animation) =>
                        FadeTransition(opacity: animation, child: child),
                    child: Icon(
                      _gridView ? Icons.view_list : Icons.grid_view,
                      key: ValueKey(_gridView),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          const _FilterBar(),
        ],
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    AppLocalizations l10n,
    ResourceFilters filters,
    CommunitySourceId source, {
    required bool gridView,
  }) {
    return RefreshIndicator(
      onRefresh: () {
        unawaited(_reset());
        return Future<void>.value();
      },
      child: ScrollConfiguration(
        behavior: const _NoStretchScrollBehavior(),
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (_loading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              SliverFillRemaining(
                child: Center(
                  child: switch (_error) {
                    _BandBbsSignInRequired() => EmptyStateView(
                      icon: Icons.account_circle_outlined,
                      title: l10n.settingsBandBbsAccountRequired,
                      action: FilledButton(
                        onPressed: () => context.push('/settings/bandbbs'),
                        child: Text(l10n.settingsTapToSignIn),
                      ),
                    ),
                    _ => ErrorStateView(
                      message: localizedErrorMessage(l10n, _error!),
                      onRetry: _reset,
                    ),
                  },
                ),
              )
            else ...[
              if (!gridView)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: StyleConstants.pagePadding,
                  ),
                  sliver: SliverList.builder(
                    itemCount: _items.length,
                    itemBuilder: (context, index) => Padding(
                      padding: EdgeInsets.only(
                        bottom: index == _items.length - 1 ? 0 : 8,
                      ),
                      child: _animateResourceLayout(
                        _items[index],
                        BandBbsResourceCard(
                          key: ValueKey(_items[index].ref.key),
                          item: _items[index],
                        ),
                      ),
                    ),
                  ),
                )
              else
                SliverToBoxAdapter(
                  child: PageContainer(
                    padding: const EdgeInsets.symmetric(
                      horizontal: StyleConstants.pagePadding,
                    ),
                    child: _ResourceGrid(
                      items: _items,
                      animateItem: _animateResourceLayout,
                    ),
                  ),
                ),
              if (_loadingMore)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                )
              else if (_items.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: EmptyStateView(
                      icon: Icons.search_off_outlined,
                      title: l10n.notFound,
                    ),
                  ),
                )
              else if (!_hasMore)
                SliverToBoxAdapter(
                  child: PageContainer(
                    padding: const EdgeInsets.symmetric(
                      horizontal: StyleConstants.pagePadding,
                    ),
                    child: _OtherSourcesFooter(currentSource: source),
                  ),
                ),
            ],
            SliverPadding(
              padding: EdgeInsets.only(
                bottom: bottomContentPadding(context, extra: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Android 默认的拉伸 overscroll 会把边缘卡片的圆角拉变形,禁掉
class _NoStretchScrollBehavior extends MaterialScrollBehavior {
  const _NoStretchScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}

DeviceKind? _currentDeviceKind(DeviceManagerState state) {
  final device = state.currentDevice;
  if (device == null) return null;
  final kind = DeviceRegistry.resolveIdentity(
    name: device.name,
    codename: device.codename,
  ).kind;
  return kind == DeviceKind.zepp ? DeviceKind.zepp : DeviceKind.xiaomi;
}

bool _isCurrentDeviceZepp(DeviceManagerState state) =>
    _currentDeviceKind(state) == DeviceKind.zepp;

List<CommunitySourceId> enabledCommunitySources(
  List<CommunitySourceId>? loadedSources,
  CleanSettings clean, {
  required bool isZepposDevice,
}) => [
  for (final candidate in loadedSources ?? CommunitySourceId.values)
    if ((candidate != CommunitySourceId.oronBox ||
            (clean.oronBoxSourceEnabled && !isZepposDevice)) &&
        (candidate != CommunitySourceId.bandbbs ||
            clean.bandBbsSourceEnabled) &&
        (candidate != CommunitySourceId.astroboxRepo ||
            (clean.astroBoxSourceEnabled && !isZepposDevice)) &&
        (candidate != CommunitySourceId.huamiAppStore ||
            (clean.huamiAppStoreSourceEnabled && isZepposDevice)))
      candidate,
];

Future<void> _switchCommunitySource(
  BuildContext context,
  WidgetRef ref,
  CommunitySourceId candidate,
) async {
  final l10n = AppLocalizations.of(context)!;
  if (candidate == CommunitySourceId.bandbbs) {
    final host = ref.read(hostAccountsProvider.notifier);
    await host.refresh();
    if (!context.mounted) return;
    if (!ref.read(hostAccountsProvider).bandbbs.isSignedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.settingsBandBbsAccountRequired)),
      );
      return;
    }
  }
  if (candidate == CommunitySourceId.huamiAppStore &&
      !ref.read(hostAccountsProvider).amazfit.isSignedIn) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.settingsHuamiAccountRequired)));
    return;
  }
  await ref.read(appSettingsProvider.notifier).setCommunitySource(candidate);
  ref.read(resourceFiltersProvider.notifier).reset();
}

class CommunitySourceMenu extends ConsumerWidget {
  const CommunitySourceMenu({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final source = ref.watch(selectedCommunitySourceProvider);
    final loadedSources = ref.watch(communitySourcesProvider).value;
    final clean = ref.watch(appSettingsProvider).clean;
    final sourceById = <String, CommunitySourceId>{
      for (final candidate in enabledCommunitySources(
        loadedSources,
        clean,
        isZepposDevice: _isCurrentDeviceZepp(ref.watch(deviceManagerProvider)),
      ))
        candidate.storageKey: candidate,
    };
    if (!sourceById.containsKey(source.storageKey) && sourceById.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(appSettingsProvider.notifier)
            .setCommunitySource(sourceById.values.first);
      });
    }
    final l10n = AppLocalizations.of(context)!;
    return MenuAnchor(
      menuChildren: sourceById.values
          .map(
            (candidate) => MenuItemButton(
              trailingIcon: candidate == source
                  ? Icon(
                      Icons.check,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : null,
              onPressed: candidate == source
                  ? null
                  : () => _switchCommunitySource(context, ref, candidate),
              child: Text(_communitySourceLabel(l10n, candidate)),
            ),
          )
          .toList(),
      builder: (_, controller, _) => TextButton(
        onPressed: controller.isOpen ? controller.close : controller.open,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_communitySourceLabel(l10n, source)),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }
}

class _OtherSourcesFooter extends ConsumerWidget {
  const _OtherSourcesFooter({required this.currentSource});

  final CommunitySourceId currentSource;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final clean = ref.watch(appSettingsProvider).clean;
    final loadedSources = ref.watch(communitySourcesProvider).value;
    final others = enabledCommunitySources(
      loadedSources,
      clean,
      isZepposDevice: _isCurrentDeviceZepp(ref.watch(deviceManagerProvider)),
    ).where((candidate) => candidate != currentSource).toList();
    if (others.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Text(
            l10n.resourceLibraryEndOfList,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final candidate in others)
                FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.surfaceContainerHighest,
                    foregroundColor: colors.onSurface,
                  ),
                  onPressed: () =>
                      _switchCommunitySource(context, ref, candidate),
                  child: Text(_communitySourceLabel(l10n, candidate)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _ResourceFilterSection { type, devices, paid }

class _FilterBar extends ConsumerWidget {
  const _FilterBar();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final filters = ref.watch(resourceFiltersProvider);
    final source = ref.watch(selectedCommunitySourceProvider);
    // Keep the device catalog warm while the resource page is visible. This
    // prevents the device sheet from opening at one height and resizing when
    // its options arrive from the provider.
    ref.watch(communityCatalogDevicesProvider);
    if (source == CommunitySourceId.bandbbs) {
      ref.watch(bandbbsCategoryTreeProvider);
    }
    final hasTypeFilters =
        filters.type != null ||
        filters.featured ||
        filters.selectedAttributes.isNotEmpty;
    final hasDeviceFilters = filters.selectedDevices.isNotEmpty;
    final hasPaidFilters =
        filters.hidePaid ||
        ((source == CommunitySourceId.oronBox ||
                source == CommunitySourceId.astroboxRepo) &&
            filters.hideForcePaid);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _FilterButton(
            icon: Icons.category_outlined,
            label: l10n.resourceTypeFilter,
            selected: hasTypeFilters,
            onPressed: () => unawaited(
              _showFilters(context, ref, _ResourceFilterSection.type),
            ),
          ),
          const SizedBox(width: 8),
          _FilterButton(
            icon: Icons.devices_other_outlined,
            label: l10n.resourceCompatibleDevicesFilter,
            selected: hasDeviceFilters,
            onPressed: () => unawaited(
              _showFilters(context, ref, _ResourceFilterSection.devices),
            ),
          ),
          const SizedBox(width: 8),
          _FilterButton(
            icon: Icons.payments_outlined,
            label: l10n.creatorPaidType,
            selected: hasPaidFilters,
            onPressed: () => unawaited(
              _showFilters(context, ref, _ResourceFilterSection.paid),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Future<void> _showFilters(
    BuildContext context,
    WidgetRef ref,
    _ResourceFilterSection section,
  ) async {
    if (section == _ResourceFilterSection.devices) {
      try {
        await ref.read(communityCatalogDevicesProvider.future);
        if (ref.read(selectedCommunitySourceProvider) ==
            CommunitySourceId.bandbbs) {
          await ref.read(bandbbsCategoryTreeProvider.future);
        }
      } catch (_) {
        // The sheet can still show the numeric Huami source input or an empty
        // state when the catalog request fails.
      }
      if (!context.mounted) return;
    }
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.45,
        ),
        child: _FilterSheet(section: section),
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        minimumSize: const Size(0, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        backgroundColor: selected
            ? Theme.of(context).useMaterial3
                  ? colors.secondaryContainer
                  : context.appSelectionContainer
            : colors.surfaceContainerHighest,
        foregroundColor: selected
            ? Theme.of(context).useMaterial3
                  ? colors.onSecondaryContainer
                  : context.appSelectionForeground
            : colors.onSurfaceVariant,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        overlayColor: Colors.transparent,
      ).copyWith(elevation: const WidgetStatePropertyAll(0)),
      onPressed: onPressed,
      icon: Icon(selected ? Icons.check : icon, size: 18),
      label: Text(label),
    );
  }
}

class _FilterSheet extends ConsumerWidget {
  const _FilterSheet({required this.section});

  final _ResourceFilterSection section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final filters = ref.watch(resourceFiltersProvider);
    final source = ref.watch(selectedCommunitySourceProvider);
    final devices =
        ref.watch(communityCatalogDevicesProvider).value ??
        const <CommunityResourceDevice>[];
    final categoryTree = source == CommunitySourceId.bandbbs
        ? ref.watch(bandbbsCategoryTreeProvider).value
        : null;
    final currentDeviceKind = _currentDeviceKind(
      ref.watch(deviceManagerProvider),
    );
    final deviceOptions = _buildDeviceFilterOptions(
      devices,
      currentDeviceKind: currentDeviceKind,
      visibleDeviceIds: categoryTree == null
          ? null
          : bandBbsVisibleCategoryFilterIds(categoryTree),
    );
    final resourceAttributes = source == CommunitySourceId.oronBox
        ? ref.watch(oronBoxResourceAttributesProvider).value ??
              const <OronBoxResourceAttribute>[]
        : const <OronBoxResourceAttribute>[];
    final title = switch (section) {
      _ResourceFilterSection.type => l10n.resourceTypeFilter,
      _ResourceFilterSection.devices => l10n.resourceCompatibleDevicesFilter,
      _ResourceFilterSection.paid => l10n.creatorPaidType,
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          if (section == _ResourceFilterSection.type) ...[
            Text(l10n.all, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (source != CommunitySourceId.huamiAppStore)
                  FilterChip(
                    showCheckmark: false,
                    label: Text(
                      _typeLabel(
                        l10n,
                        CommunityResourceType.quickApp,
                        source: source,
                      ),
                    ),
                    selected: filters.type == CommunityResourceType.quickApp,
                    onSelected: (_) => ref
                        .read(resourceFiltersProvider.notifier)
                        .setType(
                          filters.type == CommunityResourceType.quickApp
                              ? null
                              : CommunityResourceType.quickApp,
                        ),
                  ),
                if (source == CommunitySourceId.huamiAppStore ||
                    source.isPlugin)
                  FilterChip(
                    showCheckmark: false,
                    label: Text(l10n.miniprograms),
                    selected: filters.type == CommunityResourceType.miniprogram,
                    onSelected: (_) => ref
                        .read(resourceFiltersProvider.notifier)
                        .setType(
                          filters.type == CommunityResourceType.miniprogram
                              ? null
                              : CommunityResourceType.miniprogram,
                        ),
                  ),
                FilterChip(
                  showCheckmark: false,
                  label: Text(l10n.watchfaces),
                  selected: filters.type == CommunityResourceType.watchface,
                  onSelected: (_) => ref
                      .read(resourceFiltersProvider.notifier)
                      .setType(
                        filters.type == CommunityResourceType.watchface
                            ? null
                            : CommunityResourceType.watchface,
                      ),
                ),
                if (source != CommunitySourceId.oronBox &&
                    source != CommunitySourceId.astroboxRepo)
                  FilterChip(
                    showCheckmark: false,
                    label: Text(l10n.firmwareTools),
                    selected: filters.type == CommunityResourceType.firmware,
                    onSelected: (_) => ref
                        .read(resourceFiltersProvider.notifier)
                        .setType(
                          filters.type == CommunityResourceType.firmware
                              ? null
                              : CommunityResourceType.firmware,
                        ),
                  ),
                if (source == CommunitySourceId.astroboxRepo)
                  FilterChip(
                    showCheckmark: false,
                    label: Text(l10n.module),
                    selected: filters.type == CommunityResourceType.canopus,
                    onSelected: (_) => ref
                        .read(resourceFiltersProvider.notifier)
                        .setType(
                          filters.type == CommunityResourceType.canopus
                              ? null
                              : CommunityResourceType.canopus,
                        ),
                  ),
              ],
            ),
            if (source == CommunitySourceId.oronBox) ...[
              const SizedBox(height: 16),
              Text(
                l10n.creatorContentAttributes,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilterChip(
                    showCheckmark: false,
                    label: Text(l10n.resourceHomeFeatured),
                    selected: filters.featured,
                    onSelected: (value) => ref
                        .read(resourceFiltersProvider.notifier)
                        .setFeatured(value),
                  ),
                  for (final attribute in resourceAttributes)
                    FilterChip(
                      showCheckmark: false,
                      label: Text(
                        attribute.labelFor(Localizations.localeOf(context)),
                      ),
                      selected: filters.selectedAttributes.contains(
                        attribute.id,
                      ),
                      onSelected: (_) => ref
                          .read(resourceFiltersProvider.notifier)
                          .toggleAttribute(attribute.id),
                    ),
                ],
              ),
            ],
          ],
          if (section == _ResourceFilterSection.devices) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: deviceOptions
                  .map(
                    (option) => FilterChip(
                      showCheckmark: false,
                      label: Text(option.label),
                      selected: option.ids.any(
                        filters.selectedDevices.contains,
                      ),
                      onSelected: (_) {
                        ref
                            .read(resourceFiltersProvider.notifier)
                            .toggleDeviceGroup(option.ids);
                      },
                    ),
                  )
                  .toList(),
            ),
            if (source == CommunitySourceId.huamiAppStore) ...[
              const SizedBox(height: 12),
              _HuamiDeviceSourceInput(filters: filters),
            ],
          ],
          if (section == _ResourceFilterSection.paid) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  showCheckmark: false,
                  label: Text('${l10n.hide}${l10n.paid}'),
                  selected: filters.hidePaid,
                  onSelected: (value) => ref
                      .read(resourceFiltersProvider.notifier)
                      .setHidePaid(value),
                ),
                if (source == CommunitySourceId.oronBox ||
                    source == CommunitySourceId.astroboxRepo)
                  FilterChip(
                    showCheckmark: false,
                    label: Text('${l10n.hide}${l10n.forcePaid}'),
                    selected: filters.hideForcePaid,
                    onSelected: (value) => ref
                        .read(resourceFiltersProvider.notifier)
                        .setHideForcePaid(value),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _HuamiDeviceSourceInput extends ConsumerStatefulWidget {
  const _HuamiDeviceSourceInput({required this.filters});

  final ResourceFilters filters;

  @override
  ConsumerState<_HuamiDeviceSourceInput> createState() =>
      _HuamiDeviceSourceInputState();
}

class _HuamiDeviceSourceInputState
    extends ConsumerState<_HuamiDeviceSourceInput> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _firstNumericDeviceSource());
  }

  @override
  void didUpdateWidget(covariant _HuamiDeviceSourceInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    final value = _firstNumericDeviceSource();
    if (value != _controller.text) {
      _controller.text = value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: '\u8bbe\u5907\u6e90',
              hintText: '260',
              prefixIcon: const Icon(Icons.numbers),
              isDense: true,
              border: const OutlineInputBorder(),
              suffixIcon: widget.filters.selectedDevices.any(_isNumeric)
                  ? IconButton(
                      tooltip: MaterialLocalizations.of(context)
                          .deleteButtonTooltip,
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _controller.clear();
                        ref
                            .read(resourceFiltersProvider.notifier)
                            .clearNumericDevices();
                      },
                    )
                  : null,
            ),
            onSubmitted: (_) => _apply(),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: context.appSelectionContainer,
            foregroundColor: context.appSelectionForeground,
          ),
          onPressed: _apply,
          child: const Text('\u5e94\u7528'),
        ),
      ],
    );
  }

  void _apply() {
    final source = int.tryParse(_controller.text.trim());
    if (source == null || source <= 0) return;
    ref.read(resourceFiltersProvider.notifier).setNumericDevice(source);
  }

  String _firstNumericDeviceSource() =>
      widget.filters.selectedDevices.firstWhere(_isNumeric, orElse: () => '');

  bool _isNumeric(String value) {
    final parsed = int.tryParse(value);
    return parsed != null && parsed > 0;
  }
}

class _DeviceFilterOption {
  const _DeviceFilterOption({required this.label, required this.ids});

  final String label;
  final Set<String> ids;
}

List<_DeviceFilterOption> _buildDeviceFilterOptions(
  Iterable<CommunityResourceDevice> devices, {
  DeviceKind? currentDeviceKind,
  Set<String>? visibleDeviceIds,
}) {
  final grouped = <String, Set<String>>{};
  for (final device in devices) {
    final rawId = device.codename.trim();
    if ((visibleDeviceIds != null &&
            rawId.startsWith('bandbbs-category:') &&
            !visibleDeviceIds.contains(rawId)) ||
        _shouldHideDeviceFilterOption(device, currentDeviceKind)) {
      continue;
    }
    final identity = normalizeXiaomiWearableIdentity(rawId);
    final id = identity?.codename ?? rawId;
    if (id.isEmpty) continue;

    final label =
        identity?.displayName ??
        (device.name.trim().isNotEmpty ? device.name.trim() : id);
    grouped.putIfAbsent(label, () => <String>{}).add(id);
  }

  return grouped.entries
      .map((entry) => _DeviceFilterOption(label: entry.key, ids: entry.value))
      .toList()
    ..sort((a, b) => a.label.compareTo(b.label));
}

bool _shouldHideDeviceFilterOption(
  CommunityResourceDevice device,
  DeviceKind? currentDeviceKind,
) {
  final name = _compactDeviceFilterText(device.name);
  final description = _compactDeviceFilterText(device.description);
  const permanentlyHidden = {
    'amazfitstratos',
    'amazfit智能手表青春版',
    '华米amazfitgts',
  };
  if (permanentlyHidden.contains(name) ||
      permanentlyHidden.contains(description)) {
    return true;
  }

  final isXiaomi = _isXiaomiDeviceFilterOption(device, name);
  final isZepp = _isZeppDeviceFilterOption(device, name);
  return switch (currentDeviceKind) {
    DeviceKind.xiaomi => isZepp,
    DeviceKind.zepp => isXiaomi && !_isMiBand7FilterOption(device, name),
    null => false,
  };
}

bool _isXiaomiDeviceFilterOption(
  CommunityResourceDevice device,
  String compactName,
) {
  return normalizeXiaomiWearableIdentity(device.name) != null ||
      compactName.startsWith('小米') ||
      compactName.startsWith('xiaomi') ||
      compactName.startsWith('红米') ||
      compactName.startsWith('redmi');
}

bool _isZeppDeviceFilterOption(
  CommunityResourceDevice device,
  String compactName,
) {
  return zeppOsDeviceForBluetoothName(device.name) != null ||
      compactName.startsWith('amazfit') ||
      compactName.startsWith('华米') ||
      compactName.startsWith('米动') ||
      compactName.startsWith('zepp');
}

bool _isMiBand7FilterOption(
  CommunityResourceDevice device,
  String compactName,
) {
  return compactName == '小米手环7' ||
      compactName == 'xiaomismartband7' ||
      compactName == 'xiaomismartband7nfc' ||
      compactName == 'miband7' ||
      device.codename.trim().toLowerCase() == 'mi-band-7';
}

String _compactDeviceFilterText(String value) => value
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9\u4e00-\u9fff]+'), '');

String _typeLabel(
  AppLocalizations l10n,
  CommunityResourceType type, {
  CommunitySourceId? source,
}) => switch (type) {
  CommunityResourceType.quickApp =>
    source == CommunitySourceId.huamiAppStore
        ? l10n.miniprograms
        : l10n.quickApps,
  CommunityResourceType.miniprogram => l10n.miniprograms,
  CommunityResourceType.watchface => l10n.watchfaces,
  CommunityResourceType.firmware => l10n.firmwareTools,
  CommunityResourceType.canopus => l10n.module,
};

String _communitySourceLabel(AppLocalizations l10n, CommunitySourceId source) =>
    switch (source) {
      CommunitySourceId.astroboxRepo => l10n.communitySourceAstroBoxRepo,
      CommunitySourceId.bandbbs => l10n.communitySourceBandBbs,
      CommunitySourceId.huamiAppStore => l10n.communitySourceHuamiAppStore,
      _ => source.displayName,
    };

class _ResourceGrid extends StatelessWidget {
  const _ResourceGrid({required this.items, required this.animateItem});
  final List<CommunityResource> items;
  final Widget Function(CommunityResource item, Widget child) animateItem;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final spacing = 10.0;
        final minTrackWidth = 150.0;
        final crossAxisCount = ((width + spacing) / (minTrackWidth + spacing))
            .floor()
            .clamp(1, 1000);
        final trackWidth =
            (width - (crossAxisCount - 1) * spacing) / crossAxisCount;
        final cardWidth = trackWidth > 300 ? 300.0 : trackWidth;
        final coverHeight = cardWidth * 2 / 3;

        return Wrap(
          alignment: WrapAlignment.start,
          spacing: spacing,
          runSpacing: spacing,
          children: items.indexed.map((entry) {
            final (index, item) = entry;
            return SizedBox(
              width: trackWidth,
              child: Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: cardWidth,
                  child: animateItem(
                    item,
                    _ResourceCard(item: item, coverHeight: coverHeight),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _ResourceLayoutMotion {
  const _ResourceLayoutMotion({required this.source, required this.target});

  final Rect source;
  final Rect target;
}

class _ResourceLayoutTransition extends StatelessWidget {
  const _ResourceLayoutTransition({
    super.key,
    required this.animation,
    required this.motion,
    required this.hidden,
    required this.child,
  });

  final Animation<double> animation;
  final _ResourceLayoutMotion? motion;
  final bool hidden;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        if (hidden) return Opacity(opacity: 0, child: child);
        final currentMotion = motion;
        if (currentMotion == null) return child!;
        final progress = Curves.easeInOutCubic.transform(animation.value);
        final remaining = 1 - progress;
        final target = currentMotion.target;
        final source = currentMotion.source;
        final scaleX = 1 + (source.width / target.width - 1) * remaining;
        final scaleY = 1 + (source.height / target.height - 1) * remaining;
        final opacityDistance = progress * 2 - 1;
        final mediaOpacity = opacityDistance * opacityDistance;
        final transform = Matrix4.diagonal3Values(scaleX, scaleY, 1)
          ..setTranslationRaw(
            (source.left - target.left) * remaining,
            (source.top - target.top) * remaining,
            0,
          );
        return ResourceLayoutMediaOpacity(
          opacity: mediaOpacity,
          child: Transform(
            alignment: Alignment.topLeft,
            transform: transform,
            child: child,
          ),
        );
      },
    );
  }
}
