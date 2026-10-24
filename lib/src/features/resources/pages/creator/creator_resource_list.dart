import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/theme/app_theme.dart';
import 'package:oronbox/src/app/widgets/app_state_view.dart';
import 'package:oronbox/src/app/widgets/page_container.dart';
import 'package:oronbox/src/core/constants/style_constants.dart';
import 'package:oronbox/src/features/resources/application/creator/creator_workspace_controller.dart';
import 'package:oronbox/src/features/resources/domain/creator_workspace.dart';
import 'package:oronbox/src/features/resources/pages/creator/creator_shared.dart';

class CreatorResourceList extends StatefulWidget {
  const CreatorResourceList({
    super.key,
    required this.state,
    required this.controller,
    required this.collections,
    required this.collectionsLoading,
    required this.onRefresh,
    this.topContent,
    this.onOpenCollection,
    this.onOpen,
    this.selectedResourceIds = const {},
    this.onSelectionChanged,
    this.onDissolveCollection,
    this.bottomPadding = 24,
  });

  final CreatorWorkspaceState state;
  final CreatorWorkspaceController controller;
  final List<Map<String, Object?>> collections;
  final bool collectionsLoading;
  final Future<void> Function() onRefresh;
  final Widget? topContent;
  final ValueChanged<Map<String, Object?>>? onOpenCollection;
  final ValueChanged<CreatorWorkspace>? onOpen;
  final Set<String> selectedResourceIds;
  final ValueChanged<Set<String>>? onSelectionChanged;
  final ValueChanged<Map<String, Object?>>? onDissolveCollection;
  final double bottomPadding;

  @override
  State<CreatorResourceList> createState() => _CreatorResourceListState();
}

class _CreatorResourceListState extends State<CreatorResourceList> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = widget.state;
    final entries = [
      for (final item in widget.collections)
        _CreatorListEntry(
          workspace: _collectionWorkspace(item),
          collection: item,
          collectionResourceCount:
              (item['resource_count'] as num?)?.toInt() ?? 0,
        ),
      for (final workspace in state.resources.where(
        (workspace) => workspace.resource.collectionId.isEmpty,
      ))
        _CreatorListEntry(workspace: workspace),
    ];
    if (state.loading || widget.collectionsLoading) {
      return PageContainer(
        padding: const EdgeInsets.fromLTRB(
          StyleConstants.pagePadding,
          8,
          StyleConstants.pagePadding,
          0,
        ),
        child: LoadingView(
          message: creatorOperationLabel(l10n, state.operation),
        ),
      );
    }
    if (entries.isEmpty) {
      return RefreshIndicator(
        onRefresh: widget.onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(bottom: widget.bottomPadding),
          children: [
            PageContainer(
              padding: const EdgeInsets.fromLTRB(
                StyleConstants.pagePadding,
                8,
                StyleConstants.pagePadding,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.topContent != null) widget.topContent!,
                  EmptyStateView(
                    icon: Icons.edit_outlined,
                    title: l10n.creatorNoResources,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    final presentStates = creatorStateOrder
        .where(
          (value) => entries.any(
            (entry) => creatorWorkspaceState(entry.workspace) == value,
          ),
        )
        .toList();
    if (!presentStates.contains(_filter)) _filter = 'all';
    final visible = _filter == 'all'
        ? entries
        : entries
              .where(
                (entry) => creatorWorkspaceState(entry.workspace) == _filter,
              )
              .toList();
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(bottom: widget.bottomPadding),
        children: [
          PageContainer(
            padding: const EdgeInsets.fromLTRB(
              StyleConstants.pagePadding,
              8,
              StyleConstants.pagePadding,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.topContent != null) widget.topContent!,
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      _filterChip(l10n.all, 'all'),
                      for (final value in presentStates)
                        _filterChip(creatorStateLabel(l10n, value), value),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                for (final entry in visible)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: CreatorResourceCard(
                      workspace: entry.workspace,
                      controller: widget.controller,
                      isCollection: entry.collection != null,
                      collectionResourceCount: entry.collectionResourceCount,
                      selected: widget.selectedResourceIds.contains(
                        entry.workspace.resource.id,
                      ),
                      onLongPress: () {
                        final collection = entry.collection;
                        if (collection != null) {
                          widget.onDissolveCollection?.call(collection);
                          return;
                        }
                        _toggleSelection(entry.workspace.resource.id);
                      },
                      onTap: () {
                        final collection = entry.collection;
                        if (collection != null) {
                          widget.onOpenCollection?.call(collection);
                        } else if (widget.selectedResourceIds.isNotEmpty) {
                          _toggleSelection(entry.workspace.resource.id);
                        } else {
                          widget.controller.select(entry.workspace);
                          widget.onOpen?.call(entry.workspace);
                        }
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _toggleSelection(String resourceId) {
    final selected = {...widget.selectedResourceIds};
    selected.contains(resourceId)
        ? selected.remove(resourceId)
        : selected.add(resourceId);
    widget.onSelectionChanged?.call(selected);
  }

  Widget _filterChip(String label, String value) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: FilterChip(
      label: Text(label),
      selected: _filter == value,
      showCheckmark: false,
      onSelected: (_) => setState(() => _filter = value),
    ),
  );

  CreatorWorkspace _collectionWorkspace(Map<String, Object?> item) {
    final pending = item['pending_revision'] as Map?;
    final current = item['current_revision'] as Map?;
    final metadata = pending ?? current;
    final representativeId = item['representative_resource_id']?.toString();
    final representative = widget.state.resources
        .where((entry) => entry.resource.id == representativeId)
        .firstOrNull;
    final kind = item['kind'] == 'watchface'
        ? CreatorResourceKind.watchface
        : CreatorResourceKind.quickApp;
    final revision = CreatorRevision(
      id: metadata?['id']?.toString() ?? '',
      number: (metadata?['revision_no'] as num?)?.toInt() ?? 0,
      name: metadata?['name']?.toString() ?? '',
      summary: metadata?['summary']?.toString() ?? '',
      state: pending != null ? 'pending' : 'approved',
    );
    return CreatorWorkspace(
      resource: CreatorResource(
        id: item['id']?.toString() ?? '',
        slug: item['slug']?.toString() ?? '',
        draftName: revision.name,
        kind: kind,
        moderationState: pending != null ? 'pending' : 'visible',
        updatedAt: DateTime.tryParse(item['updated_at']?.toString() ?? ''),
      ),
      currentRevision: revision,
      revisions: [revision],
      media: representative?.media ?? const [],
    );
  }
}

class _CreatorListEntry {
  const _CreatorListEntry({
    required this.workspace,
    this.collection,
    this.collectionResourceCount = 0,
  });

  final CreatorWorkspace workspace;
  final Map<String, Object?>? collection;
  final int collectionResourceCount;
}

class CreatorResourceThumbnail extends StatefulWidget {
  const CreatorResourceThumbnail({
    super.key,
    required this.workspace,
    required this.controller,
    this.size = 64,
  });

  final CreatorWorkspace workspace;
  final CreatorWorkspaceController controller;
  final double size;

  @override
  State<CreatorResourceThumbnail> createState() =>
      _CreatorResourceThumbnailState();
}

class _CreatorResourceThumbnailState extends State<CreatorResourceThumbnail> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant CreatorResourceThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workspace.resource.id != widget.workspace.resource.id ||
        creatorThumbnailMedia(oldWidget.workspace)?.sha256 !=
            creatorThumbnailMedia(widget.workspace)?.sha256) {
      _bytes = null;
      _load();
    }
  }

  Future<void> _load() async {
    final media = creatorThumbnailMedia(widget.workspace);
    if (media == null) return;
    try {
      final bytes = await widget.controller.blob(
        widget.workspace.resource.id,
        media.sha256,
      );
      if (mounted) setState(() => _bytes = bytes);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final bytes = _bytes;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: bytes != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(bytes, fit: BoxFit.cover),
            )
          : Icon(
              widget.workspace.resource.kind == CreatorResourceKind.watchface
                  ? Icons.watch_outlined
                  : Icons.apps_outlined,
              color: colors.onSurfaceVariant,
            ),
    );
  }
}

class CreatorResourceCard extends StatelessWidget {
  const CreatorResourceCard({
    super.key,
    required this.workspace,
    required this.controller,
    required this.onTap,
    this.isCollection = false,
    this.collectionResourceCount = 0,
    this.selected = false,
    this.onLongPress,
  });

  final CreatorWorkspace workspace;
  final CreatorWorkspaceController controller;
  final VoidCallback onTap;
  final bool isCollection;
  final int collectionResourceCount;
  final bool selected;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final state = creatorWorkspaceState(workspace);
    final subtitle = workspace.latestRevision?.summary ?? '';
    final note = state == 'rejected' ? creatorReviewNote(workspace) : '';
    final supportedDeviceCount = workspace.artifacts
        .expand((artifact) => artifact.devices)
        .toSet()
        .length;
    return Card(
      clipBehavior: Clip.antiAlias,
      color: selected
          ? context.appSelectionContainer.withValues(alpha: .72)
          : colors.surfaceContainerHighest.withValues(alpha: .5),
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          creatorWorkspaceTitle(workspace),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                height: 1.25,
                              ),
                        ),
                        if (subtitle.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: colors.onSurfaceVariant),
                            ),
                          ),
                        if (workspace.resource.updatedAt != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              _creatorResourceTime(
                                workspace.resource.updatedAt!,
                              ),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: colors.onSurfaceVariant),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (selected) ...[
                    Icon(Icons.check_circle, color: colors.primary),
                    const SizedBox(width: 8),
                  ],
                  CreatorStateBadge(state: state),
                  const SizedBox(width: 8),
                  CreatorResourceThumbnail(
                    workspace: workspace,
                    controller: controller,
                    size: 48,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (isCollection)
                    _CreatorResourceTag(
                      label: l10n.creatorCollectionTag,
                      color: colors.secondary,
                    ),
                  _CreatorResourceTag(
                    label: creatorKindLabel(l10n, workspace.resource.kind),
                    color:
                        workspace.resource.kind == CreatorResourceKind.quickApp
                        ? colors.error
                        : colors.primary,
                  ),
                  if (isCollection)
                    _CreatorResourceTag(
                      icon: Icons.inventory_2_outlined,
                      label: l10n.creatorCollectionResourceCount(
                        collectionResourceCount,
                      ),
                      color: colors.onSurfaceVariant,
                    ),
                  if (!isCollection && workspace.artifacts.isNotEmpty)
                    _CreatorResourceTag(
                      icon: Icons.folder_zip_outlined,
                      label: l10n.creatorArtifactCount(
                        workspace.artifacts.length,
                      ),
                      color: colors.onSurfaceVariant,
                    ),
                  if (supportedDeviceCount > 0)
                    _CreatorResourceTag(
                      icon: Icons.watch_outlined,
                      label: l10n.creatorCompatibleDeviceCount(
                        supportedDeviceCount,
                      ),
                      color: colors.onSurfaceVariant,
                    ),
                  if (workspace.revisions.isNotEmpty)
                    _CreatorResourceTag(
                      icon: Icons.download,
                      label: '${workspace.resource.downloadCount}',
                      color: colors.onSurfaceVariant,
                    ),
                ],
              ),
              if (note.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${l10n.reviewNote}: $note',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: colors.error),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

String _creatorResourceTime(DateTime value) {
  final time = value.toLocal();
  String two(int part) => part.toString().padLeft(2, '0');
  return '${two(time.year % 100)}-${two(time.month)}-${two(time.day)} '
      '${two(time.hour)}:${two(time.minute)}';
}

class _CreatorResourceTag extends StatelessWidget {
  const _CreatorResourceTag({
    required this.label,
    required this.color,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
        ],
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}
