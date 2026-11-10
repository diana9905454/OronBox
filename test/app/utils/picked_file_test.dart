import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/app/utils/picked_file.dart';

void main() {
  test('bounded reads reject oversized memory and file inputs', () async {
    await expectLater(
      PickedFileData(
        name: 'audio.wav',
        bytes: Uint8List(9),
      ).readAsBytes(maxBytes: 8),
      throwsA(isA<PickedFileTooLarge>()),
    );
    final directory = await Directory.systemTemp.createTemp(
      'oronbox-picked-test-',
    );
    try {
      final file = File('${directory.path}/input');
      await file.writeAsBytes(List.filled(100000, 1));
      final input = PickedFileData(name: 'input', path: file.path);
      await expectLater(
        input.readAsBytes(maxBytes: 100),
        throwsA(isA<PickedFileTooLarge>()),
      );
      expect((await input.readAsBytes(maxBytes: 100000))!.length, 100000);
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
