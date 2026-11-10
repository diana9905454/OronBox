import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oronbox/src/core/ai/ai_settings_store.dart';
import 'package:oronbox/src/core/logging/logging_service.dart';
import 'package:oronbox/src/core/wasm/wasm_opus_decoder.dart';
import 'package:oronbox/src/device/core/event_bus.dart';
import 'package:oronbox/src/features/devices/controllers/device_manager.dart';
import 'package:oronbox/src/features/voice/application/voice_ai_orchestrator.dart';
import 'package:oronbox/src/features/voice/application/voice_recognition_controller.dart';
import 'package:oronbox/src/features/voice/application/voice_session_coordinator.dart';

final globalVoiceAssistantServiceProvider =
    Provider<GlobalVoiceAssistantService>((ref) {
      final service = GlobalVoiceAssistantService(ref);
      ref.onDispose(service.dispose);
      return service;
    });

/// 全局穿戴语音助手后台服务
/// 当处于非实验室页面且开启全局 AI 时，全自动接管穿戴端语音流：
/// 1. Opus 解码为 PCM 并驱动流式 ASR
/// 2. 波形能量计算与实时文字增量监测，当波形平静或无文字增量持续 3s 判定说完，主动向设备下发 STOP_CAPTURE 停麦
/// 3. 定稿后触发 VoiceAiOrchestrator 编排，获取大模型回答并推回设备
class GlobalVoiceAssistantService {
  final Ref _ref;
  static final _log = getLogger('GlobalVoiceAssistantService');

  static const double _silenceRmsThreshold = 0.035;
  static const Duration _silenceTimeout = Duration(seconds: 3);
  static const Duration _noSpeechTimeout = Duration(seconds: 5);

  StreamSubscription<DeviceEvent>? _eventSub;
  ProviderSubscription<VoiceRecognitionState>? _asrSub;
  WasmOpusDecoder? _decoder;
  Future<WasmOpusDecoder?>? _decoderInitialization;
  bool _disposed = false;
  Timer? _partialDebounce;
  Timer? _silenceTimer;

  String _lastSentPartial = '';
  String _lastRecognizedText = '';
  bool _hasActiveSession = false;
  bool _hasSpoken = false;
  bool _stoppedCapture = false;
  bool _aiStartedForSession = false;
  int _sessionToken = 0;
  DateTime? _sessionStartTime;
  DateTime? _lastVoiceActiveTime;
  DateTime? _lastTextIncrementTime;
  String? _activeDeviceId;
  XiaoAiSessionTarget? _activeTarget;

  GlobalVoiceAssistantService(this._ref) {
    final devMgr = _ref.read(deviceManagerProvider.notifier);
    _eventSub = devMgr.deviceEvents.listen(_handleDeviceEvent);

    final coordinator = _ref.read(voiceSessionCoordinatorProvider);
    coordinator.claim(VoiceSessionOwner.global);

    _asrSub = _ref.listen<VoiceRecognitionState>(
      voiceRecognitionProvider,
      (previous, next) => _handleAsrState(previous, next),
      fireImmediately: false,
    );

    unawaited(_init());
  }

  Future<void> _init() async {
    await _getDecoder();
    if (_disposed) return;

    final desired = AiSettingsStore.asrBackend;
    unawaited(
      _ref.read(voiceRecognitionProvider.notifier).ensureBackend(desired),
    );
  }

  void dispose() {
    _disposed = true;
    _eventSub?.cancel();
    _asrSub?.close();
    _partialDebounce?.cancel();
    _silenceTimer?.cancel();
    _decoder?.dispose();
    _decoder = null;
    _ref
        .read(voiceSessionCoordinatorProvider)
        .release(VoiceSessionOwner.global);
  }

  Future<WasmOpusDecoder?> _getDecoder() async {
    if (_disposed) return null;
    final decoder = _decoder;
    if (decoder != null) return decoder;
    return _decoderInitialization ??= _createDecoder();
  }

  Future<WasmOpusDecoder?> _createDecoder() async {
    try {
      final decoder = await WasmOpusDecoder.create();
      if (_disposed) {
        decoder.dispose();
        return null;
      }
      return _decoder = decoder;
    } catch (e) {
      _log.warning('Failed to create WasmOpusDecoder: $e');
      return null;
    } finally {
      _decoderInitialization = null;
    }
  }

  void _handleDeviceEvent(DeviceEvent event) {
    if (!AiSettingsStore.globalAiEnabled || !AiSettingsStore.wearableEnabled) {
      return;
    }

    final coordinator = _ref.read(voiceSessionCoordinatorProvider);
    if (!coordinator.owns(VoiceSessionOwner.global)) {
      return;
    }

    if (event is XiaoAiSessionStarted) {
      final token = ++_sessionToken;
      _hasActiveSession = true;
      _aiStartedForSession = false;
      _activeDeviceId = event.deviceId;
      final sessionId = (event.capabilities['sessionId'] as num?)?.toInt();
      final generation = (event.capabilities['generation'] as num?)?.toInt();
      _activeTarget = sessionId == null || generation == null
          ? null
          : XiaoAiSessionTarget(
              deviceId: event.deviceId,
              sessionId: sessionId,
              generation: generation,
              useStream: AiSettingsStore.streamEnabled,
            );
      _lastSentPartial = '';
      _lastRecognizedText = '';
      _hasSpoken = false;
      _stoppedCapture = false;
      final now = DateTime.now();
      _sessionStartTime = now;
      _lastVoiceActiveTime = now;
      _lastTextIncrementTime = now;

      _partialDebounce?.cancel();
      _silenceTimer?.cancel();
      _silenceTimer = Timer.periodic(
        const Duration(milliseconds: 100),
        (_) => _checkSilenceTimeout(),
      );

      _decoder?.reset();

      final desired = AiSettingsStore.asrBackend;
      _ref.read(voiceRecognitionProvider.notifier).ensureBackend(desired).then((
        ready,
      ) {
        if (_hasActiveSession && token == _sessionToken && ready) {
          _ref.read(voiceRecognitionProvider.notifier).startRound();
        } else if (_hasActiveSession && token == _sessionToken) {
          _hasActiveSession = false;
          _activeDeviceId = null;
          _activeTarget = null;
        }
      });
      _log.info(
        'Global voice session started: dev=${event.deviceId} '
        'session=$sessionId generation=$generation '
        'replyMode=${event.capabilities['replyMode']} '
        'streamEnabled=${AiSettingsStore.streamEnabled}',
      );
    } else if (event is XiaoAiOpusFrameReceived) {
      if (!_hasActiveSession || _stoppedCapture) return;
      _processAudioFrame(event.frame);
    } else if (event is XiaoAiSessionEnded) {
      if (!_hasActiveSession) return;
      _silenceTimer?.cancel();
      _partialDebounce?.cancel();
      if (event.cancelled) {
        unawaited(_ref.read(voiceRecognitionProvider.notifier).cancel());
        _hasActiveSession = false;
        _activeDeviceId = null;
        _activeTarget = null;
        _log.info('Global voice session cancelled by device');
      } else {
        _log.info('Global voice recording completed; flushing ASR');
        unawaited(_ref.read(voiceRecognitionProvider.notifier).finishRound());
      }
    }
  }

  Future<void> _processAudioFrame(Uint8List frame) async {
    final token = _sessionToken;
    final decoder = await _getDecoder();
    if (_disposed ||
        decoder == null ||
        token != _sessionToken ||
        !_hasActiveSession ||
        _stoppedCapture) {
      return;
    }
    try {
      final pcm = decoder.decode(frame);
      if (pcm.isNotEmpty) {
        var sumSquares = 0.0;
        for (var i = 0; i < pcm.length; i++) {
          final s = pcm[i];
          sumSquares += s * s;
        }
        final rms = math.sqrt(sumSquares / math.max(1, pcm.length));
        if (rms >= _silenceRmsThreshold) {
          _hasSpoken = true;
          _lastVoiceActiveTime = DateTime.now();
        }
      }
      _ref.read(voiceRecognitionProvider.notifier).addAudio(pcm, frame);
    } catch (e) {
      _log.warning('Failed to decode Opus frame: $e');
    }
  }

  void _checkSilenceTimeout() {
    if (!_hasActiveSession || _stoppedCapture) return;

    final now = DateTime.now();

    if (_hasSpoken) {
      final voiceQuietDuration = now.difference(_lastVoiceActiveTime ?? now);
      final textIdleDuration = now.difference(_lastTextIncrementTime ?? now);

      if (voiceQuietDuration >= _silenceTimeout &&
          textIdleDuration >= _silenceTimeout) {
        _log.info(
          'Silence detected: quiet=${voiceQuietDuration.inMilliseconds}ms, '
          'textIdle=${textIdleDuration.inMilliseconds}ms. Stopping capture.',
        );
        unawaited(_triggerSilenceStop());
      }
    } else {
      final elapsed = now.difference(_sessionStartTime ?? now);
      if (elapsed >= _noSpeechTimeout) {
        _log.info(
          'No speech detected within 5s. Stopping capture and aborting.',
        );
        unawaited(_triggerEmptyTimeout());
      }
    }
  }

  Future<void> _triggerSilenceStop() async {
    if (_stoppedCapture) return;
    _stoppedCapture = true;
    _silenceTimer?.cancel();
    _partialDebounce?.cancel();

    final manager = _ref.read(deviceManagerProvider.notifier);
    try {
      final target = _activeTarget;
      await manager.stopXiaoAiCapture(
        target: target,
        notifyDevice: manager.shouldStopXiaoAiCapture(target: target),
      );
    } catch (e) {
      _log.warning('Failed to stop capture: $e');
    }

    try {
      await _ref.read(voiceRecognitionProvider.notifier).finishRound();
    } catch (e) {
      _log.warning('Failed to finish ASR round: $e');
    }
  }

  Future<void> _triggerEmptyTimeout() async {
    if (_stoppedCapture) return;
    _stoppedCapture = true;
    _silenceTimer?.cancel();
    _partialDebounce?.cancel();
    _hasActiveSession = false;
    _activeDeviceId = null;
    final target = _activeTarget;
    _activeTarget = null;

    final manager = _ref.read(deviceManagerProvider.notifier);
    try {
      await manager.stopXiaoAiCapture(target: target, force: true);
    } catch (e) {
      _log.warning('Failed to stop capture on timeout: $e');
    }

    try {
      await _ref.read(voiceRecognitionProvider.notifier).cancel();
    } catch (e) {
      _log.warning('Failed to cancel ASR on timeout: $e');
    }
  }

  void _handleAsrState(
    VoiceRecognitionState? previous,
    VoiceRecognitionState next,
  ) {
    if (!AiSettingsStore.globalAiEnabled || !AiSettingsStore.wearableEnabled) {
      return;
    }
    final coordinator = _ref.read(voiceSessionCoordinatorProvider);
    if (!coordinator.owns(VoiceSessionOwner.global)) {
      return;
    }
    if (!_hasActiveSession) {
      return;
    }

    if (next.error != null && next.error != previous?.error) {
      _log.warning('Global ASR failed: ${next.error}');
      _silenceTimer?.cancel();
      _partialDebounce?.cancel();
      _hasActiveSession = false;
      _activeDeviceId = null;
      _activeTarget = null;
      return;
    }

    final manager = _ref.read(deviceManagerProvider.notifier);

    // 1. 中间流式文字：检测增量并以 120ms 防抖推入手表屏幕回显
    if (next.running && !next.completed && next.text.trim().isNotEmpty) {
      final text = next.text.trim();
      if (text != _lastRecognizedText) {
        _lastRecognizedText = text;
        _hasSpoken = true;
        _lastTextIncrementTime = DateTime.now();
      }

      if (text != _lastSentPartial &&
          (_partialDebounce == null || !_partialDebounce!.isActive)) {
        final target = _activeTarget;
        _partialDebounce = Timer(const Duration(milliseconds: 120), () {
          if (!_hasActiveSession ||
              !coordinator.owns(VoiceSessionOwner.global)) {
            return;
          }
          _lastSentPartial = text;
          unawaited(
            manager
                .sendXiaoAiRecognitionResult(
                  text,
                  isFinal: false,
                  target: target,
                )
                .catchError((Object error, StackTrace stack) {
                  _log.fine('Discarded stale partial recognition: $error');
                }),
          );
        });
      }
    }

    // 2. 最终定稿文本：锁定设备屏幕并交付大模型编排
    if (next.completed && !_aiStartedForSession) {
      final finalText = next.text.trim();
      final target = _activeTarget;
      final token = _sessionToken;
      _silenceTimer?.cancel();
      _partialDebounce?.cancel();
      _hasActiveSession = false;
      final deviceId =
          _activeDeviceId ??
          _ref.read(deviceManagerProvider).currentDevice?.addr ??
          '';
      _activeDeviceId = null;
      _aiStartedForSession = true;

      if (!_stoppedCapture) {
        _stoppedCapture = true;
        unawaited(() async {
          try {
            await manager.stopXiaoAiCapture(
              target: target,
              notifyDevice: manager.shouldStopXiaoAiCapture(target: target),
            );
          } catch (error) {
            _log.fine('Discarded stale capture stop: $error');
          }
        }());
      }

      if (finalText.isNotEmpty) {
        // 锁定屏幕最终显示
        unawaited(
          manager
              .sendXiaoAiRecognitionResult(
                finalText,
                isFinal: true,
                target: target,
              )
              .catchError((Object error, StackTrace stack) {
                _log.fine('Discarded stale final recognition: $error');
              }),
        );

        // 移交 AI 编排中心生成回答并向设备回复
        _log.info(
          'Global AI processing final recognition: "$finalText" for $deviceId',
        );
        unawaited(
          _ref
              .read(voiceAiOrchestratorProvider)
              .handleVoiceInput(
                recognizedText: finalText,
                deviceId: deviceId,
                target: target,
              )
              .then(
                (_) => _log.info(
                  'Global AI response completed: dev=$deviceId '
                  'stale=${token != _sessionToken}',
                ),
                onError: (Object error, StackTrace stack) {
                  _log.warning(
                    'Global AI response failed: $error',
                    error,
                    stack,
                  );
                  return false;
                },
              )
              .whenComplete(() {
                if (token == _sessionToken) {
                  _activeTarget = null;
                }
              }),
        );
      } else {
        _log.info('ASR completed with empty text');
      }
    }
  }
}
