import 'package:flutter/material.dart';
import '../storage/app_preferences.dart';

class ThemeService extends ChangeNotifier {
  final AppPreferencesService _prefs;
  ThemeMode _themeMode = ThemeMode.light;

  ThemeService({AppPreferencesService? prefs})
      : _prefs = prefs ?? AppPreferencesService() {
    _loadTheme();
  }

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  Future<void> _loadTheme() async {
    try {
      final saved = await _prefs.getThemeMode();
      if (saved != null) {
        if (saved == 'dark') {
          _themeMode = ThemeMode.dark;
        } else if (saved == 'light') {
          _themeMode = ThemeMode.light;
        } else {
          _themeMode = ThemeMode.system;
        }
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> toggleTheme() async {
    if (_themeMode == ThemeMode.dark) {
      await setThemeMode(ThemeMode.light);
    } else {
      await setThemeMode(ThemeMode.dark);
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    try {
      await _prefs.saveThemeMode(
        mode == ThemeMode.dark
            ? 'dark'
            : (mode == ThemeMode.light ? 'light' : 'system'),
      );
    } catch (_) {}
  }
}
