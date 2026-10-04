import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/device/core/watchface_install_policy.dart';
import 'package:oronbox/src/features/resources/services/resource_payload_analyzer.dart';

void main() {
  Uint8List watchfaceBytes(String id) {
    final bytes = Uint8List(0x34);
    bytes.setRange(0, 4, const [0x5a, 0xa5, 0x34, 0x12]);
    bytes.setRange(0x28, 0x28 + id.length, id.codeUnits);
    return bytes;
  }

  test('extracts and restricts watchface IDs with the 1209 prefix', () {
    final bytes = watchfaceBytes('120912345678');

    expect(extractVelaWatchfaceId(bytes), '120912345678');
    expect(restrictedWatchfaceIdFor(payload: bytes), '120912345678');
    expect(
      restrictedWatchfaceIdFor(payload: bytes, identifier: '999900000000'),
      '120912345678',
    );
  });

  test('does not restrict an unrelated ID', () {
    final bytes = watchfaceBytes('999912345678');

    expect(isRestrictedWatchfaceId('999912345678'), isFalse);
    expect(restrictedWatchfaceIdFor(payload: bytes), isNull);
  });

  test('resource analyzer exposes the embedded watchface ID', () {
    final analysis = ResourcePayloadAnalyzer().analyze(
      fileName: 'face.bin',
      bytes: watchfaceBytes('120912345678'),
    );

    expect(analysis?.type, LocalDeviceInstallType.watchface);
    expect(analysis?.identifier, '120912345678');
  });

  test('reports restricted watchface message without exposing the ID', () {
    final error = WatchfaceInstallBlockedException('120912345678');

    expect(
      error.message,
      contains('OronBox 无法安装疑似来自官方表盘商城的表盘'),
    );
    expect(error.message, isNot(contains('1209')));
    expect(error.message, isNot(contains('禁止')));
  });
}
