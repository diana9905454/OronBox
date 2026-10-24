import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';

QueryExecutor openHealthDatabase() => LazyDatabase(() async {
  final root = Directory(
    '${(await getApplicationSupportDirectory()).path}/health',
  );
  await root.create(recursive: true);
  return NativeDatabase.createInBackground(File('${root.path}/health.sqlite'));
});
