import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:segmented_list/segmented_list.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/utils/error_localization.dart';
import 'package:oronbox/src/app/widgets/app_state_view.dart';
import 'package:oronbox/src/app/widgets/network_img_layer.dart';
import 'package:oronbox/src/app/widgets/page_container.dart';
import 'package:oronbox/src/app/widgets/sys_app_bar.dart';
import 'package:oronbox/src/commands/command_protocol.dart';
import 'package:oronbox/src/core/constants/style_constants.dart';
import 'package:oronbox/src/features/resources/application/creator/creator_workspace_controller.dart';
import 'package:oronbox/src/features/resources/domain/creator_review.dart';
import 'package:oronbox/src/features/resources/domain/creator_workspace.dart';
import 'package:oronbox/src/features/resources/pages/creator/creator_shared.dart';
import 'package:oronbox/src/host/application_host_provider.dart';

class CreatorReviewListPage extends ConsumerStatefulWidget {
  const CreatorReviewListPage({
    super.key,
    this.embedded = false,
    this.initialFilter,
  });
  final bool embedded;
  final String? initialFilter;
  @override
  ConsumerState<CreatorReviewListPage> createState() =>
      _CreatorReviewListPageState();
}

class _CreatorReviewListPageState extends ConsumerState<CreatorReviewListPage> {
  final _items = <CreatorReviewCase>[];
  String? _cursor;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  late String _filter = switch (widget.initialFilter) {
    'all' => 'all',
    'pending' => 'pending',
    'needs_changes' => 'needs_changes',
    'fixed_pending_review' => 'fixed_pending_review',
    'external_review' => 'external_review',
    'approved' => 'approved',
    'rejected' => 'rejected',
    _ => 'all',
  };
  Object? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load({bool more = false}) async {
    if (more && (_loadingMore || !_hasMore)) return;
    setState(() {
      if (more) {
        _loadingMore = true;
      } else {
        _loading = true;
        _error = null;
        _cursor = null;
        _hasMore = true;
      }
    });
    try {
      final result = await ref
          .read(applicationHostProvider)
          .execute(
            OronBoxCommand(
              method: 'creator.reviews',
              params: {
                'limit': 30,
                if (more && _cursor != null) 'cursor': _cursor,
              },
            ),
          );
      if (!result.ok) {
        throw StateError(result.error?.message ?? 'review_failed');
      }
      final root = (result.value as Map).cast<String, Object?>();
      final page = (root['items'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) => CreatorReviewCase.fromJson(item.cast<String, Object?>()),
          )
          .toList();
      if (!mounted) return;
      setState(() {
        if (!more) _items.clear();
        final existing = _items.map((item) => item.id).toSet();
        _items.addAll(page.where((item) => existing.add(item.id)));
        _cursor = root['next_cursor']?.toString();
        _hasMore = root['has_more'] == true;
        _loading = false;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final availableStates = _items.map((item) => item.displayState).toSet();
    final hasAstroBox = _items.any(
      (item) =>
          item.reviewType == 'astrobox' ||
          item.state.startsWith('external_') ||
          item.state == 'waiting_external_review',
    );
    final showPending = availableStates.any(
      (state) => state == 'pending' || state == 'reviewing',
    );
    final showNeedsChanges =
        availableStates.contains('needs_changes') ||
        availableStates.contains('changes_requested') ||
        availableStates.contains('external_changes_requested');
    final showFixedPending =
        availableStates.contains('fixed_pending_review') ||
        availableStates.contains('external_fixed_waiting');
    final showApproved =
        availableStates.contains('approved') ||
        availableStates.contains('published');
    final showRejected = availableStates.contains('rejected');
    final showExternal =
        hasAstroBox &&
        availableStates.any(
          (state) =>
              state == 'external_review' ||
              state == 'needs_changes' ||
              state == 'fixed_pending_review',
        );

    final validFilters = {
      'all',
      'active',
      if (showPending) 'pending',
      if (showNeedsChanges) 'needs_changes',
      if (showFixedPending) 'fixed_pending_review',
      if (showExternal) 'external_review',
      if (showApproved) 'approved',
      if (showRejected) 'rejected',
    };
    if (!validFilters.contains(_filter)) {
      _filter = 'all';
    }
    final visible = _items
        .where((item) => _matchesFilter(item.displayState))
        .toList();
    final body = RefreshIndicator(
      onRefresh: _load,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.axis == Axis.vertical &&
              notification.metrics.extentAfter < 320 &&
              !_loading &&
              !_loadingMore &&
              _hasMore) {
            unawaited(_load(more: true));
          }
          return false;
        },
        child: SegmentedList(
          maxWidth: StyleConstants.pageMaxWidth,
          physics: const AlwaysScrollableScrollPhysics(),
          contentPadding: EdgeInsets.only(
            top: 8,
            bottom: bottomContentPadding(context, extra: 16),
          ),
          sections: [
            CustomSegmentedSection(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _chip(l10n.all, 'all'),
                      _chip(l10n.creatorReviewActive, 'active'),
                      if (showPending)
                        _chip(_label(l10n, 'pending'), 'pending'),
                      if (showNeedsChanges)
                        _chip(_label(l10n, 'needs_changes'), 'needs_changes'),
                      if (showFixedPending)
                        _chip(
                          _label(l10n, 'fixed_pending_review'),
                          'fixed_pending_review',
                        ),
                      if (showExternal)
                        _chip(
                          l10n.creatorStateExternalReview,
                          'external_review',
                        ),
                      if (showApproved)
                        _chip(_label(l10n, 'approved'), 'approved'),
                      if (showRejected)
                        _chip(_label(l10n, 'rejected'), 'rejected'),
                    ],
                  ),
                ),
              ),
            ),
            if (_loading && _items.isEmpty)
              CustomSegmentedSection(
                child: SizedBox(
                  height: _stateSectionHeight(context),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (_error != null && _items.isEmpty)
              CustomSegmentedSection(
                child: SizedBox(
                  height: _stateSectionHeight(context),
                  child: Center(
                    child: ErrorStateView(
                      compact: true,
                      message: localizedErrorMessage(l10n, _error),
                      onRetry: _load,
                    ),
                  ),
                ),
              )
            else if (visible.isEmpty)
              CustomSegmentedSection(
                child: SizedBox(
                  height: _stateSectionHeight(context),
                  child: Center(
                    child: EmptyStateView(
                      compact: true,
                      title: _filter == 'active'
                          ? l10n.creatorNoPendingReviews
                          : l10n.creatorNoReviews,
                    ),
                  ),
                ),
              )
            else
              SegmentedSection(
                tiles: [for (final item in visible) _reviewItem(item)],
              ),
            if (_loadingMore)
              const CustomSegmentedSection(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        ),
      ),
    );
    if (widget.embedded) return body;
    return Scaffold(
      appBar: SysAppBar(
        secondary: true,
        title: Text(l10n.creatorReviewQueue),
        actions: [
          IconButton(
            tooltip: l10n.refresh,
            onPressed: _loading ? null : () => unawaited(_load()),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: body,
    );
  }

  Widget _chip(String label, String value) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: FilterChip(
      label: Text(label),
      selected: _filter == value,
      showCheckmark: false,
      onSelected: (_) => setState(() => _filter = value),
    ),
  );

  AbstractSegmentedTile _reviewItem(CreatorReviewCase item) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final type = item.state == 'approved' && item.reviewType == 'astrobox'
        ? l10n.astroBox
        : l10n.oronBox;
    return SegmentedTile.navigation(
      leading: _icon(item),
      title: Text(
        item.resourceName,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      description: Text(
        '$type · ${_date(item.updatedAt)}',
        style: TextStyle(color: colors.onSurfaceVariant),
      ),
      trailing: CreatorStateBadge(state: item.displayState),
      onPressed: (_) => context.push(
        '/resources/creator/reviews/${Uri.encodeComponent(item.id)}',
      ),
    );
  }

  String _label(AppLocalizations l10n, String state) => switch (state) {
    'all' => l10n.all,
    'active' => l10n.creatorReviewActive,
    'pending' || 'reviewing' => l10n.pendingReview,
    'approved' => l10n.creatorStateApproved,
    'needs_changes' ||
    'changes_requested' => l10n.creatorReviewChangesRequested,
    'rejected' => l10n.creatorReviewDeclined,
    'fixed_pending_review' => l10n.creatorReviewFixedPending,
    'external_review' ||
    'waiting_external_review' => l10n.creatorStateExternalReview,
    'closed' => l10n.creatorReviewClosed,
    'superseded' => l10n.creatorStateSuperseded,
    _ => state,
  };

  bool _matchesFilter(String state) =>
      creatorReviewMatchesFilter(_filter, state);

  Widget _icon(CreatorReviewCase item) {
    final workspace = ref
        .watch(creatorWorkspaceProvider)
        .resources
        .where((r) => r.resource.id == item.resourceId)
        .firstOrNull;
    if (workspace != null) {
      return CreatorResourceThumbnail(
        workspace: workspace,
        size: 48,
        borderRadius: 12,
      );
    }
    if (item.iconUrl.isNotEmpty) {
      return NetworkImgLayer(
        src: item.iconUrl,
        width: 48,
        height: 48,
        borderRadius: BorderRadius.circular(12),
      );
    }
    return CreatorResourceThumbnail(
      resourceId: item.resourceId,
      kind: item.resourceKind == 'watchface'
          ? CreatorResourceKind.watchface
          : CreatorResourceKind.quickApp,
      size: 48,
      borderRadius: 12,
    );
  }

  String _date(DateTime value) =>
      MaterialLocalizations.of(context).formatShortDate(value.toLocal());

  double _stateSectionHeight(BuildContext context) {
    final available = MediaQuery.sizeOf(context).height - 260;
    return available > 240 ? available : 240;
  }
}

/// Review-state predicate behind the filter chips and the deep-linked
/// `initialFilter`. Top-level so unit tests cover every selectable chip.
bool creatorReviewMatchesFilter(String filter, String state) =>
    switch (filter) {
      'all' => true,
      'active' =>
        state == 'pending' ||
            state == 'reviewing' ||
            state == 'needs_changes' ||
            state == 'changes_requested' ||
            state == 'fixed_pending_review' ||
            state == 'publishing' ||
            state == 'dispatching' ||
            state == 'waiting_external_review' ||
            state == 'external_changes_requested' ||
            state == 'external_fixed_waiting' ||
            state == 'external_review',
      'pending' => state == 'pending' || state == 'reviewing',
      'needs_changes' =>
        state == 'needs_changes' ||
            state == 'changes_requested' ||
            state == 'external_changes_requested',
      'fixed_pending_review' =>
        state == 'fixed_pending_review' || state == 'external_fixed_waiting',
      'external_review' =>
        state == 'waiting_external_review' ||
            state == 'external_review' ||
            state == 'external_changes_requested' ||
            state == 'external_fixed_waiting' ||
            state == 'needs_changes' ||
            state == 'fixed_pending_review',
      'approved' => state == 'approved' || state == 'published',
      'rejected' => state == 'rejected',
      'closed' =>
        state == 'closed' || state == 'superseded' || state == 'cancelled',
      _ => false,
    };
