import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:attendance_marker_mobile/models/student_model.dart';
import 'package:attendance_marker_mobile/models/faculty_model.dart';
import 'package:attendance_marker_mobile/models/faculty_attendance_model.dart';
import 'package:attendance_marker_mobile/services/student_service.dart';
import 'package:attendance_marker_mobile/services/faculty_service.dart';
import 'package:attendance_marker_mobile/student/screens/student_timetable_screen.dart';
import 'package:attendance_marker_mobile/faculty/screens/faculty_class_advisor_screen.dart';

class MockStudentService extends ChangeNotifier implements StudentService {
  List<TimetableItemModel> _timetable = [];
  bool _isLoading = false;
  String? _errorMessage;

  MockStudentService({
    List<TimetableItemModel>? timetable,
    bool isLoading = false,
    String? errorMessage,
  })  : _timetable = timetable ?? [],
        _isLoading = isLoading,
        _errorMessage = errorMessage;

  @override
  StudentSummaryModel? get summary => null;
  @override
  List<SubjectAttendanceModel> get subjects => [];
  @override
  List<TimetableItemModel> get timetable => _timetable;
  @override
  List<DateWiseEntryModel> get dateWise => [];
  @override
  bool get isLoading => _isLoading;
  @override
  String? get errorMessage => _errorMessage;

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

class MockFacultyService extends ChangeNotifier implements FacultyService {
  List<FacultyScheduleItem> _schedule = [];
  List<FacultyScheduleItem> _classAdvisorSchedule = [];
  String? _classAdvisorClassName;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isClassAdvisor = false;
  AdvisedClassInfo? _advisedClass;

  MockFacultyService({
    List<FacultyScheduleItem>? schedule,
    List<FacultyScheduleItem>? classAdvisorSchedule,
    String? classAdvisorClassName,
    bool isLoading = false,
    String? errorMessage,
    bool isClassAdvisor = true,
    AdvisedClassInfo? advisedClass,
  })  : _schedule = schedule ?? [],
        _classAdvisorSchedule = classAdvisorSchedule ?? [],
        _classAdvisorClassName = classAdvisorClassName,
        _isLoading = isLoading,
        _errorMessage = errorMessage,
        _isClassAdvisor = isClassAdvisor,
        _advisedClass = advisedClass;

  @override
  List<FacultyScheduleItem> get schedule => _schedule;
  @override
  List<FacultyScheduleItem> get classAdvisorSchedule => _classAdvisorSchedule;
  @override
  String? get classAdvisorClassName => _classAdvisorClassName;
  @override
  bool get isClassAdvisor => _isClassAdvisor;
  @override
  AdvisedClassInfo? get advisedClass => _advisedClass;
  @override
  bool get isLoading => _isLoading;
  @override
  String? get errorMessage => _errorMessage;

  @override
  Future<void> fetchSchedule() async {}
  @override
  Future<void> fetchClassAdvisorTimetable() async {}
  @override
  Future<void> fetchClassTimetable(int classId) async {}
  @override
  Future<void> checkActiveClassSlot() async {}
  @override
  Future<void> checkActiveSession() async {}
  @override
  Future<void> loadDashboardData() async {}
  @override
  Future<ClassAdvisorAvailablePeriodsResponse> fetchClassAdvisorAvailablePeriods() async {
    return ClassAdvisorAvailablePeriodsResponse(
      isClassAdvisor: true,
      advisedClass: _advisedClass ?? AdvisedClassInfo(id: 4, name: 'II Year CSE Cyber Security - Class 1'),
      todayDate: '2026-10-19',
      todayDay: 'MONDAY',
      yesterdayDate: '2026-10-18',
      yesterdayDay: 'SUNDAY',
      currentTime: '10:00 AM',
      todayPeriods: [],
      yesterdayPeriods: [],
      lunchBreak: LunchBreakInfo(),
    );
  }
  @override
  Future<ClassAdvisorPeriodsForDateResponse> fetchClassAdvisorPeriodsForDate(String date) async {
    return ClassAdvisorPeriodsForDateResponse(
      isClassAdvisor: true,
      advisedClass: _advisedClass ?? AdvisedClassInfo(id: 4, name: 'II Year CSE Cyber Security - Class 1'),
      date: date,
      dayOfWeek: 'MONDAY',
      isToday: false,
      periods: [],
      lunchBreak: LunchBreakInfo(),
    );
  }
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Master Timetable Data Integrity & Consistency Tests', () {
    testWidgets('1. Student Timetable displays sessions and does not show false empty on populated days', (tester) async {
      final sampleItems = List.generate(7, (i) => TimetableItemModel(
        dayOfWeek: 'Monday',
        periodNumber: i + 1,
        periodName: 'Period ${i + 1}',
        startTime: '09:10',
        endTime: '10:00',
        subjectCode: 'CS30${i + 1}',
        subjectName: 'Subject ${i + 1}',
        facultyName: 'Dr. Test Faculty',
        roomNo: 'Lab 1',
      ));

      final mockStudent = MockStudentService(timetable: sampleItems);

      await tester.pumpWidget(
        ChangeNotifierProvider<StudentService>.value(
          value: mockStudent,
          child: MaterialApp(
            home: Scaffold(
              body: StudentTimetableScreen(
                simulatedTime: DateTime(2026, 10, 19, 10, 0), // Monday
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // On Monday, it should show periods, not "No Classes on MONDAY"
      expect(find.text('No Classes on MONDAY'), findsNothing);
      expect(find.text('Subject 1'), findsWidgets);
    });

    testWidgets('2. Student Timetable shows truthful error state with retry on network failure', (tester) async {
      final mockStudent = MockStudentService(
        timetable: [],
        errorMessage: 'Unable to reach the server. Check your connection or server address.',
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<StudentService>.value(
          value: mockStudent,
          child: const MaterialApp(
            home: Scaffold(body: StudentTimetableScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Timetable Unavailable'), findsOneWidget);
      expect(find.text('Unable to reach the server. Check your connection or server address.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('3. Faculty Class Advisor Screen shows loading spinner while fetching', (tester) async {
      final mockFaculty = MockFacultyService(
        isLoading: true,
        classAdvisorSchedule: [],
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<FacultyService>.value(
          value: mockFaculty,
          child: const MaterialApp(
            home: Scaffold(body: FacultyClassAdvisorScreen()),
          ),
        ),
      );

      // Verify that while loading and schedule empty, spinner is shown
      expect(find.byType(CircularProgressIndicator), findsWidgets);
      expect(find.text('Unable to load timetable for II Year CSE Cyber Security - Class 1'), findsNothing);
    });

    testWidgets('4. Faculty Class Advisor Screen shows truthful error and Refresh Timetable button on error', (tester) async {
      final mockFaculty = MockFacultyService(
        isLoading: false,
        errorMessage: 'Connection lost to server',
        classAdvisorSchedule: [],
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<FacultyService>.value(
          value: mockFaculty,
          child: const MaterialApp(
            home: Scaffold(body: FacultyClassAdvisorScreen()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Switch to CLASS SCHEDULE tab
      final scheduleTab = find.byKey(const Key('tab_class_schedule'));
      expect(scheduleTab, findsOneWidget);
      await tester.tap(scheduleTab);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Timetable Unavailable'), findsOneWidget);
      expect(find.text('Connection lost to server'), findsOneWidget);
      expect(find.text('Refresh Timetable'), findsOneWidget);
    });
  });
}
