import 'package:oronbox/src/core/storage/app_data_directory.dart';

import 'dart:async';

import 'asr.dart';
import 'asr_model_store.dart';
import 'local_asr_stub.dart'
    if (dart.library.io) 'local_asr_io.dart'
    if (dart.library.js_interop) 'local_asr_web.dart'
    as platform;

Future<AsrEngine> openLocalAsr(AsrModelStore model) async {
  if (await platform.modelUsedByCurrentProcess(await model.storage)) {
    throw const AsrFailure('busy');
  }
  final opened = Completer<AsrEngine>();
  final released = Completer<void>();
  final unlocked = Completer<void>();
  unawaited(
    (await model.storage)
        .tryExclusive(() async {
          await model.verify();
          final engine = await platform.openLocalAsr(model);
          opened.complete(_LeasedAsrEngine(engine, released, unlocked.future));
          await released.future;
        })
        .then(
          (acquired) {
            if (!acquired && !opened.isCompleted) {
              opened.completeError(const AsrFailure('busy'));
            }
            unlocked.complete();
          },
          onError: (Object error, StackTrace stack) {
            if (!opened.isCompleted) opened.completeError(error, stack);
            if (!unlocked.isCompleted) unlocked.complete();
          },
        ),
  );
  return opened.future;
}

class _LeasedAsrEngine implements AsrEngine {
  _LeasedAsrEngine(this.engine, this.release, this.unlocked);
  final AsrEngine engine;
  final Completer<void> release;
  final Future<void> unlocked;
  @override
  Future<AsrSession> start() => engine.start();
  @override
  Future<void> dispose() async {
    try {
      await engine.dispose();
    } finally {
      if (!release.isCompleted) release.complete();
      await unlocked;
    }
  }
}

Future<void> validateLocalAsr(AsrModelStore model) async {
  final engine = await platform.openLocalAsr(model);
  try {
    final session = await engine.start();
    await session.cancel();
  } finally {
    await engine.dispose();
  }
}

Future<bool> modelUsedByCurrentProcess(AppDataDirectory directory) =>
    platform.modelUsedByCurrentProcess(directory);
