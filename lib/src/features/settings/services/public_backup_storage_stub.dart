import 'dart:typed_data';

Future<String?> savePublicBackupFile({
  required String fileName,
  required Uint8List bytes,
  bool useDownloadsOnOhos = false,
}) async => null;

Future<List<String>> listPublicBackupFiles() async => const [];

Future<Uint8List?> readPublicBackupFile(String fileName) async => null;

Future<bool> deletePublicBackupFile(String fileName) async => false;

Future<void> openPublicBackupDirectory() async {}

Future<String> getPublicBackupDisplayPath() async =>
    'Documents/OronBox/Backups';

Future<void> pruneAutoBackups({required int maxRetention}) async {}

/// Web 没有原生保存通道，失败原因恒为空。
String? getLastPublicBackupSaveError() => null;
