import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class MemorySecureStorage extends FlutterSecureStorage {
  final values = <String, String>{};
  bool failWrites = false;
  String? failKey;
  bool mismatch = false;
  bool throwOnRead = false;
  int failReadCount = 0;

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (failReadCount > 0) {
      failReadCount--;
      throw StateError('Simulated KeyStore decryption failure');
    }
    if (throwOnRead) {
      throw StateError('Simulated KeyStore decryption failure');
    }
    return mismatch && values.containsKey(key) ? 'mismatch' : values[key];
  }
  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (failWrites || key == failKey) {
      throw StateError('Test storage unavailable');
    }
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    values.remove(key);
  }

  @override
  Future<void> deleteAll({
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    values.clear();
  }
}
