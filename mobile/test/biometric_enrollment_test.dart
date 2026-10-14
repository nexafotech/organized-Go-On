import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:attendance_marker_mobile/models/biometric_enrollment_model.dart';
import 'package:attendance_marker_mobile/models/student_model.dart';
import 'package:attendance_marker_mobile/services/biometric_enrollment_service.dart';
import 'package:attendance_marker_mobile/student/screens/biometric_enrollment_screen.dart';
import 'package:attendance_marker_mobile/student/screens/student_profile_screen.dart';
import 'package:attendance_marker_mobile/services/student_service.dart';
import 'package:attendance_marker_mobile/services/auth_service.dart';

class MockBiometricEnrollmentService extends ChangeNotifier implements BiometricEnrollmentService {
  EnrollmentStatusModel? _status;
  PoseValidationResultModel? _lastValidation;
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  MockBiometricEnrollmentService({EnrollmentStatusModel? initialStatus})
      : _status = initialStatus ??
            const EnrollmentStatusModel(
              status: 'ENROLLMENT_INCOMPLETE',
              templatesCount: 0,
              requiredTemplates: 3,
              completedSteps: [],
              nextStep: 'FRONTAL',
              message: 'Enrollment incomplete: 0 of 3 captures accepted.',
            );

  @override
  EnrollmentStatusModel? get status => _status;
  @override
  PoseValidationResultModel? get lastValidation => _lastValidation;
  @override
  bool get isLoading => _isLoading;
  @override
  String? get errorMessage => _errorMessage;
  @override
  String? get successMessage => _successMessage;

  @override
  Future<void> fetchEnrollmentStatus() async {}

  @override
  Future<PoseValidationResultModel?> validatePose(File imageFile, String step, {bool mirrored = false}) async => _lastValidation;

  @override
  Future<bool> captureTemplate(File imageFile, String step, {bool mirrored = false}) async => true;

  @override
  Future<bool> resetEnrollment() async {
    _status = const EnrollmentStatusModel(
      status: 'ENROLLMENT_INCOMPLETE',
      templatesCount: 0,
      requiredTemplates: 3,
      completedSteps: [],
      nextStep: 'FRONTAL',
      message: 'Enrollment incomplete: 0 of 3 captures accepted.',
    );
    notifyListeners();
    return true;
  }

  @override
  void clearValidation() {
    _lastValidation = null;
    notifyListeners();
  }
}

class MockStudentServiceForEnrollment extends ChangeNotifier implements StudentService {
  @override
  StudentSummaryModel? get summary => StudentSummaryModel.fromJson({
        'student_id': 1,
        'full_name': 'Akash A',
        'register_number': '721024149001',
        'email': 'akash@college.edu',
        'class_name': 'III Year CSE Cyber Security - Class 2',
        'semester': '5',
        'department': 'CSE Cyber Security',
        'is_active': true,
        'total': 10,
        'present': 9,
        'absent': 1,
        'od': 0,
        'percentage': 90.0,
        'attendance_status': 'OK',
        'calculation_mode': 'PERIOD_BASED',
        'minimum_required': 75.0,
        'below_minimum': false,
      });

  @override
  List<SubjectAttendanceModel> get subjects => [];
  @override
  List<TimetableItemModel> get timetable => [];
  @override
  List<DateWiseEntryModel> get dateWise => [];
  @override
  bool get isLoading => false;
  @override
  String? get errorMessage => null;

  @override
  Future<void> fetchStudentSummary() async {}
  @override
  Future<void> fetchSubjects() async {}
  @override
  Future<void> fetchTimetable() async {}
  @override
  Future<void> fetchAttendanceReport() async {}
  @override
  Future<void> fetchAttendanceReportFiltered({int? subjectId, String? startDate, String? endDate}) async {}
  @override
  Future<void> loadDashboardData() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Biometric Enrollment Model Tests', () {
    test('EnrollmentStatusModel parses initial incomplete state', () {
      final json = {
        'status': 'ENROLLMENT_INCOMPLETE',
        'templates_count': 0,
        'required_templates': 3,
        'completed_steps': [],
        'next_step': 'FRONTAL',
        'message': 'Enrollment incomplete: 0 of 3 captures accepted.',
        'student_id': 101,
        'register_number': '721024149001',
        'full_name': 'Akash A'
      };

      final model = EnrollmentStatusModel.fromJson(json);
      expect(model.status, 'ENROLLMENT_INCOMPLETE');
      expect(model.templatesCount, 0);
      expect(model.requiredTemplates, 3);
      expect(model.isFullyEnrolled, false);
      expect(model.progress, 0.0);
      expect(model.nextStep, 'FRONTAL');
    });

    test('EnrollmentStatusModel parses completed enrolled state', () {
      final json = {
        'status': 'ENROLLED',
        'templates_count': 3,
        'required_templates': 3,
        'completed_steps': ['FRONTAL', 'LEFT_15', 'RIGHT_15'],
        'next_step': null,
        'message': 'Face enrollment complete — 3 of 3 captures accepted.',
        'student_id': 101,
        'register_number': '721024149001',
        'full_name': 'Akash A'
      };

      final model = EnrollmentStatusModel.fromJson(json);
      expect(model.status, 'ENROLLED');
      expect(model.templatesCount, 3);
      expect(model.isFullyEnrolled, true);
      expect(model.progress, 1.0);
      expect(model.nextStep, isNull);
    });

    test('PoseValidationResultModel parses READY pose', () {
      final json = {
        'valid': true,
        'status': 'READY',
        'message': 'Face position is optimal. Ready for capture!',
        'guidance': ['Look directly at camera'],
        'step': 'FRONTAL',
        'pose': {'yaw': 0.5, 'pitch': -0.2, 'roll': 0.1},
        'face_box': {'top': 100, 'right': 300, 'bottom': 300, 'left': 100, 'width': 200, 'height': 200},
        'confidence': 0.98,
        'lighting': 'GOOD'
      };

      final model = PoseValidationResultModel.fromJson(json);
      expect(model.valid, true);
      expect(model.isReady, true);
      expect(model.status, 'READY');
      expect(model.pose?.yaw, 0.5);
      expect(model.faceBox?.width, 200);
      expect(model.confidence, 0.98);
    });

    test('PoseValidationResultModel parses POSE_TOO_LEFT state', () {
      final json = {
        'valid': false,
        'status': 'POSE_TOO_LEFT',
        'message': 'Turn your head slightly to the RIGHT to face directly forward.',
        'guidance': [],
        'step': 'FRONTAL',
        'pose': {'yaw': -12.5, 'pitch': 0.0, 'roll': 0.0},
      };

      final model = PoseValidationResultModel.fromJson(json);
      expect(model.valid, false);
      expect(model.isReady, false);
      expect(model.status, 'POSE_TOO_LEFT');
      expect(model.pose?.yaw, -12.5);
    });
  });

  group('Biometric Enrollment UI Widget Tests', () {
    testWidgets('Renders capture protocol guidelines dialog on launch', (WidgetTester tester) async {
      final mockService = MockBiometricEnrollmentService();

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<BiometricEnrollmentService>.value(
            value: mockService,
            child: const BiometricEnrollmentScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check instructions modal text
      expect(find.text('Face Capture Protocol'), findsOneWidget);
      expect(find.text('Before starting:'), findsOneWidget);
      expect(find.text('• Use good, even lighting.'), findsOneWidget);
      expect(find.text('• Keep the camera at eye level.'), findsOneWidget);
      expect(find.text('1. Straight / Front (0° ±5°)'), findsOneWidget);
      expect(find.text('2. Slight Left (~15° ±5°)'), findsOneWidget);
      expect(find.text('3. Slight Right (~15° ±5°)'), findsOneWidget);

      // Dismiss dialog
      expect(find.text('Start Enrollment'), findsOneWidget);
      await tester.ensureVisible(find.text('Start Enrollment'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start Enrollment'));
      await tester.pumpAndSettle();

      // Verify Step 1 Frontal Reference card is displayed
      expect(find.text('Step 1 of 3: Frontal Reference'), findsOneWidget);
      expect(find.text('Target: 0° ±5° (Center)'), findsOneWidget);
      expect(find.text('0 / 3 Captures'), findsOneWidget);
      expect(find.text('Look directly at the camera.'), findsOneWidget);
      expect(find.text('Take Photo for FRONTAL'), findsOneWidget);
    });

    testWidgets('Student profile screen renders Biometric Face Enrollment button and navigates', (WidgetTester tester) async {
      final mockAuth = AuthService();
      final mockStudent = MockStudentServiceForEnrollment();
      final mockEnrollment = MockBiometricEnrollmentService();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthService>.value(value: mockAuth),
            ChangeNotifierProvider<StudentService>.value(value: mockStudent),
            ChangeNotifierProvider<BiometricEnrollmentService>.value(value: mockEnrollment),
          ],
          child: const MaterialApp(
            home: Scaffold(body: StudentProfileScreen()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check for Biometric Face Enrollment button in profile
      expect(find.text('Biometric Face Enrollment'), findsOneWidget);
      expect(find.byIcon(Icons.face_retouching_natural_rounded), findsOneWidget);

      // Scroll into view and tap to navigate to enrollment screen
      await tester.ensureVisible(find.text('Biometric Face Enrollment'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Biometric Face Enrollment'));
      await tester.pumpAndSettle();

      // Should render the BiometricEnrollmentScreen with instructions modal
      expect(find.text('Face Capture Protocol'), findsOneWidget);
    });
  });
}
