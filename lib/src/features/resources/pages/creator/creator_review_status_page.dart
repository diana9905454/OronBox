import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:segmented_list/segmented_list.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/utils/error_localization.dart';
import 'package:oronbox/src/app/widgets/sys_app_bar.dart';
import 'package:oronbox/src/commands/command_protocol.dart';
import 'package:oronbox/src/features/resources/application/creator/creator_workspace_controller.dart';
import 'package:oronbox/src/features/resources/domain/creator_workspace.dart';
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
  String? _replyTo;

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
    if (!_isAstroBoxReview(root)) return root;

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
    final body = _composer.text.trim();
    if (body.isEmpty || _sending) return;
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
      setState(() => _replyTo = null);
      setState(() => _future = _load());
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
    final controller = TextEditingController(text: current);
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
            params: {'review': widget.reviewId, 'comment': id, 'body': body},
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
    final state = review['state']?.toString() ?? '';
    final astro = root['astrobox'] as Map?;
    final isAstro =
        astro != null || review['review_type']?.toString() == 'astrobox';
    final comments = _comments(root);
    final pull =
        (astro?['pull_request'] as Map?)?.cast<String, Object?>() ??
        const <String, Object?>{};
    final pullIsBound = pull['number'] != null && pull['state'] != null;
    final canUpdate =
        astro != null &&
        comments.any((comment) => comment['is_author'] != true) &&
        pullIsBound &&
        ((astro['capabilities'] as Map?)?['can_update_submission'] != false) &&
        (pull['state']?.toString() ?? 'open') == 'open';
    final workspace = CreatorWorkspace.fromJson(root);
    final resourceIcon = workspace.resource.kind.name == 'watchface'
        ? Icons.watch_outlined
        : Icons.apps_outlined;
    final note = review['note']?.toString().trim() ?? '';
    final createdAt = DateTime.tryParse(review['created_at']?.toString() ?? '');
    final updatedAt = DateTime.tryParse(review['updated_at']?.toString() ?? '');
    final summaryTiles = <AbstractSegmentedTile>[
      SegmentedTile(
        leading: CircleAvatar(child: Icon(resourceIcon)),
        title: Text(name),
        description: Text(
          '${isAstro ? l10n.astroBox : l10n.oronBox} · ${creatorStateLabel(l10n, state)}',
        ),
        trailing: CreatorStateBadge(state: state),
      ),
      SegmentedTile.navigation(
        leading: const Icon(Icons.edit_outlined),
        title: Text(l10n.creatorReviewStatus),
        value: Text(creatorStateLabel(l10n, state)),
        onPressed: null,
      ),
      if (note.isNotEmpty)
        SegmentedTile(
          leading: const Icon(Icons.notes_outlined),
          title: Text(l10n.reviewNote),
          description: Text(note),
        ),
      if (createdAt != null || updatedAt != null)
        SegmentedTile(
          leading: const Icon(Icons.schedule_outlined),
          title: Text(l10n.creatorUpdatedAt),
          description: Text(
            [
              if (createdAt != null)
                '${l10n.creatorSubmittedAt}: ${_formatDate(createdAt)}',
              if (updatedAt != null)
                '${l10n.creatorUpdatedAt}: ${_formatDate(updatedAt)}',
            ].join('\n'),
          ),
        ),
    ];
    return RefreshIndicator(
      onRefresh: () async => setState(() => _future = _load()),
      child: SegmentedList(
        maxWidth: 840,
        physics: const AlwaysScrollableScrollPhysics(),
        contentPadding: const EdgeInsets.only(top: 8, bottom: 32),
        sections: [
          SegmentedSection(
            title: Text(l10n.creatorReviewStatus),
            tiles: summaryTiles,
          ),
          if (astro == null &&
              (state == 'rejected' || state == 'changes_requested'))
            CustomSegmentedSection(
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: FilledButton.icon(
                  onPressed: () {
                    ref
                        .read(creatorWorkspaceProvider.notifier)
                        .select(workspace);
                    context.push(
                      '/resources/creator/resources/${workspace.resource.id}',
                    );
                  },
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(l10n.creatorModifyResource),
                ),
              ),
            ),
          if (astro != null)
            CustomSegmentedSection(
              child: _astroBoxContent(astro, comments, canUpdate, workspace),
            ),
        ],
      ),
    );
  }

  Widget _astroBoxContent(
    Map astro,
    List<Map<String, Object?>> comments,
    bool canUpdate,
    CreatorWorkspace workspace,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final pull =
        (astro['pull_request'] as Map?)?.cast<String, Object?>() ??
        const <String, Object?>{};
    final publication =
        (astro['publication'] as Map?)?.cast<String, Object?>() ??
        const <String, Object?>{};
    final prUrl =
        pull['html_url']?.toString() ??
        publication['external_url']?.toString() ??
        '';
    final changedFiles = pull['changed_files']?.toString();
    return SegmentedList(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      contentPadding: EdgeInsets.zero,
      sections: [
        SegmentedSection(
          title: Text(l10n.creatorAstroBoxReview),
          tiles: [
            SegmentedTile.navigation(
              leading: const Icon(Icons.merge_type),
              title: Text(
                '${pull['repository'] ?? publication['repository'] ?? ''}${pull['number'] == null ? '' : ' #${pull['number']}'}',
              ),
              description: Text(
                '${pull['state'] ?? ''}${changedFiles == null ? '' : ' · $changedFiles files'}',
              ),
              trailing: const Icon(Icons.open_in_new_outlined),
              onPressed: prUrl.isEmpty
                  ? null
                  : (_) => unawaited(launchUrl(Uri.parse(prUrl))),
              enabled: prUrl.isNotEmpty,
            ),
          ],
        ),
        if (canUpdate)
          CustomSegmentedSection(
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: FilledButton.icon(
                onPressed: () {
                  ref.read(creatorWorkspaceProvider.notifier).select(workspace);
                  context.push(
                    '/resources/creator/resources/${workspace.resource.id}',
                  );
                },
                icon: const Icon(Icons.edit_outlined),
                label: Text(l10n.creatorModifyResource),
              ),
            ),
          ),
        if ((astro['review_items'] as List? ?? []).isNotEmpty)
          SegmentedSection(
            title: Text(l10n.creatorReviewItems),
            tiles: [
              for (final raw in astro['review_items'] as List)
                SegmentedTile(
                  leading: Icon(
                    (raw as Map)['fixed'] == true
                        ? Icons.check_circle_outline
                        : Icons.build_outlined,
                  ),
                  title: Text(raw['message']?.toString() ?? ''),
                  trailing: raw['fixed'] == true
                      ? Text(l10n.creatorReviewFixReplied)
                      : TextButton(
                          onPressed: () {
                            setState(() {
                              _replyTo = raw['id'].toString();
                              _composer.text = '[ABCC_FIXED_${raw['id']}] ';
                              _composer.selection = TextSelection.collapsed(
                                offset: _composer.text.length,
                              );
                            });
                          },
                          child: Text(l10n.creatorReviewReplyFix),
                        ),
                ),
            ],
          ),
        SegmentedSection(
          title: Text(l10n.comments),
          tiles: comments.isEmpty
              ? [SegmentedTile(title: Text(l10n.commentEmpty))]
              : [for (final comment in comments) _commentTile(comment)],
        ),
        CustomSegmentedSection(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_replyTo != null)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.reply_outlined),
                    title: Text(l10n.creatorReplyingTo(_replyTo!)),
                    trailing: IconButton(
                      tooltip: l10n.cancel,
                      onPressed: () => setState(() => _replyTo = null),
                      icon: const Icon(Icons.close),
                    ),
                  ),
                TextField(
                  controller: _composer,
                  minLines: 2,
                  maxLines: 6,
                  decoration: InputDecoration(
                    labelText: l10n.creatorSupplement,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: FilledButton.icon(
                    onPressed: _sending ? null : _sendComment,
                    icon: _sending
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    label: Text(l10n.send),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  AbstractSegmentedTile _commentTile(Map<String, Object?> item) {
    final l10n = AppLocalizations.of(context)!;
    final id = item['id']?.toString() ?? '';
    final body = item['body']?.toString() ?? '';
    final url = item['html_url']?.toString() ?? item['url']?.toString() ?? '';
    final mine = item['is_author'] == true;
    final createdAt = DateTime.tryParse(item['created_at']?.toString() ?? '');
    return SegmentedTile.navigation(
      title: Text(
        item['user']?.toString() ?? item['author']?.toString() ?? 'GitHub',
      ),
      description: Text('$body\n${_formatDate(createdAt ?? DateTime.now())}'),
      trailing: id.isEmpty
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (url.isNotEmpty)
                  IconButton(
                    tooltip: l10n.open,
                    icon: const Icon(Icons.open_in_new_outlined),
                    onPressed: () => unawaited(launchUrl(Uri.parse(url))),
                  ),
                IconButton(
                  tooltip: l10n.creatorReply,
                  icon: const Icon(Icons.reply_outlined),
                  onPressed: () {
                    setState(() {
                      _replyTo = id;
                      _composer.text = l10n.creatorReplyPrefix(id);
                      _composer.selection = TextSelection.collapsed(
                        offset: _composer.text.length,
                      );
                    });
                  },
                ),
                if (mine)
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        unawaited(_editComment(id, body));
                      } else if (value == 'delete') {
                        unawaited(_deleteComment(id));
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Text(l10n.creatorEditComment),
                      ),
                      PopupMenuItem(value: 'delete', child: Text(l10n.delete)),
                    ],
                  ),
              ],
            ),
      onPressed: url.isEmpty
          ? null
          : (_) => unawaited(launchUrl(Uri.parse(url))),
      enabled: url.isNotEmpty,
    );
  }

  String _formatDate(DateTime value) =>
      MaterialLocalizations.of(context).formatFullDate(value.toLocal());
}
