import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../config/api_config.dart';
import '../storage/secure_storage.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiClient {
  final http.Client _httpClient;
  final SecureStorageService _secureStorage;
  Function()? onUnauthorized;

  ApiClient({
    http.Client? httpClient,
    SecureStorageService? secureStorage,
    this.onUnauthorized,
  })  : _httpClient = httpClient ?? http.Client(),
        _secureStorage = secureStorage ?? SecureStorageService();

  Uri _buildUri(String path, [Map<String, String>? queryParams]) {
    final String cleanPath = path.startsWith('/') ? path : '/$path';
    final String urlStr = '${ApiConfig.baseUrl}$cleanPath';
    final Uri baseUri = Uri.parse(urlStr);
    if (queryParams != null && queryParams.isNotEmpty) {
      return baseUri.replace(queryParameters: queryParams);
    }
    return baseUri;
  }

  Future<String?> getAccessToken() => _secureStorage.getAccessToken();

  Future<List<int>> getBytes(String path, {bool includeAuth = true}) async {
    final uri = _buildUri(path);
    final headers = await _getHeaders(includeAuth: includeAuth, isJson: false);
    final response = await _httpClient.get(uri, headers: headers).timeout(const Duration(seconds: 30));
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.bodyBytes;
    }
    String errorMsg = 'Failed to download file (HTTP ${response.statusCode})';
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body.containsKey('detail')) {
        final d = body['detail'];
        if (d is String) {
          errorMsg = d;
        } else if (d is Map && d.containsKey('message')) {
          errorMsg = d['message'].toString();
        } else {
          errorMsg = jsonEncode(d);
        }
      }
    } catch (_) {}
    throw ApiException(response.statusCode, errorMsg);
  }

  Future<Map<String, String>> _getHeaders({bool includeAuth = true, bool isJson = true}) async {
    final Map<String, String> headers = {};
    if (isJson) {
      headers['Content-Type'] = 'application/json';
      headers['Accept'] = 'application/json';
    }
    if (includeAuth) {
      final token = await _secureStorage.getAccessToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  dynamic _processResponse(http.Response response, {bool isAuthRequest = false}) {
    if (response.statusCode == 401) {
      if (!isAuthRequest && onUnauthorized != null) {
        onUnauthorized!();
      }
      String errorMsg = isAuthRequest
          ? 'Incorrect login ID or password.'
          : 'Your session has expired. Please sign in again.';
      try {
        final body = jsonDecode(response.body);
        if (body is Map && body.containsKey('detail')) {
          final detail = body['detail'].toString();
          if (detail.toLowerCase().contains('credential') || detail.toLowerCase().contains('incorrect')) {
            errorMsg = 'Incorrect login ID or password.';
          } else if (!isAuthRequest && (detail.contains('validate') || detail.contains('expired'))) {
            errorMsg = 'Your session has expired. Please sign in again.';
          } else if (detail.isNotEmpty) {
            errorMsg = detail;
          }
        }
      } catch (_) {}
      throw ApiException(401, errorMsg);
    }

    if (response.statusCode == 403) {
      String errorMsg = 'Your account is disabled. Please contact Admin.';
      try {
        final body = jsonDecode(response.body);
        if (body is Map && body.containsKey('detail')) {
          final detail = body['detail'].toString();
          if (detail.toLowerCase().contains('locked')) {
            errorMsg = 'Your account is temporarily locked. Please try again later or contact Admin.';
          } else if (detail.toLowerCase().contains('disabled') || detail.toLowerCase().contains('deactivated')) {
            errorMsg = 'Your account is disabled. Please contact Admin.';
          } else if (detail.isNotEmpty) {
            errorMsg = detail;
          }
        }
      } catch (_) {}
      throw ApiException(403, errorMsg);
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return {};
      return jsonDecode(response.body);
    }

    String errorMsg = 'HTTP ${response.statusCode} error';
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body.containsKey('detail')) {
        final d = body['detail'];
        if (d is String) {
          errorMsg = d;
        } else if (d is Map && d.containsKey('message')) {
          errorMsg = d['message'].toString();
        } else {
          errorMsg = jsonEncode(d);
        }
      } else if (body is Map && body.containsKey('message')) {
        errorMsg = body['message'].toString();
      }
    } catch (_) {}

    throw ApiException(response.statusCode, errorMsg);
  }

  static bool _isProbing = false;

  Future<bool> _tryFailover() async {
    if (_isProbing) return false;
    _isProbing = true;
    try {
      final current = ApiConfig.baseUrl;
      for (final candidate in ApiConfig.candidateEndpoints) {
        if (candidate == current) continue;
        try {
          final uri = Uri.parse('$candidate${ApiConfig.healthCheck}');
          final res = await _httpClient.get(uri).timeout(const Duration(milliseconds: 1800));
          if (res.statusCode == 200) {
            ApiConfig.setBaseUrl(candidate);
            return true;
          }
        } catch (_) {}
      }
    } finally {
      _isProbing = false;
    }
    return false;
  }

  Future<T> _executeWithFailover<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on SocketException {
      if (await _tryFailover()) {
        return await call();
      }
      throw ApiException(0, 'Unable to reach the server. Check your connection or server address.');
    } on http.ClientException {
      if (await _tryFailover()) {
        return await call();
      }
      throw ApiException(0, 'Unable to reach the server. Check your connection or server address.');
    } on TimeoutException {
      if (await _tryFailover()) {
        return await call();
      }
      throw ApiException(0, 'Unable to reach the server. Check your connection or server address.');
    }
  }

  Future<dynamic> get(String path, {Map<String, String>? queryParams, bool includeAuth = true}) async {
    return _executeWithFailover(() async {
      final uri = _buildUri(path, queryParams);
      final headers = await _getHeaders(includeAuth: includeAuth);
      final response = await _httpClient
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 15));
      return _processResponse(response, isAuthRequest: !includeAuth);
    });
  }

  Future<dynamic> post(String path, {dynamic body, bool includeAuth = true}) async {
    return _executeWithFailover(() async {
      final uri = _buildUri(path);
      final headers = await _getHeaders(includeAuth: includeAuth);
      final String? jsonBody = body != null ? jsonEncode(body) : null;
      final response = await _httpClient
          .post(uri, headers: headers, body: jsonBody)
          .timeout(const Duration(seconds: 15));
      return _processResponse(response, isAuthRequest: !includeAuth);
    });
  }

  Future<dynamic> put(String path, {dynamic body, bool includeAuth = true}) async {
    return _executeWithFailover(() async {
      final uri = _buildUri(path);
      final headers = await _getHeaders(includeAuth: includeAuth);
      final String? jsonBody = body != null ? jsonEncode(body) : null;
      final response = await _httpClient
          .put(uri, headers: headers, body: jsonBody)
          .timeout(const Duration(seconds: 15));
      return _processResponse(response, isAuthRequest: !includeAuth);
    });
  }

  Future<dynamic> patch(String path, {dynamic body, bool includeAuth = true}) async {
    return _executeWithFailover(() async {
      final uri = _buildUri(path);
      final headers = await _getHeaders(includeAuth: includeAuth);
      final String? jsonBody = body != null ? jsonEncode(body) : null;
      final response = await _httpClient
          .patch(uri, headers: headers, body: jsonBody)
          .timeout(const Duration(seconds: 15));
      return _processResponse(response, isAuthRequest: !includeAuth);
    });
  }

  Future<dynamic> delete(String path, {bool includeAuth = true}) async {
    return _executeWithFailover(() async {
      final uri = _buildUri(path);
      final headers = await _getHeaders(includeAuth: includeAuth);
      final response = await _httpClient
          .delete(uri, headers: headers)
          .timeout(const Duration(seconds: 15));
      return _processResponse(response, isAuthRequest: !includeAuth);
    });
  }

  /// Multipart upload for future camera / group photo images
  Future<dynamic> multipartPost(
    String path, {
    required String fileField,
    required File file,
    Map<String, String>? fields,
    bool includeAuth = true,
  }) async {
    try {
      final uri = _buildUri(path);
      final request = http.MultipartRequest('POST', uri);
      if (includeAuth) {
        final token = await _secureStorage.getAccessToken();
        if (token != null && token.isNotEmpty) {
          request.headers['Authorization'] = 'Bearer $token';
        }
      }
      if (fields != null) {
        request.fields.addAll(fields);
      }

      // Explicitly set media type for image files
      MediaType? mediaType;
      final pathLower = file.path.toLowerCase();
      if (pathLower.endsWith('.png')) {
        mediaType = MediaType('image', 'png');
      } else if (pathLower.endsWith('.webp')) {
        mediaType = MediaType('image', 'webp');
      } else {
        mediaType = MediaType('image', 'jpeg');
      }

      request.files.add(await http.MultipartFile.fromPath(
        fileField,
        file.path,
        contentType: mediaType,
      ));

      final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);
      return _processResponse(response, isAuthRequest: !includeAuth);
    } on SocketException {
      throw ApiException(0, 'Unable to reach the server. Check your connection or server address.');
    } on http.ClientException {
      throw ApiException(0, 'Unable to reach the server. Check your connection or server address.');
    } on TimeoutException {
      throw ApiException(0, 'Server request timed out. Please check server responsiveness.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(0, 'Unexpected error during upload: $e');
    }
  }

  /// Platform-safe multipart upload using raw bytes (works on Web, Android, iOS, Desktop)
  Future<dynamic> multipartPostBytes(
    String path, {
    required String fileField,
    required List<int> bytes,
    required String filename,
    Map<String, String>? fields,
    bool includeAuth = true,
  }) async {
    try {
      final uri = _buildUri(path);
      final request = http.MultipartRequest('POST', uri);
      if (includeAuth) {
        final token = await _secureStorage.getAccessToken();
        if (token != null && token.isNotEmpty) {
          request.headers['Authorization'] = 'Bearer $token';
        }
      }
      if (fields != null) {
        request.fields.addAll(fields);
      }

      MediaType? mediaType;
      final nameLower = filename.toLowerCase();
      if (nameLower.endsWith('.png')) {
        mediaType = MediaType('image', 'png');
      } else if (nameLower.endsWith('.webp')) {
        mediaType = MediaType('image', 'webp');
      } else {
        mediaType = MediaType('image', 'jpeg');
      }

      request.files.add(http.MultipartFile.fromBytes(
        fileField,
        bytes,
        filename: filename,
        contentType: mediaType,
      ));

      final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);
      return _processResponse(response, isAuthRequest: !includeAuth);
    } on SocketException {
      throw ApiException(0, 'Unable to reach the server. Check your connection or server address.');
    } on http.ClientException {
      throw ApiException(0, 'Unable to reach the server. Check your connection or server address.');
    } on TimeoutException {
      throw ApiException(0, 'Server request timed out. Please check server responsiveness.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(0, 'Unexpected error during upload: $e');
    }
  }

  /// Platform-safe multipart upload for multiple files using raw bytes
  Future<dynamic> multipartPostMultipleFilesBytes(
    String path, {
    required String fileField,
    required List<({String filename, List<int> bytes})> files,
    Map<String, String>? fields,
    bool includeAuth = true,
  }) async {
    try {
      final uri = _buildUri(path);
      final request = http.MultipartRequest('POST', uri);
      if (includeAuth) {
        final token = await _secureStorage.getAccessToken();
        if (token != null && token.isNotEmpty) {
          request.headers['Authorization'] = 'Bearer $token';
        }
      }
      if (fields != null) {
        request.fields.addAll(fields);
      }

      for (var f in files) {
        MediaType? mediaType;
        final nameLower = f.filename.toLowerCase();
        if (nameLower.endsWith('.png')) {
          mediaType = MediaType('image', 'png');
        } else if (nameLower.endsWith('.webp')) {
          mediaType = MediaType('image', 'webp');
        } else {
          mediaType = MediaType('image', 'jpeg');
        }

        request.files.add(http.MultipartFile.fromBytes(
          fileField,
          f.bytes,
          filename: f.filename,
          contentType: mediaType,
        ));
      }

      final streamedResponse = await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamedResponse);
      return _processResponse(response, isAuthRequest: !includeAuth);
    } on SocketException {
      throw ApiException(0, 'Unable to reach the server. Check your connection or server address.');
    } on http.ClientException {
      throw ApiException(0, 'Unable to reach the server. Check your connection or server address.');
    } on TimeoutException {
      throw ApiException(0, 'Server request timed out. Please check server responsiveness.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(0, 'Unexpected error during upload: $e');
    }
  }
}

