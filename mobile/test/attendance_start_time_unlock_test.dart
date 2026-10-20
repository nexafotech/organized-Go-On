import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:attendance_marker_mobile/core/theme/app_theme.dart';
import 'package:attendance_marker_mobile/faculty/screens/faculty_attendance_screen.dart';
import 'package:attendance_marker_mobile/faculty/screens/faculty_class_advisor_screen.dart';
import 'package:attendance_marker_mobile/models/faculty_attendance_model.dart';
import 'package:attendance_marker_mobile/services/faculty_service.dart';

class MockFacultyServiceForStartTimeUnlock extends FacultyService {
  final AvailablePeriodsResponse mockAvailablePeriods;
  final ClassAdvisorAvailablePeriodsResponse mockAdvisorPeriods;

  MockFacultyServiceForStartTimeUnlock({
    required this.mockAvailablePeriods,
    required this.mockAdvisorPeriods,
  });

  @override
  Future<AvailablePeriodsResponse> fetchAvailableAttendancePeriods() async {
    return mockAvailablePeriods;
  }

  @override
  Future<ClassAdvisorAvailablePeriodsResponse> fetchClassAdvisorAvailablePeriods() async {
    return mockAdvisorPeriods;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Faculty & Class Adviser Attendance Start Time Unlock Tests', () {
    testWidgets('Faculty Attendance Screen: Period 5 displays "Attendance opens at 1:40 PM" when LOCKED',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Period 5 is locked before 1:40 PM
      final mockAvailable = AvailablePeriodsResponse(
        todayDate: '2026-10-19',
        todayDay: 'Monday',
        yesterdayDate: '2026-10-18',
        yesterdayDay: 'Sunday',
        currentTime: '13:30',
        todayPeriods: [
          AvailablePeriodItem(
            timetableEntryId: 198,
            periodId: 5,
            periodNumber: 5,
            periodName: 'Period 5',
            startTime: '13:40',
            endTime: '14:30',
            subjectCode: 'ESSS',
            subjectName: 'Engineering Secure Software Systems',
            classId: 2,
            className: 'III Year CSE Cyber Security - Class 2',
            date: '2026-10-19',
            dayOfWeek: 'Monday',
            facultyName: 'Dr. Shankar',
            status: 'LOCKED',
            canMark: false,
            lockReason: 'Attendance opens at 1:40 PM',
          ),
        ],
        yesterdayPeriods: [],
      );

      final mockAdvisor = ClassAdvisorAvailablePeriodsResponse(
        isClassAdvisor: false,
        advisedClass: null,
        todayDate: '2026-10-19',
        todayDay: 'Monday',
        yesterdayDate: '2026-10-18',
        yesterdayDay: 'Sunday',
        currentTime: '13:30',
        todayPeriods: [],
        yesterdayPeriods: [],
        lunchBreak: LunchBreakInfo(),
      );

      final service = MockFacultyServiceForStartTimeUnlock(
        mockAvailablePeriods: mockAvailable,
        mockAdvisorPeriods: mockAdvisor,
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<FacultyService>.value(
          value: service,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const FacultyAttendanceScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 1. Verify period header and subject name
      expect(find.text('P5'), findsOneWidget);
      expect(find.textContaining('1:40 PM'), findsWidgets);
      expect(find.text('Engineering Secure Software Systems (ESSS)'), findsOneWidget);

      // 2. Verify LOCKED status pill
      expect(find.text('LOCKED'), findsOneWidget);

      // 3. Verify exact lock reason showing START time (1:40 PM) instead of end time (2:30 PM)
      expect(find.text('Attendance opens at 1:40 PM'), findsOneWidget);
      expect(find.textContaining('ends at 2:30 PM'), findsNothing);
      expect(find.textContaining('after this period ends'), findsNothing);

      // 4. Verify MARK ATTENDANCE is NOT visible while locked
      expect(find.text('MARK ATTENDANCE'), findsNothing);
    });

    testWidgets('Faculty Attendance Screen: Period 5 becomes AVAILABLE with MARK ATTENDANCE at 1:40 PM',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Period 5 at 1:40 PM (AVAILABLE)
      final mockAvailable = AvailablePeriodsResponse(
        todayDate: '2026-10-19',
        todayDay: 'Monday',
        yesterdayDate: '2026-10-18',
        yesterdayDay: 'Sunday',
        currentTime: '13:40',
        todayPeriods: [
          AvailablePeriodItem(
            timetableEntryId: 198,
            periodId: 5,
            periodNumber: 5,
            periodName: 'Period 5',
            startTime: '13:40',
            endTime: '14:30',
            subjectCode: 'ESSS',
            subjectName: 'Engineering Secure Software Systems',
            classId: 2,
            className: 'III Year CSE Cyber Security - Class 2',
            date: '2026-10-19',
            dayOfWeek: 'Monday',
            facultyName: 'Dr. Shankar',
            status: 'AVAILABLE',
            canMark: true,
            lockReason: null,
          ),
        ],
        yesterdayPeriods: [],
      );

      final mockAdvisor = ClassAdvisorAvailablePeriodsResponse(
        isClassAdvisor: false,
        advisedClass: null,
        todayDate: '2026-10-19',
        todayDay: 'Monday',
        yesterdayDate: '2026-10-18',
        yesterdayDay: 'Sunday',
        currentTime: '13:40',
        todayPeriods: [],
        yesterdayPeriods: [],
        lunchBreak: LunchBreakInfo(),
      );

      final service = MockFacultyServiceForStartTimeUnlock(
        mockAvailablePeriods: mockAvailable,
        mockAdvisorPeriods: mockAdvisor,
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<FacultyService>.value(
          value: service,
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const FacultyAttendanceScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 1. Verify AVAILABLE pill is rendered
      expect(find.text('AVAILABLE'), findsOneWidget);

      // 2. Lock reason container is NOT rendered
      expect(find.textContaining('Attendance opens at'), findsNothing);

      // 3. Action button is enabled and shows MARK ATTENDANCE
      expect(find.text('MARK ATTENDANCE'), findsOneWidget);
    });

    testWidgets('Class Advisor Portal: Period 5 displays "Attendance opens at 1:40 PM" when locked',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockAdvisor = ClassAdvisorAvailablePeriodsResponse(
        isClassAdvisor: true,
        advisedClass: AdvisedClassInfo(id: 2, name: 'III Year CSE Cyber Security - Class 2', academicYear: '2025-2026', gradeLevel: 'III'),
        todayDate: '2026-10-19',
        todayDay: 'Monday',
        yesterdayDate: '2026-10-18',
        yesterdayDay: 'Sunday',
        currentTime: '13:35',
        todayPeriods: [
          ClassAdvisorPeriodItem(
            timetableEntryId: 198,
            periodId: 5,
            periodNumber: 5,
            periodName: 'Period 5',
            startTime: '13:40',
            endTime: '14:30',
            sessionType: 'AFTERNOON',
            subjectCode: 'ESSS',
            subjectName: 'Engineering Secure Software Systems',
            classId: 2,
            className: 'III Year CSE Cyber Security - Class 2',
            date: '2026-10-19',
            dayOfWeek: 'Monday',
            subjectFacultyName: 'Dr. Shankar',
            status: 'LOCKED',
            canMark: false,
            lockReason: 'Attendance opens at 1:40 PM',
          ),
        ],
        yesterdayPeriods: [],
        lunchBreak: LunchBreakInfo(),
      );

      final service = MockFacultyServiceForStartTimeUnlock(
        mockAvailablePeriods: AvailablePeriodsResponse(
          todayDate: '2026-10-19',
          todayDay: 'Monday',
          yesterdayDate: '2026-10-18',
          yesterdayDay: 'Sunday',
          currentTime: '13:35',
          todayPeriods: [],
          yesterdayPeriods: [],
        ),
        mockAdvisorPeriods: mockAdvisor,
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<FacultyService>.value(
          value: service,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const FacultyClassAdvisorScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify Class Advisor view shows exact start-time lock message
      expect(find.text('Attendance opens at 1:40 PM'), findsOneWidget);
      expect(find.textContaining('ends at 2:30 PM'), findsNothing);
      expect(find.text('RECORD ATTENDANCE'), findsNothing);
    });

    testWidgets('Class Advisor Portal: Period 5 renders RECORD ATTENDANCE when AVAILABLE at start time',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockAdvisor = ClassAdvisorAvailablePeriodsResponse(
        isClassAdvisor: true,
        advisedClass: AdvisedClassInfo(id: 2, name: 'III Year CSE Cyber Security - Class 2', academicYear: '2025-2026', gradeLevel: 'III'),
        todayDate: '2026-10-19',
        todayDay: 'Monday',
        yesterdayDate: '2026-10-18',
        yesterdayDay: 'Sunday',
        currentTime: '13:40',
        todayPeriods: [
          ClassAdvisorPeriodItem(
            timetableEntryId: 198,
            periodId: 5,
            periodNumber: 5,
            periodName: 'Period 5',
            startTime: '13:40',
            endTime: '14:30',
            sessionType: 'AFTERNOON',
            subjectCode: 'ESSS',
            subjectName: 'Engineering Secure Software Systems',
            classId: 2,
            className: 'III Year CSE Cyber Security - Class 2',
            date: '2026-10-19',
            dayOfWeek: 'Monday',
            subjectFacultyName: 'Dr. Shankar',
            status: 'AVAILABLE',
            canMark: true,
            lockReason: null,
          ),
        ],
        yesterdayPeriods: [],
        lunchBreak: LunchBreakInfo(),
      );

      final service = MockFacultyServiceForStartTimeUnlock(
        mockAvailablePeriods: AvailablePeriodsResponse(
          todayDate: '2026-10-19',
          todayDay: 'Monday',
          yesterdayDate: '2026-10-18',
          yesterdayDay: 'Sunday',
          currentTime: '13:40',
          todayPeriods: [],
          yesterdayPeriods: [],
        ),
        mockAdvisorPeriods: mockAdvisor,
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<FacultyService>.value(
          value: service,
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const FacultyClassAdvisorScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify Class Advisor view shows RECORD ATTENDANCE button
      expect(find.text('RECORD ATTENDANCE'), findsOneWidget);
      expect(find.textContaining('Attendance opens at'), findsNothing);
    });
  });
}
