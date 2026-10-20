import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:attendance_marker_mobile/core/theme/theme_service.dart';
import 'package:attendance_marker_mobile/models/user_model.dart';
import 'package:attendance_marker_mobile/services/auth_service.dart';
import 'package:attendance_marker_mobile/faculty/screens/faculty_profile_screen.dart';
import 'package:attendance_marker_mobile/widgets/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockAuthForRedesignTest extends ChangeNotifier implements AuthService {
  UserModel _user;
  bool _isLoading = false;

  MockAuthForRedesignTest({required UserModel user}) : _user = user;

  @override
  UserModel? get currentUser => _user;
  @override
  bool get isAuthenticated => true;
  @override
  bool get isLoading => _isLoading;
  @override
  String? get errorMessage => null;

  @override
  Future<UserModel?> refreshCurrentUser() async => _user;

  @override
  Future<bool> updateFacultyProfile({
    String? fullName,
    String? email,
    String? phone,
    String? avatarId,
  }) async {
    _user = _user.copyWith(
      fullName: fullName ?? _user.fullName,
      email: email ?? _user.email,
      phone: phone ?? _user.phone,
      avatarId: avatarId ?? _user.avatarId,
    );
    notifyListeners();
    return true;
  }

  @override
  Future<bool> updateFacultyAvatar(String avatarId) async {
    _user = _user.copyWith(avatarId: avatarId);
    notifyListeners();
    return true;
  }

  @override
  Future<void> logout() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  final sampleFaculty = UserModel(
    id: 101,
    username: 'fac02',
    email: 'showmiya@institution.edu',
    fullName: 'Showmiya S',
    phone: '+91 94433 22110',
    role: 'FACULTY',
    isClassAdvisor: true,
    advisedClassName: 'II Year CSE - Section B',
    department: 'Computer Science and Engineering',
    employeeId: 'FAC_CS_101',
    isActive: true,
    avatarId: 'avatar_female_1',
  );

  Widget createTestWidget({
    required MockAuthForRedesignTest auth,
    required ThemeService themeService,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>.value(value: auth),
        ChangeNotifierProvider<ThemeService>.value(value: themeService),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: FacultyProfileScreen(),
        ),
      ),
    );
  }

  group('Faculty Profile Redesign & Viewport Consistency Tests', () {
    testWidgets('1. Verifies profile card hierarchy, elevated header, and details on mobile (390x844)', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final auth = MockAuthForRedesignTest(user: sampleFaculty);
      final theme = ThemeService();

      await tester.pumpWidget(createTestWidget(auth: auth, themeService: theme));
      await tester.pumpAndSettle();

      // Elevated Header Card
      expect(find.text('Showmiya S'), findsNWidgets(2)); // Header + Account Details
      expect(find.text('Identifier: fac02'), findsOneWidget);
      expect(find.text('Active Faculty Member'), findsOneWidget);
      expect(find.text('Edit Profile'), findsOneWidget);

      // Verify UserAvatarWidget with radius 46
      final avatarFinder = find.byType(UserAvatarWidget);
      expect(avatarFinder, findsOneWidget);
      final avatarWidget = tester.widget<UserAvatarWidget>(avatarFinder);
      expect(avatarWidget.radius, 46.0);
      expect(avatarWidget.showEditBadge, isTrue);

      // Account Details Card
      expect(find.text('Account Details'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('FAC_CS_101'), findsOneWidget);
      expect(find.text('showmiya@institution.edu'), findsOneWidget);
      expect(find.text('+91 94433 22110'), findsOneWidget);
      expect(find.text('Computer Science and Engineering'), findsOneWidget);
      expect(find.text('Class Advisor (II Year CSE - Section B)'), findsOneWidget);

      // Scroll to bottom
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -600));
      await tester.pumpAndSettle();

      // Session Information Card
      expect(find.text('Session Information'), findsOneWidget);
      expect(find.text('Authenticated Role'), findsOneWidget);
      expect(find.text('Advisory Authority'), findsOneWidget);

      // Appearance & Theme Card
      expect(find.text('Appearance & Theme'), findsOneWidget);
      expect(find.text('Warm Light'), findsOneWidget);
      expect(find.text('Obsidian Dark'), findsOneWidget);

      // Account Actions Card
      expect(find.text('Account Actions'), findsOneWidget);
      expect(find.text('Edit Profile Details'), findsOneWidget);
      expect(find.text('Change Password'), findsOneWidget);
      expect(find.text('Sign Out'), findsOneWidget);
    });

    testWidgets('2. Verifies Dark Mode theme switching and colors', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final auth = MockAuthForRedesignTest(user: sampleFaculty);
      final theme = ThemeService(initialThemeMode: ThemeMode.dark);

      await tester.pumpWidget(createTestWidget(auth: auth, themeService: theme));
      await tester.pumpAndSettle();

      expect(find.text('Showmiya S'), findsNWidgets(2));
      expect(find.text('Active Faculty Member'), findsOneWidget);

      // Scroll and Tap Light Theme Pill
      final lightPill = find.text('Warm Light');
      await tester.ensureVisible(lightPill);
      await tester.pumpAndSettle();
      expect(lightPill, findsOneWidget);
      await tester.tap(lightPill);
      await tester.pumpAndSettle();

      expect(theme.themeMode, ThemeMode.light);
    });

    testWidgets('3. Responsive constraint (maxWidth: 720.0) on Desktop (1680x900)', (tester) async {
      tester.view.physicalSize = const Size(1680, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final auth = MockAuthForRedesignTest(user: sampleFaculty);
      final theme = ThemeService();

      await tester.pumpWidget(createTestWidget(auth: auth, themeService: theme));
      await tester.pumpAndSettle();

      // Verify ConstrainedBox constraints
      final constrainedBoxFinder = find.byWidgetPredicate(
        (widget) => widget is ConstrainedBox && widget.constraints.maxWidth == 720.0,
      );
      expect(constrainedBoxFinder, findsOneWidget);

      // Verify header card width is centered and clamped <= 720
      final headerCard = find.byType(GlassCard).first;
      final renderBox = tester.renderObject<RenderBox>(headerCard);
      expect(renderBox.size.width, lessThanOrEqualTo(720.0));
    });

    final testViewports = <String, Size>{
      'Compact Mobile': const Size(360, 800),
      'Standard Mobile': const Size(390, 844),
      'Tablet': const Size(768, 1024),
      'Laptop': const Size(1366, 768),
      'Desktop': const Size(1680, 900),
    };

    for (final entry in testViewports.entries) {
      testWidgets('4. Multi-viewport validation across ${entry.key} (${entry.value.width.toInt()}x${entry.value.height.toInt()})', (tester) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final auth = MockAuthForRedesignTest(user: sampleFaculty);
        final theme = ThemeService();

        await tester.pumpWidget(createTestWidget(auth: auth, themeService: theme));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Showmiya S'), findsWidgets);
      });
    }
  });
}
