import 'dart:io';
import 'package:flutter/foundation.dart';
import '../core/config/api_config.dart';
import '../core/network/api_client.dart';
import '../models/biometric_enrollment_model.dart';

class BiometricEnrollmentService extends ChangeNotifier {
  final ApiClient _apiClient;

  EnrollmentStatusModel? _status;
  PoseValidationResultModel? _lastValidation;
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  BiometricEnrollmentService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  EnrollmentStatusModel? get status => _status;
  PoseValidationResultModel? get lastValidation => _lastValidation;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  Future<void> fetchEnrollmentStatus() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiClient.get(ApiConfig.studentEnrollmentStatus);
      if (response is Map<String, dynamic>) {
        _status = EnrollmentStatusModel.fromJson(response);
      }
      _isLoading = false;
      notifyListeners();
    } on ApiException catch (e) {
      _isLoading = false;
      _errorMessage = e.message;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to load enrollment status.';
      notifyListeners();
    }
  }

  Future<PoseValidationResultModel?> validatePose(File imageFile, String step, {bool mirrored = false}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiClient.multipartPost(
        ApiConfig.studentEnrollValidatePose,
        fileField: 'file',
        file: imageFile,
        fields: {
          'step': step,
          'mirrored': mirrored.toString(),
        },
      );

      if (response is Map<String, dynamic>) {
        _lastValidation = PoseValidationResultModel.fromJson(response);
      }
      _isLoading = false;
      notifyListeners();
      return _lastValidation;
    } on ApiException catch (e) {
      _isLoading = false;
      _errorMessage = e.message;
      _lastValidation = PoseValidationResultModel(
        valid: false,
        status: 'VALIDATION_ERROR',
        message: e.message,
        guidance: [],
        step: step,
      );
      notifyListeners();
      return _lastValidation;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to validate pose. Check server connection.';
      notifyListeners();
      return null;
    }
  }

  Future<bool> captureTemplate(File imageFile, String step, {bool mirrored = false}) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final response = await _apiClient.multipartPost(
        ApiConfig.studentEnrollCapture,
        fileField: 'file',
        file: imageFile,
        fields: {
          'step': step,
          'mirrored': mirrored.toString(),
        },
      );

      if (response is Map<String, dynamic>) {
        _successMessage = response['message']?.toString();
        // Refresh status after successful template persistence
        await fetchEnrollmentStatus();
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _isLoading = false;
      notifyListeners();
      return false;
    } on ApiException catch (e) {
      _isLoading = false;
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to persist face template. Please retry.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> resetEnrollment() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiClient.post(ApiConfig.studentEnrollReset);
      if (response is Map<String, dynamic>) {
        _lastValidation = null;
        await fetchEnrollmentStatus();
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to reset enrollment.';
      notifyListeners();
      return false;
    }
  }

  void clearValidation() {
    _lastValidation = null;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }
}
