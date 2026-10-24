import 'dart:async';
import 'dart:typed_data';

import 'package:oronbox/src/device/core/event_bus.dart';
import 'package:oronbox/src/device/xiaomi/protocol/generated/wear.pb.dart'
    as pb;
import 'package:oronbox/src/device/xiaomi/protocol/generated/wear_aivs.pb.dart'
    as aivs;
import 'package:oronbox/src/device/xiaomi/protocol/packet/l2_packet.dart';
import 'package:oronbox/src/device/xiaomi/systems/xiaomi_system.dart';

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
          _recording = true;
          _sequence = 0;
          entity.emit(
            XiaoAiSessionStarted(
              deviceId: entity.id,
              capabilities: {
                'platform': 'xiaomi',
                'sessionId': _sessionId,
                'generation': _generation,
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
  }) async {
    final recognition = recognizedText.trim();
    if (recognition.isEmpty) throw ArgumentError('Recognition cannot be empty');
    final value = text.trim();
    if (value.isEmpty || value.length > 300) {
      throw ArgumentError('Reply must contain 1 to 300 characters');
    }
    if (_sessionId == null || !_enabled || _disposed) {
      throw StateError('No voice session');
    }
    final generation = _generation;
    if (_sendingGeneration == generation) {
      throw StateError('Voice reply is already being sent');
    }
    _sendingGeneration = generation;
    try {
      await _sendReply(value, recognition);
    } finally {
      if (_sendingGeneration == generation) _sendingGeneration = null;
    }
  }

  Future<void> _sendInstructions(List<aivs.AivsInstruction> instructions) =>
      component.sendPbPacket(
        pb.WearPacket(
          type: pb.WearPacket_Type.AIVS,
          id: 0,
          aivs: aivs.Aivs(
            instructionList: aivs.AivsInstruction_List(list: instructions),
          ),
        ),
        waitForAck: true,
      );

  Future<void> sendRecognitionPartial(String text) =>
      sendRecognitionResult(text, isFinal: false);

  Future<void> sendRecognitionResult(String text, {required bool isFinal}) {
    final session = _sessionId;
    final generation = _generation;
    if (session == null ||
        !_enabled ||
        _disposed ||
        _sendingGeneration == generation) {
      return Future<void>.value();
    }
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

  Future<void> _sendReply(String value, String recognition) async {
    final session = _sessionId;
    if (session == null || !_enabled || _disposed) return;
    final generation = _generation;
    await _pendingRecognition;
    if (generation != _generation || !_enabled || _disposed) return;
    if (_lastPartial != recognition && _lastFinal != recognition) {
      await _sendRecognition(session, recognition, isFinal: false);
      if (generation != _generation || !_enabled || _disposed) return;
      _lastPartial = recognition;
    }
    if (_recording) {
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
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    _end();
  }
}
