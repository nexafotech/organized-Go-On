import 'package:flutter/foundation.dart';
import '../core/config/api_config.dart';
import '../core/network/api_client.dart';
import '../models/student_model.dart';

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
        _timetable = rawList.map((item) => TimetableItemModel.fromJson(item)).toList();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> fetchAttendanceReport() async {
    try {
      final response = await _apiClient.get(ApiConfig.studentAttendance);
      if (response is Map && response.containsKey('date_wise') && response['date_wise'] is List) {
        final List rawList = response['date_wise'];
        _dateWise = rawList
            .map((item) => DateWiseEntryModel.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
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
      if (response is Map && response.containsKey('date_wise') && response['date_wise'] is List) {
        final List rawList = response['date_wise'];
        _dateWise = rawList
            .map((item) => DateWiseEntryModel.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> loadDashboardData() async {
    if (_summary != null) return;
    await Future.wait([
      fetchStudentSummary(),
      fetchSubjects(),
      fetchTimetable(),
      fetchAttendanceReport(),
    ]);
  }
}
