import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/core/storage/managed_temporary_files.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('oronbox-owned-test-');
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => root.path,
    );
  });
  tearDown(() async {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    await root.delete(recursive: true);
  });
  test('active files and queued paths survive cleanup; released files are reclaimable', () async {
    final path = await ManagedTemporaryFiles.create(
      TemporaryFilePurpose.downloads,
      'app.bin',
      (path) async {
        await File(path).writeAsBytes([1, 2, 3]);
      },
    );
    expect(await ManagedTemporaryFiles.cleanup(minimumAge: Duration.zero), 0);
    await ManagedTemporaryFiles.release(path, delete: false);
    expect(
      await ManagedTemporaryFiles.cleanup(
        minimumAge: Duration.zero,
        protectedPaths: {path},
      ),
      0,
    );
    expect(await File(path).readAsBytes(), [1, 2, 3]);
    expect(await ManagedTemporaryFiles.cleanup(minimumAge: Duration.zero), 1);
    expect(await File(path).exists(), isFalse);
  });
  test(
    'failed creation leaves no payload and never deletes an external file',
    () async {
      await expectLater(
        ManagedTemporaryFiles.create(
          TemporaryFilePurpose.installs,
          'app.bin',
          (_) async => throw StateError('failed'),
        ),
        throwsStateError,
      );
      final external = File('${root.path}/mine');
      await external.writeAsString('keep');
      await ManagedTemporaryFiles.release(external.path);
      expect(await external.readAsString(), 'keep');
      await expectLater(
        ManagedTemporaryFiles.create(
          TemporaryFilePurpose.installs,
          '../escape',
          (_) async {},
        ),
        throwsFormatException,
      );
      expect(
        (await root.list(recursive: true).where((e) => e is File).toList())
            .length,
        1,
      );
    },
  );
}
