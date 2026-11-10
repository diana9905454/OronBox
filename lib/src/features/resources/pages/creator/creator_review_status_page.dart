import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/utils/error_localization.dart';
import 'package:oronbox/src/app/widgets/sys_app_bar.dart';
import 'package:oronbox/src/commands/command_protocol.dart';
import 'package:oronbox/src/features/resources/application/creator/creator_workspace_controller.dart';
import 'package:oronbox/src/features/resources/domain/creator_workspace.dart';
import 'package:oronbox/src/features/resources/domain/creator_review.dart';
import 'package:oronbox/src/features/resources/pages/creator/creator_shared.dart';
import 'package:oronbox/src/host/application_host_provider.dart';

class CreatorReviewStatusPage extends ConsumerStatefulWidget {
  const CreatorReviewStatusPage({super.key, required this.reviewId});

  final String reviewId;

  @override
  ConsumerState<CreatorReviewStatusPage> createState() =>
      _CreatorReviewStatusPageState();
}

class _CreatorReviewStatusPageState
    extends ConsumerState<CreatorReviewStatusPage> {
  late Future<Map<String, Object?>> _future;
  final _composer = TextEditingController();
  bool _sending = false;
  bool _reopenRequested = false;
  String? _replyTo;
  String? _fixingId;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  Future<Map<String, Object?>> _load() async {
    final host = ref.read(applicationHostProvider);
    final result = await host.execute(
      OronBoxCommand(
        method: 'creator.review',
        params: {'review': widget.reviewId},
      ),
    );
    if (!result.ok) {
      throw StateError(result.error?.message ?? 'review_failed');
    }
    final root = (result.value as Map).cast<String, Object?>();
    final hasSubmission = (root['publications'] as List? ?? const [])
        .whereType<Map>()
        .any(
          (publication) =>
              publication['target'] == 'astrobox' &&
              int.tryParse(
                    (publication['status_detail']
                                as Map?)?['pull_request_number']
                            ?.toString() ??
                        '',
                  ) !=
                  null,
        );
    if (!_isAstroBoxReview(root) || !hasSubmission) return root;

    final extra = await host.execute(
      OronBoxCommand(
        method: 'creator.review.astrobox',
        params: {'review': widget.reviewId},
      ),
    );
    if (extra.ok && extra.value is Map) {
      root['astrobox'] = (extra.value as Map).cast<String, Object?>();
    }
    final comments = await host.execute(
      OronBoxCommand(
        method: 'creator.review.astrobox.comments',
        params: {'review': widget.reviewId},
      ),
    );
    if (!comments.ok) {
      root['astrobox_error'] = comments.error?.message ?? 'review_failed';
    }
    if (comments.ok) {
      root['astroboxComments'] = comments.value;
      if (comments.value is Map && root['astrobox'] is Map) {
        (root['astrobox'] as Map)['review_items'] =
            (comments.value as Map)['review_items'];
        (root['astrobox'] as Map)['review_state'] =
            (comments.value as Map)['review_state'];
      }
    }
    return root;
  }

  bool _isAstroBoxReview(Map<String, Object?> root) {
    if (root['review_type']?.toString() == 'astrobox') return true;
    final review = (root['review'] as Map?)?.cast<String, Object?>();
    if (review?['review_type']?.toString() == 'astrobox') return true;
    final publications = (root['publications'] as List?) ?? const [];
    return publications.whereType<Map>().any(
      (item) => item['target']?.toString() == 'astrobox',
    );
  }

  Map<String, Object?> _review(Map<String, Object?> root) {
    final nested = root['review'];
    if (nested is Map) return nested.cast<String, Object?>();
    return root;
  }

  List<Map<String, Object?>> _comments(Map<String, Object?> root) {
    final value = root['astroboxComments'];
    final list = value is Map ? value['items'] : value;
    return (list as List? ?? const [])
        .whereType<Map>()
        .map((item) => item.cast<String, Object?>())
        .toList();
  }

  Future<void> _sendComment() async {
    final text = _composer.text.trim();
    final body = _fixingId == null ? text : '[ABCC_FIXED_$_fixingId] $text';
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final result = await ref
          .read(applicationHostProvider)
          .execute(
            OronBoxCommand(
              method: 'creator.review.astrobox.comment.create',
              params: {'review': widget.reviewId, 'body': body},
            ),
          );
      if (!result.ok) {
        throw StateError(result.error?.message ?? 'comment_failed');
      }
      if (!mounted) return;
      _composer.clear();
      setState(() {
        _replyTo = null;
        _fixingId = null;
      });
      setState(() => _future = _load());
    } catch (error) {
      if (mounted) showCreatorFailure(context, error);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _requestReopen() async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      final result = await ref
          .read(applicationHostProvider)
          .execute(
            OronBoxCommand(
              method: 'creator.review.astrobox.reopen',
              params: {'review': widget.reviewId},
            ),
          );
      if (!result.ok) {
        throw CreatorCommandException.fromCommand(result.error!);
      }
      if (!mounted) return;
      setState(() {
        _reopenRequested = true;
        _future = _load();
      });
    } catch (error) {
      if (mounted) showCreatorFailure(context, error);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _deleteComment(String id) async {
    final result = await ref
        .read(applicationHostProvider)
        .execute(
          OronBoxCommand(
            method: 'creator.review.astrobox.comment.delete',
            params: {'review': widget.reviewId, 'comment': id},
          ),
        );
    if (!result.ok) {
      if (mounted) {
        showCreatorFailure(
          context,
          StateError(result.error?.message ?? 'comment_failed'),
        );
      }
      return;
    }
    if (mounted) setState(() => _future = _load());
  }

  Future<void> _editComment(String id, String current) async {
    final marker =
        RegExp(r'^\s*\[ABCC_[^\]]+\]\s*').firstMatch(current)?.group(0) ?? '';
    final controller = TextEditingController(
      text: current.substring(marker.length),
    );
    final body = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.creatorEditComment),
        content: TextField(
          controller: controller,
          minLines: 2,
          maxLines: 6,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(AppLocalizations.of(context)!.save),
          ),
        ],
      ),
    );
    controller.dispose();
    if (body == null || body.isEmpty) return;
    final result = await ref
        .read(applicationHostProvider)
        .execute(
          OronBoxCommand(
            method: 'creator.review.astrobox.comment.update',
            params: {
              'review': widget.reviewId,
              'comment': id,
              'body': '$marker$body',
            },
          ),
        );
    if (!result.ok) {
      if (mounted) {
        showCreatorFailure(
          context,
          StateError(result.error?.message ?? 'comment_failed'),
        );
      }
      return;
    }
    if (mounted) setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: SysAppBar(
        secondary: true,
        title: Text(l10n.creatorReviewStatus),
        actions: [
          IconButton(
            tooltip: l10n.refresh,
            onPressed: () => setState(() => _future = _load()),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, Object?>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(localizedErrorMessage(l10n, snapshot.error!)),
            );
          }
          return _content(snapshot.data!);
        },
      ),
    );
  }

  Widget _content(Map<String, Object?> root) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final review = _review(root);
    final resource =
        (root['resource'] as Map?)?.cast<String, Object?>() ??
        const <String, Object?>{};
    final reviewedRevision = (root['revisions'] as List? ?? const [])
        .whereType<Map>()
        .where((r) => r['id']?.toString() == review['revision_id']?.toString())
        .firstOrNull;
    final name =
        reviewedRevision?['name']?.toString() ??
        resource['draft_name']?.toString() ??
        resource['name']?.toString() ??
        review['resource_name']?.toString() ??
        '';
    final localState = review['state']?.toString() ?? '';
    final astro = root['astrobox'] as Map?;
    final publication = (root['publications'] as List? ?? const [])
        .whereType<Map>()
        .where((item) => item['target'] == 'astrobox')
        .firstOrNull;
    final state = CreatorReviewCase.fromJson({
      ...review,
      'publication_state': publication?['state'],
      'external_review_state':
          astro?['review_state'] ??
          (publication?['status_detail'] as Map?)?['review_state'],
    }).displayState;
    final isAstro =
        localState == 'approved' &&
        (astro != null || review['review_type']?.toString() == 'astrobox');
    final comments = _comments(root);
    final pull =
        (astro?['pull_request'] as Map?)?.cast<String, Object?>() ??
        const <String, Object?>{};
    final pullNumber =
        pull['number'] ??
        (publication?['status_detail'] as Map?)?['pull_request_number'];
    final pullIsBound = pullNumber != null;
    final prUrl =
        pull['html_url']?.toString() ??
        publication?['external_url']?.toString() ??
        '';
    final canUpdate =
        astro != null &&
        pullIsBound &&
        ((astro['capabilities'] as Map?)?['can_update_submission'] != false) &&
        (pull['state']?.toString() ?? 'open') == 'open';
    final workspace = CreatorWorkspace.fromJson(root);
    final note = review['note']?.toString().trim() ?? '';
    final createdAt = DateTime.tryParse(review['created_at']?.toString() ?? '');
    final updatedAt = DateTime.tryParse(review['updated_at']?.toString() ?? '');
    final isNeedsChanges = state == 'needs_changes';
    final isRejected = state == 'rejected';
    final reviewItems = (astro?['review_items'] as List? ?? const [])
        .whereType<Map>()
        .toList();
    final fixedCount = reviewItems
        .where((item) => item['fixed'] == true)
        .length;

    return RefreshIndicator(
      onRefresh: () async => setState(() => _future = _load()),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              children: [
                // 1. Header Card - 真实图标与关键元信息
                CreatorEditorCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CreatorResourceThumbnail(
                            workspace: workspace,
                            size: 56,
                            borderRadius: 14,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (pullNumber != null) ...[
                                      const SizedBox(width: 6),
                                      Text(
                                        '#$pullNumber',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                              color: colors.primary,
                                              fontFamily: 'monospace',
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    CreatorStateBadge(state: state),
                                    if (pull['state'] != null)
                                      _prBadge(
                                        pull['state']?.toString() ?? '',
                                        pull['merged'] == true,
                                      ),
                                    _tagChip(
                                      isAstro ? l10n.astroBox : l10n.oronBox,
                                      colors.secondaryContainer,
                                      colors.onSecondaryContainer,
                                    ),
                                  ],
                                ),
                                if (updatedAt != null || createdAt != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      '${l10n.creatorUpdatedAt}: ${_formatDateTime(updatedAt ?? createdAt!)}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: colors.onSurfaceVariant,
                                          ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (prUrl.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            IconButton.filledTonal(
                              tooltip: '在 GitHub 打开 PR',
                              icon: const Icon(
                                Icons.open_in_new_outlined,
                                size: 18,
                              ),
                              onPressed: () =>
                                  unawaited(launchUrl(Uri.parse(prUrl))),
                            ),
                          ],
                        ],
                      ),
                      if (note.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: colors.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.notes_outlined,
                                size: 18,
                                color: colors.onSurfaceVariant,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  note,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // 2. Action Banner - 需整改时的高亮指引
                if (isNeedsChanges || isRejected || canUpdate) ...[
                  CreatorEditorCard(
                    color: isNeedsChanges
                        ? colors.errorContainer
                        : colors.primaryContainer,
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Icon(
                          isNeedsChanges
                              ? Icons.assignment_late_outlined
                              : Icons.mode_edit_outline,
                          color: isNeedsChanges
                              ? colors.onErrorContainer
                              : colors.onPrimaryContainer,
                          size: 26,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isNeedsChanges
                                    ? l10n.creatorReviewChangesRequested
                                    : l10n.creatorReviewStatus,
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: isNeedsChanges
                                          ? colors.onErrorContainer
                                          : colors.onPrimaryContainer,
                                    ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isNeedsChanges
                                    ? '审核员已提出修改意见，请调整后重新提交或回复'
                                    : '如需调整资源内容，可前往编辑页修改',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: isNeedsChanges
                                          ? colors.onErrorContainer.withValues(
                                              alpha: .85,
                                            )
                                          : colors.onPrimaryContainer
                                                .withValues(alpha: .85),
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.tonal(
                          style: FilledButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () {
                            ref
                                .read(creatorWorkspaceProvider.notifier)
                                .select(workspace);
                            context.push(
                              '/resources/creator/resources/${workspace.resource.id}',
                            );
                          },
                          child: Text(l10n.creatorModifyResource),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // 3. Reopen Action
                if ((astro?['capabilities']
                        as Map?)?['can_reopen_submission'] ==
                    true) ...[
                  CreatorEditorCard(
                    color: colors.secondaryContainer,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.refresh_outlined,
                          size: 22,
                          color: colors.onSecondaryContainer,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _reopenRequested
                                ? l10n.creatorReopenRequested
                                : 'PR 已关闭，创作者可申请重新开启审核',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colors.onSecondaryContainer),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _sending || _reopenRequested
                              ? null
                              : _requestReopen,
                          icon: const Icon(Icons.replay, size: 16),
                          label: Text(
                            _reopenRequested
                                ? l10n.creatorReopenRequested
                                : l10n.creatorReopenSubmission,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // 4. Checklist Items (NeedFix items)
                if (reviewItems.isNotEmpty) ...[
                  CreatorEditorCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.checklist_rtl_outlined,
                              size: 20,
                              color: colors.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              l10n.creatorReviewItems,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: fixedCount == reviewItems.length
                                    ? colors.primaryContainer
                                    : colors.errorContainer,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$fixedCount / ${reviewItems.length}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'monospace',
                                  color: fixedCount == reviewItems.length
                                      ? colors.onPrimaryContainer
                                      : colors.onErrorContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        for (final raw in reviewItems) ...[
                          _reviewItemTile(raw),
                          if (raw != reviewItems.last)
                            const SizedBox(height: 8),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // 5. Comments Section Header
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.chat_bubble_outline_outlined,
                        size: 18,
                        color: colors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        l10n.comments,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '(${comments.length})',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                // 6. Comments Timeline Feed
                if (comments.isEmpty)
                  CreatorEditorCard(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        l10n.commentEmpty,
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                    ),
                  )
                else
                  for (final comment in comments) ...[
                    _commentCard(comment),
                    const SizedBox(height: 8),
                  ],
              ],
            ),
          ),

          // 7. Bottom Composer - 吸底安全区自适应
          _bottomComposer(),
        ],
      ),
    );
  }

  Widget _prBadge(String state, bool merged) {
    final colors = Theme.of(context).colorScheme;
    final isMerged = merged || state == 'merged';
    final isClosed = state == 'closed' && !isMerged;
    final (background, foreground) = isMerged
        ? (colors.tertiaryContainer, colors.onTertiaryContainer)
        : (isClosed
              ? (colors.errorContainer, colors.onErrorContainer)
              : (colors.primaryContainer, colors.onPrimaryContainer));
    final label = isMerged ? 'Merged' : (isClosed ? 'Closed' : 'Open');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: foreground,
        ),
      ),
    );
  }

  Widget _tagChip(String label, Color background, Color foreground) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: foreground,
        ),
      ),
    );
  }

  Widget _reviewItemTile(Map raw) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final fixed = raw['fixed'] == true;
    final id = raw['id']?.toString() ?? '';
    final message = raw['message']?.toString() ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            fixed ? Icons.check_circle : Icons.error_outline,
            size: 20,
            color: fixed ? colors.primary : colors.error,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.35,
                    decoration: fixed ? TextDecoration.lineThrough : null,
                    color: fixed
                        ? colors.onSurfaceVariant.withValues(alpha: .7)
                        : colors.onSurface,
                  ),
                ),
                if (id.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '#$id',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: colors.onSurfaceVariant.withValues(alpha: .7),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (fixed)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                l10n.creatorReviewFixReplied,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: colors.onPrimaryContainer,
                ),
              ),
            )
          else
            TextButton(
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              onPressed: () {
                setState(() {
                  _replyTo = id;
                  _fixingId = id;
                  _composer.clear();
                  _composer.selection = TextSelection.collapsed(
                    offset: _composer.text.length,
                  );
                });
              },
              child: Text(l10n.creatorReviewReplyFix),
            ),
        ],
      ),
    );
  }

  Widget _commentCard(Map<String, Object?> item) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final id = item['id']?.toString() ?? '';
    final body = item['body']?.toString() ?? '';
    final author =
        item['user']?.toString() ?? item['author']?.toString() ?? 'GitHub';
    final url = item['html_url']?.toString() ?? item['url']?.toString() ?? '';
    final isAuthor = item['is_author'] == true;
    final isReview = item['type'] == 'review';
    final createdAt = DateTime.tryParse(item['created_at']?.toString() ?? '');

    final rawAvatar =
        item['avatar_url']?.toString() ??
        (item['user'] is Map
            ? (item['user'] as Map)['avatar_url']?.toString()
            : null);
    final avatarUrl = (rawAvatar != null && rawAvatar.isNotEmpty)
        ? rawAvatar
        : (author.isNotEmpty && author != 'GitHub'
              ? 'https://github.com/$author.png?size=64'
              : '');

    // 匹配 ABCC 标签
    final match = RegExp(
      r'^\s*\[ABCC_(NEEDFIX|FIXED|CLOSE|REOPEN|REFUSE)(?:_([^\]]+))?\]\s*([\s\S]*)$',
      caseSensitive: false,
    ).firstMatch(body);

    String visibleBody = body;
    String? tagKind;
    String? tagId;
    if (match != null) {
      tagKind = match.group(1)?.toUpperCase();
      tagId = match.group(2);
      visibleBody = match.group(3)?.trim() ?? '';
    }

    return CreatorEditorCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundImage: avatarUrl.isNotEmpty
                    ? NetworkImage(avatarUrl)
                    : null,
                backgroundColor: isAuthor
                    ? colors.secondaryContainer
                    : colors.primaryContainer,
                child: avatarUrl.isEmpty
                    ? Text(
                        author.isNotEmpty ? author[0].toUpperCase() : '?',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isAuthor
                              ? colors.onSecondaryContainer
                              : colors.onPrimaryContainer,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            author,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isAuthor
                                ? colors.secondaryContainer
                                : colors.primaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isAuthor ? '作者' : '审核员',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              height: 1.15,
                              color: isAuthor
                                  ? colors.onSecondaryContainer
                                  : colors.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    if (createdAt != null)
                      Text(
                        _formatDateTime(createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              if (id.isNotEmpty)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 18),
                  padding: EdgeInsets.zero,
                  onSelected: (value) {
                    if (value == 'reply') {
                      setState(() {
                        _replyTo = id;
                        _fixingId = null;
                        _composer.text = l10n.creatorReplyPrefix(id);
                        _composer.selection = TextSelection.collapsed(
                          offset: _composer.text.length,
                        );
                      });
                    } else if (value == 'edit') {
                      unawaited(_editComment(id, body));
                    } else if (value == 'delete') {
                      unawaited(_deleteComment(id));
                    } else if (value == 'open' && url.isNotEmpty) {
                      unawaited(launchUrl(Uri.parse(url)));
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'reply',
                      child: Text(l10n.creatorReply),
                    ),
                    if (url.isNotEmpty)
                      PopupMenuItem(value: 'open', child: Text(l10n.open)),
                    if (isAuthor && !isReview) ...[
                      PopupMenuItem(
                        value: 'edit',
                        child: Text(l10n.creatorEditComment),
                      ),
                      PopupMenuItem(value: 'delete', child: Text(l10n.delete)),
                    ],
                  ],
                ),
            ],
          ),
          if (tagKind != null) ...[
            const SizedBox(height: 8),
            _buildTagChip(tagKind, tagId),
          ],
          if (visibleBody.isNotEmpty) ...[
            const SizedBox(height: 8),
            SelectableText(
              visibleBody,
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTagChip(String kind, String? tagId) {
    final colors = Theme.of(context).colorScheme;
    final (label, background, foreground, icon) = switch (kind) {
      'NEEDFIX' => (
        '需修改',
        colors.errorContainer,
        colors.onErrorContainer,
        Icons.error_outline,
      ),
      'FIXED' => (
        '已修复',
        colors.primaryContainer,
        colors.onPrimaryContainer,
        Icons.check_circle_outline,
      ),
      'REOPEN' => (
        '已重开',
        colors.secondaryContainer,
        colors.onSecondaryContainer,
        Icons.replay,
      ),
      'CLOSE' => (
        '已关闭',
        colors.surfaceContainerHighest,
        colors.onSurfaceVariant,
        Icons.cancel_outlined,
      ),
      'REFUSE' => (
        '已拒绝',
        colors.errorContainer,
        colors.onErrorContainer,
        Icons.block,
      ),
      _ => (
        kind,
        colors.primaryContainer,
        colors.onPrimaryContainer,
        Icons.tag,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 4),
          Text(
            tagId == null || tagId.isEmpty ? label : '$label #$tagId',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomComposer() {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        bottomInset > 0
            ? bottomInset + 8
            : (bottomPadding > 0 ? bottomPadding : 12),
      ),
      color: colors.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_replyTo != null)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: colors.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.reply,
                    size: 16,
                    color: colors.onSecondaryContainer,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _fixingId != null
                          ? '回复并标明修复整改项 #$_fixingId'
                          : l10n.creatorReplyingTo(_replyTo!),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colors.onSecondaryContainer,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    onPressed: () => setState(() {
                      _replyTo = null;
                      _fixingId = null;
                    }),
                  ),
                ],
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _composer,
                  minLines: 1,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: _fixingId != null
                        ? '说明针对整改项 #$_fixingId 的修正内容...'
                        : l10n.creatorSupplement,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    filled: true,
                    fillColor: colors.surfaceContainerHigh,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _sending ? null : _sendComment,
                icon: _sending
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    final date = MaterialLocalizations.of(context).formatShortDate(local);
    final time =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    return '$date $time';
  }
}
