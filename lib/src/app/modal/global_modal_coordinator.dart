import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'global_modal_models.dart';

class GlobalModalState {
  const GlobalModalState({
    this.activeModal,
    this.queue = const [],
  });

  final GlobalModalRequest? activeModal;
  final List<GlobalModalRequest> queue;

  GlobalModalState copyWith({
    GlobalModalRequest? activeModal,
    bool clearActive = false,
    List<GlobalModalRequest>? queue,
  }) {
    return GlobalModalState(
      activeModal: clearActive ? null : activeModal ?? this.activeModal,
      queue: queue ?? this.queue,
    );
  }
}

class GlobalModalCoordinator extends Notifier<GlobalModalState> {
  @override
  GlobalModalState build() => const GlobalModalState();

  void enqueue(GlobalModalRequest request) {
    if (request.isExpired) return;

    // Check if duplicate of active modal
    if (state.activeModal?.id == request.id) return;

    if (state.activeModal == null) {
      state = state.copyWith(activeModal: request);
      return;
    }

    // Insert into queue without duplicates
    final newQueue = state.queue.where((r) => r.id != request.id && !r.isExpired).toList();

    // If new request has strictly higher priority than current active modal,
    // preempt current active modal by placing it back at the front of queue
    final current = state.activeModal!;
    if (request.priority.index > current.priority.index) {
      newQueue.insert(0, current);
      _sortQueue(newQueue);
      state = GlobalModalState(activeModal: request, queue: newQueue);
      return;
    }

    newQueue.add(request);
    _sortQueue(newQueue);
    state = state.copyWith(queue: newQueue);
  }

  void dismiss(String id) {
    if (state.activeModal?.id == id) {
      final newQueue = state.queue.where((r) => !r.isExpired).toList();
      if (newQueue.isNotEmpty) {
        final next = newQueue.removeAt(0);
        state = GlobalModalState(activeModal: next, queue: newQueue);
      } else {
        state = const GlobalModalState();
      }
      return;
    }

    final newQueue = state.queue.where((r) => r.id != id && !r.isExpired).toList();
    state = state.copyWith(queue: newQueue);
  }

  void clear() {
    state = const GlobalModalState();
  }

  void showLocalServerPairing({
    required String pairingId,
    required String clientName,
    required String fingerprint,
    required Set<String> scopes,
    required DateTime expiresAt,
    required void Function(bool remember) onApprove,
    required void Function() onReject,
  }) {
    enqueue(
      LocalServerPairingModalRequest(
        pairingId: pairingId,
        clientName: clientName,
        fingerprint: fingerprint,
        scopes: scopes,
        expiresAt: expiresAt,
        onApprove: (remember) {
          dismiss('pairing-$pairingId');
          onApprove(remember);
        },
        onReject: () {
          dismiss('pairing-$pairingId');
          onReject();
        },
      ),
    );
  }

  void showDeviceWifiPrompt({
    required String deviceId,
    required String ssid,
    required int authMode,
    required int frequency,
    required void Function(String password) onConnect,
    required void Function() onCancel,
  }) {
    final id = 'wifi-$deviceId-$ssid';
    enqueue(
      DeviceWifiPasswordModalRequest(
        deviceId: deviceId,
        ssid: ssid,
        authMode: authMode,
        frequency: frequency,
        onConnect: (password) {
          dismiss(id);
          onConnect(password);
        },
        onCancel: () {
          dismiss(id);
          onCancel();
        },
      ),
    );
  }

  void showAnnouncement({
    required String announcementId,
    required String title,
    required String body,
    required void Function() onAcknowledge,
  }) {
    final id = 'announcement-$announcementId';
    enqueue(
      AnnouncementModalRequest(
        announcementId: announcementId,
        title: title,
        body: body,
        onAcknowledge: () {
          dismiss(id);
          onAcknowledge();
        },
      ),
    );
  }

  void _sortQueue(List<GlobalModalRequest> queue) {
    queue.sort((a, b) => b.priority.index.compareTo(a.priority.index));
  }
}

final globalModalCoordinatorProvider =
    NotifierProvider<GlobalModalCoordinator, GlobalModalState>(
      GlobalModalCoordinator.new,
    );
