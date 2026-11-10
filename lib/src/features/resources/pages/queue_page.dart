import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/utils/error_localization.dart';
import 'package:oronbox/src/app/widgets/app_state_view.dart';
import 'package:oronbox/src/app/widgets/page_container.dart';
import 'package:oronbox/src/app/widgets/network_img_layer.dart';
import 'package:oronbox/src/app/widgets/smooth_linear_progress_indicator.dart';
import 'package:oronbox/src/app/widgets/sys_app_bar.dart';
import 'package:oronbox/src/core/constants/style_constants.dart';
import 'package:oronbox/src/core/utils/layout.dart';
import 'package:oronbox/src/host/tasks/task_models.dart';
import 'package:oronbox/src/host/tasks/task_monitor.dart';
import 'package:oronbox/src/host/application_host_provider.dart';
import 'package:oronbox/src/features/resources/services/download_queue_notifier.dart';
import 'package:oronbox/src/features/resources/domain/community_resource.dart';
import 'package:oronbox/src/features/resources/services/install_queue_notifier.dart';
import 'package:oronbox/src/features/resources/services/resource_task_status.dart';

class QueuePage extends ConsumerWidget {
  const QueuePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: SysAppBar(title: Text(l10n.settingsQueue)),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = useWideLayout(constraints.maxWidth);
          final downloadList = const _DownloadQueuePanel();
          final installList = const _InstallQueuePanel();

          return PageContainer(
            padding: const EdgeInsets.fromLTRB(
              StyleConstants.pagePadding,
              8,
              StyleConstants.pagePadding,
              8,
            ),
            child: isWide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _PanelWrapper(child: downloadList)),
                      Container(
                        width: 1,
                        margin: const EdgeInsets.symmetric(vertical: 12),
                        color: Theme.of(context).colorScheme.outlineVariant
                            .withValues(alpha: 0.5),
                      ),
                      Expanded(child: _PanelWrapper(child: installList)),
                    ],
                  )
                : Column(
                    children: [
                      Expanded(child: downloadList),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Divider(height: 1),
                      ),
                      Expanded(child: installList),
                    ],
                  ),
          );
        },
      ),
    );
  }
}

class _PanelWrapper extends StatelessWidget {
  const _PanelWrapper({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      child: child,
    );
  }
}

class _DownloadQueuePanel extends ConsumerWidget {
  const _DownloadQueuePanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final tasks = ref.watch(downloadQueueProvider);
    final notifier = ref.read(downloadQueueProvider.notifier);

    return _QueuePanel(
      title: l10n.downloadQueueTitle,
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (tasks.isNotEmpty)
            IconButton(
              onPressed: () => notifier.clearTerminal(),
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.queueClear,
            ),
        ],
      ),
      emptyText: l10n.downloadQueueEmpty,
      children: [
        for (final task in tasks)
          _QueueTile(
            key: ValueKey('download-${task.id}'),
            icon: Icons.downloading,
            iconUrl: task.resource.iconUrl?.toString(),
            title: task.title,
            subtitle: _downloadTaskDescription(l10n, task),
            status: task.status,
            progress: task.progress,
            error: task.error,
            onRemove: () => notifier.remove(task.id),
            onRetry: () => notifier.retry(task.id),
          ),
      ],
    );
  }
}

class _InstallQueuePanel extends ConsumerWidget {
  const _InstallQueuePanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(installQueueProvider);
    final notifier = ref.read(installQueueProvider.notifier);
    final hostTasks = (ref.watch(hostTasksProvider).value ?? const [])
        .where(
          (task) =>
              task.method != 'install.local' &&
              task.method != 'resource.download',
        )
        .toList();
    final running = state.runStatus == QueueRunStatus.running;
    final stopping = state.runStatus == QueueRunStatus.stopping;
    final canStart = state.hasRunnableTasks && !running && !stopping;

    return _QueuePanel(
      title: l10n.installQueueTitle,
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (state.tasks.isNotEmpty || hostTasks.isNotEmpty)
            IconButton(
              onPressed: () {
                notifier.clearTerminal();
                for (final task in hostTasks.where((task) => task.isTerminal)) {
                  unawaited(
                    removeHostTask(ref.read(applicationHostProvider), task.id),
                  );
                }
              },
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.queueClear,
            ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: running
                ? notifier.pause
                : canStart
                ? notifier.start
                : null,
            icon: Icon(running ? Icons.pause : Icons.play_arrow),
            tooltip: running ? l10n.queuePause : l10n.queueStart,
          ),
        ],
      ),
      emptyText: l10n.installQueueEmpty,
      children: [
        for (final task in hostTasks)
          _QueueTile(
            key: ValueKey('host-${task.id}'),
            icon: Icons.dns_outlined,
            title: _hostTaskTitle(task),
            subtitle: 'Host · ${task.method}',
            status: _hostTaskStatus(task),
            progress: task.progress,
            error: task.error,
            onRemove: () => unawaited(
              task.isTerminal
                  ? removeHostTask(ref.read(applicationHostProvider), task.id)
                  : cancelHostTask(ref.read(applicationHostProvider), task.id),
            ),
            onRetry: _hostTaskStatus(task) == ResourceTaskStatus.failed
                ? () => unawaited(
                    retryHostTask(ref.read(applicationHostProvider), task.id),
                  )
                : null,
          ),
        for (final task in state.tasks)
          _QueueTile(
            key: ValueKey('install-${task.id}'),
            icon: _installIcon(task.type),
            iconUrl: task.resource?.iconUrl?.toString(),
            title: task.name,
            subtitle: _installTaskDescription(l10n, task),
            status: task.status,
            progress: task.progress,
            error: task.error,
            onRemove: () => notifier.remove(task.id),
            onRetry: task.status == ResourceTaskStatus.failed
                ? () => notifier.retry(task.id)
                : null,
            onFixWatchfaceId:
                task.type == LocalDeviceInstallType.watchface &&
                    (task.status == ResourceTaskStatus.pending ||
                        task.status == ResourceTaskStatus.failed)
                ? () => _promptWatchfaceId(context, ref, task)
                : null,
          ),
      ],
    );
  }

  Future<void> _promptWatchfaceId(
    BuildContext context,
    WidgetRef ref,
    InstallTask task,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final currentIdentifier = task.identifier ?? '';
    final controller = TextEditingController(
      text: RegExp(r'^[0-9]{1,12}$').hasMatch(currentIdentifier)
          ? currentIdentifier
          : '',
    );
    try {
      final identifier = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.installQueueFixWatchfaceId),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(12),
            ],
            decoration: InputDecoration(
              hintText: l10n.installQueueFixWatchfaceIdHint,
            ),
            onSubmitted: (value) {
              final normalized = value.trim();
              if (_isValidWatchfaceIdOverride(normalized)) {
                Navigator.of(context).pop(normalized);
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.cancel),
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) => FilledButton(
                onPressed: _isValidWatchfaceIdOverride(value.text)
                    ? () => Navigator.of(context).pop(value.text.trim())
                    : null,
                child: Text(l10n.save),
              ),
            ),
          ],
        ),
      );
      if (identifier != null) {
        await ref
            .read(installQueueProvider.notifier)
            .reinstallWatchface(
              task.id,
              identifier: identifier,
              startImmediately: task.status == ResourceTaskStatus.failed,
            );
      }
    } finally {
      controller.dispose();
    }
  }
}

bool _isValidWatchfaceIdOverride(String value) =>
    RegExp(r'^[0-9]{1,12}$').hasMatch(value.trim()) &&
    !RegExp(r'^[0]+$').hasMatch(value.trim());

class _QueuePanel extends StatelessWidget {
  const _QueuePanel({
    required this.title,
    required this.emptyText,
    required this.children,
    this.action,
  });

  final String title;
  final String emptyText;
  final List<Widget> children;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (action != null) action!,
            ],
          ),
        ),
        Expanded(
          child: children.isEmpty
              ? EmptyStateView(
                  compact: true,
                  icon: Icons.checklist_outlined,
                  title: emptyText,
                )
              : ListView.separated(
                  padding: EdgeInsets.only(
                    bottom: bottomContentPadding(context, extra: 16),
                  ),
                  itemCount: children.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) => children[index],
                ),
        ),
      ],
    );
  }
}

class _QueueTile extends StatelessWidget {
  const _QueueTile({
    super.key,
    required this.icon,
    this.iconUrl,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.progress,
    this.error,
    required this.onRemove,
    this.onRetry,
    this.onFixWatchfaceId,
  });

  final IconData icon;
  final String? iconUrl;
  final String title;
  final String subtitle;
  final ResourceTaskStatus status;
  final double progress;
  final String? error;
  final VoidCallback onRemove;
  final VoidCallback? onRetry;

  /// Offered on failed watchface installs to reinstall with a custom id.
  final VoidCallback? onFixWatchfaceId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final active =
        status == ResourceTaskStatus.downloading ||
        status == ResourceTaskStatus.installing;

    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        leading: iconUrl?.isNotEmpty == true
            ? NetworkImgLayer(
                src: iconUrl,
                width: 40,
                height: 40,
                type: 'resource',
                memCacheWidth: 96,
                memCacheHeight: 96,
              )
            : Icon(
                _statusIcon(status, icon),
                color: status == ResourceTaskStatus.failed
                    ? colorScheme.error
                    : colorScheme.onSurfaceVariant,
              ),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
            if (active || status == ResourceTaskStatus.completed) ...[
              const SizedBox(height: 8),
              SmoothLinearProgressIndicator(
                value: progress > 0 ? progress : null,
              ),
              const SizedBox(height: 2),
              Text(
                _statusLabel(l10n, status, progress),
                style: textTheme.bodySmall,
              ),
            ],
            if (error != null && error!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                localizedErrorMessage(l10n, error),
                style: textTheme.bodySmall?.copyWith(color: colorScheme.error),
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onFixWatchfaceId != null)
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: l10n.installQueueFixWatchfaceId,
                onPressed: onFixWatchfaceId,
              ),
            if (onRetry != null)
              IconButton(icon: const Icon(Icons.refresh), onPressed: onRetry),
            IconButton(icon: const Icon(Icons.close), onPressed: onRemove),
          ],
        ),
      ),
    );
  }
}

String _hostTaskTitle(HostTaskView task) {
  final path = task.path;
  if (path == null || path.isEmpty) return task.method;
  return path.split(RegExp(r'[/\\]')).last;
}

ResourceTaskStatus _hostTaskStatus(HostTaskView task) =>
    resourceTaskStatusFromDaemon(
      task.status,
      activity: ResourceTaskActivity.install,
    );

IconData _installIcon(LocalDeviceInstallType type) {
  return switch (type) {
    LocalDeviceInstallType.app => Icons.apps_outlined,
    LocalDeviceInstallType.watchface => Icons.watch_outlined,
    LocalDeviceInstallType.firmware => Icons.memory_outlined,
  };
}

IconData _statusIcon(ResourceTaskStatus status, IconData fallback) {
  return switch (status) {
    ResourceTaskStatus.pending => fallback,
    ResourceTaskStatus.downloading => Icons.downloading,
    ResourceTaskStatus.installing => Icons.memory,
    ResourceTaskStatus.completed => Icons.check_circle_outline,
    ResourceTaskStatus.failed => Icons.error_outline,
  };
}

String _installTaskDescription(AppLocalizations l10n, InstallTask task) {
  if (task.resource != null) {
    return resourceTargetDeviceDisplayName(task.description);
  }
  return switch (task.description) {
    'Read failed' => l10n.installQueueReadFailed,
    'Unsupported file' => l10n.installQueueUnsupportedFile,
    _ => switch (task.type) {
      LocalDeviceInstallType.app => l10n.localAppInstall,
      LocalDeviceInstallType.watchface => l10n.localWatchfaceInstall,
      LocalDeviceInstallType.firmware => l10n.localFirmwareInstall,
    },
  };
}

String _downloadTaskDescription(AppLocalizations l10n, ResourceTask task) {
  final type = switch (task.resource.type) {
    CommunityResourceType.quickApp => l10n.resourceTypeQuickApp,
    CommunityResourceType.miniprogram => l10n.resourceTypeApp,
    CommunityResourceType.watchface => l10n.resourceTypeWatchface,
    CommunityResourceType.firmware => l10n.resourceTypeFirmware,
    CommunityResourceType.canopus => l10n.module,
  };
  return [
    type,
    if (task.resource.authorName.trim().isNotEmpty)
      task.resource.authorName.trim(),
    resourceTargetDeviceDisplayName(task.codename),
  ].where((part) => part.isNotEmpty).join(' · ');
}

String _statusLabel(
  AppLocalizations l10n,
  ResourceTaskStatus status,
  double progress,
) {
  final percent = (progress * 100).toStringAsFixed(0);
  return switch (status) {
    ResourceTaskStatus.pending => l10n.queueStatusPending,
    ResourceTaskStatus.downloading => l10n.queueStatusDownloading(percent),
    ResourceTaskStatus.installing => l10n.queueStatusInstalling(percent),
    ResourceTaskStatus.completed => l10n.queueStatusCompleted,
    ResourceTaskStatus.failed => l10n.queueStatusFailed,
  };
}
