import 'faculty_attendance_model.dart';

class AuthorizedSubjectOptionModel {
  final int id;
  final String code;
  final String name;
  final bool isTeaching;

  AuthorizedSubjectOptionModel({
    required this.id,
    required this.code,
    required this.name,
    this.isTeaching = true,
  });

  factory AuthorizedSubjectOptionModel.fromJson(Map<String, dynamic> json) {
    return AuthorizedSubjectOptionModel(
      id: json['id'] as int? ?? 0,
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      isTeaching: json['is_teaching'] as bool? ?? true,
    );
  }
}

class AuthorizedClassOptionModel {
  final int id;
  final String name;
  final String? gradeLevel;
  final String? academicYear;
  final bool isAdvisorForClass;
  final List<AuthorizedSubjectOptionModel> subjects;

  AuthorizedClassOptionModel({
    required this.id,
    required this.name,
    this.gradeLevel,
    this.academicYear,
    this.isAdvisorForClass = false,
    required this.subjects,
  });

  factory AuthorizedClassOptionModel.fromJson(Map<String, dynamic> json) {
    return AuthorizedClassOptionModel(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      gradeLevel: json['grade_level'] as String?,
      academicYear: json['academic_year'] as String?,
      isAdvisorForClass: json['is_advisor_for_class'] as bool? ?? false,
      subjects: (json['subjects'] as List? ?? [])
          .map((s) => AuthorizedSubjectOptionModel.fromJson(Map<String, dynamic>.from(s as Map)))
          .toList(),
    );
  }
}

class FacultyAuthorizedReportOptionsModel {
  final int facultyId;
  final String facultyName;
  final bool isClassAdvisor;
  final AdvisedClassInfo? advisedClass;
  final List<AuthorizedClassOptionModel> classes;
  final String? currentDate;
  final String? attendanceStartDate;

  FacultyAuthorizedReportOptionsModel({
    required this.facultyId,
    required this.facultyName,
    this.isClassAdvisor = false,
    this.advisedClass,
    required this.classes,
    this.currentDate,
    this.attendanceStartDate,
  });

  factory FacultyAuthorizedReportOptionsModel.fromJson(Map<String, dynamic> json) {
    return FacultyAuthorizedReportOptionsModel(
      facultyId: json['faculty_id'] as int? ?? 0,
      facultyName: json['faculty_name'] as String? ?? '',
      isClassAdvisor: json['is_class_advisor'] as bool? ?? false,
      advisedClass: json['advised_class'] != null && json['advised_class'] is Map
          ? AdvisedClassInfo.fromJson(Map<String, dynamic>.from(json['advised_class'] as Map))
          : null,
      classes: (json['classes'] as List? ?? [])
          .map((c) => AuthorizedClassOptionModel.fromJson(Map<String, dynamic>.from(c as Map)))
          .toList(),
      currentDate: json['current_date'] as String?,
      attendanceStartDate: json['attendance_start_date'] as String?,
    );
  }
}

class FacultyStudentAttendanceRowModel {
  final int studentId;
  final String rollNumber;
  final String fullName;
  final int total;
  final int present;
  final int purePresent;
  final int absent;
  final int od;
  final double percentage;

  FacultyStudentAttendanceRowModel({
    required this.studentId,
    required this.rollNumber,
    required this.fullName,
    required this.total,
    required this.present,
    this.purePresent = 0,
    required this.absent,
    required this.od,
    required this.percentage,
  });

  factory FacultyStudentAttendanceRowModel.fromJson(Map<String, dynamic> json) {
    final pres = json['present'] as int? ?? 0;
    final odVal = json['od'] as int? ?? 0;
    return FacultyStudentAttendanceRowModel(
      studentId: json['student_id'] as int? ?? 0,
      rollNumber: json['roll_number'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      total: json['total'] as int? ?? 0,
      present: pres,
      purePresent: json['pure_present'] as int? ?? (pres >= odVal ? pres - odVal : pres),
      absent: json['absent'] as int? ?? 0,
      od: odVal,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class FacultyClassSummaryModel {
  final int classId;
  final String className;
  final int? subjectId;
  final String? subjectCode;
  final String? subjectName;
  final bool isClassAdvisorScope;
  final int totalPeriods;
  final int totalStudents;
  final int present;
  final int purePresent;
  final int absent;
  final int od;
  final int totalMarks;
  final double percentage;
  final String? startDate;
  final String? endDate;
  final String? dateRangeDisplay;
  final bool isSunday;
  final bool hasScheduledClasses;
  final String? noClassMessage;
  final List<FacultyStudentAttendanceRowModel> students;

  FacultyClassSummaryModel({
    required this.classId,
    required this.className,
    this.subjectId,
    this.subjectCode,
    this.subjectName,
    this.isClassAdvisorScope = false,
    required this.totalPeriods,
    this.totalStudents = 0,
    required this.present,
    this.purePresent = 0,
    required this.absent,
    required this.od,
    this.totalMarks = 0,
    required this.percentage,
    this.startDate,
    this.endDate,
    this.dateRangeDisplay,
    this.isSunday = false,
    this.hasScheduledClasses = true,
    this.noClassMessage,
    required this.students,
  });

  int get effectiveTotalStudents => totalStudents > 0 ? totalStudents : students.length;
  int get effectiveTotalMarks => totalMarks > 0 ? totalMarks : (effectiveTotalStudents * totalPeriods);

  bool get hasAttendanceRecords =>
      totalPeriods > 0 && (present > 0 || absent > 0 || od > 0 || students.any((s) => s.total > 0));

  factory FacultyClassSummaryModel.fromJson(Map<String, dynamic> json) {
    final stList = (json['students'] as List? ?? [])
        .map((s) => FacultyStudentAttendanceRowModel.fromJson(Map<String, dynamic>.from(s as Map)))
        .toList();
    final pVal = json['present'] as int? ?? 0;
    final odVal = json['od'] as int? ?? 0;
    return FacultyClassSummaryModel(
      classId: json['class_id'] as int? ?? 0,
      className: json['class_name'] as String? ?? '',
      subjectId: json['subject_id'] as int?,
      subjectCode: json['subject_code'] as String?,
      subjectName: json['subject_name'] as String?,
      isClassAdvisorScope: json['is_class_advisor_scope'] as bool? ?? false,
      totalPeriods: json['total_periods'] as int? ?? 0,
      totalStudents: json['total_students'] as int? ?? stList.length,
      present: pVal,
      purePresent: json['pure_present'] as int? ?? (pVal >= odVal ? pVal - odVal : pVal),
      absent: json['absent'] as int? ?? 0,
      od: odVal,
      totalMarks: json['total_marks'] as int? ?? (stList.length * (json['total_periods'] as int? ?? 0)),
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
      startDate: json['start_date'] as String?,
      endDate: json['end_date'] as String?,
      dateRangeDisplay: json['date_range_display'] as String?,
      isSunday: json['is_sunday'] as bool? ?? false,
      hasScheduledClasses: json['has_scheduled_classes'] as bool? ?? true,
      noClassMessage: json['no_class_message'] as String?,
      students: stList,
    );
  }
}

class FacultyStudentReportPeriodItemModel {
  final int periodNumber;
  final String periodName;
  final String? subjectCode;
  final String? subjectName;
  final String? facultyName;
  final String status;
  final String? odReason;

  FacultyStudentReportPeriodItemModel({
    required this.periodNumber,
    required this.periodName,
    this.subjectCode,
    this.subjectName,
    this.facultyName,
    required this.status,
    this.odReason,
  });

  factory FacultyStudentReportPeriodItemModel.fromJson(Map<String, dynamic> json) {
    return FacultyStudentReportPeriodItemModel(
      periodNumber: json['period_number'] as int? ?? 0,
      periodName: json['period_name'] as String? ?? '',
      subjectCode: json['subject_code'] as String?,
      subjectName: json['subject_name'] as String?,
      facultyName: json['faculty_name'] as String?,
      status: json['status'] as String? ?? 'NOT_ENTERED',
      odReason: json['od_reason'] as String?,
    );
  }
}

class FacultyStudentReportDateEntryModel {
  final String date;
  final String? morningStatus;
  final String? morningSummary;
  final String? afternoonStatus;
  final String? afternoonSummary;
  final String? dailyResult;
  final String lunchInterval;
  final List<FacultyStudentReportPeriodItemModel> periods;

  FacultyStudentReportDateEntryModel({
    required this.date,
    this.morningStatus,
    this.morningSummary,
    this.afternoonStatus,
    this.afternoonSummary,
    this.dailyResult,
    this.lunchInterval = '12:50 PM - 01:40 PM (Not Counted)',
    required this.periods,
  });

  factory FacultyStudentReportDateEntryModel.fromJson(Map<String, dynamic> json) {
    return FacultyStudentReportDateEntryModel(
      date: json['date'] as String? ?? '',
      morningStatus: json['morning_status'] as String?,
      morningSummary: json['morning_summary'] as String?,
      afternoonStatus: json['afternoon_status'] as String?,
      afternoonSummary: json['afternoon_summary'] as String?,
      dailyResult: json['daily_result'] as String?,
      lunchInterval: json['lunch_interval'] as String? ?? '12:50 PM - 01:40 PM (Not Counted)',
      periods: (json['periods'] as List? ?? [])
          .map((p) => FacultyStudentReportPeriodItemModel.fromJson(Map<String, dynamic>.from(p as Map)))
          .toList(),
    );
  }
}

class FacultyStudentDetailModel {
  final int studentId;
  final String rollNumber;
  final String fullName;
  final int classId;
  final String className;
  final int? subjectId;
  final String? subjectCode;
  final String? subjectName;
  final int total;
  final int present;
  final int absent;
  final int od;
  final double percentage;
  final List<FacultyStudentReportDateEntryModel> dateWise;

  FacultyStudentDetailModel({
    required this.studentId,
    required this.rollNumber,
    required this.fullName,
    required this.classId,
    required this.className,
    this.subjectId,
    this.subjectCode,
    this.subjectName,
    required this.total,
    required this.present,
    required this.absent,
    required this.od,
    required this.percentage,
    required this.dateWise,
  });

  factory FacultyStudentDetailModel.fromJson(Map<String, dynamic> json) {
    return FacultyStudentDetailModel(
      studentId: json['student_id'] as int? ?? 0,
      rollNumber: json['roll_number'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      classId: json['class_id'] as int? ?? 0,
      className: json['class_name'] as String? ?? '',
      subjectId: json['subject_id'] as int?,
      subjectCode: json['subject_code'] as String?,
      subjectName: json['subject_name'] as String?,
      total: json['total'] as int? ?? 0,
      present: json['present'] as int? ?? 0,
      absent: json['absent'] as int? ?? 0,
      od: json['od'] as int? ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
      dateWise: (json['date_wise'] as List? ?? [])
          .map((d) => FacultyStudentReportDateEntryModel.fromJson(Map<String, dynamic>.from(d as Map)))
          .toList(),
    );
  }
}

class DateMatrixPeriodHeaderModel {
  final int periodNumber;
  final String periodName;
  final String startTime;
  final String endTime;
  final String? subjectCode;
  final String? subjectName;
  final String? facultyName;
  final String status;
  final int presentCount;
  final int absentCount;
  final int odCount;
  final int totalMarked;

  DateMatrixPeriodHeaderModel({
    required this.periodNumber,
    required this.periodName,
    required this.startTime,
    required this.endTime,
    this.subjectCode,
    this.subjectName,
    this.facultyName,
    required this.status,
    this.presentCount = 0,
    this.absentCount = 0,
    this.odCount = 0,
    this.totalMarked = 0,
  });

  factory DateMatrixPeriodHeaderModel.fromJson(Map<String, dynamic> json) {
    return DateMatrixPeriodHeaderModel(
      periodNumber: json['period_number'] as int? ?? 0,
      periodName: json['period_name'] as String? ?? '',
      startTime: json['start_time'] as String? ?? '',
      endTime: json['end_time'] as String? ?? '',
      subjectCode: json['subject_code'] as String?,
      subjectName: json['subject_name'] as String?,
      facultyName: json['faculty_name'] as String?,
      status: json['status'] as String? ?? 'NOT_ENTERED',
      presentCount: json['present_count'] as int? ?? 0,
      absentCount: json['absent_count'] as int? ?? 0,
      odCount: json['od_count'] as int? ?? 0,
      totalMarked: json['total_marked'] as int? ?? 0,
    );
  }
}

class DateMatrixStudentRowModel {
  final int studentId;
  final String rollNumber;
  final String fullName;
  final Map<String, String> periodStatuses;
  final String morningStatus;
  final String afternoonStatus;
  final String dailyResult;

  DateMatrixStudentRowModel({
    required this.studentId,
    required this.rollNumber,
    required this.fullName,
    required this.periodStatuses,
    required this.morningStatus,
    required this.afternoonStatus,
    required this.dailyResult,
  });

  factory DateMatrixStudentRowModel.fromJson(Map<String, dynamic> json) {
    final Map<String, String> statuses = {};
    if (json['period_statuses'] != null && json['period_statuses'] is Map) {
      final map = json['period_statuses'] as Map;
      map.forEach((k, v) {
        statuses[k.toString()] = v.toString();
      });
    }
    return DateMatrixStudentRowModel(
      studentId: json['student_id'] as int? ?? 0,
      rollNumber: json['roll_number'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      periodStatuses: statuses,
      morningStatus: json['morning_status'] as String? ?? 'NOT_ENTERED',
      afternoonStatus: json['afternoon_status'] as String? ?? 'NOT_ENTERED',
      dailyResult: json['daily_result'] as String? ?? 'NOT ENTERED',
    );
  }
}

class FacultyDateMatrixModel {
  final int classId;
  final String className;
  final int? subjectId;
  final String? subjectCode;
  final String? subjectName;
  final bool isClassAdvisorScope;
  final String date;
  final String dayOfWeek;
  final List<DateMatrixPeriodHeaderModel> periods;
  final String lunchInterval;
  final List<DateMatrixStudentRowModel> students;

  FacultyDateMatrixModel({
    required this.classId,
    required this.className,
    this.subjectId,
    this.subjectCode,
    this.subjectName,
    this.isClassAdvisorScope = false,
    required this.date,
    required this.dayOfWeek,
    required this.periods,
    this.lunchInterval = '12:50 PM - 01:40 PM (Not Counted)',
    required this.students,
  });

  bool get hasAttendanceRecords {
    if (periods.isEmpty || students.isEmpty) return false;
    final hasMarkedPeriods = periods.any((p) => p.totalMarked > 0);
    if (hasMarkedPeriods) return true;
    final hasMarkedStudents = students.any((s) => s.periodStatuses.values.any((status) {
      final norm = status.toUpperCase().trim();
      return norm == 'PRESENT' ||
          norm == 'ABSENT' ||
          norm == 'OD' ||
          norm == 'HALF_DAY_PRESENT' ||
          norm == 'HALF_DAY_ABSENT' ||
          norm == 'FULL_DAY_PRESENT' ||
          norm == 'FULL_DAY_ABSENT';
    }));
    return hasMarkedStudents;
  }

  factory FacultyDateMatrixModel.fromJson(Map<String, dynamic> json) {
    String lunchStr = '12:50 PM - 01:40 PM (Not Counted)';
    if (json['lunch_break'] != null && json['lunch_break'] is Map) {
      final lb = json['lunch_break'];
      lunchStr = '${lb['start_time']} - ${lb['end_time']} (${lb['display_text'] ?? "Not Counted"})';
    }
    return FacultyDateMatrixModel(
      classId: json['class_id'] as int? ?? 0,
      className: json['class_name'] as String? ?? '',
      subjectId: json['subject_id'] as int?,
      subjectCode: json['subject_code'] as String?,
      subjectName: json['subject_name'] as String?,
      isClassAdvisorScope: json['is_class_advisor_scope'] as bool? ?? false,
      date: json['date'] as String? ?? '',
      dayOfWeek: json['day_of_week'] as String? ?? '',
      periods: (json['periods'] as List? ?? [])
          .map((p) => DateMatrixPeriodHeaderModel.fromJson(Map<String, dynamic>.from(p as Map)))
          .toList(),
      lunchInterval: lunchStr,
      students: (json['students'] as List? ?? [])
          .map((s) => DateMatrixStudentRowModel.fromJson(Map<String, dynamic>.from(s as Map)))
          .toList(),
    );
  }
}

class HistoricalMatrixDateEntryModel {
  final String date;
  final String dayOfWeek;
  final List<DateMatrixPeriodHeaderModel> periods;
  final String lunchInterval;
  final List<DateMatrixStudentRowModel> students;
  final bool hasScheduledClasses;

  HistoricalMatrixDateEntryModel({
    required this.date,
    required this.dayOfWeek,
    required this.periods,
    this.lunchInterval = '12:50 PM - 01:40 PM (Not Counted)',
    required this.students,
    this.hasScheduledClasses = true,
  });

  bool get hasAttendanceRecords {
    if (periods.isEmpty || students.isEmpty) return false;
    final hasMarkedPeriods = periods.any((p) => p.totalMarked > 0);
    if (hasMarkedPeriods) return true;
    final hasMarkedStudents = students.any((s) => s.periodStatuses.values.any((status) {
      final norm = status.toUpperCase().trim();
      return norm == 'PRESENT' ||
          norm == 'ABSENT' ||
          norm == 'OD' ||
          norm == 'HALF_DAY_PRESENT' ||
          norm == 'HALF_DAY_ABSENT' ||
          norm == 'FULL_DAY_PRESENT' ||
          norm == 'FULL_DAY_ABSENT';
    }));
    return hasMarkedStudents;
  }

  factory HistoricalMatrixDateEntryModel.fromJson(Map<String, dynamic> json) {
    String lunchStr = '12:50 PM - 01:40 PM (Not Counted)';
    if (json['lunch_break'] != null && json['lunch_break'] is Map) {
      final lb = json['lunch_break'];
      lunchStr = '${lb['start_time']} - ${lb['end_time']} (${lb['display_text'] ?? "Not Counted"})';
    }
    return HistoricalMatrixDateEntryModel(
      date: json['date'] as String? ?? '',
      dayOfWeek: json['day_of_week'] as String? ?? '',
      periods: (json['periods'] as List? ?? [])
          .map((p) => DateMatrixPeriodHeaderModel.fromJson(Map<String, dynamic>.from(p as Map)))
          .toList(),
      lunchInterval: lunchStr,
      students: (json['students'] as List? ?? [])
          .map((s) => DateMatrixStudentRowModel.fromJson(Map<String, dynamic>.from(s as Map)))
          .toList(),
      hasScheduledClasses: json['has_scheduled_classes'] as bool? ?? true,
    );
  }
}

class FacultyHistoricalMatrixModel {
  final int classId;
  final String className;
  final int? subjectId;
  final String? subjectCode;
  final String? subjectName;
  final bool isClassAdvisorScope;
  final String attendanceStartDate;
  final String currentDate;
  final String startDate;
  final String endDate;
  final int totalDates;
  final List<HistoricalMatrixDateEntryModel> dates;
  final List<FacultyStudentAttendanceRowModel> students;

  FacultyHistoricalMatrixModel({
    required this.classId,
    required this.className,
    this.subjectId,
    this.subjectCode,
    this.subjectName,
    this.isClassAdvisorScope = false,
    required this.attendanceStartDate,
    required this.currentDate,
    required this.startDate,
    required this.endDate,
    required this.totalDates,
    required this.dates,
    required this.students,
  });

  bool get hasAttendanceRecords {
    if (dates.isEmpty || students.isEmpty) return false;
    return dates.any((d) => d.hasAttendanceRecords) ||
        students.any((s) => s.total > 0 && (s.present > 0 || s.absent > 0 || s.od > 0));
  }

  factory FacultyHistoricalMatrixModel.fromJson(Map<String, dynamic> json) {
    return FacultyHistoricalMatrixModel(
      classId: json['class_id'] as int? ?? 0,
      className: json['class_name'] as String? ?? '',
      subjectId: json['subject_id'] as int?,
      subjectCode: json['subject_code'] as String?,
      subjectName: json['subject_name'] as String?,
      isClassAdvisorScope: json['is_class_advisor_scope'] as bool? ?? false,
      attendanceStartDate: json['attendance_start_date'] as String? ?? '',
      currentDate: json['current_date'] as String? ?? '',
      startDate: json['start_date'] as String? ?? '',
      endDate: json['end_date'] as String? ?? '',
      totalDates: json['total_dates'] as int? ?? 0,
      dates: (json['dates'] as List? ?? [])
          .map((d) => HistoricalMatrixDateEntryModel.fromJson(Map<String, dynamic>.from(d as Map)))
          .toList(),
      students: (json['students'] as List? ?? [])
          .map((s) => FacultyStudentAttendanceRowModel.fromJson(Map<String, dynamic>.from(s as Map)))
          .toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Phase 9: Faculty Date-Range Attendance Report Models
// ─────────────────────────────────────────────────────────────

class RangeStudentSummaryModel {
  final String rollNumber;
  final String fullName;
  final int present;
  final int absent;
  final int od;
  final int totalMarked;
  final double? percentage;

  RangeStudentSummaryModel({
    required this.rollNumber,
    required this.fullName,
    required this.present,
    required this.absent,
    required this.od,
    required this.totalMarked,
    this.percentage,
  });

  factory RangeStudentSummaryModel.fromJson(Map<String, dynamic> json) {
    return RangeStudentSummaryModel(
      rollNumber: json['roll_number'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      present: json['present'] as int? ?? 0,
      absent: json['absent'] as int? ?? 0,
      od: json['od'] as int? ?? 0,
      totalMarked: json['total_marked'] as int? ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble(),
    );
  }
}

class RangePeriodSummaryModel {
  final String date;
  final int periodNumber;
  final String periodName;
  final String subjectCode;
  final String subjectName;
  final int present;
  final int absent;
  final int od;
  final int totalMarked;

  RangePeriodSummaryModel({
    required this.date,
    required this.periodNumber,
    required this.periodName,
    required this.subjectCode,
    required this.subjectName,
    required this.present,
    required this.absent,
    required this.od,
    required this.totalMarked,
  });

  factory RangePeriodSummaryModel.fromJson(Map<String, dynamic> json) {
    return RangePeriodSummaryModel(
      date: json['date'] as String? ?? '',
      periodNumber: json['period_number'] as int? ?? 0,
      periodName: json['period_name'] as String? ?? '',
      subjectCode: json['subject_code'] as String? ?? '',
      subjectName: json['subject_name'] as String? ?? '',
      present: json['present'] as int? ?? 0,
      absent: json['absent'] as int? ?? 0,
      od: json['od'] as int? ?? 0,
      totalMarked: json['total_marked'] as int? ?? 0,
    );
  }
}

class AttendanceRangeReportModel {
  final int classId;
  final String className;
  final int? subjectId;
  final String? subjectCode;
  final String? subjectName;
  final String? scopeNote;
  final String fromDate;
  final String toDate;
  final int totalDays;
  final bool isSingleDay;
  final bool hasRecords;
  final int totalStudents;
  final int totalPeriodsConducted;
  final int present;
  final int absent;
  final int od;
  final int totalMarked;
  final double? percentage;
  final String percentageBasis;
  final String generatedAt;
  final List<RangeStudentSummaryModel> summary;
  final List<RangePeriodSummaryModel> periodSummary;

  AttendanceRangeReportModel({
    required this.classId,
    required this.className,
    this.subjectId,
    this.subjectCode,
    this.subjectName,
    this.scopeNote,
    required this.fromDate,
    required this.toDate,
    required this.totalDays,
    required this.isSingleDay,
    required this.hasRecords,
    required this.totalStudents,
    required this.totalPeriodsConducted,
    required this.present,
    required this.absent,
    required this.od,
    required this.totalMarked,
    this.percentage,
    required this.percentageBasis,
    required this.generatedAt,
    required this.summary,
    required this.periodSummary,
  });

  factory AttendanceRangeReportModel.fromJson(Map<String, dynamic> json) {
    return AttendanceRangeReportModel(
      classId: json['class_id'] as int? ?? 0,
      className: json['class_name'] as String? ?? '',
      subjectId: json['subject_id'] as int?,
      subjectCode: json['subject_code'] as String?,
      subjectName: json['subject_name'] as String?,
      scopeNote: json['scope_note'] as String?,
      fromDate: json['from_date'] as String? ?? '',
      toDate: json['to_date'] as String? ?? '',
      totalDays: json['total_days'] as int? ?? 0,
      isSingleDay: json['is_single_day'] as bool? ?? false,
      hasRecords: json['has_records'] as bool? ?? false,
      totalStudents: json['total_students'] as int? ?? 0,
      totalPeriodsConducted: json['total_periods_conducted'] as int? ?? 0,
      present: json['present'] as int? ?? 0,
      absent: json['absent'] as int? ?? 0,
      od: json['od'] as int? ?? 0,
      totalMarked: json['total_marked'] as int? ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble(),
      percentageBasis: json['percentage_basis'] as String? ?? '',
      generatedAt: json['generated_at'] as String? ?? '',
      summary: (json['summary'] as List? ?? [])
          .map((s) => RangeStudentSummaryModel.fromJson(Map<String, dynamic>.from(s as Map)))
          .toList(),
      periodSummary: (json['period_summary'] as List? ?? [])
          .map((p) => RangePeriodSummaryModel.fromJson(Map<String, dynamic>.from(p as Map)))
          .toList(),
    );
  }
}

