import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/utils/error_localization.dart';
import 'package:oronbox/src/app/widgets/page_container.dart';
import 'package:oronbox/src/app/widgets/sys_app_bar.dart';
import 'package:oronbox/src/features/messages/application/message_center.dart';
import 'package:oronbox/src/features/messages/application/message_presentation.dart';

class InboxPage extends ConsumerWidget {
  const InboxPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(messageCenterProvider);
    return Scaffold(
      appBar: SysAppBar(
        secondary: true,
        title: Text(l10n.inbox),
        actions: [
          IconButton(
            tooltip: l10n.inboxClear,
            onPressed: state.value?.messages.isNotEmpty == true
                ? () async {
                    final cleared = await ref
                        .read(messageCenterProvider.notifier)
                        .clear();
                    if (!cleared && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.inboxClearFailed)),
                      );
                    }
                  }
                : null,
            icon: const Icon(Icons.clear_all),
          ),
        ],
      ),
      body: state.when(
        loading: () => LoadingView(message: l10n.inboxLoading),
        error: (error, _) =>
            Center(child: Text(localizedErrorMessage(l10n, error))),
        data: (value) => RefreshIndicator(
          onRefresh: () => ref.read(messageCenterProvider.notifier).refresh(),
          child: value.messages.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  children: [
                    PageContainer(
                      child: SizedBox(
                        height: MediaQuery.sizeOf(context).height * .65,
                        child: _InboxEmpty(message: l10n.inboxEmpty),
                      ),
                    ),
                  ],
                )
              : ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  children: [
                    PageContainer(
                      child: Column(
                        children: value.messages.map((message) {
                          final presentation = MessagePresentation.localize(
                            l10n,
                            message,
                          );
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
                                .withValues(alpha: .5),
                            clipBehavior: Clip.antiAlias,
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              leading: Icon(
                                message.read
                                    ? Icons.mail_outline
                                    : Icons.mark_email_unread,
                              ),
                              title: Text(
                                presentation.title,
                                style: TextStyle(
                                  fontWeight: message.read
                                      ? null
                                      : FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(presentation.body),
                                  const SizedBox(height: 4),
                                  Text(
                                    _messageTime(message.createdAt),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
                                  ),
                                ],
                              ),
                              onTap: () async {
                                final read = ref
                                    .read(messageCenterProvider.notifier)
                                    .read(message.id);
                                if (message.targetResourceId.isEmpty) {
                                  await read;
                                  return;
                                }
                                final query = Uri(
                                  queryParameters: {
                                    'source': 'oronBox',
                                    if (message.targetCommentId.isNotEmpty)
                                      'comment': message.targetCommentId,
                                  },
                                ).query;
                                context.go(
                                  '/resources/detail/${message.targetResourceId}?$query',
                                );
                                await read;
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  String _messageTime(DateTime value) {
    final date = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)} '
        '${two(date.hour)}:${two(date.minute)}';
  }
}

class _InboxEmpty extends StatelessWidget {
  const _InboxEmpty({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.notifications_none_rounded,
          size: 72,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 16),
        Text(message, textAlign: TextAlign.center),
      ],
    ),
  );
}
