import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:attendance_marker_mobile/auth/screens/splash_screen.dart';
import 'package:attendance_marker_mobile/auth/screens/login_screen.dart';
import 'package:attendance_marker_mobile/student/screens/student_dashboard_screen.dart';
import 'package:attendance_marker_mobile/faculty/screens/faculty_dashboard_screen.dart';
import 'package:attendance_marker_mobile/admin/screens/admin_student_face_screen.dart';
import 'package:attendance_marker_mobile/services/auth_service.dart';
import 'package:attendance_marker_mobile/models/user_model.dart';
import 'package:attendance_marker_mobile/core/theme/theme_service.dart';
import 'package:attendance_marker_mobile/core/theme/app_theme.dart';
import 'package:attendance_marker_mobile/services/student_service.dart';
import 'package:attendance_marker_mobile/services/faculty_service.dart';
import 'package:attendance_marker_mobile/services/admin_service.dart';
import 'package:attendance_marker_mobile/services/biometric_enrollment_service.dart';
import 'package:attendance_marker_mobile/services/notification_service.dart';
import 'package:attendance_marker_mobile/widgets/common/go_on_brand.dart';

class FakeAuthService extends ChangeNotifier implements AuthService {
  UserModel? _mockUser;
  bool _mockIsLoading = false;
  String? _mockErrorMessage;
  bool _mockSessionExpired = false;
  bool _mockHasStoredToken = false;
  bool _restoreSessionCalled = false;
  bool get restoreSessionCalled => _restoreSessionCalled;
  int restoreSessionCallCount = 0;

  @override
  UserModel? get currentUser => _mockUser;
  @override
  bool get isLoading => _mockIsLoading;
  @override
  bool get isAuthenticated => _mockUser != null;
  @override
  String? get errorMessage => _mockErrorMessage;
  @override
  bool get sessionExpired => _mockSessionExpired;
  @override
  bool get isNetworkError => _mockErrorMessage != null && !_mockSessionExpired && _mockUser == null;

  void configure({
    UserModel? user,
    bool isLoading = false,
    String? errorMessage,
    bool sessionExpired = false,
    bool hasStoredToken = false,
  }) {
    _mockUser = user;
    _mockIsLoading = isLoading;
    _mockErrorMessage = errorMessage;
    _mockSessionExpired = sessionExpired;
    _mockHasStoredToken = hasStoredToken;
    restoreSessionCallCount = 0;
    _restoreSessionCalled = false;
  }

  @override
  Future<bool> hasStoredToken() async => _mockHasStoredToken;

  @override
  Future<UserModel?> restoreSession() async {
    restoreSessionCallCount++;
    _restoreSessionCalled = true;
    return _mockUser;
  }

  @override
  void clearErrorMessage() {
    _mockErrorMessage = null;
    notifyListeners();
  }

  @override
  void clearSessionExpired() {
    _mockSessionExpired = false;
    notifyListeners();
  }

  @override
  void setMockUser(UserModel user) {
    _mockUser = user;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAuthService fakeAuth;

  setUp(() {
    fakeAuth = FakeAuthService();
  });

  Widget createSplashWidget({ThemeMode themeMode = ThemeMode.light}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeService>(
          create: (_) => ThemeService(initialThemeMode: themeMode),
        ),
        ChangeNotifierProvider<AuthService>.value(
          value: fakeAuth,
        ),
        ChangeNotifierProvider<StudentService>(
          create: (_) => StudentService(),
        ),
        ChangeNotifierProvider<FacultyService>(
          create: (_) => FacultyService(),
        ),
        ChangeNotifierProvider<AdminService>(
          create: (_) => AdminService(),
        ),
        ChangeNotifierProvider<BiometricEnrollmentService>(
          create: (_) => BiometricEnrollmentService(),
        ),
        ChangeNotifierProvider<NotificationService>.value(
          value: NotificationService(),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeMode,
        home: const SplashScreen(),
      ),
    );
  }

  group('New Branded Loading Screen (Image 2) Visual Verification', () {
    testWidgets('Renders official Go-On gold logo and bottom NexafoBranding in light mode', (tester) async {
      fakeAuth.configure(user: null); // logged out

      await tester.pumpWidget(createSplashWidget(themeMode: ThemeMode.light));

      // 1. Scaffold background must be pure white in light mode
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, Colors.white);

      // 2. Must render the centered official Go-On gold logo
      final logoFinder = find.byType(GoOnLogo);
      final imageWidget = tester.widget<Image>(find.descendant(of: logoFinder, matching: find.byType(Image)));
      final imageProvider = imageWidget.image;
      final assetName = imageProvider is ResizeImage
          ? (imageProvider.imageProvider as AssetImage).assetName
          : (imageProvider as AssetImage).assetName;
      expect(assetName, 'assets/branding/go_on_logo.png');
      expect(imageWidget.fit, BoxFit.contain);

      // 3. Must render the bottom "from NEXAFOTECH" branding with safe-area protection
      final brandingFinder = find.byType(NexafoBranding);
      expect(brandingFinder, findsOneWidget);
      expect(find.text('from'), findsOneWidget);
      expect(find.text('NEXAFOTECH'), findsOneWidget);

      // Verify safe-area protection
      expect(find.descendant(of: find.byType(SafeArea), matching: find.byType(NexafoBranding)), findsOneWidget);

      // 4. Old brown card elements must NOT exist in widget tree
      expect(find.text('Go-On'), findsNothing); // Old text lockup was removed
      expect(find.byType(CircularProgressIndicator), findsNothing); // Old spinner was removed
    });

    testWidgets('Renders gold logo and bottom NexafoBranding on obsidian dark background in dark mode', (tester) async {
      fakeAuth.configure(user: null);

      await tester.pumpWidget(createSplashWidget(themeMode: ThemeMode.dark));

      // 1. Scaffold background must be obsidian dark
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, const Color(0xFF0D0C13));

      // 2. Must render official Go-On logo
      final logoFinder = find.byType(GoOnLogo);
      expect(logoFinder, findsOneWidget);

      // 3. Must render "from NEXAFOTECH" branding
      final brandingFinder = find.byType(NexafoBranding);
      expect(brandingFinder, findsOneWidget);
      expect(find.text('from'), findsOneWidget);
      expect(find.text('NEXAFOTECH'), findsOneWidget);
    });

    testWidgets('Responsive layout adapts across different device sizes without overflow', (tester) async {
      fakeAuth.configure(user: null);

      // Test small phone size (360 x 640)
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createSplashWidget(themeMode: ThemeMode.light));
      expect(tester.takeException(), isNull);
      expect(find.byType(GoOnLogo), findsOneWidget);
      expect(find.byType(NexafoBranding), findsOneWidget);

      // Test tall modern phone size (412 x 915 - Samsung S24 aspect)
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.625;
      await tester.pumpWidget(createSplashWidget(themeMode: ThemeMode.light));
      expect(tester.takeException(), isNull);
      expect(find.byType(GoOnLogo), findsOneWidget);
      expect(find.byType(NexafoBranding), findsOneWidget);
    });
  });

  group('Authentication-Aware Startup Routing Tests', () {
    testWidgets('Logged-out user routes to LoginScreen', (tester) async {
      fakeAuth.configure(user: null, hasStoredToken: false);

      await tester.pumpWidget(createSplashWidget());
      await tester.pump(); // Start restoreSession
      await tester.pumpAndSettle(); // Complete transition

      expect(find.byType(SplashScreen), findsNothing);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(fakeAuth.restoreSessionCallCount, 1);
    });

    testWidgets('Authenticated student routes directly to StudentDashboardScreen', (tester) async {
      final student = UserModel(
        id: 10,
        username: '23CS01',
        email: 'student@college.edu',
        role: 'STUDENT',
        isActive: true,
        fullName: 'Test Student',
      );
      fakeAuth.configure(user: student, hasStoredToken: true);

      await tester.pumpWidget(createSplashWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.byType(SplashScreen), findsNothing);
      expect(find.byType(StudentDashboardScreen), findsOneWidget);
      expect(fakeAuth.restoreSessionCallCount, 1);
    });

    testWidgets('Authenticated faculty routes directly to FacultyDashboardScreen', (tester) async {
      final faculty = UserModel(
        id: 20,
        username: 'FAC01',
        email: 'faculty@college.edu',
        role: 'FACULTY',
        isActive: true,
        fullName: 'Prof. Faculty',
        facultyProfileId: 5,
      );
      fakeAuth.configure(user: faculty, hasStoredToken: true);

      await tester.pumpWidget(createSplashWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.byType(SplashScreen), findsNothing);
      expect(find.byType(FacultyDashboardScreen), findsOneWidget);
      expect(fakeAuth.restoreSessionCallCount, 1);
    });

    testWidgets('Authenticated administrator routes to AdminStudentFaceScreen', (tester) async {
      final admin = UserModel(
        id: 1,
        username: 'ADMIN01',
        email: 'admin@college.edu',
        role: 'ADMIN',
        isActive: true,
        fullName: 'Principal Admin',
      );
      fakeAuth.configure(user: admin, hasStoredToken: true);

      await tester.pumpWidget(createSplashWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.byType(SplashScreen), findsNothing);
      expect(find.byType(AdminStudentFaceScreen), findsOneWidget);
      expect(fakeAuth.restoreSessionCallCount, 1);
    });

    testWidgets('Expired session routes securely to LoginScreen', (tester) async {
      fakeAuth.configure(user: null, sessionExpired: true, hasStoredToken: true);

      await tester.pumpWidget(createSplashWidget());
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(SplashScreen), findsNothing);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(fakeAuth.restoreSessionCallCount, 1);
    });

    testWidgets('Network failure with stored session displays retry banner without loop or session wipe', (tester) async {
      fakeAuth.configure(
        user: null,
        errorMessage: 'Unable to reach the server. Check your connection or server address.',
        sessionExpired: false,
        hasStoredToken: true,
      );

      await tester.pumpWidget(createSplashWidget());
      await tester.pump();
      await tester.pumpAndSettle();

      // Must remain on SplashScreen and show retry banner
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.text('Unable to reach the server. Check your connection or server address.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Go to Sign In'), findsOneWidget);

      // Tapping "Go to Sign In" takes user to LoginScreen
      await tester.tap(find.text('Go to Sign In'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('Rebuilds do not trigger duplicate routing', (tester) async {
      fakeAuth.configure(user: null);

      await tester.pumpWidget(createSplashWidget());
      await tester.pump();
      await tester.pumpAndSettle();

      // Trigger extra pumps/rebuilds
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(fakeAuth.restoreSessionCallCount, 1);
    });
  });

  group('Theme Service Initial Theme Preservation', () {
    test('ThemeService initializes with supplied initialMode', () {
      final sLight = ThemeService(initialThemeMode: ThemeMode.light);
      expect(sLight.themeMode, ThemeMode.light);
      expect(sLight.isDarkMode, false);

      final sDark = ThemeService(initialThemeMode: ThemeMode.dark);
      expect(sDark.themeMode, ThemeMode.dark);
      expect(sDark.isDarkMode, true);
    });
  });
}
