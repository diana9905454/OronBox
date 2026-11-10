import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/features/messages/application/message_center.dart';

class MessagePresentation {
  const MessagePresentation({required this.title, required this.body});

  final String title;
  final String body;

  static String _targetName(String target) => switch (target.toLowerCase()) {
    'oronbox' => 'OronBox',
    'bandbbs' => 'BandBBS',
    'astrobox' => 'AstroBox',
    _ => target,
  };

  static String _formatTargetsSummary(AppLocalizations l10n, Object? raw) {
    if (raw is! List) return '';
    final entries = <String>[];
    for (final item in raw) {
      if (item is Map) {
        final target = item['target']?.toString() ?? '';
        final state = item['state']?.toString() ?? '';
        if (target.isNotEmpty) {
          final label = _targetName(target);
          final status = switch (state) {
            'pending' || 'running' => l10n.creatorStatePublishing,
            'reviewing' => l10n.creatorStateExternalReview,
            'published' => l10n.published,
            'failed' => l10n.creatorStateFailed,
            'cancelled' => l10n.creatorStateCancelled,
            _ => '',
          };
          entries.add(status.isNotEmpty ? '$label ($status)' : label);
        }
      } else if (item is String && item.isNotEmpty) {
        entries.add(_targetName(item));
      }
    }
    return entries.join(', ');
  }

  static String _extractUnapprovedItems(Object? raw) {
    if (raw is! List) return '';
    final issues = <String>[];
    for (final item in raw) {
      if (item is String && item.trim().isNotEmpty) {
        issues.add(item.trim());
      } else if (item is Map) {
        final passed = item['passed'] == true || item['state'] == 'pass';
        if (!passed) {
          final name = item['name'] ?? item['title'] ?? item['key'];
          final note = item['note'] ?? item['reason'];
          if (name != null) {
            issues.add(note != null ? '$name ($note)' : '$name');
          }
        }
      }
    }
    return issues.join(', ');
  }

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

    String formatSubject(String baseTitle) {
      final name = text('resource_name').isNotEmpty
          ? text('resource_name')
          : text('collection_name').isNotEmpty
          ? text('collection_name')
          : text('plugin_name').isNotEmpty
          ? text('plugin_name')
          : (text('title').isNotEmpty && text('title') != baseTitle)
          ? text('title')
          : '';
      final version = text('version');
      if (name.isEmpty && version.isEmpty) return baseTitle;
      if (name.isNotEmpty && version.isNotEmpty) {
        return '$name $version · $baseTitle';
      }
      if (name.isNotEmpty) return '$name · $baseTitle';
      return '$version · $baseTitle';
    }

    String accountRole(String role) => switch (role) {
      'user' => l10n.messageRoleUser,
      'reviewer' => l10n.messageRoleReviewer,
      'admin' => l10n.messageRoleAdministrator,
      _ => role,
    };

    final event = message.event;
    switch (event) {
      case 'comment.created':
        final author = text('author_name');
        final title = formatSubject(l10n.messageCommentCreatedTitle);
        final bodyText = text('body').isEmpty
            ? message.legacyBody
            : text('body');
        final fullBody = author.isNotEmpty ? '$author: $bodyText' : bodyText;
        return MessagePresentation(title: title, body: fullBody);
      case 'comment.replied':
        final author = text('author_name').isNotEmpty
            ? text('author_name')
            : text('author');
        final resName = text('resource_name');
        final title = [
          if (author.isNotEmpty) author,
          if (resName.isNotEmpty) resName,
          l10n.messageCommentRepliedTitle,
        ].join(' · ');
        final parentBody = text('parent_body');
        final body = text('body');
        final fullBody = parentBody.isNotEmpty
            ? '> $parentBody\n\n$body'
            : body;
        return MessagePresentation(title: title, body: fullBody);
      case 'comment.hidden':
        final commentBody = text('comment_body');
        final reason = text('reason');
        final baseReason = reason.isNotEmpty
            ? l10n.messageReasonBody(reason)
            : flag('automated')
            ? l10n.messageCommentHiddenAutomatedBody
            : l10n.messageCommentHiddenReviewedBody;
        final fullBody = commentBody.isNotEmpty
            ? '> $commentBody\n\n$baseReason'
            : baseReason;
        return MessagePresentation(
          title: formatSubject(l10n.messageCommentHiddenTitle),
          body: fullBody,
        );
      case 'review.approved':
        final note = text('note');
        final reviewer = text('reviewer_name');
        final targetsList = data['targets'];
        final targetSummary = _formatTargetsSummary(l10n, targetsList);
        final paragraphs = <String>[];
        if (note.isNotEmpty) {
          paragraphs.add(l10n.messageReviewNoteBody(note));
        } else if (reviewer.isEmpty && targetSummary.isEmpty) {
          paragraphs.add(l10n.messageApprovedBody);
        }
        if (reviewer.isNotEmpty) {
          paragraphs.add(l10n.messageReviewerPrefix(reviewer));
        }
        if (targetSummary.isNotEmpty) {
          paragraphs.add(l10n.messageTargetsPrefix(targetSummary));
        }
        return MessagePresentation(
          title: formatSubject(l10n.messageReviewApprovedTitle),
          body: paragraphs.join('\n'),
        );
      case 'review.rejected':
        final note = text('note').isNotEmpty ? text('note') : text('reason');
        final reviewer = text('reviewer_name');
        final unapprovedItems = _extractUnapprovedItems(data['items']);
        final paragraphs = <String>[];
        if (note.isNotEmpty) {
          paragraphs.add(l10n.messageReviewNoteBody(note));
        } else {
          paragraphs.add(l10n.messageNeedsChangesBody);
        }
        if (unapprovedItems.isNotEmpty) {
          paragraphs.add(l10n.messageUnapprovedItemsPrefix(unapprovedItems));
        }
        if (reviewer.isNotEmpty) {
          paragraphs.add(l10n.messageReviewerPrefix(reviewer));
        }
        return MessagePresentation(
          title: formatSubject(l10n.messageReviewRejectedTitle),
          body: paragraphs.join('\n'),
        );
      case 'resource.suspended':
      case 'resource.frozen':
      case 'resource.deleted':
      case 'resource.restored':
        final title = switch (event) {
          'resource.suspended' => formatSubject(
            l10n.messageResourceSuspendedTitle,
          ),
          'resource.frozen' => formatSubject(l10n.messageResourceFrozenTitle),
          'resource.deleted' => formatSubject(l10n.messageResourceDeletedTitle),
          _ => formatSubject(l10n.messageResourceRestoredTitle),
        };
        final lines = <String>[];
        final reason = text('reason');
        if (reason.isNotEmpty) {
          lines.add(l10n.messageReasonBody(reason));
        } else {
          lines.add(l10n.messageStatusChangedBody);
        }
        final operator = text('operator_name').isNotEmpty
            ? text('operator_name')
            : text('moderator_name');
        if (operator.isNotEmpty) {
          lines.add(l10n.messageOperatorPrefix(operator));
        }
        return MessagePresentation(title: title, body: lines.join('\n'));
      case 'report.updated':
        final subject = text('ticket_subject').isNotEmpty
            ? text('ticket_subject')
            : text('target_name');
        final title = subject.isNotEmpty
            ? '$subject · ${l10n.messageReportUpdatedTitle}'
            : l10n.messageReportUpdatedTitle;
        final resolution = text('resolution');
        final status = reportStatus(text('status'));
        final quote = text('ticket_message');
        final lines = <String>[];
        if (quote.isNotEmpty) {
          lines.add('> $quote\n');
        }
        if (resolution.isNotEmpty) {
          lines.add(resolution);
        } else if (status.isNotEmpty) {
          lines.add(l10n.messageReportStatusBody(status));
        } else {
          lines.add(l10n.messageStatusChangedBody);
        }
        final handler = text('handler_name').isNotEmpty
            ? text('handler_name')
            : text('operator_name');
        if (handler.isNotEmpty) {
          lines.add(l10n.messageOperatorPrefix(handler));
        }
        return MessagePresentation(title: title, body: lines.join('\n'));
      case 'plugin.approved':
        return MessagePresentation(
          title: formatSubject(l10n.messagePluginApprovedTitle),
          body: l10n.messageApprovedBody,
        );
      case 'plugin.relisted':
        return MessagePresentation(
          title: formatSubject(l10n.messagePluginRelistedTitle),
          body: l10n.messageStatusChangedBody,
        );
      case 'plugin.rejected':
        return MessagePresentation(
          title: formatSubject(l10n.messagePluginRejectedTitle),
          body: reasonOr(l10n.messageNeedsChangesBody),
        );
      case 'plugin.delisted':
        return MessagePresentation(
          title: formatSubject(l10n.messagePluginDelistedTitle),
          body: reasonOr(l10n.messageStatusChangedBody),
        );
      case 'collection.approved':
        return MessagePresentation(
          title: formatSubject(l10n.messageCollectionApprovedTitle),
          body: l10n.messageApprovedBody,
        );
      case 'collection.rejected':
        return MessagePresentation(
          title: formatSubject(l10n.messageCollectionRejectedTitle),
          body: noteOr(l10n.messageNeedsChangesBody),
        );
      case 'coin.adjusted':
        final units = data['delta_units'];
        final positive = units is num && units > 0;
        final amount = amountFromUnits(units);
        final lines = <String>[
          positive
              ? l10n.messageCoinAddedBody(amount)
              : l10n.messageCoinDeductedBody(amount),
        ];
        final refName = text('reference_name');
        if (refName.isNotEmpty) {
          lines.add(l10n.messageReferencePrefix(refName));
        }
        final reason = text('reason');
        if (reason.isNotEmpty) {
          lines.add(l10n.messageReasonBody(reason));
        }
        final operator = text('operator_name');
        if (operator.isNotEmpty) {
          lines.add(l10n.messageOperatorPrefix(operator));
        }
        return MessagePresentation(
          title: positive
              ? l10n.messageCoinAddedTitle
              : l10n.messageCoinDeductedTitle,
          body: lines.join('\n'),
        );
      case 'coin.reversed':
        final lines = <String>[];
        final reason = text('reason');
        lines.add(
          reason.isNotEmpty
              ? l10n.messageReasonBody(reason)
              : l10n.messageStatusChangedBody,
        );
        final refName = text('reference_name');
        if (refName.isNotEmpty) {
          lines.add(l10n.messageReferencePrefix(refName));
        }
        return MessagePresentation(
          title: l10n.messageCoinReversedTitle,
          body: lines.join('\n'),
        );
      case 'coin.vote_revoked':
        final lines = <String>[l10n.messageCoinVoteRevokedBody(text('coins'))];
        final reason = text('reason');
        if (reason.isNotEmpty) {
          lines.add(l10n.messageReasonBody(reason));
        }
        final operator = text('operator_name');
        if (operator.isNotEmpty) {
          lines.add(l10n.messageOperatorPrefix(operator));
        }
        return MessagePresentation(
          title: formatSubject(l10n.messageCoinVoteRevokedTitle),
          body: lines.join('\n'),
        );
      case 'appeal.overturned':
      case 'appeal.upheld':
      case 'appeal.dismissed':
        final subject = text('subject_name');
        final baseTitle = switch (event) {
          'appeal.overturned' => l10n.messageAppealOverturnedTitle,
          'appeal.upheld' => l10n.messageAppealUpheldTitle,
          _ => l10n.messageAppealDismissedTitle,
        };
        final title = subject.isNotEmpty ? '$subject · $baseTitle' : baseTitle;
        final defaultBody = switch (event) {
          'appeal.overturned' => l10n.messageAppealOverturnedBody,
          'appeal.upheld' => l10n.messageAppealUpheldBody,
          _ => l10n.messageAppealDismissedBody,
        };
        final resolution = text('resolution').isNotEmpty
            ? text('resolution')
            : defaultBody;
        final quote = text('appeal_message');
        final handler = text('handler_name');
        final lines = <String>[];
        if (quote.isNotEmpty) {
          lines.add('> $quote\n');
        }
        lines.add(resolution);
        if (handler.isNotEmpty) {
          lines.add(l10n.messageOperatorPrefix(handler));
        }
        return MessagePresentation(title: title, body: lines.join('\n'));
      case 'account.ban':
      case 'account.freeze_creator':
        final title = event == 'account.ban'
            ? l10n.messageAccountBannedTitle
            : l10n.messageCreatorFrozenTitle;
        final lines = <String>[];
        final reason = text('reason');
        if (reason.isNotEmpty) {
          lines.add(l10n.messageReasonBody(reason));
        } else {
          lines.add(l10n.messageStatusChangedBody);
        }
        final operator = text('operator_name');
        if (operator.isNotEmpty) {
          lines.add(l10n.messageOperatorPrefix(operator));
        }
        return MessagePresentation(title: title, body: lines.join('\n'));
      case 'account.unban':
      case 'account.unfreeze_creator':
        final title = event == 'account.unban'
            ? l10n.messageAccountUnbannedTitle
            : l10n.messageCreatorUnfrozenTitle;
        final lines = <String>[l10n.messageStatusChangedBody];
        final operator = text('operator_name');
        if (operator.isNotEmpty) {
          lines.add(l10n.messageOperatorPrefix(operator));
        }
        return MessagePresentation(title: title, body: lines.join('\n'));
      case 'account.set_role':
        final lines = <String>[
          l10n.messageRoleChangedBody(accountRole(text('role'))),
        ];
        final operator = text('operator_name');
        if (operator.isNotEmpty) {
          lines.add(l10n.messageOperatorPrefix(operator));
        }
        return MessagePresentation(
          title: l10n.messageRoleChangedTitle,
          body: lines.join('\n'),
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
