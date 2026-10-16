import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/user_model.dart';

class AppPreferencesService {
  static const String _keySelectedRoleTab = 'pref_selected_role_tab';
  static const String _keyCustomBackendUrl = 'pref_custom_backend_url';
  static const String _keyThemeMode = 'pref_theme_mode';
  static const String _keyCachedUser = 'pref_cached_user';

  Future<void> saveThemeMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    // Strictly sanitize to 'dark' or 'light'
    final sanitized = (mode == 'dark') ? 'dark' : 'light';
    await prefs.setString(_keyThemeMode, sanitized);
  }

  Future<String?> getThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyThemeMode);
    } catch (_) {
      return null;
    }
  }

  Future<String> getThemeModeWithDefault() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mode = prefs.getString(_keyThemeMode);
      if (mode == 'dark') return 'dark';
      return 'light';
    } catch (_) {
      return 'light';
    }
  }

  Future<void> saveSelectedRoleTab(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySelectedRoleTab, role);
  }

  Future<String?> getSelectedRoleTab() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySelectedRoleTab);
  }

  Future<void> saveCustomBackendUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCustomBackendUrl, url);
  }

  Future<String?> getCustomBackendUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyCustomBackendUrl);
  }

  Future<void> saveCachedUser(UserModel user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyCachedUser, jsonEncode(user.toJson()));
    } catch (_) {}
  }

  Future<UserModel?> getCachedUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_keyCachedUser);
      if (str == null || str.isEmpty) return null;
      return UserModel.fromJson(jsonDecode(str) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearCachedUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyCachedUser);
    } catch (_) {}
  }
}
