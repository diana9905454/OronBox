import 'package:oronbox/src/core/asr/asr_runtime.dart';

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oronbox/src/core/asr/asr.dart';
import 'package:oronbox/src/core/asr/asr_benchmark.dart';
import 'package:oronbox/src/core/asr/cloud_asr_protocol.dart';
import 'package:oronbox/src/core/asr/asr_model_store.dart';
import 'package:oronbox/src/core/asr/local_asr.dart';
import 'package:oronbox/src/core/asr/wetype_asr.dart';
import 'package:oronbox/src/core/asr/doubao_asr.dart';
import 'package:oronbox/src/core/logging/logging_service.dart';

class VoiceRecognitionState {
  const VoiceRecognitionState({
    this.backend = AsrBackend.manual,
    this.preparing = false,
    this.running = false,
    this.finishing = false,
    this.completed = false,
    this.text = '',
    this.error,
    this.modelInstalled = false,
    this.downloadProgress,
    this.round = 0,
  });
  final AsrBackend backend;
  final bool preparing, running, finishing, completed, modelInstalled;
  final String text;
  final String? error;
  final double? downloadProgress;
  final int round;
  VoiceRecognitionState copyWith({
    AsrBackend? backend,
    bool? preparing,
    bool? running,
    bool? finishing,
    bool? completed,
    String? text,
    String? error,
    bool clearError = false,
    bool? modelInstalled,
    double? downloadProgress,
    bool clearProgress = false,
    int? round,
  }) => VoiceRecognitionState(
    backend: backend ?? this.backend,
    preparing: preparing ?? this.preparing,
    running: running ?? this.running,
    finishing: finishing ?? this.finishing,
    completed: completed ?? this.completed,
    text: text ?? this.text,
    error: clearError ? null : error ?? this.error,
    modelInstalled: modelInstalled ?? this.modelInstalled,
    downloadProgress: clearProgress
        ? null
        : downloadProgress ?? this.downloadProgress,
    round: round ?? this.round,
  );
}

final asrEngineFactoryProvider =
    Provider<Future<AsrEngine> Function(AsrBackend, AsrModelStore)>(
      (ref) =>
          (backend, model) async => switch (backend) {
            AsrBackend.native || AsrBackend.wasm => await openLocalAsr(model),
            AsrBackend.wetype => WeTypeAsrEngine(),
            AsrBackend.doubao => DoubaoAsrEngine(),
            AsrBackend.manual => throw const AsrFailure('unsupported'),
          },
    );
final voiceRecognitionProvider =
    NotifierProvider.autoDispose<
      VoiceRecognitionController,
      VoiceRecognitionState
    >(VoiceRecognitionController.new);

class VoiceRecognitionController extends Notifier<VoiceRecognitionState> {
  final _model = AsrModelStore();
  AsrBenchmarkRun? _benchmark;
  AsrEngine? _engine;
  AsrSession? _session;
  StreamSubscription<AsrResult>? _subscription;
  Future<AsrSession?>? _opening;
  Future<void> _audioTail = Future.value();
  CancelToken? _download;
  int _generation = 0;
  int _queuedSamples = 0;
  bool _ended = false;
  bool _suspended = false;
  final _log = getLogger('VoiceRecognition');

  @override
  VoiceRecognitionState build() {
    ref.onDispose(() {
      _generation++;
      unawaited(_benchmark?.cancel());
      _download?.cancel();
      unawaited(_subscription?.cancel());
      unawaited(_session?.cancel().catchError((Object _) {}));
      unawaited(_engine?.dispose().catchError((Object _) {}));
    });
    Future<void>.microtask(() async {
      try {
        final installed =
            await _model.isInstalled() && await isAsrRuntimeInstalled();
        if (ref.mounted) state = state.copyWith(modelInstalled: installed);
      } catch (_) {
        /* Installation is checked again before model use. */
      }
    });
    return const VoiceRecognitionState();
  }

  Future<AsrBenchmarkReport> replay(
    Float32List pcm, {
    List<Uint8List>? opus,
  }) async {
    if (_benchmark != null ||
        state.running ||
        state.preparing ||
        _engine == null) {
      throw const AsrFailure('busy');
    }
    await cancel();
    if (!ref.mounted || _engine == null) throw const AsrFailure('cancelled');
    final run = AsrBenchmarkRun();
    _benchmark = run;
    state = state.copyWith(preparing: true);
    try {
      return await run.run(
        _engine!,
        pcm,
        opus: state.backend == AsrBackend.wetype ? opus : null,
      );
    } finally {
      if (identical(_benchmark, run)) _benchmark = null;
      if (ref.mounted) state = state.copyWith(preparing: false);
    }
  }

  Future<void> resetCloudIdentity() async {
    final backend = state.backend;
    if (backend != AsrBackend.wetype && backend != AsrBackend.doubao) return;
    await cancel();
    if (!ref.mounted) return;
    state = state.copyWith(preparing: true, clearError: true);
    try {
      await AsrIdentityStore().reset(backend.name);
      if (ref.mounted) await select(backend);
    } catch (_) {
      if (ref.mounted) {
        state = state.copyWith(preparing: false, error: 'identity_reset');
      }
    }
  }

  Future<void> select(AsrBackend backend) async {
    final generation = _generation + 1;
    await cancel();
    if (!ref.mounted || generation != _generation) return;
    _suspended = false;
    state = state.copyWith(
      backend: backend,
      preparing: true,
      text: '',
      completed: false,
      clearError: true,
    );
    final old = _engine;
    _engine = null;
    await old?.dispose();
    if (!ref.mounted || generation != _generation) return;
    if (backend == AsrBackend.manual) {
      state = state.copyWith(preparing: false);
      return;
    }
    if ((kIsWeb && backend == AsrBackend.native) ||
        (!kIsWeb && backend == AsrBackend.wasm) ||
        (kIsWeb && backend == AsrBackend.doubao)) {
      state = state.copyWith(preparing: false, error: 'unsupported');
      return;
    }
    try {
      final engine = await ref.read(asrEngineFactoryProvider)(backend, _model);
      if (!ref.mounted || generation != _generation) {
        await engine.dispose();
        return;
      }
      _engine = engine;
      state = state.copyWith(preparing: false, clearError: true);
    } catch (error) {
      _fail(error, generation);
    }
  }

  void startRound() {
    if (state.backend == AsrBackend.manual || state.preparing) return;
    final generation = ++_generation;
    _ended = false;
    _queuedSamples = 0;
    _audioTail = Future.value();
    state = state.copyWith(
      running: true,
      finishing: false,
      completed: false,
      text: '',
      clearError: true,
      round: generation,
    );
    _opening = _open(generation);
  }

  Future<AsrSession?> _open(int generation) async {
    try {
      final previousSubscription = _subscription;
      final previousSession = _session;
      _subscription = null;
      _session = null;
      await previousSubscription?.cancel();
      await previousSession?.cancel();
      if (!ref.mounted || generation != _generation) return null;
      final engine = _engine;
      if (engine == null) throw const AsrFailure('model_missing');
      final session = await engine.start();
      if (!ref.mounted || generation != _generation) {
        await session.cancel();
        return null;
      }
      _session = session;
      _subscription = session.results.listen((result) {
        if (!ref.mounted || generation != _generation || state.completed) {
          return;
        }
        state = state.copyWith(
          text: result.text,
          completed: result.isFinal,
          running: !result.isFinal,
          finishing: result.isFinal ? false : state.finishing,
          error: result.isFinal && result.text.trim().isEmpty ? 'empty' : null,
          clearError: !(result.isFinal && result.text.trim().isEmpty),
        );
      }, onError: (Object error) => _fail(error, generation));
      return session;
    } catch (error) {
      _fail(error, generation);
      return null;
    }
  }

  void addAudio(Float32List pcm, Uint8List opus) {
    if (!state.running || _ended || pcm.isEmpty) return;
    final generation = _generation;
    _queuedSamples += pcm.length;
    if (_queuedSamples > 16000 * 5) {
      _fail(const AsrFailure('slow'), generation);
      return;
    }
    final samples = Float32List.fromList(pcm);
    final packet = Uint8List.fromList(opus);
    final opening = _opening;
    _audioTail = _audioTail
        .then((_) async {
          if (!ref.mounted || generation != _generation) return;
          final session = await opening;
          if (session != null && ref.mounted && generation == _generation) {
            await session.addAudio(samples, opus: packet);
          }
        })
        .catchError((Object error) {
          _fail(error, generation);
        })
        .whenComplete(() {
          if (generation == _generation) _queuedSamples -= samples.length;
        });
  }

  Future<void> finishRound() async {
    if (_ended || !state.running) return;
    _ended = true;
    final generation = _generation;
    state = state.copyWith(finishing: true);
    try {
      await _audioTail;
      final session = await _opening;
      if (session != null && ref.mounted && generation == _generation) {
        await session.finishInput();
      }
    } catch (error) {
      _fail(error, generation);
    }
  }

  void _fail(Object error, int generation) {
    if (!ref.mounted || generation != _generation) return;
    final code = error is AsrFailure ? error.code : 'connection';
    _generation++;
    _log.warning('Speech recognition failed: $code');
    state = state.copyWith(
      preparing: false,
      running: false,
      finishing: false,
      error: code,
    );
    _ended = true;
    unawaited(_session?.cancel().catchError((Object _) {}));
  }

  Future<void> cancel() async {
    final generation = ++_generation;
    await _benchmark?.cancel();
    _ended = true;
    final subscription = _subscription;
    final session = _session;
    _subscription = null;
    _session = null;
    await subscription?.cancel();
    await session?.cancel();
    if (ref.mounted && generation == _generation) {
      state = state.copyWith(
        running: false,
        finishing: false,
        preparing: false,
      );
    }
  }

  Future<void> suspend() async {
    _suspended = true;
    final engine = _engine;
    _engine = null;
    await cancel();
    await engine?.dispose();
  }

  Future<void> downloadModel() async {
    if (_download != null) return;
    final token = CancelToken();
    _download = token;
    state = state.copyWith(downloadProgress: 0, clearError: true);
    var lastUpdate = DateTime.fromMillisecondsSinceEpoch(0);
    try {
      final runtimeBytes = asrRuntimeDownloadBytes;
      final totalBytes = runtimeBytes + AsrModelStore.totalBytes;
      await installAsrRuntime(
        cancel: token,
        onProgress: (received, total) {
          if (ref.mounted) {
            state = state.copyWith(downloadProgress: received / totalBytes);
          }
        },
      );
      await _model.install(
        cancel: token,
        onProgress: (received, total) {
          final now = DateTime.now();
          if (ref.mounted &&
              (now.difference(lastUpdate).inMilliseconds >= 100 ||
                  received == total)) {
            lastUpdate = now;
            state = state.copyWith(
              downloadProgress: ((runtimeBytes + received) / totalBytes).clamp(
                0,
                1,
              ),
            );
          }
        },
      );
      if (!ref.mounted) return;
      state = state.copyWith(modelInstalled: true, clearProgress: true);
      if (!_suspended &&
          (state.backend == AsrBackend.native ||
              state.backend == AsrBackend.wasm)) {
        await select(state.backend);
      }
    } catch (error) {
      if (ref.mounted) {
        state = state.copyWith(
          clearProgress: true,
          error: error is AsrFailure && error.code != 'cancelled'
              ? error.code
              : token.isCancelled
              ? null
              : 'model_download',
        );
      }
    } finally {
      _download = null;
    }
  }

  void cancelDownload() => _download?.cancel();
  Future<void> removeModel() async {
    await select(AsrBackend.manual);
    try {
      await _model.remove();
      await removeAsrRuntime();
      if (ref.mounted) state = state.copyWith(modelInstalled: false);
    } catch (_) {
      if (ref.mounted) state = state.copyWith(error: 'model_storage');
    }
  }
}
