import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/layout/app_navigation_bar.dart';
import 'package:oronbox/src/core/providers/app_settings_providers.dart';
import 'package:oronbox/src/core/services/status_surface_bridge.dart';
import 'package:oronbox/src/core/utils/layout.dart';
import 'package:oronbox/src/features/resources/services/download_queue_notifier.dart';
import 'package:oronbox/src/features/resources/services/install_queue_notifier.dart';
import 'package:oronbox/src/features/messages/widgets/announcement_gate.dart';

bool _hasPending(List<ResourceTask> dl, List<InstallTask> il) =>
    dl.any((t) => t.status != ResourceTaskStatus.completed) ||
    il.any((t) => t.status != ResourceTaskStatus.completed);

class AppScaffold extends ConsumerWidget {
  const AppScaffold({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    ref.listen(downloadQueueProvider, (prev, _) {
      if (prev != null) {
        final il = ref.read(installQueueProvider).tasks;
        if (_hasPending(prev, il) &&
            !_hasPending(ref.read(downloadQueueProvider), il)) {
          markQueueDone(ref);
        }
      }
      _syncQueueActivity(ref, l10n);
    });
    ref.listen(installQueueProvider, (prev, _) {
      if (prev != null) {
        final dl = ref.read(downloadQueueProvider);
        if (_hasPending(dl, prev.tasks) &&
            !_hasPending(dl, ref.read(installQueueProvider).tasks)) {
          markQueueDone(ref);
        }
      }
      _syncQueueActivity(ref, l10n);
    });
    ref.listen(
      appSettingsProvider.select(
        (settings) => settings.realtimeActivityNotification,
      ),
      (_, _) => _syncQueueActivity(ref, l10n),
    );

    final doneAt = ref.watch(queueDoneAtProvider);
    final width = MediaQuery.sizeOf(context).width;
    final queue = queueNavCounts(ref);

    final showExplore = ref.watch(
      appSettingsProvider.select((state) => state.clean.exploreEnabled),
    );
    final showPlugins = ref.watch(
      appSettingsProvider.select((state) => state.clean.pluginsEnabled),
    );
    final branchIndices = visibleBranchIndices(
      showExplore: showExplore,
      showPlugins: showPlugins,
    );
    if (!branchIndices.contains(navigationShell.currentIndex)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        navigationShell.goBranch(branchIndices.first);
      });
    }
    final railPosition = ref.watch(
      appSettingsProvider.select((state) => state.wideNavigationRailPosition),
    );

    if (useWideLayout(width)) {
      return _buildSideMenu(
        context,
        l10n,
        queue,
        doneAt,
        railPosition,
        branchIndices,
      );
    }
    return ShellBranchIndex(
      index: navigationShell.currentIndex,
      child: Scaffold(
        body: Container(
          color: Theme.of(context).colorScheme.surfaceContainer,
          child: AnnouncementGate(child: navigationShell),
        ),
        bottomNavigationBar: AppBottomNavigationBar(
          currentBranch: navigationShell.currentIndex,
          onBranchSelected: (branch) => navigationShell.goBranch(branch),
        ),
      ),
    );
  }

  Widget _buildSideMenu(
    BuildContext context,
    AppLocalizations l10n,
    QueueNavState queue,
    DateTime? doneAt,
    WideNavigationRailPosition railPosition,
    List<int> branchIndices,
  ) {
    final destinations = branchIndices
        .map((index) => _railDestination(context, l10n, queue, doneAt, index))
        .toList(growable: false);
    final selectedIndex = branchIndices.indexOf(navigationShell.currentIndex);
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      body: Row(
        children: [
          SizedBox(
            width: 80,
            child: _WideNavigationRail(
              position: railPosition,
              destinations: destinations,
              selectedIndex: selectedIndex < 0 ? null : selectedIndex,
              onDestinationSelected: (index) {
                final branch = branchIndices[index];
                if (branch != navigationShell.currentIndex) {
                  navigationShell.goBranch(branch);
                }
              },
            ),
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(28),
                  bottomLeft: Radius.circular(28),
                ),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(28),
                  bottomLeft: Radius.circular(28),
                ),
                child: AnnouncementGate(child: navigationShell),
              ),
            ),
          ),
        ],
      ),
    );
  }

  NavigationRailDestination _railDestination(
    BuildContext context,
    AppLocalizations l10n,
    QueueNavState queue,
    DateTime? doneAt,
    int branch,
  ) => switch (branch) {
    0 => NavigationRailDestination(
      selectedIcon: const Icon(Icons.apps),
      icon: const Icon(Icons.apps_outlined),
      label: Text(l10n.exploreTab),
    ),
    1 => NavigationRailDestination(
      selectedIcon: const Icon(Icons.watch),
      icon: const Icon(Icons.watch_outlined),
      label: Text(l10n.devicesTab),
    ),
    2 => () {
      final icon = queueNavIcon(context, queue, doneAt);
      return NavigationRailDestination(
        selectedIcon: icon,
        icon: icon,
        label: Text(l10n.settingsQueue),
      );
    }(),
    3 => NavigationRailDestination(
      selectedIcon: const Icon(Icons.extension),
      icon: const Icon(Icons.extension_outlined),
      label: Text(l10n.pluginsTab),
    ),
    _ => NavigationRailDestination(
      selectedIcon: const Icon(Icons.settings),
      icon: const Icon(Icons.settings_outlined),
      label: Text(l10n.settingsTab),
    ),
  };
}

void _syncQueueActivity(WidgetRef ref, AppLocalizations l10n) {
  final settings = ref.read(appSettingsProvider);
  if (!settings.realtimeActivityNotification) {
    unawaited(clearQueueActivitySurface());
    return;
  }

  final queue = queueNavState(
    ref.read(downloadQueueProvider),
    ref.read(installQueueProvider).tasks,
  );
  if (queue.total == 0) {
    unawaited(clearQueueActivitySurface());
    return;
  }

  final downloads = ref.read(downloadQueueProvider);
  final installs = ref.read(installQueueProvider).tasks;
  final currentName =
      downloads
          .where((task) => task.status != ResourceTaskStatus.completed)
          .map((task) => task.title)
          .firstOrNull ??
      installs
          .where((task) => task.status != ResourceTaskStatus.completed)
          .map((task) => task.name)
          .firstOrNull;
  final activeDownload = downloads
      .where(
        (task) =>
            task.status == ResourceTaskStatus.downloading ||
            task.status == ResourceTaskStatus.installing,
      )
      .firstOrNull;
  final activeInstall = installs
      .where(
        (task) =>
            task.status == ResourceTaskStatus.downloading ||
            task.status == ResourceTaskStatus.installing,
      )
      .firstOrNull;
  final activeStatus = activeDownload?.status ?? activeInstall?.status;
  final active = activeDownload != null || activeInstall != null;
  if (!active) {
    // A held queue (for example with automatic installation disabled) is not
    // a live activity. Do not leave a progress notification in the shade
    // while the user is waiting to press Start.
    unawaited(clearQueueActivitySurface());
    return;
  }
  final progress =
      ((activeDownload?.progress ?? activeInstall?.progress ?? 0) * 100)
          .round()
          .clamp(0, 100);
  final status = switch (activeStatus) {
    ResourceTaskStatus.downloading => l10n.queueStatusDownloading('$progress'),
    ResourceTaskStatus.installing => l10n.queueStatusInstalling('$progress'),
    ResourceTaskStatus.failed => l10n.queueStatusFailed,
    _ => l10n.queueStatusPending,
  };
  unawaited(
    updateQueueActivitySurface({
      'title': currentName ?? l10n.settingsQueue,
      'status': status,
      'progress': progress,
      'active': active,
      'total': queue.total,
      'pending': queue.pending,
      'installing': queue.installing,
      'hasError': queue.hasError,
    }),
  );
}

class _WideNavigationRail extends StatelessWidget {
  const _WideNavigationRail({
    required this.position,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final WideNavigationRailPosition position;
  final List<NavigationRailDestination> destinations;
  final int? selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainer;
    if (position != WideNavigationRailPosition.split) {
      return NavigationRail(
        backgroundColor: color,
        groupAlignment: switch (position) {
          WideNavigationRailPosition.center => 0,
          _ => 1,
        },
        labelType: NavigationRailLabelType.selected,
        destinations: destinations,
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
      );
    }
    final primaryCount = destinations.length - 1;
    return Material(
      color: color,
      child: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: NavigationRail(
                backgroundColor: color,
                groupAlignment: 0,
                labelType: NavigationRailLabelType.selected,
                destinations: destinations
                    .take(primaryCount)
                    .toList(growable: false),
                selectedIndex:
                    selectedIndex != null && selectedIndex! < primaryCount
                    ? selectedIndex
                    : null,
                onDestinationSelected: onDestinationSelected,
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SizedBox(
                height: 96,
                child: NavigationRail(
                  backgroundColor: color,
                  groupAlignment: 0,
                  labelType: NavigationRailLabelType.selected,
                  destinations: [destinations.last],
                  selectedIndex: selectedIndex == primaryCount ? 0 : null,
                  onDestinationSelected: (_) =>
                      onDestinationSelected(primaryCount),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
