import 'package:dio/dio.dart';

import 'asr_runtime_stub.dart'
    if (dart.library.io) 'asr_runtime_io.dart'
    as platform;

Future<bool> isAsrRuntimeInstalled() => platform.isAsrRuntimeInstalled();
Future<void> installAsrRuntime({
  required CancelToken cancel,
  required void Function(int, int) onProgress,
}) => platform.installAsrRuntime(cancel: cancel, onProgress: onProgress);
Future<void> removeAsrRuntime() => platform.removeAsrRuntime();

int get asrRuntimeDownloadBytes => platform.asrRuntimeDownloadBytes;

Future<void> cleanupAsrRuntimes() => platform.cleanupAsrRuntimes();
