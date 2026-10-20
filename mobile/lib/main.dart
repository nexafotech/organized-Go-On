import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_service.dart';
import 'services/auth_service.dart';
import 'services/student_service.dart';
import 'services/faculty_service.dart';
import 'services/biometric_enrollment_service.dart';
import 'services/admin_service.dart';
import 'services/notification_service.dart';
import 'core/storage/app_preferences.dart';
import 'auth/screens/splash_screen.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('FLUTTER_ERROR_EX: ${details.exceptionAsString()}');
    debugPrint('FLUTTER_ERROR_CONTEXT: ${details.context}');
    debugPrint('FLUTTER_ERROR_STACK: ${details.stack}');
  };
  NotificationService().setNavigatorKey(appNavigatorKey);
  await NotificationService().initialize();

  // Restore saved theme preference before first frame to eliminate theme flash.
  // Default strictly to light theme on fresh installs or missing storage.
  final prefs = AppPreferencesService();
  ThemeMode initialThemeMode = ThemeMode.light;
  try {
    final savedTheme = await prefs.getThemeMode();
    if (savedTheme == 'dark') {
      initialThemeMode = ThemeMode.dark;
    } else {
      initialThemeMode = ThemeMode.light;
    }
  } catch (_) {
    initialThemeMode = ThemeMode.light;
  }

  final authService = AuthService();

  runApp(AttendanceMarkerApp(
    initialThemeMode: initialThemeMode,
    authService: authService,
    initialScreen: const SplashScreen(),
  ));
}

class AttendanceMarkerApp extends StatelessWidget {
  final ThemeMode initialThemeMode;
  final AuthService? authService;
  final Widget? initialScreen;

  const AttendanceMarkerApp({
    Key? key,
    this.initialThemeMode = ThemeMode.light,
    this.authService,
    this.initialScreen,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeService>(
          create: (_) => ThemeService(initialThemeMode: initialThemeMode),
        ),
        ChangeNotifierProvider<AuthService>.value(
          value: authService ?? AuthService(),
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
          final isDark = themeService.isDarkMode;
          return MaterialApp(
            title: 'Go-On',
            navigatorKey: appNavigatorKey,
            debugShowCheckedModeBanner: false,
            color: isDark ? AppColors.dark.background : AppColors.light.background,
            themeAnimationDuration: Duration.zero,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeService.themeMode,
            home: initialScreen ?? const SplashScreen(),
          );
        },
      ),
    );
  }
}
