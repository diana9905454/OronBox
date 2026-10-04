import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

bool get shouldLoadPickedFileData => kIsWeb;

/// The small piece of file-picker state the app needs after selection.
///
/// `file_picker` 12 returns platform files directly and loads their contents
/// asynchronously. Keeping that detail here prevents every feature page from
/// depending on the package's platform representation.
class PickedFileData {
  const PickedFileData({
    required this.name,
    this.path,
    this.bytes,
  });

  final String name;
  final String? path;
  final Uint8List? bytes;

  XFile? get xFile {
    if (bytes != null) return XFile.fromData(bytes!, name: name);
    final filePath = path;
    return filePath == null ? null : XFile(filePath, name: name);
  }

  Future<Uint8List?> readAsBytes() async {
    if (bytes != null) return bytes;
    final filePath = path;
    if (filePath == null) return null;
    return XFile(filePath, name: name).readAsBytes();
  }
}

Future<List<PickedFileData>> pickFilesData({
  FileType type = FileType.any,
  List<String>? allowedExtensions,
  String? dialogTitle,
  bool allowMultiple = false,
  bool loadBytes = false,
}) async {
  final files = allowMultiple
      ? await FilePicker.pickFiles(
          dialogTitle: dialogTitle,
          type: type,
          allowedExtensions: allowedExtensions,
        )
      : [
          if (await FilePicker.pickFile(
                dialogTitle: dialogTitle,
                type: type,
                allowedExtensions: allowedExtensions,
              )
              case final file?)
            file,
        ];
  return Future.wait(
    files.map((file) async {
      Uint8List? bytes;
      if (loadBytes || file.path == null) {
        bytes = await file.readAsBytes();
      }
      return PickedFileData(name: file.name, path: file.path, bytes: bytes);
    }),
  );
}

Future<PickedFileData?> pickFileData({
  FileType type = FileType.any,
  List<String>? allowedExtensions,
  String? dialogTitle,
  bool loadBytes = false,
}) async {
  final files = await pickFilesData(
    dialogTitle: dialogTitle,
    type: type,
    allowedExtensions: allowedExtensions,
    loadBytes: loadBytes,
  );
  return files.isEmpty ? null : files.first;
}
