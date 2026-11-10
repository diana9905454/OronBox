import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/theme/app_theme.dart';
import 'package:oronbox/src/app/utils/error_localization.dart';
import 'package:oronbox/src/app/widgets/app_state_view.dart';
import 'package:oronbox/src/app/widgets/page_container.dart';
import 'package:oronbox/src/app/widgets/sys_app_bar.dart';
import 'package:oronbox/src/core/constants/style_constants.dart';
import 'package:oronbox/src/features/settings/services/oronbox_support_api.dart';

enum FeedbackTargetType { resource, comment }

String _ticketTime(DateTime value) {
  final time = value.toLocal();
  String two(int part) => part.toString().padLeft(2, '0');
  return '${time.year}-${two(time.month)}-${two(time.day)} '
      '${two(time.hour)}:${two(time.minute)}';
}

Future<FeedbackTicket?> showFeedbackComposer(
  BuildContext context, {
  FeedbackTarget? target,
}) => showDialog<FeedbackTicket>(
  context: context,
  builder: (context) => _FeedbackComposer(target: target),
);

class FeedbackTarget {
  const FeedbackTarget({
    required this.type,
    required this.source,
    required this.id,
    required this.name,
    this.url = '',
  });

  final FeedbackTargetType type;
  final String source, id, name, url;

  String get reportKind => switch (type) {
    FeedbackTargetType.resource => 'resource_report',
    FeedbackTargetType.comment => 'comment_report',
  };
}

bool _isReportKind(String kind) =>
    kind == 'resource_report' || kind == 'comment_report';

String _reportTitle(AppLocalizations l10n, FeedbackTarget target) =>
    target.type == FeedbackTargetType.comment
    ? l10n.reportComment
    : l10n.reportResource;

class FeedbackPage extends ConsumerStatefulWidget {
  const FeedbackPage({super.key, this.target});

  final FeedbackTarget? target;

  @override
  ConsumerState<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends ConsumerState<FeedbackPage> {
  List<FeedbackTicket>? _tickets;
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _reload();
    if (widget.target != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _compose());
    }
  }

  Future<void> _reload() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final tickets = await ref.read(oronBoxSupportApiProvider).feedback();
      if (!mounted) return;
      setState(() {
        _tickets = tickets;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  void _open(FeedbackTicket ticket) {
    unawaited(
      context
          .push<void>('/settings/feedback/ticket', extra: ticket)
          .then((_) => _reload()),
    );
  }

  Future<void> _compose() async {
    final created = await showFeedbackComposer(context, target: widget.target);
    if (created == null || !mounted) return;
    await _reload();
    if (mounted) _open(created);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: SysAppBar(
        secondary: true,
        title: Text(
          widget.target == null
              ? l10n.feedbackTitle
              : _reportTitle(l10n, widget.target!),
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : _reload,
            tooltip: l10n.refresh,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: _compose,
            tooltip: l10n.feedbackNewTicket,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: _TicketList(
        tickets: _tickets ?? const [],
        loading: _loading,
        error: _error,
        onRetry: _reload,
        onSelect: _open,
        onCreate: _compose,
      ),
    );
  }
}

class FeedbackTicketPage extends ConsumerStatefulWidget {
  const FeedbackTicketPage({super.key, required this.ticket});

  final FeedbackTicket ticket;

  @override
  ConsumerState<FeedbackTicketPage> createState() => _FeedbackTicketPageState();
}

class _FeedbackTicketPageState extends ConsumerState<FeedbackTicketPage> {
  late FeedbackTicket _ticket = widget.ticket;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final detail = await ref
          .read(oronBoxSupportApiProvider)
          .feedbackDetail(widget.ticket.id);
      if (mounted) setState(() => _ticket = detail);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SysAppBar(
        secondary: true,
        title: Text(
          _ticket.subject,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(child: _TicketStatus(status: _ticket.status)),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: _TicketDetail(
              ticket: _ticket,
              onUpdated: (ticket) => setState(() => _ticket = ticket),
            ),
          ),
        ),
      ),
    );
  }
}

class _TicketList extends StatelessWidget {
  const _TicketList({
    required this.tickets,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.onSelect,
    required this.onCreate,
  });

  final List<FeedbackTicket> tickets;
  final bool loading;
  final Object? error;
  final VoidCallback onRetry;
  final ValueChanged<FeedbackTicket> onSelect;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (loading && tickets.isEmpty) {
      return PageContainer(child: LoadingView(message: l10n.feedbackLoading));
    }
    if (error != null && tickets.isEmpty) {
      return PageContainer(
        child: ErrorStateView(
          message: localizedErrorMessage(l10n, error),
          onRetry: onRetry,
        ),
      );
    }
    if (tickets.isEmpty) {
      return PageContainer(child: _TicketPlaceholder(onCreate: onCreate));
    }
    return RefreshIndicator(
      onRefresh: () async => onRetry(),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(
          bottom: bottomContentPadding(context, extra: 24),
        ),
        itemCount: 1,
        separatorBuilder: (_, _) => const SizedBox.shrink(),
        itemBuilder: (context, _) => PageContainer(
          child: Column(
            children: [
              for (var index = 0; index < tickets.length; index++) ...[
                if (index > 0) const SizedBox(height: StyleConstants.cardSpace),
                Builder(
                  builder: (context) {
                    final ticket = tickets[index];
                    return Card(
                      margin: EdgeInsets.zero,
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: .5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          StyleConstants.cardRadius,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        leading: Icon(
                          _isReportKind(ticket.kind)
                              ? Icons.flag_outlined
                              : Icons.chat_bubble_outline,
                        ),
                        title: Text(ticket.subject, maxLines: 1),
                        subtitle: Text(
                          ticket.message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: _TicketStatus(
                          status: ticket.status,
                          compact: true,
                        ),
                        onTap: () => onSelect(ticket),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TicketDetail extends ConsumerStatefulWidget {
  const _TicketDetail({required this.ticket, required this.onUpdated});

  final FeedbackTicket ticket;
  final ValueChanged<FeedbackTicket> onUpdated;

  @override
  ConsumerState<_TicketDetail> createState() => _TicketDetailState();
}

class _TicketDetailState extends ConsumerState<_TicketDetail> {
  final _reply = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final message = _reply.text.trim();
    if (message.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final ticket = await ref
          .read(oronBoxSupportApiProvider)
          .replyFeedback(widget.ticket.id, message);
      _reply.clear();
      widget.onUpdated(ticket);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizedErrorMessage(AppLocalizations.of(context)!, error),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final ticket = widget.ticket;
    final canReply = ticket.status != 'closed' && ticket.status != 'dismissed';
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 20),
            children: [
              _MessageBubble(
                author: l10n.feedbackYou,
                message: ticket.message,
                time: ticket.createdAt,
                mine: true,
              ),
              for (final reply in ticket.replies)
                _MessageBubble(
                  author: reply.author,
                  message: reply.message,
                  time: reply.createdAt,
                ),
              if (ticket.resolution.isNotEmpty &&
                  !ticket.replies.any(
                    (reply) => reply.message == ticket.resolution,
                  ))
                _MessageBubble(
                  author: l10n.feedbackResolution,
                  message: ticket.resolution,
                  time: ticket.updatedAt,
                ),
            ],
          ),
        ),
        if (canReply)
          Material(
            color: Theme.of(context).colorScheme.surfaceContainer,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _reply,
                        minLines: 1,
                        maxLines: 5,
                        decoration: InputDecoration(
                          hintText: l10n.feedbackReplyHint,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _sending ? null : _send,
                      icon: Icon(
                        _sending
                            ? Icons.hourglass_top_rounded
                            : Icons.send_outlined,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(l10n.feedbackConversationClosed),
          ),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.author,
    required this.message,
    required this.time,
    this.mine = false,
  });

  final String author, message;
  final DateTime time;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 620),
        margin: const EdgeInsets.fromLTRB(16, 5, 16, 5),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: mine
              ? context.appSelectionContainer
              : colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(author, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            SelectableText(message),
            const SizedBox(height: 6),
            Text(
              _ticketTime(time),
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _TicketStatus extends StatelessWidget {
  const _TicketStatus({required this.status, this.compact = false});

  final String status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final (label, color) = switch (status) {
      'open' => (l10n.feedbackOpen, Theme.of(context).colorScheme.primary),
      'investigating' => (
        l10n.feedbackProcessing,
        Theme.of(context).colorScheme.tertiary,
      ),
      'replied' => (
        l10n.feedbackReplied,
        Theme.of(context).colorScheme.secondary,
      ),
      'resolved' => (l10n.feedbackResolved, context.appColors.success),
      'dismissed' => (
        l10n.feedbackDismissed,
        Theme.of(context).colorScheme.error,
      ),
      'closed' => (l10n.feedbackClosed, Theme.of(context).colorScheme.outline),
      _ => (status, Theme.of(context).colorScheme.outline),
    };
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 9,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}

class _TicketPlaceholder extends StatelessWidget {
  const _TicketPlaceholder({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return EmptyStateView(
      icon: Icons.forum_outlined,
      title: l10n.noFeedback,
      action: FilledButton.icon(
        onPressed: onCreate,
        icon: const Icon(Icons.add),
        label: Text(l10n.feedbackNewTicket),
      ),
    );
  }
}

class _FeedbackComposer extends ConsumerStatefulWidget {
  const _FeedbackComposer({this.target});

  final FeedbackTarget? target;

  @override
  ConsumerState<_FeedbackComposer> createState() => _FeedbackComposerState();
}

class _FeedbackComposerState extends ConsumerState<_FeedbackComposer> {
  final _subject = TextEditingController();
  final _message = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    if (widget.target != null) _subject.text = widget.target!.name;
  }

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_subject.text.trim().isEmpty ||
        _message.text.trim().isEmpty ||
        _sending) {
      return;
    }
    setState(() => _sending = true);
    try {
      final ticket = await ref
          .read(oronBoxSupportApiProvider)
          .createFeedback(
            kind: widget.target?.reportKind ?? 'feedback',
            subject: _subject.text.trim(),
            message: _message.text.trim(),
            targetSource: widget.target?.source ?? '',
            targetId: widget.target?.id ?? '',
            targetUrl: widget.target?.url ?? '',
          );
      if (mounted) Navigator.pop(context, ticket);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizedErrorMessage(AppLocalizations.of(context)!, error),
            ),
          ),
        );
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(
        widget.target == null
            ? l10n.feedbackNewTicket
            : _reportTitle(l10n, widget.target!),
      ),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.target case final target?)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.flag_outlined),
                title: Text(target.name),
                subtitle: Text('${target.source} · ${target.id}'),
              ),
            TextField(
              controller: _subject,
              maxLength: 120,
              autofocus: widget.target == null,
              decoration: InputDecoration(labelText: l10n.feedbackSubject),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _message,
              maxLength: 10000,
              minLines: 5,
              maxLines: 10,
              decoration: InputDecoration(
                labelText: widget.target == null
                    ? l10n.feedbackMessage
                    : l10n.reportReason,
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton.icon(
          onPressed: _sending ? null : _submit,
          icon: Icon(
            _sending ? Icons.hourglass_top_rounded : Icons.send_outlined,
          ),
          label: Text(l10n.submit),
        ),
      ],
    );
  }
}

class FeedbackTicketLinkPage extends ConsumerStatefulWidget {
  const FeedbackTicketLinkPage({super.key, required this.ticketId});
  final String ticketId;
  @override
  ConsumerState<FeedbackTicketLinkPage> createState() =>
      _FeedbackTicketLinkPageState();
}

class _FeedbackTicketLinkPageState
    extends ConsumerState<FeedbackTicketLinkPage> {
  late Future<FeedbackTicket> _future = ref
      .read(oronBoxSupportApiProvider)
      .feedbackDetail(widget.ticketId);
  @override
  Widget build(BuildContext context) => FutureBuilder<FeedbackTicket>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.hasData) return FeedbackTicketPage(ticket: snapshot.data!);
      final l10n = AppLocalizations.of(context)!;
      return Scaffold(
        appBar: SysAppBar(secondary: true, title: Text(l10n.feedbackTitle)),
        body: Center(
          child: snapshot.hasError
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(localizedErrorMessage(l10n, snapshot.error!)),
                    TextButton(
                      onPressed: () => setState(
                        () => _future = ref
                            .read(oronBoxSupportApiProvider)
                            .feedbackDetail(widget.ticketId),
                      ),
                      child: Text(l10n.retry),
                    ),
                  ],
                )
              : const CircularProgressIndicator(),
        ),
      );
    },
  );
}
