import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

Future<int?> availableStorageBytes() async {
  try {
    final estimate = await web.window.navigator.storage.estimate().toDart;
    final rawQuota = estimate.getProperty<JSAny?>('quota'.toJS);
    final rawUsage = estimate.getProperty<JSAny?>('usage'.toJS);
    if (rawQuota.isUndefinedOrNull || rawUsage.isUndefinedOrNull) return null;
    final quota = (rawQuota as JSNumber).toDartDouble;
    final usage = (rawUsage as JSNumber).toDartDouble;
    return (quota - usage).clamp(0, quota).toInt();
  } catch (_) {
    return null;
  }
}
