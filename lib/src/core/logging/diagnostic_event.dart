import 'dart:convert';

import 'package:logging/logging.dart';

enum DiagnosticProcess { frontend, backend, cli, debugWindow, pluginWindow }

class DiagnosticEvent {
  const DiagnosticEvent({
    required this.time,
    required this.level,
    required this.source,
    required this.process,
    required this.message,
    this.pluginId,
    this.runtime,
    this.error,
    this.stackTrace,
    this.fields = const {},
  });

  final DateTime time;
  final Level level;
  final String source;
  final DiagnosticProcess process;
  final String message;
  final String? pluginId;
  final String? runtime;
  final Object? error;
  final StackTrace? stackTrace;
  final Map<String, Object?> fields;

  String get scope => pluginId == null ? process.name : 'plugin:$pluginId';

  Map<String, Object?> toJson() => {
    'time': time.toIso8601String(),
    'level': level.name,
    'source': source,
    'process': process.name,
    'message': message,
    if (pluginId != null) 'pluginId': pluginId,
    if (runtime != null) 'runtime': runtime,
    if (error != null) 'error': error.toString(),
    if (stackTrace != null) 'stackTrace': stackTrace.toString(),
    if (fields.isNotEmpty) 'fields': fields,
  };

  factory DiagnosticEvent.fromJson(Map<String, Object?> json) {
    final levelName = json['level']?.toString() ?? 'INFO';
    return DiagnosticEvent(
      time: DateTime.tryParse(json['time']?.toString() ?? '') ?? DateTime.now(),
      level: Level.LEVELS.firstWhere(
        (level) => level.name == levelName,
        orElse: () => Level.INFO,
      ),
      source: json['source']?.toString() ?? 'unknown',
      process: DiagnosticProcess.values.firstWhere(
        (value) => value.name == json['process']?.toString(),
        orElse: () => DiagnosticProcess.backend,
      ),
      message: json['message']?.toString() ?? '',
      pluginId: json['pluginId']?.toString(),
      runtime: json['runtime']?.toString(),
      error: json['error'],
      stackTrace: json['stackTrace'] == null
          ? null
          : StackTrace.fromString(json['stackTrace'].toString()),
      fields: (json['fields'] as Map?)?.cast<String, Object?>() ?? const {},
    );
  }

  String format({bool includeStackTrace = true}) {
    final buffer = StringBuffer('${_formatTime(time)} ')
      ..write(level.name.padRight(5))
      ..write(' [$scope] ')
      ..write(source)
      ..write(' – ')
      ..write(message);
    if (fields.isNotEmpty) {
      for (final entry in fields.entries) {
        buffer
          ..write(' ')
          ..write(entry.key)
          ..write('=')
          ..write(_formatField(entry.value));
      }
    }
    if (error != null) buffer.write('\n  error: $error');
    if (includeStackTrace && stackTrace != null) {
      buffer.write('\n$stackTrace');
    }
    return buffer.toString();
  }

  static String _formatTime(DateTime value) {
    final local = value.toLocal();
    String two(int part) => part.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}:${two(local.second)}.'
        '${local.millisecond.toString().padLeft(3, '0')}';
  }

  String _formatField(Object? value) {
    String encoded;
    try {
      encoded = switch (value) {
        null || num() || bool() => value.toString(),
        String text => text.contains(RegExp(r'\s')) ? jsonEncode(text) : text,
        _ => jsonEncode(value),
      };
    } catch (_) {
      encoded = jsonEncode(value.toString());
    }
    return encoded.length <= 300 ? encoded : '${encoded.substring(0, 297)}...';
  }
}
