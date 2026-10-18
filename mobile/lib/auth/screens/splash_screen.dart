import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../student/screens/student_dashboard_screen.dart';
import '../../faculty/screens/faculty_dashboard_screen.dart';
import '../../admin/screens/admin_student_face_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  final int minDisplayMs;

  const SplashScreen({
    Key? key,
    this.minDisplayMs = 800,
  }) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _hasNavigated = false;
  String? _errorMessage;
  Timer? _displayTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthentication();
    });
  }

  @override
  void dispose() {
    _displayTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkAuthentication() async {
    if (_hasNavigated) return;

    final authService = Provider.of<AuthService>(context, listen: false);

    UserModel? user;
    try {
      user = await authService.restoreSession();
    } catch (_) {
      user = null;
    }

    if (!mounted) return;

    if (widget.minDisplayMs > 0) {
      _displayTimer?.cancel();
      _displayTimer = Timer(Duration(milliseconds: widget.minDisplayMs), () {
        if (!mounted) return;
        _onAuthResolved(user, authService);
      });
    } else {
      _onAuthResolved(user, authService);
    }
  }

  Future<void> _onAuthResolved(UserModel? user, AuthService authService) async {
    if (_hasNavigated || !mounted) return;

    if (user != null) {
      _navigateSafely(user);
    } else {
      final hasToken = await authService.hasStoredToken();
      if (hasToken && authService.isNetworkError) {
        if (!mounted) return;
        setState(() {
          _errorMessage = authService.errorMessage ?? 'Unable to reach the server. Please check your connection.';
        });
      } else {
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
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF04050A) : Colors.white;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: backgroundColor,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: _errorMessage != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? const Color(0xFFE57373) : const Color(0xFFC62828),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _errorMessage = null;
                          });
                          _checkAuthentication();
                        },
                        child: const Text('Retry'),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => _navigateSafely(null),
                        child: const Text('Go to Sign In'),
                      ),
                    ],
                  ),
                ),
              )
            : SizedBox.expand(
                child: SafeArea(
                  child: Image.asset(
                    isDark
                        ? 'assets/branding/go_on_splash_dark.png'
                        : 'assets/branding/go_on_splash.png',
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (context, error, stackTrace) {
                      return Center(
                        child: Image.asset(
                          'assets/branding/go_on_logo.png',
                          width: 140,
                          height: 140,
                          fit: BoxFit.contain,
                        ),
                      );
                    },
                  ),
                ),
              ),
      ),
    );
  }
}
