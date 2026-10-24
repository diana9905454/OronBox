import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/theme/app_theme.dart';
import 'package:oronbox/src/app/widgets/app_state_view.dart';
import 'package:oronbox/src/app/widgets/network_img_layer.dart';
import 'package:oronbox/src/app/widgets/page_container.dart';
import 'package:oronbox/src/core/constants/style_constants.dart';
import 'package:oronbox/src/data/community/community_source.dart';
import 'package:oronbox/src/data/oronbox/oronbox_home_api.dart';
import 'package:oronbox/src/features/resources/application/home_providers.dart';
import 'package:oronbox/src/features/resources/application/resource_catalog_providers.dart';
import 'package:oronbox/src/features/resources/controllers/resource_filter_controller.dart';
import 'package:oronbox/src/features/resources/domain/community_resource.dart';
import 'package:oronbox/src/features/resources/domain/resource_catalog.dart';
import 'package:oronbox/src/features/resources/pages/blog_post_page.dart';
import 'package:oronbox/src/features/resources/widgets/resource_card.dart';
import 'package:oronbox/src/features/resources/widgets/resource_media_hero.dart';
import 'package:oronbox/src/app/utils/error_localization.dart';
import 'package:oronbox/src/core/providers/app_settings_providers.dart';
import 'package:oronbox/src/features/resources/widgets/resource_external_link.dart';
import 'package:oronbox/src/features/resources/pages/resources_page.dart'
    show resourceRouteObserver;

typedef _ResourceCard = ResourceCard;
typedef _ResourceLabel = ResourceLabel;
typedef _NoStretchScrollBehavior = NoStretchScrollBehavior;

String _typeLabel(
  AppLocalizations l10n,
  CommunityResourceType type, {
  CommunitySourceId? source,
}) => resourceTypeLabel(l10n, type, source: source);

String _paidLabel(AppLocalizations l10n, CommunityPaidType type) =>
    resourcePaidLabel(l10n, type);

final _homeFeedProvider = FutureProvider.autoDispose
    .family<List<CommunityResource>, CommunitySortRule>((ref, sort) async {
      final home = await _tryLoadHomeFeed(ref);
      if (home?.resourceFeed.available == true) {
        return switch (sort) {
          CommunitySortRule.recommendation => home!.resourceFeed.recommended,
          CommunitySortRule.time => home!.resourceFeed.latest,
          _ => home!.resourceFeed.recommended,
        };
      }
      ref.watch(resourceRefreshProvider);
      final page = await ref
          .watch(communityCatalogProviderForSource(CommunitySourceId.oronBox))
          .getPage(CommunityResourceQuery(pageSize: 12, sort: sort));
      return page.items;
    });

final _featuredFeedProvider =
    FutureProvider.autoDispose<List<CommunityResource>>((ref) async {
      final home = await _tryLoadHomeFeed(ref);
      if (home?.resourceFeed.available == true) {
        return home!.resourceFeed.featured;
      }
      ref.watch(resourceRefreshProvider);
      final page = await ref
          .watch(communityCatalogProviderForSource(CommunitySourceId.oronBox))
          .getPage(
            const CommunityResourceQuery(
              pageSize: 12,
              sort: CommunitySortRule.recommendation,
              featured: true,
            ),
          );
      return page.items;
    });

Future<HomeFeed?> _tryLoadHomeFeed(Ref ref) async {
  try {
    return await ref.watch(homeFeedProvider.future);
  } catch (_) {
    // The curated homepage is supplementary. Keep the resource rows usable
    // when the aggregate endpoint is temporarily unavailable.
    return null;
  }
}

class ResourceHomeView extends ConsumerStatefulWidget {
  const ResourceHomeView({super.key});

  @override
  ConsumerState<ResourceHomeView> createState() => _ResourceHomeViewState();
}

class _ResourceHomeViewState extends ConsumerState<ResourceHomeView>
    with RouteAware {
  String? _activeHeroOccurrence;
  var _resourcePushInFlight = false;
  var _heroOccurrenceGeneration = 0;
  ModalRoute<dynamic>? _observedRoute;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is ModalRoute<dynamic> && route != _observedRoute) {
      if (_observedRoute != null) {
        resourceRouteObserver.unsubscribe(this);
      }
      _observedRoute = route;
      resourceRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    resourceRouteObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    _finishHeroAfterRoutePop(
      resourceRouteObserver.takeLastPoppedRoute(),
      _heroOccurrenceGeneration,
    );
  }

  void _finishHeroAfterRoutePop(Route<dynamic>? route, int generation) {
    if (_activeHeroOccurrence == null) return;
    final animation = route is TransitionRoute<dynamic>
        ? route.animation
        : null;
    if (animation == null || animation.status == AnimationStatus.dismissed) {
      _clearActiveHeroOccurrence(generation);
      return;
    }

    void handleStatus(AnimationStatus status) {
      if (status == AnimationStatus.dismissed) {
        animation.removeStatusListener(handleStatus);
        _clearActiveHeroOccurrence(generation);
      } else if (status == AnimationStatus.completed) {
        // A back gesture may have been canceled. Keep the source Hero enabled
        // so a later pop can start a new flight.
        animation.removeStatusListener(handleStatus);
      }
    }

    animation.addStatusListener(handleStatus);
  }

  void _clearActiveHeroOccurrence(int generation) {
    if (mounted &&
        generation == _heroOccurrenceGeneration &&
        _activeHeroOccurrence != null) {
      setState(() => _activeHeroOccurrence = null);
    }
  }

  void _openResource(CommunityResource resource, String occurrence) {
    if (_resourcePushInFlight) return;
    _resourcePushInFlight = true;
    _heroOccurrenceGeneration += 1;
    setState(() => _activeHeroOccurrence = occurrence);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        _resourcePushInFlight = false;
        return;
      }
      final path = resource.isCollection
          ? '/resources/collection/${resource.ref.id}'
          : '/resources/detail/${resource.ref.id}';
      unawaited(
        context.push(path, extra: resource).whenComplete(() {
          if (!mounted || !_resourcePushInFlight) return;
          setState(() => _resourcePushInFlight = false);
        }),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final clean = ref.watch(appSettingsProvider.select((state) => state.clean));
    final home = ref.watch(homeFeedProvider);
    final sections = [
      if (clean.homeLatestEnabled)
        (
          title: l10n.newlyPublished,
          sort: CommunitySortRule.time,
          feed: ref.watch(_homeFeedProvider(CommunitySortRule.time)),
          hideWhileLoading: false,
        ),
      if (clean.homeRecommendedEnabled)
        (
          title: l10n.resourceHomeRecommended,
          sort: CommunitySortRule.recommendation,
          feed: ref.watch(_homeFeedProvider(CommunitySortRule.recommendation)),
          hideWhileLoading: false,
        ),
      if (clean.homeFeaturedEnabled)
        (
          title: l10n.resourceHomeFeatured,
          sort: CommunitySortRule.recommendation,
          feed: ref.watch(_featuredFeedProvider),
          hideWhileLoading: true,
        ),
    ];
    final curated = home.value;
    final curatedEmpty =
        curated == null ||
        ((!clean.homeBannerEnabled || curated.banners.isEmpty) &&
            curated.blogs.isEmpty &&
            (!clean.homeEditorSectionsEnabled ||
                curated.sections.every((section) => section.cards.isEmpty)));
    final allFailed =
        home.hasError && sections.every((section) => section.feed.hasError);
    final allEmpty =
        !allFailed &&
        !home.isLoading &&
        curatedEmpty &&
        sections.every(
          (section) => section.feed.hasValue && section.feed.value!.isEmpty,
        );

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(homeFeedProvider);
        ref.invalidate(_featuredFeedProvider);
        ref.invalidate(_homeFeedProvider);
      },
      child: ScrollConfiguration(
        behavior: const _NoStretchScrollBehavior(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (allFailed)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _HomeEmpty(
                  error: sections
                      .map((section) => section.feed.error)
                      .firstOrNull,
                ),
              )
            else if (allEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _HomeEmpty(),
              )
            else
              SliverList.list(
                children: [
                  if (!home.isLoading &&
                      clean.homeBannerEnabled &&
                      curated != null &&
                      curated.banners.isNotEmpty)
                    _HomeBannerCarousel(banners: curated.banners),
                  if (!home.isLoading &&
                      curated != null &&
                      curated.blogs.isNotEmpty)
                    _HomeBlogSection(blogs: curated.blogs),
                  if (!home.isLoading &&
                      clean.homeEditorSectionsEnabled &&
                      curated != null)
                    for (
                      var index = 0;
                      index < curated.sections.length;
                      index++
                    )
                      if (curated.sections[index].cards.isNotEmpty)
                        _HomeEditorSection(
                          section: curated.sections[index],
                          heroOccurrencePrefix: 'editor:$index',
                          heroOccurrence: _activeHeroOccurrence,
                          onResourceTap: (resource, itemIndex) => _openResource(
                            resource,
                            'editor:$index:$itemIndex',
                          ),
                        ),
                  for (var index = 0; index < sections.length; index++)
                    if ((!sections[index].hideWhileLoading &&
                            sections[index].feed.isLoading) ||
                        (sections[index].feed.hasValue &&
                            sections[index].feed.value!.isNotEmpty))
                      _HomeSection(
                        title: sections[index].title,
                        sort: sections[index].sort,
                        feed: sections[index].feed,
                        heroOccurrencePrefix: 'feed:$index',
                        heroOccurrence: _activeHeroOccurrence,
                        onResourceTap: (resource, itemIndex) =>
                            _openResource(resource, 'feed:$index:$itemIndex'),
                      ),
                  if (clean.resourceLibraryEnabled && clean.hasResourceSource)
                    _HomeAllResourcesFooter(
                      onPressed: () => ref
                          .read(resourceModeControllerProvider.notifier)
                          .setMode(ResourceMode.library),
                    ),
                  SizedBox(
                    height: bottomContentPadding(
                      context,
                      extra: StyleConstants.pagePadding,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _HomeAllResourcesFooter extends StatelessWidget {
  const _HomeAllResourcesFooter({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: StyleConstants.pagePadding,
        vertical: 24,
      ),
      child: Center(
        child: FilledButton.tonal(
          style: FilledButton.styleFrom(
            backgroundColor: colors.surfaceContainerHighest,
            foregroundColor: colors.onSurface,
          ),
          onPressed: onPressed,
          child: Text(l10n.viewAllResources),
        ),
      ),
    );
  }
}

class _HomeSection extends ConsumerWidget {
  const _HomeSection({
    required this.title,
    required this.sort,
    required this.feed,
    required this.heroOccurrencePrefix,
    required this.heroOccurrence,
    required this.onResourceTap,
  });

  final String title;
  final CommunitySortRule sort;
  final AsyncValue<List<CommunityResource>> feed;
  final String heroOccurrencePrefix;
  final String? heroOccurrence;
  final void Function(CommunityResource resource, int index) onResourceTap;

  static const _cardSpacing = 12.0;
  static const _cardTargetWidth = 190.0;
  static const _cardBodyHeight = 76.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return PageContainer(
      padding: const EdgeInsets.fromLTRB(
        StyleConstants.pagePadding,
        StyleConstants.pagePadding,
        StyleConstants.pagePadding,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              TextButton(
                onPressed: () {
                  ref.read(resourceFiltersProvider.notifier).reset();
                  ref.read(resourceFiltersProvider.notifier).setSort(sort);
                  ref
                      .read(resourceModeControllerProvider.notifier)
                      .setMode(ResourceMode.library);
                },
                child: Text(l10n.more),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final count = math.max(
                2,
                (constraints.maxWidth / _cardTargetWidth).floor(),
              );
              final cardWidth =
                  (constraints.maxWidth - (count - 1) * _cardSpacing) / count;
              final coverHeight = cardWidth * 0.64;
              return SizedBox(
                height: coverHeight + _cardBodyHeight,
                child: feed.isLoading
                    ? _HomeLoadingCards(
                        count: count,
                        cardWidth: cardWidth,
                        coverHeight: coverHeight,
                      )
                    : switch (feed) {
                        AsyncData(:final value) =>
                          value.isEmpty
                              ? _HomeSlotEmpty(
                                  height: coverHeight + _cardBodyHeight,
                                )
                              : ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: value.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(width: _cardSpacing),
                                  itemBuilder: (context, index) => SizedBox(
                                    width: cardWidth,
                                    child: _ResourceCard(
                                      item: value[index],
                                      coverHeight: coverHeight,
                                      heroEnabled:
                                          heroOccurrence ==
                                          '$heroOccurrencePrefix:$index',
                                      onTap: () =>
                                          onResourceTap(value[index], index),
                                    ),
                                  ),
                                ),
                        AsyncError(:final error) => Center(
                          child: Text(
                            localizedErrorMessage(l10n, error),
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ),
                        _ => ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: count,
                          separatorBuilder: (_, _) =>
                              const SizedBox(width: _cardSpacing),
                          itemBuilder: (_, _) => SizedBox(
                            width: cardWidth,
                            child: _HomeResourceSkeleton(
                              coverHeight: coverHeight,
                            ),
                          ),
                        ),
                      },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HomeEmpty extends ConsumerWidget {
  const _HomeEmpty({this.error});

  final Object? error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    if (error != null) {
      return ErrorStateView(
        icon: Icons.cloud_off_outlined,
        message: localizedErrorMessage(l10n, error!),
        onRetry: () {
          ref.invalidate(homeFeedProvider);
          ref.invalidate(_featuredFeedProvider);
          ref.invalidate(_homeFeedProvider);
        },
      );
    }
    return EmptyStateView(
      icon: Icons.home_outlined,
      title: l10n.resourceHomeEmptyTitle,
      message: l10n.resourceHomeEmptySubtitle,
      action: FilledButton.icon(
        onPressed: () {
          ref
              .read(resourceModeControllerProvider.notifier)
              .setMode(ResourceMode.library);
        },
        icon: const Icon(Icons.library_books_outlined),
        label: Text(l10n.openResourceLibrary),
      ),
    );
  }
}

class _HomeSlotEmpty extends StatelessWidget {
  const _HomeSlotEmpty({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: .3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          AppLocalizations.of(context)!.noContent,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: colors.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _HomeLoadingCards extends StatelessWidget {
  const _HomeLoadingCards({
    required this.count,
    required this.cardWidth,
    required this.coverHeight,
  });

  final int count;
  final double cardWidth;
  final double coverHeight;

  @override
  Widget build(BuildContext context) => ListView.separated(
    scrollDirection: Axis.horizontal,
    itemCount: count,
    separatorBuilder: (_, _) =>
        const SizedBox(width: _HomeSection._cardSpacing),
    itemBuilder: (_, _) => SizedBox(
      width: cardWidth,
      child: _HomeResourceSkeleton(coverHeight: coverHeight),
    ),
  );
}

class _HomeResourceSkeleton extends StatelessWidget {
  const _HomeResourceSkeleton({required this.coverHeight});

  final double coverHeight;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant
        .withValues(alpha: .12);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: coverHeight, color: color),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 112,
                  height: 14,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: 68,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeBannerCarousel extends ConsumerStatefulWidget {
  const _HomeBannerCarousel({required this.banners});

  final List<HomeBanner> banners;

  @override
  ConsumerState<_HomeBannerCarousel> createState() =>
      _HomeBannerCarouselState();
}

class _HomeBannerCarouselState extends ConsumerState<_HomeBannerCarousel> {
  final _controller = PageController();
  Timer? _timer;
  var _index = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted || !_controller.hasClients || widget.banners.length < 2) {
        return;
      }
      _controller.animateToPage(
        (_index + 1) % widget.banners.length,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _open(HomeBanner banner) {
    switch (banner.type) {
      case HomeBannerType.resource:
        if (banner.resourceId.isNotEmpty) {
          context.push(
            '/resources/detail/${banner.resourceId}?source=${CommunitySourceId.oronBox.storageKey}',
          );
        }
      case HomeBannerType.blog:
        if (banner.blogSlug.isNotEmpty) {
          context.push(
            '/resources/blog/${banner.blogSlug}',
            extra: BlogCard(
              slug: banner.blogSlug,
              type: 'announcement',
              title: banner.title,
              subtitle: banner.subtitle,
              author: '',
              coverUrl: banner.coverUrl,
            ),
          );
        }
      case HomeBannerType.link:
        final url = banner.linkUrl;
        if (url != null) openResourceExternalLink(context, url);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return PageContainer(
      padding: const EdgeInsets.fromLTRB(
        StyleConstants.pagePadding,
        0,
        StyleConstants.pagePadding,
        8,
      ),
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) => SizedBox(
              height: math.min(constraints.maxWidth * 9 / 21, 340),
              child: PageView.builder(
                controller: _controller,
                itemCount: widget.banners.length,
                onPageChanged: (index) => setState(() => _index = index),
                itemBuilder: (context, index) {
                  final banner = widget.banners[index];
                  return Card(
                    margin: EdgeInsets.zero,
                    clipBehavior: Clip.antiAlias,
                    color: colors.surfaceContainerHighest.withValues(alpha: .5),
                    child: InkWell(
                      onTap: () => _open(banner),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (banner.coverUrl != null)
                            NetworkImgLayer(
                              src: banner.coverUrl!.toString(),
                              fit: BoxFit.cover,
                              borderRadius: BorderRadius.zero,
                            ),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: .72),
                                ],
                                stops: const [.38, 1],
                              ),
                            ),
                          ),
                          Positioned(
                            left: 18,
                            right: 18,
                            bottom: 14,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  banner.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                                if (banner.subtitle.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    banner.subtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: Colors.white.withValues(
                                            alpha: .85,
                                          ),
                                        ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          if (widget.banners.length > 1) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < widget.banners.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _index ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == _index
                          ? colors.primary
                          : colors.onSurfaceVariant.withValues(alpha: .35),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _HomeEditorSection extends StatelessWidget {
  const _HomeEditorSection({
    required this.section,
    required this.heroOccurrencePrefix,
    required this.heroOccurrence,
    required this.onResourceTap,
  });

  final HomeSection section;
  final String heroOccurrencePrefix;
  final String? heroOccurrence;
  final void Function(CommunityResource resource, int index) onResourceTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return PageContainer(
      padding: const EdgeInsets.fromLTRB(
        StyleConstants.pagePadding,
        8,
        StyleConstants.pagePadding,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.name,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          if (section.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              section.description,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 12),
          for (var index = 0; index < section.cards.length; index++) ...[
            if (section.cards[index].resource != null)
              _WideResourceCard(
                card: section.cards[index].resource!,
                heroEnabled: heroOccurrence == '$heroOccurrencePrefix:$index',
                onResourceTap: (resource) => onResourceTap(resource, index),
              )
            else if (section.cards[index].blog != null)
              _HomeBlogCard(
                card: section.cards[index].blog!,
                heroEnabled: false,
              ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _HomeBlogSection extends StatelessWidget {
  const _HomeBlogSection({required this.blogs});

  final List<BlogCard> blogs;

  @override
  Widget build(BuildContext context) => PageContainer(
    padding: const EdgeInsets.fromLTRB(
      StyleConstants.pagePadding,
      8,
      StyleConstants.pagePadding,
      0,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.resourceHomeUpdates,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        for (final blog in blogs) ...[
          _HomeBlogCard(card: blog, heroEnabled: true),
          const SizedBox(height: 12),
        ],
      ],
    ),
  );
}

CommunityResourceType _homeCardKind(String kind) => switch (kind) {
  'zepp_app' => CommunityResourceType.miniprogram,
  'watchface' => CommunityResourceType.watchface,
  'firmware' => CommunityResourceType.firmware,
  'canopus' => CommunityResourceType.canopus,
  _ => CommunityResourceType.quickApp,
};

class _WideResourceCard extends StatelessWidget {
  const _WideResourceCard({
    required this.card,
    this.heroEnabled = true,
    this.onResourceTap,
  });

  final HomeResourceCard card;
  final bool heroEnabled;
  final ValueChanged<CommunityResource>? onResourceTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final resource = CommunityResource(
      ref: ResourceRef(source: CommunitySourceId.oronBox, id: card.id),
      name: card.name,
      type: _homeCardKind(card.kind),
      paidType: card.paidType,
      authors: [
        if (card.owner.isNotEmpty) CommunityResourceAuthor(name: card.owner),
      ],
      supportedDevices: const {},
      iconUrl: card.iconUrl,
      coverUrl: card.coverUrl,
      summary: card.summary,
    );
    final imageUrl = card.iconUrl ?? card.coverUrl;
    final imageRole = card.iconUrl != null ? 'icon' : 'cover';
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: colors.surfaceContainerHighest.withValues(alpha: .5),
      child: InkWell(
        onTap: () {
          if (onResourceTap != null) {
            onResourceTap!(resource);
          } else {
            context.push('/resources/detail/${card.id}', extra: resource);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (imageUrl != null)
                    HeroMode(
                      enabled: heroEnabled,
                      child: ResourceMediaHero(
                        tag: resourceMediaHeroTag(resource.ref, imageRole),
                        url: imageUrl.toString(),
                        width: 56,
                        height: 56,
                        style: const ResourceMediaHeroStyle(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                      ),
                    )
                  else
                    NetworkImgLayer(
                      src: null,
                      width: 56,
                      height: 56,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          card.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        if (card.summary.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            card.summary,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colors.onSurfaceVariant),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _ResourceLabel(
                    label: _typeLabel(
                      l10n,
                      _homeCardKind(card.kind),
                      source: CommunitySourceId.oronBox,
                    ),
                    color: colors.primary,
                  ),
                  if (card.paidType != CommunityPaidType.free) ...[
                    const SizedBox(width: 8),
                    _ResourceLabel(
                      label: _paidLabel(l10n, card.paidType),
                      color: colors.tertiary,
                    ),
                  ],
                  if (card.owner.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Icon(
                      Icons.person_outline,
                      size: 14,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        card.owner,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: colors.onSurfaceVariant),
                      ),
                    ),
                  ],
                ],
              ),
              if (card.previews.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    for (var i = 0; i < card.previews.take(3).length; i++) ...[
                      Expanded(
                        child: AspectRatio(
                          aspectRatio: 16 / 10,
                          child: NetworkImgLayer(
                            src: card.previews[i].toString(),
                            fit: BoxFit.cover,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      if (i < card.previews.take(3).length - 1)
                        const SizedBox(width: 8),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeBlogCard extends StatelessWidget {
  const _HomeBlogCard({required this.card, required this.heroEnabled});

  final BlogCard card;
  final bool heroEnabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: colors.surfaceContainerHighest.withValues(alpha: .5),
      child: InkWell(
        onTap: () => context.push('/resources/blog/${card.slug}', extra: card),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final height = math.min(constraints.maxWidth * 9 / 21, 240.0);
                return card.coverUrl != null
                    ? HeroMode(
                        enabled: heroEnabled,
                        child: ResourceMediaHero(
                          tag: 'blog-cover-${card.slug}',
                          url: card.coverUrl!.toString(),
                          width: double.infinity,
                          height: height,
                          style: const ResourceMediaHeroStyle(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                          fit: BoxFit.cover,
                        ),
                      )
                    : Container(
                        height: height,
                        color: context.appSelectionContainer.withValues(
                          alpha: .35,
                        ),
                      );
              },
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ResourceLabel(
                    label: blogTypeLabel(l10n, card.type),
                    color: colors.primary,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    card.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (card.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      card.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: colors.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
