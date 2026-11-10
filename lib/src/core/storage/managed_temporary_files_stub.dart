import 'managed_temporary_files.dart';

Future<String> create(
  TemporaryFilePurpose purpose,
  String name,
  Future<void> Function(String) write,
) => throw UnsupportedError('Temporary file paths are unavailable');
Future<void> release(String path, {bool delete = true}) async {}
Future<int> cleanup(Duration minimumAge, Set<String> protectedPaths) async => 0;
