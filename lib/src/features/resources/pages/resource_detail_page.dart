import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/utils/error_localization.dart';
import 'package:oronbox/src/app/widgets/horizontal_scroller.dart';
import 'package:oronbox/src/app/widgets/network_img_layer.dart';
import 'package:oronbox/src/app/widgets/page_container.dart';
import 'package:oronbox/src/app/widgets/sys_app_bar.dart';
import 'package:oronbox/src/core/constants/style_constants.dart';
import 'package:oronbox/src/core/providers/app_settings_providers.dart';
import 'package:oronbox/src/data/community/community_source.dart';
import 'package:oronbox/src/device/core/xiaomi_wearable_catalog.dart';
import 'package:oronbox/src/features/devices/controllers/device_manager.dart';
import 'package:oronbox/src/features/accounts/application/host_accounts.dart';
import 'package:oronbox/src/features/accounts/services/bandbbs_auth_service.dart';
import 'package:oronbox/src/features/accounts/services/oronbox_coin_service.dart';
import 'package:oronbox/src/features/resources/application/comments/oronbox_comments.dart';
import 'package:oronbox/src/features/resources/application/resource_catalog_providers.dart';
import 'package:oronbox/src/features/resources/controllers/resource_filter_controller.dart';
import 'package:oronbox/src/features/resources/domain/community_resource.dart';
import 'package:oronbox/src/features/resources/services/download_queue_notifier.dart';
import 'package:oronbox/src/features/resources/services/install_queue_notifier.dart';
import 'package:oronbox/src/features/resources/widgets/community_html_content.dart';
import 'package:oronbox/src/features/resources/widgets/resource_detail_header.dart';
import 'package:oronbox/src/features/resources/widgets/resource_external_link.dart';
import 'package:oronbox/src/features/settings/pages/feedback_page.dart';

class ResourceDetailPage extends ConsumerWidget {
  const ResourceDetailPage({
    super.key,
    required this.resource,
    this.targetCommentId = '',
  });
  final CommunityResource resource;
  final String targetCommentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final detail = ref.watch(communityResourceDetailProvider(resource.ref));
    final visibleResource = detail.value ?? resource;
    return Scaffold(
      appBar: SysAppBar(secondary: true, title: Text(l10n.resourceDetails)),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          ResourceDetailHeader(
            resource: visibleResource,
            mediaResource: visibleResource,
            animateCover: resource.coverUrl != null,
            animateIcon: resource.iconUrl != null,
          ),
          detail.when(
            loading: () => const PageContainer(
              padding: EdgeInsets.symmetric(
                horizontal: StyleConstants.pagePadding,
                vertical: 20,
              ),
              child: _DelayedLoadingIndicator(),
            ),
            error: (error, _) => PageContainer(
              padding: const EdgeInsets.all(StyleConstants.pagePadding),
              child: Text(localizedErrorMessage(l10n, error)),
            ),
            data: (value) =>
                _DetailContent(detail: value, targetCommentId: targetCommentId),
          ),
        ],
      ),
    );
  }
}

class _DelayedLoadingIndicator extends StatefulWidget {
  const _DelayedLoadingIndicator();

  @override
  State<_DelayedLoadingIndicator> createState() =>
      _DelayedLoadingIndicatorState();
}

class _DelayedLoadingIndicatorState extends State<_DelayedLoadingIndicator> {
  Timer? _timer;
  var _visible = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 160),
    child: _visible
        ? const LinearProgressIndicator(key: ValueKey('detail-progress'))
        : const SizedBox.shrink(key: ValueKey('detail-progress-delay')),
  );
}

class _DetailContent extends ConsumerStatefulWidget {
  const _DetailContent({required this.detail, required this.targetCommentId});
  final CommunityResourceDetail detail;
  final String targetCommentId;

  @override
  ConsumerState<_DetailContent> createState() => _DetailContentState();
}

class _DetailContentState extends ConsumerState<_DetailContent> {
  var _unsupportedNoticeShown = false;

  CommunityResourceDetail get detail => widget.detail;
  String get targetCommentId => widget.targetCommentId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybeShowUnsupportedDownloadNotice();
  }

  @override
  void didUpdateWidget(covariant _DetailContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.detail.ref != widget.detail.ref) {
      _unsupportedNoticeShown = false;
    }
    _maybeShowUnsupportedDownloadNotice();
  }

  void _maybeShowUnsupportedDownloadNotice() {
    if (_unsupportedNoticeShown ||
        detail.downloadRestriction !=
            CommunityResourceDownloadRestriction.astroBoxCreatorEncrypted) {
      return;
    }
    _unsupportedNoticeShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      unawaited(
        showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            icon: Icon(
              Icons.lock_outline,
              color: Theme.of(dialogContext).colorScheme.error,
            ),
            title: Text(l10n.resourceAstroBoxEncryptedTitle),
            content: Text(l10n.resourceAstroBoxEncryptedMessage),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(l10n.resourceAstroBoxEncryptedAction),
              ),
            ],
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final deviceState = ref.watch(deviceManagerProvider);
    final current = deviceState.currentDevice;
    final currentCodename = normalizeXiaomiWearableCodename(current?.codename);
    final isBandBbs = detail.ref.source == CommunitySourceId.bandbbs;
    final previews = isBandBbs
        ? detail.previewImages
              .where(
                (image) => !detail.content.value.contains(image.url.toString()),
              )
              .toList()
        : detail.previewImages;
    return PageContainer(
      padding: const EdgeInsets.all(StyleConstants.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (detail.summary.isNotEmpty &&
              detail.summary != detail.content.value) ...[
            Text(
              detail.summary,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: _Actions(
                  detail: detail,
                  currentCodename: currentCodename,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 108,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (detail.ref.source == CommunitySourceId.oronBox) ...[
                      _CoinButton(resource: detail),
                      const SizedBox(height: 6),
                    ],
                    FilledButton.tonalIcon(
                      onPressed: () => showFeedbackComposer(
                        context,
                        target: FeedbackTarget(
                          type: FeedbackTargetType.resource,
                          source: detail.ref.source.name,
                          id: detail.ref.id,
                          name: detail.name,
                          url: detail.links.firstOrNull?.url.toString() ?? '',
                        ),
                      ),
                      icon: const Icon(Icons.flag_outlined),
                      label: Text(l10n.report),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(36),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: theme
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: .62),
                        foregroundColor: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (detail.collectionName?.isNotEmpty == true) ...[
            const SizedBox(height: 12),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: detail.collectionId?.isNotEmpty == true
                  ? () => context.push(
                      '/resources/collection/${detail.collectionId}',
                      extra: CommunityResource(
                        ref: ResourceRef(
                          source: CommunitySourceId.oronBox,
                          id: detail.collectionId!,
                        ),
                        name: detail.collectionName ?? '',
                        type: detail.type,
                        paidType: detail.paidType,
                        authors: detail.authors,
                        supportedDevices: detail.supportedDevices,
                        iconUrl: detail.iconUrl,
                        coverUrl: detail.coverUrl,
                        summary: detail.summary,
                        isCollection: true,
                      ),
                    )
                  : null,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(
                    alpha: .5,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.folder_outlined,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      l10n.resourceFromCollection(detail.collectionName!),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (detail.links.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final link in detail.links)
                  TextButton.icon(
                    onPressed: () =>
                        openResourceExternalLink(context, link.url),
                    icon: const Icon(Icons.link_outlined),
                    label: Text(link.title),
                  ),
              ],
            ),
          ],
          if (previews.isNotEmpty && !isBandBbs) ...[
            const SizedBox(height: 24),
            _PreviewGallery(previews: previews),
          ],
          if (detail.content.value.trim().isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              AppLocalizations.of(context)!.description,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            switch (detail.content.format) {
              ResourceContentFormat.html => CommunityHtmlContent(
                html: detail.content.value,
                baseUri: detail.content.baseUri,
                onOpenLink: (uri) => openResourceExternalLink(context, uri),
              ),
              ResourceContentFormat.plainText => SelectableText(
                detail.content.value,
                style: theme.textTheme.bodyLarge,
              ),
            },
          ],
          if (previews.isNotEmpty && isBandBbs) ...[
            const SizedBox(height: 24),
            _PreviewGallery(previews: previews),
          ],
          if (currentCodename.isNotEmpty) ...[
            const SizedBox(height: 24),
            _Compatibility(
              detail: detail,
              codename: currentCodename,
              deviceName: xiaomiDisplayNameForIdentity(
                name: current?.name.toString() ?? currentCodename,
                codename: currentCodename,
              ),
            ),
          ],
          if (detail.ref.source == CommunitySourceId.oronBox &&
              ref.watch(appSettingsProvider).clean.commentsEnabled) ...[
            const SizedBox(height: 28),
            _CommentsSection(
              resourceId: detail.ref.id,
              targetCommentId: targetCommentId,
            ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _CoinButton extends ConsumerStatefulWidget {
  const _CoinButton({required this.resource});

  final CommunityResource resource;

  @override
  ConsumerState<_CoinButton> createState() => _CoinButtonState();
}

class _CoinButtonState extends ConsumerState<_CoinButton> {
  var _sending = false;

  Future<void> _send(int remaining) async {
    if (remaining <= 0 || _sending) return;
    final l10n = AppLocalizations.of(context)!;
    final count = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.resourceCoinDialogTitle),
        content: Text(l10n.resourceCoinDialogMessage),
        actions: [
          TextButton(onPressed: () => context.pop(), child: Text(l10n.cancel)),
          if (remaining >= 1)
            TextButton(
              onPressed: () => context.pop(1),
              child: Text(l10n.resourceCoinOne),
            ),
          if (remaining >= 2)
            FilledButton(
              onPressed: () => context.pop(2),
              child: Text(l10n.resourceCoinTwo),
            ),
        ],
      ),
    );
    if (count == null || _sending) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(oronBoxCoinServiceProvider)
          .coin(widget.resource.ref.id, count);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.resourceCoinSuccess)));
      ref.invalidate(communityResourceDetailProvider(widget.resource.ref));
      ref.invalidate(oronBoxMyCoinsProvider(widget.resource.ref.id));
      ref.read(resourceRefreshProvider.notifier).refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizedErrorMessage(l10n, error))),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isSignedIn = ref.watch(bandBbsAuthProvider).isSignedIn;
    final myCoins = ref.watch(oronBoxMyCoinsProvider(widget.resource.ref.id));
    final voted = myCoins.value ?? 0;
    final statusLoading = isSignedIn && myCoins.isLoading;
    final statusError = isSignedIn && myCoins.hasError;
    final statusKnown = isSignedIn && myCoins.hasValue;
    final locked = statusKnown && voted >= 2;
    final canCoin =
        statusKnown && !statusLoading && !statusError && !_sending && !locked;
    final canRetry = statusError && !_sending;
    return Tooltip(
      message: !isSignedIn
          ? l10n.resourceCoinNotSignedIn
          : statusError
          ? l10n.errorCoinStatusUnavailable
          : '',
      child: FilledButton.icon(
        onPressed: canCoin
            ? () => _send(2 - voted)
            : canRetry
            ? () =>
                  ref.invalidate(oronBoxMyCoinsProvider(widget.resource.ref.id))
            : null,
        icon: _sending || statusLoading
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : statusError
            ? const Icon(Icons.refresh)
            : const Icon(Icons.toll_outlined),
        label: Text(
          !isSignedIn
              ? l10n.resourceCoinNotSignedIn
              : statusError
              ? l10n.refresh
              : voted > 0
              ? l10n.resourceCoinVoted
              : l10n.resourceCoin,
        ),
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(36),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          visualDensity: VisualDensity.compact,
          backgroundColor: !isSignedIn || (voted > 0 && statusKnown)
              ? theme.colorScheme.surfaceContainerHighest
              : null,
          foregroundColor: !isSignedIn || (voted > 0 && statusKnown)
              ? theme.colorScheme.onSurfaceVariant
              : null,
          disabledBackgroundColor: theme.colorScheme.surfaceContainerHighest,
          disabledForegroundColor: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _CommentsSection extends ConsumerStatefulWidget {
  const _CommentsSection({
    required this.resourceId,
    required this.targetCommentId,
  });
  final String resourceId;
  final String targetCommentId;

  @override
  ConsumerState<_CommentsSection> createState() => _CommentsSectionState();
}

class _CommentsSectionState extends ConsumerState<_CommentsSection> {
  final _controller = TextEditingController();
  final _deletingCommentIds = <String>{};
  List<OronBoxComment> _comments = const [];
  bool _loading = true;
  bool _sending = false;
  bool _hasMore = true;
  String? _replyTo;
  Object? _error;
  final _targetCommentKey = GlobalKey();
  bool _targetRevealed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await ref
          .read(oronBoxCommentsApiProvider)
          .list(
            widget.resourceId,
            before: more && _comments.isNotEmpty
                ? _comments.last.createdAt
                : null,
          );
      if (!mounted) return;
      setState(() {
        _comments = more ? [..._comments, ...page] : page;
        _hasMore = page.length == 20;
        _loading = false;
      });
      _revealTargetComment();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  void _revealTargetComment() {
    if (_targetRevealed || widget.targetCommentId.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final targetContext = _targetCommentKey.currentContext;
      if (!mounted) return;
      if (targetContext == null) {
        if (_hasMore && !_loading) unawaited(_load(more: true));
        return;
      }
      _targetRevealed = true;
      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        alignment: .25,
      );
    });
  }

  Key? _commentKey(OronBoxComment comment) =>
      comment.id == widget.targetCommentId ? _targetCommentKey : null;

  Future<bool> _send() async {
    final body = _controller.text.trim();
    if (body.isEmpty || _sending) return false;
    setState(() => _sending = true);
    try {
      final comment = await ref
          .read(oronBoxCommentsApiProvider)
          .create(widget.resourceId, body, parentId: _replyTo ?? '');
      if (!mounted) return false;
      setState(() {
        if (_replyTo == null) {
          _comments = [comment, ..._comments];
        } else {
          _comments = _comments
              .map(
                (item) => item.id == _replyTo
                    ? item.copyWith(replies: [...item.replies, comment])
                    : item,
              )
              .toList();
        }
        _replyTo = null;
        _controller.clear();
      });
      return true;
    } on CommentApiException catch (error) {
      if (!mounted) return false;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizedErrorMessage(l10n, error))),
      );
      return false;
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _compose({String? parentId}) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _replyTo = parentId);
    var dialogBusy = false;
    final sent = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: Text(
              parentId == null ? l10n.commentHint : l10n.commentReplying,
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: TextField(
                controller: _controller,
                enabled: !dialogBusy,
                autofocus: true,
                maxLength: 2000,
                minLines: 3,
                maxLines: 10,
                keyboardType: TextInputType.multiline,
                decoration: InputDecoration(
                  hintText: l10n.commentHint,
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: dialogBusy
                    ? null
                    : () => Navigator.pop(dialogContext, false),
                child: Text(l10n.cancel),
              ),
              FilledButton.icon(
                onPressed: dialogBusy
                    ? null
                    : () async {
                        setDialogState(() => dialogBusy = true);
                        final success = await _send();
                        if (!dialogContext.mounted) return;
                        if (success) {
                          Navigator.pop(dialogContext, true);
                        } else {
                          setDialogState(() => dialogBusy = false);
                        }
                      },
                icon: dialogBusy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_outlined),
                label: Text(parentId == null ? l10n.commentHint : l10n.reply),
              ),
            ],
          );
        },
      ),
    );
    if (sent != true && mounted) setState(() => _replyTo = null);
  }

  Future<void> _delete(OronBoxComment comment) async {
    if (_deletingCommentIds.contains(comment.id)) return;
    setState(() => _deletingCommentIds.add(comment.id));
    try {
      await ref.read(oronBoxCommentsApiProvider).delete(comment.id);
      await _load();
    } finally {
      if (mounted) setState(() => _deletingCommentIds.remove(comment.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final auth = ref.watch(hostAccountsProvider).bandbbs;
    final isAdmin = ref.watch(currentUserRoleProvider).value == 'admin';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.comments,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: auth.isSignedIn
                  ? () => _compose()
                  : () => context.push('/settings/bandbbs'),
              icon: Icon(auth.isSignedIn ? Icons.edit_outlined : Icons.login),
              label: Text(
                auth.isSignedIn ? l10n.commentHint : l10n.commentLoginRequired,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_loading && _comments.isEmpty)
          const Center(child: CircularProgressIndicator())
        else if (_error != null && _comments.isEmpty)
          TextButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: Text(l10n.retry),
          )
        else if (_comments.isEmpty)
          Text(l10n.commentEmpty)
        else
          for (final comment in _comments) ...[
            _CommentTile(
              key: _commentKey(comment),
              comment: comment,
              ownUserId: int.tryParse(auth.userId ?? ''),
              canModerate: isAdmin,
              deleting: _deletingCommentIds.contains(comment.id),
              onReply: () => _compose(parentId: comment.id),
              onDelete: () => _delete(comment),
              replies: [
                for (final reply in comment.replies)
                  _CommentTile(
                    key: _commentKey(reply),
                    comment: reply,
                    isReply: true,
                    ownUserId: int.tryParse(auth.userId ?? ''),
                    canModerate: isAdmin,
                    deleting: _deletingCommentIds.contains(reply.id),
                    onDelete: () => _delete(reply),
                  ),
              ],
            ),
          ],
        if (_hasMore && _comments.isNotEmpty)
          TextButton(
            onPressed: _loading ? null : () => _load(more: true),
            child: Text(l10n.loadMore),
          ),
      ],
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    super.key,
    required this.comment,
    required this.ownUserId,
    required this.canModerate,
    required this.deleting,
    this.isReply = false,
    this.onReply,
    required this.onDelete,
    this.replies = const [],
  });
  final OronBoxComment comment;
  final int? ownUserId;
  final bool canModerate;
  final bool deleting;
  final bool isReply;
  final VoidCallback? onReply;
  final VoidCallback onDelete;
  final List<Widget> replies;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final own = ownUserId == comment.bandBbsUserId;
    final date = comment.createdAt.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    final theme = Theme.of(context);
    final content = Padding(
      padding: EdgeInsets.all(isReply ? 10 : 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: isReply ? 14 : 18,
            backgroundImage: comment.avatarUrl.isEmpty
                ? null
                : NetworkImage(comment.avatarUrl),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        comment.username,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '${two(date.year % 100)}-${two(date.month)}-${two(date.day)} ${two(date.hour)}:${two(date.minute)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                Text(
                  l10n.bandBbsIdLabel(comment.bandBbsUserId),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Text(comment.body, style: theme.textTheme.bodyMedium),
                if (own && comment.moderationAction == 'review')
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      l10n.commentPending,
                      style: TextStyle(color: theme.colorScheme.tertiary),
                    ),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (onReply != null)
                      IconButton(
                        tooltip: l10n.reply,
                        visualDensity: VisualDensity.compact,
                        onPressed: onReply,
                        icon: const Icon(Icons.reply_outlined, size: 19),
                      ),
                    if (own || canModerate)
                      IconButton(
                        tooltip: l10n.delete,
                        visualDensity: VisualDensity.compact,
                        onPressed: deleting ? null : onDelete,
                        icon: deleting
                            ? const SizedBox.square(
                                dimension: 17,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.delete_outline, size: 19),
                      )
                    else
                      IconButton(
                        tooltip: l10n.report,
                        visualDensity: VisualDensity.compact,
                        onPressed: () => showFeedbackComposer(
                          context,
                          target: FeedbackTarget(
                            type: FeedbackTargetType.comment,
                            source: 'comment',
                            id: comment.id,
                            name: comment.username,
                          ),
                        ),
                        icon: const Icon(Icons.flag_outlined, size: 19),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (isReply) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: .48,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: content,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            content,
            if (replies.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
                child: Column(children: replies),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PreviewGallery extends StatelessWidget {
  const _PreviewGallery({required this.previews});
  final List<CommunityResourceImage> previews;

  static const _height = 240.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.preview,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 10),
        HorizontalScroller(
          height: _height,
          spacing: 12,
          children: [
            for (final image in previews)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _sized(image)
                    ? NetworkImgLayer(
                        src: image.url.toString(),
                        width: _height * _aspectOf(image),
                        height: _height,
                        fit: BoxFit.contain,
                      )
                    : NetworkImgAutoWidth(
                        src: image.url.toString(),
                        height: _height,
                      ),
              ),
          ],
        ),
      ],
    );
  }

  bool _sized(CommunityResourceImage image) =>
      image.width != null && image.height != null && image.height! > 0;

  double _aspectOf(CommunityResourceImage image) {
    final width = image.width;
    final height = image.height;
    if (width == null || height == null || height <= 0) return 3 / 2;
    return width / height;
  }
}

class _Actions extends ConsumerStatefulWidget {
  const _Actions({required this.detail, required this.currentCodename});
  final CommunityResourceDetail detail;
  final String currentCodename;

  @override
  ConsumerState<_Actions> createState() => _ActionsState();
}

class _ActionsState extends ConsumerState<_Actions> {
  String? _sizeKey;
  int? _preferredFileSize;
  bool _probeScheduled = false;

  CommunityResourceDetail get detail => widget.detail;
  String get currentCodename => widget.currentCodename;

  void _ensurePreferredFileSize(CommunityResourceFile? file) {
    if (file == null) return;
    final key = _fileSizeKey(file);
    if (key == _sizeKey || _probeScheduled) return;
    _probeScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _probeScheduled = false;
      if (mounted) _probeFileSize(file, key);
    });
  }

  Future<void> _probeFileSize(CommunityResourceFile file, String key) async {
    if (!mounted) return;
    setState(() {
      _sizeKey = key;
      _preferredFileSize = file.size;
    });
    if (file.size != null) return;
    try {
      final size = await ref
          .read(communityCatalogProviderForSource(detail.ref.source))
          .probeDownloadSize(file);
      if (!mounted || _sizeKey != key) return;
      setState(() => _preferredFileSize = size);
    } catch (_) {
      // A HEAD request is only an enhancement. The install action remains
      // usable when a source does not expose Content-Length.
    }
  }

  String _fileSizeKey(CommunityResourceFile file) =>
      '${file.id}|${file.downloadUrl}';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final files = detail.files;
    final choices = buildResourceInstallChoices(detail);
    final purchaseLink = detail.purchaseLink;
    if (files.isEmpty && purchaseLink == null) {
      return const SizedBox.shrink();
    }
    final preferred = preferredResourceInstallChoice(
      detail,
      choices,
      currentCodename,
    );
    final preferredFile = preferred?.file;
    _ensurePreferredFileSize(preferredFile);
    final preferredFileKey = preferredFile == null
        ? null
        : _fileSizeKey(preferredFile);
    final preferredFileSize = preferredFileKey == _sizeKey
        ? _preferredFileSize
        : preferredFile?.size;
    final inDownloadQueue = ref.watch(
      downloadQueueProvider.select(
        (tasks) => tasks.any(
          (task) =>
              task.resource.ref == detail.ref &&
              task.status != ResourceTaskStatus.completed,
        ),
      ),
    );
    final inInstallQueue = ref.watch(
      installQueueProvider.select(
        (state) => state.tasks.any(
          (task) =>
              task.resource?.ref == detail.ref &&
              task.status != ResourceTaskStatus.completed,
        ),
      ),
    );
    final inQueue = inDownloadQueue || inInstallQueue;
    final canInstall = detail.canDownload && !inQueue;
    void enqueue(ResourceInstallChoice choice) {
      final target = choice.codename.isNotEmpty
          ? choice.codename
          : currentCodename;
      final accepted = ref
          .read(downloadQueueProvider.notifier)
          .enqueue(resource: detail, file: choice.file, codename: target);
      if (!accepted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.downloadStarted)));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final expand = constraints.maxWidth < 520;
        final color = Theme.of(context).colorScheme;
        final baseLabel = inQueue ? l10n.productInQueue : l10n.install;
        final sizeLabel = preferredFileSize == null
            ? null
            : _formatResourceFileSize(preferredFileSize);
        final foreground = canInstall
            ? color.onPrimaryContainer
            : color.onSurface.withValues(alpha: .38);
        final buttonWidth = expand ? double.infinity : 200.0;
        final installButton = files.isEmpty
            ? null
            : SizedBox(
                width: buttonWidth,
                child: MenuAnchor(
                  style: const MenuStyle(
                    alignment: AlignmentDirectional.topEnd,
                  ),
                  alignmentOffset: const Offset(0, 4),
                  menuChildren: choices
                      .map(
                        (choice) => MenuItemButton(
                          onPressed: canInstall ? () => enqueue(choice) : null,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 280),
                            child: Text(
                              choice.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  builder: (_, controller, _) => ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Material(
                      color: canInstall
                          ? color.primaryContainer
                          : color.onSurface.withValues(alpha: .08),
                      child: SizedBox(
                        height: sizeLabel == null ? 48 : 58,
                        child: preferred == null
                            ? InkWell(
                                onTap: canInstall
                                    ? () => _toggleMenu(controller)
                                    : null,
                                child: _InstallButtonContent(
                                  label: baseLabel,
                                  sizeLabel: sizeLabel,
                                  color: foreground,
                                  trailing: const Icon(Icons.arrow_drop_down),
                                ),
                              )
                            : Row(
                                children: [
                                  Expanded(
                                    child: InkWell(
                                      onTap: canInstall
                                          ? () => enqueue(preferred)
                                          : null,
                                      child: _InstallButtonContent(
                                        label: baseLabel,
                                        sizeLabel: sizeLabel,
                                        color: foreground,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    height: 36,
                                    child: VerticalDivider(
                                      width: 1,
                                      color: foreground.withValues(alpha: .20),
                                    ),
                                  ),
                                  _InstallMenuHandle(
                                    enabled: canInstall && choices.length > 1,
                                    color: foreground,
                                    onTap: () => _toggleMenu(controller),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              );
        final purchaseButton = purchaseLink == null
            ? null
            : SizedBox(
                width: buttonWidth,
                child: FilledButton.icon(
                  onPressed: () =>
                      openResourceExternalLink(context, purchaseLink),
                  icon: const Icon(Icons.shopping_bag_outlined),
                  label: Text(_purchaseLabel(l10n, detail)),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.centerLeft,
                    backgroundColor: color.primaryContainer.withValues(
                      alpha: .58,
                    ),
                    foregroundColor: color.onPrimaryContainer,
                  ),
                ),
              );
        return Column(
          crossAxisAlignment: expand
              ? CrossAxisAlignment.stretch
              : CrossAxisAlignment.start,
          children: [
            if (installButton != null) installButton,
            if (installButton != null && purchaseButton != null)
              const SizedBox(height: 10),
            if (purchaseButton != null) purchaseButton,
          ],
        );
      },
    );
  }

  String _purchaseLabel(AppLocalizations l10n, CommunityResourceDetail detail) {
    final price = detail.purchasePrice;
    if (price == null) return l10n.resourcePurchaseFullVersion;
    final amount = price.toStringAsFixed(2);
    final base = l10n.resourcePurchaseFullVersion;
    return '$base (¥$amount)';
  }

  void _toggleMenu(MenuController controller) {
    if (controller.isOpen) {
      controller.close();
    } else {
      controller.open();
    }
  }
}

String _formatResourceFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) {
    final value = bytes / 1024;
    return '${value.toStringAsFixed(value >= 100 ? 0 : 1)} KB';
  }
  if (bytes < 1024 * 1024 * 1024) {
    final value = bytes / (1024 * 1024);
    return '${value.toStringAsFixed(value >= 100 ? 0 : 1)} MB';
  }
  final value = bytes / (1024 * 1024 * 1024);
  return '${value.toStringAsFixed(value >= 100 ? 0 : 2)} GB';
}

class ResourceInstallChoice {
  const ResourceInstallChoice({
    required this.file,
    required this.codename,
    required this.label,
  });

  final CommunityResourceFile file;
  final String codename;
  final String label;
}

List<ResourceInstallChoice> buildResourceInstallChoices(
  CommunityResourceDetail detail,
) {
  final choices = <ResourceInstallChoice>[];
  for (final file in detail.files) {
    if (detail.ref.source == CommunitySourceId.bandbbs ||
        detail.ref.source == CommunitySourceId.huamiAppStore) {
      choices.add(
        ResourceInstallChoice(file: file, codename: '', label: file.fileName),
      );
      continue;
    }
    final devices = file.supportedDevices.isNotEmpty
        ? file.supportedDevices
        : detail.supportedDevices;
    if (devices.isEmpty) {
      choices.add(
        ResourceInstallChoice(file: file, codename: '', label: file.label),
      );
      continue;
    }
    for (final device in devices) {
      final codename = normalizeXiaomiWearableCodename(device);
      if (codename.isEmpty) continue;
      choices.add(
        ResourceInstallChoice(
          file: file,
          codename: codename,
          label: xiaomiDisplayNameForIdentity(
            name: codename,
            codename: codename,
          ),
        ),
      );
    }
  }
  return choices;
}

ResourceInstallChoice? preferredResourceInstallChoice(
  CommunityResourceDetail detail,
  List<ResourceInstallChoice> choices,
  String currentCodename,
) {
  if (detail.ref.source == CommunitySourceId.huamiAppStore) {
    return choices.firstOrNull;
  }
  return choices
      .where((choice) => _matchesDevice(choice.file, currentCodename))
      .where(
        (choice) =>
            choice.codename.isEmpty ||
            normalizeXiaomiWearableCodename(choice.codename) == currentCodename,
      )
      .firstOrNull;
}

bool _matchesDevice(CommunityResourceFile file, String codename) {
  if (file.supportedDevices.isEmpty) return true;
  return file.supportedDevices
      .map(normalizeXiaomiWearableCodename)
      .contains(codename);
}

class _InstallButtonContent extends StatelessWidget {
  const _InstallButtonContent({
    required this.label,
    required this.color,
    this.sizeLabel,
    this.trailing,
  });

  final String label;
  final Color color;
  final String? sizeLabel;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => SizedBox.expand(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(Icons.download, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: color, fontWeight: FontWeight.w700),
                ),
                if (sizeLabel != null)
                  Text(
                    sizeLabel!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color.withValues(alpha: .72),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            IconTheme(
              data: IconThemeData(color: color),
              child: trailing!,
            ),
          ],
        ],
      ),
    ),
  );
}

class _InstallMenuHandle extends StatelessWidget {
  const _InstallMenuHandle({
    required this.enabled,
    required this.color,
    required this.onTap,
  });

  final bool enabled;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: double.infinity,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Icon(Icons.arrow_drop_down, color: color),
      ),
    );
  }
}

class _Compatibility extends StatelessWidget {
  const _Compatibility({
    required this.detail,
    required this.codename,
    required this.deviceName,
  });
  final CommunityResourceDetail detail;
  final String codename;
  final String deviceName;
  @override
  Widget build(BuildContext context) {
    final compatible = detail.files.any(
      (file) => _matchesDevice(file, codename),
    );
    final versions = detail.files
        .expand((file) => file.supportedDevices)
        .map(normalizeXiaomiWearableCodename)
        .where((value) => value.isNotEmpty)
        .toSet();
    final color = Theme.of(context).colorScheme;
    final statusColor = compatible ? Colors.green : color.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.productDeviceRequirements,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              compatible ? Icons.check_circle : Icons.cancel,
              size: 20,
              color: statusColor,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                compatible
                    ? '${AppLocalizations.of(context)!.compatible} $deviceName'
                    : '${AppLocalizations.of(context)!.incompatible} $deviceName ${AppLocalizations.of(context)!.incompatibleSuffix}',
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(color: statusColor, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        if (versions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.productOtherVersions,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: color.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: versions.map((version) {
              final selected = version == codename;
              return Chip(
                label: Text(
                  xiaomiDisplayNameForIdentity(
                    name: version,
                    codename: version,
                  ),
                ),
                backgroundColor: selected
                    ? color.primaryContainer
                    : color.surfaceContainerHighest,
                side: BorderSide.none,
                visualDensity: VisualDensity.compact,
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}
