import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_marker_mobile/models/student_model.dart';
import 'package:attendance_marker_mobile/models/faculty_report_model.dart';
import 'package:attendance_marker_mobile/widgets/attendance/period_status_chip.dart';
import 'package:attendance_marker_mobile/widgets/attendance/attendance_legend.dart';
import 'package:attendance_marker_mobile/widgets/attendance/attendance_summary_card.dart';


void main() {
  group('Attendance Report Models', () {
    test('DateWiseEntryModel parses morningSummary and afternoonSummary correctly', () {
      final json = {
        'date': '2026-09-28',
        'morning_status': 'PRESENT',
        'morning_summary': '4/4 Present (Full)',
        'afternoon_status': 'PRESENT',
        'afternoon_summary': '3/3 Present (Full)',
        'daily_result': 'FULL_DAY_PRESENT',
        'lunch_interval': '12:50 PM - 01:40 PM (Not Counted)',
        'periods': [
          {
            'period_number': 1,
            'period_name': 'Period 1',
            'subject_code': '23CS301',
            'subject_name': 'Data Structures',
            'status': 'PRESENT',
          },
          {
            'period_number': 5,
            'period_name': 'Period 5',
            'subject_code': '23CS302',
            'subject_name': 'Operating Systems',
            'status': 'OD',
            'od_reason': 'Sports Meet',
          },
        ],
      };

      final model = DateWiseEntryModel.fromJson(json);
      expect(model.date, '2026-09-28');
      expect(model.morningSummary, '4/4 Present (Full)');
      expect(model.afternoonSummary, '3/3 Present (Full)');
      expect(model.dailyResult, 'FULL_DAY_PRESENT');
      expect(model.lunchInterval, contains('Not Counted'));
      expect(model.periods.length, 2);
      expect(model.periods[0].status, 'PRESENT');
      expect(model.periods[1].status, 'OD');
      expect(model.periods[1].odReason, 'Sports Meet');
    });

    test('FacultyAuthorizedReportOptionsModel parses correctly', () {
      final json = {
        'faculty_id': 1,
        'faculty_name': 'Dr. Advisor',
        'is_class_advisor': true,
        'advised_class': {
          'id': 4,
          'name': 'Class 4',
          'department': 'CSE',
        },
        'classes': [
          {
            'id': 4,
            'name': 'Class 4',
            'is_advisor_for_class': true,
            'subjects': [
              {
                'id': 101,
                'code': '23CS301',
                'name': 'Data Structures',
                'is_teaching': true,
              }
            ],
          }
        ],
      };

      final model = FacultyAuthorizedReportOptionsModel.fromJson(json);
      expect(model.facultyId, 1);
      expect(model.isClassAdvisor, true);
      expect(model.advisedClass?.name, 'Class 4');
      expect(model.classes.length, 1);
      expect(model.classes[0].isAdvisorForClass, true);
      expect(model.classes[0].subjects.first.code, '23CS301');
    });

    test('FacultyClassSummaryModel parses aggregate and students list', () {
      final json = {
        'class_id': 4,
        'class_name': 'Class 4',
        'subject_id': null,
        'subject_code': null,
        'subject_name': null,
        'is_class_advisor_scope': true,
        'total_periods': 14,
        'present': 12,
        'absent': 1,
        'od': 1,
        'percentage': 92.86,
        'students': [
          {
            'student_id': 10,
            'roll_number': '25CS001',
            'full_name': 'Alice',
            'total': 14,
            'present': 13,
            'absent': 1,
            'od': 0,
            'percentage': 92.86,
          }
        ],
      };

      final model = FacultyClassSummaryModel.fromJson(json);
      expect(model.classId, 4);
      expect(model.totalPeriods, 14);
      expect(model.percentage, 92.86);
      expect(model.students.length, 1);
      expect(model.students[0].fullName, 'Alice');
    });

    test('FacultyDateMatrixModel parses period headers and student rows', () {
      final json = {
        'class_id': 4,
        'class_name': 'Class 4',
        'subject_id': 15,
        'subject_code': 'DMC',
        'subject_name': 'Discrete Math',
        'is_class_advisor_scope': false,
        'date': '2026-10-01',
        'day_of_week': 'THURSDAY',
        'periods': [
          {
            'period_number': 1,
            'period_name': 'Period 1',
            'start_time': '09:10',
            'end_time': '10:00',
            'subject_code': 'DMC',
            'subject_name': 'Discrete Math',
            'status': 'MARKED',
            'present_count': 60,
            'absent_count': 6,
            'od_count': 0,
            'total_marked': 66,
          }
        ],
        'lunch_break': {
          'start_time': '12:50',
          'end_time': '13:40',
          'is_attendance_period': false,
          'display_text': 'Not Counted',
        },
        'students': [
          {
            'student_id': 10,
            'roll_number': '25CS001',
            'full_name': 'Alice',
            'period_statuses': {'1': 'PRESENT'},
            'morning_status': 'PRESENT',
            'afternoon_status': 'PRESENT',
            'daily_result': 'PRESENT',
          }
        ],
      };

      final model = FacultyDateMatrixModel.fromJson(json);
      expect(model.classId, 4);
      expect(model.subjectId, 15);
      expect(model.subjectCode, 'DMC');
      expect(model.isClassAdvisorScope, false);
      expect(model.lunchInterval, contains('Not Counted'));
      expect(model.periods.length, 1);
      expect(model.students.length, 1);
      expect(model.students[0].periodStatuses['1'], 'PRESENT');
      expect(model.students[0].dailyResult, 'PRESENT');
    });

    test('FacultyHistoricalMatrixModel parses date breakdown and aggregate students', () {
      final json = {
        'class_id': 4,
        'class_name': 'Class 4',
        'subject_id': 15,
        'subject_code': 'DMC',
        'subject_name': 'Discrete Math',
        'is_class_advisor_scope': false,
        'attendance_start_date': '2026-10-01',
        'current_date': '2026-10-01',
        'start_date': '2026-10-01',
        'end_date': '2026-10-01',
        'total_dates': 1,
        'dates': [
          {
            'date': '2026-10-01',
            'day_of_week': 'THURSDAY',
            'periods': [
              {
                'period_number': 1,
                'period_name': 'Period 1',
                'start_time': '09:10',
                'end_time': '10:00',
                'subject_code': 'DMC',
                'status': 'MARKED',
              }
            ],
            'lunch_break': {
              'start_time': '12:50',
              'end_time': '13:40',
              'display_text': 'Not Counted',
            },
            'students': [
              {
                'student_id': 10,
                'roll_number': '25CS001',
                'full_name': 'Alice',
                'period_statuses': {'1': 'PRESENT'},
                'morning_status': 'PRESENT',
                'afternoon_status': 'PRESENT',
                'daily_result': 'PRESENT',
              }
            ],
            'has_scheduled_classes': true,
          }
        ],
        'students': [
          {
            'student_id': 10,
            'roll_number': '25CS001',
            'full_name': 'Alice',
            'total': 1,
            'present': 1,
            'absent': 0,
            'od': 0,
            'percentage': 100.0,
          }
        ],
      };

      final model = FacultyHistoricalMatrixModel.fromJson(json);
      expect(model.classId, 4);
      expect(model.attendanceStartDate, '2026-10-01');
      expect(model.currentDate, '2026-10-01');
      expect(model.totalDates, 1);
      expect(model.dates.length, 1);
      expect(model.dates.first.hasScheduledClasses, true);
      expect(model.dates.first.periods.length, 1);
      expect(model.students.length, 1);
      expect(model.students.first.percentage, 100.0);
    });

    test('AttendanceRangeReportModel parses full range dataset correctly', () {
      final json = {
        'class_id': 1,
        'class_name': 'II Year CSE - Class 1',
        'subject_id': 101,
        'subject_code': '23CS301',
        'subject_name': 'Data Structures',
        'scope_note': null,
        'from_date': '2026-09-21',
        'to_date': '2026-09-28',
        'total_days': 8,
        'is_single_day': false,
        'has_records': true,
        'total_students': 2,
        'total_periods_conducted': 3,
        'present': 5,
        'absent': 1,
        'od': 1,
        'total_marked': 7,
        'percentage': 85.71,
        'percentage_basis': 'Attendance % = (Present + OD) / Total Marked.',
        'generated_at': '2026-10-06T12:00:00Z',
        'summary': [
          {
            'roll_number': '721025149001',
            'full_name': 'Alice Student',
            'present': 2,
            'absent': 1,
            'od': 0,
            'total_marked': 3,
            'percentage': 66.67,
          },
          {
            'roll_number': '721025149002',
            'full_name': 'Bob Student',
            'present': 3,
            'absent': 0,
            'od': 1,
            'total_marked': 4,
            'percentage': 100.0,
          },
        ],
        'period_summary': [
          {
            'date': '2026-09-21',
            'period_number': 1,
            'period_name': 'Period 1',
            'subject_code': '23CS301',
            'subject_name': 'Data Structures',
            'present': 2,
            'absent': 0,
            'od': 1,
            'total_marked': 3,
          },
        ],
      };

      final model = AttendanceRangeReportModel.fromJson(json);
      expect(model.classId, 1);
      expect(model.className, 'II Year CSE - Class 1');
      expect(model.subjectId, 101);
      expect(model.subjectCode, '23CS301');
      expect(model.fromDate, '2026-09-21');
      expect(model.toDate, '2026-09-28');
      expect(model.hasRecords, true);
      expect(model.totalMarked, 7);
      expect(model.percentage, 85.71);
      expect(model.summary.length, 2);
      expect(model.summary[0].rollNumber, '721025149001');
      expect(model.summary[0].percentage, 66.67);
      expect(model.summary[1].rollNumber, '721025149002');
      expect(model.summary[1].percentage, 100.0);
      expect(model.periodSummary.length, 1);
      expect(model.periodSummary[0].periodName, 'Period 1');
    });


    test('FacultyDateMatrixModel hasAttendanceRecords correctly differentiates recorded vs unrecorded dates', () {
      final unrecordedJson = {
        'class_id': 4,
        'class_name': 'Class 4',
        'date': '2026-10-01',
        'day_of_week': 'THURSDAY',
        'periods': [
          {
            'period_number': 1,
            'period_name': 'P1',
            'start_time': '09:10',
            'end_time': '10:00',
            'status': 'PENDING',
            'total_marked': 0,
          },
        ],
        'students': [
          {
            'student_id': 1,
            'roll_number': '25CS001',
            'full_name': 'Alice',
            'period_statuses': {'1': 'NOT_ENTERED'},
            'morning_status': 'NOT_ENTERED',
            'afternoon_status': 'NOT_ENTERED',
            'daily_result': 'NOT ENTERED',
          },
        ],
      };
      final unrecorded = FacultyDateMatrixModel.fromJson(unrecordedJson);
      expect(unrecorded.hasAttendanceRecords, isFalse);

      final recordedJson = {
        'class_id': 4,
        'class_name': 'Class 4',
        'date': '2026-10-05',
        'day_of_week': 'MONDAY',
        'periods': [
          {
            'period_number': 1,
            'period_name': 'P1',
            'start_time': '09:10',
            'end_time': '10:00',
            'status': 'MARKED',
            'total_marked': 60,
          },
        ],
        'students': [
          {
            'student_id': 1,
            'roll_number': '25CS001',
            'full_name': 'Alice',
            'period_statuses': {'1': 'PRESENT'},
            'morning_status': 'PRESENT',
            'afternoon_status': 'PRESENT',
            'daily_result': 'FULL DAY PRESENT',
          },
        ],
      };
      final recorded = FacultyDateMatrixModel.fromJson(recordedJson);
      expect(recorded.hasAttendanceRecords, isTrue);

      // Recorded date where all students are marked ABSENT
      final allAbsentJson = {
        'class_id': 4,
        'class_name': 'Class 4',
        'date': '2026-10-05',
        'day_of_week': 'MONDAY',
        'periods': [
          {
            'period_number': 1,
            'period_name': 'P1',
            'start_time': '09:10',
            'end_time': '10:00',
            'status': 'MARKED',
            'total_marked': 64,
            'absent_count': 64,
          },
        ],
        'students': [
          {
            'student_id': 1,
            'roll_number': '25CS001',
            'full_name': 'Alice',
            'period_statuses': {'1': 'ABSENT'},
            'morning_status': 'ABSENT',
            'afternoon_status': 'ABSENT',
            'daily_result': 'FULL DAY ABSENT',
          },
        ],
      };
      final allAbsent = FacultyDateMatrixModel.fromJson(allAbsentJson);
      expect(allAbsent.hasAttendanceRecords, isTrue);
    });

    test('FacultyClassSummaryModel hasAttendanceRecords correctly identifies unrecorded class summary', () {
      final emptySummary = FacultyClassSummaryModel(
        classId: 4,
        className: 'Class 4',
        totalPeriods: 0,
        present: 0,
        absent: 0,
        od: 0,
        percentage: 0.0,
        students: [],
      );
      expect(emptySummary.hasAttendanceRecords, isFalse);

      final activeSummary = FacultyClassSummaryModel(
        classId: 4,
        className: 'Class 4',
        totalPeriods: 10,
        present: 8,
        absent: 2,
        od: 0,
        percentage: 80.0,
        students: [],
      );
      expect(activeSummary.hasAttendanceRecords, isTrue);
    });

    test('FacultyHistoricalMatrixModel hasAttendanceRecords identifies empty range', () {
      final emptyHist = FacultyHistoricalMatrixModel(
        classId: 4,
        className: 'Class 4',
        attendanceStartDate: '2026-10-01',
        currentDate: '2026-10-06',
        startDate: '2026-10-01',
        endDate: '2026-10-06',
        totalDates: 0,
        dates: [],
        students: [],
      );
      expect(emptyHist.hasAttendanceRecords, isFalse);
    });
  });

  group('Attendance UI Widgets', () {
    testWidgets('PeriodStatusChip renders P for PRESENT', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PeriodStatusChip(status: 'PRESENT'),
          ),
        ),
      );

      expect(find.text('P'), findsOneWidget);
    });

    testWidgets('PeriodStatusChip renders OD for OD', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PeriodStatusChip(status: 'OD', odReason: 'Sports'),
          ),
        ),
      );

      expect(find.text('OD'), findsOneWidget);
    });

    testWidgets('AttendanceLegend renders all status labels', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AttendanceLegend(),
          ),
        ),
      );

      expect(find.text('ATTENDANCE STATUS LEGEND'), findsOneWidget);
      expect(find.text('Present'), findsOneWidget);
      expect(find.text('Absent'), findsOneWidget);
      expect(find.text('On Duty'), findsOneWidget);
      expect(find.text('Lunch Break'), findsOneWidget);
    });

    testWidgets('AttendanceSummaryCard renders percentage and stats', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AttendanceSummaryCard(
              percentage: 85.5,
              total: 20,
              present: 16,
              absent: 3,
              od: 1,
              status: 'OK',
            ),
          ),
        ),
      );

      expect(find.text('85.5%'), findsOneWidget);
      expect(find.text('OVERALL ATTENDANCE'), findsOneWidget);
      expect(find.text('16'), findsOneWidget); // Present
      expect(find.text('3'), findsOneWidget);  // Absent
    });
  });
}
