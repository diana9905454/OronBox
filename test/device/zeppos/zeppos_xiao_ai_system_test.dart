import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/device/core/entity.dart';
import 'package:oronbox/src/device/core/event_bus.dart';
import 'package:oronbox/src/device/core/transport.dart';
import 'package:oronbox/src/device/zeppos/systems/zeppos_xiao_ai_system.dart';
import 'package:oronbox/src/device/zeppos/zeppos_device_component.dart';

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

class _Component extends ZeppOsDeviceComponent {
  _Component() : super(transport: _Transport());
  final sent = <(int, Uint8List)>[];
  Completer<void>? gate;
  @override
  Future<void> sendToEndpoint(
    int endpoint,
    Uint8List payload, {
    bool encrypted = false,
    int? maxWriteLength,
  }) async {
    expect(encrypted, isTrue);
    sent.add((endpoint, payload));
    await gate?.future;
  }
}

void main() {
  late ZeppOsXiaoAiSystem voice;
  late _Component component;
  late DeviceEventBus bus;
  setUp(() {
    voice = ZeppOsXiaoAiSystem();
    component = _Component();
    bus = DeviceEventBus();
    final entity = DeviceEntity(
      id: 'watch',
      kind: 'zepp',
      transport: _Transport(),
      eventBus: bus,
    );
    entity.set<ZeppOsDeviceComponent>(component);
    entity.registerSystem(voice);
  });
  tearDown(() async {
    await voice.dispose();
    bus.dispose();
  });

  for (final endpoint in [0x10, 0x4a]) {
    test(
      'sends final recognition before the reply on endpoint $endpoint',
      () async {
        voice.selectEndpoint(endpoint);
        await voice.sendTextReply('回答', recognizedText: '问题');
        expect(component.sent.map((e) => e.$1), [endpoint, endpoint]);
        expect(component.sent[0].$2, [0x07, 1, ...utf8.encode('问题'), 0]);
        expect(component.sent[1].$2, [0x09, ...utf8.encode('回答'), 0]);
      },
    );
  }

  test(
    'recording queues both recognition and answer until audio ends',
    () async {
      voice.handlePayload(0x10, Uint8List.fromList([1]));
      await voice.sendTextReply('answer', recognizedText: 'question');
      expect(component.sent, isEmpty);
      voice.handlePayload(0x10, Uint8List.fromList([2]));
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(component.sent.map((e) => e.$2.first), [7, 9]);
    },
  );

  test(
    'a new session cancels an old answer while recognition is in flight',
    () async {
      final gate = Completer<void>();
      component.gate = gate;
      final sending = voice.sendTextReply('old', recognizedText: 'question');
      voice.handlePayload(0x10, Uint8List.fromList([1]));
      gate.complete();
      await sending;
      expect(component.sent.map((e) => e.$2.first), [7]);
    },
  );
}
