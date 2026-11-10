Future<void> initializeFileLogSink({List<String> arguments = const []}) async {}

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

void writeFileLogLine(String line) {}
Future<void> closeFileLogSink() async {}
Future<String?> openLogDirectory() async => null;
Future<String?> getLogDirectoryPath() async => null;
Future<int> logDirectorySize() async => 0;
Future<List<LogFileInfo>> listLogFiles() async => const [];
Future<String> readLogPreview(LogFileInfo file) async => '';
Future<String?> saveDeviceLogFile(String name, List<int> bytes) async => null;
Future<bool> openLogFile(LogFileInfo file) async => false;
Future<int> clearLogFiles() async => 0;
Future<String?> exportLogsZip() async => null;
