import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
    if (_themeMode == themeModeDark) {
      await setThemeMode(ThemeMode.light);
    } else {
      await setThemeMode(ThemeMode.dark);
    }
  }

  static const ThemeMode themeModeDark = ThemeMode.dark;

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

/// A defensive theme consumer that gracefully falls back to a default
/// [ThemeService] if no Provider<ThemeService> is present in the widget tree
/// (e.g. during isolated widget tests).
class SafeThemeConsumer extends StatelessWidget {
  final Widget Function(BuildContext context, ThemeService themeService, Widget? child) builder;
  final Widget? child;

  const SafeThemeConsumer({super.key, required this.builder, this.child});

  static final ThemeService _fallback = ThemeService();

  @override
  Widget build(BuildContext context) {
    ThemeService? service;
    try {
      service = Provider.of<ThemeService>(context);
    } catch (_) {
      service = null;
    }
    return builder(context, service ?? _fallback, child);
  }
}

