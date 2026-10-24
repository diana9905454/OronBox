import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:oronbox/src/core/storage/app_data_directory.dart';

import 'asr.dart';

/// A partial download is never exposed as an installed model.
Future<void> downloadModelFile({
  required Dio dio,
  required AppDataDirectory directory,
  required Uri source,
  Uri? fallbackSource,
  required String name,
  required int bytes,
  required String checksum,
  required CancelToken cancel,
  required void Function(int) onProgress,
}) async {
  Future<void> attempt(Uri uri) => _downloadModelFile(
    dio: dio,
    directory: directory,
    source: uri,
    name: name,
    bytes: bytes,
    checksum: checksum,
    cancel: cancel,
    onProgress: onProgress,
  );
  try {
    await attempt(source);
  } catch (error) {
    final retryable =
        error is DioException && error.type != DioExceptionType.cancel ||
        error is AsrFailure &&
            (error.code == 'model_download' || error.code == 'model_checksum');
    if (fallbackSource == null || cancel.isCancelled || !retryable) rethrow;
    await attempt(fallbackSource);
  }
}

Future<void> _downloadModelFile({
  required Dio dio,
  required AppDataDirectory directory,
  required Uri source,
  required String name,
  required int bytes,
  required String checksum,
  required CancelToken cancel,
  required void Function(int) onProgress,
}) async {
  final entries = await directory.files(includeTemporary: true);
  if (entries.any((file) => file.path == name && file.bytes == bytes) &&
      await _valid(directory, name, checksum)) {
    onProgress(bytes);
    return;
  }
  final partial = '$name.part';
  final metadata = '$name.resume.json';
  var offset = 0;
  String? etag;
  for (final entry in await directory.files(includeTemporary: true)) {
    if (entry.path == partial) offset = entry.bytes;
  }
  final saved = await directory.read(metadata);
  if (saved != null) {
    try {
      final value = jsonDecode(utf8.decode(saved));
      if (value is Map && value['source'] == source.toString()) {
        etag = value['etag'] as String?;
      } else {
        offset = 0;
      }
    } on FormatException {
      offset = 0;
    }
  } else {
    offset = 0;
  }
  if (offset > bytes) offset = 0;
  if (offset == bytes && await _valid(directory, partial, checksum)) {
    await directory.move(partial, name);
    await directory.remove(metadata);
    onProgress(bytes);
    return;
  }
  if (offset == bytes) offset = 0;
  final response = await dio.get<ResponseBody>(
    source.toString(),
    options: Options(
      responseType: ResponseType.stream,
      headers: {
        if (offset > 0) 'Range': 'bytes=$offset-',
        if (offset > 0 && etag != null) 'If-Range': etag,
      },
    ),
    cancelToken: cancel,
  );
  final status = response.statusCode;
  if (status == 200) {
    offset = 0;
    await directory.remove(partial);
  } else if (status == 206) {
    final range = response.headers.value('content-range');
    final match = RegExp(r'^bytes (\d+)-(\d+)/(\d+)$').firstMatch(range ?? '');
    if (match == null ||
        int.parse(match[1]!) != offset ||
        int.parse(match[2]!) != bytes - 1 ||
        int.parse(match[3]!) != bytes ||
        (etag != null && response.headers.value('etag') != etag)) {
      await response.data!.stream.listen(null).cancel();
      throw const AsrFailure('model_download');
    }
  } else {
    await response.data!.stream.listen(null).cancel();
    throw const AsrFailure('model_download');
  }
  if (offset == 0) await directory.remove(partial);
  await directory.write(
    metadata,
    Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'source': source.toString(),
          'etag': response.headers.value('etag'),
        }),
      ),
    ),
  );
  var received = offset;
  Stream<List<int>> checked() async* {
    await for (final chunk in response.data!.stream) {
      if (cancel.isCancelled) throw const AsrFailure('cancelled');
      received += chunk.length;
      if (received > bytes) throw const AsrFailure('model_checksum');
      yield chunk;
      onProgress(received);
    }
  }

  await directory.writeStream(partial, checked(), append: true);
  if (cancel.isCancelled) throw const AsrFailure('cancelled');
  if (received != bytes) throw const AsrFailure('model_download');
  if (!await _valid(directory, partial, checksum)) {
    await directory.remove(partial);
    await directory.remove(metadata);
    throw const AsrFailure('model_checksum');
  }
  await directory.move(partial, name);
  await directory.remove(metadata);
}

Future<bool> _valid(
  AppDataDirectory directory,
  String name,
  String checksum,
) async =>
    (await sha256.bind(directory.readStream(name)).first).toString() ==
    checksum;
