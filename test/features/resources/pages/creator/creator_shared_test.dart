import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/app/generated/app_localizations_en.dart';
import 'package:oronbox/src/features/resources/domain/creator_workspace.dart';
import 'package:oronbox/src/features/resources/domain/creator_review.dart';
import 'package:oronbox/src/features/resources/pages/creator/creator_review_list_page.dart'
    show creatorReviewMatchesFilter;
import 'package:oronbox/src/features/resources/pages/creator/creator_shared.dart';

void main() {
  final l10n = AppLocalizationsEn();

  group('creatorStateLabel', () {
    test('localizes every review state rendered by CreatorStateBadge', () {
      for (final state in const [
        'needs_changes',
        'changes_requested',
        'external_changes_requested',
        'fixed_pending_review',
        'external_fixed_waiting',
        'closed',
      ]) {
        expect(
          creatorStateLabel(l10n, state),
          isNot(state),
          reason: '$state must not render as a raw enum string',
        );
      }
      expect(
        creatorStateLabel(l10n, 'needs_changes'),
        l10n.creatorReviewChangesRequested,
      );
      expect(
        creatorStateLabel(l10n, 'fixed_pending_review'),
        l10n.creatorReviewFixedPending,
      );
      expect(creatorStateLabel(l10n, 'closed'), l10n.creatorReviewClosed);
    });
  });

  group('creatorWorkspaceState', () {
    CreatorWorkspace workspaceWithReview(String state) =>
        CreatorWorkspace.fromJson({
          'resource': {'id': 'r1', 'slug': 'slug'},
          'revisions': [
            {'id': 'v1', 'number': 1, 'state': 'published'},
          ],
          'review': {'state': state},
        });

    test('treats needs_changes like changes_requested', () {
      expect(
        creatorWorkspaceState(workspaceWithReview('needs_changes')),
        'rejected',
      );
      expect(
        creatorWorkspaceState(workspaceWithReview('changes_requested')),
        'rejected',
      );
    });

    test('maps the active review states to pending', () {
      for (final state in const [
        'pending',
        'reviewing',
        'fixed_pending_review',
      ]) {
        expect(
          creatorWorkspaceState(workspaceWithReview(state)),
          'pending',
          reason: state,
        );
      }
    });
    test('maps publications dispatching to publishing and waiting_external_review to external_review', () {
      final publishingWs = CreatorWorkspace.fromJson({
        'resource': {'id': 'r1', 'slug': 'slug'},
        'revisions': [
          {'id': 'v1', 'number': 1, 'state': 'approved'},
        ],
        'review': {'state': 'approved'},
        'publications': [
          {'state': 'running', 'target': 'bandbbs'},
        ],
      });
      expect(creatorWorkspaceState(publishingWs), 'publishing');

      final externalWs = CreatorWorkspace.fromJson({
        'resource': {'id': 'r1', 'slug': 'slug'},
        'revisions': [
          {'id': 'v1', 'number': 1, 'state': 'approved'},
        ],
        'review': {'state': 'approved'},
        'publications': [
          {'state': 'reviewing', 'target': 'astrobox'},
        ],
      });
      expect(creatorWorkspaceState(externalWs), 'external_review');
    });
  });

  test('external review filters use the published API contract', () {
    for (final pair in const [
      ('waiting_review', 'external_review'),
      ('changes_requested', 'needs_changes'),
      ('fixed_waiting', 'fixed_pending_review'),
    ]) {
      final item = CreatorReviewCase.fromJson({
        'state': 'approved',
        'review_type': 'astrobox',
        'publication_state': 'reviewing',
        'external_review_state': pair.$1,
      });
      expect(item.displayState, pair.$2);
      expect(
        creatorReviewMatchesFilter('external_review', item.displayState),
        isTrue,
      );
      expect(creatorReviewMatchesFilter('active', item.displayState), isTrue);
    }
  });

  group('creatorReviewMatchesFilter', () {
    test('all filter matches every state', () {
      for (final state in const [
        'pending',
        'reviewing',
        'needs_changes',
        'approved',
        'rejected',
        'superseded',
        'waiting_external_review',
      ]) {
        expect(creatorReviewMatchesFilter('all', state), isTrue, reason: state);
      }
    });

    test('approved and rejected filters match their states', () {
      expect(creatorReviewMatchesFilter('approved', 'approved'), isTrue);
      expect(creatorReviewMatchesFilter('approved', 'published'), isTrue);
      expect(creatorReviewMatchesFilter('approved', 'pending'), isFalse);

      expect(creatorReviewMatchesFilter('rejected', 'rejected'), isTrue);
      expect(creatorReviewMatchesFilter('rejected', 'approved'), isFalse);
    });

    test('external_review filter matches waiting_external_review', () {
      expect(
        creatorReviewMatchesFilter(
          'external_review',
          'waiting_external_review',
        ),
        isTrue,
      );
      expect(
        creatorReviewMatchesFilter('external_review', 'external_fixed_waiting'),
        isTrue,
      );
      expect(creatorReviewMatchesFilter('external_review', 'pending'), isFalse);
    });

    test('the fixed_pending_review chip matches its own state', () {
      expect(
        creatorReviewMatchesFilter(
          'fixed_pending_review',
          'fixed_pending_review',
        ),
        isTrue,
      );
      expect(
        creatorReviewMatchesFilter('fixed_pending_review', 'pending'),
        isFalse,
      );
    });

    test('active spans every open state', () {
      for (final state in const [
        'pending',
        'reviewing',
        'needs_changes',
        'changes_requested',
        'fixed_pending_review',
      ]) {
        expect(
          creatorReviewMatchesFilter('active', state),
          isTrue,
          reason: state,
        );
      }
      expect(creatorReviewMatchesFilter('active', 'closed'), isFalse);
      expect(creatorReviewMatchesFilter('active', 'superseded'), isFalse);
    });

    test('unknown filters match nothing instead of everything', () {
      expect(creatorReviewMatchesFilter('nonsense', 'pending'), isFalse);
    });
  });
}
