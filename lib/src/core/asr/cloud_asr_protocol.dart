import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/export.dart';
import 'package:oronbox/src/core/logging/logging_service.dart';

final _random = Random.secure();
Uint8List asrRandomBytes(int length) =>
    Uint8List.fromList(List.generate(length, (_) => _random.nextInt(256)));
String asrRandomLower(int length) => List.generate(
  length,
  (_) => String.fromCharCode(97 + _random.nextInt(26)),
).join();
String asrRandomHex(int length) =>
    asrRandomBytes(length)
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();

Uint8List protoField(int number, Object value) {
  if (value is String) value = utf8.encode(value);
  if (value is List<int>) {
    return Uint8List.fromList([
      ...protoVarint((number << 3) | 2),
      ...protoVarint(value.length),
      ...value,
    ]);
  }
  if (value is int) {
    return Uint8List.fromList([
      ...protoVarint(number << 3),
      ...protoVarint(value),
    ]);
  }
  throw const FormatException('Invalid protobuf field');
}

List<int> protoVarint(int value) {
  if (value < 0) throw const FormatException('Negative protobuf integer');
  final result = <int>[];
  while (value > 127) {
    result.add((value & 127) | 128);
    value >>= 7;
  }
  return result..add(value);
}

List<(int, Object)> protoFields(List<int> bytes) {
  if (bytes.length > 8 * 1024 * 1024) {
    throw const FormatException('ASR message too large');
  }
  var offset = 0;
  int readInt() {
    var result = 0;
    for (var shift = 0; shift < 63; shift += 7) {
      if (offset >= bytes.length) {
        throw const FormatException('Truncated protobuf');
      }
      final value = bytes[offset++];
      result |= (value & 127) << shift;
      if (value < 128) return result;
    }
    throw const FormatException('Invalid protobuf integer');
  }

  final result = <(int, Object)>[];
  while (offset < bytes.length) {
    final tag = readInt();
    if (tag >> 3 == 0) {
      throw const FormatException('Invalid protobuf field number');
    }
    final wire = tag & 7;
    if (wire == 0) {
      result.add((tag >> 3, readInt()));
      continue;
    }
    final size = switch (wire) {
      1 => 8,
      2 => readInt(),
      5 => 4,
      _ => -1,
    };
    if (size < 0 || offset + size > bytes.length) {
      throw const FormatException('Invalid protobuf length');
    }
    result.add((
      tag >> 3,
      Uint8List.fromList(bytes.sublist(offset, offset + size)),
    ));
    offset += size;
  }
  return result;
}

Map<int, Object> protoMap(List<int> bytes) => {
  for (final field in protoFields(bytes)) field.$1: field.$2,
};
String protoText(Map<int, Object> fields, int number) =>
    fields[number] == null ? '' : utf8.decode(fields[number] as List<int>);

Uint8List asrAes(Uint8List key, Uint8List data, {bool encrypt = true}) {
  final cipher = ECBBlockCipher(AESEngine())..init(encrypt, KeyParameter(key));
  Uint8List input;
  if (encrypt) {
    final padding = 16 - data.length % 16;
    input = Uint8List(data.length + padding)..setAll(0, data);
    input.fillRange(data.length, input.length, padding);
  } else {
    if (data.isEmpty || data.length % 16 != 0) {
      throw const FormatException('Invalid AES block length');
    }
    input = data;
  }
  final result = Uint8List(input.length);
  for (var offset = 0; offset < input.length; offset += 16) {
    cipher.processBlock(input, offset, result, offset);
  }
  if (encrypt) return result;
  final padding = PKCS7Padding().padCount(result);
  return Uint8List.sublistView(result, 0, result.length - padding);
}

Uint8List encodeDoubaoRegistration(Uint8List content, {Uint8List? salt}) {
  salt ??= asrRandomBytes(32);
  final constant = _hex(
    '4dd4c2e6b83162090e52b3c7a6733ba41cb2462b829ab58a196b39db57177524f49baf7f08e8d68d26a72e37c1a95a2f1f05a51892aef2949732b62a38aadd58',
  );
  final digest = sha512.convert([
    ...sha512.convert(salt).bytes,
    ...constant,
  ]).bytes;
  final cipher = PaddedBlockCipher('AES/CBC/PKCS7')
    ..init(
      true,
      PaddedBlockCipherParameters<ParametersWithIV<KeyParameter>, Null>(
        ParametersWithIV(
          KeyParameter(Uint8List.fromList(digest.sublist(0, 16))),
          Uint8List.fromList(digest.sublist(16, 32)),
        ),
        null,
      ),
    );
  final payload = Uint8List.fromList([
    ...sha512.convert(content).bytes,
    ...content,
  ]);
  return Uint8List.fromList([
    0x74,
    0x63,
    5,
    0x10,
    0,
    0,
    ...salt,
    ...cipher.process(payload),
  ]);
}

Uint8List gzipAsr(List<int> input) =>
    Uint8List.fromList(GZipEncoder().encode(input));

Uint8List snappyLiteral(List<int> input) {
  final result = BytesBuilder()..add(protoVarint(input.length));
  for (var offset = 0; offset < input.length; offset += 60) {
    final end = min(input.length, offset + 60);
    result.addByte((end - offset - 1) << 2);
    result.add(input.sublist(offset, end));
  }
  return result.takeBytes();
}

Uint8List snappyDecode(Uint8List bytes) {
  var offset = 0;
  int take() {
    if (offset >= bytes.length) throw const FormatException('Truncated snappy');
    return bytes[offset++];
  }

  var size = 0;
  for (var shift = 0; ; shift += 7) {
    if (shift >= 35) throw const FormatException('Invalid snappy size');
    final value = take();
    size |= (value & 127) << shift;
    if (value < 128) break;
  }
  if (size > 8 * 1024 * 1024) {
    throw const FormatException('Snappy message too large');
  }
  final output = Uint8List(size);
  var used = 0;
  int little(int count) {
    var value = 0;
    for (var i = 0; i < count; i++) {
      value |= take() << (i * 8);
    }
    return value;
  }

  while (offset < bytes.length) {
    final tag = take();
    final mode = tag & 3;
    if (mode == 0) {
      var length = tag >> 2;
      if (length >= 60) length = little(length - 59);
      length++;
      if (used + length > size || offset + length > bytes.length) {
        throw const FormatException('Invalid snappy literal');
      }
      output.setRange(used, used + length, bytes, offset);
      used += length;
      offset += length;
    } else {
      final distance = mode == 1
          ? ((tag >> 5) << 8) | take()
          : little(mode == 2 ? 2 : 4);
      final length = mode == 1 ? ((tag >> 2) & 7) + 4 : (tag >> 2) + 1;
      if (distance <= 0 || distance > used || used + length > size) {
        throw const FormatException('Invalid snappy reference');
      }
      for (var i = 0; i < length; i++) {
        output[used] = output[used - distance];
        used++;
      }
    }
  }
  if (used != size) throw const FormatException('Snappy length mismatch');
  return output;
}

Uint8List _hex(String value) => Uint8List.fromList([
  for (var i = 0; i < value.length; i += 2)
    int.parse(value.substring(i, i + 2), radix: 16),
]);

class AsrIdentityStore {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: false),
    mOptions: MacOsOptions(usesDataProtectionKeychain: false),
  );
  static final _memory = <String, Map<String, dynamic>>{};
  static bool _secureAvailable = true;
  Future<Map<String, dynamic>?> read(String provider) async {
    final cached = _memory[provider];
    if (cached != null) return Map.of(cached);
    if (!_secureAvailable) return null;
    try {
      final raw = await _storage.read(key: 'oronbox.asr.$provider');
      if (raw == null) return null;
      final value = (jsonDecode(raw) as Map).cast<String, dynamic>();
      _memory[provider] = value;
      return Map.of(value);
    } on FormatException {
      return null;
    } catch (_) {
      _secureAvailable = false;
      getLogger('ASR')
          .warning('Anonymous recognition identity will remain in memory');
      return null;
    }
  }

  Future<void> reset(String provider) async {
    if (provider != 'wetype' && provider != 'doubao') {
      throw ArgumentError.value(provider);
    }
    await _storage.delete(key: 'oronbox.asr.$provider');
    if (await _storage.read(key: 'oronbox.asr.$provider') != null) {
      throw StateError('ASR identity was not removed');
    }
    _memory.remove(provider);
    _secureAvailable = true;
  }

  Future<void> write(String provider, Map<String, dynamic> value) async {
    _memory[provider] = Map.of(value);
    if (!_secureAvailable) return;
    try {
      await _storage.write(
        key: 'oronbox.asr.$provider',
        value: jsonEncode(value),
      );
    } catch (_) {
      _secureAvailable = false;
      getLogger('ASR')
          .warning('Anonymous recognition identity will remain in memory');
    }
  }
}

class AsrTranscript {
  String committed = '';
  String current = '';
  bool finished = false;
  String text = '';
  String? update(String value, bool segmentFinal) {
    if ((value.isEmpty && !segmentFinal) ||
        (segmentFinal && finished && current == value)) {
      return null;
    }
    text = committed + value;
    current = value;
    finished = segmentFinal;
    if (segmentFinal) committed = text;
    return text;
  }
}
