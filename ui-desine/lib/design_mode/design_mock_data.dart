import '../models/student_model.dart';
import '../models/faculty_attendance_model.dart';
import '../models/user_model.dart';

class DesignMockData {
  static UserModel get mockStudentUser => UserModel(
        id: 101,
        username: '7376222IT101',
        fullName: 'Aarav Sharma',
        role: 'STUDENT',
        email: 'aarav.sharma@college.edu',
        forcePasswordChange: false,
        isActive: true,
      );

  static UserModel get mockFacultyUser => UserModel(
        id: 201,
        username: 'FAC001',
        fullName: 'Dr. K. Senthil Kumar',
        role: 'FACULTY',
        email: 'senthil.kumar@college.edu',
        forcePasswordChange: false,
        isActive: true,
      );

  static StudentSummaryModel get mockStudentSummary => StudentSummaryModel(
        studentId: 101,
        userId: 101,
        fullName: 'Aarav Sharma',
        registerNumber: '7376222IT101',
        email: 'aarav.sharma@college.edu',
        className: 'B.Tech IT - Year III (Section B)',
        classId: 3,
        semester: '5',
        department: 'Information Technology',
        isActive: true,
        total: 120,
        present: 106,
        absent: 10,
        od: 4,
        halfDayPresent: 0,
        halfDayAbsent: 0,
        percentage: 88.33,
        calculationMode: 'PERIOD',
        attendanceStatus: 'OK',
        minimumRequired: 75.0,
        belowMinimum: false,
        alertMessage: 'Attendance is in safe zone (> 75%). Keep it up!',
        requiredFutureClasses: 0,
        estimatedWorkingDays: 45,
        missableFutureClasses: 16,
      );

  static List<SubjectAttendanceModel> get mockSubjects => [
        SubjectAttendanceModel(
          subjectId: 1,
          subjectCode: '19IT501',
          subjectName: 'Design and Analysis of Algorithms',
          total: 28,
          present: 26,
          absent: 1,
          od: 1,
          percentage: 92.8,
        ),
        SubjectAttendanceModel(
          subjectId: 2,
          subjectCode: '19IT502',
          subjectName: 'Computer Networks',
          total: 25,
          present: 22,
          absent: 3,
          od: 0,
          percentage: 88.0,
        ),
        SubjectAttendanceModel(
          subjectId: 3,
          subjectCode: '19IT503',
          subjectName: 'Database Management Systems',
          total: 24,
          present: 20,
          absent: 3,
          od: 1,
          percentage: 83.3,
        ),
        SubjectAttendanceModel(
          subjectId: 4,
          subjectCode: '19IT504',
          subjectName: 'Full Stack Web Development',
          total: 26,
          present: 24,
          absent: 2,
          od: 0,
          percentage: 92.3,
        ),
        SubjectAttendanceModel(
          subjectId: 5,
          subjectCode: '19IT505',
          subjectName: 'Artificial Intelligence & ML',
          total: 17,
          present: 14,
          absent: 1,
          od: 2,
          percentage: 82.4,
        ),
      ];

  static List<TimetableItemModel> get mockTimetable => [
        TimetableItemModel(
          dayOfWeek: 'MONDAY',
          periodNumber: 1,
          periodName: 'Period 1',
          startTime: '08:45 AM',
          endTime: '09:40 AM',
          subjectName: 'Design and Analysis of Algorithms',
          subjectCode: '19IT501',
          facultyName: 'Dr. K. Senthil Kumar',
        ),
        TimetableItemModel(
          dayOfWeek: 'MONDAY',
          periodNumber: 2,
          periodName: 'Period 2',
          startTime: '09:40 AM',
          endTime: '10:35 AM',
          subjectName: 'Computer Networks',
          subjectCode: '19IT502',
          facultyName: 'Prof. R. Priya',
        ),
        TimetableItemModel(
          dayOfWeek: 'MONDAY',
          periodNumber: 3,
          periodName: 'Period 3',
          startTime: '10:55 AM',
          endTime: '11:50 AM',
          subjectName: 'Database Management Systems',
          subjectCode: '19IT503',
          facultyName: 'Dr. M. Vignesh',
        ),
        TimetableItemModel(
          dayOfWeek: 'MONDAY',
          periodNumber: 4,
          periodName: 'Period 4',
          startTime: '11:50 AM',
          endTime: '12:45 PM',
          subjectName: 'Full Stack Web Development',
          subjectCode: '19IT504',
          facultyName: 'Prof. S. Kavitha',
        ),
        TimetableItemModel(
          dayOfWeek: 'MONDAY',
          periodNumber: 5,
          periodName: 'Period 5',
          startTime: '01:45 PM',
          endTime: '02:40 PM',
          subjectName: 'Artificial Intelligence & ML',
          subjectCode: '19IT505',
          facultyName: 'Dr. P. Rajesh',
        ),
      ];

  static List<DateWiseEntryModel> get mockDateWise => [
        DateWiseEntryModel(
          date: '2026-10-12',
          morningStatus: 'PRESENT',
          morningSummary: 'All morning periods attended',
          afternoonStatus: 'PRESENT',
          afternoonSummary: 'All afternoon periods attended',
          dailyResult: 'PRESENT',
          periods: [
            PeriodEntryModel(periodNumber: 1, periodName: 'Period 1', subjectCode: '19IT501', subjectName: 'DAA', status: 'P'),
            PeriodEntryModel(periodNumber: 2, periodName: 'Period 2', subjectCode: '19IT502', subjectName: 'CN', status: 'P'),
            PeriodEntryModel(periodNumber: 3, periodName: 'Period 3', subjectCode: '19IT503', subjectName: 'DBMS', status: 'P'),
            PeriodEntryModel(periodNumber: 4, periodName: 'Period 4', subjectCode: '19IT504', subjectName: 'FSWD', status: 'OD'),
            PeriodEntryModel(periodNumber: 5, periodName: 'Period 5', subjectCode: '19IT505', subjectName: 'AI/ML', status: 'P'),
          ],
        ),
        DateWiseEntryModel(
          date: '2026-10-09',
          morningStatus: 'PARTIAL',
          morningSummary: '1 period absent',
          afternoonStatus: 'PRESENT',
          afternoonSummary: 'Present',
          dailyResult: 'PARTIAL',
          periods: [
            PeriodEntryModel(periodNumber: 1, periodName: 'Period 1', subjectCode: '19IT501', subjectName: 'DAA', status: 'P'),
            PeriodEntryModel(periodNumber: 2, periodName: 'Period 2', subjectCode: '19IT502', subjectName: 'CN', status: 'A'),
            PeriodEntryModel(periodNumber: 3, periodName: 'Period 3', subjectCode: '19IT503', subjectName: 'DBMS', status: 'P'),
            PeriodEntryModel(periodNumber: 4, periodName: 'Period 4', subjectCode: '19IT504', subjectName: 'FSWD', status: 'P'),
          ],
        ),
      ];

  static List<StudentRosterItem> get mockRoster => [
        StudentRosterItem(
          studentId: 101,
          fullName: 'Aarav Sharma',
          rollNumber: '22IT001',
          attendanceStatus: 'PRESENT',
        ),
        StudentRosterItem(
          studentId: 102,
          fullName: 'Ananya Ramesh',
          rollNumber: '22IT002',
          attendanceStatus: 'PRESENT',
        ),
        StudentRosterItem(
          studentId: 103,
          fullName: 'Bhavin Patel',
          rollNumber: '22IT003',
          attendanceStatus: 'ABSENT',
        ),
        StudentRosterItem(
          studentId: 104,
          fullName: 'Deepika Sundaram',
          rollNumber: '22IT004',
          attendanceStatus: 'OD',
        ),
        StudentRosterItem(
          studentId: 105,
          fullName: 'Gokul Krishna',
          rollNumber: '22IT005',
          attendanceStatus: 'PRESENT',
        ),
        StudentRosterItem(
          studentId: 106,
          fullName: 'Harini Mohan',
          rollNumber: '22IT006',
          attendanceStatus: 'PRESENT',
        ),
      ];
}
