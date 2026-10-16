import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../student/screens/student_dashboard_screen.dart';
import '../../faculty/screens/faculty_dashboard_screen.dart';
import '../../admin/screens/admin_student_face_screen.dart';
import 'login_screen.dart';
import '../../widgets/common/go_on_brand.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _hasNavigated = false;
  bool _isChecking = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthentication();
    });
  }

  Future<void> _checkAuthentication() async {
    if (_hasNavigated || _isChecking) return;
    if (mounted) {
      setState(() {
        _isChecking = true;
        _errorMessage = null;
      });
    }

    final authService = Provider.of<AuthService>(context, listen: false);
    UserModel? user;
    try {
      user = await authService.restoreSession();
    } catch (_) {
      user = null;
    }

    if (!mounted) return;

    if (user != null) {
      _navigateSafely(user);
    } else {
      // Determine if failure was due to network error with an existing stored session
      final hasToken = await authService.hasStoredToken();
      if (hasToken && authService.isNetworkError) {
        if (!mounted) return;
        setState(() {
          _isChecking = false;
          _errorMessage = authService.errorMessage ?? 'Unable to reach the server. Please check your connection.';
        });
      } else {
        // Logged out or expired session: cleanly proceed to LoginScreen
        _navigateSafely(null);
      }
    }
  }

  void _navigateSafely(UserModel? user) {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;

    Widget destination;
    if (user == null) {
      destination = const LoginScreen();
    } else if (user.isStudent) {
      destination = const StudentDashboardScreen();
    } else if (user.isAdmin) {
      destination = const AdminStudentFaceScreen();
    } else if (user.isFaculty) {
      destination = const FacultyDashboardScreen();
    } else {
      destination = const LoginScreen();
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => destination,
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 250),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF0D0C13) : Colors.white;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: backgroundColor,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Centered official Go-On gold logo (Image 2)
            Center(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final logoSize = (constraints.maxWidth * 0.44).clamp(140.0, 190.0);
                  return GoOnLogo(size: logoSize);
                },
              ),
            ),

            // Bottom-centered "from NEXAFOTECH" branding with safe-area protection (Image 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                minimum: const EdgeInsets.only(bottom: 28),
                child: Center(
                  child: NexafoBranding(isDark: isDark),
                ),
              ),
            ),

            // Network retry banner (only surfaces on connectivity failure with stored session)
            if (_errorMessage != null)
              Positioned(
                left: 20,
                right: 20,
                bottom: 32,
                child: SafeArea(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1C27) : const Color(0xFFF6F1EA),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? const Color(0x33FFFFFF) : const Color(0xFFD5C8B8),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.wifi_off_rounded,
                              size: 20,
                              color: isDark ? const Color(0xFFF7F5EE) : const Color(0xFF22150F),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? const Color(0xFFF7F5EE) : const Color(0xFF22150F),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () {
                                _navigateSafely(null);
                              },
                              child: Text(
                                'Go to Sign In',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? const Color(0xFFC5BDD3) : const Color(0xFF6B5B50),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _checkAuthentication,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFB87B4B),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Text('Retry', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
