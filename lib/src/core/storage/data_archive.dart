import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Reads entries as bytes only; archive paths are never native filesystem paths.
Map<String, Uint8List> readDataArchive(
  Uint8List bytes, {
  int maxBytes = 128 * 1024 * 1024,
  int maxFiles = 2048,
}) {
  if (bytes.length > maxBytes) {
    throw const FormatException('Archive is too large');
  }
  final directory = ZipDirectory()..read(InputMemoryStream(bytes));
  if (directory.fileHeaders.isEmpty ||
      directory.fileHeaders.length > maxFiles) {
    throw const FormatException('Invalid archive entry count');
  }
  final result = <String, Uint8List>{};
  var total = 0;
  for (final header in directory.fileHeaders) {
    final name = header.filename;
    if (name.startsWith('/') ||
        name.contains('\\') ||
        name.contains(':') ||
        name
            .split('/')
            .any((part) => part.isEmpty || part == '.' || part == '..') ||
        ((header.externalFileAttributes >> 16) & 0xf000) == 0xa000 ||
        result.containsKey(name) ||
        header.uncompressedSize > maxBytes - total) {
      throw const FormatException('Invalid archive entry');
    }
    final output = _BoundedOutput(maxBytes - total);
    header.file!.decompress(output);
    final data = output.getBytes();
    if (data.length != header.uncompressedSize ||
        getCrc32(data) != header.crc32) {
      throw const FormatException('Archive checksum mismatch');
    }
    result[name] = data;
    total += data.length;
  }
  return result;
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
