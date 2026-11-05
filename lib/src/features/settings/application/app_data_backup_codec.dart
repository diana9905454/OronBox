part of 'app_data_backup.dart';

Uint8List _encodeBackup(
  (
    Map<String, Object?>,
    Map<String, Object?>,
    Map<String, Object?>,
    Map<String, Uint8List>,
  )
  data, {
  String? password,
}) {
  _validateSettings(data.$1);
  validatePrivateBackup(data.$3);
  final files = <String, Uint8List>{
    if (data.$1.isNotEmpty)
      'settings.json': Uint8List.fromList(utf8.encode(jsonEncode(data.$1))),
    if (data.$2.isNotEmpty)
      'extensions.json': Uint8List.fromList(utf8.encode(jsonEncode(data.$2))),
    if (data.$3.isNotEmpty)
      'private.json': Uint8List.fromList(utf8.encode(jsonEncode(data.$3))),
    ...data.$4,
  };
  final manifest = {
    'format': 'oronbox-backup',
    'version': 1,
    'createdAt': DateTime.now().toUtc().toIso8601String(),
    'files': {
      for (final entry in files.entries)
        entry.key: {
          'bytes': entry.value.length,
          'sha256': sha256.convert(entry.value).toString(),
        },
    },
  };
  final archive = Archive();
  for (final entry in files.entries) {
    archive.addFile(ArchiveFile(entry.key, entry.value.length, entry.value));
  }
  final manifestBytes = utf8.encode(jsonEncode(manifest));
  if (files.values.fold(manifestBytes.length, (sum, f) => sum + f.length) >
      512 * 1024 * 1024) {
    throw const FormatException('Backup expansion limit exceeded');
  }
  archive.addFile(
    ArchiveFile('manifest.json', manifestBytes.length, manifestBytes),
  );
  final effectivePassword = (password != null && password.trim().isNotEmpty)
      ? password.trim()
      : null;
  return Uint8List.fromList(
    ZipEncoder(password: effectivePassword).encode(archive),
  );
}

AppDataBackup _decodeBackup(Uint8List bytes, {String? password}) {
  final files = readDataArchive(
    bytes,
    maxFiles: 8192,
    maxBytes: 512 * 1024 * 1024,
    password: password,
  );
  final manifestRaw = files['manifest.json'];
  if (manifestRaw == null) {
    throw const FormatException('Unsupported backup format');
  }
  final manifest = jsonDecode(utf8.decode(manifestRaw)) as Map;
  if (manifest['format'] != 'oronbox-backup' || manifest['version'] != 1) {
    throw const FormatException('Unsupported backup format');
  }

  final manifestFiles = (manifest['files'] as Map).cast<String, Map>();
  if (manifestFiles.length != files.length - 1) {
    throw const FormatException('Unsupported backup format');
  }

  for (final entry in manifestFiles.entries) {
    final name = entry.key;
    final descriptor = entry.value;
    final file = files[name];
    if (file == null ||
        file.length != descriptor['bytes'] ||
        sha256.convert(file).toString() != descriptor['sha256']) {
      throw const FormatException('Backup file is damaged');
    }
  }

  final settings = files.containsKey('settings.json')
      ? (jsonDecode(utf8.decode(files['settings.json']!)) as Map)
            .cast<String, Object?>()
      : <String, Object?>{};
  _validateSettings(settings);

  final extensions = files.containsKey('extensions.json')
      ? (jsonDecode(utf8.decode(files['extensions.json']!)) as Map)
            .cast<String, Object?>()
      : <String, Object?>{};
  if (extensions.isNotEmpty) {
    validateExtensionBackup(extensions);
  }

  final privateData = files.containsKey('private.json')
      ? decodePrivateBackup(files['private.json']!)
      : <String, Object?>{};
  if (privateData.isNotEmpty) {
    validatePrivateBackup(privateData);
  }

  final activityFiles = <String, Uint8List>{};
  final extensionFiles = <String, Uint8List>{};
  for (final entry in files.entries) {
    final name = entry.key;
    if (name.startsWith('health/raw/') || name.startsWith('raw/')) {
      activityFiles[name] = entry.value;
    } else if (name.startsWith('plugins/')) {
      extensionFiles[name] = entry.value;
    }
  }

  return AppDataBackup(
    settings: settings,
    activityFiles: activityFiles,
    extensions: extensions,
    extensionFiles: extensionFiles,
    privateData: privateData,
  );
}

void _validateSettings(Map<String, Object?> settings) {
  for (final entry in settings.entries) {
    final value = entry.value;
    final valid =
        (backupPreferenceKeys.contains(entry.key) ||
            backupAccountPreferenceKeys.contains(entry.key)) &&
        (value == null ||
            switch (entry.key) {
              'app_theme_mode' ||
              'app_desktop_accent_color_source' ||
              'app_locale' ||
              'github_cdn' ||
              'community_source' ||
              'wide_navigation_rail_position' ||
              'auto_backup_interval_unit' => value is String,
              'desktop.exit_behavior' =>
                value is int && value >= 0 && value <= 2,
              'app_custom_seed_color' =>
                value is int && value >= 0 && value <= 0xffffffff,
              'zeppos.mirror.frame_interval_ms' =>
                value is int && value >= 1 && value <= 1000,
              'auto_backup_interval_value' => value is int && value >= 1,
              'auto_backup_retention' => value is int && value >= 0,
              'mi_account.username' ||
              'mi_account.password' ||
              'huami_account.username' ||
              'huami_account.password' => value is String,
              _ => value is bool,
            });
    if (!valid) throw const FormatException('Invalid backup settings');
  }
}

Uint8List _encodeBackupEntry(
  (
    Map<String, Object?>,
    Map<String, Object?>,
    Map<String, Object?>,
    Map<String, Uint8List>,
    String?,
  )
  input,
) =>
    _encodeBackup((input.$1, input.$2, input.$3, input.$4), password: input.$5);

AppDataBackup _decodeBackupEntry((Uint8List, String?) input) =>
    _decodeBackup(input.$1, password: input.$2);
