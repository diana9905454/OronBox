import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/widgets/sys_app_bar.dart';
import 'package:oronbox/src/core/constants/style_constants.dart';
import 'package:oronbox/src/core/providers/app_settings_providers.dart';
import 'package:oronbox/src/data/bandbbs/bandbbs_resource_provider.dart';
import 'package:oronbox/src/features/accounts/application/host_accounts.dart';
import 'package:oronbox/src/features/messages/application/message_center.dart';
import 'package:oronbox/src/features/resources/application/resource_catalog_providers.dart';
import 'package:oronbox/src/features/resources/controllers/resource_filter_controller.dart';
import 'package:oronbox/src/features/resources/pages/resource_home_view.dart';
import 'package:oronbox/src/features/resources/pages/resource_library_view.dart';

export 'package:oronbox/src/features/resources/pages/resource_library_view.dart'
    show enabledCommunitySources;

class ResourcesPage extends ConsumerWidget {
  const ResourcesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final mode = ref.watch(resourceModeControllerProvider);
    final clean = ref.watch(appSettingsProvider).clean;
    final showHome = clean.homeFeedEnabled;
    final showExplore = clean.resourceLibraryEnabled && clean.hasResourceSource;
    final showCreator = clean.creatorEnabled;
    if (!showHome && !showExplore) {
      return Scaffold(
        appBar: SysAppBar(title: Text(l10n.exploreTab)),
        body: Center(child: Text(l10n.cleanModeDescription)),
      );
    }
    final displayMode = switch (mode) {
      ResourceMode.home when showHome => ResourceMode.home,
      ResourceMode.library when showExplore => ResourceMode.library,
      _ when showHome => ResourceMode.home,
      _ => ResourceMode.library,
    };
    return Scaffold(
      appBar: SysAppBar(
        title: Text(l10n.exploreTab),
        actions: [
          if (displayMode == ResourceMode.library) const CommunitySourceMenu(),
          IconButton(
            tooltip: l10n.refresh,
            icon: const Icon(Icons.refresh),
            onPressed: () {
              final catalog = ref.read(communityCatalogProvider);
              if (catalog is BandBbsCatalog) {
                catalog.clearCategoryCache();
                ref.invalidate(bandbbsCategoryTreeProvider);
              }
              ref.invalidate(communityCatalogDevicesProvider);
              ref.read(resourceRefreshProvider.notifier).refresh();
            },
          ),
          if (clean.inboxEnabled) ...[
            if (ref.watch(
              hostAccountsProvider.select((s) => s.bandbbs.isSignedIn),
            ))
              _InboxAction(
                unread: ref.watch(messageCenterProvider).value?.unread ?? 0,
              ),
          ],
        ],
      ),
      body: Column(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: StyleConstants.pageMaxWidth,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: StyleConstants.pagePadding,
                  vertical: 8,
                ),
                child: SegmentedButton<ResourceMode>(
                  showSelectedIcon: false,
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    side: WidgetStateProperty.all(BorderSide.none),
                    backgroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return Theme.of(context).colorScheme.secondaryContainer;
                      }
                      return Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.5);
                    }),
                  ),
                  segments: [
                    if (showHome)
                      ButtonSegment(
                        value: ResourceMode.home,
                        label: Text(
                          l10n.homeTab,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                        ),
                        icon: const Icon(Icons.home_outlined),
                      ),
                    if (showExplore)
                      ButtonSegment(
                        value: ResourceMode.library,
                        label: Text(
                          l10n.resourceLibrary,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                        ),
                        icon: const Icon(Icons.library_books_outlined),
                      ),
                    if (showCreator)
                      ButtonSegment(
                        value: ResourceMode.creator,
                        label: Text(
                          l10n.creatorCenter,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                        ),
                        icon: const Icon(Icons.create_outlined),
                      ),
                  ],
                  selected: {displayMode},
                  onSelectionChanged: (value) {
                    final selected = value.first;
                    if (selected == ResourceMode.creator) {
                      context.push('/resources/creator');
                      return;
                    }
                    ref
                        .read(resourceModeControllerProvider.notifier)
                        .setMode(selected);
                  },
                ),
              ),
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: switch (displayMode) {
                ResourceMode.home => const ResourceHomeView(
                  key: ValueKey('home'),
                ),
                _ => const ResourceLibraryView(key: ValueKey('library')),
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Keeps the resource card Hero enabled until a pushed detail route has
/// finished its reverse transition.
class ResourceRouteObserver extends RouteObserver<ModalRoute<dynamic>> {
  Route<dynamic>? _lastPoppedRoute;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _lastPoppedRoute = route;
    super.didPop(route, previousRoute);
  }

  Route<dynamic>? takeLastPoppedRoute() {
    final route = _lastPoppedRoute;
    _lastPoppedRoute = null;
    return route;
  }
}

final resourceRouteObserver = ResourceRouteObserver();

class _InboxAction extends StatelessWidget {
  const _InboxAction({required this.unread});

  final int unread;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: AppLocalizations.of(context)!.inbox,
    onPressed: () => context.push('/inbox'),
    icon: unread > 0
        ? Badge(
            label: Text('$unread'),
            child: const Icon(Icons.notifications_outlined),
          )
        : const Icon(Icons.notifications_outlined),
  );
}
