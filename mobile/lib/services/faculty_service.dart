import 'dart:io';
import 'package:flutter/foundation.dart';
import '../core/config/api_config.dart';
import '../core/network/api_client.dart';
import '../models/faculty_model.dart';
import '../models/recognition_model.dart';
import '../models/faculty_attendance_model.dart';
import '../models/faculty_report_model.dart';

class FacultyService extends ChangeNotifier {
  final ApiClient _apiClient;

  List<FacultyScheduleItem> _schedule = [];
  ActiveClassSlot? _activeSlot;
  bool _hasActiveSlot = false;

  int? _activeSessionId;
  String? _activeSessionStatus;
  List<RosterStudentModel> _roster = [];
  bool _isLoading = false;
  String? _errorMessage;

  bool _isClassAdvisor = false;
  AdvisedClassInfo? _advisedClass;

  FacultyService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  List<FacultyScheduleItem> get schedule => _schedule;
  ActiveClassSlot? get activeSlot => _activeSlot;
  bool get hasActiveSlot => _hasActiveSlot;
  int? get activeSessionId => _activeSessionId;
  String? get activeSessionStatus => _activeSessionStatus;
  List<RosterStudentModel> get roster => _roster;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  bool get isClassAdvisor => _isClassAdvisor;
  AdvisedClassInfo? get advisedClass => _advisedClass;

  void setMockData({
    List<FacultyScheduleItem>? schedule,
    ActiveClassSlot? activeSlot,
    List<RosterStudentModel>? roster,
    bool? isClassAdvisor,
    AdvisedClassInfo? advisedClass,
  }) {
    if (schedule != null) _schedule = schedule;
    if (activeSlot != null) {
      _activeSlot = activeSlot;
      _hasActiveSlot = true;
    }
    if (roster != null) _roster = roster;
    if (isClassAdvisor != null) _isClassAdvisor = isClassAdvisor;
    if (advisedClass != null) _advisedClass = advisedClass;
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> fetchSchedule() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiClient.get(ApiConfig.facultyTimetable);
      if (response is Map && response.containsKey('timetable') && response['timetable'] is List) {
        final List rawList = response['timetable'];
        _schedule = rawList
            .map((item) => FacultyScheduleItem.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
      }
      _isLoading = false;
      notifyListeners();
    } on ApiException catch (e) {
      _isLoading = false;
      _errorMessage = e.message;
      notifyListeners();
    } catch (_) {
      _isLoading = false;
      _errorMessage = 'Failed to load faculty schedule';
      notifyListeners();
    }
  }

  Future<void> checkActiveClassSlot() async {
    try {
      final response = await _apiClient.get(ApiConfig.facultyActiveClass);
      if (response is Map) {
        _hasActiveSlot = response['has_active_class'] as bool? ?? false;
        if (response['active_class'] != null && response['active_class'] is Map) {
          _activeSlot = ActiveClassSlot.fromJson(Map<String, dynamic>.from(response['active_class'] as Map));
        } else {
          _activeSlot = null;
        }

        _isClassAdvisor = response['is_class_advisor'] as bool? ?? false;
        if (response['advised_class'] != null && response['advised_class'] is Map) {
          _advisedClass = AdvisedClassInfo.fromJson(Map<String, dynamic>.from(response['advised_class'] as Map));
        } else {
          _advisedClass = null;
        }

        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> checkActiveSession() async {
    try {
      final response = await _apiClient.get(ApiConfig.facultySessionsActive);
      if (response is Map && response['has_active_session'] == true) {
        final session = response['session'];
        if (session is Map) {
          _activeSessionId = session['session_id'] as int?;
          _activeSessionStatus = session['status'] as String?;
          if (session.containsKey('roster') && session['roster'] is List) {
            final List rawRoster = session['roster'];
            _roster = rawRoster
                .map((item) => RosterStudentModel.fromJson(Map<String, dynamic>.from(item as Map)))
                .toList();
          }
          notifyListeners();
        }
      } else {
        _activeSessionId = null;
        _activeSessionStatus = null;
        _roster = [];
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> startSession() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiClient.post(ApiConfig.facultySessionsStart);
      if (response is Map && response.containsKey('session_id')) {
        _activeSessionId = response['session_id'] as int;
        _activeSessionStatus = response['status'] as String? ?? 'ACTIVE';
        await checkActiveSession();
      }
      _isLoading = false;
      notifyListeners();
    } on ApiException catch (e) {
      _isLoading = false;
      _errorMessage = e.message;
      notifyListeners();
      rethrow;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to start session';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> markAttendance({
    required int studentId,
    required String status, // "PRESENT", "ABSENT", "OD"
    String? odReason,
  }) async {
    if (_activeSessionId == null) return;

    try {
      final path = ApiConfig.facultyMarkAttendance(_activeSessionId!);
      await _apiClient.post(
        path,
        body: {
          'student_id': studentId,
          'status': status,
          if (odReason != null) 'od_reason': odReason,
        },
      );

      // Local state update for instant UI feedback
      final idx = _roster.indexWhere((r) => r.studentId == studentId);
      if (idx != -1) {
        _roster[idx].attendanceStatus = status;
        _roster[idx].odReason = odReason;
        notifyListeners();
      }
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      rethrow;
    }
  }

  Future<RecognitionResultModel> uploadGroupPhoto(
    File imageFile, {
    List<int>? bytes,
    String? filename,
  }) async {
    if (_activeSessionId == null) {
      throw ApiException(400, "No active session running");
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final path = ApiConfig.facultyRecognizeImage(_activeSessionId!);
      dynamic response;
      if (bytes != null && bytes.isNotEmpty) {
        response = await _apiClient.multipartPostBytes(
          path,
          fileField: 'file',
          bytes: bytes,
          filename: filename ?? 'group_photo.jpg',
        );
      } else {
        response = await _apiClient.multipartPost(
          path,
          fileField: 'file',
          file: imageFile,
        );
      }

      final result = RecognitionResultModel.fromJson(response);
      _isLoading = false;
      notifyListeners();
      return result;
    } on ApiException catch (e) {
      _isLoading = false;
      _errorMessage = e.message;
      notifyListeners();
      rethrow;
    } catch (e) {
      debugPrint('uploadGroupPhoto error: $e');
      _isLoading = false;
      _errorMessage = 'Failed to process group photo: ${e.toString()}';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> confirmRecognition(List<int> confirmedStudentIds) async {
    if (_activeSessionId == null) {
      throw ApiException(400, "No active session running");
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final path = ApiConfig.facultyConfirmRecognition(_activeSessionId!);
      final payload = {
        "confirmed_candidates": confirmedStudentIds.map((id) => {
          "student_id": id,
          "status": "PRESENT",
          "recognized_via": "GROUP_PHOTO"
        }).toList()
      };

      await _apiClient.post(path, body: payload);
      await checkActiveSession();
      _isLoading = false;
      notifyListeners();
    } on ApiException catch (e) {
      _isLoading = false;
      _errorMessage = e.message;
      notifyListeners();
      rethrow;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to confirm recognition attendance';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> completeSession() async {
    if (_activeSessionId == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final path = ApiConfig.facultyCompleteSession(_activeSessionId!);
      await _apiClient.post(path);
      _activeSessionId = null;
      _activeSessionStatus = 'COMPLETED';
      _roster = [];
      _isLoading = false;
      notifyListeners();
    } on ApiException catch (e) {
      _isLoading = false;
      _errorMessage = e.message;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> loadDashboardData() async {
    await Future.wait([
      fetchSchedule().catchError((e) {
        _isLoading = false;
        _errorMessage = 'Failed to load faculty schedule';
        notifyListeners();
      }),
      checkActiveClassSlot().catchError((_) {}),
      checkActiveSession().catchError((_) {}),
    ]);
  }

  Future<AvailablePeriodsResponse> fetchAvailableAttendancePeriods() async {
    try {
      final response = await _apiClient.get(ApiConfig.facultyAvailablePeriods);
      if (response is Map<String, dynamic>) {
        return AvailablePeriodsResponse.fromJson(response);
      } else if (response is Map) {
        return AvailablePeriodsResponse.fromJson(Map<String, dynamic>.from(response));
      }
      throw ApiException(500, 'Invalid server response format');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(0, 'Unable to load attendance periods. Check your connection.');
    }
  }

  Future<FacultyAttendanceRosterResponse> fetchAttendanceRoster(
      int timetableEntryId, String date) async {
    try {
      final path = ApiConfig.facultyAttendanceRoster(timetableEntryId, date);
      final response = await _apiClient.get(path);
      if (response is Map<String, dynamic>) {
        return FacultyAttendanceRosterResponse.fromJson(response);
      } else if (response is Map) {
        return FacultyAttendanceRosterResponse.fromJson(Map<String, dynamic>.from(response));
      }
      throw ApiException(500, 'Invalid server response format');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(0, 'Unable to load class roster. Check your connection.');
    }
  }

  Future<Map<String, dynamic>> submitAttendanceWindow({
    required int timetableEntryId,
    required String date,
    required List<Map<String, dynamic>> records,
  }) async {
    try {
      final response = await _apiClient.post(
        ApiConfig.facultyAttendanceSubmit,
        body: {
          'timetable_entry_id': timetableEntryId,
          'date': date,
          'records': records,
        },
      );
      if (response is Map<String, dynamic>) {
        return response;
      } else if (response is Map) {
        return Map<String, dynamic>.from(response);
      }
      return {'message': 'Attendance submitted successfully.'};
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(0, 'Unable to submit attendance. Check your connection.');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Class Advisor API Methods
  // ─────────────────────────────────────────────────────────────

  Future<ClassAdvisorAvailablePeriodsResponse> fetchClassAdvisorAvailablePeriods() async {
    try {
      final response = await _apiClient.get(ApiConfig.facultyClassAdvisorAvailablePeriods);
      if (response is Map<String, dynamic>) {
        return ClassAdvisorAvailablePeriodsResponse.fromJson(response);
      } else if (response is Map) {
        return ClassAdvisorAvailablePeriodsResponse.fromJson(Map<String, dynamic>.from(response));
      }
      throw ApiException(500, 'Invalid server response format');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(0, 'Unable to load class advisor periods. Check your connection.');
    }
  }

  Future<ClassAdvisorAttendanceRosterResponse> fetchClassAdvisorRoster(
      int timetableEntryId, String date) async {
    try {
      final path = ApiConfig.facultyClassAdvisorRoster(timetableEntryId, date);
      final response = await _apiClient.get(path);
      if (response is Map<String, dynamic>) {
        return ClassAdvisorAttendanceRosterResponse.fromJson(response);
      } else if (response is Map) {
        return ClassAdvisorAttendanceRosterResponse.fromJson(Map<String, dynamic>.from(response));
      }
      throw ApiException(500, 'Invalid server response format');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(0, 'Unable to load class advisor roster. Check your connection.');
    }
  }

  Future<ClassAdvisorAttendanceSubmitResponse> submitClassAdvisorAttendance({
    required int timetableEntryId,
    required String date,
    required List<Map<String, dynamic>> records,
    String? expectedLastUpdated,
  }) async {
    try {
      final response = await _apiClient.post(
        ApiConfig.facultyClassAdvisorSubmit,
        body: {
          'timetable_entry_id': timetableEntryId,
          'date': date,
          'records': records,
          if (expectedLastUpdated != null) 'expected_last_updated': expectedLastUpdated,
        },
      );
      if (response is Map<String, dynamic>) {
        return ClassAdvisorAttendanceSubmitResponse.fromJson(response);
      } else if (response is Map) {
        return ClassAdvisorAttendanceSubmitResponse.fromJson(Map<String, dynamic>.from(response));
      }
      throw ApiException(500, 'Invalid server response format');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(0, 'Unable to submit attendance. Check your connection.');
    }
  }

  Future<ClassDailySummaryResponse> fetchClassAdvisorDailySummary(String date) async {
    try {
      final path = ApiConfig.facultyClassAdvisorDailySummary(date);
      final response = await _apiClient.get(path);
      if (response is Map<String, dynamic>) {
        return ClassDailySummaryResponse.fromJson(response);
      } else if (response is Map) {
        return ClassDailySummaryResponse.fromJson(Map<String, dynamic>.from(response));
      }
      throw ApiException(500, 'Invalid server response format');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(0, 'Unable to load daily summary. Check your connection.');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Attendance Reports Methods
  // ─────────────────────────────────────────────────────────────

  Future<FacultyAuthorizedReportOptionsModel> fetchReportAuthorizedOptions() async {
    try {
      final response = await _apiClient.get(ApiConfig.facultyReportAuthorizedOptions);
      if (response is Map<String, dynamic>) {
        return FacultyAuthorizedReportOptionsModel.fromJson(response);
      } else if (response is Map) {
        return FacultyAuthorizedReportOptionsModel.fromJson(Map<String, dynamic>.from(response));
      }
      throw ApiException(500, 'Invalid server response format');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(0, 'Unable to load authorized report options.');
    }
  }

  Future<FacultyClassSummaryModel> fetchClassSummaryReport({
    required int classId,
    int? subjectId,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final path = ApiConfig.facultyReportClassSummary(
        classId: classId,
        subjectId: subjectId,
        startDate: startDate,
        endDate: endDate,
      );
      final response = await _apiClient.get(path);
      if (response is Map<String, dynamic>) {
        return FacultyClassSummaryModel.fromJson(response);
      } else if (response is Map) {
        return FacultyClassSummaryModel.fromJson(Map<String, dynamic>.from(response));
      }
      throw ApiException(500, 'Invalid server response format');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(0, 'Unable to load class summary report.');
    }
  }

  Future<FacultyStudentDetailModel> fetchStudentDetailReport({
    required int studentId,
    int? subjectId,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final path = ApiConfig.facultyReportStudentDetail(
        studentId: studentId,
        subjectId: subjectId,
        startDate: startDate,
        endDate: endDate,
      );
      final response = await _apiClient.get(path);
      if (response is Map<String, dynamic>) {
        return FacultyStudentDetailModel.fromJson(response);
      } else if (response is Map) {
        return FacultyStudentDetailModel.fromJson(Map<String, dynamic>.from(response));
      }
      throw ApiException(500, 'Invalid server response format');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(0, 'Unable to load student detail report.');
    }
  }

  Future<FacultyDateMatrixModel> fetchDateMatrixReport({
    required int classId,
    required String date,
    int? subjectId,
  }) async {
    try {
      final path = ApiConfig.facultyReportDateMatrix(
        classId: classId,
        date: date,
        subjectId: subjectId,
      );
      final response = await _apiClient.get(path);
      if (response is Map<String, dynamic>) {
        return FacultyDateMatrixModel.fromJson(response);
      } else if (response is Map) {
        return FacultyDateMatrixModel.fromJson(Map<String, dynamic>.from(response));
      }
      throw ApiException(500, 'Invalid server response format');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(0, 'Unable to load date matrix report.');
    }
  }

  Future<FacultyHistoricalMatrixModel> fetchHistoricalMatrixReport({
    required int classId,
    int? subjectId,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final path = ApiConfig.facultyReportHistoricalMatrix(
        classId: classId,
        subjectId: subjectId,
        startDate: startDate,
        endDate: endDate,
      );
      final response = await _apiClient.get(path);
      if (response is Map<String, dynamic>) {
        return FacultyHistoricalMatrixModel.fromJson(response);
      } else if (response is Map) {
        return FacultyHistoricalMatrixModel.fromJson(Map<String, dynamic>.from(response));
      }
      throw ApiException(500, 'Invalid server response format');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(0, 'Unable to load historical matrix report.');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Phase 8: Retrospective Periods & Batch Photo Recognition
  // ─────────────────────────────────────────────────────────────

  Future<FacultyPeriodsForDateResponse> fetchPeriodsForDate(String date) async {
    try {
      final path = ApiConfig.facultyAttendancePeriodsForDate(date);
      final response = await _apiClient.get(path);
      if (response is Map<String, dynamic>) {
        return FacultyPeriodsForDateResponse.fromJson(response);
      } else if (response is Map) {
        return FacultyPeriodsForDateResponse.fromJson(Map<String, dynamic>.from(response));
      }
      throw ApiException(500, 'Invalid server response format');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(0, 'Unable to load periods for date: $e');
    }
  }

  Future<ClassAdvisorPeriodsForDateResponse> fetchClassAdvisorPeriodsForDate(String date) async {
    try {
      final path = ApiConfig.facultyClassAdvisorPeriodsForDate(date);
      final response = await _apiClient.get(path);
      if (response is Map<String, dynamic>) {
        return ClassAdvisorPeriodsForDateResponse.fromJson(response);
      } else if (response is Map) {
        return ClassAdvisorPeriodsForDateResponse.fromJson(Map<String, dynamic>.from(response));
      }
      throw ApiException(500, 'Invalid server response format');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(0, 'Unable to load class advisor periods for date: $e');
    }
  }

  Future<BatchRecognitionResultModel> batchRecognizePhotos({
    required int timetableEntryId,
    required String date,
    required List<({String filename, List<int> bytes})> files,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final path = ApiConfig.facultyAttendanceBatchRecognize;
      final response = await _apiClient.multipartPostMultipleFilesBytes(
        path,
        fileField: 'files',
        files: files,
        fields: {
          'timetable_entry_id': timetableEntryId.toString(),
          'date': date,
        },
      );

      _isLoading = false;
      notifyListeners();

      if (response is Map<String, dynamic>) {
        return BatchRecognitionResultModel.fromJson(response);
      } else if (response is Map) {
        return BatchRecognitionResultModel.fromJson(Map<String, dynamic>.from(response));
      }
      throw ApiException(500, 'Invalid server response format');
    } on ApiException catch (e) {
      _isLoading = false;
      _errorMessage = e.message;
      notifyListeners();
      rethrow;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Batch photo recognition failed: $e';
      notifyListeners();
      throw ApiException(0, 'Batch photo recognition failed: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Phase 9: Faculty Date-Range Attendance Report & Exports
  // ─────────────────────────────────────────────────────────────

  Future<AttendanceRangeReportModel> fetchAttendanceRangeReport({
    required int classId,
    required String fromDate,
    required String toDate,
    int? subjectId,
  }) async {
    try {
      final path = ApiConfig.facultyReportRange(
        classId: classId,
        fromDate: fromDate,
        toDate: toDate,
        subjectId: subjectId,
      );
      final response = await _apiClient.get(path);
      if (response is Map<String, dynamic>) {
        return AttendanceRangeReportModel.fromJson(response);
      } else if (response is Map) {
        return AttendanceRangeReportModel.fromJson(Map<String, dynamic>.from(response));
      }
      throw ApiException(500, 'Invalid server response format');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(0, 'Unable to load date range attendance report: $e');
    }
  }

  Future<List<int>> downloadAttendanceRangePdf({
    required int classId,
    required String fromDate,
    required String toDate,
    int? subjectId,
  }) async {
    final path = ApiConfig.facultyReportRangePdf(
      classId: classId,
      fromDate: fromDate,
      toDate: toDate,
      subjectId: subjectId,
    );
    return await _apiClient.getBytes(path);
  }

  Future<List<int>> downloadAttendanceRangeExcel({
    required int classId,
    required String fromDate,
    required String toDate,
    int? subjectId,
  }) async {
    final path = ApiConfig.facultyReportRangeExcel(
      classId: classId,
      fromDate: fromDate,
      toDate: toDate,
      subjectId: subjectId,
    );
    return await _apiClient.getBytes(path);
  }
}


