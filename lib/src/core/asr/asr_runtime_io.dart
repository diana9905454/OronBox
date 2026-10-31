import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:oronbox/src/core/network/app_http_transport.dart';
import 'package:oronbox/src/core/storage/app_data_directory.dart';
import 'package:path_provider/path_provider.dart';

import 'asr.dart';
import 'asr_model_download.dart';
import 'asr_runtime_spec.dart';

AsrRuntimeSpec get _spec => switch (Abi.current()) {
  Abi.androidArm64 => androidAsrRuntimes[0],
  Abi.androidArm => androidAsrRuntimes[1],
  Abi.androidX64 => androidAsrRuntimes[2],
  _ => throw const AsrFailure('unsupported'),
};
String get _relative =>
    'ai/runtimes/sherpa-onnx/${AsrRuntimeSpec.version}/${_spec.abi}';
Future<AppDataDirectory> _store() => openAppDataDirectory(_relative);

Future<bool> isAsrRuntimeInstalled() async {
  if (!Platform.isAndroid) return true;
  try {
    final store = await _store();
    final manifest = await store.read('manifest.json');
    if (manifest == null || utf8.decode(manifest) != AsrRuntimeSpec.version) {
      return false;
    }
    return await _verified(store, _spec);
  } on AsrFailure {
    return false;
  }
}

Future<bool> _verified(AppDataDirectory store, AsrRuntimeSpec spec) async {
  for (final file in spec.files) {
    final entries = await store.files();
    if (!entries.any((e) => e.path == file.name && e.bytes == file.bytes) ||
        (await sha256.bind(store.readStream(file.name)).first).toString() !=
            file.sha256) {
      return false;
    }
  }
  return true;
}

Future<void> installAsrRuntime({
  required CancelToken cancel,
  required void Function(int, int) onProgress,
}) async {
  if (!Platform.isAndroid) return;
  final spec = _spec;
  final store = await _store();
  final acquired = await store.tryExclusive(() async {
    if (await _verified(store, spec)) {
      await compute(
        _tryLoad,
        '${(await getApplicationSupportDirectory()).path}/$_relative',
      );
      await store.write(
        'manifest.json',
        Uint8List.fromList(utf8.encode(AsrRuntimeSpec.version)),
      );
      await _clearStaging(store);
      onProgress(spec.bytes, spec.bytes);
      return;
    }
    final staged = store.scope('.staging');
    final dio = createAppHttpTransport();
    try {
      await downloadModelFile(
        dio: dio,
        directory: staged,
        source: Uri.parse(
          'https://pub.dev/api/archives/${spec.package}-${AsrRuntimeSpec.version}.tar.gz',
        ),
        fallbackSource: Uri.parse(
          'https://pub.flutter-io.cn/api/archives/${spec.package}-${AsrRuntimeSpec.version}.tar.gz',
        ),
        name: 'runtime.tar.gz',
        bytes: spec.bytes,
        checksum: spec.sha256,
        cancel: cancel,
        onProgress: (n) => onProgress(n, spec.bytes),
      );
      if (cancel.isCancelled) throw const AsrFailure('cancelled');
      final files = await compute(
        extractAsrRuntimeArchive,
        (await staged.read('runtime.tar.gz'))!,
        debugLabel: 'ASR runtime extraction',
      );
      for (final file in spec.files) {
        final bytes = files['${spec.abi}/${file.name}'];
        if (bytes == null ||
            bytes.length != file.bytes ||
            sha256.convert(bytes).toString() != file.sha256) {
          throw const AsrFailure('model_checksum');
        }
        await staged.write(file.name, bytes);
      }
      if (cancel.isCancelled) throw const AsrFailure('cancelled');
      for (final file in spec.files) {
        await store.move('.staging/${file.name}', file.name);
      }
      final path =
          '${(await getApplicationSupportDirectory()).path}/$_relative';
      await compute(_tryLoad, path);
      await store.write(
        'manifest.json',
        Uint8List.fromList(utf8.encode(AsrRuntimeSpec.version)),
      );
      await _clearStaging(store);
    } finally {
      dio.close();
    }
  });
  if (!acquired) throw const AsrFailure('busy');
}

/// The entire pinned pub archive is verified before processing its members.
Map<String, Uint8List> extractAsrRuntimeArchive(Uint8List bytes) {
  final spec = androidAsrRuntimes
      .where(
        (s) =>
            s.bytes == bytes.length &&
            s.sha256 == sha256.convert(bytes).toString(),
      )
      .firstOrNull;
  if (spec == null) throw const AsrFailure('model_checksum');
  final archive = TarDecoder().decodeBytes(GZipDecoder().decodeBytes(bytes));
  final result = <String, Uint8List>{};
  for (final file in spec.files) {
    final name = 'android/src/main/jniLibs/${spec.abi}/${file.name}';
    final entries = archive.files.where((f) => f.name == name).toList();
    if (entries.length != 1 ||
        !entries.single.isFile ||
        entries.single.isSymbolicLink ||
        entries.single.size != file.bytes) {
      throw const AsrFailure('model_checksum');
    }
    final data = entries.single.content;
    if (sha256.convert(data).toString() != file.sha256) {
      throw const AsrFailure('model_checksum');
    }
    result['${spec.abi}/${file.name}'] = Uint8List.fromList(data);
  }
  return result;
}

void _tryLoad(String path) {
  try {
    DynamicLibrary.open('$path/libonnxruntime.so');
    DynamicLibrary.open('$path/libsherpa-onnx-c-api.so');
  } catch (_) {
    throw const AsrFailure('local_inference');
  }
}

Future<({String? path, Future<void> Function() release})>
acquireAsrRuntime() async {
  if (!Platform.isAndroid) return (path: null, release: () async {});
  final store = await _store();
  final ready = Completer<String>();
  final release = Completer<void>();
  final done = Completer<void>();
  unawaited(
    store
        .tryExclusive(() async {
          if (await store.read('manifest.json') == null ||
              !await _verified(store, _spec)) {
            throw const AsrFailure('model_missing');
          }
          ready.complete(
            '${(await getApplicationSupportDirectory()).path}/$_relative',
          );
          await release.future;
        })
        .then(
          (acquired) {
            if (!acquired && !ready.isCompleted) {
              ready.completeError(const AsrFailure('busy'));
            }
            done.complete();
          },
          onError: (Object e, StackTrace s) {
            if (!ready.isCompleted) ready.completeError(e, s);
            done.complete();
          },
        ),
  );
  return (
    path: await ready.future,
    release: () async {
      if (!release.isCompleted) release.complete();
      await done.future;
    },
  );
}

Future<void> removeAsrRuntime() async {
  if (!Platform.isAndroid) return;
  final store = await _store();
  if (!await store.tryExclusive(() async {
    for (final file in await store.files(includeTemporary: true)) {
      await store.remove(file.path);
    }
  })) {
    throw const AsrFailure('busy');
  }
}

int get asrRuntimeDownloadBytes => Platform.isAndroid ? _spec.bytes : 0;

Future<void> _clearStaging(AppDataDirectory store) async {
  final staged = store.scope('.staging');
  for (final file in await staged.files(includeTemporary: true)) {
    await staged.remove(file.path);
  }
}

Future<void> cleanupAsrRuntimes() async {
  if (!Platform.isAndroid) return;
  final root = await openAppDataDirectory('ai/runtimes/sherpa-onnx');
  final groups = <String>{};
  for (final file in await root.files(includeTemporary: true)) {
    final parts = file.path.split('/');
    if (parts.length >= 3 &&
        RegExp(r'^[0-9]+\.[0-9]+\.[0-9]+$').hasMatch(parts[0]) &&
        androidAsrRuntimes.any((s) => s.abi == parts[1])) {
      groups.add('${parts[0]}/${parts[1]}');
    }
  }
  final current = '${AsrRuntimeSpec.version}/${_spec.abi}';
  final expiry = DateTime.now().subtract(const Duration(days: 7));
  for (final group in groups) {
    final store = await openAppDataDirectory('ai/runtimes/sherpa-onnx/$group');
    await store.tryExclusive(() async {
      for (final file in await store.files(includeTemporary: true)) {
        if (group != current ||
            file.path.startsWith('.staging/') &&
                file.modifiedAt != null &&
                file.modifiedAt!.isBefore(expiry)) {
          await store.remove(file.path);
        }
      }
    });
  }
}
