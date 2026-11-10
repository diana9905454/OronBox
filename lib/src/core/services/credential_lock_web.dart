import 'dart:js_interop';

import 'package:web/web.dart' as web;

Future<T> withPlatformCredentialLock<T>(Future<T> Function() action) async {
  late T result;
  final callback = ((JSAny? _) => (() async {
    result = await action();
    return null;
  })().toJS).toJS;
  await web.window.navigator.locks.request('oronbox-oauth', callback).toDart;
  return result;
}
