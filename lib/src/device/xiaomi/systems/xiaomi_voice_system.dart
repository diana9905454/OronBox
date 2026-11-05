import 'dart:async';
import 'dart:typed_data';

import 'package:oronbox/src/core/logging/logging_service.dart';
import 'package:oronbox/src/device/core/entity.dart';
import 'package:oronbox/src/device/core/event_bus.dart';
import 'package:oronbox/src/device/xiaomi/protocol/generated/wear.pb.dart'
    as pb;
import 'package:oronbox/src/device/xiaomi/protocol/generated/wear_aivs.pb.dart'
    as aivs;
import 'package:oronbox/src/device/xiaomi/protocol/packet/l2_packet.dart';
import 'package:oronbox/src/device/xiaomi/systems/xiaomi_system.dart';

enum XiaomiVoiceReplyMode {
  templateAfterStop,
  streamAfterStop,
  templateBeforeFinish,
}

class XiaomiVoiceCommand {
  const XiaomiVoiceCommand(this.type, this.data);
  final int type;
  final Uint8List data;

  static List<XiaomiVoiceCommand> parse(Uint8List payload) {
    if (payload.isEmpty || payload[0] != 0) {
      throw const FormatException('Unsupported voice protocol');
    }
    final commands = <XiaomiVoiceCommand>[];
    var offset = 1;
    while (offset < payload.length) {
      final type = payload[offset++];
      if (type < 1 || type > 4) {
        throw const FormatException('Unknown voice command');
      }
      if (offset == payload.length && (type == 3 || type == 4)) {
        commands.add(XiaomiVoiceCommand(type, Uint8List(0)));
        break;
      }
      if (payload.length - offset < 2) {
        throw const FormatException('Truncated voice header');
      }
      final length = ByteData.sublistView(payload).getInt16(offset, Endian.big);
      offset += 2;
      if (length < 0 || length > payload.length - offset) {
        throw const FormatException('Invalid voice length');
      }
      final data = Uint8List.fromList(payload.sublist(offset, offset + length));
      offset += length;
      if ((type == 1 && length != 1 && length != 2) ||
          (type == 2 && (length == 0 || length > 4096 || length % 80 != 0)) ||
          ((type == 3 || type == 4) && length != 0)) {
        throw const FormatException('Invalid voice command data');
      }
      commands.add(XiaomiVoiceCommand(type, data));
    }
    return commands;
  }
}

class XiaomiVoiceSystem extends XiaomiSystem {
  static final _log = getLogger('XiaomiVoiceSystem');
  bool _enabled = false;
  bool _recording = false;
  bool _disposed = false;
  int? _sessionId;
  int _generation = 0;
  int _sequence = 0;
  int? _sendingGeneration;
  Future<void> _pendingRecognition = Future<void>.value();
  String? _lastPartial;
  String? _lastFinal;
  Timer? _timeout;
  Future<void> _aivsSendTail = Future<void>.value();
  Future<void>? _stopCaptureFuture;
  int _deviceCapabilityV2 = 0;
  XiaomiVoiceReplyMode _replyMode = XiaomiVoiceReplyMode.templateAfterStop;
  StreamSubscription? _capsSub;

  bool get supportsAivsLargeModel => (_deviceCapabilityV2 & 256) != 0;

  XiaomiVoiceReplyMode get replyMode => _replyMode;

  XiaoAiSessionTarget? get sessionTarget {
    final session = _sessionId;
    if (session == null) return null;
    return XiaoAiSessionTarget(
      deviceId: entity.id,
      sessionId: session,
      generation: _generation,
    );
  }

  @override
  void attach(DeviceEntity entity) {
    super.attach(entity);
    _capsSub?.cancel();
    _capsSub = this.entity.on<XiaomiDeviceCapabilitiesUpdated>().listen((
      event,
    ) {
      _deviceCapabilityV2 = event.deviceCapabilityV2;
    });
  }

  void setEnabled(bool enabled) {
    _enabled = enabled;
    if (!enabled) _stop();
  }

  @override
  void onLayer2Packet(L2Channel channel, L2OpCode opcode, Uint8List payload) {
    if (channel != L2Channel.massVoice || !_enabled || _disposed) return;
    // Validate the complete packet before changing the session.
    final commands = XiaomiVoiceCommand.parse(payload);
    for (final command in commands) {
      switch (command.type) {
        case 1:
          _end();
          _sessionId = command.data[0];
          _replyMode = supportsAivsLargeModel
              ? XiaomiVoiceReplyMode.streamAfterStop
              : XiaomiVoiceReplyMode.templateAfterStop;
          _recording = true;
          _sequence = 0;
          entity.emit(
            XiaoAiSessionStarted(
              deviceId: entity.id,
              capabilities: {
                'platform': 'xiaomi',
                'sessionId': _sessionId,
                'generation': _generation,
                'replyMode': _replyMode.name,
                'tts': command.data.length == 2 && command.data[1] == 1,
              },
            ),
          );
          _timeout = Timer(const Duration(seconds: 60), _stop);
        case 2:
          if (_recording) {
            // Mi Fitness decodes each command as fixed 80-byte Opus packets.
            for (var offset = 0; offset < command.data.length; offset += 80) {
              entity.emit(
                XiaoAiOpusFrameReceived(
                  deviceId: entity.id,
                  sequence: _sequence++,
                  frame: Uint8List.fromList(
                    command.data.sublist(offset, offset + 80),
                  ),
                ),
              );
            }
          }
        case 3:
          _endRecording();
        case 4:
          _end();
      }
    }
  }

  Future<void> sendTextReply(
    String text, {
    required String recognizedText,
    XiaoAiSessionTarget? target,
    bool useStream = true,
  }) async {
    final recognition = recognizedText.trim();
    if (recognition.isEmpty) throw ArgumentError('Recognition cannot be empty');
    final value = text.trim();
    if (value.isEmpty) {
      throw ArgumentError('Reply must contain at least 1 character');
    }
    if (_sessionId == null || !_enabled || _disposed) {
      throw StateError('No voice session');
    }
    _ensureTarget(target);
    final generation = _generation;
    if (_sendingGeneration == generation) {
      throw StateError('Voice reply is already being sent');
    }
    _sendingGeneration = generation;
    try {
      if (_replyMode == XiaomiVoiceReplyMode.streamAfterStop && useStream) {
        await _sendStreamText(value, recognition, target: target);
      } else {
        await _sendReply(
          value,
          recognition,
          target: target,
          deferStop:
              _replyMode == XiaomiVoiceReplyMode.streamAfterStop ||
              _replyMode == XiaomiVoiceReplyMode.templateBeforeFinish,
        );
      }
    } finally {
      if (_sendingGeneration == generation) _sendingGeneration = null;
    }
  }

  Future<void> _sendInstructions(List<aivs.AivsInstruction> instructions) {
    final session = _sessionId;
    final packet = pb.WearPacket(
      type: pb.WearPacket_Type.AIVS,
      id: 0,
      aivs: aivs.Aivs(
        instructionList: aivs.AivsInstruction_List(list: instructions),
      ),
    );
    final operation = _queueInstructions(packet);
    unawaited(
      operation.then(
        (_) => _log.info(
          '[${entity.id}] AIVS reply queued: '
          'session=$session generation=$_generation '
          'mode=${_replyMode.name} '
          'types=${instructions.map((item) => item.resultType.value).join(',')}',
        ),
        onError: (Object error) {
          _log.warning('[${entity.id}] AIVS reply queue failed', error);
        },
      ),
    );
    return operation;
  }

  Future<void> _queueInstructions(pb.WearPacket packet) {
    final operation = _aivsSendTail.then((_) => component.sendPbPacket(packet));
    _aivsSendTail = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> sendStreamReply(
    Stream<String> textStream, {
    required String recognizedText,
    XiaoAiSessionTarget? target,
  }) async {
    final buffer = StringBuffer();
    await for (final chunk in textStream) {
      buffer.write(chunk);
    }
    final text = buffer.toString().trim();
    if (text.isEmpty) return;
    _ensureTarget(target);
    if (_replyMode != XiaomiVoiceReplyMode.streamAfterStop) {
      await sendTextReply(text, recognizedText: recognizedText, target: target);
      return;
    }
    final session = _sessionId;
    if (session == null || !_enabled || _disposed) {
      throw StateError('No voice session');
    }
    _ensureTarget(target);
    final generation = _generation;
    await _pendingRecognition;
    if (generation != _generation) return;
    if (_recording) await stopCapture(target: target);
    if (generation != _generation) return;
    if (_lastFinal != recognizedText) {
      await _sendRecognition(session, recognizedText, isFinal: true);
      _lastFinal = recognizedText;
    }
    await _sendStreamInstructions(session, text, generation: generation);
    if (generation == _generation) _end();
  }

  Future<void> sendRecognitionPartial(String text) =>
      sendRecognitionResult(text, isFinal: false);

  Future<void> sendRecognitionResult(
    String text, {
    required bool isFinal,
    XiaoAiSessionTarget? target,
  }) {
    final session = _sessionId;
    final generation = _generation;
    if (session == null ||
        !_enabled ||
        _disposed ||
        _sendingGeneration == generation) {
      return Future<void>.value();
    }
    _ensureTarget(target);
    final recognition = text.trim();
    final operation = _pendingRecognition.then((_) async {
      if (generation != _generation ||
          !_enabled ||
          _disposed ||
          recognition == (isFinal ? _lastFinal : _lastPartial)) {
        return;
      }
      if (isFinal && _lastPartial != recognition) {
        await _sendRecognition(session, recognition, isFinal: false);
        if (generation != _generation || !_enabled || _disposed) return;
        _lastPartial = recognition;
      }
      await _sendRecognition(session, recognition, isFinal: isFinal);
      if (generation == _generation) {
        if (isFinal) {
          _lastFinal = recognition;
        } else {
          _lastPartial = recognition;
        }
      }
    });
    _pendingRecognition = operation.then<void>((_) {}, onError: (Object _) {});
    return operation;
  }

  Future<void> _sendRecognition(
    int session,
    String text, {
    required bool isFinal,
  }) => _sendInstructions([
    aivs.AivsInstruction(
      resultType: aivs.ResultType.RECOGNIZE_RESULT,
      sessionId: session,
      recognizeResult: aivs.SpeechRecognizeResult(
        isFinal: isFinal,
        results: aivs.SpeechRecognizeResultItem_List(
          list: [aivs.SpeechRecognizeResultItem(text: text)],
        ),
      ),
    ),
  ]);

  Future<void> _sendReply(
    String value,
    String recognition, {
    XiaoAiSessionTarget? target,
    bool deferStop = false,
  }) async {
    final session = _sessionId;
    if (session == null || !_enabled || _disposed) return;
    _ensureTarget(target);
    final generation = _generation;
    await _pendingRecognition;
    if (generation != _generation || !_enabled || _disposed) return;
    if (_lastPartial != recognition && _lastFinal != recognition) {
      await _sendRecognition(session, recognition, isFinal: false);
      if (generation != _generation || !_enabled || _disposed) return;
      _lastPartial = recognition;
    }
    if (_recording && !deferStop) {
      await _sendInstructions([
        aivs.AivsInstruction(
          resultType: aivs.ResultType.STOP_CAPTURE,
          sessionId: session,
        ),
      ]);
      if (generation != _generation || !_enabled || _disposed) return;
      _endRecording();
    }
    if (_lastFinal != recognition) {
      await _sendRecognition(session, recognition, isFinal: true);
      if (generation == _generation) _lastFinal = recognition;
    }
    if (generation != _generation || !_enabled || _disposed) return;
    await _sendInstructions([
      aivs.AivsInstruction(
        resultType: aivs.ResultType.TEMPLATE_TOAST,
        sessionId: session,
        templateToast: aivs.TemplateToast(text: value),
      ),
    ]);
    if (generation != _generation || !_enabled || _disposed) return;
    await _sendInstructions([
      aivs.AivsInstruction(
        resultType: aivs.ResultType.DIALOG_FINISH,
        sessionId: session,
      ),
    ]);
    if (generation == _generation) _end();
  }

  Future<void> _sendStreamText(
    String text,
    String recognition, {
    XiaoAiSessionTarget? target,
  }) async {
    final session = _sessionId;
    if (session == null || !_enabled || _disposed) {
      throw StateError('No voice session');
    }
    _ensureTarget(target);
    final generation = _generation;
    await _pendingRecognition;
    if (generation != _generation) return;
    if (_recording) await stopCapture(target: target);
    if (generation != _generation) return;
    if (_lastFinal != recognition) {
      await _sendRecognition(session, recognition, isFinal: true);
      _lastFinal = recognition;
    }
    await _sendStreamInstructions(session, text, generation: generation);
    if (generation == _generation) _end();
  }

  Future<void> _sendStreamInstructions(
    int session,
    String text, {
    required int generation,
  }) async {
    await _sendInstructions([
      aivs.AivsInstruction(
        resultType: aivs.ResultType.LLM_TOAST_STREAM,
        sessionId: session,
        llmToastStream: aivs.LLM_ToastStream(markdownText: text),
      ),
    ]);
    if (generation != _generation) return;
    await _sendInstructions([
      aivs.AivsInstruction(
        resultType: aivs.ResultType.LLM_FINISH_STREAM,
        sessionId: session,
      ),
    ]);
  }

  Future<void> stopCapture({
    XiaoAiSessionTarget? target,
    bool force = false,
    bool notifyDevice = true,
  }) async {
    final session = _sessionId;
    if (session == null || !_recording || !_enabled || _disposed) return;
    _ensureTarget(target);
    if (!force && !notifyDevice) {
      // A capable device must keep its capture session open until the final
      // stream reply can send STOP_CAPTURE and the 292/293 pair.
      return;
    }
    if (!force && _replyMode == XiaomiVoiceReplyMode.templateBeforeFinish) {
      _recording = false;
      return;
    }
    final previous = _stopCaptureFuture;
    if (previous != null) return previous;
    final generation = _generation;
    final operation =
        _sendInstructions([
          aivs.AivsInstruction(
            resultType: aivs.ResultType.STOP_CAPTURE,
            sessionId: session,
          ),
        ]).then((_) {
          if (generation == _generation && _enabled && !_disposed) {
            _recording = false;
          }
        });
    _stopCaptureFuture = operation;
    try {
      await operation;
    } finally {
      if (identical(_stopCaptureFuture, operation)) _stopCaptureFuture = null;
    }
  }

  void _stop() {
    final session = _sessionId;
    final wasRecording = _recording;
    _end();
    if (session == null || _disposed) return;
    final generation = _generation;
    unawaited(
      _sendStop(session, generation, wasRecording).catchError((Object error) {
        entity.emit(DeviceError(deviceId: entity.id, error: error.toString()));
      }),
    );
  }

  Future<void> _sendStop(int session, int generation, bool wasRecording) async {
    if (wasRecording) {
      await _sendInstructions([
        aivs.AivsInstruction(
          resultType: aivs.ResultType.STOP_CAPTURE,
          sessionId: session,
        ),
      ]);
      if (generation != _generation || _disposed) return;
    }
    await _sendInstructions([
      aivs.AivsInstruction(
        resultType: aivs.ResultType.DIALOG_FINISH,
        sessionId: session,
      ),
    ]);
  }

  void _endRecording({bool cancelled = false}) {
    if (!_recording) return;
    _recording = false;
    entity.emit(XiaoAiSessionEnded(deviceId: entity.id, cancelled: cancelled));
  }

  void _end() {
    _generation++;
    _timeout?.cancel();
    _timeout = null;
    _endRecording(cancelled: true);
    _sessionId = null;
    _sendingGeneration = null;
    _lastPartial = null;
    _lastFinal = null;
    _pendingRecognition = Future<void>.value();
    _replyMode = XiaomiVoiceReplyMode.templateAfterStop;
  }

  void _ensureTarget(XiaoAiSessionTarget? target) {
    if (target == null) return;
    final current = sessionTarget;
    if (current == null ||
        current.deviceId != target.deviceId ||
        current.sessionId != target.sessionId ||
        current.generation != target.generation) {
      throw StateError('Voice session is no longer active');
    }
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    await _capsSub?.cancel();
    _end();
  }
}
