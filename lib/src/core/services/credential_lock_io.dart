import 'dart:io';

import 'package:path_provider/path_provider.dart';

Future<T> withPlatformCredentialLock<T>(Future<T> Function() action) async {
  final directory = await getApplicationSupportDirectory();
  await directory.create(recursive: true);
  final lock = await File('${directory.path}/oauth.lock')
      .open(mode: FileMode.append);
  try {
    await lock.lock(FileLock.blockingExclusive);
    try {
      return await action();
    } finally {
      await lock.unlock();
    }
  } finally {
    await lock.close();
  }
}
