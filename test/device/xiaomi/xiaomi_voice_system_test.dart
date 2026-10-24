import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/device/core/entity.dart';
import 'package:oronbox/src/device/core/event_bus.dart';
import 'package:oronbox/src/device/core/transport.dart';
import 'package:oronbox/src/device/xiaomi/protocol/generated/wear.pb.dart'
    as pb;
import 'package:oronbox/src/device/xiaomi/protocol/generated/wear_aivs.pb.dart'
    as aivs;
import 'package:oronbox/src/device/xiaomi/protocol/packet/l2_packet.dart';
import 'package:oronbox/src/device/xiaomi/systems/xiaomi_device_component.dart';
import 'package:oronbox/src/device/xiaomi/systems/xiaomi_voice_system.dart';

Uint8List _packet(int type, List<int> data) =>
    Uint8List.fromList([0, type, data.length >> 8, data.length & 255, ...data]);

class _Transport implements Transport {
  @override
  String get deviceId => 'watch';
  @override
  String get deviceName => 'Watch';
  @override
  Stream<Uint8List> get incomingData => const Stream.empty();
  @override
  Stream<bool> get connectionState => const Stream.empty();
  @override
  Future<void> send(Uint8List data) async {}
  @override
  Future<void> dispose() async {}
}

class _Component extends XiaomiDeviceComponent {
  _Component() : super(transport: _Transport(), sppV1: false);
  final packets = <pb.WearPacket>[];
  final ackRequests = <bool>[];
  Completer<void>? gate;
  int? gateAt;
  bool failNext = false;
  @override
  Future<void> sendPbPacket(
    pb.WearPacket packet, {
    bool waitForAck = false,
  }) async {
    if (failNext) {
      failNext = false;
      throw StateError('Transport unavailable');
    }
    packets.add(packet);
    ackRequests.add(waitForAck);
    if (gateAt == null || packets.length == gateAt) await gate?.future;
  }
}

void main() {
  test('validates the full packet, including malformed command tails', () {
    for (final data in [
      <int>[],
      [1],
      [0, 1],
      [0, 2, 0],
      [0, 2, 255, 255],
      [0, 1, 0, 3, 1, 2, 3],
      [0, 2, 0, 1, 1],
      [0, 4, 0, 1, 1],
      [0, 1, 0, 1, 1, 2, 0],
    ]) {
      expect(
        () => XiaomiVoiceCommand.parse(Uint8List.fromList(data)),
        throwsFormatException,
      );
    }
    expect(XiaomiVoiceCommand.parse(Uint8List.fromList([0, 3])).single.type, 3);
    expect(XiaomiVoiceCommand.parse(_packet(4, [])).single.type, 4);
  });

  late XiaomiVoiceSystem voice;
  late DeviceEventBus bus;
  late _Component component;
  late List<DeviceEvent> events;
  late StreamSubscription<DeviceEvent> subscription;
  setUp(() {
    bus = DeviceEventBus();
    component = _Component();
    voice = XiaomiVoiceSystem();
    final entity = DeviceEntity(
      id: 'watch',
      kind: 'xiaomi',
      transport: _Transport(),
      eventBus: bus,
    );
    entity.set<XiaomiDeviceComponent>(component);
    entity.registerSystem(voice);
    events = [];
    subscription = bus.stream.listen(events.add);
  });
  tearDown(() async {
    await voice.dispose();
    await subscription.cancel();
    bus.dispose();
  });
  void input(int type, List<int> data) => voice.onLayer2Packet(
    L2Channel.massVoice,
    L2OpCode.write,
    _packet(type, data),
  );

  test(
    'final recognition preserves start/final order across repeated rounds',
    () async {
      voice.setEnabled(true);
      for (final session in [1, 2]) {
        input(1, [session]);
        await voice.sendRecognitionResult('same words', isFinal: true);
        await voice.sendRecognitionResult('same words', isFinal: true);
        await voice.sendTextReply('answer', recognizedText: 'same words');
      }
      final results = component.packets
          .expand((p) => p.aivs.instructionList.list)
          .where((p) => p.hasRecognizeResult())
          .toList();
      expect(results.map((p) => p.sessionId), [1, 1, 2, 2]);
      expect(results.map((p) => p.recognizeResult.isFinal), [
        false,
        true,
        false,
        true,
      ]);
    },
  );

  test(
    'only captures while enabled and splits command audio into 80-byte packets',
    () async {
      input(1, [255, 1]);
      input(2, List.filled(160, 1));
      await Future<void>.delayed(Duration.zero);
      expect(events, isEmpty);
      voice.setEnabled(true);
      input(1, [255, 1]);
      input(2, List.filled(160, 1));
      input(3, []);
      input(2, List.filled(80, 2));
      await Future<void>.delayed(Duration.zero);
      expect(
        events
            .whereType<XiaoAiSessionStarted>()
            .single
            .capabilities['sessionId'],
        255,
      );
      final frames = events.whereType<XiaoAiOpusFrameReceived>().toList();
      expect(frames.map((e) => e.sequence), [0, 1]);
      expect(frames.map((e) => e.frame.length), [80, 80]);
      expect(events.whereType<XiaoAiSessionEnded>(), hasLength(1));
    },
  );

  test(
    'phone ends recording without waiting for the wearable end event',
    () async {
      voice.setEnabled(true);
      input(1, [255]);
      await voice.sendTextReply('hello', recognizedText: 'question');
      expect(component.packets, isNotEmpty);
      final results = component.packets
          .expand((p) => p.aivs.instructionList.list)
          .toList();
      expect(results.map((e) => e.resultType), [
        aivs.ResultType.RECOGNIZE_RESULT,
        aivs.ResultType.STOP_CAPTURE,
        aivs.ResultType.RECOGNIZE_RESULT,
        aivs.ResultType.TEMPLATE_TOAST,
        aivs.ResultType.DIALOG_FINISH,
      ]);
      expect(results.map((e) => e.sessionId), everyElement(255));
      expect(results[2].recognizeResult.isFinal, isTrue);
      expect(results[2].recognizeResult.results.list.single.text, 'question');
      input(3, []);
      expect(component.packets, hasLength(5));
      expect(component.ackRequests, everyElement(isTrue));
    },
  );

  test('natural audio end keeps the session available for a reply', () async {
    voice.setEnabled(true);
    input(1, [1]);
    input(3, []);
    await voice.sendTextReply('hello', recognizedText: 'question');
    expect(
      component.packets.map(
        (p) => p.aivs.instructionList.list.single.resultType,
      ),
      [
        aivs.ResultType.RECOGNIZE_RESULT,
        aivs.ResultType.RECOGNIZE_RESULT,
        aivs.ResultType.TEMPLATE_TOAST,
        aivs.ResultType.DIALOG_FINISH,
      ],
    );
    await Future<void>.delayed(Duration.zero);
    expect(events.whereType<XiaoAiSessionEnded>(), hasLength(1));
  });

  test(
    'partial recognition is ordered before final and reset every round',
    () async {
      voice.setEnabled(true);
      for (var round = 0; round < 3; round++) {
        input(1, [7]);
        final offset = component.packets.length;
        await voice.sendRecognitionPartial('q');
        await voice.sendRecognitionPartial('question');
        await voice.sendRecognitionPartial('question');
        await voice.sendTextReply('answer', recognizedText: 'question');
        final results = component.packets
            .skip(offset)
            .expand((p) => p.aivs.instructionList.list)
            .toList();
        final recognition = results
            .where((e) => e.hasRecognizeResult())
            .toList();
        expect(recognition.map((e) => e.recognizeResult.isFinal), [
          false,
          false,
          true,
        ]);
        expect(
          recognition.map((e) => e.recognizeResult.results.list.single.text),
          ['q', 'question', 'question'],
        );
        expect(results.map((e) => e.sessionId), everyElement(7));
        expect(results.last.resultType, aivs.ResultType.DIALOG_FINISH);
      }
    },
  );

  test(
    'submission waits for pending recognition and rejects late partials',
    () async {
      voice.setEnabled(true);
      input(1, [7]);
      component.gate = Completer<void>();
      final partial = voice.sendRecognitionPartial('question');
      await Future<void>.delayed(Duration.zero);
      final sending = voice.sendTextReply('answer', recognizedText: 'question');
      await voice.sendRecognitionPartial('late');
      expect(component.packets, hasLength(1));
      component.gate!.complete();
      await partial;
      await sending;
      expect(component.packets, hasLength(5));
      expect(
        component.packets
            .where(
              (p) => p.aivs.instructionList.list.single.hasRecognizeResult(),
            )
            .map(
              (p) => p.aivs.instructionList.list.single.recognizeResult.isFinal,
            ),
        [false, true],
      );
    },
  );

  for (final stage in [1, 2, 3, 4, 5]) {
    test('new session survives old send completion at packet $stage', () async {
      voice.setEnabled(true);
      input(1, [1]);
      final gate = Completer<void>();
      component.gate = gate;
      component.gateAt = stage;
      final sending = voice.sendTextReply('old', recognizedText: 'question');
      while (component.packets.length < stage) {
        await Future<void>.delayed(Duration.zero);
      }
      input(1, [2]);
      gate.complete();
      await sending;
      expect(component.packets, hasLength(stage));
      component.gate = null;
      await voice.sendTextReply('new', recognizedText: 'question');
      expect(
        component.packets
            .skip(stage)
            .expand((p) => p.aivs.instructionList.list)
            .map((e) => e.sessionId),
        everyElement(2),
      );
    });
  }

  test('leaving during a stop cannot finish the next session', () async {
    voice.setEnabled(true);
    input(1, [1]);
    component.gate = Completer<void>();
    voice.setEnabled(false);
    voice.setEnabled(true);
    input(1, [2]);
    component.gate!.complete();
    await Future<void>.delayed(Duration.zero);
    expect(component.packets, hasLength(1));
    component.gate = null;
    await voice.sendTextReply('new', recognizedText: 'question');
    expect(
      component.packets.last.aivs.instructionList.list.single.sessionId,
      2,
    );
  });

  test('duplicate submission is rejected while a send is pending', () async {
    voice.setEnabled(true);
    input(1, [1]);
    component.gate = Completer<void>();
    final sending = voice.sendTextReply('first', recognizedText: 'question');
    await expectLater(
      voice.sendTextReply('second', recognizedText: 'question'),
      throwsStateError,
    );
    expect(component.packets, hasLength(1));
    component.gate!.complete();
    await sending;
    expect(component.packets, hasLength(5));
  });

  test('a failed recognition can be retried before stopping capture', () async {
    voice.setEnabled(true);
    input(1, [1]);
    component.failNext = true;
    await expectLater(
      voice.sendTextReply('hello', recognizedText: 'question'),
      throwsStateError,
    );
    await voice.sendTextReply('hello', recognizedText: 'question');
    expect(
      component.packets[1].aivs.instructionList.list.single.resultType,
      aivs.ResultType.STOP_CAPTURE,
    );
    expect(component.packets, hasLength(5));
  });

  test('wearable quit prevents the remaining reply from being sent', () async {
    voice.setEnabled(true);
    input(1, [1]);
    component.gate = Completer<void>();
    final sending = voice.sendTextReply('hello', recognizedText: 'question');
    await Future<void>.delayed(Duration.zero);
    input(4, []);
    component.gate!.complete();
    await sending;
    expect(component.packets, hasLength(1));
    await expectLater(
      voice.sendTextReply('hello', recognizedText: 'question'),
      throwsStateError,
    );
  });

  test('leaving the lab stops capture and ignores late audio', () async {
    voice.setEnabled(true);
    input(1, [10]);
    voice.setEnabled(false);
    input(2, List.filled(80, 1));
    input(1, [11]);
    await Future<void>.delayed(Duration.zero);
    expect(events.whereType<XiaoAiOpusFrameReceived>(), isEmpty);
    expect(events.whereType<XiaoAiSessionStarted>(), hasLength(1));
    expect(
      component.packets
          .expand((p) => p.aivs.instructionList.list)
          .map((e) => e.resultType),
      [aivs.ResultType.STOP_CAPTURE, aivs.ResultType.DIALOG_FINISH],
    );
  });
}
