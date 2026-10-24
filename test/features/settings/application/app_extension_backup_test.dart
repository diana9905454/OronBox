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
  test('round-trip restores configuration and data without touching code or grants', () async {
    final backup = await store.export();
    expect(jsonEncode(backup), isNot(contains('test-grant')));
    expect(jsonEncode(backup), isNot(contains('export {}')));
    await plugins.writeConfig(id, {'color': 'blue'});
    await plugins.writeFile(
      id,
      PluginStoragePath.parse('/data/new.bin'),
      Uint8List(3),
    );
    zeppos.values = {'theme': 'light'};
    await store.restore(backup);
    expect((await plugins.loadInstalled()).single.config, {'color': 'red'});
    expect(
      await plugins.readFile(id, PluginStoragePath.parse('/data/file.bin')),
      [1, 2],
    );
    expect(
      await plugins.stat(id, PluginStoragePath.parse('/data/new.bin')),
      isNull,
    );
    expect(await plugins.readPermissionGrants(id), {'test-grant'});
    expect(zeppos.values, {'theme': 'dark'});
  });
  test(
    'missing matching version is rejected before any data changes',
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
  test('permission metadata and package paths cannot enter a data archive', () {
    for (final path in [
      '/plugin/main.js',
      '/data/.oronbox/permissions.json',
      '/data/../escape',
    ]) {
      expect(
        () => validateExtensionBackup({
          'plugins': {
            id: {
              'version': '1.0.0',
              'config': {},
              'files': {path: 'AA=='},
            },
          },
        }),
        throwsFormatException,
      );
    }
  });
}
