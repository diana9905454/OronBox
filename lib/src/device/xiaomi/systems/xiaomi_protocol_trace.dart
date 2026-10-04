import 'dart:typed_data';

import 'package:oronbox/src/device/xiaomi/protocol/generated/wear.pb.dart' as pb;

typedef XiaomiProtocolTraceSink = void Function(Map<String, Object?> trace);

/// Structured tracing for the Xiaomi transport and the operations running on
/// top of it.
///
/// Transport decoding lives here instead of in individual feature systems.
/// A feature may add operation stages, but it must not teach the transport
/// tracer how to decode that feature's protobuf payload.
class XiaomiProtocolTracer {
  XiaomiProtocolTracer(this._sink);

  final XiaomiProtocolTraceSink _sink;
  int _nextOperationId = 0;

  void emit(Map<String, Object?> trace) {
    _sink(Map.unmodifiable({...trace}));
  }

  XiaomiTraceOperation beginOperation(
    String name, {
    Map<String, Object?> data = const {},
  }) {
    final operation = XiaomiTraceOperation._(
      tracer: this,
      id: '${++_nextOperationId}',
      name: name,
    );
    operation.step('started', data: data);
    return operation;
  }

  void emitWearPacket({
    required String direction,
    required Uint8List bytes,
    bool? encrypted,
  }) {
    final trace = <String, Object?>{
      'layer': 'wear_packet',
      'direction': direction,
      'hex': _hex(bytes),
      if (encrypted != null) 'encrypted': encrypted,
    };
    try {
      final packet = pb.WearPacket.fromBuffer(bytes);
      trace.addAll({
        'type': packet.type.name,
        'id': packet.id,
        'payload': packet.whichPayload().name,
      });
    } catch (error) {
      trace['decode'] = 'failed';
      trace['error'] = error.toString();
    }
    emit(trace);
  }

  static String _hex(Uint8List bytes) =>
      bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(' ');
}

class XiaomiTraceOperation {
  XiaomiTraceOperation._({
    required this._tracer,
    required this.id,
    required this.name,
  });

  final XiaomiProtocolTracer _tracer;
  final String id;
  final String name;
  bool _finished = false;
  String? _lastStage;

  void step(String stage, {Map<String, Object?> data = const {}}) {
    if (_finished) return;
    _lastStage = stage;
    _tracer.emit({
      'layer': 'operation',
      'operation': name,
      'operationId': id,
      'stage': stage,
      ...data,
    });
  }

  void complete({Map<String, Object?> data = const {}}) {
    if (_finished) return;
    _finished = true;
    _tracer.emit({
      'layer': 'operation',
      'operation': name,
      'operationId': id,
      'stage': 'completed',
      ...data,
    });
  }

  void fail(Object error, {Map<String, Object?> data = const {}}) {
    if (_finished) return;
    _finished = true;
    _tracer.emit({
      'layer': 'operation',
      'operation': name,
      'operationId': id,
      'stage': 'failed',
      if (_lastStage != null) 'lastStage': _lastStage,
      'error': error.toString(),
      ...data,
    });
  }
}
