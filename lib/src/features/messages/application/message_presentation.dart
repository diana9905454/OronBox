import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/features/messages/application/message_center.dart';

class MessagePresentation {
  const MessagePresentation({required this.title, required this.body});

  final String title;
  final String body;

  factory MessagePresentation.localize(
    AppLocalizations l10n,
    UserMessage message,
  ) {
    final data = message.data;
    String text(String key) => data[key]?.toString().trim() ?? '';
    bool flag(String key) => data[key] == true;
    String reasonOr(String fallback) {
      final reason = text('reason').isNotEmpty ? text('reason') : text('note');
      return reason.isEmpty ? fallback : l10n.messageReasonBody(reason);
    }

    String noteOr(String fallback) {
      final note = text('note');
      return note.isEmpty ? fallback : l10n.messageReviewNoteBody(note);
    }

    String amountFromUnits(Object? raw) {
      final units = raw is num ? raw.toDouble() : double.tryParse('$raw') ?? 0;
      final coins = units / 10;
      return coins == coins.roundToDouble()
          ? coins.toInt().toString()
          : coins.toStringAsFixed(1);
    }

    String reportStatus(String status) => switch (status) {
      'open' => l10n.feedbackOpen,
      'processing' => l10n.feedbackProcessing,
      'resolved' => l10n.feedbackResolved,
      'dismissed' => l10n.feedbackDismissed,
      'closed' => l10n.feedbackClosed,
      _ => '',
    };

    String accountRole(String role) => switch (role) {
      'user' => l10n.messageRoleUser,
      'reviewer' => l10n.messageRoleReviewer,
      'admin' => l10n.messageRoleAdministrator,
      _ => role,
    };

    final event = message.event;
    switch (event) {
      case 'comment.replied':
        return MessagePresentation(
          title: l10n.messageCommentRepliedTitle,
          body: text('body'),
        );
      case 'comment.hidden':
        return MessagePresentation(
          title: l10n.messageCommentHiddenTitle,
          body: flag('automated')
              ? l10n.messageCommentHiddenAutomatedBody
              : l10n.messageCommentHiddenReviewedBody,
        );
      case 'review.approved':
        return MessagePresentation(
          title: l10n.messageReviewApprovedTitle,
          body: l10n.messageApprovedBody,
        );
      case 'review.rejected':
        return MessagePresentation(
          title: l10n.messageReviewRejectedTitle,
          body: noteOr(l10n.messageNeedsChangesBody),
        );
      case 'resource.suspended':
        return MessagePresentation(
          title: l10n.messageResourceSuspendedTitle,
          body: reasonOr(l10n.messageStatusChangedBody),
        );
      case 'resource.frozen':
        return MessagePresentation(
          title: l10n.messageResourceFrozenTitle,
          body: reasonOr(l10n.messageStatusChangedBody),
        );
      case 'resource.deleted':
        return MessagePresentation(
          title: l10n.messageResourceDeletedTitle,
          body: reasonOr(l10n.messageStatusChangedBody),
        );
      case 'resource.restored':
        return MessagePresentation(
          title: l10n.messageResourceRestoredTitle,
          body: l10n.messageStatusChangedBody,
        );
      case 'report.updated':
        final resolution = text('resolution');
        final status = reportStatus(text('status'));
        return MessagePresentation(
          title: l10n.messageReportUpdatedTitle,
          body: resolution.isNotEmpty
              ? resolution
              : status.isEmpty
              ? l10n.messageStatusChangedBody
              : l10n.messageReportStatusBody(status),
        );
      case 'plugin.approved':
        return MessagePresentation(
          title: l10n.messagePluginApprovedTitle,
          body: l10n.messageApprovedBody,
        );
      case 'plugin.relisted':
        return MessagePresentation(
          title: l10n.messagePluginRelistedTitle,
          body: l10n.messageStatusChangedBody,
        );
      case 'plugin.rejected':
        return MessagePresentation(
          title: l10n.messagePluginRejectedTitle,
          body: reasonOr(l10n.messageNeedsChangesBody),
        );
      case 'plugin.delisted':
        return MessagePresentation(
          title: l10n.messagePluginDelistedTitle,
          body: reasonOr(l10n.messageStatusChangedBody),
        );
      case 'collection.approved':
        return MessagePresentation(
          title: l10n.messageCollectionApprovedTitle,
          body: l10n.messageApprovedBody,
        );
      case 'collection.rejected':
        return MessagePresentation(
          title: l10n.messageCollectionRejectedTitle,
          body: noteOr(l10n.messageNeedsChangesBody),
        );
      case 'coin.adjusted':
        final units = data['delta_units'];
        final positive = units is num && units > 0;
        final amount = amountFromUnits(units);
        return MessagePresentation(
          title: positive
              ? l10n.messageCoinAddedTitle
              : l10n.messageCoinDeductedTitle,
          body: reasonOr(
            positive
                ? l10n.messageCoinAddedBody(amount)
                : l10n.messageCoinDeductedBody(amount),
          ),
        );
      case 'coin.reversed':
        return MessagePresentation(
          title: l10n.messageCoinReversedTitle,
          body: reasonOr(l10n.messageStatusChangedBody),
        );
      case 'coin.vote_revoked':
        return MessagePresentation(
          title: l10n.messageCoinVoteRevokedTitle,
          body: reasonOr(l10n.messageCoinVoteRevokedBody(text('coins'))),
        );
      case 'appeal.overturned':
        return MessagePresentation(
          title: l10n.messageAppealOverturnedTitle,
          body: text('resolution').isEmpty
              ? l10n.messageAppealOverturnedBody
              : text('resolution'),
        );
      case 'appeal.upheld':
        return MessagePresentation(
          title: l10n.messageAppealUpheldTitle,
          body: text('resolution').isEmpty
              ? l10n.messageAppealUpheldBody
              : text('resolution'),
        );
      case 'appeal.dismissed':
        return MessagePresentation(
          title: l10n.messageAppealDismissedTitle,
          body: text('resolution').isEmpty
              ? l10n.messageAppealDismissedBody
              : text('resolution'),
        );
      case 'account.ban':
        return MessagePresentation(
          title: l10n.messageAccountBannedTitle,
          body: reasonOr(l10n.messageStatusChangedBody),
        );
      case 'account.unban':
        return MessagePresentation(
          title: l10n.messageAccountUnbannedTitle,
          body: l10n.messageStatusChangedBody,
        );
      case 'account.freeze_creator':
        return MessagePresentation(
          title: l10n.messageCreatorFrozenTitle,
          body: reasonOr(l10n.messageStatusChangedBody),
        );
      case 'account.unfreeze_creator':
        return MessagePresentation(
          title: l10n.messageCreatorUnfrozenTitle,
          body: l10n.messageStatusChangedBody,
        );
      case 'account.set_role':
        return MessagePresentation(
          title: l10n.messageRoleChangedTitle,
          body: l10n.messageRoleChangedBody(accountRole(text('role'))),
        );
      case 'admin.message':
      case 'announcement.published':
        return MessagePresentation(title: text('title'), body: text('body'));
      default:
        if (message.legacyTitle.isNotEmpty || message.legacyBody.isNotEmpty) {
          return MessagePresentation(
            title: message.legacyTitle,
            body: message.legacyBody,
          );
        }
        return MessagePresentation(
          title: l10n.messageUnknownTitle,
          body: l10n.messageUnknownBody,
        );
    }
  }
}
