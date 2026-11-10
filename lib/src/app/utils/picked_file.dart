import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class PickedFileTooLarge implements Exception {
  const PickedFileTooLarge();
}

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
    this.source,
  });

  final String name;
  final String? path;
  final Uint8List? bytes;

  /// Platform handle for the pick.
  ///
  /// OpenHarmony pickers hand back `file://docs/...` URIs, which dart:io
  /// cannot open as a filesystem path, so byte reads must go through the
  /// platform implementation instead of `XFile(path)`.
  final PlatformFile? source;

  XFile? get xFile {
    if (bytes != null) return XFile.fromData(bytes!, name: name);
    final filePath = path;
    return filePath == null ? null : XFile(filePath, name: name);
  }

  Future<Uint8List?> readAsBytes({int? maxBytes}) async {
    if (bytes != null) {
      if (maxBytes != null && bytes!.length > maxBytes) {
        throw const PickedFileTooLarge();
      }
      return bytes;
    }
    final filePath = path;
    final handle = source;
    if (filePath == null && handle == null) return null;
    final data = handle != null
        ? await handle.readAsBytes()
        : await XFile(filePath!, name: name).readAsBytes();
    if (maxBytes != null && data.length > maxBytes) {
      throw const PickedFileTooLarge();
    }
    return data;
  }
}

Future<List<PickedFileData>> pickFilesData({
  FileType type = FileType.any,
  List<String>? allowedExtensions,
  String? dialogTitle,
  bool allowMultiple = false,
  bool loadBytes = false,
  int? maxBytes,
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
      final knownSize = maxBytes == null ? null : file.lengthSync();
      if (maxBytes != null && knownSize != null && knownSize > maxBytes) {
        throw const PickedFileTooLarge();
      }
      Uint8List? bytes;
      if (loadBytes || file.path == null || maxBytes != null) {
        // Read through the platform file: picker results may be URIs
        // (`file://docs/...` on OpenHarmony) that dart:io cannot open.
        bytes = await file.readAsBytes();
        if (maxBytes != null && bytes.length > maxBytes) {
          throw const PickedFileTooLarge();
        }
      }
      return PickedFileData(
        name: file.name,
        path: file.path,
        bytes: bytes,
        source: file,
      );
    }),
  );
}

Future<PickedFileData?> pickFileData({
  FileType type = FileType.any,
  List<String>? allowedExtensions,
  String? dialogTitle,
  bool loadBytes = false,
  int? maxBytes,
}) async {
  final files = await pickFilesData(
    dialogTitle: dialogTitle,
    type: type,
    allowedExtensions: allowedExtensions,
    loadBytes: loadBytes,
    maxBytes: maxBytes,
  );
  return files.isEmpty ? null : files.first;
}
