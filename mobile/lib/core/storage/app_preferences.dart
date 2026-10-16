import 'package:shared_preferences/shared_preferences.dart';

class AppPreferencesService {
  static const String _keySelectedRoleTab = 'pref_selected_role_tab';
  static const String _keyCustomBackendUrl = 'pref_custom_backend_url';
  static const String _keyThemeMode = 'pref_theme_mode';

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
}
