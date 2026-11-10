import 'dart:async';
import 'dart:typed_data';

import 'asr.dart';

class AsrBenchmarkReport {
  const AsrBenchmarkReport({
    required this.audioMilliseconds,
    required this.elapsedMilliseconds,
    required this.firstResultMilliseconds,
    required this.text,
  });
  final int audioMilliseconds, elapsedMilliseconds;
  final int? firstResultMilliseconds;
  final String text;
  double get realTimeFactor => elapsedMilliseconds / audioMilliseconds;
  Map<String, Object?> toJson() => {
    'format': 'oronbox-asr-benchmark',
    'version': 1,
    'mode': 'replay-fast',
    'sampleRate': 16000,
    'audioMilliseconds': audioMilliseconds,
    'elapsedMilliseconds': elapsedMilliseconds,
    'firstResultMilliseconds': firstResultMilliseconds,
    'realTimeFactor': realTimeFactor,
    'characters': text.runes.length,
  };
}

/// Replays a bounded recording through the same engine without device output.
class AsrBenchmarkRun {
  AsrSession? _session;
  bool _cancelled = false;
  Future<void> cancel() async {
    _cancelled = true;
    await _session?.cancel();
  }

  Future<AsrBenchmarkReport> run(
    AsrEngine engine,
    Float32List pcm, {
    List<Uint8List>? opus,
  }) async {
    if (pcm.isEmpty || pcm.length > 16000 * 60 || pcm.any((x) => !x.isFinite)) {
      throw const AsrFailure('audio_format');
    }
    if (opus != null &&
        (opus.length * 320 != pcm.length ||
            opus.any((frame) => frame.isEmpty))) {
      throw const AsrFailure('opus_format');
    }
    final stopwatch = Stopwatch()..start();
    final finished = Completer<String>();
    unawaited(finished.future.catchError((Object _) => ''));
    int? first;
    StreamSubscription<AsrResult>? subscription;
    try {
      final session = await engine
          .start()
          .then((session) async {
            if (_cancelled) {
              await session.cancel();
              throw const AsrFailure('cancelled');
            }
            return session;
          })
          .timeout(const Duration(seconds: 20));
      _session = session;
      if (_cancelled) throw const AsrFailure('cancelled');
      subscription = session.results.listen(
        (result) {
          if (result.text.isNotEmpty) first ??= stopwatch.elapsedMilliseconds;
          if (result.isFinal && !finished.isCompleted) {
            finished.complete(result.text);
          }
        },
        onError: (Object error, StackTrace stack) {
          if (!finished.isCompleted) finished.completeError(error, stack);
        },
        onDone: () {
          if (!finished.isCompleted) {
            finished.completeError(const AsrFailure('service_ended'));
          }
        },
      );
      for (
        var offset = 0;
        offset < pcm.length;
        offset += opus == null ? 640 : 320
      ) {
        if (_cancelled) throw const AsrFailure('cancelled');
        final end = (offset + (opus == null ? 640 : 320)).clamp(0, pcm.length);
        await session.addAudio(
          Float32List.sublistView(pcm, offset, end),
          opus: opus?[offset ~/ 320],
        );
        // Keep cancellation and UI updates responsive even with a synchronous engine.
        if (offset % 16000 == 0) await Future<void>.delayed(Duration.zero);
      }
      await session.finishInput().timeout(const Duration(seconds: 30));
      final text = await finished.future.timeout(const Duration(seconds: 10));
      if (_cancelled) throw const AsrFailure('cancelled');
      if (text.trim().isEmpty) throw const AsrFailure('empty');
      return AsrBenchmarkReport(
        audioMilliseconds: (pcm.length * 1000 / 16000).ceil(),
        elapsedMilliseconds: stopwatch.elapsedMilliseconds,
        firstResultMilliseconds: first,
        text: text,
      );
    } on TimeoutException {
      throw AsrFailure(_cancelled ? 'cancelled' : 'timeout');
    } catch (_) {
      if (_cancelled) throw const AsrFailure('cancelled');
      rethrow;
    } finally {
      _cancelled = true;
      await subscription?.cancel();
      await _session?.cancel();
      _session = null;
    }
  }
}

Float32List decodePcm16Wave(Uint8List bytes) {
  if (bytes.length < 44 || bytes.length > 2 * 16000 * 60 + 65536) {
    throw const AsrFailure('audio_format');
  }
  final data = ByteData.sublistView(bytes);
  String tag(int offset) =>
      String.fromCharCodes(bytes.sublist(offset, offset + 4));
  if (tag(0) != 'RIFF' ||
      tag(8) != 'WAVE' ||
      data.getUint32(4, Endian.little) + 8 != bytes.length) {
    throw const AsrFailure('audio_format');
  }
  var format = false;
  Uint8List? pcm;
  for (var offset = 12; offset + 8 <= bytes.length;) {
    final size = data.getUint32(offset + 4, Endian.little);
    final end = offset + 8 + size;
    if (end > bytes.length) throw const AsrFailure('audio_format');
    if (tag(offset) == 'fmt ') {
      if (size < 16 ||
          data.getUint16(offset + 8, Endian.little) != 1 ||
          data.getUint16(offset + 10, Endian.little) != 1 ||
          data.getUint32(offset + 12, Endian.little) != 16000 ||
          data.getUint16(offset + 22, Endian.little) != 16) {
        throw const AsrFailure('audio_format');
      }
      format = true;
    } else if (tag(offset) == 'data') {
      if (pcm != null) throw const AsrFailure('audio_format');
      pcm = Uint8List.sublistView(bytes, offset + 8, end);
    }
    offset = end + (size & 1);
  }
  if (!format ||
      pcm == null ||
      pcm.isEmpty ||
      pcm.length.isOdd ||
      pcm.length > 2 * 16000 * 60) {
    throw const AsrFailure('audio_format');
  }
  return decodePcm16(pcm);
}

Float32List decodePcm16(Uint8List pcm) {
  if (pcm.length.isOdd) throw const AsrFailure('audio_format');
  final data = ByteData.sublistView(pcm);
  return Float32List.fromList([
    for (var i = 0; i < pcm.length; i += 2)
      data.getInt16(i, Endian.little) / 32768,
  ]);
}
