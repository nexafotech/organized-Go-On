import 'student_model.dart';

class FacultyScheduleItem {
  final int id;
  final String dayOfWeek;
  final int periodId;
  final int periodNumber;
  final String periodName;
  final String startTime;
  final String endTime;
  final int assignmentId;
  final String subjectCode;
  final String subjectName;
  final String className;
  final String? facultyName;
  final String? roomNo;
  final String? type;

  FacultyScheduleItem({
    required this.id,
    required this.dayOfWeek,
    required this.periodId,
    required this.periodNumber,
    required this.periodName,
    required this.startTime,
    required this.endTime,
    required this.assignmentId,
    required this.subjectCode,
    required this.subjectName,
    required this.className,
    this.facultyName,
    this.roomNo,
    this.type,
  });

  TimetableItemModel toTimetableItemModel() {
    return TimetableItemModel(
      dayOfWeek: dayOfWeek,
      periodNumber: periodNumber,
      periodName: periodName,
      startTime: startTime,
      endTime: endTime,
      subjectCode: subjectCode,
      subjectName: subjectName,
      facultyName: facultyName,
      roomNo: roomNo,
      type: type,
    );
  }

  factory FacultyScheduleItem.fromJson(Map<String, dynamic> json) {
    return FacultyScheduleItem(
      id: json['id'] as int? ?? 0,
      dayOfWeek: json['day_of_week'] as String? ?? '',
      periodId: json['period_id'] as int? ?? 0,
      periodNumber: json['period_number'] as int? ?? 0,
      periodName: json['period_name'] as String? ?? '',
      startTime: json['start_time'] as String? ?? '',
      endTime: json['end_time'] as String? ?? '',
      assignmentId: json['assignment_id'] as int? ?? 0,
      subjectCode: json['subject_code'] as String? ?? '',
      subjectName: json['subject_name'] as String? ?? '',
      className: json['class_name'] as String? ?? '',
      facultyName: json['faculty_name'] as String?,
      roomNo: json['room_no'] as String? ?? json['room'] as String?,
      type: json['type'] as String?,
    );
  }
}

class ActiveClassSlot {
  final int timetableEntryId;
  final int assignmentId;
  final String dayOfWeek;
  final String date;
  final int periodNumber;
  final String periodName;
  final String startTime;
  final String endTime;
  final String subjectCode;
  final String subjectName;
  final String className;
  final int classId;
  final int subjectId;

  ActiveClassSlot({
    required this.timetableEntryId,
    required this.assignmentId,
    required this.dayOfWeek,
    required this.date,
    required this.periodNumber,
    required this.periodName,
    required this.startTime,
    required this.endTime,
    required this.subjectCode,
    required this.subjectName,
    required this.className,
    required this.classId,
    required this.subjectId,
  });

  factory ActiveClassSlot.fromJson(Map<String, dynamic> json) {
    return ActiveClassSlot(
      timetableEntryId: json['timetable_entry_id'] as int? ?? 0,
      assignmentId: json['assignment_id'] as int? ?? 0,
      dayOfWeek: json['day_of_week'] as String? ?? '',
      date: json['date'] as String? ?? '',
      periodNumber: json['period_number'] as int? ?? 0,
      periodName: json['period_name'] as String? ?? '',
      startTime: json['start_time'] as String? ?? '',
      endTime: json['end_time'] as String? ?? '',
      subjectCode: json['subject_code'] as String? ?? '',
      subjectName: json['subject_name'] as String? ?? '',
      className: json['class_name'] as String? ?? '',
      classId: json['class_id'] as int? ?? 0,
      subjectId: json['subject_id'] as int? ?? 0,
    );
  }
}

class RosterStudentModel {
  final int studentId;
  final String rollNumber;
  final String fullName;
  final String? email;
  String attendanceStatus; // "PRESENT", "ABSENT", "OD", "UNMARKED"
  String? odReason;

  RosterStudentModel({
    required this.studentId,
    required this.rollNumber,
    required this.fullName,
    this.email,
    required this.attendanceStatus,
    this.odReason,
  });

  factory RosterStudentModel.fromJson(Map<String, dynamic> json) {
    return RosterStudentModel(
      studentId: json['student_id'] as int? ?? 0,
      rollNumber: json['roll_number'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String?,
      attendanceStatus: json['attendance_status'] as String? ?? 'UNMARKED',
      odReason: json['od_reason'] as String?,
    );
  }
}
