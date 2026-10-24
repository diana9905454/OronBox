part of 'app_data_backup.dart';

XiaomiHealthData _decodeHealth(String raw) => XiaomiHealthData.decode(raw);
Uint8List _encodeBackup(
  (
    Map<String, Object?>,
    Map<String, String>,
    Map<String, Object?>,
    Map<String, Object?>,
  )
  data,
) {
  _validateSettings(data.$1);
  validatePrivateBackup(data.$4);
  final files = {
    'settings.json': Uint8List.fromList(utf8.encode(jsonEncode(data.$1))),
    'health.json': Uint8List.fromList(utf8.encode(jsonEncode(data.$2))),
    if (data.$3.isNotEmpty)
      'extensions.json': Uint8List.fromList(utf8.encode(jsonEncode(data.$3))),
    if (data.$4.isNotEmpty)
      'private.json': Uint8List.fromList(utf8.encode(jsonEncode(data.$4))),
  };
  final manifest = {
    'format': 'oronbox-backup',
    'version': data.$4.isNotEmpty
        ? 3
        : data.$3.isEmpty
        ? 1
        : 2,
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
  final bytes = utf8.encode(jsonEncode(manifest));
  if (files.values.fold(bytes.length, (sum, file) => sum + file.length) >
      128 * 1024 * 1024) {
    throw const FormatException('Backup expansion limit exceeded');
  }
  archive.addFile(ArchiveFile('manifest.json', bytes.length, bytes));
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

AppDataBackup _decodeBackup(Uint8List bytes) {
  final files = readDataArchive(bytes, maxFiles: 5);
  final manifest = jsonDecode(utf8.decode(files['manifest.json']!)) as Map;
  if (manifest['format'] != 'oronbox-backup' ||
      ![1, 2, 3].contains(manifest['version']) ||
      (manifest['version'] != 3 &&
          files.length != (manifest['version'] == 1 ? 3 : 4)) ||
      files.keys.any(
        (name) => !const [
          'manifest.json',
          'settings.json',
          'health.json',
          'extensions.json',
          'private.json',
        ].contains(name),
      ) ||
      (manifest['version'] == 3 && !files.containsKey('private.json')) ||
      ((manifest['files'] as Map).length != files.length - 1)) {
    throw const FormatException('Unsupported backup format');
  }
  for (final name in [
    'settings.json',
    'health.json',
    if (files.containsKey('extensions.json')) 'extensions.json',
    if (files.containsKey('private.json')) 'private.json',
  ]) {
    final file = files[name];
    final descriptor = (manifest['files'] as Map)[name] as Map;
    if (file == null ||
        file.length != descriptor['bytes'] ||
        sha256.convert(file).toString() != descriptor['sha256']) {
      throw const FormatException('Backup file is damaged');
    }
  }
  final settings = (jsonDecode(utf8.decode(files['settings.json']!)) as Map)
      .cast<String, Object?>();
  _validateSettings(settings);
  final health = (jsonDecode(utf8.decode(files['health.json']!)) as Map)
      .cast<String, String>();
  if (health.keys.any((key) => !RegExp(r'^[a-f0-9]{40}$').hasMatch(key))) {
    throw const FormatException('Invalid backup device identity');
  }
  final extensions = files['extensions.json'] == null
      ? <String, Object?>{}
      : (jsonDecode(utf8.decode(files['extensions.json']!)) as Map)
            .cast<String, Object?>();
  validateExtensionBackup(extensions);
  final privateData = files['private.json'] == null
      ? <String, Object?>{}
      : decodePrivateBackup(files['private.json']!);
  validatePrivateBackup(privateData);
  return AppDataBackup(
    settings,
    {
      for (final entry in health.entries)
        entry.key: _decodeBackupHealth(entry.value),
    },
    extensions: extensions,
    privateData: privateData,
  );
}

void _validateSettings(Map<String, Object?> settings) {
  for (final entry in settings.entries) {
    final value = entry.value;
    final valid =
        backupPreferenceKeys.contains(entry.key) &&
        (value == null ||
            switch (entry.key) {
              'app_theme_mode' ||
              'app_desktop_accent_color_source' ||
              'app_locale' ||
              'github_cdn' ||
              'community_source' ||
              'wide_navigation_rail_position' => value is String,
              'desktop.exit_behavior' =>
                value is int && value >= 0 && value <= 2,
              'app_custom_seed_color' =>
                value is int && value >= 0 && value <= 0xffffffff,
              _ => value is bool,
            });
    if (!valid) throw const FormatException('Invalid backup settings');
  }
}

XiaomiHealthData _decodeBackupHealth(String raw) {
  final json = (jsonDecode(raw) as Map).cast<String, Object?>();
  final data = XiaomiHealthData.fromJson(json);
  if (json['schema'] != 2 || !_sameJson(json, data.toJson())) {
    throw const FormatException('Invalid backup health records');
  }
  return data;
}

bool _sameJson(Object? left, Object? right) {
  if (left is Map && right is Map) {
    return left.length == right.length &&
        left.keys.every(
          (key) => right.containsKey(key) && _sameJson(left[key], right[key]),
        );
  }
  if (left is List && right is List) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (!_sameJson(left[index], right[index])) return false;
    }
    return true;
  }
  return left == right;
}
