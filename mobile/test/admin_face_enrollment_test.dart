import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:attendance_marker_mobile/models/admin_biometric_model.dart';
import 'package:attendance_marker_mobile/services/admin_service.dart';
import 'package:attendance_marker_mobile/services/auth_service.dart';
import 'package:attendance_marker_mobile/admin/screens/admin_student_face_screen.dart';

void main() {
  group('Admin Biometric Models Unit Tests', () {
    test('AdminStudentBioModel parses JSON correctly for enrolled student', () {
      final json = {
        'student_id': 1,
        'roll_number': '721025149001',
        'full_name': 'ABINAYA B',
        'class_name': 'B.E. II CSE',
        'enrolled': true,
        'template_count': 3,
        'model_name': 'dlib_resnet',
        'detector_name': 'dlib_hog',
        'last_enrollment_at': '2026-10-05T10:00:00',
      };

      final model = AdminStudentBioModel.fromJson(json);

      expect(model.studentId, 1);
      expect(model.rollNumber, '721025149001');
      expect(model.fullName, 'ABINAYA B');
      expect(model.className, 'B.E. II CSE');
      expect(model.enrolled, true);
      expect(model.templateCount, 3);
      expect(model.modelName, 'dlib_resnet');
      expect(model.detectorName, 'dlib_hog');
      expect(model.lastEnrollmentAt, '2026-10-05T10:00:00');
    });

    test('AdminStudentBioModel parses JSON correctly for unenrolled student', () {
      final json = {
        'student_id': 2,
        'roll_number': '721025149002',
        'full_name': 'ABISHEK A',
        'class_name': null,
        'enrolled': false,
        'template_count': 0,
      };

      final model = AdminStudentBioModel.fromJson(json);

      expect(model.studentId, 2);
      expect(model.rollNumber, '721025149002');
      expect(model.fullName, 'ABISHEK A');
      expect(model.className, isNull);
      expect(model.enrolled, false);
      expect(model.templateCount, 0);
    });

    test('AdminStudentBioDetailModel parses JSON correctly', () {
      final json = {
        'student_id': 3,
        'full_name': 'AKASH K',
        'roll_number': '721025149003',
        'class_name': 'B.E. II CSE',
        'enrolled': true,
        'template_count': 1,
        'required_templates': 1,
        'last_enrollment_time': '2026-10-05T11:00:00',
      };

      final detail = AdminStudentBioDetailModel.fromJson(json);

      expect(detail.studentId, 3);
      expect(detail.fullName, 'AKASH K');
      expect(detail.rollNumber, '721025149003');
      expect(detail.enrolled, true);
      expect(detail.templateCount, 1);
      expect(detail.requiredTemplates, 1);
      expect(detail.lastEnrollmentTime, '2026-10-05T11:00:00');
    });

    test('AdminBioOverviewModel parses summary statistics', () {
      final json = {
        'total_students': 119,
        'enrolled_count': 45,
        'pending_count': 74,
        'model_name': 'dlib_resnet',
        'detector_name': 'dlib_hog',
        'dimension': 128,
      };

      final overview = AdminBioOverviewModel.fromJson(json);

      expect(overview.totalStudents, 119);
      expect(overview.enrolledCount, 45);
      expect(overview.pendingCount, 74);
      expect(overview.modelName, 'dlib_resnet');
      expect(overview.dimension, 128);
    });

    test('StudentDatasetViewModel parses JSON correctly', () {
      final json = {
        'student_id': 10,
        'roll_number': '721025149046',
        'full_name': 'RETHISH S',
        'class_name': 'B.E. II CSE',
        'enrolled': true,
        'photo_count': 4,
        'template_count': 4,
        'photos': [
          {
            'embedding_id': 101,
            'filename': 'photo_001.jpg',
            'image_path': 'data/student_faces/721025149046/photo_001.jpg',
            'created_at': '2026-10-05T12:00:00',
            'quality_score': 0.95,
          },
          {
            'embedding_id': 102,
            'filename': 'photo_002.jpg',
            'image_path': 'data/student_faces/721025149046/photo_002.jpg',
            'created_at': '2026-10-05T12:01:00',
            'quality_score': 0.92,
          }
        ]
      };

      final dataset = StudentDatasetViewModel.fromJson(json);

      expect(dataset.studentId, 10);
      expect(dataset.rollNumber, '721025149046');
      expect(dataset.fullName, 'RETHISH S');
      expect(dataset.enrolled, true);
      expect(dataset.photoCount, 4);
      expect(dataset.templateCount, 4);
      expect(dataset.photos.length, 2);
      expect(dataset.photos[0].embeddingId, 101);
      expect(dataset.photos[0].filename, 'photo_001.jpg');
      expect(dataset.photos[0].imagePath, 'data/student_faces/721025149046/photo_001.jpg');
      expect(dataset.photos[0].qualityScore, 0.95);
    });

    test('MultiPhotoEnrollResponseModel parses batch upload response correctly', () {
      final json = {
        'student_id': 10,
        'roll_number': '721025149046',
        'full_name': 'RETHISH S',
        'total_files': 3,
        'valid_enrolled': 2,
        'rejected': 1,
        'replaced_old_count': 0,
        'message': 'Successfully enrolled 2 new face photos for RETHISH S',
        'items': [
          {
            'filename': 'img1.jpg',
            'status': 'ENROLLED',
            'reason': null,
            'faces_detected': 1,
            'embedding_id': 105,
            'saved_path': 'data/student_faces/721025149046/img1.jpg',
          },
          {
            'filename': 'img2.jpg',
            'status': 'REJECTED_NO_FACE',
            'reason': 'No face detected',
            'faces_detected': 0,
            'embedding_id': null,
            'saved_path': null,
          }
        ]
      };

      final res = MultiPhotoEnrollResponseModel.fromJson(json);

      expect(res.studentId, 10);
      expect(res.rollNumber, '721025149046');
      expect(res.totalFiles, 3);
      expect(res.validEnrolled, 2);
      expect(res.rejected, 1);
      expect(res.items.length, 2);
      expect(res.items[0].status, 'ENROLLED');
      expect(res.items[0].embeddingId, 105);
      expect(res.items[1].status, 'REJECTED_NO_FACE');
    });
  });

  group('AdminService Unit Tests', () {
    test('Initial state is clean', () {
      final service = AdminService();

      expect(service.students, isEmpty);
      expect(service.overview, isNull);
      expect(service.selectedStudentDetail, isNull);
      expect(service.isLoading, false);
      expect(service.isActionLoading, false);
      expect(service.errorMessage, isNull);
      expect(service.successMessage, isNull);
    });

    test('clearMessages clears error and success', () {
      final service = AdminService();
      service.clearMessages();

      expect(service.errorMessage, isNull);
      expect(service.successMessage, isNull);
    });
  });

  group('AdminStudentFaceScreen Widget Tests', () {
    testWidgets('Renders Admin Face Management header and search bar', (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AdminService>(create: (_) => AdminService()),
            ChangeNotifierProvider<AuthService>(create: (_) => AuthService()),
          ],
          child: const MaterialApp(
            home: AdminStudentFaceScreen(),
          ),
        ),
      );

      // Verify title & subtitle
      expect(find.text('Admin Face Management'), findsOneWidget);
      expect(find.text('Institutional Biometric Control'), findsOneWidget);

      // Verify quick stats labels
      expect(find.text('Total Students'), findsOneWidget);
      expect(find.text('Enrolled'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);

      // Verify search input
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Search student name or roll number...'), findsOneWidget);

      // Verify filter chips
      expect(find.text('All Students'), findsOneWidget);
      expect(find.text('Enrolled Only'), findsOneWidget);
      expect(find.text('Pending Only'), findsOneWidget);
    });
  });
}
