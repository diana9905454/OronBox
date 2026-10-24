part of 'resource_detail_page.dart';

class CommentThreadPage extends ConsumerStatefulWidget {
  const CommentThreadPage({
    super.key,
    this.resourceId = '',
    required this.commentId,
  });
  final String resourceId, commentId;
  @override
  ConsumerState<CommentThreadPage> createState() => CommentThreadPageState();
}

class CommentThreadPageState extends ConsumerState<CommentThreadPage> {
  final _input = TextEditingController();
  final _targetKey = GlobalKey();
  OronBoxCommentThread? _thread;
  List<OronBoxComment> _replies = [];
  OronBoxComment? _replyTarget;
  Object? _error;
  bool _loading = false, _sending = false, _revealed = false;
  String _next = '', _previous = '';
  int _request = 0;
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _load({
    String? target,
    bool earlier = false,
    bool more = false,
  }) async {
    if (_loading) return;
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final value = await ref
          .read(oronBoxCommentsApiProvider)
          .thread(
            target ?? _thread?.root.id ?? widget.commentId,
            before: earlier ? _previous : '',
            after: more ? _next : '',
          );
      if (!mounted || request != _request) return;
      if (widget.resourceId.isNotEmpty &&
          value.resourceId != widget.resourceId) {
        throw const CommentApiException(
          'wrong_resource',
          'Comment does not belong to this resource',
        );
      }
      setState(() {
        _thread = value;
        final merged = earlier
            ? [...value.replies, ..._replies]
            : more
            ? [..._replies, ...value.replies]
            : value.replies;
        _replies = {for (final c in merged) c.id: c}.values.toList();
        if (!more) _previous = value.previousCursor;
        if (!earlier) _next = value.nextCursor;
      });
      if (!_revealed) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _targetKey.currentContext == null) return;
          _revealed = true;
          Scrollable.ensureVisible(
            _targetKey.currentContext!,
            alignment: .25,
            duration: const Duration(milliseconds: 250),
          );
        });
      }
    } catch (error) {
      if (mounted && request == _request) setState(() => _error = error);
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final thread = _thread;
    final body = _input.text.trim();
    if (thread == null || thread.root.deleted || body.isEmpty || _sending) {
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final comment = await ref
          .read(oronBoxCommentsApiProvider)
          .create(
            thread.resourceId,
            body,
            parentId: _replyTarget?.id ?? thread.root.id,
          );
      if (!mounted) return;
      if (comment.moderationAction == 'block') {
        setState(
          () => _error = const CommentApiException('comment_blocked', ''),
        );
        return;
      }
      _input.clear();
      setState(() => _replyTarget = null);
      await _load(target: comment.id);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _delete(OronBoxComment comment) async {
    try {
      await ref.read(oronBoxCommentsApiProvider).delete(comment.id);
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    ref.listen(
      hostAccountsProvider.select(
        (value) => (value.bandbbs.isSignedIn, value.bandbbs.userId),
      ),
      (previous, next) {
        setState(() {
          _thread = null;
          _replies = [];
          _replyTarget = null;
          _input.clear();
          _next = _previous = '';
          _loading = false;
        });
        unawaited(_load());
      },
    );
    final account = ref.watch(hostAccountsProvider).bandbbs;
    final ownUID = int.tryParse(account.userId ?? '');
    final thread = _thread;
    Widget tile(OronBoxComment c, {bool reply = false}) => _CommentTile(
      key: c.id == widget.commentId ? _targetKey : ValueKey(c.id),
      comment: c,
      ownUserId: ownUID,
      canModerate: false,
      deleting: false,
      isReply: reply,
      onReply: thread?.root.deleted == true
          ? null
          : () => setState(() => _replyTarget = c),
      onDelete: () => _delete(c),
    );
    return Scaffold(
      appBar: SysAppBar(secondary: true, title: Text(l10n.commentThreadTitle)),
      body: SafeArea(
        child: Column(
          children: [
            if (thread != null)
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * .35,
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: tile(thread.root),
                  ),
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(localizedErrorMessage(l10n, _error!)),
              ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    if (_previous.isNotEmpty)
                      TextButton(
                        onPressed: _loading ? null : () => _load(earlier: true),
                        child: Text(l10n.commentLoadEarlier),
                      ),
                    for (final reply in _replies) tile(reply, reply: true),
                    if (_loading)
                      const Center(child: CircularProgressIndicator()),
                    if (!_loading && _replies.isEmpty && thread != null)
                      Text(l10n.commentEmpty),
                    if (_next.isNotEmpty)
                      TextButton(
                        onPressed: _loading ? null : () => _load(more: true),
                        child: Text(l10n.loadMore),
                      ),
                    if (_error != null)
                      TextButton(
                        onPressed: _loading ? null : () => _load(),
                        child: Text(l10n.retry),
                      ),
                  ],
                ),
              ),
            ),
            if (thread != null && !thread.root.deleted)
              Padding(
                padding: const EdgeInsets.all(12),
                child: !account.isSignedIn
                    ? Text(l10n.commentLoginRequired)
                    : Column(
                        children: [
                          if (_replyTarget != null)
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    l10n.commentReplyTarget(
                                      _replyTarget!.username,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () =>
                                      setState(() => _replyTarget = null),
                                  icon: const Icon(Icons.close),
                                ),
                              ],
                            ),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _input,
                                  minLines: 1,
                                  maxLines: 4,
                                  maxLength: 2000,
                                  decoration: InputDecoration(
                                    hintText: l10n.commentHint,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: _sending || _loading ? null : _send,
                                icon: _sending
                                    ? const CircularProgressIndicator()
                                    : const Icon(Icons.send_outlined),
                              ),
                            ],
                          ),
                        ],
                      ),
              ),
          ],
        ),
      ),
    );
  }
}
