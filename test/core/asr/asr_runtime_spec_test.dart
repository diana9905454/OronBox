import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/core/asr/asr.dart';
import 'package:oronbox/src/core/asr/asr_runtime_io.dart';
import 'package:oronbox/src/core/asr/asr_runtime_spec.dart';

void main() {
  test(
    'runtime pins match the resolved Dart bindings and pub archive hashes',
    () {
      final lock = File('pubspec.lock').readAsStringSync();
      String section(String name) => RegExp(
        '^  $name:\n((?:    .*\n)+)',
        multiLine: true,
      ).firstMatch(lock)!.group(1)!;
      expect(
        section('sherpa_onnx'),
        contains('version: "${AsrRuntimeSpec.version}"'),
      );
      for (final spec in androidAsrRuntimes) {
        expect(
          section(spec.package),
          contains('version: "${AsrRuntimeSpec.version}"'),
        );
        expect(section(spec.package), contains(spec.sha256));
      }
    },
  );
  test('rejects an unpinned archive before extraction', () {
    expect(
      () => extractAsrRuntimeArchive(Uint8List.fromList([1, 2, 3])),
      throwsA(isA<AsrFailure>()),
    );
  });
}
