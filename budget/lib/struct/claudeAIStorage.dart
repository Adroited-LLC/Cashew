import 'package:budget/struct/databaseGlobal.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores the Claude API key.
/// On mobile/desktop: flutter_secure_storage (encrypted).
/// On web: SharedPreferences / localStorage (acceptable for single-user local app).
class ClaudeAIStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    lOptions: LinuxOptions(),
  );
  static const _apiKeyKey = 'claude_api_key';

  static Future<void> saveApiKey(String key) async {
    if (kIsWeb) {
      await sharedPreferences.setString(_apiKeyKey, key);
    } else {
      await _storage.write(key: _apiKeyKey, value: key);
    }
  }

  static Future<String?> getApiKey() async {
    if (kIsWeb) {
      return sharedPreferences.getString(_apiKeyKey);
    }
    return await _storage.read(key: _apiKeyKey);
  }

  static Future<void> clearApiKey() async {
    if (kIsWeb) {
      await sharedPreferences.remove(_apiKeyKey);
    } else {
      await _storage.delete(key: _apiKeyKey);
    }
  }
}
