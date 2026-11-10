import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/core/asr/asr.dart';
import 'package:oronbox/src/core/asr/asr_benchmark.dart';

class _Engine implements AsrEngine {
  final session = _Session();
  @override
  Future<AsrSession> start() async => session;
  @override
  Future<void> dispose() async {}
}

class _Session implements AsrSession {
  final controller = StreamController<AsrResult>.broadcast(sync: true);
  int samples = 0;
  bool cancelled = false;
  final packets = <Uint8List?>[];
  @override
  Stream<AsrResult> get results => controller.stream;
  @override
  Future<void> addAudio(Float32List pcm, {Uint8List? opus}) async {
    samples += pcm.length;
    packets.add(opus);
    controller.add(const AsrResult('test'));
  }

  @override
  Future<void> finishInput() async =>
      controller.add(const AsrResult('test', isFinal: true));
  @override
  Future<void> cancel() async {
    cancelled = true;
    await controller.close();
  }
}

void main() {
  test('replay preserves samples and reports timing without exporting the transcript', () async {
    final engine = _Engine();
    final report = await AsrBenchmarkRun().run(engine, Float32List(16000));
    expect(engine.session.samples, 16000);
    expect(engine.session.cancelled, isTrue);
    expect(report.audioMilliseconds, 1000);
    expect(report.text, 'test');
    expect(report.toJson(), isNot(contains('text')));
    expect(report.firstResultMilliseconds, isNotNull);
  });
  test('WeType replay preserves original 20 ms packets', () async {
    final engine = _Engine();
    final packets = [
      Uint8List.fromList([1]),
      Uint8List.fromList([2]),
    ];
    await AsrBenchmarkRun().run(engine, Float32List(640), opus: packets);
    expect(engine.session.packets, packets);
  });
  test(
    'invalid packet duration is rejected before opening a session',
    () async {
      await expectLater(
        AsrBenchmarkRun().run(
          _Engine(),
          Float32List(1000),
          opus: [
            Uint8List.fromList([1]),
          ],
        ),
        throwsA(isA<AsrFailure>()),
      );
    },
  );
  test('WAV decoder validates channels, duration and truncated chunks', () {
    final bytes = Uint8List(48);
    final data = ByteData.sublistView(bytes);
    bytes.setAll(0, 'RIFF'.codeUnits);
    data.setUint32(4, 40, Endian.little);
    bytes.setAll(8, 'WAVEfmt '.codeUnits);
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little);
    data.setUint16(22, 1, Endian.little);
    data.setUint32(24, 16000, Endian.little);
    data.setUint16(34, 16, Endian.little);
    bytes.setAll(36, 'data'.codeUnits);
    data.setUint32(40, 4, Endian.little);
    data.setInt16(44, -32768, Endian.little);
    expect(decodePcm16Wave(bytes), [-1, 0]);
    data.setUint16(22, 2, Endian.little);
    expect(() => decodePcm16Wave(bytes), throwsA(isA<AsrFailure>()));
    data.setUint16(22, 1, Endian.little);
    data.setUint32(40, 100, Endian.little);
    expect(() => decodePcm16Wave(bytes), throwsA(isA<AsrFailure>()));
  });
}
