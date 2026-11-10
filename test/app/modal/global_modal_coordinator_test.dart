import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/app/modal/global_modal_coordinator.dart';
import 'package:oronbox/src/app/modal/global_modal_models.dart';

void main() {
  group('GlobalModalCoordinator', () {
    test('enqueues modal and activates when empty', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(globalModalCoordinatorProvider.notifier);
      expect(container.read(globalModalCoordinatorProvider).activeModal, isNull);

      notifier.showAnnouncement(
        announcementId: '1',
        title: 'Notice',
        body: 'Body text',
        onAcknowledge: () {},
      );

      final state = container.read(globalModalCoordinatorProvider);
      expect(state.activeModal, isNotNull);
      expect(state.activeModal?.id, 'announcement-1');
      expect(state.queue, isEmpty);
    });

    test('prioritizes urgent device prompt over lower priority modals', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(globalModalCoordinatorProvider.notifier);

      // Low/normal priority announcement
      notifier.showAnnouncement(
        announcementId: '1',
        title: 'Notice',
        body: 'Body',
        onAcknowledge: () {},
      );

      // High priority Local Server pairing
      notifier.showLocalServerPairing(
        pairingId: 'p-1',
        clientName: 'VS Code',
        fingerprint: 'fp-1',
        scopes: {'device.read'},
        expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
        onApprove: (_) {},
        onReject: () {},
      );

      // Pairing should preempt announcement because high > normal
      var state = container.read(globalModalCoordinatorProvider);
      expect(state.activeModal?.id, 'pairing-p-1');
      expect(state.queue.first.id, 'announcement-1');

      // Urgent priority Wi-Fi password prompt
      notifier.showDeviceWifiPrompt(
        deviceId: 'dev-1',
        ssid: 'Home_WiFi',
        authMode: 2,
        frequency: 2412,
        onConnect: (_) {},
        onCancel: () {},
      );

      // Urgent should preempt high
      state = container.read(globalModalCoordinatorProvider);
      expect(state.activeModal?.id, 'wifi-dev-1-Home_WiFi');
      expect(state.queue.map((r) => r.id).toList(), ['pairing-p-1', 'announcement-1']);

      // Dismiss Wi-Fi -> next is pairing
      notifier.dismiss('wifi-dev-1-Home_WiFi');
      state = container.read(globalModalCoordinatorProvider);
      expect(state.activeModal?.id, 'pairing-p-1');
      expect(state.queue.map((r) => r.id).toList(), ['announcement-1']);

      // Dismiss pairing -> next is announcement
      notifier.dismiss('pairing-p-1');
      state = container.read(globalModalCoordinatorProvider);
      expect(state.activeModal?.id, 'announcement-1');
      expect(state.queue, isEmpty);

      // Dismiss announcement -> empty
      notifier.dismiss('announcement-1');
      state = container.read(globalModalCoordinatorProvider);
      expect(state.activeModal, isNull);
      expect(state.queue, isEmpty);
    });

    test('ignores duplicate modal requests', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(globalModalCoordinatorProvider.notifier);

      notifier.showAnnouncement(
        announcementId: 'dup-1',
        title: 'Title',
        body: 'Body',
        onAcknowledge: () {},
      );
      notifier.showAnnouncement(
        announcementId: 'dup-1',
        title: 'Title',
        body: 'Body',
        onAcknowledge: () {},
      );

      final state = container.read(globalModalCoordinatorProvider);
      expect(state.activeModal?.id, 'announcement-dup-1');
      expect(state.queue, isEmpty);
    });

    test('drops expired modal requests upon queue advance', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(globalModalCoordinatorProvider.notifier);

      notifier.showAnnouncement(
        announcementId: 'current',
        title: 'Active',
        body: 'Body',
        onAcknowledge: () {},
      );

      notifier.enqueue(
        LocalServerPairingModalRequest(
          pairingId: 'expired-p',
          clientName: 'CLI',
          fingerprint: 'fp',
          scopes: const {},
          expiresAt: DateTime.now().toUtc().subtract(const Duration(seconds: 10)),
          onApprove: (_) {},
          onReject: () {},
        ),
      );

      notifier.dismiss('announcement-current');
      final state = container.read(globalModalCoordinatorProvider);
      expect(state.activeModal, isNull);
      expect(state.queue, isEmpty);
    });
  });
}
