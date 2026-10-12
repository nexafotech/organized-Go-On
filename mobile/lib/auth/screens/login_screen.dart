import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../core/config/api_config.dart';
import '../../core/storage/app_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../student/screens/student_dashboard_screen.dart';
import '../../faculty/screens/faculty_dashboard_screen.dart';
import '../../admin/screens/admin_student_face_screen.dart';
import '../../widgets/widgets.dart';

enum FacultyValidationState {
  empty,
  checking,
  valid,
  invalid,
  networkError,
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AppPreferencesService _prefsService = AppPreferencesService();

  final _studentIdController = TextEditingController();
  final _studentPassController = TextEditingController();
  final _facultyIdController = TextEditingController();
  final _facultyPassController = TextEditingController();

  final _formKeyStudent = GlobalKey<FormState>();
  final _formKeyFaculty = GlobalKey<FormState>();

  bool _isStudentPasswordVisible = false;
  bool _isFacultyPasswordVisible = false;
  String? _localErrorMessage;

  FacultyValidationState _facultyValidationState = FacultyValidationState.empty;
  String? _facultyValidationMessage;
  Timer? _facultyDebounceTimer;
  String _lastValidatedFacultyId = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSavedPreferences();
  }

  Future<void> _loadSavedPreferences() async {
    final savedUrl = await _prefsService.getCustomBackendUrl();
    if (savedUrl != null && savedUrl.isNotEmpty) {
      ApiConfig.setBaseUrl(savedUrl);
    }
    final savedTab = await _prefsService.getSelectedRoleTab();
    if (savedTab == 'FACULTY') {
      _tabController.animateTo(1);
    }
  }

  @override
  void dispose() {
    _facultyDebounceTimer?.cancel();
    _tabController.dispose();
    _studentIdController.dispose();
    _studentPassController.dispose();
    _facultyIdController.dispose();
    _facultyPassController.dispose();
    super.dispose();
  }

  void _onFacultyIdChanged(String value) {
    final trimmed = value.trim();
    _facultyDebounceTimer?.cancel();

    if (trimmed.isEmpty) {
      setState(() {
        _facultyValidationState = FacultyValidationState.empty;
        _facultyValidationMessage = null;
        _lastValidatedFacultyId = '';
      });
      return;
    }

    if (trimmed == _lastValidatedFacultyId && _facultyValidationState != FacultyValidationState.empty) {
      return;
    }

    setState(() {
      _facultyValidationState = FacultyValidationState.checking;
      _facultyValidationMessage = 'Checking...';
    });

    _facultyDebounceTimer = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted) return;
      final currentText = _facultyIdController.text.trim();
      if (currentText.isEmpty) {
        setState(() {
          _facultyValidationState = FacultyValidationState.empty;
          _facultyValidationMessage = null;
        });
        return;
      }

      try {
        final authService = Provider.of<AuthService>(context, listen: false);
        final result = await authService.validateIdentifier(currentText, role: 'FACULTY');
        if (!mounted) return;
        if (_facultyIdController.text.trim() != currentText) return;

        setState(() {
          _lastValidatedFacultyId = currentText;
          if (result['is_network_error'] == true) {
            _facultyValidationState = FacultyValidationState.networkError;
            _facultyValidationMessage = 'Unable to verify username. Check your connection.';
          } else if (result['valid'] == true) {
            _facultyValidationState = FacultyValidationState.valid;
            _facultyValidationMessage = '✓ Faculty account recognized';
          } else {
            _facultyValidationState = FacultyValidationState.invalid;
            _facultyValidationMessage = 'Invalid faculty username';
          }
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _facultyValidationState = FacultyValidationState.networkError;
          _facultyValidationMessage = 'Unable to verify username. Check your connection.';
        });
      }
    });
  }

  Future<void> _handleStudentLogin() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (authService.isLoading) return;
    if (!_formKeyStudent.currentState!.validate()) return;

    setState(() => _localErrorMessage = null);
    authService.clearErrorMessage();

    try {
      final user = await authService.loginStudent(
        _studentIdController.text.trim(),
        _studentPassController.text.trim(),
      );

      if (!mounted) return;
      await _prefsService.saveSelectedRoleTab('STUDENT');

      if (user != null && user.isStudent) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const StudentDashboardScreen()),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _localErrorMessage = authService.errorMessage;
      });
    }
  }

  Future<void> _handleFacultyLogin() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (authService.isLoading) return;
    if (!_formKeyFaculty.currentState!.validate()) return;

    if (_facultyValidationState == FacultyValidationState.invalid) {
      return;
    }

    if (_facultyValidationState == FacultyValidationState.checking || _facultyValidationState == FacultyValidationState.empty) {
      final currentText = _facultyIdController.text.trim();
      if (currentText.isEmpty) return;

      final res = await authService.validateIdentifier(currentText, role: 'FACULTY');
      if (!mounted) return;

      if (res['valid'] != true) {
        setState(() {
          if (res['is_network_error'] == true) {
            _facultyValidationState = FacultyValidationState.networkError;
            _facultyValidationMessage = 'Unable to verify username. Check your connection.';
          } else {
            _facultyValidationState = FacultyValidationState.invalid;
            _facultyValidationMessage = 'Invalid faculty username';
          }
        });
        return;
      } else {
        setState(() {
          _facultyValidationState = FacultyValidationState.valid;
          _facultyValidationMessage = '✓ Faculty account recognized';
        });
      }
    }

    setState(() => _localErrorMessage = null);
    authService.clearErrorMessage();

    try {
      final user = await authService.loginFaculty(
        _facultyIdController.text.trim(),
        _facultyPassController.text.trim(),
      );

      if (!mounted) return;
      await _prefsService.saveSelectedRoleTab('FACULTY');

      if (user != null) {
        if (user.isAdmin) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const AdminStudentFaceScreen()),
          );
        } else if (user.isFaculty) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const FacultyDashboardScreen()),
          );
        }
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _localErrorMessage = authService.errorMessage;
      });
    }
  }

  void _showServerConfigDialog() {
    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => _ServerConfigDialog(
        prefsService: _prefsService,
        onSaved: (newUrl) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Server URL updated to: $newUrl'),
              backgroundColor: context.colors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final authService = Provider.of<AuthService>(context);
    final displayedError = _localErrorMessage ?? authService.errorMessage;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_remote_rounded),
            tooltip: 'Configure Server URL',
            onPressed: _showServerConfigDialog,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 4.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. STANDALONE BRANDING - Official Go-On Logo + Wordmark (no box/background)
                  const SizedBox(height: 6),
                  Center(
                    child: GoOnLockup(
                      logoSize: 76,
                      fontSize: 26,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // SUPPORTING SERVER STATUS PILL
                  Center(
                    child: GestureDetector(
                      onTap: _showServerConfigDialog,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: colors.surfaceElevated.withValues(alpha: 0.9),
                          borderRadius: AppRadius.pillBorder,
                          border: Border.all(color: colors.glassBorderStrong),
                          boxShadow: AppElevation.e1,
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.wifi, size: 12, color: colors.success),
                              const SizedBox(width: 5),
                              Text(
                                'Server Connected',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: colors.success,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.settings, size: 11, color: colors.textMuted),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // 2. GLASS LOGIN PANEL
                  GlassCard(
                    variant: GlassCardVariant.elevated,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    borderColor: colors.glassBorderStrong,
                    borderWidth: 1.0,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Role Selection Tabs
                        Container(
                          height: 42,
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: colors.surfaceMuted,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: colors.border),
                          ),
                          child: TabBar(
                            controller: _tabController,
                            indicator: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: colors.primary,
                            ),
                            indicatorSize: TabBarIndicatorSize.tab,
                            labelColor: colors.onPrimary,
                            unselectedLabelColor: colors.textMuted,
                            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            tabs: const [
                              Tab(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.person_rounded, size: 17),
                                      SizedBox(width: 6),
                                      Text('STUDENT'),
                                    ],
                                  ),
                                ),
                              ),
                              Tab(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.badge_rounded, size: 17),
                                      SizedBox(width: 6),
                                      Text('FACULTY'),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Session Expired Banner
                        if (authService.sessionExpired) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: colors.warningBg,
                              borderRadius: AppRadius.smallBorder,
                              border: Border.all(color: colors.warning.withValues(alpha: 0.5)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.warning_amber_rounded, color: colors.warning, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Your session has expired. Please sign in again.',
                                    style: TextStyle(color: colors.warning, fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.close, size: 16, color: colors.warning),
                                  onPressed: () => authService.clearSessionExpired(),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Error State Banner
                        if (displayedError != null && !authService.sessionExpired) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: colors.errorBg,
                              borderRadius: AppRadius.smallBorder,
                              border: Border.all(color: colors.error.withValues(alpha: 0.5)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.error_outline, color: colors.error, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    displayedError,
                                    style: TextStyle(color: colors.error, fontSize: 12, fontWeight: FontWeight.w500),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.close, size: 16, color: colors.error),
                                  onPressed: () {
                                    setState(() => _localErrorMessage = null);
                                    authService.clearErrorMessage();
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 10),

                        // Form Tab Views
                        AnimatedBuilder(
                          animation: _tabController,
                          builder: (context, _) {
                            return IndexedStack(
                              index: _tabController.index,
                              children: [
                                _buildStudentForm(colors, authService),
                                _buildFacultyForm(colors, authService),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStudentForm(AppColors colors, AuthService authService) {
    return Form(
      key: _formKeyStudent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _studentIdController,
            enabled: !authService.isLoading,
            keyboardType: TextInputType.text,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: 'Register Number / Student ID',
              hintText: 'e.g. 23CY001',
              prefixIcon: const Icon(Icons.badge_outlined, size: 20),
              filled: true,
              fillColor: colors.surfaceMuted.withValues(alpha: 0.5),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              border: OutlineInputBorder(borderRadius: AppRadius.mediumBorder, borderSide: BorderSide(color: colors.border)),
              enabledBorder: OutlineInputBorder(borderRadius: AppRadius.mediumBorder, borderSide: BorderSide(color: colors.border)),
              focusedBorder: OutlineInputBorder(borderRadius: AppRadius.mediumBorder, borderSide: BorderSide(color: colors.accent, width: 1.8)),
            ),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Enter your register number' : null,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _studentPassController,
            obscureText: !_isStudentPasswordVisible,
            enabled: !authService.isLoading,
            decoration: InputDecoration(
              labelText: 'Password',
              hintText: 'Enter student password',
              prefixIcon: const Icon(Icons.lock_outline, size: 20),
              filled: true,
              fillColor: colors.surfaceMuted.withValues(alpha: 0.5),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              border: OutlineInputBorder(borderRadius: AppRadius.mediumBorder, borderSide: BorderSide(color: colors.border)),
              enabledBorder: OutlineInputBorder(borderRadius: AppRadius.mediumBorder, borderSide: BorderSide(color: colors.border)),
              focusedBorder: OutlineInputBorder(borderRadius: AppRadius.mediumBorder, borderSide: BorderSide(color: colors.accent, width: 1.8)),
              suffixIcon: IconButton(
                icon: Icon(
                  _isStudentPasswordVisible ? Icons.visibility_off : Icons.visibility,
                  size: 20,
                ),
                onPressed: () => setState(
                    () => _isStudentPasswordVisible = !_isStudentPasswordVisible),
              ),
            ),
            validator: (v) =>
                v == null || v.isEmpty ? 'Enter your password' : null,
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
              elevation: 2,
              padding: const EdgeInsets.symmetric(vertical: 11),
              shape: RoundedRectangleBorder(borderRadius: AppRadius.pillBorder),
            ),
            onPressed: authService.isLoading ? null : _handleStudentLogin,
            child: authService.isLoading
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('Student Sign In', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildFacultyForm(AppColors colors, AuthService authService) {
    return Form(
      key: _formKeyFaculty,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _facultyIdController,
            enabled: !authService.isLoading,
            onChanged: _onFacultyIdChanged,
            decoration: InputDecoration(
              labelText: 'Username / Employee ID / Email',
              hintText: 'e.g. FAC01 or username',
              prefixIcon: const Icon(Icons.person_outline, size: 20),
              filled: true,
              fillColor: colors.surfaceMuted.withValues(alpha: 0.5),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              border: OutlineInputBorder(borderRadius: AppRadius.mediumBorder, borderSide: BorderSide(color: colors.border)),
              enabledBorder: OutlineInputBorder(borderRadius: AppRadius.mediumBorder, borderSide: BorderSide(color: colors.border)),
              focusedBorder: OutlineInputBorder(borderRadius: AppRadius.mediumBorder, borderSide: BorderSide(color: colors.accent, width: 1.8)),
            ),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Enter faculty identifier' : null,
          ),
          if (_facultyValidationState != FacultyValidationState.empty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                if (_facultyValidationState == FacultyValidationState.checking) ...[
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.0,
                      valueColor: AlwaysStoppedAnimation<Color>(colors.textMuted),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Checking...',
                      key: const Key('faculty_checking_status'),
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textMuted,
                      ),
                    ),
                  ),
                ] else if (_facultyValidationState == FacultyValidationState.valid) ...[
                  Icon(
                    Icons.check_circle_outline,
                    color: colors.success,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _facultyValidationMessage ?? '✓ Faculty account recognized',
                      key: const Key('faculty_valid_status'),
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ] else if (_facultyValidationState == FacultyValidationState.invalid) ...[
                  Icon(
                    Icons.cancel_outlined,
                    color: colors.error,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _facultyValidationMessage ?? 'Invalid faculty username',
                      key: const Key('faculty_invalid_status'),
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ] else if (_facultyValidationState == FacultyValidationState.networkError) ...[
                  Icon(
                    Icons.warning_amber_rounded,
                    color: colors.warning,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _facultyValidationMessage ?? 'Unable to verify username. Check your connection.',
                      key: const Key('faculty_network_error_status'),
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.warning,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
          const SizedBox(height: 8),
          TextFormField(
            controller: _facultyPassController,
            obscureText: !_isFacultyPasswordVisible,
            enabled: !authService.isLoading && _facultyValidationState != FacultyValidationState.invalid,
            decoration: InputDecoration(
              labelText: 'Password',
              hintText: 'Enter faculty password',
              prefixIcon: const Icon(Icons.lock_outline, size: 20),
              filled: true,
              fillColor: colors.surfaceMuted.withValues(alpha: 0.5),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              border: OutlineInputBorder(borderRadius: AppRadius.mediumBorder, borderSide: BorderSide(color: colors.border)),
              enabledBorder: OutlineInputBorder(borderRadius: AppRadius.mediumBorder, borderSide: BorderSide(color: colors.border)),
              focusedBorder: OutlineInputBorder(borderRadius: AppRadius.mediumBorder, borderSide: BorderSide(color: colors.accent, width: 1.8)),
              suffixIcon: IconButton(
                icon: Icon(
                  _isFacultyPasswordVisible ? Icons.visibility_off : Icons.visibility,
                  size: 20,
                ),
                onPressed: () => setState(
                    () => _isFacultyPasswordVisible = !_isFacultyPasswordVisible),
              ),
            ),
            validator: (v) =>
                v == null || v.isEmpty ? 'Enter your password' : null,
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
              elevation: 2,
              padding: const EdgeInsets.symmetric(vertical: 11),
              shape: RoundedRectangleBorder(borderRadius: AppRadius.pillBorder),
            ),
            onPressed: (authService.isLoading || _facultyValidationState == FacultyValidationState.invalid)
                ? null
                : _handleFacultyLogin,
            child: authService.isLoading
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('Faculty Sign In', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _ServerConfigDialog extends StatefulWidget {
  final AppPreferencesService prefsService;
  final ValueChanged<String> onSaved;

  const _ServerConfigDialog({
    Key? key,
    required this.prefsService,
    required this.onSaved,
  }) : super(key: key);

  @override
  State<_ServerConfigDialog> createState() => _ServerConfigDialogState();
}

class _ServerConfigDialogState extends State<_ServerConfigDialog> {
  late final TextEditingController _urlController;
  bool _isTesting = false;
  String? _testResult;
  bool? _testSuccess;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: ApiConfig.baseUrl);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    final rawUrl = _urlController.text.trim();
    if (rawUrl.isEmpty) return;

    setState(() {
      _isTesting = true;
      _testResult = null;
      _testSuccess = null;
    });

    try {
      String clean = rawUrl;
      while (clean.endsWith('/')) {
        clean = clean.substring(0, clean.length - 1);
      }
      if (!clean.startsWith('http://') && !clean.startsWith('https://')) {
        clean = 'http://$clean';
      }

      final uri = Uri.parse('$clean/health');
      final client = http.Client();
      final response = await client.get(uri).timeout(const Duration(seconds: 4));
      client.close();

      if (!mounted) return;
      setState(() {
        _isTesting = false;
        if (response.statusCode == 200) {
          _testSuccess = true;
          _testResult = 'Server is reachable and online!';
        } else {
          _testSuccess = false;
          _testResult = 'Server responded with status ${response.statusCode}';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isTesting = false;
        _testSuccess = false;
        _testResult = 'Unable to reach the server. Check your connection or server address.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return AlertDialog(
      backgroundColor: colors.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.dialogBorder,
        side: BorderSide(color: colors.glassBorderStrong),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colors.heroChip,
              borderRadius: AppRadius.smallBorder,
            ),
            child: Icon(Icons.settings_ethernet_rounded, color: colors.primary, size: 20),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'Server Settings',
            style: typography.titleMedium.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Enter backend API URL or tap a network preset:',
                style: typography.bodySmall.copyWith(color: colors.textMuted),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  ActionChip(
                    avatar: Icon(Icons.wifi_rounded, size: 14, color: colors.info),
                    label: const Text('WiFi (192.168.0.114)', style: TextStyle(fontSize: 11)),
                    backgroundColor: colors.surfaceMuted,
                    side: BorderSide(color: colors.glassBorder),
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.pillBorder),
                    onPressed: () {
                      setState(() {
                        _urlController.text = ApiConfig.defaultUrl;
                        _testResult = null;
                        _testSuccess = null;
                      });
                    },
                  ),
                  ActionChip(
                    avatar: Icon(Icons.wifi_tethering_rounded, size: 14, color: colors.success),
                    label: const Text('Hotspot (10.254.103.195)', style: TextStyle(fontSize: 11)),
                    backgroundColor: colors.surfaceMuted,
                    side: BorderSide(color: colors.glassBorder),
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.pillBorder),
                    onPressed: () {
                      setState(() {
                        _urlController.text = ApiConfig.hotspotUrl;
                        _testResult = null;
                        _testSuccess = null;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _urlController,
                decoration: InputDecoration(
                  labelText: 'Server Base URL',
                  hintText: 'http://192.168.0.114:8000',
                  prefixIcon: const Icon(Icons.link_rounded),
                  filled: true,
                  fillColor: colors.surfaceMuted.withValues(alpha: 0.5),
                  border: OutlineInputBorder(borderRadius: AppRadius.mediumBorder, borderSide: BorderSide(color: colors.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: AppRadius.mediumBorder, borderSide: BorderSide(color: colors.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: AppRadius.mediumBorder, borderSide: BorderSide(color: colors.accent, width: 1.8)),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Connection Test Action & Result
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    visualDensity: VisualDensity.compact,
                    foregroundColor: colors.primary,
                    side: BorderSide(color: colors.primary.withValues(alpha: 0.4)),
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.pillBorder),
                  ),
                  icon: _isTesting
                      ? SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(colors.primary)),
                        )
                      : const Icon(Icons.network_check_rounded, size: 16),
                  label: const Text('Test Connection', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: _isTesting ? null : _testConnection,
                ),
              ),

              if (_testResult != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _testSuccess == true ? colors.successBg : colors.errorBg,
                    borderRadius: AppRadius.smallBorder,
                    border: Border.all(
                      color: _testSuccess == true
                          ? colors.success.withValues(alpha: 0.5)
                          : colors.error.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _testSuccess == true ? Icons.check_circle_outline : Icons.error_outline,
                        size: 16,
                        color: _testSuccess == true ? colors.success : colors.error,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _testResult!,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _testSuccess == true ? colors.success : colors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            _urlController.text = ApiConfig.defaultUrl;
          },
          child: Text('Reset Default', style: TextStyle(color: colors.textSecondary)),
        ),
        TextButton(
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
          child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.primary,
            foregroundColor: colors.onPrimary,
            minimumSize: const Size(80, 40),
            shape: RoundedRectangleBorder(borderRadius: AppRadius.pillBorder),
          ),
          onPressed: () {
            final newUrl = _urlController.text.trim();
            if (newUrl.isNotEmpty) {
              ApiConfig.setBaseUrl(newUrl);
              widget.prefsService.saveCustomBackendUrl(ApiConfig.baseUrl);
              widget.onSaved(ApiConfig.baseUrl);
            }
            Navigator.of(context, rootNavigator: true).pop();
          },
          child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
