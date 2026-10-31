import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Reads entries as bytes only; archive paths are never native filesystem paths.
Map<String, Uint8List> readDataArchive(
  Uint8List bytes, {
  int maxBytes = 128 * 1024 * 1024,
  int maxFiles = 2048,
}) {
  final result = <String, Uint8List>{};
  _readDataArchiveEntries(
    bytes,
    maxBytes: maxBytes,
    maxFiles: maxFiles,
    onEntry: (name, data) => result[name] = data,
  );
  return result;
}

void validateDataArchive(
  Uint8List bytes, {
  int maxBytes = 128 * 1024 * 1024,
  int maxFiles = 2048,
}) {
  _readDataArchiveEntries(
    bytes,
    maxBytes: maxBytes,
    maxFiles: maxFiles,
    onEntry: (_, _) {},
  );
}

void _readDataArchiveEntries(
  Uint8List bytes, {
  required int maxBytes,
  required int maxFiles,
  required void Function(String name, Uint8List data) onEntry,
}) {
  if (bytes.length > maxBytes) {
    throw const FormatException('Archive is too large');
  }
  final directory = ZipDirectory()..read(InputMemoryStream(bytes));
  if (directory.fileHeaders.isEmpty ||
      directory.fileHeaders.length > maxFiles) {
    throw const FormatException('Invalid archive entry count');
  }
  final names = <String>{};
  var total = 0;
  for (final header in directory.fileHeaders) {
    final name = header.filename;
    final directoryEntry = name.endsWith('/');
    if (name.startsWith('/') ||
        name.contains('\\') ||
        name.contains(':') ||
        name
            .split('/')
            .asMap()
            .entries
            .any(
              (entry) =>
                  entry.value == '.' ||
                  entry.value == '..' ||
                  (entry.value.isEmpty &&
                      !(directoryEntry &&
                          entry.key == name.split('/').length - 1)),
            ) ||
        ((header.externalFileAttributes >> 16) & 0xf000) == 0xa000 ||
        !names.add(name) ||
        header.uncompressedSize > maxBytes - total) {
      throw const FormatException('Invalid archive entry');
    }
    if (directoryEntry) continue;
    final output = _BoundedOutput(maxBytes - total);
    header.file!.decompress(output);
    final data = output.getBytes();
    if (data.length != header.uncompressedSize ||
        getCrc32(data) != header.crc32) {
      throw const FormatException('Archive checksum mismatch');
    }
    onEntry(name, data);
    total += data.length;
  }
}

class _BoundedOutput extends OutputMemoryStream {
  _BoundedOutput(this.limit);
  final int limit;
  void _check(int count) {
    if (count < 0 || length + count > limit) {
      throw const FormatException('Archive expansion limit exceeded');
    }
  }

  @override
  void writeByte(int value) {
    _check(1);
    super.writeByte(value);
  }

  @override
  void writeBytes(List<int> bytes, {int? length}) {
    _check(length ?? bytes.length);
    super.writeBytes(bytes, length: length);
  }

  @override
  void writeStream(InputStream stream) {
    _check(stream.length);
    super.writeStream(stream);
  }

  @override
  void writeBackReference(int distance, int count) {
    _check(count);
    super.writeBackReference(distance, count);
  }
}
