import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
import 'package:web/web.dart' as web;

QueryExecutor openHealthDatabase() => LazyDatabase(() async {
  final base = Uri.parse(web.document.baseURI);
  final opened = await WasmDatabase.open(
    databaseName: 'oronbox-health',
    sqlite3Uri: base.resolve('sqlite3.wasm'),
    driftWorkerUri: base.resolve('drift_worker.js'),
  );
  return opened.resolvedExecutor;
});
