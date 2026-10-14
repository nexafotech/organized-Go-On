class AvailablePeriodItem {
  final int timetableEntryId;
  final int periodId;
  final int periodNumber;
  final String periodName;
  final String startTime;
  final String endTime;
  final String subjectCode;
  final String subjectName;
  final int classId;
  final String className;
  final String date;
  final String dayOfWeek;
  final String facultyName;
  final String status; // "AVAILABLE", "ALREADY_MARKED", "LOCKED"
  final bool canMark;
  final String? lockReason;
  final int? sessionId;

  AvailablePeriodItem({
    required this.timetableEntryId,
    required this.periodId,
    required this.periodNumber,
    required this.periodName,
    required this.startTime,
    required this.endTime,
    required this.subjectCode,
    required this.subjectName,
    required this.classId,
    required this.className,
    required this.date,
    required this.dayOfWeek,
    required this.facultyName,
    required this.status,
    required this.canMark,
    this.lockReason,
    this.sessionId,
  });

  factory AvailablePeriodItem.fromJson(Map<String, dynamic> json) {
    return AvailablePeriodItem(
      timetableEntryId: json['timetable_entry_id'] as int? ?? 0,
      periodId: json['period_id'] as int? ?? 0,
      periodNumber: json['period_number'] as int? ?? 0,
      periodName: json['period_name'] as String? ?? '',
      startTime: json['start_time'] as String? ?? '',
      endTime: json['end_time'] as String? ?? '',
      subjectCode: json['subject_code'] as String? ?? '',
      subjectName: json['subject_name'] as String? ?? '',
      classId: json['class_id'] as int? ?? 0,
      className: json['class_name'] as String? ?? '',
      date: json['date'] as String? ?? '',
      dayOfWeek: json['day_of_week'] as String? ?? '',
      facultyName: json['faculty_name'] as String? ?? '',
      status: json['status'] as String? ?? 'LOCKED',
      canMark: json['can_mark'] as bool? ?? false,
      lockReason: json['lock_reason'] as String?,
      sessionId: json['session_id'] as int?,
    );
  }
}

class AvailablePeriodsResponse {
  final String todayDate;
  final String todayDay;
  final String yesterdayDate;
  final String yesterdayDay;
  final String currentTime;
  final List<AvailablePeriodItem> todayPeriods;
  final List<AvailablePeriodItem> yesterdayPeriods;

  AvailablePeriodsResponse({
    required this.todayDate,
    required this.todayDay,
    required this.yesterdayDate,
    required this.yesterdayDay,
    required this.currentTime,
    required this.todayPeriods,
    required this.yesterdayPeriods,
  });

  factory AvailablePeriodsResponse.fromJson(Map<String, dynamic> json) {
    return AvailablePeriodsResponse(
      todayDate: json['today_date'] as String? ?? '',
      todayDay: json['today_day'] as String? ?? '',
      yesterdayDate: json['yesterday_date'] as String? ?? '',
      yesterdayDay: json['yesterday_day'] as String? ?? '',
      currentTime: json['current_time'] as String? ?? '',
      todayPeriods: (json['today_periods'] as List? ?? [])
          .map((i) => AvailablePeriodItem.fromJson(Map<String, dynamic>.from(i as Map)))
          .toList(),
      yesterdayPeriods: (json['yesterday_periods'] as List? ?? [])
          .map((i) => AvailablePeriodItem.fromJson(Map<String, dynamic>.from(i as Map)))
          .toList(),
    );
  }
}

class StudentRosterItem {
  final int studentId;
  final String rollNumber;
  final String fullName;
  final String? email;
  String attendanceStatus; // "PRESENT", "ABSENT", "OD", "UNMARKED"
  String? odReason;
  bool recognizedInBatch;
  String? recognitionEvidence;

  StudentRosterItem({
    required this.studentId,
    required this.rollNumber,
    required this.fullName,
    this.email,
    required this.attendanceStatus,
    this.odReason,
    this.recognizedInBatch = false,
    this.recognitionEvidence,
  });

  factory StudentRosterItem.fromJson(Map<String, dynamic> json) {
    return StudentRosterItem(
      studentId: json['student_id'] as int? ?? 0,
      rollNumber: json['roll_number'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String?,
      attendanceStatus: json['attendance_status'] as String? ?? 'UNMARKED',
      odReason: json['od_reason'] as String?,
    );
  }
}

class FacultyAttendanceRosterResponse {
  final int timetableEntryId;
  final String date;
  final String dayOfWeek;
  final int periodId;
  final int periodNumber;
  final String periodName;
  final String startTime;
  final String endTime;
  final String subjectCode;
  final String subjectName;
  final int classId;
  final String className;
  final String facultyName;
  final String status;
  final bool canMark;
  final String? lockReason;
  final int? sessionId;
  final bool alreadyMarked;
  final List<StudentRosterItem> roster;

  FacultyAttendanceRosterResponse({
    required this.timetableEntryId,
    required this.date,
    required this.dayOfWeek,
    required this.periodId,
    required this.periodNumber,
    required this.periodName,
    required this.startTime,
    required this.endTime,
    required this.subjectCode,
    required this.subjectName,
    required this.classId,
    required this.className,
    required this.facultyName,
    required this.status,
    required this.canMark,
    this.lockReason,
    this.sessionId,
    required this.alreadyMarked,
    required this.roster,
  });

  factory FacultyAttendanceRosterResponse.fromJson(Map<String, dynamic> json) {
    return FacultyAttendanceRosterResponse(
      timetableEntryId: json['timetable_entry_id'] as int? ?? 0,
      date: json['date'] as String? ?? '',
      dayOfWeek: json['day_of_week'] as String? ?? '',
      periodId: json['period_id'] as int? ?? 0,
      periodNumber: json['period_number'] as int? ?? 0,
      periodName: json['period_name'] as String? ?? '',
      startTime: json['start_time'] as String? ?? '',
      endTime: json['end_time'] as String? ?? '',
      subjectCode: json['subject_code'] as String? ?? '',
      subjectName: json['subject_name'] as String? ?? '',
      classId: json['class_id'] as int? ?? 0,
      className: json['class_name'] as String? ?? '',
      facultyName: json['faculty_name'] as String? ?? '',
      status: json['status'] as String? ?? '',
      canMark: json['can_mark'] as bool? ?? false,
      lockReason: json['lock_reason'] as String?,
      sessionId: json['session_id'] as int?,
      alreadyMarked: json['already_marked'] as bool? ?? false,
      roster: (json['roster'] as List? ?? [])
          .map((i) => StudentRosterItem.fromJson(Map<String, dynamic>.from(i as Map)))
          .toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Class Advisor Models
// ─────────────────────────────────────────────────────────────

class AdvisedClassInfo {
  final int id;
  final String name;
  final String? academicYear;
  final String? gradeLevel;

  AdvisedClassInfo({
    required this.id,
    required this.name,
    this.academicYear,
    this.gradeLevel,
  });

  factory AdvisedClassInfo.fromJson(Map<String, dynamic> json) {
    return AdvisedClassInfo(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      academicYear: json['academic_year'] as String?,
      gradeLevel: json['grade_level'] as String?,
    );
  }
}

class LunchBreakInfo {
  final String startTime;
  final String endTime;
  final String label;
  final String note;

  LunchBreakInfo({
    this.startTime = '12:50',
    this.endTime = '13:40',
    this.label = 'Lunch Break (12:50 PM - 01:40 PM)',
    this.note = 'Institutional break — strictly excluded from attendance marking and calculations.',
  });

  factory LunchBreakInfo.fromJson(Map<String, dynamic> json) {
    return LunchBreakInfo(
      startTime: json['start_time'] as String? ?? '12:50',
      endTime: json['end_time'] as String? ?? '13:40',
      label: json['label'] as String? ?? 'Lunch Break (12:50 PM - 01:40 PM)',
      note: json['note'] as String? ??
          'Institutional break — strictly excluded from attendance marking and calculations.',
    );
  }
}

class ClassAdvisorPeriodItem {
  final int timetableEntryId;
  final int periodId;
  final int periodNumber;
  final String periodName;
  final String startTime;
  final String endTime;
  final String sessionType; // "MORNING" or "AFTERNOON"
  final String subjectCode;
  final String subjectName;
  final int classId;
  final String className;
  final String date;
  final String dayOfWeek;
  final String subjectFacultyName;
  final String status; // "AVAILABLE", "ALREADY_MARKED", "LOCKED"
  final bool canMark;
  final String? lockReason;
  final int? sessionId;
  final int recordCount;

  ClassAdvisorPeriodItem({
    required this.timetableEntryId,
    required this.periodId,
    required this.periodNumber,
    required this.periodName,
    required this.startTime,
    required this.endTime,
    required this.sessionType,
    required this.subjectCode,
    required this.subjectName,
    required this.classId,
    required this.className,
    required this.date,
    required this.dayOfWeek,
    required this.subjectFacultyName,
    required this.status,
    required this.canMark,
    this.lockReason,
    this.sessionId,
    this.recordCount = 0,
  });

  factory ClassAdvisorPeriodItem.fromJson(Map<String, dynamic> json) {
    return ClassAdvisorPeriodItem(
      timetableEntryId: json['timetable_entry_id'] as int? ?? 0,
      periodId: json['period_id'] as int? ?? 0,
      periodNumber: json['period_number'] as int? ?? 0,
      periodName: json['period_name'] as String? ?? '',
      startTime: json['start_time'] as String? ?? '',
      endTime: json['end_time'] as String? ?? '',
      sessionType: json['session_type'] as String? ?? 'MORNING',
      subjectCode: json['subject_code'] as String? ?? '',
      subjectName: json['subject_name'] as String? ?? '',
      classId: json['class_id'] as int? ?? 0,
      className: json['class_name'] as String? ?? '',
      date: json['date'] as String? ?? '',
      dayOfWeek: json['day_of_week'] as String? ?? '',
      subjectFacultyName: json['subject_faculty_name'] as String? ?? 'Unassigned',
      status: json['status'] as String? ?? 'LOCKED',
      canMark: json['can_mark'] as bool? ?? false,
      lockReason: json['lock_reason'] as String?,
      sessionId: json['session_id'] as int?,
      recordCount: json['record_count'] as int? ?? 0,
    );
  }
}

class ClassAdvisorAvailablePeriodsResponse {
  final bool isClassAdvisor;
  final AdvisedClassInfo? advisedClass;
  final String todayDate;
  final String todayDay;
  final String yesterdayDate;
  final String yesterdayDay;
  final String currentTime;
  final List<ClassAdvisorPeriodItem> todayPeriods;
  final List<ClassAdvisorPeriodItem> yesterdayPeriods;
  final LunchBreakInfo lunchBreak;

  ClassAdvisorAvailablePeriodsResponse({
    required this.isClassAdvisor,
    this.advisedClass,
    required this.todayDate,
    required this.todayDay,
    required this.yesterdayDate,
    required this.yesterdayDay,
    required this.currentTime,
    required this.todayPeriods,
    required this.yesterdayPeriods,
    required this.lunchBreak,
  });

  factory ClassAdvisorAvailablePeriodsResponse.fromJson(Map<String, dynamic> json) {
    return ClassAdvisorAvailablePeriodsResponse(
      isClassAdvisor: json['is_class_advisor'] as bool? ?? false,
      advisedClass: json['advised_class'] != null
          ? AdvisedClassInfo.fromJson(Map<String, dynamic>.from(json['advised_class'] as Map))
          : null,
      todayDate: json['today_date'] as String? ?? '',
      todayDay: json['today_day'] as String? ?? '',
      yesterdayDate: json['yesterday_date'] as String? ?? '',
      yesterdayDay: json['yesterday_day'] as String? ?? '',
      currentTime: json['current_time'] as String? ?? '',
      todayPeriods: (json['today_periods'] as List? ?? [])
          .map((i) => ClassAdvisorPeriodItem.fromJson(Map<String, dynamic>.from(i as Map)))
          .toList(),
      yesterdayPeriods: (json['yesterday_periods'] as List? ?? [])
          .map((i) => ClassAdvisorPeriodItem.fromJson(Map<String, dynamic>.from(i as Map)))
          .toList(),
      lunchBreak: json['lunch_break'] != null
          ? LunchBreakInfo.fromJson(Map<String, dynamic>.from(json['lunch_break'] as Map))
          : LunchBreakInfo(),
    );
  }
}

class ClassAdvisorAttendanceRosterResponse {
  final int timetableEntryId;
  final String date;
  final String dayOfWeek;
  final int periodId;
  final int periodNumber;
  final String periodName;
  final String startTime;
  final String endTime;
  final String subjectCode;
  final String subjectName;
  final int classId;
  final String className;
  final String subjectFacultyName;
  final String status;
  final bool canMark;
  final int? sessionId;
  final bool alreadyMarked;
  final String? lastUpdatedAt;
  final List<StudentRosterItem> roster;

  ClassAdvisorAttendanceRosterResponse({
    required this.timetableEntryId,
    required this.date,
    required this.dayOfWeek,
    required this.periodId,
    required this.periodNumber,
    required this.periodName,
    required this.startTime,
    required this.endTime,
    required this.subjectCode,
    required this.subjectName,
    required this.classId,
    required this.className,
    required this.subjectFacultyName,
    required this.status,
    required this.canMark,
    this.sessionId,
    required this.alreadyMarked,
    this.lastUpdatedAt,
    required this.roster,
  });

  factory ClassAdvisorAttendanceRosterResponse.fromJson(Map<String, dynamic> json) {
    return ClassAdvisorAttendanceRosterResponse(
      timetableEntryId: json['timetable_entry_id'] as int? ?? 0,
      date: json['date'] as String? ?? '',
      dayOfWeek: json['day_of_week'] as String? ?? '',
      periodId: json['period_id'] as int? ?? 0,
      periodNumber: json['period_number'] as int? ?? 0,
      periodName: json['period_name'] as String? ?? '',
      startTime: json['start_time'] as String? ?? '',
      endTime: json['end_time'] as String? ?? '',
      subjectCode: json['subject_code'] as String? ?? '',
      subjectName: json['subject_name'] as String? ?? '',
      classId: json['class_id'] as int? ?? 0,
      className: json['class_name'] as String? ?? '',
      subjectFacultyName: json['subject_faculty_name'] as String? ?? 'Unassigned',
      status: json['status'] as String? ?? '',
      canMark: json['can_mark'] as bool? ?? false,
      sessionId: json['session_id'] as int?,
      alreadyMarked: json['already_marked'] as bool? ?? false,
      lastUpdatedAt: json['last_updated_at'] as String?,
      roster: (json['roster'] as List? ?? [])
          .map((i) => StudentRosterItem.fromJson(Map<String, dynamic>.from(i as Map)))
          .toList(),
    );
  }
}

class ClassDailyStudentSummary {
  final int studentId;
  final String rollNumber;
  final String fullName;
  final String morningStatus;
  final String morningText;
  final String afternoonStatus;
  final String afternoonText;
  final String dailyResult;

  ClassDailyStudentSummary({
    required this.studentId,
    required this.rollNumber,
    required this.fullName,
    required this.morningStatus,
    required this.morningText,
    required this.afternoonStatus,
    required this.afternoonText,
    required this.dailyResult,
  });

  factory ClassDailyStudentSummary.fromJson(Map<String, dynamic> json) {
    return ClassDailyStudentSummary(
      studentId: json['student_id'] as int? ?? 0,
      rollNumber: json['roll_number'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      morningStatus: json['morning_status'] as String? ?? 'NOT ENTERED',
      morningText: json['morning_text'] as String? ?? '',
      afternoonStatus: json['afternoon_status'] as String? ?? 'NOT ENTERED',
      afternoonText: json['afternoon_text'] as String? ?? '',
      dailyResult: json['daily_result'] as String? ?? 'NOT ENTERED',
    );
  }
}

class ClassDailySummaryResponse {
  final int classId;
  final String className;
  final String date;
  final int totalStudents;
  final int fullDayPresentCount;
  final int halfDayPresentCount;
  final int fullDayAbsentCount;
  final int odCount;
  final int notEnteredCount;
  final int partialCount;
  final String lunchInterval;
  final List<ClassDailyStudentSummary> students;

  ClassDailySummaryResponse({
    required this.classId,
    required this.className,
    required this.date,
    required this.totalStudents,
    required this.fullDayPresentCount,
    required this.halfDayPresentCount,
    required this.fullDayAbsentCount,
    required this.odCount,
    required this.notEnteredCount,
    required this.partialCount,
    this.lunchInterval = '12:50 PM - 01:40 PM (Not Counted)',
    required this.students,
  });

  factory ClassDailySummaryResponse.fromJson(Map<String, dynamic> json) {
    return ClassDailySummaryResponse(
      classId: json['class_id'] as int? ?? 0,
      className: json['class_name'] as String? ?? '',
      date: json['date'] as String? ?? '',
      totalStudents: json['total_students'] as int? ?? 0,
      fullDayPresentCount: json['full_day_present_count'] as int? ?? 0,
      halfDayPresentCount: json['half_day_present_count'] as int? ?? 0,
      fullDayAbsentCount: json['full_day_absent_count'] as int? ?? 0,
      odCount: json['od_count'] as int? ?? 0,
      notEnteredCount: json['not_entered_count'] as int? ?? 0,
      partialCount: json['partial_count'] as int? ?? 0,
      lunchInterval: json['lunch_interval'] as String? ?? '12:50 PM - 01:40 PM (Not Counted)',
      students: (json['students'] as List? ?? [])
          .map((i) => ClassDailyStudentSummary.fromJson(Map<String, dynamic>.from(i as Map)))
          .toList(),
    );
  }
}

class ClassAdvisorAttendanceSubmitResponse {
  final String message;
  final int sessionId;
  final String date;
  final int periodNumber;
  final int recordsCount;
  final String status;
  final ClassDailySummaryResponse? dailySummary;

  ClassAdvisorAttendanceSubmitResponse({
    required this.message,
    required this.sessionId,
    required this.date,
    required this.periodNumber,
    required this.recordsCount,
    required this.status,
    this.dailySummary,
  });

  factory ClassAdvisorAttendanceSubmitResponse.fromJson(Map<String, dynamic> json) {
    return ClassAdvisorAttendanceSubmitResponse(
      message: json['message'] as String? ?? '',
      sessionId: json['session_id'] as int? ?? 0,
      date: json['date'] as String? ?? '',
      periodNumber: json['period_number'] as int? ?? 0,
      recordsCount: json['records_count'] as int? ?? 0,
      status: json['status'] as String? ?? '',
      dailySummary: json['daily_summary'] != null
          ? ClassDailySummaryResponse.fromJson(Map<String, dynamic>.from(json['daily_summary'] as Map))
          : null,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Phase 8: Retrospective Periods & Batch Photo Models
// ─────────────────────────────────────────────────────────────

class FacultyPeriodsForDateResponse {
  final String date;
  final String dayOfWeek;
  final bool isToday;
  final List<AvailablePeriodItem> periods;

  FacultyPeriodsForDateResponse({
    required this.date,
    required this.dayOfWeek,
    required this.isToday,
    required this.periods,
  });

  factory FacultyPeriodsForDateResponse.fromJson(Map<String, dynamic> json) {
    return FacultyPeriodsForDateResponse(
      date: json['date'] as String? ?? '',
      dayOfWeek: json['day_of_week'] as String? ?? '',
      isToday: json['is_today'] as bool? ?? false,
      periods: (json['periods'] as List? ?? [])
          .map((i) => AvailablePeriodItem.fromJson(Map<String, dynamic>.from(i as Map)))
          .toList(),
    );
  }
}

class ClassAdvisorPeriodsForDateResponse {
  final bool isClassAdvisor;
  final AdvisedClassInfo? advisedClass;
  final String date;
  final String dayOfWeek;
  final bool isToday;
  final List<ClassAdvisorPeriodItem> periods;
  final LunchBreakInfo lunchBreak;

  ClassAdvisorPeriodsForDateResponse({
    required this.isClassAdvisor,
    this.advisedClass,
    required this.date,
    required this.dayOfWeek,
    required this.isToday,
    required this.periods,
    required this.lunchBreak,
  });

  factory ClassAdvisorPeriodsForDateResponse.fromJson(Map<String, dynamic> json) {
    return ClassAdvisorPeriodsForDateResponse(
      isClassAdvisor: json['is_class_advisor'] as bool? ?? false,
      advisedClass: json['advised_class'] != null
          ? AdvisedClassInfo.fromJson(Map<String, dynamic>.from(json['advised_class'] as Map))
          : null,
      date: json['date'] as String? ?? '',
      dayOfWeek: json['day_of_week'] as String? ?? '',
      isToday: json['is_today'] as bool? ?? false,
      periods: (json['periods'] as List? ?? [])
          .map((i) => ClassAdvisorPeriodItem.fromJson(Map<String, dynamic>.from(i as Map)))
          .toList(),
      lunchBreak: json['lunch_break'] != null
          ? LunchBreakInfo.fromJson(Map<String, dynamic>.from(json['lunch_break'] as Map))
          : LunchBreakInfo(),
    );
  }
}

class BatchRecognizedStudent {
  final int studentId;
  final String rollNumber;
  final String name;
  final double bestDistance;
  final double bestConfidence;
  final int recognizedInPhotosCount;
  final List<String> sourcePhotos;

  BatchRecognizedStudent({
    required this.studentId,
    required this.rollNumber,
    required this.name,
    required this.bestDistance,
    required this.bestConfidence,
    required this.recognizedInPhotosCount,
    required this.sourcePhotos,
  });

  factory BatchRecognizedStudent.fromJson(Map<String, dynamic> json) {
    return BatchRecognizedStudent(
      studentId: json['student_id'] as int? ?? 0,
      rollNumber: json['roll_number'] as String? ?? '',
      name: json['name'] as String? ?? '',
      bestDistance: (json['best_distance'] as num?)?.toDouble() ?? 0.0,
      bestConfidence: (json['best_confidence'] as num?)?.toDouble() ?? 0.0,
      recognizedInPhotosCount: json['recognized_in_photos_count'] as int? ?? 1,
      sourcePhotos: (json['source_photos'] as List? ?? []).map((e) => e.toString()).toList(),
    );
  }
}

class BatchPhotoSummary {
  final String filename;
  final int facesDetected;
  final int recognizedCount;
  final String status;
  final String? errorDetail;

  BatchPhotoSummary({
    required this.filename,
    required this.facesDetected,
    required this.recognizedCount,
    required this.status,
    this.errorDetail,
  });

  factory BatchPhotoSummary.fromJson(Map<String, dynamic> json) {
    return BatchPhotoSummary(
      filename: json['filename'] as String? ?? '',
      facesDetected: json['faces_detected'] as int? ?? 0,
      recognizedCount: json['recognized_count'] as int? ?? 0,
      status: json['status'] as String? ?? 'SUCCESS',
      errorDetail: json['error_detail'] as String?,
    );
  }
}

class BatchRecognitionResultModel {
  final int totalPhotos;
  final int photosProcessed;
  final int photosFailed;
  final int totalFacesDetected;
  final int uniqueRecognizedCount;
  final List<BatchRecognizedStudent> recognizedStudents;
  final List<BatchPhotoSummary> photoSummaries;

  BatchRecognitionResultModel({
    required this.totalPhotos,
    required this.photosProcessed,
    required this.photosFailed,
    required this.totalFacesDetected,
    required this.uniqueRecognizedCount,
    required this.recognizedStudents,
    required this.photoSummaries,
  });

  factory BatchRecognitionResultModel.fromJson(Map<String, dynamic> json) {
    return BatchRecognitionResultModel(
      totalPhotos: json['total_photos'] as int? ?? 0,
      photosProcessed: json['photos_processed'] as int? ?? 0,
      photosFailed: json['photos_failed'] as int? ?? 0,
      totalFacesDetected: json['total_faces_detected'] as int? ?? 0,
      uniqueRecognizedCount: json['unique_recognized_count'] as int? ?? 0,
      recognizedStudents: (json['recognized_students'] as List? ?? [])
          .map((i) => BatchRecognizedStudent.fromJson(Map<String, dynamic>.from(i as Map)))
          .toList(),
      photoSummaries: (json['photo_summaries'] as List? ?? [])
          .map((i) => BatchPhotoSummary.fromJson(Map<String, dynamic>.from(i as Map)))
          .toList(),
    );
  }
}
