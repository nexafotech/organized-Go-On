class StudentSummaryModel {
  final int studentId;
  final int? userId;
  final String fullName;
  final String registerNumber;
  final String? email;
  final String? className;
  final int? classId;
  final String? semester;
  final String? department;
  final bool isActive;
  final int total;
  final int present;
  final int absent;
  final int od;
  final int halfDayPresent;
  final int halfDayAbsent;
  final double percentage;
  final String calculationMode;
  final String attendanceStatus; // "OK", "WARNING", "CRITICAL", "NO_DATA"
  final double minimumRequired;
  final bool belowMinimum;
  final String? alertMessage;
  final int? requiredFutureClasses;
  final int? estimatedWorkingDays;
  final int? missableFutureClasses;

  StudentSummaryModel({
    required this.studentId,
    this.userId,
    required this.fullName,
    required this.registerNumber,
    this.email,
    this.className,
    this.classId,
    this.semester,
    this.department,
    required this.isActive,
    required this.total,
    required this.present,
    required this.absent,
    required this.od,
    this.halfDayPresent = 0,
    this.halfDayAbsent = 0,
    required this.percentage,
    required this.calculationMode,
    required this.attendanceStatus,
    required this.minimumRequired,
    required this.belowMinimum,
    this.alertMessage,
    this.requiredFutureClasses,
    this.estimatedWorkingDays,
    this.missableFutureClasses,
  });

  factory StudentSummaryModel.fromJson(Map<String, dynamic> json) {
    return StudentSummaryModel(
      studentId: json['student_id'] as int? ?? 0,
      userId: json['user_id'] as int?,
      fullName: json['full_name'] as String? ?? '',
      registerNumber: json['register_number'] as String? ?? '',
      email: json['email'] as String?,
      className: json['class_name'] as String?,
      classId: json['class_id'] as int?,
      semester: json['semester'] as String?,
      department: json['department'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      total: json['total'] as int? ?? 0,
      present: json['present'] as int? ?? 0,
      absent: json['absent'] as int? ?? 0,
      od: json['od'] as int? ?? 0,
      halfDayPresent: json['half_day_present'] as int? ?? 0,
      halfDayAbsent: json['half_day_absent'] as int? ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
      calculationMode: json['calculation_mode'] as String? ?? 'RECORD_BASED',
      attendanceStatus: json['attendance_status'] as String? ?? 'OK',
      minimumRequired: (json['minimum_required'] as num?)?.toDouble() ?? 75.0,
      belowMinimum: json['below_minimum'] as bool? ?? false,
      alertMessage: json['alert_message'] as String?,
      requiredFutureClasses: json['required_future_classes'] as int?,
      estimatedWorkingDays: json['estimated_working_days'] as int?,
      missableFutureClasses: json['missable_future_classes'] as int?,
    );
  }
}

class SubjectAttendanceModel {
  final int subjectId;
  final String subjectCode;
  final String subjectName;
  final int total;
  final int present;
  final int absent;
  final int od;
  final double percentage;

  SubjectAttendanceModel({
    required this.subjectId,
    required this.subjectCode,
    required this.subjectName,
    required this.total,
    required this.present,
    required this.absent,
    required this.od,
    required this.percentage,
  });

  factory SubjectAttendanceModel.fromJson(Map<String, dynamic> json) {
    return SubjectAttendanceModel(
      subjectId: json['subject_id'] as int? ?? 0,
      subjectCode: json['subject_code'] as String? ?? '',
      subjectName: json['subject_name'] as String? ?? '',
      total: json['total'] as int? ?? 0,
      present: json['present'] as int? ?? 0,
      absent: json['absent'] as int? ?? 0,
      od: json['od'] as int? ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class TimetableItemModel {
  final String dayOfWeek;
  final int? periodNumber;
  final String? periodName;
  final String? startTime;
  final String? endTime;
  final String? subjectCode;
  final String? subjectName;
  final String? facultyName;

  TimetableItemModel({
    required this.dayOfWeek,
    this.periodNumber,
    this.periodName,
    this.startTime,
    this.endTime,
    this.subjectCode,
    this.subjectName,
    this.facultyName,
  });

  factory TimetableItemModel.fromJson(Map<String, dynamic> json) {
    return TimetableItemModel(
      dayOfWeek: json['day_of_week'] as String? ?? '',
      periodNumber: json['period_number'] as int?,
      periodName: json['period_name'] as String?,
      startTime: json['start_time'] as String?,
      endTime: json['end_time'] as String?,
      subjectCode: json['subject_code'] as String?,
      subjectName: json['subject_name'] as String?,
      facultyName: json['faculty_name'] as String?,
    );
  }
}

class PeriodEntryModel {
  final int? periodNumber;
  final String? periodName;
  final String? subjectCode;
  final String? subjectName;
  final String status;
  final String? odReason;

  PeriodEntryModel({
    this.periodNumber,
    this.periodName,
    this.subjectCode,
    this.subjectName,
    required this.status,
    this.odReason,
  });

  factory PeriodEntryModel.fromJson(Map<String, dynamic> json) {
    return PeriodEntryModel(
      periodNumber: json['period_number'] as int?,
      periodName: json['period_name'] as String?,
      subjectCode: json['subject_code'] as String?,
      subjectName: json['subject_name'] as String?,
      status: json['status'] as String? ?? 'NOT_ENTERED',
      odReason: json['od_reason'] as String?,
    );
  }
}

class DateWiseEntryModel {
  final String date;
  final String? morningStatus;
  final String? morningSummary;
  final String? afternoonStatus;
  final String? afternoonSummary;
  final String? dailyResult;
  final String lunchInterval;
  final List<PeriodEntryModel> periods;

  DateWiseEntryModel({
    required this.date,
    this.morningStatus,
    this.morningSummary,
    this.afternoonStatus,
    this.afternoonSummary,
    this.dailyResult,
    this.lunchInterval = '12:50 PM - 01:40 PM (Not Counted)',
    required this.periods,
  });

  factory DateWiseEntryModel.fromJson(Map<String, dynamic> json) {
    return DateWiseEntryModel(
      date: json['date'] as String? ?? '',
      morningStatus: json['morning_status'] as String?,
      morningSummary: json['morning_summary'] as String?,
      afternoonStatus: json['afternoon_status'] as String?,
      afternoonSummary: json['afternoon_summary'] as String?,
      dailyResult: json['daily_result'] as String?,
      lunchInterval: json['lunch_interval'] as String? ?? '12:50 PM - 01:40 PM (Not Counted)',
      periods: (json['periods'] as List? ?? [])
          .map((p) => PeriodEntryModel.fromJson(Map<String, dynamic>.from(p as Map)))
          .toList(),
    );
  }
}


