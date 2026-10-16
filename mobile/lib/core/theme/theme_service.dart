import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../storage/app_preferences.dart';

class ThemeService extends ChangeNotifier {
  final AppPreferencesService _prefs;
  ThemeMode _themeMode;

  ThemeService({AppPreferencesService? prefs, ThemeMode initialThemeMode = ThemeMode.light})
      : _prefs = prefs ?? AppPreferencesService(),
        _themeMode = (initialThemeMode == ThemeMode.dark) ? ThemeMode.dark : ThemeMode.light {
    _loadTheme();
  }

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  Future<void> _loadTheme() async {
    try {
      final saved = await _prefs.getThemeMode();
      if (saved != null) {
        final targetMode = (saved == 'dark') ? ThemeMode.dark : ThemeMode.light;
        if (_themeMode != targetMode) {
          _themeMode = targetMode;
          notifyListeners();
        }
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

  static const ThemeMode themeModeDark = ThemeMode.dark;
  static const ThemeMode themeModeLight = ThemeMode.light;

  Future<void> setThemeMode(ThemeMode mode) async {
    final targetMode = (mode == ThemeMode.dark) ? ThemeMode.dark : ThemeMode.light;
    if (_themeMode == targetMode) return;
    _themeMode = targetMode;
    notifyListeners();
    try {
      await _prefs.saveThemeMode(targetMode == ThemeMode.dark ? 'dark' : 'light');
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

  static final ThemeService _fallback = ThemeService(initialThemeMode: ThemeMode.light);
  static ThemeMode get fallbackThemeMode => _fallback.themeMode;

  @override
  Widget build(BuildContext context) {
    ThemeService? service;
    try {
      service = Provider.of<ThemeService>(context, listen: true);
    } catch (_) {
      service = null;
    }
    return builder(context, service ?? _fallback, child);
  }
}
