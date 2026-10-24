import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider_windows/path_provider_windows.dart';

const _channel = MethodChannel('oronbox/xiaomi_screenshot');
const _directoryName = 'WatchScreenshots';

/// Exports a Xiaomi wearable screenshot to the user's public Pictures folder.
///
/// Android uses MediaStore so the file remains in the official
/// `Pictures/WatchScreenshots` directory. Desktop platforms resolve the
/// user's Pictures directory and write the file there as well.
Future<String?> saveXiaomiScreenshot(Uint8List bytes) async {
  if (bytes.isEmpty) return null;

  final fileName = _fileName(DateTime.now());
  if (Platform.isAndroid) {
    return _channel.invokeMethod<String>('save', <String, Object?>{
      'bytes': bytes,
      'fileName': fileName,
    });
  }
  if (!Platform.isLinux && !Platform.isMacOS && !Platform.isWindows) {
    return null;
  }

  final pictures = await _userPicturesDirectory();
  final directory = Directory(
    '${pictures.path}${Platform.pathSeparator}$_directoryName',
  );
  await directory.create(recursive: true);
  final file = File('${directory.path}${Platform.pathSeparator}$fileName');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

String _fileName(DateTime now) =>
    'IMG_${now.year.toString().padLeft(4, '0')}'
    '${now.month.toString().padLeft(2, '0')}'
    '${now.day.toString().padLeft(2, '0')}_'
    '${now.hour.toString().padLeft(2, '0')}'
    '${now.minute.toString().padLeft(2, '0')}'
    '${now.second.toString().padLeft(2, '0')}_'
    '${now.millisecond.toString().padLeft(3, '0')}.png';

Future<Directory> _userPicturesDirectory() async {
  if (Platform.isWindows) {
    final Future<String?> lookup = PathProviderWindows().getPath(
      '{33E28130-4E1E-4676-835A-98395C3BC3BB}', // FOLDERID_Pictures
    );
    final path = await lookup;
    if (path == null || path.isEmpty) {
      throw StateError('Unable to locate the Windows Pictures directory');
    }
    return Directory(path);
  }
  final environment = Platform.environment;
  if (Platform.isLinux) {
    final configured = await _linuxPicturesDirectory(environment);
    if (configured != null) return Directory(configured);
  }

  final home = environment['HOME'];
  if (home == null || home.trim().isEmpty) {
    throw StateError('Unable to locate the user Pictures directory');
  }
  return Directory('$home${Platform.pathSeparator}Pictures');
}

Future<String?> _linuxPicturesDirectory(Map<String, String> environment) async {
  final home = environment['HOME'];
  if (home == null || home.trim().isEmpty) return null;

  final configHome = environment['XDG_CONFIG_HOME'];
  final configPath = configHome == null || configHome.trim().isEmpty
      ? '$home${Platform.pathSeparator}.config${Platform.pathSeparator}user-dirs.dirs'
      : '$configHome${Platform.pathSeparator}user-dirs.dirs';
  final config = File(configPath);
  if (!await config.exists()) return null;

  for (final line in await config.readAsLines()) {
    final match = RegExp(r'^\s*XDG_PICTURES_DIR="([^"]+)"\s*$')
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
