import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:oronbox/src/core/services/shared_prefs_service.dart';

import 'credential_lock_stub.dart'
    if (dart.library.io) 'credential_lock_io.dart'
    if (dart.library.js_interop) 'credential_lock_web.dart'
    as platform;

/// Native credentials use the system keyring. A single protected record keeps
/// the OronBox session and BandBBS read token together during account switches.
class OAuthCredentialStore {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: false),
    mOptions: MacOsOptions(usesDataProtectionKeychain: false),
  );
  static const _bundleKey = 'oronbox.oauth.credentials';
  static const sessionKey = 'oronbox.session.token';
  static const readTokenKey = 'bandbbs.oauth.token';
  static Future<void> _tail = Future.value();

  static Future<T> locked<T>(Future<T> Function() action) async {
    final previous = _tail;
    final done = Completer<void>();
    _tail = done.future;
    await previous;
    try {
      return await platform.withPlatformCredentialLock(action);
    } finally {
      done.complete();
    }
  }

  // Callers hold the process/tab lock for each read-modify-write transaction.
  static Future<Map<String, dynamic>> _bundle() async {
    final raw = await _storage.read(key: _bundleKey);
    if (raw != null) {
      final prefs = SharedPrefsService.instance;
      if (prefs.isInitialized) {
        for (final key in [sessionKey, readTokenKey]) {
          if (prefs.getString(key) != null) await prefs.remove(key);
        }
      }
      return (jsonDecode(raw) as Map).cast<String, dynamic>();
    }
    final prefs = SharedPrefsService.instance;
    if (prefs.isInitialized) await prefs.reload();
    final values = <String, dynamic>{};
    for (final key in [sessionKey, readTokenKey]) {
      final value =
          await _storage.read(key: key) ??
          (prefs.isInitialized ? prefs.getString(key) : null);
      if (value != null) values[key] = value;
    }
    await _storage.write(key: _bundleKey, value: jsonEncode(values));
    // Never remove the legacy copy before the protected record is durable.
    for (final key in [sessionKey, readTokenKey]) {
      await _storage.delete(key: key);
      if (prefs.isInitialized) await prefs.remove(key);
    }
    return values;
  }

  static Future<String?> read(String key) async =>
      (await _bundle())[key] as String?;

  static Future<void> write(String key, String value) async {
    final values = await _bundle();
    values[key] = value;
    await _storage.write(key: _bundleKey, value: jsonEncode(values));
  }

  static Future<void> writePair(String session, String? readToken) async {
    await _bundle();
    await _storage.write(
      key: _bundleKey,
      value: jsonEncode({
        sessionKey: session,
        if (readToken != null) readTokenKey: readToken,
      }),
    );
  }

  static Future<void> remove(String key) async {
    final values = await _bundle();
    values.remove(key);
    await _storage.write(key: _bundleKey, value: jsonEncode(values));
  }

  static Future<void> clear() async {
    await _bundle();
    await _storage.write(key: _bundleKey, value: '{}');
  }
}
