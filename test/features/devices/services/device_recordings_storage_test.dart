import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/features/devices/services/device_recordings_storage_io.dart';

void main() {
  group('device_recordings_storage', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'oronbox-recordings-test-',
      );
      userRecordingsDirectoryOverride = Directory(
        '${tempDir.path}${Platform.pathSeparator}Documents${Platform.pathSeparator}OronBox${Platform.pathSeparator}Recordings',
      );
    });

    tearDown(() async {
      userRecordingsDirectoryOverride = null;
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'saves recording to Documents/OronBox/Recordings and lists it',
      () async {
        final sampleData = Uint8List.fromList([1, 2, 3, 4, 5]);
        final savedPath = await saveDeviceRecording(
          fileName: 'test_meeting.opus',
          bytes: sampleData,
        );

        expect(savedPath, isNotNull);
        expect(savedPath!.contains('Documents'), isTrue);
        expect(savedPath.contains('OronBox'), isTrue);
        expect(savedPath.contains('Recordings'), isTrue);
        expect(File(savedPath).existsSync(), isTrue);
        expect(await File(savedPath).readAsBytes(), equals(sampleData));

        final list = await listSavedDeviceRecordings();
        expect(list.contains('test_meeting.opus'), isTrue);

        final isSaved = await isDeviceRecordingSaved('test_meeting.opus');
        expect(isSaved, isTrue);

        final notSaved = await isDeviceRecordingSaved('non_existent.opus');
        expect(notSaved, isFalse);
      },
    );
  });
}
