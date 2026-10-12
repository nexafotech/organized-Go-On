import 'package:flutter/foundation.dart';
import '../core/config/api_config.dart';
import '../core/network/api_client.dart';
import '../models/admin_biometric_model.dart';

class AdminService extends ChangeNotifier {
  final ApiClient _apiClient;

  List<AdminStudentBioModel> _students = [];
  AdminBioOverviewModel? _overview;
  AdminStudentBioDetailModel? _selectedStudentDetail;
  bool _isLoading = false;
  bool _isActionLoading = false;
  String? _errorMessage;
  String? _successMessage;

  AdminService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  List<AdminStudentBioModel> get students => _students;
  AdminBioOverviewModel? get overview => _overview;
  AdminStudentBioDetailModel? get selectedStudentDetail => _selectedStudentDetail;
  bool get isLoading => _isLoading;
  bool get isActionLoading => _isActionLoading;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  Future<void> fetchSummary() async {
    try {
      final res = await _apiClient.get(ApiConfig.adminBiometricsSummary);
      if (res is Map<String, dynamic>) {
        _overview = AdminBioOverviewModel.fromJson(res);
        notifyListeners();
      }
    } catch (_) {
      // Summary error is non-fatal for student list
    }
  }

  Future<void> fetchStudents({String? search, bool? enrolledOnly}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final queryParams = <String, String>{};
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }
      if (enrolledOnly != null) {
        queryParams['enrolled_only'] = enrolledOnly.toString();
      }

      final res = await _apiClient.get(
        ApiConfig.adminBiometricsStudents,
        queryParams: queryParams.isNotEmpty ? queryParams : null,
      );

      if (res is List) {
        _students = res
            .map((e) => AdminStudentBioModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
      _isLoading = false;
      notifyListeners();
    } on ApiException catch (e) {
      _isLoading = false;
      _errorMessage = e.message;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to load students. Check server connection.';
      notifyListeners();
    }
  }

  Future<AdminStudentBioDetailModel?> fetchStudentDetail(int studentId) async {
    try {
      final res = await _apiClient.get(ApiConfig.adminStudentBiometrics(studentId));
      if (res is Map<String, dynamic>) {
        _selectedStudentDetail = AdminStudentBioDetailModel.fromJson(res);
        notifyListeners();
        return _selectedStudentDetail;
      }
      return null;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return null;
    } catch (e) {
      _errorMessage = 'Failed to load student biometric details.';
      notifyListeners();
      return null;
    }
  }

  Future<bool> enrollStudentFace({
    required int studentId,
    required List<int> imageBytes,
    required String filename,
    bool isReplace = false,
  }) async {
    _isActionLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final res = await _apiClient.multipartPostBytes(
        ApiConfig.adminStudentEnrollFace(studentId, replace: isReplace),
        fileField: 'file',
        bytes: imageBytes,
        filename: filename,
      );

      _isActionLoading = false;
      if (res is Map<String, dynamic>) {
        _successMessage = res['message']?.toString() ?? 'Face enrolled successfully';
        // Refresh local student record & summary
        await fetchStudentDetail(studentId);
        await fetchStudents();
        await fetchSummary();
        return true;
      }
      return false;
    } on ApiException catch (e) {
      _isActionLoading = false;
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _isActionLoading = false;
      _errorMessage = 'Face enrollment failed. Please check connection and retry.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> resetStudentFace(int studentId) async {
    _isActionLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final res = await _apiClient.post(ApiConfig.adminStudentResetBiometrics(studentId));
      _isActionLoading = false;
      if (res is Map<String, dynamic>) {
        _successMessage = res['message']?.toString() ?? 'Biometric enrollment reset successfully';
        await fetchStudentDetail(studentId);
        await fetchStudents();
        await fetchSummary();
        return true;
      }
      return false;
    } on ApiException catch (e) {
      _isActionLoading = false;
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _isActionLoading = false;
      _errorMessage = 'Failed to reset biometric templates.';
      notifyListeners();
      return false;
    }
  }

  Future<Map<String, dynamic>?> previewFolderPath(String folderPath) async {
    _isActionLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _apiClient.post(
        ApiConfig.adminPreviewFolderPath,
        body: {'folder_path': folderPath},
      );
      _isActionLoading = false;
      notifyListeners();
      if (res is Map<String, dynamic>) {
        return res;
      }
      return null;
    } on ApiException catch (e) {
      _isActionLoading = false;
      _errorMessage = e.message;
      notifyListeners();
      return null;
    } catch (e) {
      _isActionLoading = false;
      _errorMessage = 'Failed to inspect folder: $e';
      notifyListeners();
      return null;
    }
  }

  Future<Map<String, dynamic>?> enrollFolderPath({
    required String folderPath,
    bool replace = false,
  }) async {
    _isActionLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final res = await _apiClient.post(
        ApiConfig.adminEnrollFolderPath,
        body: {
          'folder_path': folderPath,
          'replace': replace,
        },
      );
      _isActionLoading = false;
      if (res is Map<String, dynamic>) {
        _successMessage = res['message']?.toString() ?? 'Folder enrollment completed';
        await fetchStudents();
        await fetchSummary();
        return res;
      }
      return null;
    } on ApiException catch (e) {
      _isActionLoading = false;
      _errorMessage = e.message;
      notifyListeners();
      return null;
    } catch (e) {
      _isActionLoading = false;
      _errorMessage = 'Failed to enroll folder path: $e';
      notifyListeners();
      return null;
    }
  }

  // ==========================================
  // PHASE 7.8: DATASET MANAGEMENT METHODS
  // ==========================================

  Future<MultiPhotoEnrollResponseModel?> enrollStudentPhotos({
    required int studentId,
    required List<({String filename, List<int> bytes})> files,
    bool isReplace = false,
  }) async {
    _isActionLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final res = await _apiClient.multipartPostMultipleFilesBytes(
        ApiConfig.adminStudentEnrollPhotos(studentId, replace: isReplace),
        fileField: 'files',
        files: files,
        fields: {'replace': isReplace.toString()},
      );

      _isActionLoading = false;
      if (res is Map<String, dynamic>) {
        final model = MultiPhotoEnrollResponseModel.fromJson(res);
        _successMessage = model.message;
        await fetchStudentDetail(studentId);
        await fetchStudents();
        await fetchSummary();
        return model;
      }
      return null;
    } on ApiException catch (e) {
      _isActionLoading = false;
      _errorMessage = e.message;
      notifyListeners();
      return null;
    } catch (e) {
      _isActionLoading = false;
      _errorMessage = 'Multi-photo enrollment failed: $e';
      notifyListeners();
      return null;
    }
  }

  Future<StudentDatasetViewModel?> fetchStudentDataset(int studentId) async {
    try {
      final res = await _apiClient.get(ApiConfig.adminStudentPhotos(studentId));
      if (res is Map<String, dynamic>) {
        return StudentDatasetViewModel.fromJson(res);
      }
      return null;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return null;
    } catch (e) {
      _errorMessage = 'Failed to load student photos: $e';
      notifyListeners();
      return null;
    }
  }

  Future<List<int>?> fetchStudentPhotoImageBytes(int studentId, int embeddingId) async {
    try {
      final bytes = await _apiClient.getBytes(ApiConfig.adminStudentPhotoImage(studentId, embeddingId));
      return bytes;
    } catch (_) {
      return null;
    }
  }

  Future<bool> deleteStudentPhoto({
    required int studentId,
    required int embeddingId,
  }) async {
    _isActionLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final res = await _apiClient.delete(ApiConfig.adminStudentDeletePhoto(studentId, embeddingId));
      _isActionLoading = false;
      if (res is Map<String, dynamic>) {
        _successMessage = res['message']?.toString() ?? 'Photo deleted successfully';
        await fetchStudentDetail(studentId);
        await fetchStudents();
        await fetchSummary();
        return true;
      }
      return false;
    } on ApiException catch (e) {
      _isActionLoading = false;
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _isActionLoading = false;
      _errorMessage = 'Failed to delete photo: $e';
      notifyListeners();
      return false;
    }
  }
}

