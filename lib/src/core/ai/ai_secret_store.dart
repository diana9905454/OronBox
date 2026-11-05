import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AiSecretStore {
  static const instance = AiSecretStore();

  const AiSecretStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(resetOnError: false),
            mOptions: MacOsOptions(usesDataProtectionKeychain: false),
          );

  final FlutterSecureStorage _storage;

  static const _prefix = 'oronbox.ai.key.';

  Future<void> saveApiKey(String credentialRef, String apiKey) async {
    final trimmed = apiKey.trim();
    if (trimmed.isEmpty) {
      await deleteApiKey(credentialRef);
      return;
    }
    await _storage.write(key: '$_prefix$credentialRef', value: trimmed);
  }

  Future<String?> getApiKey(String credentialRef) async {
    if (credentialRef.isEmpty) return null;
    return await _storage.read(key: '$_prefix$credentialRef');
  }

  Future<void> deleteApiKey(String credentialRef) async {
    if (credentialRef.isEmpty) return;
    await _storage.delete(key: '$_prefix$credentialRef');
  }
}
