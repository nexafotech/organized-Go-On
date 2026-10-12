import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'services/auth_service.dart';
import 'services/student_service.dart';
import 'services/faculty_service.dart';
import 'services/biometric_enrollment_service.dart';
import 'services/admin_service.dart';
import 'services/notification_service.dart';
import 'auth/screens/splash_screen.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  NotificationService().setNavigatorKey(appNavigatorKey);
  await NotificationService().initialize();
  runApp(const AttendanceMarkerApp());
}

class AttendanceMarkerApp extends StatelessWidget {
  const AttendanceMarkerApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>(
          create: (_) => AuthService(),
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
      child: MaterialApp(
        title: 'Go-On',
        navigatorKey: appNavigatorKey,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.light,
        home: const SplashScreen(),
      ),
    );
  }
}
