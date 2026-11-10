import 'dart:io';
import 'dart:isolate';
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/core/storage/app_data_directory.dart';
import 'package:oronbox/src/core/storage/app_data_directory_io.dart';

Future<void> _holdStorage(List<Object> args) async {
  await IoAppDataDirectory(Directory(args[0] as String)).exclusive(() async {
    (args[1] as SendPort).send(true);
    await Completer<void>().future;
  });
}

void main() {
  late Directory root;
  late AppDataDirectory data;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('oronbox-stream-');
    data = IoAppDataDirectory(root);
  });
  tearDown(() => root.delete(recursive: true));

  test(
    'an exiting owner releases its descriptor and queued storage operations',
    () async {
      final ready = ReceivePort();
      final owner = await Isolate.spawn(_holdStorage, <Object>[
        root.path,
        ready.sendPort,
      ]);
      await ready.first;
      ready.close();
      owner.kill(priority: Isolate.immediate);
      await data
          .exclusive(() async {
            await data.write('recovered', Uint8List.fromList([1]));
          })
          .timeout(const Duration(seconds: 5));
      expect(await data.read('recovered'), [1]);
    },
  );
  test(
    'exclusive storage ownership spans isolates in the same process',
    () async {
      final path = root.path;
      await data.exclusive(() async {
        final acquired = await Isolate.run(
          () => IoAppDataDirectory(Directory(path)).tryExclusive(() async {}),
        );
        expect(acquired, isFalse);
      });
    },
  );
  test(
    'failed replacement preserves the published file and removes staging',
    () async {
      await data.write('model', Uint8List.fromList([9]));
      Stream<List<int>> broken() async* {
        yield [1, 2];
        throw StateError('interrupted');
      }

      await expectLater(data.writeStream('model', broken()), throwsStateError);
      expect(await data.read('model'), [9]);
      expect((await data.files(includeTemporary: true)).map((f) => f.path), [
        'model',
      ]);
    },
  );

  test(
    'interrupted append can resume and publish without loading the file',
    () async {
      final staging = data.scope('staging');
      Stream<List<int>> interrupted() async* {
        yield [1, 2];
        throw StateError('offline');
      }

      await expectLater(
        staging.writeStream('model.part', interrupted(), append: true),
        throwsStateError,
      );
      await staging.writeStream(
        'model.part',
        Stream.value([3, 4]),
        append: true,
      );
      expect(await staging.readStream('model.part').expand((x) => x).toList(), [
        1,
        2,
        3,
        4,
      ]);
      expect(await staging.files(), isEmpty);
      expect(
        (await staging.files(includeTemporary: true)).single.modifiedAt,
        isNotNull,
      );
      await data.move('staging/model.part', 'current/model');
      expect(await data.scope('current').read('model'), [1, 2, 3, 4]);
    },
  );

  test(
    'scoped operations reject traversal and never follow symbolic links',
    () async {
      expect(() => data.scope('../outside'), throwsFormatException);
      await Link('${root.path}/link').create(root.parent.path);
      await expectLater(
        data.writeStream('link/out', Stream.value([1])),
        throwsA(isA<FileSystemException>()),
      );
    },
  );
}
