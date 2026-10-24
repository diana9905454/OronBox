import 'dart:async';
import 'dart:ffi';

import 'asr_runtime_io.dart';

import 'dart:isolate';
import 'dart:io';

import 'package:uuid/uuid.dart';
import 'package:oronbox/src/core/storage/app_data_directory.dart';

import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import 'asr.dart';
import 'asr_model_store.dart';

Future<AsrEngine> openLocalAsr(AsrModelStore model) async {
  final root =
      '${(await getApplicationSupportDirectory()).path}/${model.relativeDirectory}';
  final runtime = await acquireAsrRuntime();
  try {
    final engine = await NativeAsrEngine.open(root, libraryPath: runtime.path);
    engine._runtimeRelease = runtime.release;
    return engine;
  } catch (_) {
    await runtime.release();
    rethrow;
  }
}

Future<bool> modelUsedByCurrentProcess(AppDataDirectory directory) async =>
    (await directory.files()).any(
      (file) => file.path.startsWith('.usage.$pid.'),
    );

class NativeAsrEngine implements AsrEngine {
  NativeAsrEngine._();
  final _pending = <int, Completer<Object?>>{};
  final _events = StreamController<AsrResult>.broadcast();
  File? _usageMarker;
  Isolate? _worker;
  late ReceivePort _port;
  SendPort? _commands;
  StreamSubscription<dynamic>? _subscription;
  int _next = 0;
  Future<void> Function()? _runtimeRelease;
  bool _closed = false;
  bool _closing = false;
  bool _active = false;
  static Future<NativeAsrEngine> open(
    String modelRoot, {
    String? libraryPath,
  }) async {
    final engine = NativeAsrEngine._();
    engine._usageMarker = File('$modelRoot/.usage.$pid.${const Uuid().v4()}');
    await engine._usageMarker!.writeAsBytes(const [], flush: true);
    engine._port = ReceivePort();
    final ready = Completer<SendPort>();
    engine._subscription = engine._port.listen((dynamic message) {
      if (message is SendPort) {
        ready.complete(message);
        return;
      }
      final result = message as List;
      if (result[0] == 'result') {
        engine._events.add(
          AsrResult(result[1] as String, isFinal: result[2] as bool),
        );
      } else {
        final waiter = engine._pending.remove(result[1] as int);
        if (result[0] == 'error') {
          waiter?.completeError(const AsrFailure('local_inference'));
        } else {
          waiter?.complete(result.length > 2 ? result[2] : null);
        }
      }
    });
    try {
      engine._worker = await Isolate.spawn(_workerMain, engine._port.sendPort);
      engine._commands = await ready.future.timeout(
        const Duration(seconds: 10),
      );
      await engine._request('load', [modelRoot, libraryPath]);
      return engine;
    } catch (_) {
      await engine.dispose();
      rethrow;
    }
  }

  Future<Object?> _request(String method, [Object? argument]) {
    if (_closed || (_closing && method != 'close')) {
      return Future.error(const AsrFailure('cancelled'));
    }
    final commands = _commands;
    if (commands == null) {
      return Future.error(const AsrFailure('local_inference'));
    }
    final id = ++_next;
    final waiter = Completer<Object?>();
    _pending[id] = waiter;
    commands.send([id, method, argument]);
    return waiter.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        _pending.remove(id);
        throw const AsrFailure('timeout');
      },
    );
  }

  @override
  Future<AsrSession> start() async {
    if (_active) throw const AsrFailure('busy');
    await _request('start');
    _active = true;
    return _NativeSession(this);
  }

  @override
  Future<void> dispose() async {
    if (_closed) return;
    _closing = true;
    if (_worker != null) {
      try {
        await _request('close').timeout(const Duration(seconds: 2));
      } catch (_) {}
    }
    _closed = true;
    for (final waiter in _pending.values) {
      waiter.completeError(const AsrFailure('cancelled'));
    }
    _pending.clear();
    _worker?.kill(priority: Isolate.immediate);
    await _subscription?.cancel();
    _port.close();
    await _events.close();
    try {
      final marker = _usageMarker;
      if (marker != null && await marker.exists()) await marker.delete();
    } finally {
      await _runtimeRelease?.call();
    }
  }
}

class _NativeSession implements AsrSession {
  _NativeSession(this.engine);
  final NativeAsrEngine engine;
  bool _done = false;
  bool _cancelled = false;
  @override
  Stream<AsrResult> get results => engine._events.stream;
  @override
  Future<void> addAudio(Float32List pcm, {Uint8List? opus}) async {
    if (!_done) {
      await engine._request(
        'audio',
        TransferableTypedData.fromList([
          pcm.buffer.asUint8List(pcm.offsetInBytes, pcm.lengthInBytes),
        ]),
      );
    }
  }

  @override
  Future<void> finishInput() async {
    if (_done) return;
    _done = true;
    try {
      await engine._request('finish');
    } finally {
      engine._active = false;
    }
  }

  @override
  Future<void> cancel() async {
    if (_cancelled) return;
    _cancelled = true;
    _done = true;
    try {
      await engine._request('cancel');
    } finally {
      engine._active = false;
    }
  }
}

void _workerMain(SendPort output) {
  final input = ReceivePort();
  output.send(input.sendPort);
  sherpa.OnlineRecognizer? recognizer;
  sherpa.OnlineStream? stream;
  var previous = '';
  input.listen((dynamic message) {
    final values = message as List;
    final id = values[0] as int;
    try {
      switch (values[1]) {
        case 'load':
          final args = values[2] as List;
          final root = args[0] as String;
          final libraryPath = args[1] as String?;
          if (Platform.isAndroid && libraryPath != null) {
            DynamicLibrary.open('$libraryPath/libonnxruntime.so');
          }
          sherpa.initBindings(libraryPath);
          recognizer = sherpa.OnlineRecognizer(
            sherpa.OnlineRecognizerConfig(
              model: sherpa.OnlineModelConfig(
                transducer: sherpa.OnlineTransducerModelConfig(
                  encoder: '$root/${AsrModelStore.files[0].name}',
                  decoder: '$root/${AsrModelStore.files[1].name}',
                  joiner: '$root/${AsrModelStore.files[2].name}',
                ),
                tokens: '$root/tokens.txt',
                numThreads: 2,
                debug: false,
              ),
              enableEndpoint: false,
            ),
          );
        case 'start':
          stream?.free();
          stream = recognizer!.createStream();
          previous = '';
        case 'audio':
          final pcm = (values[2] as TransferableTypedData)
              .materialize()
              .asFloat32List();
          stream!.acceptWaveform(samples: pcm, sampleRate: 16000);
          while (recognizer!.isReady(stream!)) {
            recognizer!.decode(stream!);
          }
          final text = recognizer!.getResult(stream!).text;
          if (text != previous) {
            previous = text;
            output.send(['result', text, false]);
          }
        case 'finish':
          stream!.acceptWaveform(
            samples: Float32List(12800),
            sampleRate: 16000,
          );
          stream!.inputFinished();
          while (recognizer!.isReady(stream!)) {
            recognizer!.decode(stream!);
          }
          output.send(['result', recognizer!.getResult(stream!).text, true]);
          stream!.free();
          stream = null;
        case 'cancel':
          stream?.free();
          stream = null;
        case 'close':
          stream?.free();
          stream = null;
          recognizer?.free();
          recognizer = null;
          input.close();
      }
      output.send(['ok', id]);
    } catch (_) {
      output.send(['error', id]);
    }
  });
}
