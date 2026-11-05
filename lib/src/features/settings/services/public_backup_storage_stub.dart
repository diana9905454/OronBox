import 'dart:typed_data';

Future<String?> savePublicBackupFile({
  required String fileName,
  required Uint8List bytes,
}) async => null;

Future<List<String>> listPublicBackupFiles() async => const [];

Future<Uint8List?> readPublicBackupFile(String fileName) async => null;

Future<bool> deletePublicBackupFile(String fileName) async => false;

Future<void> openPublicBackupDirectory() async {}

Future<String> getPublicBackupDisplayPath() async =>
    'Documents/OronBox/Backups';

Future<void> pruneAutoBackups({required int maxRetention}) async {}
