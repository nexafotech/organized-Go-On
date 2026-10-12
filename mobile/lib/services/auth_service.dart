import 'package:flutter/foundation.dart';
import '../core/config/api_config.dart';
import '../core/network/api_client.dart';
import '../core/storage/secure_storage.dart';
import '../models/user_model.dart';
import 'notification_service.dart';

class AuthService extends ChangeNotifier {
  final ApiClient _apiClient;
  final SecureStorageService _secureStorage;

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;
  bool _sessionExpired = false;

  AuthService({
    ApiClient? apiClient,
    SecureStorageService? secureStorage,
  })  : _secureStorage = secureStorage ?? SecureStorageService(),
        _apiClient = apiClient ?? ApiClient() {
    _apiClient.onUnauthorized = _handleUnauthorized;
  }

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;
  String? get errorMessage => _errorMessage;
  bool get sessionExpired => _sessionExpired;

  void clearErrorMessage() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  void clearSessionExpired() {
    if (_sessionExpired) {
      _sessionExpired = false;
      notifyListeners();
    }
  }

  void _handleUnauthorized() {
    _currentUser = null;
    _secureStorage.clearSession();
    _sessionExpired = true;
    _errorMessage = 'Your session has expired. Please sign in again.';
    notifyListeners();
  }

  String _formatErrorMessage(dynamic error, {String defaultMessage = 'Request failed'}) {
    if (error is ApiException) {
      if (error.statusCode == 401) {
        return 'Incorrect login ID or password.';
      } else if (error.statusCode == 403) {
        if (error.message.toLowerCase().contains('lock')) {
          return 'Your account is temporarily locked. Please try again later or contact Admin.';
        }
        return 'Your account is disabled. Please contact Admin.';
      } else if (error.statusCode == 0) {
        return 'Unable to reach the server. Check your connection or server address.';
      } else if (error.message.isNotEmpty) {
        return error.message;
      }
    }
    return defaultMessage;
  }

  /// App Launch Session Restoration
  /// 1. Read token from secure storage
  /// 2. If missing -> return null (show login)
  /// 3. If token exists -> call /api/v1/auth/me
  /// 4. If 401/403 or failure -> clear secure session and return null
  /// 5. Route strictly based on authoritative backend role
  Future<UserModel?> restoreSession() async {
    if (_isLoading) return _currentUser;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final token = await _secureStorage.getAccessToken();
      if (token == null || token.isEmpty) {
        _isLoading = false;
        notifyListeners();
        return null;
      }

      // Verify token authoritatively with backend
      final response = await _apiClient.get(ApiConfig.authMe);
      _currentUser = UserModel.fromJson(response);
      _sessionExpired = false;
      _isLoading = false;
      notifyListeners();
      // Register device token for push notifications
      NotificationService().registerTokenWithBackend(_apiClient, user: _currentUser);
      return _currentUser;
    } on ApiException catch (e) {
      await _secureStorage.clearSession();
      _currentUser = null;
      _isLoading = false;
      if (e.statusCode == 401) {
        _errorMessage = 'Your session has expired. Please sign in again.';
        _sessionExpired = true;
      } else if (e.statusCode == 403) {
        _errorMessage = _formatErrorMessage(e, defaultMessage: 'Your account is disabled. Please contact Admin.');
      } else if (e.statusCode == 0) {
        _errorMessage = 'Unable to reach the server. Check your connection or server address.';
      } else {
        _errorMessage = e.message;
      }
      notifyListeners();
      return null;
    } catch (e) {
      await _secureStorage.clearSession();
      _currentUser = null;
      _isLoading = false;
      _errorMessage = 'Unable to reach the server. Check your connection or server address.';
      notifyListeners();
      return null;
    }
  }

  /// Student Login
  Future<UserModel?> loginStudent(String identifier, String password) async {
    if (_isLoading) return null;
    _isLoading = true;
    _errorMessage = null;
    _sessionExpired = false;
    notifyListeners();

    try {
      final response = await _apiClient.post(
        ApiConfig.authStudentLogin,
        body: {'identifier': identifier.trim(), 'password': password.trim()},
        includeAuth: false,
      );

      final token = response['access_token'] as String;
      final forcePassChange = response['force_password_change'] as bool? ?? false;
      await _secureStorage.saveAccessToken(token);

      // Verify profile authoritatively via /auth/me
      final userProfile = await _apiClient.get(ApiConfig.authMe);
      final profileMap = Map<String, dynamic>.from(userProfile as Map);
      if (forcePassChange) {
        profileMap['force_password_change'] = true;
      }
      _currentUser = UserModel.fromJson(profileMap);
      _isLoading = false;
      notifyListeners();
      // Register device token for push notifications
      NotificationService().registerTokenWithBackend(_apiClient, user: _currentUser);
      return _currentUser;
    } on ApiException catch (e) {
      _isLoading = false;
      _errorMessage = _formatErrorMessage(e, defaultMessage: 'Student sign in failed.');
      notifyListeners();
      rethrow;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Unable to reach the server. Check your connection or server address.';
      notifyListeners();
      rethrow;
    }
  }

  /// Faculty Login
  Future<UserModel?> loginFaculty(String usernameOrEmail, String password) async {
    if (_isLoading) return null;
    _isLoading = true;
    _errorMessage = null;
    _sessionExpired = false;
    notifyListeners();

    try {
      final response = await _apiClient.post(
        ApiConfig.authFacultyLogin,
        body: {'username_or_email': usernameOrEmail.trim(), 'password': password.trim()},
        includeAuth: false,
      );

      final token = response['access_token'] as String;
      final forcePassChange = response['force_password_change'] as bool? ?? false;
      await _secureStorage.saveAccessToken(token);

      // Verify profile authoritatively via /auth/me
      final userProfile = await _apiClient.get(ApiConfig.authMe);
      final profileMap = Map<String, dynamic>.from(userProfile as Map);
      if (forcePassChange) {
        profileMap['force_password_change'] = true;
      }
      _currentUser = UserModel.fromJson(profileMap);
      _isLoading = false;
      notifyListeners();
      // Register device token for push notifications
      NotificationService().registerTokenWithBackend(_apiClient, user: _currentUser);
      return _currentUser;
    } on ApiException catch (e) {
      _isLoading = false;
      _errorMessage = _formatErrorMessage(e, defaultMessage: 'Faculty sign in failed.');
      notifyListeners();
      rethrow;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Unable to reach the server. Check your connection or server address.';
      notifyListeners();
      rethrow;
    }
  }

  /// Validate Identifier (Live UX assistance before submitting credentials)
  Future<Map<String, dynamic>> validateIdentifier(String identifier, {String role = 'FACULTY'}) async {
    final cleanId = identifier.trim();
    if (cleanId.isEmpty) {
      return {
        'valid': false,
        'role': role,
        'message': 'Identifier cannot be empty',
        'is_network_error': false,
      };
    }

    try {
      final response = await _apiClient.post(
        ApiConfig.authValidateIdentifier,
        body: {'identifier': cleanId, 'role': role},
        includeAuth: false,
      );

      if (response is Map) {
        return {
          'valid': response['valid'] == true,
          'role': response['role']?.toString() ?? role,
          'message': response['message']?.toString(),
          'is_network_error': false,
        };
      }
      return {
        'valid': false,
        'role': role,
        'message': 'Invalid response',
        'is_network_error': false,
      };
    } on ApiException catch (e) {
      if (e.statusCode == 0) {
        return {
          'valid': false,
          'role': role,
          'message': 'Unable to verify username. Check your connection.',
          'is_network_error': true,
        };
      }
      return {
        'valid': false,
        'role': role,
        'message': e.message,
        'is_network_error': false,
      };
    } catch (e) {
      return {
        'valid': false,
        'role': role,
        'message': 'Unable to verify username. Check your connection.',
        'is_network_error': true,
      };
    }
  }

  /// Change Password (Profile / Mandatory -> Change Password)
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _apiClient.post(
        ApiConfig.authChangePassword,
        body: {
          'current_password': currentPassword,
          'new_password': newPassword,
        },
      );

      // Re-fetch authoritative profile so forcePasswordChange is cleared immediately
      try {
        final userProfile = await _apiClient.get(ApiConfig.authMe);
        if (userProfile is Map) {
          _currentUser = UserModel.fromJson(Map<String, dynamic>.from(userProfile));
        }
      } catch (_) {
        if (_currentUser != null) {
          _currentUser = UserModel(
            id: _currentUser!.id,
            username: _currentUser!.username,
            email: _currentUser!.email,
            role: _currentUser!.role,
            isActive: _currentUser!.isActive,
            fullName: _currentUser!.fullName,
            facultyProfileId: _currentUser!.facultyProfileId,
            forcePasswordChange: false,
          );
        }
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _isLoading = false;
      if (e.statusCode == 404) {
        _errorMessage = 'Password change service is currently being configured by college administration.';
      } else if (e.statusCode == 400 || e.statusCode == 422) {
        _errorMessage = e.message.isNotEmpty ? e.message : 'Invalid password format.';
      } else if (e.statusCode == 401) {
        _errorMessage = e.message.isNotEmpty ? e.message : 'Current password is incorrect.';
      } else if (e.statusCode == 0) {
        _errorMessage = 'Unable to reach the server. Check your connection or server address.';
      } else {
        _errorMessage = _formatErrorMessage(e, defaultMessage: 'Failed to change password. Please try again.');
      }
      notifyListeners();
      rethrow;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Unable to reach the server. Check your connection or server address.';
      notifyListeners();
      rethrow;
    }
  }

  /// Logout
  Future<void> logout() async {
    try {
      await NotificationService().unregisterTokenFromBackend(_apiClient);
    } catch (_) {}

    try {
      if (_currentUser?.isStudent == true) {
        await _apiClient.post(ApiConfig.authStudentLogout);
      } else {
        await _apiClient.post(ApiConfig.authFacultyLogout);
      }
    } catch (_) {}

    await _secureStorage.clearSession();
    _currentUser = null;
    _sessionExpired = false;
    _errorMessage = null;
    notifyListeners();
  }
}
