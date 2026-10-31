import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/features/resources/services/resource_payload_analyzer.dart';

void main() {
  final analyzer = ResourcePayloadAnalyzer();

  test(
    'RPK publishing versions follow manifest-watch without changing bytes',
    () {
      final archive = Archive();
      for (final entry in {
        'manifest.json': {
          'package': 'org.demo.app',
          'versionName': '1.0',
          'versionCode': 1,
        },
        'manifest-watch.json': {'versionName': '2.0', 'versionCode': 2.0},
      }.entries) {
        final bytes = utf8.encode(jsonEncode(entry.value));
        archive.addFile(ArchiveFile(entry.key, bytes.length, bytes));
      }
      final bytes = Uint8List.fromList(ZipEncoder().encode(archive));
      final result = analyzer.analyze(fileName: 'demo.rpk', bytes: bytes);
      expect(result?.version, '2.0');
      expect(result?.versionCode, 2);
      expect(result?.payload, same(bytes));
    },
  );

  test('watchface version code preserves zero and uses the actual header', () {
    final bytes = Uint8List(0x40)..setAll(0, [0x5a, 0xa5, 0x34, 0x12]);
    bytes.setAll(0x28, ascii.encode('123456789'));
    expect(
      analyzer.analyze(fileName: 'face.bin', bytes: bytes)?.versionCode,
      0,
    );
    bytes.setAll(4, [3, 2, 1]);
    final result = analyzer.analyze(fileName: 'face.bin', bytes: bytes);
    expect(result?.versionCode, 66051);
    expect(result?.payload, same(bytes));
  });
}
