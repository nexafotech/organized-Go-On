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
  final String? avatarId;

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
    this.avatarId,
  });

  StudentSummaryModel copyWith({
    int? studentId,
    int? userId,
    String? fullName,
    String? registerNumber,
    String? email,
    String? className,
    int? classId,
    String? semester,
    String? department,
    bool? isActive,
    int? total,
    int? present,
    int? absent,
    int? od,
    int? halfDayPresent,
    int? halfDayAbsent,
    double? percentage,
    String? calculationMode,
    String? attendanceStatus,
    double? minimumRequired,
    bool? belowMinimum,
    String? alertMessage,
    int? requiredFutureClasses,
    int? estimatedWorkingDays,
    int? missableFutureClasses,
    String? avatarId,
  }) {
    return StudentSummaryModel(
      studentId: studentId ?? this.studentId,
      userId: userId ?? this.userId,
      fullName: fullName ?? this.fullName,
      registerNumber: registerNumber ?? this.registerNumber,
      email: email ?? this.email,
      className: className ?? this.className,
      classId: classId ?? this.classId,
      semester: semester ?? this.semester,
      department: department ?? this.department,
      isActive: isActive ?? this.isActive,
      total: total ?? this.total,
      present: present ?? this.present,
      absent: absent ?? this.absent,
      od: od ?? this.od,
      halfDayPresent: halfDayPresent ?? this.halfDayPresent,
      halfDayAbsent: halfDayAbsent ?? this.halfDayAbsent,
      percentage: percentage ?? this.percentage,
      calculationMode: calculationMode ?? this.calculationMode,
      attendanceStatus: attendanceStatus ?? this.attendanceStatus,
      minimumRequired: minimumRequired ?? this.minimumRequired,
      belowMinimum: belowMinimum ?? this.belowMinimum,
      alertMessage: alertMessage ?? this.alertMessage,
      requiredFutureClasses: requiredFutureClasses ?? this.requiredFutureClasses,
      estimatedWorkingDays: estimatedWorkingDays ?? this.estimatedWorkingDays,
      missableFutureClasses: missableFutureClasses ?? this.missableFutureClasses,
      avatarId: avatarId ?? this.avatarId,
    );
  }

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
      avatarId: json['avatar_id'] as String?,
    );
  }
}

class AvatarItemModel {
  final String id;
  final String name;
  final String category; // 'masculine', 'feminine', 'neutral'
  final bool isNeutral;
  final List<String> tags;
  final String assetPath;

  const AvatarItemModel({
    required this.id,
    required this.name,
    required this.category,
    this.isNeutral = false,
    required this.tags,
    required this.assetPath,
  });

  static const List<AvatarItemModel> catalog = [
    AvatarItemModel(
      id: 'avatar_m1',
      name: 'Curly Cream Hoodie',
      category: 'masculine',
      isNeutral: true,
      tags: ['hoodie', 'curly', 'casual'],
      assetPath: 'assets/avatars/avatar_m1.png',
    ),
    AvatarItemModel(
      id: 'avatar_f1',
      name: 'Wavy Blue Polo',
      category: 'feminine',
      isNeutral: true,
      tags: ['polo', 'bob', 'wavy'],
      assetPath: 'assets/avatars/avatar_f1.png',
    ),
    AvatarItemModel(
      id: 'avatar_m2',
      name: 'Sharp Black Jacket',
      category: 'masculine',
      isNeutral: false,
      tags: ['jacket', 'parted', 'smart'],
      assetPath: 'assets/avatars/avatar_m2.png',
    ),
    AvatarItemModel(
      id: 'avatar_m3',
      name: 'Green Tee & Glasses',
      category: 'masculine',
      isNeutral: true,
      tags: ['glasses', 'curly', 'crewneck'],
      assetPath: 'assets/avatars/avatar_m3.png',
    ),
    AvatarItemModel(
      id: 'avatar_m4',
      name: 'Black Collared Shirt',
      category: 'masculine',
      isNeutral: false,
      tags: ['button-up', 'wavy', 'minimal'],
      assetPath: 'assets/avatars/avatar_m4.png',
    ),
    AvatarItemModel(
      id: 'avatar_f2',
      name: 'Pink Tee with Fringe',
      category: 'feminine',
      isNeutral: false,
      tags: ['straight', 'fringe', 'casual'],
      assetPath: 'assets/avatars/avatar_f2.png',
    ),
    AvatarItemModel(
      id: 'avatar_m5',
      name: 'Beige Crewneck Fade',
      category: 'masculine',
      isNeutral: false,
      tags: ['fade', 'buzz-cut', 'modern'],
      assetPath: 'assets/avatars/avatar_m5.png',
    ),
    AvatarItemModel(
      id: 'avatar_f3',
      name: 'Lavender Ponytail Hoodie',
      category: 'feminine',
      isNeutral: false,
      tags: ['ponytail', 'hoodie', 'sporty'],
      assetPath: 'assets/avatars/avatar_f3.png',
    ),
    AvatarItemModel(
      id: 'avatar_f4',
      name: 'Yellow Dungarees Bob',
      category: 'feminine',
      isNeutral: true,
      tags: ['dungarees', 'bob', 'bangs'],
      assetPath: 'assets/avatars/avatar_f4.png',
    ),
    AvatarItemModel(
      id: 'avatar_m6',
      name: 'Green Hoodie & Round Glasses',
      category: 'masculine',
      isNeutral: true,
      tags: ['glasses', 'hoodie', 'curly'],
      assetPath: 'assets/avatars/avatar_m6.png',
    ),
    AvatarItemModel(
      id: 'avatar_f5',
      name: 'Striped Top Wavy Curls',
      category: 'feminine',
      isNeutral: true,
      tags: ['striped', 'long-hair', 'wavy'],
      assetPath: 'assets/avatars/avatar_f5.png',
    ),
    AvatarItemModel(
      id: 'avatar_m7',
      name: 'Blue Denim Jacket',
      category: 'masculine',
      isNeutral: false,
      tags: ['denim', 'parted', 'classic'],
      assetPath: 'assets/avatars/avatar_m7.png',
    ),
    AvatarItemModel(
      id: 'avatar_m8',
      name: 'Lilac Tee Messy Bangs',
      category: 'masculine',
      isNeutral: false,
      tags: ['lilac', 'messy-hair', 'casual'],
      assetPath: 'assets/avatars/avatar_m8.png',
    ),
    AvatarItemModel(
      id: 'avatar_f6',
      name: 'Turtleneck High Bun',
      category: 'feminine',
      isNeutral: false,
      tags: ['bun', 'turtleneck', 'elegant'],
      assetPath: 'assets/avatars/avatar_f6.png',
    ),
    AvatarItemModel(
      id: 'avatar_f7',
      name: 'Classic Black Hijab',
      category: 'feminine',
      isNeutral: false,
      tags: ['hijab', 'modest', 'warm'],
      assetPath: 'assets/avatars/avatar_f7.png',
    ),
    AvatarItemModel(
      id: 'avatar_f8',
      name: 'Terracotta Natural Curls',
      category: 'feminine',
      isNeutral: false,
      tags: ['curly', 'volume', 'natural'],
      assetPath: 'assets/avatars/avatar_f8.png',
    ),
  ];

  static AvatarItemModel findById(String? id) {
    if (id == null || id.isEmpty) return catalog.first;
    return catalog.firstWhere((a) => a.id == id, orElse: () => catalog.first);
  }

  static String resolveAsset(String? id, {String fallbackSeed = ''}) {
    if (id != null && id.isNotEmpty) {
      final match = catalog.where((a) => a.id == id);
      if (match.isNotEmpty) return match.first.assetPath;
    }
    if (fallbackSeed.isNotEmpty) {
      int hash = 0;
      for (int i = 0; i < fallbackSeed.length; i++) {
        hash = (hash * 31 + fallbackSeed.codeUnitAt(i)) & 0x7FFFFFFF;
      }
      final idx = hash % catalog.length;
      return catalog[idx].assetPath;
    }
    return catalog.first.assetPath;
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
  final String? roomNo;
  final int span;
  final String? type;
  final String? colorTag;

  TimetableItemModel({
    required this.dayOfWeek,
    this.periodNumber,
    this.periodName,
    this.startTime,
    this.endTime,
    this.subjectCode,
    this.subjectName,
    this.facultyName,
    this.roomNo,
    this.span = 1,
    this.type,
    this.colorTag,
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
      roomNo: json['room_no'] as String? ?? json['room'] as String?,
      span: json['span'] as int? ?? 1,
      type: json['type'] as String?,
      colorTag: json['color_tag'] as String?,
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


