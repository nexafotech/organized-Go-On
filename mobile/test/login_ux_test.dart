import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:attendance_marker_mobile/auth/screens/login_screen.dart';
import 'package:attendance_marker_mobile/core/config/api_config.dart';
import 'package:attendance_marker_mobile/services/auth_service.dart';
import 'package:attendance_marker_mobile/models/user_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockAuthService extends ChangeNotifier implements AuthService {
  bool _isLoading = false;
  String? _errorMessage;
  bool _sessionExpired = false;
  UserModel? _currentUser;

  @override
  bool get isLoading => _isLoading;
  @override
  String? get errorMessage => _errorMessage;
  @override
  bool get sessionExpired => _sessionExpired;
  @override
  UserModel? get currentUser => _currentUser;
  @override
  bool get isAuthenticated => _currentUser != null;

  void setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }

  void setError(String? val) {
    _errorMessage = val;
    notifyListeners();
  }

  void setSessionExpired(bool val) {
    _sessionExpired = val;
    notifyListeners();
  }

  @override
  void clearErrorMessage() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void clearSessionExpired() {
    _sessionExpired = false;
    notifyListeners();
  }

  @override
  Future<UserModel?> loginStudent(String identifier, String password) async {
    if (identifier == 'FAIL') {
      _errorMessage = 'Incorrect login ID or password.';
      notifyListeners();
      throw Exception('Login failed');
    }
    if (identifier == 'LOCKED') {
      _errorMessage = 'Your account is temporarily locked. Please try again later or contact Admin.';
      notifyListeners();
      throw Exception('Account locked');
    }
    if (identifier == 'DISABLED') {
      _errorMessage = 'Your account is disabled. Please contact Admin.';
      notifyListeners();
      throw Exception('Account disabled');
    }
    if (identifier == 'NETWORK') {
      _errorMessage = 'Unable to reach the server. Check your connection or server address.';
      notifyListeners();
      throw Exception('Network error');
    }
    _currentUser = UserModel(
      id: 1,
      username: identifier,
      email: 'student@college.edu',
      role: 'STUDENT',
      isActive: true,
      fullName: 'Test Student',
    );
    notifyListeners();
    return _currentUser;
  }

  @override
  Future<UserModel?> loginFaculty(String usernameOrEmail, String password) async {
    if (usernameOrEmail == 'FAIL') {
      _errorMessage = 'Incorrect login ID or password.';
      notifyListeners();
      throw Exception('Login failed');
    }
    _currentUser = UserModel(
      id: 2,
      username: usernameOrEmail,
      email: 'faculty@college.edu',
      role: 'FACULTY',
      isActive: true,
      fullName: 'Test Faculty',
    );
    notifyListeners();
    return _currentUser;
  }

  @override
  Future<UserModel?> restoreSession() async => _currentUser;

  @override
  Future<bool> changePassword({required String currentPassword, required String newPassword}) async => true;

  @override
  Future<void> logout() async {
    _currentUser = null;
    _sessionExpired = false;
    notifyListeners();
  }

  @override
  Future<Map<String, dynamic>> validateIdentifier(String identifier, {String role = 'FACULTY'}) async {
    final clean = identifier.trim();
    if (clean.isEmpty) {
      return {'valid': false, 'role': role, 'message': 'Identifier cannot be empty', 'is_network_error': false};
    }
    if (clean == 'NETWORK_ERR') {
      return {'valid': false, 'role': role, 'message': 'Unable to verify username. Check your connection.', 'is_network_error': true};
    }
    if (clean.toLowerCase().startsWith('fac')) {
      return {'valid': true, 'role': 'FACULTY', 'message': '✓ Faculty account recognized', 'is_network_error': false};
    }
    return {'valid': false, 'role': role, 'message': 'Invalid faculty username', 'is_network_error': false};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget createTestWidget(MockAuthService mockAuth) {
    return ChangeNotifierProvider<AuthService>.value(
      value: mockAuth,
      child: const MaterialApp(
        home: LoginScreen(),
      ),
    );
  }

  group('Login UX Tests', () {
    testWidgets('Renders Student and Faculty tabs with correct initial fields', (tester) async {
      final mockAuth = MockAuthService();
      await tester.pumpWidget(createTestWidget(mockAuth));

      expect(find.text('STUDENT'), findsOneWidget);
      expect(find.text('FACULTY'), findsOneWidget);
      expect(find.text('Register Number / Student ID'), findsOneWidget);
      expect(find.text('Student Sign In'), findsOneWidget);
    });

    testWidgets('Student form shows validation error on empty submit', (tester) async {
      final mockAuth = MockAuthService();
      await tester.pumpWidget(createTestWidget(mockAuth));

      // Tap Student Sign In with empty fields
      await tester.tap(find.text('Student Sign In'));
      await tester.pump();

      expect(find.text('Enter your register number'), findsOneWidget);
      expect(find.text('Enter your password'), findsOneWidget);
    });

    testWidgets('Password visibility toggle toggles obscureText', (tester) async {
      final mockAuth = MockAuthService();
      await tester.pumpWidget(createTestWidget(mockAuth));

      // Initially password field is obscured
      final passField = find.byType(EditableText).last;
      EditableText editable = tester.widget(passField);
      expect(editable.obscureText, true);

      // Tap visibility toggle icon
      await tester.tap(find.byIcon(Icons.visibility));
      await tester.pump();

      editable = tester.widget(passField);
      expect(editable.obscureText, false);

      // Tap again to hide
      await tester.tap(find.byIcon(Icons.visibility_off));
      await tester.pump();

      editable = tester.widget(passField);
      expect(editable.obscureText, true);
    });

    testWidgets('Switches to Faculty tab and validates Faculty form fields', (tester) async {
      final mockAuth = MockAuthService();
      await tester.pumpWidget(createTestWidget(mockAuth));

      // Tap FACULTY tab
      await tester.tap(find.text('FACULTY'));
      await tester.pumpAndSettle();

      expect(find.text('Username / Employee ID / Email'), findsOneWidget);
      expect(find.text('Faculty Sign In'), findsOneWidget);

      // Tap Faculty Sign In with empty fields
      await tester.tap(find.text('Faculty Sign In'));
      await tester.pump();

      expect(find.text('Enter faculty identifier'), findsOneWidget);
      expect(find.text('Enter your password'), findsOneWidget);
    });

    testWidgets('Displays session expired banner when sessionExpired is true', (tester) async {
      final mockAuth = MockAuthService();
      mockAuth.setSessionExpired(true);

      await tester.pumpWidget(createTestWidget(mockAuth));
      await tester.pump();

      expect(find.text('Your session has expired. Please sign in again.'), findsOneWidget);
    });

    testWidgets('Displays distinct error banners for 401, locked, disabled, and network failure', (tester) async {
      final mockAuth = MockAuthService();
      await tester.pumpWidget(createTestWidget(mockAuth));

      // 1. Wrong credentials
      await tester.enterText(find.byType(TextFormField).first, 'FAIL');
      await tester.enterText(find.byType(TextFormField).last, 'wrongpass');
      await tester.tap(find.text('Student Sign In'));
      await tester.pump();
      expect(find.text('Incorrect login ID or password.'), findsOneWidget);

      // 2. Locked account
      await tester.enterText(find.byType(TextFormField).first, 'LOCKED');
      await tester.enterText(find.byType(TextFormField).last, 'wrongpass');
      await tester.tap(find.text('Student Sign In'));
      await tester.pump();
      expect(find.text('Your account is temporarily locked. Please try again later or contact Admin.'), findsOneWidget);

      // 3. Disabled account
      await tester.enterText(find.byType(TextFormField).first, 'DISABLED');
      await tester.enterText(find.byType(TextFormField).last, 'wrongpass');
      await tester.tap(find.text('Student Sign In'));
      await tester.pump();
      expect(find.text('Your account is disabled. Please contact Admin.'), findsOneWidget);

      // 4. Network error
      await tester.enterText(find.byType(TextFormField).first, 'NETWORK');
      await tester.enterText(find.byType(TextFormField).last, 'wrongpass');
      await tester.tap(find.text('Student Sign In'));
      await tester.pump();
      expect(find.text('Unable to reach the server. Check your connection or server address.'), findsOneWidget);
    });

    testWidgets('Disables login button during loading state', (tester) async {
      final mockAuth = MockAuthService();
      mockAuth.setLoading(true);

      await tester.pumpWidget(createTestWidget(mockAuth));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('Tapping server status pill opens Server Settings dialog immediately and can cancel', (tester) async {
      final mockAuth = MockAuthService();
      await tester.pumpWidget(createTestWidget(mockAuth));

      expect(find.text('Server Connected'), findsOneWidget);
      await tester.tap(find.text('Server Connected'));
      await tester.pumpAndSettle();

      expect(find.text('Server Settings'), findsOneWidget);
      expect(find.text('Server Base URL'), findsOneWidget);
      expect(find.text('Test Connection'), findsOneWidget);
      expect(find.text('Reset Default'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);

      // Tap Cancel to dismiss
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Server Settings'), findsNothing);
    });

    testWidgets('Server Settings dialog resets to default URL and saves', (tester) async {
      final mockAuth = MockAuthService();
      await tester.pumpWidget(createTestWidget(mockAuth));

      // Open via Server Connected pill
      await tester.tap(find.text('Server Connected'));
      await tester.pumpAndSettle();

      expect(find.text('Server Settings'), findsOneWidget);

      // Tap Reset Default
      await tester.tap(find.text('Reset Default'));
      await tester.pumpAndSettle();

      // Tap Save
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Server Settings'), findsNothing);
      expect(ApiConfig.baseUrl, ApiConfig.defaultUrl);
    });

    testWidgets('Faculty tab: live debounced validation recognizes valid faculty ID', (tester) async {
      final mockAuth = MockAuthService();
      await tester.pumpWidget(createTestWidget(mockAuth));

      // Switch to Faculty tab
      await tester.tap(find.text('FACULTY'));
      await tester.pumpAndSettle();

      // Enter valid faculty identifier
      final idField = find.byType(TextFormField).first;
      await tester.enterText(idField, 'FAC01');
      await tester.pump();

      // Checking status is immediately displayed
      expect(find.text('Checking...'), findsOneWidget);

      // Advance debounce timer (500ms)
      await tester.pump(const Duration(milliseconds: 550));
      await tester.pumpAndSettle();

      // Valid recognized status
      expect(find.text('✓ Faculty account recognized'), findsOneWidget);

      // Password field and button are enabled
      final passField = find.byType(TextFormField).last;
      final FormField passWidget = tester.widget(passField);
      expect(passWidget.enabled, isTrue);

      final button = find.widgetWithText(ElevatedButton, 'Faculty Sign In');
      final ElevatedButton btnWidget = tester.widget(button);
      expect(btnWidget.onPressed, isNotNull);
    });

    testWidgets('Faculty tab: live validation rejects student ID, shows red error, blocks password & sign-in', (tester) async {
      final mockAuth = MockAuthService();
      await tester.pumpWidget(createTestWidget(mockAuth));

      // Switch to Faculty tab
      await tester.tap(find.text('FACULTY'));
      await tester.pumpAndSettle();

      // Enter student register number
      final idField = find.byType(TextFormField).first;
      await tester.enterText(idField, '721025149001');
      await tester.pump();

      expect(find.text('Checking...'), findsOneWidget);

      // Advance debounce timer (500ms)
      await tester.pump(const Duration(milliseconds: 550));
      await tester.pumpAndSettle();

      // Invalid status shown
      expect(find.text('Invalid faculty username'), findsOneWidget);

      // Password field is disabled
      final passField = find.byType(TextFormField).last;
      final FormField passWidget = tester.widget(passField);
      expect(passWidget.enabled, isFalse);

      // Sign In button is disabled
      final button = find.widgetWithText(ElevatedButton, 'Faculty Sign In');
      final ElevatedButton btnWidget = tester.widget(button);
      expect(btnWidget.onPressed, isNull);
    });

    testWidgets('Faculty tab: live validation shows warning yellow on network error', (tester) async {
      final mockAuth = MockAuthService();
      await tester.pumpWidget(createTestWidget(mockAuth));

      // Switch to Faculty tab
      await tester.tap(find.text('FACULTY'));
      await tester.pumpAndSettle();

      // Enter triggering network error
      final idField = find.byType(TextFormField).first;
      await tester.enterText(idField, 'NETWORK_ERR');
      await tester.pump();

      await tester.pump(const Duration(milliseconds: 550));
      await tester.pumpAndSettle();

      expect(find.text('Unable to verify username. Check your connection.'), findsOneWidget);
    });

    testWidgets('Faculty tab: clearing input resets validation state to empty', (tester) async {
      final mockAuth = MockAuthService();
      await tester.pumpWidget(createTestWidget(mockAuth));

      // Switch to Faculty tab
      await tester.tap(find.text('FACULTY'));
      await tester.pumpAndSettle();

      // Enter text
      final idField = find.byType(TextFormField).first;
      await tester.enterText(idField, 'FAC01');
      await tester.pump(const Duration(milliseconds: 550));
      await tester.pumpAndSettle();

      expect(find.text('✓ Faculty account recognized'), findsOneWidget);

      // Clear text
      await tester.enterText(idField, '');
      await tester.pump();

      expect(find.text('✓ Faculty account recognized'), findsNothing);
      expect(find.text('Checking...'), findsNothing);
      expect(find.text('Invalid faculty username'), findsNothing);
    });

    testWidgets('Login shows official Go-On branding at target phone sizes without overflow', (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        for (final scale in [1.0, 2.0]) {
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          for (final size in const [Size(320, 640), Size(360, 800), Size(390, 844), Size(430, 932)]) {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1.0;
            await tester.pumpWidget(createTestWidget(MockAuthService()));
            await tester.pumpAndSettle();

            expect(find.text('Go-On'), findsOneWidget, reason: '$size @ $scale');
            expect(find.bySemanticsLabel('Go-On logo'), findsOneWidget, reason: '$size @ $scale');
            expect(find.text('AI Face Attendance'), findsNothing);
            final exc = tester.takeException();
            expect(exc, isNull, reason: 'overflow at $size @ $scale');
          }
        }
      } finally {
        semantics.dispose();
      }
    });
  });
}
