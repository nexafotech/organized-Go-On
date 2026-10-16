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
import 'auth/screens/login_screen.dart';
import 'student/screens/student_dashboard_screen.dart';
import 'faculty/screens/faculty_dashboard_screen.dart';
import 'admin/screens/admin_student_face_screen.dart';

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

  // Directly determine initial screen before first frame to eliminate intermediate splash screen
  final authService = AuthService();
  final hasToken = await authService.hasStoredToken();
  final cachedUser = await prefs.getCachedUser();

  Widget initialScreen = const LoginScreen();
  if (hasToken && cachedUser != null) {
    authService.setInitialCachedUser(cachedUser);
    if (cachedUser.isStudent) {
      initialScreen = const StudentDashboardScreen();
    } else if (cachedUser.isAdmin) {
      initialScreen = const AdminStudentFaceScreen();
    } else if (cachedUser.isFaculty) {
      initialScreen = const FacultyDashboardScreen();
    }
    // Verify token authoritatively in background without delaying initial UI frame
    authService.restoreSession();
  } else if (hasToken) {
    // Stored token without cached user: fast restore with 1.5s timeout
    try {
      final user = await authService.restoreSession().timeout(const Duration(milliseconds: 1500));
      if (user != null) {
        if (user.isStudent) {
          initialScreen = const StudentDashboardScreen();
        } else if (user.isAdmin) {
          initialScreen = const AdminStudentFaceScreen();
        } else if (user.isFaculty) {
          initialScreen = const FacultyDashboardScreen();
        }
      }
    } catch (_) {
      initialScreen = const LoginScreen();
    }
  }

  runApp(AttendanceMarkerApp(
    initialThemeMode: initialThemeMode,
    authService: authService,
    initialScreen: initialScreen,
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
          return MaterialApp(
            title: 'Go-On',
            navigatorKey: appNavigatorKey,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeService.themeMode,
            home: initialScreen ?? const LoginScreen(),
          );
        },
      ),
    );
  }
}
