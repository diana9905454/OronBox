import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider_windows/path_provider_windows.dart';

const _channel = MethodChannel('oronbox/device_recordings');
const _subDirectoryName = 'Recordings';

@visibleForTesting
Directory? userRecordingsDirectoryOverride;

Future<Directory> _userRecordingsDirectory() async {
  if (userRecordingsDirectoryOverride != null) {
    final dir = userRecordingsDirectoryOverride!;
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }
  if (Platform.isWindows) {
    try {
      final Future<String?> lookup = PathProviderWindows().getPath(
        '{FDD39AD0-238F-46AF-ADB4-6C85480369C7}', // FOLDERID_Documents
      );
      final path = await lookup;
      if (path != null && path.isNotEmpty) {
        final dir = Directory(
          '$path${Platform.pathSeparator}OronBox${Platform.pathSeparator}$_subDirectoryName',
        );
        if (!await dir.exists()) await dir.create(recursive: true);
        return dir;
      }
    } catch (_) {}
    final profile = Platform.environment['USERPROFILE'];
    final base = (profile != null && profile.trim().isNotEmpty)
        ? '$profile${Platform.pathSeparator}Documents'
        : '.';
    final dir = Directory(
      '$base${Platform.pathSeparator}OronBox${Platform.pathSeparator}$_subDirectoryName',
    );
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  final environment = Platform.environment;
  if (Platform.isLinux) {
    final configured = await _linuxDocumentsDirectory(environment);
    if (configured != null) {
      final dir = Directory(
        '$configured${Platform.pathSeparator}OronBox${Platform.pathSeparator}$_subDirectoryName',
      );
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir;
    }
  }

  final home = environment['HOME'];
  final base = (home != null && home.trim().isNotEmpty)
      ? '$home${Platform.pathSeparator}Documents'
      : '.';
  final dir = Directory(
    '$base${Platform.pathSeparator}OronBox${Platform.pathSeparator}$_subDirectoryName',
  );
  if (!await dir.exists()) await dir.create(recursive: true);
  return dir;
}

Future<String?> _linuxDocumentsDirectory(
  Map<String, String> environment,
) async {
  final home = environment['HOME'];
  if (home == null || home.trim().isEmpty) return null;
  final configHome = environment['XDG_CONFIG_HOME'];
  final configPath = configHome == null || configHome.trim().isEmpty
      ? '$home${Platform.pathSeparator}.config${Platform.pathSeparator}user-dirs.dirs'
      : '$configHome${Platform.pathSeparator}user-dirs.dirs';
  final config = File(configPath);
  if (!await config.exists()) return null;
  for (final line in await config.readAsLines()) {
    final match = RegExp(r'^\s*XDG_DOCUMENTS_DIR="([^"]+)"\s*$')
        .firstMatch(line);
    if (match == null) continue;
    var path = match.group(1)!;
    path = path.replaceAll(r'${HOME}', home).replaceAll(r'$HOME', home);
    if (!path.startsWith(Platform.pathSeparator)) {
      path = '$home${Platform.pathSeparator}$path';
    }
    return path;
  }
  return null;
}

Future<String?> saveDeviceRecording({
  required String fileName,
  required Uint8List bytes,
}) async {
  if (bytes.isEmpty) return null;
  final sanitizedName = fileName
      .replaceAll(RegExp(r'[\x00-\x1F<>:"/\\|?*]'), '_')
      .trim();
  final targetName = sanitizedName.isEmpty ? 'recording.opus' : sanitizedName;

  if (Platform.isAndroid) {
    try {
      return await _channel.invokeMethod<String>('save', <String, Object?>{
        'fileName': targetName,
        'bytes': bytes,
      });
    } catch (_) {
      return null;
    }
  }

  final directory = await _userRecordingsDirectory();
  final target = File('${directory.path}${Platform.pathSeparator}$targetName');
  await target.writeAsBytes(bytes, flush: true);
  return target.path;
}

Future<List<String>> listSavedDeviceRecordings() async {
  if (Platform.isAndroid) {
    try {
      final list = await _channel.invokeListMethod<String>('list');
      return list ?? const [];
    } catch (_) {
      return const [];
    }
  }

  try {
    final directory = await _userRecordingsDirectory();
    final names = <String>[];
    for (final entity in directory.listSync()) {
      if (entity is File) {
        names.add(entity.uri.pathSegments.last);
      }
    }
    return names;
  } catch (_) {
    return const [];
  }
}

Future<bool> isDeviceRecordingSaved(String fileName) async {
  final list = await listSavedDeviceRecordings();
  return list.contains(fileName);
}

Future<bool> openDeviceRecordingsDirectory() async {
  if (Platform.isAndroid) {
    try {
      return await _channel.invokeMethod<bool>('open') ?? false;
    } catch (_) {
      return false;
    }
  }

  try {
    final directory = await _userRecordingsDirectory();
    final path = directory.path;
    final result = Platform.isWindows
        ? await Process.run('explorer.exe', [path])
        : Platform.isMacOS
        ? await Process.run('open', [path])
        : Platform.isLinux
        ? await Process.run('xdg-open', [path])
        : null;
    return result?.exitCode == 0;
  } catch (_) {
    return false;
  }
}
