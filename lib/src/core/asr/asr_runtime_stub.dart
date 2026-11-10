import 'package:dio/dio.dart';

Future<bool> isAsrRuntimeInstalled() async => true;
Future<void> installAsrRuntime({
  required CancelToken cancel,
  required void Function(int, int) onProgress,
}) async {}
Future<void> removeAsrRuntime() async {}

int get asrRuntimeDownloadBytes => 0;

Future<void> cleanupAsrRuntimes() async {}
