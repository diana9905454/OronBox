import 'managed_temporary_files_stub.dart'
    if (dart.library.io) 'managed_temporary_files_io.dart'
    as platform;

enum TemporaryFilePurpose { downloads, installs }

/// The owner keeps a lease until the consumer releases the file.
class ManagedTemporaryFiles {
  static Future<String> create(
    TemporaryFilePurpose purpose,
    String name,
    Future<void> Function(String path) write,
  ) => platform.create(purpose, name, write);
  static Future<void> release(String path, {bool delete = true}) =>
      platform.release(path, delete: delete);
  static Future<int> cleanup({
    Duration minimumAge = const Duration(days: 1),
    Set<String> protectedPaths = const {},
  }) => platform.cleanup(minimumAge, protectedPaths);
}
