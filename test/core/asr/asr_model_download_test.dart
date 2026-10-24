import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/core/asr/asr.dart';
import 'package:oronbox/src/core/asr/asr_model_download.dart';
import 'package:oronbox/src/core/storage/app_data_directory_io.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);
  final Future<ResponseBody> Function(RequestOptions) respond;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => respond(options);
  @override
  void close({bool force = false}) {}
}

void main() {
  late Directory root;
  late IoAppDataDirectory store;
  late Dio dio;
  final source = Uri.parse('https://example.invalid/pinned/model');
  final checksum = sha256.convert([1, 2, 3, 4]).toString();
  setUp(() async {
    root = await Directory.systemTemp.createTemp('oronbox-model-');
    store = IoAppDataDirectory(root);
    dio = Dio();
  });
  tearDown(() async {
    dio.close();
    await root.delete(recursive: true);
  });
  Future<void> download() => downloadModelFile(
    dio: dio,
    directory: store,
    source: source,
    name: 'model',
    bytes: 4,
    checksum: checksum,
    cancel: CancelToken(),
    onProgress: (_) {},
  );
  Future<void> partial() async {
    await store.write('model.part', Uint8List.fromList([1, 2]));
    await store.write(
      'model.resume.json',
      Uint8List.fromList(
        utf8.encode(jsonEncode({'source': source.toString(), 'etag': '"v1"'})),
      ),
    );
  }

  test(
    'uses the mirror after primary failure without mixing partial sources',
    () async {
      await partial();
      final mirror = Uri.parse('https://mirror.invalid/pinned/model');
      final requested = <Uri>[];
      dio.httpClientAdapter = _Adapter((options) async {
        requested.add(options.uri);
        if (options.uri == source) {
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
          );
        }
        expect(options.headers['Range'], isNull);
        return ResponseBody.fromBytes([1, 2, 3, 4], 200);
      });
      await downloadModelFile(
        dio: dio,
        directory: store,
        source: source,
        fallbackSource: mirror,
        name: 'model',
        bytes: 4,
        checksum: checksum,
        cancel: CancelToken(),
        onProgress: (_) {},
      );
      expect(requested, [source, mirror]);
      expect(await store.read('model'), [1, 2, 3, 4]);
    },
  );
  test('does not contact mirror after success or cancellation', () async {
    final mirror = Uri.parse('https://mirror.invalid/pinned/model');
    final requested = <Uri>[];
    dio.httpClientAdapter = _Adapter((options) async {
      requested.add(options.uri);
      return ResponseBody.fromBytes([1, 2, 3, 4], 200);
    });
    Future<void> attempt(CancelToken token) => downloadModelFile(
      dio: dio,
      directory: store,
      source: source,
      fallbackSource: mirror,
      name: 'model',
      bytes: 4,
      checksum: checksum,
      cancel: token,
      onProgress: (_) {},
    );
    await attempt(CancelToken());
    expect(requested, [source]);
    await store.remove('model');
    final token = CancelToken()..cancel();
    await expectLater(attempt(token), throwsA(isA<DioException>()));
    expect(requested, [source]);
  });

  test(
    'retains mirror partial when primary fails before returning headers',
    () async {
      final mirror = Uri.parse('https://mirror.invalid/pinned/model');
      await store.write('model.part', Uint8List.fromList([1, 2]));
      await store.write(
        'model.resume.json',
        Uint8List.fromList(
          utf8.encode(
            jsonEncode({'source': mirror.toString(), 'etag': '"m1"'}),
          ),
        ),
      );
      dio.httpClientAdapter = _Adapter((options) async {
        if (options.uri == source)
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
          );
        expect(options.headers['Range'], 'bytes=2-');
        expect(options.headers['If-Range'], '"m1"');
        return ResponseBody.fromBytes(
          [3, 4],
          206,
          headers: {
            'content-range': ['bytes 2-3/4'],
            'etag': ['"m1"'],
          },
        );
      });
      await downloadModelFile(
        dio: dio,
        directory: store,
        source: source,
        fallbackSource: mirror,
        name: 'model',
        bytes: 4,
        checksum: checksum,
        cancel: CancelToken(),
        onProgress: (_) {},
      );
      expect(await store.read('model'), [1, 2, 3, 4]);
    },
  );
  test(
    'a verified staged file is reused without another network request',
    () async {
      await store.write('model', Uint8List.fromList([1, 2, 3, 4]));
      dio.httpClientAdapter = _Adapter(
        (_) async => throw StateError('unexpected network'),
      );
      await download();
      expect(await store.read('model'), [1, 2, 3, 4]);
    },
  );
  test(
    'resumes the exact range and removes resume metadata after hash validation',
    () async {
      await partial();
      dio.httpClientAdapter = _Adapter((request) async {
        expect(request.headers['Range'], 'bytes=2-');
        expect(request.headers['If-Range'], '"v1"');
        return ResponseBody.fromBytes(
          [3, 4],
          206,
          headers: {
            'content-range': ['bytes 2-3/4'],
            'etag': ['"v1"'],
          },
        );
      });
      await download();
      expect(await store.read('model'), [1, 2, 3, 4]);
      expect((await store.files(includeTemporary: true)).map((e) => e.path), [
        'model',
      ]);
    },
  );
  test(
    'a server ignoring Range restarts rather than appending duplicate bytes',
    () async {
      await partial();
      dio.httpClientAdapter = _Adapter(
        (_) async => ResponseBody.fromBytes([1, 2, 3, 4], 200),
      );
      await download();
      expect(await store.read('model'), [1, 2, 3, 4]);
    },
  );
  test('wrong range cannot overwrite an existing published file', () async {
    await partial();
    await store.write('model', Uint8List.fromList([9]));
    dio.httpClientAdapter = _Adapter(
      (_) async => ResponseBody.fromBytes(
        [3, 4],
        206,
        headers: {
          'content-range': ['bytes 1-3/4'],
          'etag': ['"v1"'],
        },
      ),
    );
    await expectLater(download(), throwsA(isA<AsrFailure>()));
    expect(await store.read('model'), [9]);
    expect(await store.read('model.part'), [1, 2]);
  });
  test('checksum mismatch removes the poisoned partial but preserves published file', () async {
    await store.write('model', Uint8List.fromList([9]));
    dio.httpClientAdapter = _Adapter(
      (_) async => ResponseBody.fromBytes([4, 3, 2, 1], 200),
    );
    await expectLater(download(), throwsA(isA<AsrFailure>()));
    expect(await store.read('model'), [9]);
    expect(await store.read('model.part'), isNull);
  });
}
