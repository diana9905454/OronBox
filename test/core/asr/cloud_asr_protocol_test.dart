import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/core/asr/cloud_asr_protocol.dart';
import 'package:oronbox/src/core/asr/wetype_asr.dart';

void main() {
  test('empty AES requests include a full PKCS7 block', () {
    final key = Uint8List.fromList(List.filled(32, 65));
    final encoded = asrAes(key, Uint8List(0));
    expect(
      encoded.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(),
      '98cc2f3f476b40b7ea032f33af023b61',
    );
    expect(asrAes(key, encoded, encrypt: false), isEmpty);
  });
  test('registration encryption matches the independent reference vector', () {
    final encrypted = encodeDoubaoRegistration(
      Uint8List.fromList(List.generate(20, (i) => i)),
      salt: Uint8List.fromList(List.generate(32, (i) => i)),
    );
    expect(
      encrypted.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(),
      '746305100000000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f519ff3577fbeb6a7ec685510f773906cc8a15a8506f892e9fb71724e9d2a713b4ba3bee8d1f2a667c6efa5c9be3cbde21d282c8a0f8f6503301a398a7ddb7529ec4535c9d6ff8810b26694e7cbbe945467cddb0661fd2ba972788ce015b37ad8',
    );
  });
  test('WeType shared-key encoding matches a known secp128r1 point', () {
    expect(
      ascii.decode(
        wetypeSharedKey(
          BigInt.two,
          '040AD632F542942F23AA423B628A304B3B7AA67EE421C4E78851E4B4679BCDC41F',
        ),
      ),
      '624BCC28BF7670B76E6D3B61D2247FEF',
    );
  });
  test('rejects server public points outside the curve', () {
    expect(
      () => wetypeSharedKey(BigInt.two, '04${'0' * 64}'),
      throwsFormatException,
    );
  });
  test('protobuf rejects truncated values and preserves repeated fields', () {
    final bytes = [
      ...protoField(1, 123),
      ...protoField(2, 'abc'),
      ...protoField(2, 'def'),
    ];
    expect(protoFields(bytes).where((field) => field.$1 == 2), hasLength(2));
    expect(() => protoFields([18, 9, 1]), throwsFormatException);
    expect(() => protoFields([128]), throwsFormatException);
  });
  test('bounded snappy handles literals and rejects invalid references', () {
    final content = Uint8List.fromList(utf8.encode('hello' * 100));
    expect(snappyDecode(snappyLiteral(content)), content);
    expect(
      () => snappyDecode(Uint8List.fromList([4, 1, 0])),
      throwsFormatException,
    );
    expect(
      () => snappyDecode(Uint8List.fromList([1, 4, 65, 66])),
      throwsFormatException,
    );
  });
  test('segment hypotheses replace partials and retain committed text', () {
    final transcript = AsrTranscript();
    expect(transcript.update('你', false), '你');
    expect(transcript.update('你好', true), '你好');
    expect(transcript.update('你好', true), isNull);
    expect(transcript.update('世', false), '你好世');
    expect(transcript.update('世界', true), '你好世界');
  });
}
