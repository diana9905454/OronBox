import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/core/asr/asr.dart';
import 'package:oronbox/src/core/asr/asr_model_store.dart';
import 'package:oronbox/src/core/asr/local_asr.dart';
import 'package:oronbox/src/core/storage/app_data_directory_io.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('oronbox-model-lifecycle-');
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
  test('opening and removing an occupied model fail immediately without waiting for its owner', () async {
    final directory = IoAppDataDirectory(root);
    final model = AsrModelStore(storage: directory);
    await directory.exclusive(() async {
      await expectLater(
        openLocalAsr(model).timeout(const Duration(seconds: 1)),
        throwsA(isA<AsrFailure>().having((e) => e.code, 'code', 'busy')),
      );
      await expectLater(model.remove(), throwsA(isA<AsrFailure>()));
      expect(await directory.tryExclusive(() async {}), isFalse);
    });
    expect(await directory.tryExclusive(() async {}), isTrue);
  });
  test('cleanup preserves installed and active versions and reclaims only stale current staging', () async {
    final base = '${root.path}/ai/models/${AsrModelStore.id}';
    final old = IoAppDataDirectory(Directory('$base/${'a' * 40}'));
    final active = IoAppDataDirectory(Directory('$base/${'b' * 40}'));
    final current = IoAppDataDirectory(
      Directory('$base/${AsrModelStore.revision}'),
    );
    await old.write('old.onnx', Uint8List(2));
    await active.write('active.onnx', Uint8List(2));
    await active.write('.usage.$pid.test', Uint8List(0));
    await current.write('manifest.json', Uint8List(1));
    await current.write('.staging/expired.part', Uint8List(2));
    await current.write('.staging/recent.part', Uint8List(2));
    await File('${current.root.path}/.staging/expired.part')
        .setLastModified(DateTime.now().subtract(const Duration(days: 8)));
    await AsrModelStore.cleanupUnused();
    expect(await old.read('old.onnx'), isNull);
    expect(await active.read('active.onnx'), isNotNull);
    expect(await current.read('manifest.json'), isNotNull);
    expect(await current.read('.staging/expired.part'), isNull);
    expect(await current.read('.staging/recent.part'), isNotNull);
  });
}
