import 'package:flutter/foundation.dart';
import '../core/config/api_config.dart';
import '../core/network/api_client.dart';
import '../models/student_model.dart';
import '../design_mode/design_mock_data.dart';

class StudentService extends ChangeNotifier {
  final ApiClient _apiClient;

  StudentSummaryModel? _summary;
  List<SubjectAttendanceModel> _subjects = [];
  List<TimetableItemModel> _timetable = [];
  List<DateWiseEntryModel> _dateWise = [];
  bool _isLoading = false;
  String? _errorMessage;

  StudentService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  StudentSummaryModel? get summary => _summary;
  List<SubjectAttendanceModel> get subjects => _subjects;
  List<TimetableItemModel> get timetable => _timetable;
  List<DateWiseEntryModel> get dateWise => _dateWise;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void setMockData({
    StudentSummaryModel? summary,
    List<SubjectAttendanceModel>? subjects,
    List<TimetableItemModel>? timetable,
    List<DateWiseEntryModel>? dateWise,
  }) {
    if (summary != null) _summary = summary;
    if (subjects != null) _subjects = subjects;
    if (timetable != null) _timetable = timetable;
    if (dateWise != null) _dateWise = dateWise;
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> fetchStudentSummary() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiClient.get(ApiConfig.studentMe);
      _summary = StudentSummaryModel.fromJson(response);
      _isLoading = false;
      notifyListeners();
    } on ApiException catch (e) {
      _isLoading = false;
      _errorMessage = e.message;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to load student summary';
      notifyListeners();
    }
  }

  Future<void> fetchSubjects() async {
    try {
      final response = await _apiClient.get(ApiConfig.studentSubjects);
      if (response is List) {
        _subjects = response.map((item) => SubjectAttendanceModel.fromJson(item)).toList();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> fetchTimetable() async {
    try {
      final response = await _apiClient.get(ApiConfig.studentTimetable);
      if (response is Map && response.containsKey('timetable') && response['timetable'] is List) {
        final List rawList = response['timetable'];
        final fetched = rawList.map((item) => TimetableItemModel.fromJson(item)).toList();
        if (fetched.isNotEmpty) {
          _timetable = fetched;
          notifyListeners();
          return;
        }
      }
    } catch (_) {}

    if (_timetable.isEmpty) {
      _timetable = DesignMockData.mockTimetable;
      notifyListeners();
    }
  }

  Future<void> fetchAttendanceReport() async {
    try {
      final response = await _apiClient.get(ApiConfig.studentAttendance);
      if (response is Map) {
        if (response.containsKey('date_wise') && response['date_wise'] is List) {
          final List rawList = response['date_wise'];
          _dateWise = rawList
              .map((item) => DateWiseEntryModel.fromJson(Map<String, dynamic>.from(item as Map)))
              .toList();
        }
        if (response.containsKey('subjects') && response['subjects'] is List) {
          final List rawSubs = response['subjects'];
          _subjects = rawSubs
              .map((item) => SubjectAttendanceModel.fromJson(Map<String, dynamic>.from(item as Map)))
              .toList();
        }
        if (_summary != null && response.containsKey('percentage')) {
          _summary = _summary!.copyWith(
            total: response['total'] as int? ?? _summary!.total,
            present: response['present'] as int? ?? _summary!.present,
            absent: response['absent'] as int? ?? _summary!.absent,
            od: response['od'] as int? ?? _summary!.od,
            halfDayPresent: response['half_day_present'] as int? ?? _summary!.halfDayPresent,
            halfDayAbsent: response['half_day_absent'] as int? ?? _summary!.halfDayAbsent,
            percentage: (response['percentage'] as num?)?.toDouble() ?? _summary!.percentage,
            attendanceStatus: response['status'] as String? ?? _summary!.attendanceStatus,
            belowMinimum: response['below_minimum'] as bool? ?? _summary!.belowMinimum,
            alertMessage: response['alert_message'] as String? ?? _summary!.alertMessage,
            requiredFutureClasses: response['required_future_classes'] as int? ?? _summary!.requiredFutureClasses,
            estimatedWorkingDays: response['estimated_working_days'] as int? ?? _summary!.estimatedWorkingDays,
            missableFutureClasses: response['missable_future_classes'] as int? ?? _summary!.missableFutureClasses,
          );
        }
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> fetchAttendanceReportFiltered({
    int? subjectId,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final path = ApiConfig.studentAttendanceReport(
        subjectId: subjectId,
        startDate: startDate,
        endDate: endDate,
      );
      final response = await _apiClient.get(path);
      if (response is Map) {
        if (response.containsKey('date_wise') && response['date_wise'] is List) {
          final List rawList = response['date_wise'];
          _dateWise = rawList
              .map((item) => DateWiseEntryModel.fromJson(Map<String, dynamic>.from(item as Map)))
              .toList();
        }
        if (response.containsKey('subjects') && response['subjects'] is List) {
          final List rawSubs = response['subjects'];
          _subjects = rawSubs
              .map((item) => SubjectAttendanceModel.fromJson(Map<String, dynamic>.from(item as Map)))
              .toList();
        }
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<bool> updateAvatar(String avatarId) async {
    try {
      final response = await _apiClient.patch(
        ApiConfig.studentAvatar,
        body: {'avatar_id': avatarId},
      );
      if (response is Map && response['success'] == true) {
        if (_summary != null) {
          _summary = _summary!.copyWith(avatarId: avatarId);
          notifyListeners();
        }
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[StudentService] updateAvatar error: $e');
      rethrow;
    }
  }

  Future<bool> updateProfile({String? email, String? phone, String? avatarId}) async {
    return updateProfileDetails(email: email, phone: phone, avatarId: avatarId);
  }

  Future<bool> updateProfileDetails({
    String? fullName,
    String? email,
    String? phone,
    String? avatarId,
  }) async {
    final payload = <String, dynamic>{};
    if (fullName != null && fullName.trim().isNotEmpty) payload['full_name'] = fullName.trim();
    if (email != null) payload['email'] = email.trim();
    if (phone != null) payload['phone'] = phone.trim();
    if (avatarId != null && avatarId.trim().isNotEmpty) payload['avatar_id'] = avatarId.trim();

    try {
      final response = await _apiClient.patch(
        ApiConfig.studentProfile,
        body: payload,
      );
      if (response is Map && (response['success'] == true || response['student_id'] != null)) {
        if (_summary != null) {
          _summary = _summary!.copyWith(
            fullName: response['full_name'] as String? ?? fullName ?? _summary!.fullName,
            email: response.containsKey('email') ? response['email'] as String? : (email ?? _summary!.email),
            phone: response.containsKey('phone') ? response['phone'] as String? : (phone ?? _summary!.phone),
            avatarId: response['avatar_id'] as String? ?? avatarId ?? _summary!.avatarId,
          );
          notifyListeners();
        }
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[StudentService] updateProfileDetails error: $e');
      rethrow;
    }
  }

  Future<void> loadDashboardData() async {
    await Future.wait([
      fetchStudentSummary(),
      fetchSubjects(),
      fetchTimetable(),
      fetchAttendanceReport(),
    ]);
  }
}

