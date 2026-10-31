import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/app/generated/app_localizations_en.dart';
import 'package:oronbox/src/commands/command_protocol.dart';
import 'package:oronbox/src/features/messages/application/message_center.dart';
import 'package:oronbox/src/features/messages/application/message_presentation.dart';
import 'package:oronbox/src/host/application_host_provider.dart';

void main() {
  test('empty read_at remains unread', () {
    final message = UserMessage.fromJson({'id': 'm', 'read_at': ''});
    expect(message.read, isFalse);
  });

  test(
    'opening a target marks the message read without waiting for network',
    () async {
      final host = _MessageHost();
      final container = ProviderContainer(
        overrides: [applicationHostProvider.overrideWithValue(host)],
      );
      addTearDown(container.dispose);

      await container.read(messageCenterProvider.future);
      final pending = container.read(messageCenterProvider.notifier).read('m1');
      await Future<void>.delayed(Duration.zero);

      final optimistic = container.read(messageCenterProvider).requireValue;
      expect(optimistic.messages.single.read, isTrue);
      expect(optimistic.unread, 0);

      host.readGate.complete();
      await pending;
    },
  );

  test('parses structured metadata and localizes its presentation', () {
    final message = UserMessage.fromJson({
      'id': 'm2',
      'kind': 'review_result',
      'event': 'review.rejected',
      'data': {
        'resource_id': 'resource-2',
        'revision_id': 'revision-2',
        'note': 'Add a clearer preview',
      },
      'created_at': '2026-08-28T10:00:00Z',
    });

    final presentation = MessagePresentation.localize(
      AppLocalizationsEn(),
      message,
    );

    expect(message.targetResourceId, 'resource-2');
    expect(presentation.title, 'Resource needs changes');
    expect(presentation.body, 'Review note: Add a clearer preview');
  });

  test('formats rich metadata when resource_name and version are present', () {
    final message = UserMessage.fromJson({
      'id': 'm2b',
      'kind': 'review_result',
      'event': 'review.approved',
      'data': {
        'resource_id': 'com.shell.terminal',
        'resource_name': 'Shell++',
        'version': '1.0.2',
      },
      'created_at': '2026-10-26T01:00:00Z',
    });

    final presentation = MessagePresentation.localize(
      AppLocalizationsEn(),
      message,
    );

    expect(presentation.title, 'Shell++ 1.0.2 · Resource approved');
    expect(presentation.body, 'Your submission passed review.');
  });

  test('keeps legacy message targets migrated into metadata', () {
    final message = UserMessage.fromJson({
      'id': 'm3',
      'kind': 'comment_reply',
      'event': 'legacy.comment_reply',
      'data': {
        'ref': 'comment-3',
        'resource_id': 'resource-3',
        'comment_id': 'comment-3',
      },
      'created_at': '2026-08-28T10:00:00Z',
    });

    expect(message.targetResourceId, 'resource-3');
    expect(message.targetCommentId, 'comment-3');
  });

  test('parses review case deep links from message metadata', () {
    final message = UserMessage.fromJson({
      'id': 'm4',
      'kind': 'review_result',
      'event': 'review.rejected',
      'data': {'review_case_id': 'review-4'},
      'created_at': '2026-08-28T10:00:00Z',
    });

    expect(message.targetReviewId, 'review-4');
  });

  test('formats comprehensive rich metadata across message domains', () {
    final en = AppLocalizationsEn();

    // 1. comment.replied with parent quote and resource name
    final replyMsg = UserMessage.fromJson({
      'id': 'msg-reply',
      'kind': 'comment_reply',
      'event': 'comment.replied',
      'data': {
        'resource_name': 'Astral Watch',
        'author_name': 'alice',
        'parent_body': 'How do I install this?',
        'body': 'Copy the bin to /apps',
      },
      'created_at': '2026-10-26T01:00:00Z',
    });
    final replyPresentation = MessagePresentation.localize(en, replyMsg);
    expect(replyPresentation.title, 'alice · Astral Watch · New comment reply');
    expect(
      replyPresentation.body,
      '> How do I install this?\n\nCopy the bin to /apps',
    );

    // 2. comment.hidden with comment quote and reason
    final hiddenMsg = UserMessage.fromJson({
      'id': 'msg-hidden',
      'kind': 'moderation',
      'event': 'comment.hidden',
      'data': {
        'resource_name': 'Astral Watch',
        'comment_body': 'Spam advertising link',
        'reason': 'Advertising violation',
      },
      'created_at': '2026-10-26T01:00:00Z',
    });
    final hiddenPresentation = MessagePresentation.localize(en, hiddenMsg);
    expect(hiddenPresentation.title, 'Astral Watch · Comment hidden');
    expect(
      hiddenPresentation.body,
      '> Spam advertising link\n\nReason: Advertising violation',
    );

    // 3. review.approved with reviewer and copublishing targets
    final approvedMsg = UserMessage.fromJson({
      'id': 'msg-approved',
      'kind': 'review_result',
      'event': 'review.approved',
      'data': {
        'resource_name': 'Retro Dial',
        'version': '2.1.0',
        'reviewer_name': 'bob_reviewer',
        'targets': [
          {'target': 'oronbox', 'state': 'published'},
          {'target': 'astrobox', 'state': 'reviewing'},
        ],
      },
      'created_at': '2026-10-26T01:00:00Z',
    });
    final approvedPresentation = MessagePresentation.localize(en, approvedMsg);
    expect(approvedPresentation.title, 'Retro Dial 2.1.0 · Resource approved');
    expect(
      approvedPresentation.body,
      'Reviewer: bob_reviewer\nChannels: OronBox (Published), AstroBox (External review)',
    );

    // 4. review.rejected with checklist items and note
    final rejectedMsg = UserMessage.fromJson({
      'id': 'msg-rejected',
      'kind': 'review_result',
      'event': 'review.rejected',
      'data': {
        'resource_name': 'Retro Dial',
        'version': '2.1.1',
        'reviewer_name': 'bob_reviewer',
        'note': 'Please re-export icon at 128x128',
        'items': ['Icon dimensions (needs 128px)'],
      },
      'created_at': '2026-10-26T01:00:00Z',
    });
    final rejectedPresentation = MessagePresentation.localize(en, rejectedMsg);
    expect(
      rejectedPresentation.title,
      'Retro Dial 2.1.1 · Resource needs changes',
    );
    expect(
      rejectedPresentation.body,
      'Review note: Please re-export icon at 128x128\nItems needing changes: Icon dimensions (needs 128px)\nReviewer: bob_reviewer',
    );

    // 5. report.updated with subject, quote, and resolution
    final reportMsg = UserMessage.fromJson({
      'id': 'msg-report',
      'kind': 'report_result',
      'event': 'report.updated',
      'data': {
        'ticket_subject': 'Plagiarism report',
        'ticket_message': 'This resource copies my assets directly',
        'resolution': 'Assets verified and infringing revision was delisted',
      },
      'created_at': '2026-10-26T01:00:00Z',
    });
    final reportPresentation = MessagePresentation.localize(en, reportMsg);
    expect(reportPresentation.title, 'Plagiarism report · Report updated');
    expect(
      reportPresentation.body,
      '> This resource copies my assets directly\n\nAssets verified and infringing revision was delisted',
    );

    // 6. coin.adjusted with reference_name, reason, and operator_name
    final coinMsg = UserMessage.fromJson({
      'id': 'msg-coin',
      'kind': 'account',
      'event': 'coin.adjusted',
      'data': {
        'delta_units': 50,
        'reference_name': 'Creator Award 2026',
        'reason': 'First prize reward',
        'operator_name': 'admin_team',
      },
      'created_at': '2026-10-26T01:00:00Z',
    });
    final coinPresentation = MessagePresentation.localize(en, coinMsg);
    expect(coinPresentation.title, 'Coins added');
    expect(
      coinPresentation.body,
      '5 coins were added to your account.\nRelated: Creator Award 2026\nReason: First prize reward\nOperator: admin_team',
    );

    // 7. coin.vote_revoked with resource_name, reason, and operator_name
    final voteRevokedMsg = UserMessage.fromJson({
      'id': 'msg-vote-revoked',
      'kind': 'account',
      'event': 'coin.vote_revoked',
      'data': {
        'resource_name': 'Pixel Runner',
        'coins': 2,
        'reason': 'Abnormal vote batch detected',
        'operator_name': 'security_audit',
      },
      'created_at': '2026-10-26T01:00:00Z',
    });
    final voteRevokedPresentation = MessagePresentation.localize(
      en,
      voteRevokedMsg,
    );
    expect(
      voteRevokedPresentation.title,
      'Pixel Runner · Coin contribution revoked',
    );
    expect(
      voteRevokedPresentation.body,
      'Your contribution of 2 coins to this resource was revoked.\nReason: Abnormal vote batch detected\nOperator: security_audit',
    );

    // 8. appeal.overturned with subject_name, quote, and handler_name
    final appealMsg = UserMessage.fromJson({
      'id': 'msg-appeal',
      'kind': 'report_result',
      'event': 'appeal.overturned',
      'data': {
        'subject_name': 'Retro Dial',
        'appeal_message': 'The original artwork license was attached in repo',
        'resolution': 'License verified, resource has been restored',
        'handler_name': 'chief_arbiter',
      },
      'created_at': '2026-10-26T01:00:00Z',
    });
    final appealPresentation = MessagePresentation.localize(en, appealMsg);
    expect(appealPresentation.title, 'Retro Dial · Appeal accepted');
    expect(
      appealPresentation.body,
      '> The original artwork license was attached in repo\n\nLicense verified, resource has been restored\nOperator: chief_arbiter',
    );

    // 9. resource.suspended with operator_name
    final suspendedMsg = UserMessage.fromJson({
      'id': 'msg-suspended',
      'kind': 'moderation',
      'event': 'resource.suspended',
      'data': {
        'resource_name': 'Astral Watch',
        'reason': 'Copyright infringement complaint',
        'operator_name': 'OrPudding',
      },
      'created_at': '2026-10-26T01:00:00Z',
    });
    final suspendedPresentation = MessagePresentation.localize(
      en,
      suspendedMsg,
    );
    expect(suspendedPresentation.title, 'Astral Watch · Resource delisted');
    expect(
      suspendedPresentation.body,
      'Reason: Copyright infringement complaint\nOperator: OrPudding',
    );

    // 10. account.ban with operator_name
    final banMsg = UserMessage.fromJson({
      'id': 'msg-ban',
      'kind': 'account',
      'event': 'account.ban',
      'data': {
        'reason': 'Malicious payload in uploaded package',
        'operator_name': 'OrPudding',
      },
      'created_at': '2026-10-26T01:00:00Z',
    });
    final banPresentation = MessagePresentation.localize(en, banMsg);
    expect(banPresentation.title, 'Account suspended');
    expect(
      banPresentation.body,
      'Reason: Malicious payload in uploaded package\nOperator: OrPudding',
    );
  });
}

class _MessageHost implements OronBoxCommandBus {
  final readGate = Completer<void>();

  @override
  Stream<CommandEvent> get events => const Stream.empty();

  @override
  Future<CommandResult> execute(OronBoxCommand command) async {
    if (command.method == 'message.list') {
      return CommandResult.success({
        'unread': 1,
        'messages': [
          {
            'id': 'm1',
            'kind': 'comment',
            'title': 'Reply',
            'body': 'Body',
            'created_at': '2026-07-27T12:00:00Z',
            'target_resource_id': 'resource-1',
            'target_comment_id': 'comment-1',
          },
        ],
      });
    }
    if (command.method == 'message.read') {
      await readGate.future;
      return const CommandResult.success(<String, Object?>{});
    }
    return CommandResult.failure(CommandError('unexpected', command.method));
  }

  @override
  Future<void> close() async {}
}
