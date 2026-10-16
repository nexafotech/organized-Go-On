import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:attendance_marker_mobile/core/theme/theme_service.dart';
import 'package:attendance_marker_mobile/core/theme/app_theme.dart';
import 'package:attendance_marker_mobile/core/storage/app_preferences.dart';
import 'package:attendance_marker_mobile/auth/screens/splash_screen.dart';
import 'package:attendance_marker_mobile/services/auth_service.dart';
import 'package:attendance_marker_mobile/services/student_service.dart';
import 'package:attendance_marker_mobile/services/faculty_service.dart';
import 'package:attendance_marker_mobile/services/admin_service.dart';
import 'package:attendance_marker_mobile/services/biometric_enrollment_service.dart';
import 'package:attendance_marker_mobile/services/notification_service.dart';
import 'package:attendance_marker_mobile/models/user_model.dart';
import 'package:attendance_marker_mobile/widgets/common/go_on_brand.dart';

class MockFailingPreferencesService extends AppPreferencesService {
  @override
  Future<String?> getThemeMode() async {
    throw Exception('Simulated disk I/O failure');
  }

  @override
  Future<void> saveThemeMode(String mode) async {
    throw Exception('Simulated disk write failure');
  }
}

class FakeAuthService extends ChangeNotifier implements AuthService {
  UserModel? _user;
  @override
  UserModel? get currentUser => _user;
  @override
  bool get isAuthenticated => _user != null;
  @override
  bool get isLoading => false;
  @override
  String? get errorMessage => null;
  @override
  bool get sessionExpired => false;
  @override
  bool get isNetworkError => false;

  @override
  Future<UserModel?> restoreSession() async => _user;
  @override
  Future<bool> hasStoredToken() async => _user != null;
  @override
  void clearErrorMessage() {}
  @override
  void clearSessionExpired() {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('1. Authoritative Theme State & Fresh Installation Default', () {
    test('A fresh installation with no saved preference defaults to ThemeMode.light', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = AppPreferencesService();
      final saved = await prefs.getThemeMode();
      expect(saved, isNull);

      final themeService = ThemeService(prefs: prefs);
      expect(themeService.themeMode, equals(ThemeMode.light));
      expect(themeService.isDarkMode, isFalse);
    });

    test('getThemeModeWithDefault returns "light" when no preference exists', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = AppPreferencesService();
      final mode = await prefs.getThemeModeWithDefault();
      expect(mode, equals('light'));
    });

    test('ThemeService only allows ThemeMode.light or ThemeMode.dark', () async {
      final themeService = ThemeService(initialThemeMode: ThemeMode.system);
      // System mode is sanitized to light mode
      expect(themeService.themeMode, equals(ThemeMode.light));
    });
  });

  group('2. Theme Persistence Across Selection & Restarts', () {
    test('Selecting dark theme updates ThemeService and persists "dark"', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = AppPreferencesService();
      final themeService = ThemeService(prefs: prefs, initialThemeMode: ThemeMode.light);

      await themeService.setThemeMode(ThemeMode.dark);
      expect(themeService.themeMode, equals(ThemeMode.dark));
      expect(themeService.isDarkMode, isTrue);

      final saved = await prefs.getThemeMode();
      expect(saved, equals('dark'));
    });

    test('Dark theme preference survives simulated app restart', () async {
      SharedPreferences.setMockInitialValues({'pref_theme_mode': 'dark'});
      final prefs = AppPreferencesService();
      final saved = await prefs.getThemeMode();
      expect(saved, equals('dark'));

      final restoredMode = (saved == 'dark') ? ThemeMode.dark : ThemeMode.light;
      final themeService = ThemeService(prefs: prefs, initialThemeMode: restoredMode);
      expect(themeService.themeMode, equals(ThemeMode.dark));
      expect(themeService.isDarkMode, isTrue);
    });

    test('Selecting light theme updates ThemeService and persists "light"', () async {
      SharedPreferences.setMockInitialValues({'pref_theme_mode': 'dark'});
      final prefs = AppPreferencesService();
      final themeService = ThemeService(prefs: prefs, initialThemeMode: ThemeMode.dark);

      await themeService.setThemeMode(ThemeMode.light);
      expect(themeService.themeMode, equals(ThemeMode.light));
      expect(themeService.isDarkMode, isFalse);

      final saved = await prefs.getThemeMode();
      expect(saved, equals('light'));
    });

    test('Light theme preference survives simulated app restart', () async {
      SharedPreferences.setMockInitialValues({'pref_theme_mode': 'light'});
      final prefs = AppPreferencesService();
      final saved = await prefs.getThemeMode();
      expect(saved, equals('light'));

      final restoredMode = (saved == 'dark') ? ThemeMode.dark : ThemeMode.light;
      final themeService = ThemeService(prefs: prefs, initialThemeMode: restoredMode);
      expect(themeService.themeMode, equals(ThemeMode.light));
      expect(themeService.isDarkMode, isFalse);
    });

    test('toggleTheme alternates between light and dark and persists each state', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = AppPreferencesService();
      final themeService = ThemeService(prefs: prefs, initialThemeMode: ThemeMode.light);

      await themeService.toggleTheme();
      expect(themeService.themeMode, equals(ThemeMode.dark));
      expect(await prefs.getThemeMode(), equals('dark'));

      await themeService.toggleTheme();
      expect(themeService.themeMode, equals(ThemeMode.light));
      expect(await prefs.getThemeMode(), equals('light'));
    });
  });

  group('3. System Appearance Independence (Test D)', () {
    testWidgets('System brightness changes do NOT override explicit light theme', (tester) async {
      SharedPreferences.setMockInitialValues({'pref_theme_mode': 'light'});
      final themeService = ThemeService(initialThemeMode: ThemeMode.light);

      await tester.pumpWidget(
        ChangeNotifierProvider<ThemeService>.value(
          value: themeService,
          child: Consumer<ThemeService>(
            builder: (context, ts, _) {
              return MaterialApp(
                theme: AppTheme.lightTheme,
                darkTheme: AppTheme.darkTheme,
                themeMode: ts.themeMode,
                home: Builder(
                  builder: (ctx) {
                    final isDark = Theme.of(ctx).brightness == Brightness.dark;
                    return Text('Brightness: ${isDark ? "DARK" : "LIGHT"}');
                  },
                ),
              );
            },
          ),
        ),
      );

      expect(find.text('Brightness: LIGHT'), findsOneWidget);

      // Simulate Android OS switching to Dark Mode
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pumpAndSettle();

      // App MUST stay in explicit LIGHT theme
      expect(themeService.themeMode, equals(ThemeMode.light));
      expect(find.text('Brightness: LIGHT'), findsOneWidget);

      // Reset
      tester.platformDispatcher.clearPlatformBrightnessTestValue();
    });

    testWidgets('System brightness changes do NOT override explicit dark theme', (tester) async {
      SharedPreferences.setMockInitialValues({'pref_theme_mode': 'dark'});
      final themeService = ThemeService(initialThemeMode: ThemeMode.dark);

      await tester.pumpWidget(
        ChangeNotifierProvider<ThemeService>.value(
          value: themeService,
          child: Consumer<ThemeService>(
            builder: (context, ts, _) {
              return MaterialApp(
                theme: AppTheme.lightTheme,
                darkTheme: AppTheme.darkTheme,
                themeMode: ts.themeMode,
                home: Builder(
                  builder: (ctx) {
                    final isDark = Theme.of(ctx).brightness == Brightness.dark;
                    return Text('Brightness: ${isDark ? "DARK" : "LIGHT"}');
                  },
                ),
              );
            },
          ),
        ),
      );

      expect(find.text('Brightness: DARK'), findsOneWidget);

      // Simulate Android OS switching to Light Mode
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      await tester.pumpAndSettle();

      // App MUST stay in explicit DARK theme
      expect(themeService.themeMode, equals(ThemeMode.dark));
      expect(find.text('Brightness: DARK'), findsOneWidget);

      // Reset
      tester.platformDispatcher.clearPlatformBrightnessTestValue();
    });
  });

  group('4. Startup Splash Screen & Theme Rendering', () {
    Widget buildAppWithTheme(ThemeMode mode) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<ThemeService>(
            create: (_) => ThemeService(initialThemeMode: mode),
          ),
          ChangeNotifierProvider<AuthService>(
            create: (_) => FakeAuthService(),
          ),
          ChangeNotifierProvider<StudentService>(
            create: (_) => StudentService(),
          ),
          ChangeNotifierProvider<FacultyService>(
            create: (_) => FacultyService(),
          ),
          ChangeNotifierProvider<BiometricEnrollmentService>(
            create: (_) => BiometricEnrollmentService(),
          ),
          ChangeNotifierProvider<AdminService>(
            create: (_) => AdminService(),
          ),
          ChangeNotifierProvider<NotificationService>.value(
            value: NotificationService(),
          ),
        ],
        child: Consumer<ThemeService>(
          builder: (context, themeService, _) {
            return MaterialApp(
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: themeService.themeMode,
              home: const SplashScreen(),
            );
          },
        ),
      );
    }

    testWidgets('SplashScreen renders white background and GoOnLogo/NexafoBranding on light startup', (tester) async {
      await tester.pumpWidget(buildAppWithTheme(ThemeMode.light));

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, equals(Colors.white));

      final logoFinder = find.byType(GoOnLogo);
      expect(logoFinder, findsOneWidget);
      final brandingFinder = find.byType(NexafoBranding);
      expect(brandingFinder, findsOneWidget);
      expect(find.text('NEXAFOTECH'), findsOneWidget);
    });

    testWidgets('SplashScreen renders obsidian background and GoOnLogo/NexafoBranding on dark startup', (tester) async {
      await tester.pumpWidget(buildAppWithTheme(ThemeMode.dark));

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, equals(const Color(0xFF0D0C13)));

      final logoFinder = find.byType(GoOnLogo);
      expect(logoFinder, findsOneWidget);
      final brandingFinder = find.byType(NexafoBranding);
      expect(brandingFinder, findsOneWidget);
      expect(find.text('NEXAFOTECH'), findsOneWidget);
    });
  });

  group('5. Defensive Fallback & Error Resilience', () {
    test('Storage failure safely falls back to ThemeMode.light without throwing', () async {
      final failingPrefs = MockFailingPreferencesService();
      final themeService = ThemeService(prefs: failingPrefs);
      // Wait for any async microtasks
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(themeService.themeMode, equals(ThemeMode.light));
      expect(themeService.isDarkMode, isFalse);
    });

    testWidgets('SafeThemeConsumer provides fallback ThemeService when not in Provider tree', (tester) async {
      ThemeMode? resolvedMode;

      await tester.pumpWidget(
        MaterialApp(
          home: SafeThemeConsumer(
            builder: (context, ts, _) {
              resolvedMode = ts.themeMode;
              return Text('Mode: ${ts.themeMode}');
            },
          ),
        ),
      );

      expect(resolvedMode, equals(ThemeMode.light));
      expect(SafeThemeConsumer.fallbackThemeMode, equals(ThemeMode.light));
      expect(find.text('Mode: ThemeMode.light'), findsOneWidget);
    });
  });
}
