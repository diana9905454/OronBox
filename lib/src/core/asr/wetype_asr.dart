import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pointycastle/ecc/curves/secp128r1.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'asr.dart';
import 'asr_socket.dart';
import 'cloud_asr_protocol.dart';

// Wire format reference: xifan2333/vinput-registry, wetype/streaming.
const _host = 'wetype.weixin.qq.com';
const _signingConstant = 'zN7rB3bL4pO8jW1o';
final _bootstrapKey = Uint8List.fromList(
  ascii.encode('D4Y5U3Y2M0C0T7N4P1P7O2N6E1I2Y1U6'),
);
const _dh = 2147483646;
const _register = 0x7FFFFDFD;

class WeTypeAsrEngine implements AsrEngine {
  WeTypeAsrEngine({AsrIdentityStore? identities})
    : identities = identities ?? AsrIdentityStore();
  final AsrIdentityStore identities;
  WeTypeSession? _current;
  @override
  Future<AsrSession> start() async {
    final session = WeTypeSession(identities);
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

class WeTypeSession implements AsrSession {
  WeTypeSession(this.identities);
  final AsrIdentityStore identities;
  final _results = StreamController<AsrResult>.broadcast();
  WebSocketChannel? _channel;
  StreamIterator<dynamic>? _incoming;
  Uint8List? _key;
  String _uin = '0';
  String _device = '';
  int _task = 0;
  int _offset = 0;
  bool _closed = false;
  bool _finished = false;
  final _voice = const Uuid().v4().replaceAll('-', '');
  final _packets = <Uint8List>[];
  int _sequence = 0;
  int _total = 0;
  String _text = '';
  String _polished = '';
  @override
  Stream<AsrResult> get results => _results.stream;

  Future<void> connect() async {
    final channel = await connectAsrSocket(
      Uri.parse('wss://$_host/'),
      protocols: ['wxws_pb'],
    );
    _channel = channel;
    if (_closed) {
      await channel.sink.close();
      throw const AsrFailure('cancelled');
    }
    _incoming = StreamIterator(channel.stream);
    final timestamp = await _rpc('/timestamp');
    final server = protoMap(timestamp.$1)[1];
    if (server is int && server >= 1000000000000 && server <= 10000000000000) {
      _offset = server - DateTime.now().millisecondsSinceEpoch;
    }
    final cached = await identities.read('wetype');
    var reused = false;
    if (cached != null &&
        cached['device'] is String &&
        cached['uin'] is String) {
      _device = cached['device'] as String;
      _uin = cached['uin'] as String;
      await _exchange(false);
      reused = true;
    }
    if (!reused) {
      _uin = '0';
      final body = 'MAC${'0' * 9}Mac16,12${asrRandomLower(12)}';
      _device =
          '$body${md5.convert(utf8.encode('$body$_signingConstant')).toString().toUpperCase()}';
      final exchange = await _exchange(true);
      if (exchange.$2.isEmpty) throw const AsrFailure('registration');
      final request = Uint8List.fromList([
        ...protoField(1, _device),
        ...protoField(2, exchange.$1),
        ...protoField(4, exchange.$2),
      ]);
      final response = await _rpc(
        '/gen_uin_v2',
        body: asrAes(_key!, request),
        command: _register,
        token: exchange.$2,
      );
      _uin = '${protoMap(asrAes(_key!, response.$1, encrypt: false))[2] ?? 0}';
      if (_uin == '0') throw const AsrFailure('registration');
      await identities.write('wetype', {'device': _device, 'uin': _uin});
    }
    await _rpc('/api_v2', body: asrAes(_key!, Uint8List(0)), command: 8074);
  }

  Future<(String, String)> _exchange(bool register) async {
    final curve = ECCurve_secp128r1();
    BigInt scalar;
    do {
      scalar = BigInt.parse(asrRandomHex(16), radix: 16);
    } while (scalar == BigInt.zero || scalar >= curve.n);
    final point = curve.G * scalar;
    final public = point!
        .getEncoded(false)
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join()
        .toUpperCase();
    final request = Uint8List.fromList([
      ...protoField(1, public),
      ...protoField(2, public),
      ...protoField(4, _device),
      ...protoField(7, ''),
      ...protoField(8, 'Mac16,12'),
      ...protoField(9, ''),
      ...protoField(register ? 3 : 5, register ? 1 : int.parse(_uin)),
    ]);
    final response = await _rpc(
      '/oauth_pubkey_v2',
      body: asrAes(_bootstrapKey, request),
      command: _dh,
    );
    final decoded = protoMap(
      asrAes(_bootstrapKey, response.$1, encrypt: false),
    );
    final server = protoText(decoded, 2);
    _key = wetypeSharedKey(scalar, server);
    return (server, protoText(decoded, 4));
  }

  Future<(Uint8List, Map<String, String>)> _rpc(
    String path, {
    Uint8List? body,
    int command = 0,
    String compression = '1',
    String token = '',
  }) async {
    if (_closed) throw const AsrFailure('cancelled');
    body ??= Uint8List(0);
    final special = command == _dh || command == _register;
    final task = special ? command : ++_task;
    final timestamp = '${DateTime.now().millisecondsSinceEpoch + _offset}';
    final trace = asrRandomLower(16);
    final digest = md5.convert(body).toString().toUpperCase();
    final signature = [
      '5',
      '2.2.3(657)',
      '2',
      if (command == _dh) ...[
        timestamp,
        digest,
        trace,
        '$command',
      ] else if (command == _register) ...[
        timestamp,
        digest,
        token,
        trace,
        '$command',
      ] else ...[
        '$command',
        '0',
        timestamp,
        digest,
        _uin,
        trace,
        '$task',
      ],
    ].join();
    final headers = <String, String>{
      'Kb-Uin': _uin,
      if (token.isNotEmpty) 'Kb-GenUinToken': token,
      if (special) 'Kb-DeviceCodeRestrictionV2': '1',
      if (command != _dh) ...{
        if (_key != null)
          'Kb-SharedKeySuffix': ascii.decode(_key!.sublist(_key!.length - 4)),
        'Kb-CmdId': '$command',
        'Kb-SubCmdId': '0',
      },
      'Kb-OsType': '5',
      'Kb-Version': '2.2.3(657)',
      'Kb-SystemVersion': '27.0.0',
      'Kb-PackageType': '3',
      'Use_DebugNet': '0',
      'Kb-TimeStamp': timestamp,
      'Kb-BodyMd5': digest,
      'Kb-TraceId': trace,
      'Kb-TaskId': '$task',
      'Kb-Scene': '2',
      'Kb-Sign': sha256
          .convert(utf8.encode('$signature$_signingConstant'))
          .toString()
          .toUpperCase(),
      'Content-Length': '${body.length}',
      'Kb-CompressionType': compression,
      'Content-Type': 'application/octet-stream',
      'HOST': _host,
    };
    final http = [
      ...protoField(1, 'POST'),
      ...protoField(3, path),
      ...protoField(4, ''),
      for (final header in headers.entries)
        ...protoField(5, [
          ...protoField(1, header.key),
          ...protoField(2, header.value),
        ]),
      ...protoField(6, body),
    ];
    _channel!.sink.add(
      Uint8List.fromList([
        ...protoField(1, 0),
        ...protoField(2, 0),
        ...protoField(3, task),
        ...protoField(5, http),
      ]),
    );
    if (!await _incoming!.moveNext().timeout(const Duration(seconds: 10))) {
      throw const AsrFailure('connection');
    }
    final raw = _incoming!.current;
    if (raw is! List<int>) throw const AsrFailure('protocol');
    final envelope = protoMap(raw)[4];
    if (envelope is! List<int>) throw const AsrFailure('protocol');
    final fields = protoFields(envelope);
    final response = {for (final item in fields) item.$1: item.$2};
    if (response[2] != 200) throw const AsrFailure('service_rejected');
    final resultHeaders = <String, String>{};
    for (final item in fields) {
      if (item.$1 == 5 || item.$2 is! List<int>) continue;
      try {
        final pair = protoMap(item.$2 as List<int>);
        if (pair[1] is List<int> && pair[2] is List<int>) {
          resultHeaders[protoText(pair, 1)] = protoText(pair, 2);
        }
      } on FormatException {
        /* Non-header response field. */
      }
    }
    return (
      Uint8List.fromList((response[5] as List<int>?) ?? const []),
      resultHeaders,
    );
  }

  @override
  Future<void> addAudio(Float32List pcm, {Uint8List? opus}) async {
    if (_closed || _finished) return;
    // Reuse the validated 20 ms Opus packet; no lossy decode/re-encode cycle.
    if (pcm.length != 320 || opus == null || opus.isEmpty) {
      throw const AsrFailure('opus_format');
    }
    _packets.add(Uint8List.fromList(opus));
    if (_packets.length == 6) await _sendVoice(false);
  }

  Future<void> _sendVoice(bool end, {bool poll = false}) async {
    final builder = BytesBuilder();
    var number = 0;
    Uint8List? framed;
    if (!poll) {
      number = ++_sequence;
      if (number == 1) builder.add([...ascii.encode('#!OPUS_RAW_V1'), 2, 1, 0]);
      for (final packet in _packets) {
        final size = ByteData(2)..setUint16(0, packet.length, Endian.little);
        builder.add(size.buffer.asUint8List());
        builder.add(packet);
      }
      _packets.clear();
      framed = builder.takeBytes();
      _total += framed.length;
    }
    final request = [
      ...protoField(2, _voice),
      ...protoField(5, 5),
      ...protoField(7, number),
      ...protoField(22, 1),
      ...protoField(23, 1),
      ...protoField(24, 1),
      if (framed != null) ...protoField(4, framed),
      if (end) ...protoField(6, 1),
      if (_total != 0) ...protoField(11, _total),
    ];
    final response = await _rpc(
      '/api_v2',
      body: asrAes(_key!, snappyLiteral(protoField(1, request))),
      command: 4548,
      compression: '2',
    );
    var plain = asrAes(_key!, response.$1, encrypt: false);
    if ((response.$2['Kb-CompressionType'] ?? response.$2['CompressionType']) ==
        '2') {
      plain = snappyDecode(plain);
    }
    var fields = protoMap(plain);
    if (fields[1] is List<int>) fields = protoMap(fields[1] as List<int>);
    final text = protoText(fields, 4);
    if (text.isNotEmpty && text != _text) {
      _text = text;
      _results.add(AsrResult(text));
    }
    if (end) _polished = protoText(fields, 14);
  }

  @override
  Future<void> finishInput() async {
    if (_closed || _finished) return;
    _finished = true;
    try {
      await _sendVoice(true);
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (_polished.isEmpty &&
          _text.isNotEmpty &&
          DateTime.now().isBefore(deadline) &&
          !_closed) {
        await Future<void>.delayed(const Duration(milliseconds: 30));
        await _sendVoice(true, poll: true);
      }
      if (!_closed) {
        _results.add(
          AsrResult(_polished.isNotEmpty ? _polished : _text, isFinal: true),
        );
      }
    } finally {
      await cancel();
    }
  }

  @override
  Future<void> cancel() async {
    if (_closed) return;
    _closed = true;
    _packets.clear();
    try {
      await _channel?.sink.close().timeout(const Duration(seconds: 1));
    } catch (_) {}
    await _incoming?.cancel();
    await _results.close();
    _key = null;
  }
}

Uint8List wetypeSharedKey(BigInt scalar, String public) {
  if (!RegExp(r'^04[0-9a-fA-F]{64}$').hasMatch(public)) {
    throw const FormatException('Invalid server point');
  }
  final x = BigInt.parse(public.substring(2, 34), radix: 16);
  final y = BigInt.parse(public.substring(34), radix: 16);
  final p = BigInt.parse('FFFFFFFDFFFFFFFFFFFFFFFFFFFFFFFF', radix: 16);
  final b = BigInt.parse('E87579C11079F43DD824993C2CEE5ED3', radix: 16);
  if (x >= p ||
      y >= p ||
      (y * y - x * x * x + BigInt.from(3) * x - b) % p != BigInt.zero) {
    throw const FormatException('Server point is not on curve');
  }
  final curve = ECCurve_secp128r1();
  final shared = curve.curve.createPoint(x, y) * scalar;
  if (shared == null || shared.isInfinity) {
    throw const FormatException('Invalid shared point');
  }
  return Uint8List.fromList(
    ascii.encode(
      shared.x!
          .toBigInteger()!
          .toRadixString(16)
          .padLeft(32, '0')
          .toUpperCase(),
    ),
  );
}
