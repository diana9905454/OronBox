import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefsService {
  SharedPrefsService._();

  static final SharedPrefsService _instance = SharedPrefsService._();
  static SharedPrefsService get instance => _instance;

  SharedPreferences? _prefs;

  bool get isInitialized => _prefs != null;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Refresh the in-memory cache from disk when another OronBox process may
  /// have changed preferences, such as the desktop daemon after OAuth.
  Future<void> reload() => _safePrefs.reload();

  SharedPreferences get _safePrefs {
    if (_prefs == null) {
      throw StateError(
        'SharedPrefsService not initialized. Call init() first.',
      );
    }
    return _prefs!;
  }

  Set<String> get keys => _safePrefs.getKeys();
  Object? value(String key) => _safePrefs.get(key);

  String? getString(String key) => _safePrefs.getString(key);
  Future<bool> setString(String key, String value) =>
      _safePrefs.setString(key, value);
  Future<bool> remove(String key) => _safePrefs.remove(key);

  bool? getBool(String key) => _safePrefs.getBool(key);
  Future<bool> setBool(String key, bool value) =>
      _safePrefs.setBool(key, value);

  int? getInt(String key) => _safePrefs.getInt(key);
  Future<bool> setInt(String key, int value) => _safePrefs.setInt(key, value);

  double? getDouble(String key) => _safePrefs.getDouble(key);
  Future<bool> setDouble(String key, double value) =>
      _safePrefs.setDouble(key, value);

  List<String>? getStringList(String key) => _safePrefs.getStringList(key);
  Future<bool> setStringList(String key, List<String> value) =>
      _safePrefs.setStringList(key, value);
}
