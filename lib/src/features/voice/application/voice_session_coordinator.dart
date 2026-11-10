import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oronbox/src/device/core/event_bus.dart';
import 'package:oronbox/src/features/devices/controllers/device_manager.dart';

enum VoiceSessionOwner { global, lab }

/// Provides one device-event subscription for wearable voice sessions.
///
/// The global service and the lab page still own their presentation and ASR
/// state, but only one of them may consume a session at a time.
class VoiceSessionCoordinator {
  VoiceSessionCoordinator(this._manager) {
    _subscription = _manager.deviceEvents.listen(_events.add);
  }

  final DeviceManager _manager;
  final _events = StreamController<DeviceEvent>.broadcast();
  late final StreamSubscription<DeviceEvent> _subscription;
  VoiceSessionOwner? _owner;
  bool _globalRegistered = false;

  Stream<DeviceEvent> get events => _events.stream;
  VoiceSessionOwner? get owner => _owner;

  bool claim(VoiceSessionOwner owner) {
    if (owner == VoiceSessionOwner.global) {
      _globalRegistered = true;
      if (_owner == VoiceSessionOwner.lab) return false;
    }
    if (owner == VoiceSessionOwner.lab) {
      _owner = owner;
      return true;
    }
    _owner = owner;
    return true;
  }

  void release(VoiceSessionOwner owner) {
    if (owner == VoiceSessionOwner.global) {
      _globalRegistered = false;
    }
    if (_owner != owner) return;
    _owner = owner == VoiceSessionOwner.lab && _globalRegistered
        ? VoiceSessionOwner.global
        : null;
  }

  bool owns(VoiceSessionOwner owner) => _owner == owner;

  Future<void> dispose() async {
    await _subscription.cancel();
    await _events.close();
  }
}

final voiceSessionCoordinatorProvider = Provider<VoiceSessionCoordinator>((
  ref,
) {
  final coordinator = VoiceSessionCoordinator(
    ref.read(deviceManagerProvider.notifier),
  );
  ref.onDispose(coordinator.dispose);
  return coordinator;
});
