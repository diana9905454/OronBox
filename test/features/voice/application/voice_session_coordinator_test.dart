import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/device/core/event_bus.dart';
import 'package:oronbox/src/features/devices/controllers/device_manager.dart';
import 'package:oronbox/src/features/voice/application/voice_session_coordinator.dart';

class _FakeDeviceManager extends Fake implements DeviceManager {
  final _controller = StreamController<DeviceEvent>.broadcast();

  @override
  Stream<DeviceEvent> get deviceEvents => _controller.stream;
}

void main() {
  group('VoiceSessionCoordinator Tests', () {
    test(
      'arbitrates ownership between global and lab without losing registration',
      () async {
        final fakeManager = _FakeDeviceManager();
        final coordinator = VoiceSessionCoordinator(fakeManager);

        // 1. Lab claims ownership first
        expect(coordinator.claim(VoiceSessionOwner.lab), isTrue);
        expect(coordinator.owner, VoiceSessionOwner.lab);
        expect(coordinator.owns(VoiceSessionOwner.lab), isTrue);

        // 2. Global claims while Lab is active: returns false, but remembers registration
        expect(coordinator.claim(VoiceSessionOwner.global), isFalse);
        expect(coordinator.owner, VoiceSessionOwner.lab);

        // 3. Lab releases: ownership safely returns to Global
        coordinator.release(VoiceSessionOwner.lab);
        expect(coordinator.owner, VoiceSessionOwner.global);
        expect(coordinator.owns(VoiceSessionOwner.global), isTrue);

        // 4. Global releases: ownership becomes null
        coordinator.release(VoiceSessionOwner.global);
        expect(coordinator.owner, isNull);

        await coordinator.dispose();
      },
    );
  });
}
