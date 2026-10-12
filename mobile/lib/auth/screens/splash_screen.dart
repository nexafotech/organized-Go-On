import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../student/screens/student_dashboard_screen.dart';
import '../../faculty/screens/faculty_dashboard_screen.dart';
import '../../admin/screens/admin_student_face_screen.dart';
import '../../widgets/widgets.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthentication();
    });
  }

  Future<void> _checkAuthentication() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = await authService.restoreSession();

    if (!mounted) return;

    if (user == null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } else if (user.isStudent) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const StudentDashboardScreen()),
      );
    } else if (user.isAdmin) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AdminStudentFaceScreen()),
      );
    } else if (user.isFaculty) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const FacultyDashboardScreen()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.hero,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colors.hero,
              colors.heroRaised,
              colors.heroGradientEnd,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: GlassCard(
                  variant: GlassCardVariant.hero,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.xxl),
                  borderColor: colors.accent.withValues(alpha: 0.35),
                  borderWidth: 1.2,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Official Go-On logo + name
                      const GoOnLockup(
                        logoSize: 104,
                        fontSize: 30,
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      // Restrained loading indicator (static under reduced motion)
                      SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          value: (MediaQuery.maybeOf(context)?.disableAnimations ?? false)
                              ? 0.3
                              : null,
                          valueColor: AlwaysStoppedAnimation<Color>(colors.accentOnHero),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
