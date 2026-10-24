import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:oronbox/src/core/network/app_http_transport.dart';

import 'asr.dart';
import 'asr_socket.dart';
import 'cloud_asr_protocol.dart';

// Wire format reference: xifan2333/vinput-registry, doubaoime/streaming.
const _appKey = 'OrnqKvSSrs';

class DoubaoAsrEngine implements AsrEngine {
  DoubaoAsrEngine({AsrIdentityStore? identities})
    : identities = identities ?? AsrIdentityStore();
  final AsrIdentityStore identities;
  DoubaoSession? _current;
  @override
  Future<AsrSession> start() async {
    final session = DoubaoSession(identities);
    _current = session;
    try {
      await session.connect();
      return session;
    } catch (_) {
      await session.cancel();
      rethrow;
    }
  }

  @override
  Future<void> dispose() async {
    await _current?.cancel();
  }
}

class DoubaoSession implements AsrSession {
  DoubaoSession(this.identities);
  final AsrIdentityStore identities;
  final _results = StreamController<AsrResult>.broadcast();
  final _waiters = <String, Completer<void>>{};
  final _transcript = AsrTranscript();
  final _cancel = CancelToken();
  final _finished = Completer<void>();
  final _task = const Uuid().v4();
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  bool _closed = false;
  bool _inputEnded = false;
  int _sequence = 0;
  @override
  Stream<AsrResult> get results => _results.stream;

  Future<Map<String, dynamic>> _identity() async {
    var identity = await identities.read('doubao');
    if (_closed) throw const AsrFailure('cancelled');
    if (identity?['device_id'] != null && identity?['install_id'] != null) {
      return identity!;
    }
    identity ??= {
      'openudid': asrRandomHex(10),
      'clientudid': const Uuid().v4(),
      'cdid': const Uuid().v4(),
      'first_install_time': DateTime.now().millisecondsSinceEpoch,
    };
    await identities.write('doubao', identity);
    final request = const Uuid().v4();
    final body = doubaoRegistrationBody(identity, request);
    final content = encodeDoubaoRegistration(
      gzipAsr(utf8.encode(jsonEncode(body))),
    );
    final dio = createAppHttpTransport(
      options: BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
      ),
    );
    try {
      final response = await dio.post<Object?>(
        'https://log.snssdk.com/service/2/device_register/',
        queryParameters: {'req_id': request, 'tt_data': 'a'},
        data: content,
        cancelToken: _cancel,
        options: Options(contentType: 'application/octet-stream;tt-data=a'),
      );
      final data = response.data is String
          ? jsonDecode(response.data as String)
          : response.data;
      if (data is! Map) throw const AsrFailure('registration');
      final device = '${data['device_id_str'] ?? data['device_id'] ?? ''}';
      final install = '${data['install_id_str'] ?? data['install_id'] ?? ''}';
      if (device.isEmpty ||
          device == '0' ||
          install.isEmpty ||
          install == '0') {
        throw const AsrFailure('registration');
      }
      identity.addAll({'device_id': device, 'install_id': install});
      if (_closed) throw const AsrFailure('cancelled');
      await identities.write('doubao', identity);
      return identity;
    } on DioException {
      throw const AsrFailure('registration');
    } finally {
      dio.close();
    }
  }

  Future<void> connect() async {
    // Listen to completion errors from early transport failure, before finishInput.
    unawaited(_finished.future.catchError((Object _) {}));
    final identity = await _identity();
    final channel = await connectAsrSocket(
      Uri.https('frontier-audio-ime-ws.doubao.com', '/ocean/api/v1/ws', {
        'device_id': identity['device_id'] as String,
        'iid': identity['install_id'] as String,
        'aid': '401734',
      }).replace(scheme: 'wss'),
      headers: {
        'proto-version': 'v2',
        'sdk-version': '2',
        'x-custom-keepalive': 'true',
      },
    );
    _channel = channel;
    if (_closed) {
      await channel.sink.close();
      throw const AsrFailure('cancelled');
    }
    _subscription = channel.stream.listen(
      _receive,
      onError: (Object _) => _fail(const AsrFailure('connection')),
      onDone: () {
        if (!_closed && !_finished.isCompleted) {
          _fail(const AsrFailure('connection'));
        }
      },
    );
    await _expect('TaskStarted', () => _send('StartTask'));
    await _expect(
      'SessionStarted',
      () => _send(
        'StartSession',
        payload: {
          'audio_info': {'sample_rate': 16000, 'channel': 1, 'format': 'pcm'},
          'extra': {
            'enable_punctuation': true,
            'enable_asr_twopass': true,
            'enable_asr_threepass': true,
            'end_smooth_window_ms': 800,
            'did': identity['device_id'],
            'app_name': 'oime',
            'app_version': '1.5.1',
          },
        },
      ),
    );
  }

  Future<void> _expect(String event, void Function() send) async {
    final waiter = Completer<void>();
    _waiters[event] = waiter;
    send();
    try {
      await waiter.future.timeout(const Duration(seconds: 10));
    } on TimeoutException {
      throw const AsrFailure('timeout');
    } finally {
      _waiters.remove(event);
    }
  }

  void _send(
    String event, {
    Map<String, Object?>? payload,
    Uint8List? audio,
    int sequence = 0,
  }) {
    if (_closed) throw const AsrFailure('cancelled');
    _channel!.sink.add(
      Uint8List.fromList([
        if (event != 'TaskRequest') ...protoField(2, _appKey),
        ...protoField(3, 'ASR'),
        ...protoField(5, event),
        if (payload != null) ...protoField(6, jsonEncode(payload)),
        if (audio != null) ...protoField(7, audio),
        ...protoField(8, _task),
        if (sequence != 0) ...protoField(9, sequence),
      ]),
    );
  }

  void _receive(dynamic message) {
    if (_closed) return;
    try {
      if (message is! List<int>) throw const AsrFailure('protocol');
      final fields = protoMap(message);
      final task = protoText(fields, 1);
      if (task.isNotEmpty && task != _task) return;
      final event = protoText(fields, 4);
      if (event == 'Ping') {
        _send('Pong');
        return;
      }
      if (event == 'SessionFailed' || event == 'TaskFailed') {
        throw const AsrFailure('service_rejected');
      }
      final waiter = _waiters[event];
      if (waiter != null && !waiter.isCompleted) waiter.complete();
      final payload = protoText(fields, 7);
      if (payload.isNotEmpty) {
        final body = jsonDecode(payload) as Map;
        final results = body['results'];
        if (results is List && results.isNotEmpty && results.first is Map) {
          final result = results.first as Map;
          if (result['text'] is String) {
            final text = _transcript.update(
              result['text'] as String,
              result['is_vad_finished'] == true,
            );
            if (text != null) _results.add(AsrResult(text));
          }
        }
      }
      if (event == 'SessionFinished' || event == 'TaskFinished') {
        if (!_inputEnded) throw const AsrFailure('service_ended');
        if (!_finished.isCompleted) {
          _results.add(AsrResult(_transcript.text, isFinal: true));
          _finished.complete();
          if (event != 'TaskFinished') _send('FinishTask');
        }
      }
    } catch (error) {
      _fail(error is AsrFailure ? error : const AsrFailure('protocol'));
    }
  }

  void _fail(AsrFailure error) {
    if (_closed) return;
    for (final waiter in _waiters.values) {
      if (!waiter.isCompleted) waiter.completeError(error);
    }
    if (!_finished.isCompleted) _finished.completeError(error);
    _results.addError(error);
  }

  @override
  Future<void> addAudio(Float32List pcm, {Uint8List? opus}) async {
    if (_closed || _inputEnded) return;
    for (var offset = 0; offset < pcm.length; offset += 160) {
      final count = (pcm.length - offset).clamp(0, 160);
      final bytes = ByteData(count * 2);
      for (var i = 0; i < count; i++) {
        bytes.setInt16(
          i * 2,
          (pcm[offset + i].clamp(-1.0, 1.0) * 32767).round(),
          Endian.little,
        );
      }
      _send(
        'TaskRequest',
        audio: bytes.buffer.asUint8List(),
        sequence: ++_sequence,
        payload: {
          'extra': <String, Object?>{},
          'timestamp_ms': DateTime.now().millisecondsSinceEpoch,
        },
      );
    }
  }

  @override
  Future<void> finishInput() async {
    if (_closed || _inputEnded) return;
    _inputEnded = true;
    try {
      _send('FinishSession');
      await _finished.future.timeout(const Duration(seconds: 10));
    } on TimeoutException {
      throw const AsrFailure('timeout');
    } finally {
      await cancel();
    }
  }

  @override
  Future<void> cancel() async {
    if (_closed) return;
    _closed = true;
    _cancel.cancel();
    for (final waiter in _waiters.values) {
      if (!waiter.isCompleted) {
        waiter.completeError(const AsrFailure('cancelled'));
      }
    }
    await _subscription?.cancel();
    try {
      await _channel?.sink.close().timeout(const Duration(seconds: 1));
    } catch (_) {}
    await _results.close();
  }
}

Map<String, Object?> doubaoRegistrationBody(
  Map<String, dynamic> identity,
  String request,
) => {
  'magic_tag': 'ss_app_log',
  '_gen_time': DateTime.now().millisecondsSinceEpoch,
  'header': {
    'aid': 401734,
    'app_name': 'oime',
    'channel': 'official',
    'package': 'com.bytedance.android.doubaoime',
    'app_version': '1.5.1',
    'app_version_minor': '6',
    'version_code': 100501006,
    'update_version_code': 100501006,
    'manifest_version_code': 100501006,
    'not_request_sender': 1,
    'release_build': '',
    'custom': <String, Object?>{},
    'device_platform': 'android',
    'os': 'Android',
    'os_version': '14',
    'os_api': 34,
    'device_model': 'OronBox voice experiment',
    'device_brand': 'generic',
    'device_manufacturer': 'generic',
    'cpu_abi': 'arm64-v8a',
    'language': 'zh',
    'timezone': 8,
    'tz_name': 'Asia/Shanghai',
    'tz_offset': 28800,
    'access': 'wifi',
    'openudid': identity['openudid'],
    'clientudid': identity['clientudid'],
    'cdid': identity['cdid'],
    'git_hash': 'b416399',
    'sdk_version_code': 4030263,
    'sdk_target_version': 30,
    'sdk_version': '4.3.2-rc.13',
    'sdk_flavor': 'cnInner',
    'guest_mode': 0,
    'req_id': request,
    'apk_first_install_time': identity['first_install_time'],
    'is_system_app': 0,
  },
};
