import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/core/storage/app_data_directory_io.dart';
import 'package:oronbox/src/device/xiaomi/systems/health_system.dart';
import 'package:oronbox/src/features/devices/health/health_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late IoAppDataDirectory storage;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('oronbox-activity-test-');
    storage = IoAppDataDirectory(root);
    HealthStore.activityStorageForTesting = storage;
    HealthStore.clearCache();
  });

  tearDown(() async {
    HealthStore.activityStorageForTesting = null;
    HealthStore.clearCache();
    await root.delete(recursive: true);
  });

  test('saves activity files in flat readable paths', () async {
    final file = XiaomiActivityRawFile(
      id: '8101af6a1005d8',
      data: Uint8List.fromList(const [1, 2, 3, 4]),
    );

    await HealthStore().saveActivityFiles(
      deviceId: 'AA:BB:CC:DD:EE:FF',
      deviceCode: 'o66',
      files: [file],
    );

    final batches = await HealthStore.listActivityBatches();
    expect(batches, hasLength(1));
    expect(batches.single.deviceId, 'AA:BB:CC:DD:EE:FF');
    expect(batches.single.deviceCode, 'o66');
    expect(batches.single.files.single.id, '8101af6a1005d8');
    // Verify flat path pattern: {deviceId}/{fileId}.bin
    expect(batches.single.files.single.path, 'aabbccddeeff/8101af6a1005d8.bin');
  });

  test('exports and imports activity batch archive', () async {
    final file = XiaomiActivityRawFile(
      id: '8101af6a1006d9',
      data: Uint8List.fromList(const [5, 6, 7]),
    );

    await HealthStore().saveActivityFiles(
      deviceId: 'device-export-test',
      deviceCode: 'o66nfc',
      files: [file],
    );

    final batches = await HealthStore.listActivityBatches();
    final batchId = batches.single.id;
    final exportedBytes = await HealthStore.exportActivityBatch(batchId);
    expect(exportedBytes, isNotEmpty);

    final imported = await HealthStore.importActivityBatch(exportedBytes);
    expect(imported.files, isNotEmpty);
    expect(imported.deviceId, 'device-export-test');
    expect(imported.deviceCode, 'o66nfc');

    final allBytes = await HealthStore.exportAllActivityBatches();
    await HealthStore.clearActivityFiles();
    final importedAll = await HealthStore.importActivityBatch(allBytes);
    expect(importedAll.deviceId, 'device-export-test');
    expect(importedAll.files, isNotEmpty);
  });

  test('smoothly migrates legacy nested sha256 paths to flat paths', () async {
    const legacyPath = 'legacy_sha256_dir/sub_sha256_dir/digest123.bin';
    final legacyData = Uint8List.fromList(const [10, 20, 30]);
    final digest =
        '6951bbd9c2178b2a9d01714687307afda1eb6161ff8c398486a76683e7b42925';

    // Pre-populate legacy index and file
    await storage.write(legacyPath, legacyData);
    final legacyIndex = jsonEncode({
      'version': 1,
      'snapshots': [
        {
          'id': 'batch-legacy',
          'deviceId': 'device-legacy',
          'capturedAt': DateTime.now().toIso8601String(),
          'files': [
            {
              'id': '8101af6a1007da',
              'path': legacyPath,
              'bytes': legacyData.length,
              'sha256': digest,
            },
          ],
        },
      ],
    });
    await storage.write(
      'index.json',
      Uint8List.fromList(utf8.encode(legacyIndex)),
    );

    // Load batches should automatically trigger flat path migration
    final batches = await HealthStore.listActivityBatches();
    expect(batches, hasLength(1));
    expect(
      batches.single.files.single.path,
      'device-legacy/8101af6a1007da.bin',
    );

    // Confirm new file exists and old file is removed
    final migratedBytes = await storage.read(
      'device-legacy/8101af6a1007da.bin',
    );
    expect(migratedBytes, legacyData);
    final oldBytes = await storage.read(legacyPath);
    expect(oldBytes, isNull);
  });

  test('failed operation does not poison the serialization queue', () async {
    await expectLater(
      storage.exclusive(() async => throw StateError('fail')),
      throwsStateError,
    );
    expect(await storage.exclusive(() async => 42), 42);
  });

  test('overview finds a workout older than its recent window', () async {
    final bytes = await File(
      '${Directory.current.path}/test/device/xiaomi/fixtures/8101af6a1005d8.bin',
    ).readAsBytes();
    await HealthStore().saveActivityFiles(
      deviceId: 'old-workout',
      files: [
        XiaomiActivityRawFile(
          id: '8101af6a1005d8',
          data: Uint8List.fromList(bytes),
        ),
      ],
    );

    final overview = await HealthStore().overview('old-workout');
    expect(overview.workouts, isNotEmpty);

    final historical = await HealthStore().query(
      'old-workout',
      start: DateTime(2026, 9, 19),
      end: DateTime(2026, 9, 21),
      kinds: const ['workouts'],
    );
    expect(historical.workouts, isNotEmpty);
  });
}
