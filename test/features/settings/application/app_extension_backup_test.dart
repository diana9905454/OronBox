import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/device/zeppos/app_side/zeppos_app_side_storage.dart';
import 'package:oronbox/src/features/plugins/domain/plugin_package.dart';
import 'package:oronbox/src/features/plugins/storage/plugin_storage.dart';
import 'package:oronbox/src/features/plugins/storage/plugin_storage_io.dart';
import 'package:oronbox/src/features/settings/application/app_extension_backup.dart';

class _Zepp extends Fake implements ZeppOsAppSideStorage {
  Map<String, String> values = {'theme': 'dark'};
  @override
  Future<List<int>> listAppIds() async => [123];
  @override
  Future<Map<String, String>> readSettings(int appId) async => Map.of(values);
  @override
  Future<void> writeSettings(int appId, Map<String, String> value) async {
    values = Map.of(value);
  }
}

void main() {
  late Directory root;
  late PluginStorage plugins;
  late _Zepp zeppos;
  late AppExtensionBackupStore store;
  const id = 'org.example.plugin';

  setUp(() async {
    root = await Directory.systemTemp.createTemp('oronbox-extension-test-');
    plugins = await createIoPluginStorage(
      installedRoot: Directory('${root.path}/plugins'),
      cacheRoot: Directory('${root.path}/cache'),
      temporaryRoot: Directory('${root.path}/temp'),
    );
    final archive = Archive()
      ..addFile(
        ArchiveFile.string(
          'manifest.json',
          jsonEncode({
            'id': id,
            'name': 'Test',
            'version': '1.0.0',
            'author': 'test',
            'description': 'test',
            'api_level': 1,
            'runtime': 'js',
            'entry': 'main.js',
            'permissions': [],
          }),
        ),
      )
      ..addFile(ArchiveFile.string('main.js', 'export {}'));
    await plugins.install(
      const PluginPackageReader().read(
        Uint8List.fromList(ZipEncoder().encode(archive)),
      ),
      config: {'color': 'red'},
    );
    await plugins.writePermissionGrants(id, {'test-grant'});
    await plugins.writeFile(
      id,
      PluginStoragePath.parse('/data/file.bin'),
      Uint8List.fromList([1, 2]),
    );
    zeppos = _Zepp();
    store = AppExtensionBackupStore(plugins: plugins, zeppos: zeppos);
  });

  tearDown(() async {
    await plugins.close();
    await root.delete(recursive: true);
  });

  test(
    'payload export and restore installs uninstalled plugin and restores data',
    () async {
      final payload = await store.exportPayload();
      expect(
        payload.files.containsKey('plugins/$id/package/manifest.json'),
        isTrue,
      );
      expect(payload.files.containsKey('plugins/$id/package/main.js'), isTrue);
      expect(payload.files.containsKey('plugins/$id/data/file.bin'), isTrue);
      expect((payload.metadata['plugins'] as Map)[id], {
        'version': '1.0.0',
        'config': {'color': 'red'},
        'permissions': ['test-grant'],
      });

      final newRoot = await Directory.systemTemp.createTemp(
        'oronbox-new-ext-test-',
      );
      final newPlugins = await createIoPluginStorage(
        installedRoot: Directory('${newRoot.path}/plugins'),
        cacheRoot: Directory('${newRoot.path}/cache'),
        temporaryRoot: Directory('${newRoot.path}/temp'),
      );
      final newZeppos = _Zepp();
      final newStore = AppExtensionBackupStore(
        plugins: newPlugins,
        zeppos: newZeppos,
      );
      try {
        expect(await newPlugins.loadInstalled(), isEmpty);
        await newStore.restore(payload.metadata, files: payload.files);
        final installed = await newPlugins.loadInstalled();
        expect(installed.length, 1);
        expect(installed.single.manifest.id, id);
        expect(installed.single.config, {'color': 'red'});
        expect(await newPlugins.readPermissionGrants(id), {'test-grant'});
        expect(
          await newPlugins.readFile(
            id,
            PluginStoragePath.parse('/data/file.bin'),
          ),
          [1, 2],
        );
        expect(newZeppos.values, {'theme': 'dark'});
      } finally {
        await newPlugins.close();
        await newRoot.delete(recursive: true);
      }
    },
  );

  test(
    'missing matching version is rejected when package files are absent',
    () async {
      final backup = await store.export();
      ((backup['plugins'] as Map)[id] as Map)['version'] = '9.9.9';
      await expectLater(
        store.restore(backup),
        throwsA(isA<ExtensionBackupTargetMissing>()),
      );
      expect(
        await plugins.readFile(id, PluginStoragePath.parse('/data/file.bin')),
        [1, 2],
      );
    },
  );

  test('restores an explicitly empty permission set', () async {
    final payload = await store.exportPayload();
    final metadata = (jsonDecode(jsonEncode(payload.metadata)) as Map)
        .cast<String, Object?>();
    ((metadata['plugins'] as Map)[id] as Map)['permissions'] = <String>[];

    await store.restore(metadata, files: payload.files);

    expect(await plugins.readPermissionGrants(id), isEmpty);
  });

  test('invalid metadata structure is rejected', () {
    expect(
      () => validateExtensionBackup({
        'plugins': {
          'INVALID ID!': {'version': '1.0.0', 'config': {}},
        },
      }),
      throwsFormatException,
    );
    expect(
      () => validateExtensionBackup({
        'plugins': {
          id: {'version': 123, 'config': {}},
        },
      }),
      throwsFormatException,
    );
  });
}
