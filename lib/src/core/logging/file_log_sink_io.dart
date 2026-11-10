import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:oronbox/src/core/services/build_info_service.dart';

/// 日志导出通道。Android 走 DocumentsProvider，鸿蒙走系统下载授权。
const _logsChannel = MethodChannel('oronbox/logs');

bool _isManagedLogFile(File file) {
  final name = file.uri.pathSegments.last;
  return name.endsWith('.log') ||
      (name.startsWith('device-') &&
          (name.endsWith('.zip') || name.endsWith('.tar.gz')));
}

class LogFileInfo {
  const LogFileInfo({
    required this.name,
    required this.path,
    required this.size,
    required this.modifiedAt,
  });

  final String name;
  final String path;
  final int size;
  final DateTime modifiedAt;
}

Directory? _logDirectory;
SerialFileLogWriter? _writer;
String? _currentLogPath;

class SerialFileLogWriter {
  SerialFileLogWriter(this._sink);

  /// Flushing after every single line costs one write syscall per log record,
  /// which stacks up during chatty periods (device sync, plugin traffic).
  /// Buffer instead and flush on whichever comes first: [_flushAfterLines]
  /// lines, or [_flushInterval]. Crash exposure is bounded by that interval,
  /// and [close] always flushes what is left.
  static const _flushAfterLines = 64;
  static const _flushInterval = Duration(milliseconds: 250);

  final IOSink _sink;
  Future<void> _pending = Future<void>.value();
  bool _closed = false;
  Timer? _flushTimer;
  int _bufferedLines = 0;

  void writeLine(String line) {
    if (_closed) return;
    _pending = _pending
        .then((_) async {
          _sink.writeln(line);
          _bufferedLines++;
          if (_bufferedLines >= _flushAfterLines) {
            await _flush();
          } else {
            _flushTimer ??= Timer(_flushInterval, () {
              _flushTimer = null;
              unawaited(_flush());
            });
          }
        })
        .catchError((Object _) {
          // Logging must never crash the application. A later line can still
          // retry after a transient sink failure.
        });
  }

  Future<void> _flush() async {
    _flushTimer?.cancel();
    _flushTimer = null;
    _bufferedLines = 0;
    try {
      await _sink.flush();
    } catch (_) {
      // A failed flush must not surface as an application error; the next
      // write or close() will try again.
    }
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _pending;
    await _flush();
    await _sink.close();
  }
}

Future<void> initializeFileLogSink({List<String> arguments = const []}) async {
  final support = await getApplicationSupportDirectory();
  final directory = Directory('${support.path}${Platform.pathSeparator}logs');
  await directory.create(recursive: true);
  _logDirectory = directory;
  await _removeExpiredLogs(directory);
  final now = DateTime.now();
  final timestamp =
      '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}_'
      '${now.hour.toString().padLeft(2, '0')}-'
      '${now.minute.toString().padLeft(2, '0')}-'
      '${now.second.toString().padLeft(2, '0')}-'
      '${now.millisecond.toString().padLeft(3, '0')}';
  final file = File(
    '${directory.path}${Platform.pathSeparator}oronbox-$timestamp-$pid.log',
  );
  await _writer?.close();
  _writer = SerialFileLogWriter(file.openWrite(mode: FileMode.write));
  _currentLogPath = file.path;
  final commit = await BuildInfoService.resolveCommitHash();
  _writer!.writeLine('OronBox ${BuildInfoService.appVersion} ($commit)');
  _writer!.writeLine('Builder: ${BuildInfoService.buildUser}');
  _writer!.writeLine('Started: ${now.toIso8601String()}');
  _writer!.writeLine(
    'Platform: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
  );
  _writer!.writeLine('Architecture: ${Abi.current()}');
  _writer!.writeLine('Dart: ${Platform.version}');
  _writer!.writeLine('Process: $pid');
  _writer!.writeLine(
    'Arguments: ${arguments.length} value(s), content omitted',
  );
  _writer!.writeLine('');
}

Future<void> _removeExpiredLogs(Directory directory) async {
  final cutoff = DateTime.now().subtract(const Duration(days: 3));
  await for (final entity in directory.list()) {
    if (entity is! File || !entity.path.endsWith('.log')) continue;
    try {
      final modified = await entity.lastModified();
      if (modified.isBefore(cutoff)) await entity.delete();
    } catch (_) {}
  }
}

void writeFileLogLine(String line) {
  _writer?.writeLine(line);
}

Future<int> logDirectorySize() async {
  final path = await getLogDirectoryPath();
  if (path == null) return 0;
  var total = 0;
  await for (final entity in Directory(path).list()) {
    if (entity is File && _isManagedLogFile(entity)) {
      total += await entity.length();
    }
  }
  return total;
}

Future<List<LogFileInfo>> listLogFiles() async {
  final path = await getLogDirectoryPath();
  if (path == null) return const [];
  final result = <LogFileInfo>[];
  await for (final entity in Directory(path).list()) {
    if (entity is! File || !_isManagedLogFile(entity)) continue;
    result.add(
      LogFileInfo(
        name: entity.uri.pathSegments.last,
        path: entity.path,
        size: await entity.length(),
        modifiedAt: await entity.lastModified(),
      ),
    );
  }
  result.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
  return result;
}

/// Reads the most recent part of a text log without loading the entire file.
Future<String> readLogPreview(LogFileInfo file) async {
  const previewLimit = 64 * 1024;
  final reader = await File(file.path).open();
  try {
    final size = await reader.length();
    final truncated = size > previewLimit;
    if (truncated) await reader.setPosition(size - previewLimit);
    final bytes = await reader.read(truncated ? previewLimit : size);
    final start = truncated ? bytes.indexOf(0x0A) + 1 : 0;
    final text = utf8.decode(bytes.sublist(start), allowMalformed: true);
    return truncated ? '…\n$text' : text;
  } finally {
    await reader.close();
  }
}

Future<String?> saveDeviceLogFile(String name, List<int> bytes) async {
  if (bytes.isEmpty) return null;
  final safeName = name
      .split(RegExp(r'[/\\]'))
      .last
      .replaceAll(RegExp(r'[\x00-\x1F<>:"/\\|?*]'), '_')
      .trim()
      .replaceFirst(RegExp(r'[. ]+$'), '');
  final fileName = safeName.isEmpty ? 'device-logs.tar.gz' : safeName;
  final directory = await _exportDirectory();
  final file = await _uniqueLogFile(
    File('${directory.path}${Platform.pathSeparator}$fileName'),
  );
  final temporary = File('${file.path}.part');
  try {
    await temporary.writeAsBytes(bytes, flush: true);
    await temporary.rename(file.path);
  } catch (_) {
    try {
      await temporary.delete();
    } catch (_) {}
    rethrow;
  }

  if (Platform.isAndroid) {
    try {
      final exportedPath = await _logsChannel.invokeMethod<String>('export', {
        'name': file.uri.pathSegments.last,
      });
      if (exportedPath != null && exportedPath.isNotEmpty) {
        return exportedPath;
      }
    } catch (_) {
      // Fallback to internal file path if export fails
    } finally {
      try {
        await file.delete();
      } catch (_) {}
    }
  }

  return file.path;
}

Future<File> _uniqueLogFile(File requested) async {
  if (!await requested.exists()) return requested;
  final directory = requested.parent;
  final name = requested.uri.pathSegments.last;
  final dot = name.lastIndexOf('.');
  final stem = dot > 0 ? name.substring(0, dot) : name;
  final extension = dot > 0 ? name.substring(dot) : '';
  for (var index = 2; index < 100000; index++) {
    final candidate = File(
      '${directory.path}${Platform.pathSeparator}$stem ($index)$extension',
    );
    if (!await candidate.exists()) return candidate;
  }
  throw StateError('Unable to allocate a unique log file name');
}

Future<bool> openLogFile(LogFileInfo file) async {
  if (Platform.isOhos) {
    return await _logsChannel.invokeMethod<String>('saveToDownloads', {
          'name': file.name,
        }) !=
        null;
  }
  if (Platform.isAndroid) {
    try {
      return await _logsChannel.invokeMethod<bool>('share', {
            'name': file.name,
          }) ??
          false;
    } catch (_) {
      return false;
    }
  }
  try {
    final result = Platform.isWindows
        ? await Process.run('explorer.exe', ['/select,${file.path}'])
        : Platform.isMacOS
        ? await Process.run('open', ['-R', file.path])
        : Platform.isLinux
        ? await Process.run('xdg-open', [File(file.path).parent.path])
        : null;
    return result?.exitCode == 0;
  } catch (_) {
    return false;
  }
}

Future<int> clearLogFiles() async {
  final path = await getLogDirectoryPath();
  if (path == null) return 0;
  final files = <File>[];
  await for (final entity in Directory(path).list()) {
    if (entity is File && _isManagedLogFile(entity)) files.add(entity);
  }
  var removed = 0;
  for (final file in files) {
    if (file.path == _currentLogPath) continue;
    try {
      await file.delete();
      removed++;
    } catch (_) {}
  }
  return removed;
}

Future<String?> exportLogsZip() async {
  final path = await getLogDirectoryPath();
  if (path == null) return null;
  final archive = Archive();
  await for (final entity in Directory(path).list()) {
    if (entity is! File || !_isManagedLogFile(entity)) continue;
    final bytes = await entity.readAsBytes();
    archive.addFile(
      ArchiveFile(entity.uri.pathSegments.last, bytes.length, bytes),
    );
  }
  if (archive.isEmpty) return null;
  final zipped = ZipEncoder().encode(archive);
  final now = DateTime.now();
  final timestamp =
      '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-'
      '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
  final name = 'oronbox-logs-$timestamp.zip';
  final directory = await _exportDirectory();
  final target = await _uniqueLogFile(
    File('${directory.path}${Platform.pathSeparator}$name'),
  );
  await target.writeAsBytes(zipped);
  if (Platform.isOhos) {
    try {
      return await _logsChannel.invokeMethod<String>('saveToDownloads', {
        'name': target.uri.pathSegments.last,
      });
    } finally {
      try {
        await target.delete();
      } catch (_) {}
    }
  }
  if (Platform.isAndroid) {
    try {
      final exportedPath = await _logsChannel.invokeMethod<String>('export', {
        'name': target.uri.pathSegments.last,
      });
      if (exportedPath != null && exportedPath.isNotEmpty) {
        return exportedPath;
      }
    } catch (_) {
      return null;
    } finally {
      try {
        await target.delete();
      } catch (_) {}
    }
  }
  return target.path;
}

Future<Directory> _exportDirectory() async {
  // Keep device logs alongside the runtime logs on mobile. Android's
  // DocumentsProvider also resolves export archives by name from this directory.
  if (Platform.isAndroid || Platform.isIOS || Platform.isOhos) {
    final path = await getLogDirectoryPath();
    if (path != null) return Directory(path);
  }
  if (!Platform.isAndroid && !Platform.isIOS) {
    final home =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    if (home != null) {
      final logsDir = Directory(
        '$home${Platform.pathSeparator}Documents${Platform.pathSeparator}OronBox${Platform.pathSeparator}Logs',
      );
      if (!await logsDir.exists()) {
        await logsDir.create(recursive: true);
      }
      return logsDir;
    }
  }
  return getApplicationDocumentsDirectory();
}

Future<void> closeFileLogSink() async {
  final writer = _writer;
  _writer = null;
  _currentLogPath = null;
  await writer?.close();
}

Future<String?> getLogDirectoryPath() async {
  if (_logDirectory == null) await initializeFileLogSink();
  return _logDirectory?.path;
}

/// Opens the log directory in the platform file manager where supported.
Future<String?> openLogDirectory() async {
  if (Platform.isOhos) {
    try {
      return await _logsChannel.invokeMethod<String>('exportDirectory');
    } on PlatformException {
      return null;
    }
  }
  if (Platform.isAndroid) {
    try {
      final opened = await _logsChannel.invokeMethod<bool>('open') ?? false;
      return opened ? '' : null;
    } catch (_) {
      return null;
    }
  }
  final path = await getLogDirectoryPath();
  if (path == null) return null;
  try {
    final result = Platform.isWindows
        ? await Process.run('explorer.exe', [path])
        : Platform.isMacOS
        ? await Process.run('open', [path])
        : Platform.isLinux
        ? await Process.run('xdg-open', [path])
        : null;
    return (result?.exitCode ?? 1) == 0 ? '' : null;
  } catch (_) {
    return null;
  }
}
