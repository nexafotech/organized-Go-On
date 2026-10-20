import 'package:flutter/foundation.dart';
import '../core/config/api_config.dart';
import '../core/network/api_client.dart';
import '../core/storage/secure_storage.dart';
import '../core/storage/app_preferences.dart';
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

  bool get isNetworkError => _errorMessage != null && !_sessionExpired && _currentUser == null;

  Future<bool> hasStoredToken() async {
    final token = await _secureStorage.getAccessToken();
    return token != null && token.isNotEmpty;
  }

  void setInitialCachedUser(UserModel user) {
    _currentUser = user;
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }

  void setMockUser(UserModel user) {
    _currentUser = user;
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }

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
    AppPreferencesService().clearCachedUser();
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
  /// 4. If 401/403 -> clear secure session and return null
  /// 5. If network error (statusCode == 0) -> preserve session, return null with isNetworkError
  /// 6. Route strictly based on authoritative backend role
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
      try {
        await AppPreferencesService().saveCachedUser(_currentUser!);
      } catch (_) {}
      // Clear any previous notification data and initialize for current user
      NotificationService().clearUserData();
      // Register device token for push notifications and start in-app polling
      NotificationService().registerTokenWithBackend(_apiClient, user: _currentUser);
      NotificationService().startInAppPolling(_apiClient);
      return _currentUser;
    } on ApiException catch (e) {
      _currentUser = null;
      _isLoading = false;
      if (e.statusCode == 401 || e.statusCode == 403) {
        await _secureStorage.clearSession();
        try {
          await AppPreferencesService().clearCachedUser();
        } catch (_) {}
        _sessionExpired = true;
        _errorMessage = e.statusCode == 401
            ? 'Your session has expired. Please sign in again.'
            : _formatErrorMessage(e, defaultMessage: 'Your account is disabled. Please contact Admin.');
      } else if (e.statusCode == 0) {
        // Network or connectivity error: DO NOT delete user's stored session!
        _sessionExpired = false;
        _errorMessage = 'Unable to reach the server. Check your connection or server address.';
      } else {
        _sessionExpired = false;
        _errorMessage = e.message;
      }
      notifyListeners();
      return null;
    } catch (e) {
      // General network/socket/timeout error: DO NOT clear session!
      _currentUser = null;
      _isLoading = false;
      _sessionExpired = false;
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
      try {
        await AppPreferencesService().saveCachedUser(_currentUser!);
      } catch (_) {}
      // Clear any previous notification data and initialize for current user
      NotificationService().clearUserData();
      // Register device token for push notifications and start in-app polling
      NotificationService().registerTokenWithBackend(_apiClient, user: _currentUser);
      NotificationService().startInAppPolling(_apiClient);
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
      try {
        await AppPreferencesService().saveCachedUser(_currentUser!);
      } catch (_) {}
      // Clear any previous notification data and initialize for current user
      NotificationService().clearUserData();
      // Register device token for push notifications and start in-app polling
      NotificationService().registerTokenWithBackend(_apiClient, user: _currentUser);
      NotificationService().startInAppPolling(_apiClient);
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

  /// Update Faculty Self-Service Profile (Full Name, Email, Phone, Avatar)
  Future<bool> updateFacultyProfile({
    String? fullName,
    String? email,
    String? phone,
    String? avatarId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final payload = <String, dynamic>{};
    if (fullName != null && fullName.trim().isNotEmpty) payload['full_name'] = fullName.trim();
    if (email != null) payload['email'] = email.trim();
    if (phone != null) payload['phone'] = phone.trim();
    if (avatarId != null && avatarId.trim().isNotEmpty) payload['avatar_id'] = avatarId.trim();

    try {
      final response = await _apiClient.patch(
        ApiConfig.facultyProfile,
        body: payload,
      );

      if (response is Map && (response['success'] == true || response.containsKey('user_id'))) {
        final updatedName = response['full_name'] as String? ?? (fullName ?? _currentUser?.fullName ?? '');
        final updatedEmail = response.containsKey('email') ? response['email'] as String? : (email ?? _currentUser?.email ?? '');
        final updatedPhone = response.containsKey('phone') ? response['phone'] as String? : (phone ?? _currentUser?.phone);
        final updatedAvatar = response['avatar_id'] as String? ?? (avatarId ?? _currentUser?.avatarId);
        final updatedDept = response['department'] as String? ?? _currentUser?.department;

        if (_currentUser != null) {
          _currentUser = _currentUser!.copyWith(
            fullName: updatedName,
            email: updatedEmail,
            phone: updatedPhone,
            avatarId: updatedAvatar,
            department: updatedDept,
          );
          try {
            await AppPreferencesService().saveCachedUser(_currentUser!);
          } catch (_) {}
        }
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _isLoading = false;
      _errorMessage = 'Failed to update profile. Unexpected server response.';
      notifyListeners();
      return false;
    } on ApiException catch (e) {
      _isLoading = false;
      _errorMessage = _formatErrorMessage(e, defaultMessage: 'Failed to update profile.');
      notifyListeners();
      rethrow;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Unable to reach the server. Check your connection or server address.';
      notifyListeners();
      rethrow;
    }
  }

  /// Update Faculty Avatar only
  Future<bool> updateFacultyAvatar(String avatarId) async {
    _errorMessage = null;
    final String? previousAvatarId = _currentUser?.avatarId;
    if (previousAvatarId == avatarId) {
      return true;
    }

    // Optimistic UI update: update memory and notify immediately
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(avatarId: avatarId);
      notifyListeners();
    }

    try {
      final response = await _apiClient.patch(
        ApiConfig.facultyAvatar,
        body: {'avatar_id': avatarId},
      );
      if (response is Map && response['success'] == true) {
        if (_currentUser != null) {
          try {
            await AppPreferencesService().saveCachedUser(_currentUser!);
          } catch (_) {}
        }
        return true;
      }
      // Revert if response unsuccessful
      if (_currentUser != null) {
        _currentUser = _currentUser!.copyWith(avatarId: previousAvatarId);
        notifyListeners();
      }
      return false;
    } catch (e) {
      debugPrint('[AuthService] updateFacultyAvatar error: $e');
      if (_currentUser != null) {
        _currentUser = _currentUser!.copyWith(avatarId: previousAvatarId);
        notifyListeners();
      }
      rethrow;
    }
  }

  /// Refresh Current User from /auth/me
  Future<UserModel?> refreshCurrentUser() async {
    try {
      final response = await _apiClient.get(ApiConfig.authMe);
      if (response is Map) {
        _currentUser = UserModel.fromJson(Map<String, dynamic>.from(response));
        try {
          await AppPreferencesService().saveCachedUser(_currentUser!);
        } catch (_) {}
        notifyListeners();
      }
      return _currentUser;
    } catch (e) {
      debugPrint('[AuthService] refreshCurrentUser error: $e');
      return _currentUser;
    }
  }

  /// Logout
  Future<void> logout() async {
    try {
      NotificationService().stopInAppPolling();
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
    try {
      await AppPreferencesService().clearCachedUser();
    } catch (_) {}
    NotificationService().clearUserData();
    _currentUser = null;
    _sessionExpired = false;
    _errorMessage = null;
    notifyListeners();
  }
}
