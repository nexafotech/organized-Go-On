import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:attendance_marker_mobile/core/theme/app_theme.dart';
import 'package:attendance_marker_mobile/core/theme/theme_service.dart';
import 'package:attendance_marker_mobile/core/storage/app_preferences.dart';
import 'package:attendance_marker_mobile/widgets/common/app_scaffold.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Theme Consistency & Instant Switching Tests', () {
    testWidgets('1. Cold launch with light theme saved renders light canvas without black flash', (tester) async {
      SharedPreferences.setMockInitialValues({'pref_theme_mode': 'light'});
      final prefs = AppPreferencesService();
      final saved = await prefs.getThemeMode();
      expect(saved, equals('light'));

      final themeService = ThemeService(prefs: prefs, initialThemeMode: ThemeMode.light);

      await tester.pumpWidget(
        ChangeNotifierProvider<ThemeService>.value(
          value: themeService,
          child: Consumer<ThemeService>(
            builder: (context, ts, _) {
              final isDark = ts.isDarkMode;
              return MaterialApp(
                theme: AppTheme.lightTheme,
                darkTheme: AppTheme.darkTheme,
                themeMode: ts.themeMode,
                color: isDark ? AppColors.dark.background : AppColors.light.background,
                themeAnimationDuration: Duration.zero,
                home: const AppScaffold(
                  body: Center(child: Text('Content')),
                ),
              );
            },
          ),
        ),
      );

      // Verify immediate light background
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, equals(AppColors.light.background));

      // Verify AnnotatedRegion SystemUiOverlayStyle matches light theme
      final annotatedRegion = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
      );
      expect(annotatedRegion.value.systemNavigationBarColor, equals(AppColors.light.background));
      expect(annotatedRegion.value.statusBarIconBrightness, equals(Brightness.dark));
    });

    testWidgets('2. Cold launch with dark theme saved renders dark canvas immediately', (tester) async {
      SharedPreferences.setMockInitialValues({'pref_theme_mode': 'dark'});
      final prefs = AppPreferencesService();
      final saved = await prefs.getThemeMode();
      expect(saved, equals('dark'));

      final themeService = ThemeService(prefs: prefs, initialThemeMode: ThemeMode.dark);

      await tester.pumpWidget(
        ChangeNotifierProvider<ThemeService>.value(
          value: themeService,
          child: Consumer<ThemeService>(
            builder: (context, ts, _) {
              final isDark = ts.isDarkMode;
              return MaterialApp(
                theme: AppTheme.lightTheme,
                darkTheme: AppTheme.darkTheme,
                themeMode: ts.themeMode,
                color: isDark ? AppColors.dark.background : AppColors.light.background,
                themeAnimationDuration: Duration.zero,
                home: const AppScaffold(
                  body: Center(child: Text('Content')),
                ),
              );
            },
          ),
        ),
      );

      // Verify immediate dark background
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, equals(AppColors.dark.background));

      // Verify AnnotatedRegion SystemUiOverlayStyle matches dark theme
      final annotatedRegion = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
      );
      expect(annotatedRegion.value.systemNavigationBarColor, equals(AppColors.dark.background));
      expect(annotatedRegion.value.statusBarIconBrightness, equals(Brightness.light));
    });

    testWidgets('3. Rapid repeated light-to-dark-to-light switching updates atomically in 1 frame', (tester) async {
      final themeService = ThemeService(initialThemeMode: ThemeMode.light);

      await tester.pumpWidget(
        ChangeNotifierProvider<ThemeService>.value(
          value: themeService,
          child: Consumer<ThemeService>(
            builder: (context, ts, _) {
              final isDark = ts.isDarkMode;
              return MaterialApp(
                theme: AppTheme.lightTheme,
                darkTheme: AppTheme.darkTheme,
                themeMode: ts.themeMode,
                color: isDark ? AppColors.dark.background : AppColors.light.background,
                themeAnimationDuration: Duration.zero,
                home: const AppScaffold(
                  body: Center(child: Text('Content')),
                ),
              );
            },
          ),
        ),
      );

      expect(tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor, equals(AppColors.light.background));

      // Switch to Dark
      await themeService.setThemeMode(ThemeMode.dark);
      await tester.pump(); // Exactly 1 frame
      expect(tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor, equals(AppColors.dark.background));

      // Switch back to Light
      await themeService.setThemeMode(ThemeMode.light);
      await tester.pump(); // Exactly 1 frame
      expect(tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor, equals(AppColors.light.background));

      // Switch to Dark again
      await themeService.setThemeMode(ThemeMode.dark);
      await tester.pump(); // Exactly 1 frame
      expect(tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor, equals(AppColors.dark.background));
    });

    testWidgets('4. Form inputs and scroll positions are fully preserved when switching themes', (tester) async {
      final themeService = ThemeService(initialThemeMode: ThemeMode.light);
      final scrollController = ScrollController();
      final textController = TextEditingController(text: 'Initial Input');

      await tester.pumpWidget(
        ChangeNotifierProvider<ThemeService>.value(
          value: themeService,
          child: Consumer<ThemeService>(
            builder: (context, ts, _) {
              final isDark = ts.isDarkMode;
              return MaterialApp(
                theme: AppTheme.lightTheme,
                darkTheme: AppTheme.darkTheme,
                themeMode: ts.themeMode,
                color: isDark ? AppColors.dark.background : AppColors.light.background,
                themeAnimationDuration: Duration.zero,
                home: Scaffold(
                  body: ListView(
                    controller: scrollController,
                    children: [
                      TextField(controller: textController),
                      const SizedBox(height: 1000),
                      const Text('Bottom Item'),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      );

      // Scroll down
      scrollController.jumpTo(400);
      await tester.pump();
      expect(scrollController.offset, equals(400));

      // Type into text field
      textController.text = 'Modified User Input';
      await tester.pump();

      // Switch theme to Dark
      await themeService.setThemeMode(ThemeMode.dark);
      await tester.pump();

      // Verify scroll offset and text input are preserved
      expect(scrollController.offset, equals(400));
      expect(textController.text, equals('Modified User Input'));
    });

    test('5. AppTheme lightTheme and darkTheme define systemOverlayStyle on AppBarTheme', () {
      final lightOverlay = AppTheme.lightTheme.appBarTheme.systemOverlayStyle;
      expect(lightOverlay, isNotNull);
      expect(lightOverlay!.statusBarIconBrightness, equals(Brightness.dark));
      expect(lightOverlay.systemNavigationBarColor, equals(const Color(0xFFF6F1EA)));

      final darkOverlay = AppTheme.darkTheme.appBarTheme.systemOverlayStyle;
      expect(darkOverlay, isNotNull);
      expect(darkOverlay!.statusBarIconBrightness, equals(Brightness.light));
      expect(darkOverlay.systemNavigationBarColor, equals(const Color(0xFF0D0C13)));
    });

    test('6. AppTheme lightTheme and darkTheme define explicit canvasColor matching background', () {
      expect(AppTheme.lightTheme.canvasColor, equals(AppColors.light.background));
      expect(AppTheme.darkTheme.canvasColor, equals(AppColors.dark.background));
    });
  });
}
