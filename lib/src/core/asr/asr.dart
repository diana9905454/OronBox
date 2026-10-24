import 'dart:typed_data';

enum AsrBackend { manual, native, wetype, doubao, wasm }

class AsrResult {
  const AsrResult(this.text, {this.isFinal = false});
  final String text;
  final bool isFinal;
}

class AsrFailure implements Exception {
  const AsrFailure(this.code);
  final String code;
  @override
  String toString() => 'ASR: $code';
}

abstract interface class AsrSession {
  Stream<AsrResult> get results;
  Future<void> addAudio(Float32List pcm, {Uint8List? opus});
  Future<void> finishInput();
  Future<void> cancel();
}

abstract interface class AsrEngine {
  Future<AsrSession> start();
  Future<void> dispose();
}
