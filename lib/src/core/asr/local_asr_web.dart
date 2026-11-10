import 'package:oronbox/src/core/storage/app_data_directory.dart';

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'asr.dart';
import 'asr_model_store.dart';

Future<AsrEngine> openLocalAsr(AsrModelStore model) async {
  final engine = _WebAsrEngine();
  try {
    final arguments = JSObject();
    arguments['assets'] = Uri.parse(web.document.baseURI)
        .resolve('assets/packages/sherpa_onnx_web/assets')
        .toString()
        .toJS;
    final files = JSObject();
    final store = await model.storage;
    for (final file in AsrModelStore.files) {
      final bytes = await store.read(file.name);
      if (bytes == null) throw const AsrFailure('model_missing');
      files[file.name] = bytes.toJS;
    }
    arguments['files'] = files;
    await engine.request('load', arguments);
    return engine;
  } catch (_) {
    await engine.dispose();
    rethrow;
  }
}

class _WebAsrEngine implements AsrEngine {
  _WebAsrEngine() {
    _worker.onmessage = ((web.MessageEvent event) {
      final data = (event.data as JSObject).dartify() as Map;
      if (data['kind'] == 'result') {
        _events.add(
          AsrResult(data['text'] as String, isFinal: data['final'] as bool),
        );
      } else {
        final waiter = _pending.remove((data['id'] as num).toInt());
        if (data['kind'] == 'error') {
          waiter?.completeError(const AsrFailure('local_inference'));
        } else {
          waiter?.complete();
        }
      }
    }).toJS;
    _worker.onerror = ((web.Event _) {
      for (final waiter in _pending.values) {
        if (!waiter.isCompleted) {
          waiter.completeError(const AsrFailure('local_inference'));
        }
      }
      _pending.clear();
    }).toJS;
  }
  final _worker = web.Worker(
    Uri.parse(web.document.baseURI).resolve('asr_worker.js').toString().toJS,
  );
  final _events = StreamController<AsrResult>.broadcast();
  final _pending = <int, Completer<void>>{};
  int _id = 0;
  bool _closed = false;
  bool _active = false;
  Future<void> request(String method, [JSAny? argument]) {
    if (_closed) return Future.error(const AsrFailure('cancelled'));
    final id = ++_id;
    final waiter = Completer<void>();
    _pending[id] = waiter;
    final message = JSObject();
    message['id'] = id.toJS;
    message['method'] = method.toJS;
    message['argument'] = argument;
    _worker.postMessage(message);
    return waiter.future.timeout(
      const Duration(seconds: 45),
      onTimeout: () {
        _pending.remove(id);
        throw const AsrFailure('timeout');
      },
    );
  }

  @override
  Future<AsrSession> start() async {
    if (_active) throw const AsrFailure('busy');
    await request('start');
    _active = true;
    return _WebSession(this);
  }

  @override
  Future<void> dispose() async {
    if (_closed) return;
    try {
      await request('close').timeout(const Duration(seconds: 1));
    } catch (_) {}
    _closed = true;
    _worker.terminate();
    for (final waiter in _pending.values) {
      if (!waiter.isCompleted) {
        waiter.completeError(const AsrFailure('cancelled'));
      }
    }
    _pending.clear();
    await _events.close();
  }
}

class _WebSession implements AsrSession {
  _WebSession(this.engine);
  final _WebAsrEngine engine;
  bool _done = false;
  bool _cancelled = false;
  @override
  Stream<AsrResult> get results => engine._events.stream;
  @override
  Future<void> addAudio(Float32List pcm, {Uint8List? opus}) async {
    if (!_done) await engine.request('audio', pcm.toJS);
  }

  @override
  Future<void> finishInput() async {
    if (_done) return;
    _done = true;
    try {
      await engine.request('finish');
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
      await engine.request('cancel');
    } finally {
      engine._active = false;
    }
  }
}

Future<bool> modelUsedByCurrentProcess(AppDataDirectory directory) async =>
    false;
