import 'dart:typed_data';
import 'dart:io';

import 'package:oronbox/src/core/storage/app_data_directory_io.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/device/xiaomi/systems/health_system.dart';
import 'package:oronbox/src/features/devices/health/health_debug_snapshot_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late IoAppDataDirectory storage;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('oronbox-snapshots-test-');
    storage = IoAppDataDirectory(root);
  });

  tearDown(() async {
    await root.delete(recursive: true);
  });

  test('adds the first snapshot to an empty store', () async {
    final store = HealthDebugSnapshotStore(storage: storage);

    await store.add(
      deviceId: 'device-a',
      deviceCode: 'o66',
      files: [
        XiaomiActivityRawFile(
          id: 'activity-file-a',
          data: Uint8List.fromList(const [1, 2, 3]),
        ),
      ],
    );

    final snapshots = await store.read();
    expect(snapshots, hasLength(1));
    expect(snapshots.single.deviceId, 'device-a');
    expect(snapshots.single.deviceCode, 'o66');
    expect(snapshots.single.files.single.id, 'activity-file-a');
  });

  test('round-trips an exported snapshot through the archive', () async {
    final capturedAt = DateTime(2026, 9, 20, 1, 41, 21);
    final snapshot = XiaomiHealthRawSnapshot(
      id: 'snapshot-a',
      deviceId: 'device-a',
      deviceCode: 'o66nfc',
      capturedAt: capturedAt,
      files: [
        XiaomiActivityRawFile(
          id: '8101af6a1005d8',
          data: Uint8List.fromList(const [1, 2, 3, 4]),
        ),
        XiaomiActivityRawFile(
          id: '8101af6a1006d9',
          data: Uint8List.fromList(const [5, 6]),
        ),
      ],
    );

    final decoded = XiaomiHealthRawSnapshot.decodeArchive(
      snapshot.encodeArchive(),
    );

    expect(decoded.id, 'snapshot-a');
    expect(decoded.deviceId, 'device-a');
    expect(decoded.deviceCode, 'o66nfc');
    expect(decoded.capturedAt, capturedAt);
    expect(decoded.files, hasLength(2));
    expect(decoded.files[0].id, '8101af6a1005d8');
    expect(decoded.files[0].data, [1, 2, 3, 4]);
    expect(decoded.files[1].id, '8101af6a1006d9');
    expect(decoded.files[1].data, [5, 6]);
  });

  test('imports an archive into the store', () async {
    final store = HealthDebugSnapshotStore(storage: storage);
    final archive = XiaomiHealthRawSnapshot(
      id: 'snapshot-b',
      deviceId: 'device-b',
      deviceCode: 'o66nfc',
      capturedAt: DateTime(2026, 9, 20, 2),
      files: [
        XiaomiActivityRawFile(
          id: '8101af6a1005d8',
          data: Uint8List.fromList(const [9, 8, 7]),
        ),
      ],
    ).encodeArchive();

    final imported = await store.import(archive);
    expect(imported.id, 'snapshot-b');

    final snapshots = await store.read();
    expect(snapshots, hasLength(1));
    expect(snapshots.single.id, 'snapshot-b');
    expect(snapshots.single.files.single.data, [9, 8, 7]);
  });

  test('rejects an archive without activity files', () {
    expect(
      () => XiaomiHealthRawSnapshot.decodeArchive(Uint8List.fromList(const [])),
      throwsA(isA<Exception>()),
    );
  });
  test('concurrent store instances do not overwrite captures', () async {
    await Future.wait(
      List.generate(
        8,
        (i) => HealthDebugSnapshotStore(storage: IoAppDataDirectory(root)).add(
          deviceId: 'device-$i',
          files: [
            XiaomiActivityRawFile(id: 'sample', data: Uint8List.fromList([i])),
          ],
        ),
      ),
    );
    expect(
      await HealthDebugSnapshotStore(storage: storage).list(),
      hasLength(8),
    );
  });

  test(
    'listing never loads raw files but loading detects corruption',
    () async {
      final store = HealthDebugSnapshotStore(storage: storage);
      await store.add(
        deviceId: 'device',
        files: [
          XiaomiActivityRawFile(id: 'sample', data: Uint8List.fromList([5])),
        ],
      );
      final summary = (await store.list()).single;
      await storage.write(summary.files.single.path, Uint8List.fromList([9]));
      expect((await store.list()).single.totalBytes, 1);
      await expectLater(
        store.load(summary.id),
        throwsA(isA<FormatException>()),
      );
    },
  );

  test('a failed operation does not poison the serialization queue', () async {
    await expectLater(
      storage.exclusive(() async => throw StateError('fail')),
      throwsStateError,
    );
    expect(await storage.exclusive(() async => 42), 42);
  });
}
