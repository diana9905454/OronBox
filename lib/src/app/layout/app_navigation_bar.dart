import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/core/providers/app_settings_providers.dart';
import 'package:oronbox/src/core/utils/layout.dart';
import 'package:oronbox/src/features/resources/services/download_queue_notifier.dart';
import 'package:oronbox/src/features/resources/services/install_queue_notifier.dart';

final queueDoneAtProvider = NotifierProvider<QueueDoneNotifier, DateTime?>(
  QueueDoneNotifier.new,
);

class QueueDoneNotifier extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;
  void mark() => state = DateTime.now();
  void clear() => state = null;
}

final queueDoneVersionProvider =
    NotifierProvider<QueueDoneVersionNotifier, int>(
      QueueDoneVersionNotifier.new,
    );

class QueueDoneVersionNotifier extends Notifier<int> {
  @override
  int build() => 0;
  int next() {
    state = state + 1;
    return state;
  }
}

void markQueueDone(WidgetRef ref) {
  final version = ref.read(queueDoneVersionProvider.notifier).next();
  ref.read(queueDoneAtProvider.notifier).mark();
  Timer(const Duration(seconds: 2), () {
    if (ref.read(queueDoneVersionProvider) == version) {
      ref.read(queueDoneAtProvider.notifier).clear();
    }
  });
}

class QueueNavState {
  const QueueNavState({
    this.active = 0,
    this.pending = 0,
    this.total = 0,
    this.progress = 0,
    this.installing = false,
    this.hasError = false,
  });
  final int active;
  final int pending;
  final int total;
  final double progress;
  final bool installing;
  final bool hasError;
}

QueueNavState queueNavCounts(WidgetRef ref) {
  return queueNavState(
    ref.watch(downloadQueueProvider),
    ref.watch(installQueueProvider).tasks,
  );
}

QueueNavState queueNavState(List<ResourceTask> dl, List<InstallTask> il) {
  var active = 0, pending = 0, total = 0;
  var installing = false, hasError = false;
  double progress = 0;
  bool hasActive = false;
  for (final t in dl) {
    if (t.status == ResourceTaskStatus.completed) continue;
    total++;
    if (t.status == ResourceTaskStatus.failed) hasError = true;
    if (t.status == ResourceTaskStatus.downloading ||
        t.status == ResourceTaskStatus.installing) {
      active++;
      if (!hasActive) {
        progress = t.progress;
        hasActive = true;
      }
    } else if (t.status == ResourceTaskStatus.pending) {
      pending++;
    }
  }
  for (final t in il) {
    if (t.status == ResourceTaskStatus.completed) continue;
    total++;
    if (t.status == ResourceTaskStatus.failed) hasError = true;
    if (t.status == ResourceTaskStatus.downloading ||
        t.status == ResourceTaskStatus.installing) {
      active++;
      installing = true;
      if (!hasActive) {
        progress = t.progress;
        hasActive = true;
      }
    } else if (t.status == ResourceTaskStatus.pending) {
      pending++;
    }
  }
  return QueueNavState(
    active: active,
    pending: pending,
    total: total,
    progress: progress,
    installing: installing,
    hasError: hasError,
  );
}

List<int> visibleBranchIndices({
  required bool showExplore,
  required bool showPlugins,
}) => [if (showExplore) 0, 1, 2, if (showPlugins) 3, 4];

Widget queueNavIcon(
  BuildContext context,
  QueueNavState queue,
  DateTime? doneAt,
) {
  if (queue.total == 0) {
    if (doneAt != null) {
      return Icon(Icons.check, color: Theme.of(context).colorScheme.primary);
    }
    return const Icon(Icons.format_list_bulleted);
  }
  if (queue.active == 0 && queue.hasError) {
    return Icon(
      Icons.priority_high,
      color: Theme.of(context).colorScheme.error,
    );
  }
  if (queue.active == 0) return const Icon(Icons.format_list_bulleted);
  final scheme = Theme.of(context).colorScheme;
  final color = queue.installing ? scheme.primary : scheme.secondary;
  return SizedBox.square(
    dimension: 24,
    child: Stack(
      alignment: Alignment.center,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween<double>(end: queue.progress),
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          builder: (_, v, _) => CircularProgressIndicator(
            value: v > 0 ? v : null,
            strokeWidth: 2.5,
            color: color,
          ),
        ),
        Text(
          '${queue.total}',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    ),
  );
}

NavigationDestination bottomNavDestination(
  BuildContext context,
  AppLocalizations l10n,
  QueueNavState queue,
  DateTime? doneAt,
  int branch,
) => switch (branch) {
  0 => NavigationDestination(
    selectedIcon: const Icon(Icons.apps),
    icon: const Icon(Icons.apps_outlined),
    label: l10n.exploreTab,
  ),
  1 => NavigationDestination(
    selectedIcon: const Icon(Icons.watch),
    icon: const Icon(Icons.watch_outlined),
    label: l10n.devicesTab,
  ),
  2 => NavigationDestination(
    selectedIcon: queueNavIcon(context, queue, doneAt),
    icon: queueNavIcon(context, queue, doneAt),
    label: l10n.settingsQueue,
  ),
  3 => NavigationDestination(
    selectedIcon: const Icon(Icons.extension),
    icon: const Icon(Icons.extension_outlined),
    label: l10n.pluginsTab,
  ),
  _ => NavigationDestination(
    selectedIcon: const Icon(Icons.settings),
    icon: const Icon(Icons.settings_outlined),
    label: l10n.settingsTab,
  ),
};

class ShellBranchIndex extends InheritedWidget {
  const ShellBranchIndex({
    super.key,
    required this.index,
    required super.child,
  });

  final int index;

  static int? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellBranchIndex>()?.index;

  @override
  bool updateShouldNotify(ShellBranchIndex oldWidget) =>
      index != oldWidget.index;
}

class AppBottomNavigationBar extends ConsumerWidget {
  const AppBottomNavigationBar({
    super.key,
    required this.currentBranch,
    required this.onBranchSelected,
  });

  final int currentBranch;
  final ValueChanged<int> onBranchSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final queue = queueNavCounts(ref);
    final doneAt = ref.watch(queueDoneAtProvider);
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
    // Track the shell's live index so the newly shown page's bar animates the
    // indicator from the previous branch instead of appearing pre-selected.
    final activeBranch = ShellBranchIndex.maybeOf(context) ?? currentBranch;
    final selectedIndex = branchIndices.indexOf(activeBranch);
    // 鸿蒙端底部导航栏加沉浸光感（毛玻璃 + 顶部高光渐变）。
    if (defaultTargetPlatform == TargetPlatform.ohos) {
      return _OhosImmersiveNavigationBar(
        destinations: [
          for (final index in branchIndices)
            bottomNavDestination(context, l10n, queue, doneAt, index),
        ],
        selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
        onDestinationSelected: (index) {
          final branch = branchIndices[index];
          if (branch != activeBranch) {
            StatefulNavigationShell.of(context).goBranch(branch);
          }
        },
      );
    }
    return NavigationBar(
      destinations: [
        for (final index in branchIndices)
          bottomNavDestination(context, l10n, queue, doneAt, index),
      ],
      selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
      onDestinationSelected: (index) {
        final branch = branchIndices[index];
        if (branch != activeBranch) {
          onBranchSelected(branch);
        }
      },
    );
  }
}

/// 鸿蒙沉浸式底部导航栏：半透明毛玻璃背景 + 顶部柔和高光，营造 HarmonyOS
/// 标志性的「光感」质感。
class _OhosImmersiveNavigationBar extends StatelessWidget {
  const _OhosImmersiveNavigationBar({
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final List<NavigationDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: 0.72),
            border: Border(
              top: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.4),
                width: 0.5,
              ),
            ),
          ),
          child: Stack(
            children: [
              // 顶部高光渐变：HarmonyOS 导航栏顶部的柔和光晕。
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: 1.5,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          scheme.primary.withValues(alpha: 0.0),
                          scheme.primary.withValues(alpha: 0.35),
                          scheme.primary.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              NavigationBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                height: 68,
                destinations: destinations,
                selectedIndex: selectedIndex,
                onDestinationSelected: onDestinationSelected,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PrimaryBranchScaffold extends StatelessWidget {
  const PrimaryBranchScaffold({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (useWideLayout(MediaQuery.sizeOf(context).width)) return child;
    return Scaffold(body: child);
  }
}
