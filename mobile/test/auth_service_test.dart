import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_marker_mobile/models/user_model.dart';
import 'package:attendance_marker_mobile/models/student_model.dart';
import 'package:attendance_marker_mobile/models/faculty_model.dart';

void main() {
  group('Model Tests', () {
    test('UserModel deserializes student correctly', () {
      final json = {
        'id': 1,
        'username': '23DIS01',
        'email': 'student@test.com',
        'role': 'STUDENT',
        'is_active': true,
        'full_name': 'Disable Test',
      };
      final user = UserModel.fromJson(json);
      expect(user.id, 1);
      expect(user.isStudent, true);
      expect(user.isFaculty, false);
      expect(user.fullName, 'Disable Test');
    });

    test('UserModel deserializes faculty correctly', () {
      final json = {
        'id': 2,
        'username': 'FAC01',
        'email': 'fac@test.com',
        'role': 'FACULTY',
        'is_active': true,
        'full_name': 'Dr. Faculty',
        'faculty_profile_id': 10,
      };
      final user = UserModel.fromJson(json);
      expect(user.id, 2);
      expect(user.isStudent, false);
      expect(user.isFaculty, true);
      expect(user.facultyProfileId, 10);
    });

    test('StudentSummaryModel deserializes attendance summary correctly', () {
      final json = {
        'student_id': 5,
        'full_name': 'Alex Student',
        'register_number': 'REG001',
        'is_active': true,
        'total': 10,
        'present': 8,
        'absent': 2,
        'od': 0,
        'percentage': 80.0,
        'calculation_mode': 'RECORD_BASED',
        'attendance_status': 'OK',
        'minimum_required': 75.0,
        'below_minimum': false,
        'missable_future_classes': 1,
      };
      final summary = StudentSummaryModel.fromJson(json);
      expect(summary.studentId, 5);
      expect(summary.percentage, 80.0);
      expect(summary.belowMinimum, false);
      expect(summary.missableFutureClasses, 1);
    });

    test('FacultyScheduleItem deserializes schedule entry correctly', () {
      final json = {
        'id': 101,
        'day_of_week': 'MONDAY',
        'period_id': 1,
        'period_number': 1,
        'period_name': 'Period 1',
        'start_time': '09:00',
        'end_time': '09:50',
        'assignment_id': 12,
        'subject_code': '23CS101',
        'subject_name': 'Data Structures',
        'class_name': 'II Year CSE - Section A',
      };
      final item = FacultyScheduleItem.fromJson(json);
      expect(item.id, 101);
      expect(item.dayOfWeek, 'MONDAY');
      expect(item.periodNumber, 1);
      expect(item.subjectCode, '23CS101');
      expect(item.className, 'II Year CSE - Section A');
    });

    test('ActiveClassSlot deserializes active class slot correctly', () {
      final json = {
        'timetable_entry_id': 42,
        'assignment_id': 12,
        'day_of_week': 'MONDAY',
        'date': '2026-08-18',
        'period_number': 2,
        'period_name': 'Period 2',
        'start_time': '10:00',
        'end_time': '10:50',
        'subject_code': '23CS102',
        'subject_name': 'Algorithms',
        'class_name': 'II Year CSE - Section A',
        'class_id': 1,
        'subject_id': 3,
      };
      final slot = ActiveClassSlot.fromJson(json);
      expect(slot.timetableEntryId, 42);
      expect(slot.periodNumber, 2);
      expect(slot.subjectCode, '23CS102');
      expect(slot.subjectName, 'Algorithms');
    });
  });
}
