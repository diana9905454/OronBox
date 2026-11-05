import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:oronbox/src/core/logging/diagnostic_event.dart';
import 'package:oronbox/src/core/logging/file_log_sink.dart';
import 'package:oronbox/src/core/services/build_info_service.dart';

export 'package:logging/logging.dart';

Logger getLogger(String name) => Logger('oronbox.$name');

/// Emits a diagnostic with machine-readable fields without serializing those
/// fields into the human message. Use this at application, command, HTTP and
/// runtime boundaries; byte-level protocol tracing belongs at [Level.FINE].
void logDiagnostic(
  Logger logger,
  Level level,
  String message, {
  Map<String, Object?> fields = const {},
  Object? error,
  StackTrace? stackTrace,
}) {
  if (level < Logger.root.level) return;
  publishDiagnostic(
    DiagnosticEvent(
      time: DateTime.now(),
      level: level,
      source: logger.fullName,
      process: _effectiveProcess,
      message: message,
      fields: fields,
      error: error,
      stackTrace: stackTrace,
    ),
  );
}

final _diagnostics = StreamController<DiagnosticEvent>.broadcast();
final _recentDiagnostics = <DiagnosticEvent>[];
DiagnosticProcess diagnosticProcess = DiagnosticProcess.frontend;

final _processZoneKey = Object();

/// Tags logs emitted by host-side code as backend. Mobile and web keep the
/// host inside the GUI process, so the backend boundary is a zone rather
/// than a real process.
R runAsDiagnosticBackend<R>(R Function() body) =>
    runZoned(body, zoneValues: {_processZoneKey: DiagnosticProcess.backend});

DiagnosticProcess get _effectiveProcess {
  final override = Zone.current[_processZoneKey];
  return override is DiagnosticProcess ? override : diagnosticProcess;
}

Stream<DiagnosticEvent> get oronBoxDiagnosticStream => _diagnostics.stream;
List<DiagnosticEvent> get recentOronBoxDiagnostics =>
    List.unmodifiable(_recentDiagnostics);
Stream<String> get oronBoxLogStream =>
    oronBoxDiagnosticStream.map((event) => event.format());
List<String> get recentOronBoxLogs =>
    recentOronBoxDiagnostics.map((event) => event.format()).toList();
bool _globalErrorLoggingInstalled = false;

void publishDiagnostic(DiagnosticEvent event) {
  _recentDiagnostics.add(event);
  if (_recentDiagnostics.length > 1000) _recentDiagnostics.removeAt(0);
  _diagnostics.add(event);
  if (event.level < Level.INFO) return;
  final line = event.format(includeStackTrace: false);
  writeFileLogLine(line);
  // ignore: avoid_print
  print(line);
}

void installGlobalErrorLogging() {
  if (_globalErrorLoggingInstalled) return;
  _globalErrorLoggingInstalled = true;
  final log = getLogger('UnhandledError');
  final previousFlutterError = FlutterError.onError;
  FlutterError.onError = (details) {
    logDiagnostic(
      log,
      Level.SEVERE,
      'Unhandled Flutter framework error',
      fields: {
        if (details.library != null) 'library': details.library,
        if (details.context != null) 'context': details.context.toString(),
      },
      error: details.exception,
      stackTrace: details.stack,
    );
    if (previousFlutterError != null) {
      previousFlutterError(details);
    } else {
      FlutterError.presentError(details);
    }
  };
  final previousPlatformError = PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (error, stackTrace) {
    logDiagnostic(
      log,
      Level.SEVERE,
      'Unhandled asynchronous error',
      error: error,
      stackTrace: stackTrace,
    );
    return previousPlatformError?.call(error, stackTrace) ?? false;
  };
}

void logPluginDiagnostic({
  required String pluginId,
  required String runtime,
  required Level level,
  required String message,
  Object? error,
  StackTrace? stackTrace,
  Map<String, Object?> fields = const {},
}) => publishDiagnostic(
  DiagnosticEvent(
    time: DateTime.now(),
    level: level,
    source: 'Plugin.$pluginId',
    process: DiagnosticProcess.backend,
    pluginId: pluginId,
    runtime: runtime,
    message: message,
    error: error,
    stackTrace: stackTrace,
    fields: fields,
  ),
);

Future<void> initLogging({
  List<String> arguments = const [],
  DiagnosticProcess process = DiagnosticProcess.frontend,
}) async {
  diagnosticProcess = process;
  await initializeFileLogSink(arguments: arguments);
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((record) {
    publishDiagnostic(
      DiagnosticEvent(
        time: record.time,
        level: record.level,
        source: record.loggerName,
        process: _effectiveProcess,
        message: record.message.toString(),
        error: record.error,
        stackTrace: record.stackTrace,
      ),
    );
  });
  logDiagnostic(
    getLogger('Application'),
    Level.INFO,
    'OronBox process started',
    fields: {
      'version': BuildInfoService.appVersion,
      'builder': BuildInfoService.buildUser,
      'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
      'mode': kReleaseMode
          ? 'release'
          : kProfileMode
          ? 'profile'
          : 'debug',
      'role': process.name,
      'launch': arguments.contains('--nogui') ? 'nogui' : 'gui',
    },
  );
}
