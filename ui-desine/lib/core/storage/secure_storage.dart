import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  final FlutterSecureStorage _storage;

  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const String _keyAccessToken = 'auth_access_token';

  /// Saves access token securely
  Future<void> saveAccessToken(String token) async {
    await _storage.write(key: _keyAccessToken, value: token);
  }

  /// Reads access token securely
  Future<String?> getAccessToken() async {
    return await _storage.read(key: _keyAccessToken);
  }

  /// Deletes access token securely
  Future<void> deleteAccessToken() async {
    await _storage.delete(key: _keyAccessToken);
  }

  /// Clears all secure session information
  Future<void> clearSession() async {
    await _storage.deleteAll();
  }
}
