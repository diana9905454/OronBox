import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/core/asr/asr.dart';
import 'package:oronbox/src/features/voice/application/voice_recognition_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer container;
  late _Engine engine;
  late VoiceRecognitionController controller;
  setUp(() async {
    engine = _Engine();
    container = ProviderContainer(
      overrides: [
        asrEngineFactoryProvider.overrideWithValue(
          (backend, model) async => engine,
        ),
      ],
    );
    container.listen(voiceRecognitionProvider, (_, _) {});
    controller = container.read(voiceRecognitionProvider.notifier);
    await controller.select(AsrBackend.wetype);
  });
  tearDown(() async {
    await controller.cancel();
    container.dispose();
    for (final session in engine.sessions) {
      await session.events.close();
    }
  });
  test(
    'buffers first frames during connection and drains before finalizing',
    () async {
      final gate = Completer<void>();
      engine.startGate = gate;
      controller.startRound();
      final pcm = Float32List.fromList([0.25, 0.5]);
      controller.addAudio(pcm, Uint8List.fromList([1]));
      pcm[0] = 1;
      final finishing = controller.finishRound();
      gate.complete();
      await finishing;
      await Future<void>.delayed(Duration.zero);
      expect(engine.sessions.single.frames.single, [0.25, 0.5]);
      expect(container.read(voiceRecognitionProvider).text, 'recognized');
      expect(container.read(voiceRecognitionProvider).completed, true);
    },
  );
  test(
    'late results from the previous round cannot update the new round',
    () async {
      controller.startRound();
      await Future<void>.delayed(Duration.zero);
      final old = engine.sessions.single;
      controller.startRound();
      await Future<void>.delayed(Duration.zero);
      old.events.add(const AsrResult('old', isFinal: true));
      engine.sessions.last.events.add(const AsrResult('new'));
      await Future<void>.delayed(Duration.zero);
      expect(old.cancelled, true);
      expect(container.read(voiceRecognitionProvider).text, 'new');
    },
  );
  test('a failed round rejects late final results', () async {
    controller.startRound();
    await Future<void>.delayed(Duration.zero);
    final session = engine.sessions.single;
    session.events.addError(const AsrFailure('service_rejected'));
    await Future<void>.delayed(Duration.zero);
    session.events.add(const AsrResult('late', isFinal: true));
    await Future<void>.delayed(Duration.zero);
    final state = container.read(voiceRecognitionProvider);
    expect(state.error, 'service_rejected');
    expect(state.completed, false);
    expect(state.text, isEmpty);
  });
  test('a slow old cancellation cannot clear a newly started round', () async {
    controller.startRound();
    await Future<void>.delayed(Duration.zero);
    final old = engine.sessions.single;
    old.cancelGate = Completer<void>();
    final cancelling = controller.cancel();
    await Future<void>.delayed(Duration.zero);
    controller.startRound();
    await Future<void>.delayed(Duration.zero);
    final current = engine.sessions.last;
    expect(current, isNot(same(old)));
    old.cancelGate!.complete();
    await cancelling;
    expect(container.read(voiceRecognitionProvider).running, true);
    current.events.add(const AsrResult('current'));
    await Future<void>.delayed(Duration.zero);
    expect(container.read(voiceRecognitionProvider).text, 'current');
  });
  test(
    'the latest backend selection wins over a pending cancellation',
    () async {
      controller.startRound();
      await Future<void>.delayed(Duration.zero);
      final old = engine.sessions.single;
      old.cancelGate = Completer<void>();
      final first = controller.select(AsrBackend.manual);
      await Future<void>.delayed(Duration.zero);
      await controller.select(AsrBackend.doubao);
      old.cancelGate!.complete();
      await first;
      expect(
        container.read(voiceRecognitionProvider).backend,
        AsrBackend.doubao,
      );
    },
  );
  test('audio backlog is bounded without switching providers', () async {
    engine.startGate = Completer<void>();
    controller.startRound();
    controller.addAudio(Float32List(16000 * 6), Uint8List(1));
    expect(container.read(voiceRecognitionProvider).error, 'slow');
    expect(container.read(voiceRecognitionProvider).backend, AsrBackend.wetype);
    engine.startGate!.complete();
    await Future<void>.delayed(Duration.zero);
  });
}

class _Engine implements AsrEngine {
  final sessions = <_Session>[];
  Completer<void>? startGate;
  @override
  Future<AsrSession> start() async {
    await startGate?.future;
    final session = _Session();
    sessions.add(session);
    return session;
  }

  @override
  Future<void> dispose() async {}
}

class _Session implements AsrSession {
  final events = StreamController<AsrResult>.broadcast();
  final frames = <List<double>>[];
  bool cancelled = false;
  Completer<void>? cancelGate;
  @override
  Stream<AsrResult> get results => events.stream;
  @override
  Future<void> addAudio(Float32List pcm, {Uint8List? opus}) async {
    frames.add(pcm.toList());
  }

  @override
  Future<void> finishInput() async {
    events.add(const AsrResult('recognized', isFinal: true));
  }

  @override
  Future<void> cancel() async {
    cancelled = true;
    await cancelGate?.future;
  }
}
