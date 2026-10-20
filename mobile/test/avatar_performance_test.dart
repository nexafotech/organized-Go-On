import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:attendance_marker_mobile/core/network/api_client.dart';
import 'package:attendance_marker_mobile/core/storage/secure_storage.dart';
import 'package:attendance_marker_mobile/core/theme/app_theme.dart';
import 'package:attendance_marker_mobile/models/student_model.dart';
import 'package:attendance_marker_mobile/models/user_model.dart';
import 'package:attendance_marker_mobile/services/auth_service.dart';
import 'package:attendance_marker_mobile/services/student_service.dart';
import 'package:attendance_marker_mobile/widgets/avatar/avatar_picker_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Avatar Performance & Selection Tests', () {
    Widget buildSheetHarness({
      required String currentAvatarId,
      required String userSeed,
      required Future<bool> Function(String selectedAvatarId) onSave,
      ThemeData? theme,
    }) {
      return MaterialApp(
        theme: theme ?? AppTheme.darkTheme,
        home: Scaffold(
          body: Center(
            child: AvatarPickerSheet(
              currentAvatarId: currentAvatarId,
              userSeed: userSeed,
              onSave: onSave,
            ),
          ),
        ),
      );
    }

    testWidgets('Instant tap selection updates preview card and selection checkmark', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      String? savedId;

      await tester.pumpWidget(buildSheetHarness(
        currentAvatarId: 'avatar_m1',
        userSeed: 'CS2021001',
        onSave: (id) async {
          savedId = id;
          return true;
        },
      ));
      await tester.pumpAndSettle();

      // Initial state has 'Curly Cream Hoodie' in preview
      expect(find.text('Curly Cream Hoodie'), findsOneWidget);

      // Tap on second avatar in the grid (avatar_m2)
      final secondCard = find.byKey(const ValueKey('avatar_m2'));
      expect(secondCard, findsOneWidget);

      await tester.tap(secondCard);
      await tester.pump(); // Immediate frame without pumpAndSettle

      // Preview card title should immediately update to avatar_m2
      final m2 = AvatarItemModel.findById('avatar_m2');
      expect(find.text(m2.name), findsOneWidget);

      // Save button should save avatar_m2
      await tester.tap(find.text('Save Avatar'));
      await tester.pumpAndSettle();

      expect(savedId, equals('avatar_m2'));
    });

    testWidgets('Unchanged avatar fast-path closes immediately without triggering onSave', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool onSaveCalled = false;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () {
                AvatarPickerSheet.show(
                  context: ctx,
                  currentAvatarId: 'avatar_m1',
                  userSeed: 'CS2021001',
                  onSave: (id) async {
                    onSaveCalled = true;
                    return true;
                  },
                );
              },
              child: const Text('Open Sheet'),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Open sheet
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();
      expect(find.text('Choose Your Avatar'), findsOneWidget);

      // Without tapping another avatar, tap Save Avatar
      await tester.tap(find.text('Save Avatar'));
      await tester.pumpAndSettle();

      // Sheet should have popped immediately and onSave was NOT called
      expect(onSaveCalled, isFalse);
      expect(find.text('Choose Your Avatar'), findsNothing);
    });

    testWidgets('Save button shows loading indicator and prevents concurrent duplicate saves', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      int saveCallCount = 0;
      final completer = Completer<bool>();

      await tester.pumpWidget(buildSheetHarness(
        currentAvatarId: 'avatar_m1',
        userSeed: 'CS2021001',
        onSave: (id) async {
          saveCallCount++;
          return completer.future;
        },
      ));
      await tester.pumpAndSettle();

      // Select a different avatar to trigger real save
      await tester.tap(find.byKey(const ValueKey('avatar_m2')));
      await tester.pump();

      // Tap Save Avatar once
      await tester.tap(find.text('Save Avatar'));
      await tester.pump();

      // Spinner should be visible
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(saveCallCount, equals(1));

      // Tap Save button again while loading
      await tester.tap(find.byType(CircularProgressIndicator));
      await tester.pump();

      // saveCallCount must still be 1 (duplicate click ignored)
      expect(saveCallCount, equals(1));

      // Complete save
      completer.complete(true);
      await tester.pump(); // Immediate frame before pop timer fires

      expect(find.text('Avatar updated successfully!'), findsOneWidget);

      await tester.pumpAndSettle(); // Let dismiss finish
    });

    testWidgets('Error handling recovers from failed save with readable banner and retry button', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0; // Viewport 1080x2400
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      int attempt = 0;

      await tester.pumpWidget(buildSheetHarness(
        currentAvatarId: 'avatar_m1',
        userSeed: 'CS2021001',
        onSave: (id) async {
          attempt++;
          if (attempt == 1) {
            return false; // First attempt fails
          }
          return true; // Second attempt succeeds
        },
      ));
      await tester.pumpAndSettle();

      // Select avatar_m2 (different from m1)
      await tester.tap(find.byKey(const ValueKey('avatar_m2')));
      await tester.pump();

      // Tap Save
      await tester.tap(find.text('Save Avatar'));
      await tester.pumpAndSettle();

      // Should display failure message and Retry button
      expect(find.text('Failed to save avatar. Please try again.'), findsOneWidget);
      final retryFinder = find.text('Retry');
      expect(retryFinder, findsOneWidget);
      // Spinner must NOT be stuck
      expect(find.byType(CircularProgressIndicator), findsNothing);

      // Scroll into view if needed and tap Retry
      await tester.ensureVisible(retryFinder);
      await tester.tap(retryFinder);
      await tester.pump();

      expect(attempt, equals(2));
      await tester.pump();
      expect(find.text('Avatar updated successfully!'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
    });

    testWidgets('Exception during onSave is cleanly caught and clears spinner', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildSheetHarness(
        currentAvatarId: 'avatar_m1',
        userSeed: 'CS2021001',
        onSave: (id) async {
          throw Exception('Network disconnected');
        },
      ));
      await tester.pumpAndSettle();

      // Select avatar_m2
      await tester.tap(find.byKey(const ValueKey('avatar_m2')));
      await tester.pump();

      // Save
      await tester.tap(find.text('Save Avatar'));
      await tester.pumpAndSettle();

      // Spinner must NOT be spinning forever
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Save Avatar'), findsOneWidget);
    });

    testWidgets('Renders properly in Warm Light theme', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildSheetHarness(
        currentAvatarId: 'avatar_f1',
        userSeed: 'CS2021002',
        onSave: (id) async => true,
        theme: AppTheme.lightTheme,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Choose Your Avatar'), findsOneWidget);
      expect(find.byKey(const ValueKey('avatar_f1')), findsOneWidget);
    });
  });

  group('Optimistic Avatar Persistence & Rollback Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('StudentService performs optimistic avatar update and rolls back on server failure', () async {
      bool shouldFail = false;
      final mockClient = MockClient((request) async {
        if (shouldFail) {
          return http.Response(jsonEncode({'detail': 'Server error'}), 500, headers: {'content-type': 'application/json'});
        }
        return http.Response(jsonEncode({'success': true, 'avatar_id': 'avatar_f2'}), 200, headers: {'content-type': 'application/json'});
      });

      final mockStorage = _TestMockSecureStorage();
      final apiClient = ApiClient(httpClient: mockClient, secureStorage: mockStorage);
      final studentService = StudentService(apiClient: apiClient);
      studentService.setMockData(
        summary: StudentSummaryModel(
          studentId: 1,
          fullName: 'Test Student',
          registerNumber: 'CS2021001',
          isActive: true,
          total: 100,
          present: 85,
          absent: 15,
          od: 0,
          percentage: 85.0,
          calculationMode: 'PERIOD',
          attendanceStatus: 'On Track',
          minimumRequired: 75.0,
          belowMinimum: false,
          avatarId: 'avatar_m1',
        ),
      );

      expect(studentService.summary?.avatarId, equals('avatar_m1'));

      // 1. Success case: updates optimistically and stays
      final success = await studentService.updateAvatar('avatar_f2');
      expect(success, isTrue);
      expect(studentService.summary?.avatarId, equals('avatar_f2'));

      // 2. Unchanged fast-path: returns true immediately
      final fastSuccess = await studentService.updateAvatar('avatar_f2');
      expect(fastSuccess, isTrue);
      expect(studentService.summary?.avatarId, equals('avatar_f2'));

      // 3. Failure case: optimistically changes then rolls back on error
      shouldFail = true;
      try {
        await studentService.updateAvatar('avatar_m3');
        fail('Should have thrown an exception');
      } catch (_) {
        // Rollback check: must revert to avatar_f2
        expect(studentService.summary?.avatarId, equals('avatar_f2'));
      }
    });

    test('AuthService performs optimistic faculty avatar update and rolls back on failure', () async {
      bool shouldFail = false;
      final mockClient = MockClient((request) async {
        if (shouldFail) {
          return http.Response(jsonEncode({'detail': 'Internal error'}), 500, headers: {'content-type': 'application/json'});
        }
        return http.Response(jsonEncode({'success': true, 'avatar_id': 'avatar_f4'}), 200, headers: {'content-type': 'application/json'});
      });

      final mockStorage = _TestMockSecureStorage();
      final apiClient = ApiClient(httpClient: mockClient, secureStorage: mockStorage);
      final authService = AuthService(apiClient: apiClient, secureStorage: mockStorage);
      authService.setInitialCachedUser(
        UserModel(
          id: 10,
          username: 'FAC_101',
          fullName: 'Dr. Faculty Member',
          email: 'faculty@college.edu',
          role: 'faculty',
          isActive: true,
          avatarId: 'avatar_m1',
        ),
      );

      expect(authService.currentUser?.avatarId, equals('avatar_m1'));

      // 1. Success case
      final success = await authService.updateFacultyAvatar('avatar_f4');
      expect(success, isTrue);
      expect(authService.currentUser?.avatarId, equals('avatar_f4'));

      // 2. Fast-path unchanged
      final fast = await authService.updateFacultyAvatar('avatar_f4');
      expect(fast, isTrue);
      expect(authService.currentUser?.avatarId, equals('avatar_f4'));

      // 3. Failure case rolls back to avatar_f4
      shouldFail = true;
      try {
        await authService.updateFacultyAvatar('avatar_m5');
        fail('Should have thrown exception');
      } catch (_) {
        expect(authService.currentUser?.avatarId, equals('avatar_f4'));
      }
    });
  });
}

class _TestMockSecureStorage extends SecureStorageService {
  String? _token = 'test_token_123';

  @override
  Future<String?> getAccessToken() async => _token;

  @override
  Future<void> saveAccessToken(String token) async {
    _token = token;
  }

  @override
  Future<void> deleteAccessToken() async {
    _token = null;
  }

  @override
  Future<void> clearSession() async {
    _token = null;
  }
}

