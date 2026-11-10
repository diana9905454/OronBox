@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;
import 'package:oronbox/src/core/storage/app_data_directory.dart';
import 'package:oronbox/src/features/plugins/storage/plugin_storage.dart';
import 'package:oronbox/src/features/plugins/storage/plugin_storage_web.dart';

void main() {
  test('chunked streams resume atomically and preserve the published file on failure', () async {
    final store = await openAppDataDirectory(
      'test-${DateTime.now().microsecondsSinceEpoch}',
    );
    try {
      await store.write('target', Uint8List.fromList([9]));
      Stream<List<int>> broken() async* {
        yield [1, 2];
        throw StateError('offline');
      }

      await expectLater(
        store.writeStream('target', broken()),
        throwsStateError,
      );
      expect(await store.read('target'), [9]);
      expect((await store.files(includeTemporary: true)).length, 1);
      await expectLater(
        store.writeStream('partial', broken(), append: true),
        throwsStateError,
      );
      await store.writeStream('partial', Stream.value([3, 4]), append: true);
      await store.move('partial', 'target');
      expect(await store.readStream('target').expand((x) => x).toList(), [
        1,
        2,
        3,
        4,
      ]);
      expect((await store.files()).single.bytes, 4);
      await store.write('target', Uint8List.fromList([5]));
      expect(await store.read('target'), [5]);
    } finally {
      for (final file in await store.files(includeTemporary: true)) {
        await store.remove(file.path);
      }
    }
  });
  test(
    'plugin v1 size index migration and all subsequent mutations stay in sync',
    () async {
      final created = web.window.indexedDB.open('oronbox.plugins', 1);
      created.onupgradeneeded = ((web.Event _) {
        final db = created.result as web.IDBDatabase;
        db
            .createObjectStore('files')
            .put(
              Uint8List.fromList([1, 2, 3]).toJS,
              'test\u0001data\u0001before.bin'.toJS,
            );
      }).toJS;
      final opened = Completer<web.IDBDatabase>();
      created.onsuccess = ((web.Event _) => opened.complete(
        created.result as web.IDBDatabase,
      )).toJS;
      (await opened.future).close();
      final store = await createPluginStorage();
      try {
        expect(
          (await collectWebPluginStorageUsage())[PluginStorageArea.data],
          3,
        );
        await store.writeFile(
          'test',
          PluginStoragePath.parse('/data/after.bin'),
          Uint8List(7),
        );
        expect(
          (await collectWebPluginStorageUsage())[PluginStorageArea.data],
          10,
        );
        await store.removeFile(
          'test',
          PluginStoragePath.parse('/data/before.bin'),
        );
        expect(
          (await collectWebPluginStorageUsage())[PluginStorageArea.data],
          7,
        );
        await store.removePlugin('test');
        expect(
          (await collectWebPluginStorageUsage())[PluginStorageArea.data],
          0,
        );
      } finally {
        await store.close();
      }
    },
  );
}
