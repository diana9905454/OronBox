import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:oronbox/src/core/network/app_http_transport.dart';
import 'package:oronbox/src/core/storage/app_data_directory.dart';


import 'asr.dart';
import 'asr_model_download.dart';
import 'local_asr.dart' show validateLocalAsr, modelUsedByCurrentProcess;

class AsrModelFile {
  const AsrModelFile(this.path, this.bytes, this.sha256);
  final String path;
  final int bytes;
  final String sha256;
  String get name => path.split('/').last;
}

class AsrModelStore {
  AsrModelStore({AppDataDirectory? storage, this.relativeDirectory = directory})
    : _storage = storage == null ? null : Future.value(storage);
  final String relativeDirectory;
  static const id = 'zipformer-small-zh-en';
  static const revision = 'e2382758de9a0219b4efe682b95af30b399db3b8';
  static const directory = 'ai/models/$id/$revision';
  static const files = [
    AsrModelFile(
      'exp/32/encoder-epoch-99-avg-1.int8.onnx',
      42980793,
      'db6f51551762e40e549166fe041ea3e45464370b595e9ad23f06478ec3794fbb',
    ),
    AsrModelFile(
      'exp/32/decoder-epoch-99-avg-1.onnx',
      13877276,
      '89be509a83175261695bdef5fd1c7b9ab1129a663d1284e7ba9f8507b21e0906',
    ),
    AsrModelFile(
      'exp/32/joiner-epoch-99-avg-1.int8.onnx',
      3228485,
      'bdda356d6f9b8c2d7cee9ee0e26075fa537490f7fd06520be408d287073667b9',
    ),
    AsrModelFile(
      'data/lang_char_bpe/tokens.txt',
      56317,
      'a8e0e4ec53810e433789b54a5c0134a7eaa2ffca595a6334d54c00da858841d3',
    ),
  ];
  static int get totalBytes => files.fold(0, (sum, file) => sum + file.bytes);
  Future<AppDataDirectory>? _storage;
  Future<AppDataDirectory> get storage =>
      _storage ??= openAppDataDirectory(relativeDirectory);

  Future<bool> isInstalled() async {
    final store = await storage;
    final manifest = await store.read('manifest.json');
    if (manifest == null) return false;
    try {
      final value = jsonDecode(utf8.decode(manifest));
      if (value is! Map || value['revision'] != revision) return false;
    } on FormatException {
      return false;
    }
    final existing = {
      for (final file in await store.files()) file.path: file.bytes,
    };
    return files.every((file) => existing[file.name] == file.bytes);
  }

  Future<void> install({
    required CancelToken cancel,
    required void Function(int, int) onProgress,
  }) async {
    final store = await storage;
    if (await modelUsedByCurrentProcess(store)) throw const AsrFailure('busy');
    final dio = createAppHttpTransport(
      options: BaseOptions(
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(minutes: 5),
      ),
    );
    try {
      final acquired = await store.tryExclusive(() async {
        var completed = 0;
        for (final file in files) {
          if (cancel.isCancelled) throw const AsrFailure('cancelled');
          final installed = (await store.files()).any(
            (entry) => entry.path == file.name && entry.bytes == file.bytes,
          );
          if (installed &&
              (await sha256.bind(store.readStream(file.name)).first)
                      .toString() ==
                  file.sha256) {
            await store
                .scope('.staging')
                .writeStream(file.name, store.readStream(file.name));
            completed += file.bytes;
            onProgress(completed, totalBytes);
            continue;
          }
          final staged = store.scope('.staging');
          await downloadModelFile(
            dio: dio,
            directory: staged,
            source: Uri.parse(
              'https://huggingface.co/csukuangfj/k2fsa-zipformer-bilingual-zh-en-t/resolve/$revision/${file.path}',
            ),
            fallbackSource: Uri.parse(
              'https://hf-mirror.com/csukuangfj/k2fsa-zipformer-bilingual-zh-en-t/resolve/$revision/${file.path}',
            ),
            name: file.name,
            bytes: file.bytes,
            checksum: file.sha256,
            cancel: cancel,
            onProgress: (received) =>
                onProgress(completed + received, totalBytes),
          );
          completed += file.bytes;
          onProgress(completed, totalBytes);
        }
        if (cancel.isCancelled) throw const AsrFailure('cancelled');
        final staged = store.scope('.staging');
        await validateLocalAsr(
          AsrModelStore(
            storage: staged,
            relativeDirectory: '$relativeDirectory/.staging',
          ),
        );
        if (cancel.isCancelled) throw const AsrFailure('cancelled');
        for (final file in files) {
          await store.move('.staging/${file.name}', file.name);
        }
        await store.write(
          'manifest.json',
          Uint8List.fromList(
            utf8.encode(
              jsonEncode({
                'id': id,
                'revision': revision,
                'license': 'Apache-2.0',
                'runtime': 'sherpa-onnx-1.13.8',
                'source': 'https://huggingface.co/csukuangfj/k2fsa-zipformer-bilingual-zh-en-t',
                'files': [
                  for (final file in files)
                    {
                      'name': file.name,
                      'bytes': file.bytes,
                      'sha256': file.sha256,
                    },
                ],
              }),
            ),
          ),
        );
        for (final file in await staged.files(includeTemporary: true)) {
          await staged.remove(file.path);
        }
      });
      if (!acquired) throw const AsrFailure('busy');
    } on DioException catch (error) {
      throw AsrFailure(
        CancelToken.isCancel(error) ? 'cancelled' : 'model_download',
      );
    } finally {
      dio.close();
    }
  }

  Future<void> verify() async {
    final store = await storage;
    if (!await isInstalled()) throw const AsrFailure('model_missing');
    for (final file in files) {
      final entries = await store.files();
      if (!entries.any(
            (entry) => entry.path == file.name && entry.bytes == file.bytes,
          ) ||
          (await sha256.bind(store.readStream(file.name)).first).toString() !=
              file.sha256) {
        throw const AsrFailure('model_checksum');
      }
    }
  }

  static Future<void> cleanupUnused() async {
    final root = await openAppDataDirectory('ai/models/$id');
    final versions = {
      for (final file in await root.files(includeTemporary: true))
        file.path.split('/').first,
    };
    for (final version in versions) {
      if (!RegExp(r'^[a-f0-9]{40}$').hasMatch(version)) {
        continue;
      }
      final directory = await openAppDataDirectory('ai/models/$id/$version');
      if (await modelUsedByCurrentProcess(directory)) continue;
      await directory.tryExclusive(() async {
        final stale = DateTime.now().subtract(const Duration(days: 7));
        for (final file in await directory.files(includeTemporary: true)) {
          if (version == revision &&
              (!file.path.startsWith('.staging/') ||
                  file.modifiedAt == null ||
                  !file.modifiedAt!.isBefore(stale))) {
            continue;
          }
          await directory.remove(file.path);
        }
      });
    }
  }

  Future<void> remove() async {
    final store = await storage;
    if (await modelUsedByCurrentProcess(store)) throw const AsrFailure('busy');
    final acquired = await store.tryExclusive(() async {
      await store.remove('manifest.json');
      for (final file in await store.files(includeTemporary: true)) {
        await store.remove(file.path);
      }
    });
    if (!acquired) throw const AsrFailure('busy');
  }
}
