import 'dart:developer';
import '../config.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService extends ChangeNotifier {
  static const String directusUrl = AppConfig.directusUrl;
  late final Dio _dio;

  String? _token;
  String? _refreshToken;
  DateTime? _tokenExpiry;
  Map<String, dynamic>? _user;
  bool _isRefreshing = false;

  // Callback for when session expires (refresh token invalid)
  void Function()? onSessionExpired;

  String? get token => _token;
  Map<String, dynamic>? get currentUser => _user;
  bool get isAuthenticated => _token != null;

  AuthService() {
    _dio = Dio(BaseOptions(
      baseUrl: directusUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ));

    // Add interceptor for automatic token refresh
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Check if token needs refresh before each request
          if (_token != null && _shouldRefreshToken()) {
            await _refreshAccessToken();
          }
          if (_token != null) {
            options.headers['Authorization'] = 'Bearer $_token';
          }
          return handler.next(options);
        },
        onError: (error, handler) async {
          // Handle 401 errors by attempting token refresh
          if (error.response?.statusCode == 401 && _refreshToken != null) {
            if (!_isRefreshing) {
              final success = await _refreshAccessToken();
              if (success) {
                // Retry the original request
                final opts = error.requestOptions;
                opts.headers['Authorization'] = 'Bearer $_token';
                try {
                  final response = await _dio.fetch(opts);
                  return handler.resolve(response);
                } catch (e) {
                  return handler.next(error);
                }
              } else {
                // Refresh failed - session expired
                await _forceLogout();
              }
            }
          }
          return handler.next(error);
        },
      ),
    );

    _loadTokenFromStorage();
  }

  // Check if token should be refreshed (5 minutes before expiry)
  bool _shouldRefreshToken() {
    if (_tokenExpiry == null) return false;
    final buffer = const Duration(minutes: 5);
    return DateTime.now().isAfter(_tokenExpiry!.subtract(buffer));
  }

  Future<void> _loadTokenFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final storedToken = prefs.getString('auth_token');
    final storedRefreshToken = prefs.getString('refresh_token');
    final storedExpiry = prefs.getInt('token_expiry');

    if (storedToken != null && storedRefreshToken != null) {
      _token = storedToken;
      _refreshToken = storedRefreshToken;
      _tokenExpiry = storedExpiry != null
          ? DateTime.fromMillisecondsSinceEpoch(storedExpiry)
          : null;

      log('Loaded tokens from storage', name: 'AuthService');

      // Check if token is expired or about to expire
      if (_tokenExpiry != null && DateTime.now().isAfter(_tokenExpiry!)) {
        log('Token expired, attempting refresh...', name: 'AuthService');
        final refreshed = await _refreshAccessToken();
        if (!refreshed) {
          log('Refresh failed, session expired', name: 'AuthService');
          await _forceLogout();
          return;
        }
      }

      try {
        await _fetchCurrentUser();
        notifyListeners();
      } catch (e) {
        log('Failed to fetch user with stored token: $e', name: 'AuthService');
        // Try refreshing token
        final refreshed = await _refreshAccessToken();
        if (refreshed) {
          try {
            await _fetchCurrentUser();
            notifyListeners();
            return;
          } catch (_) {}
        }
        // If all fails, session expired
        await _forceLogout();
      }
    }
  }

  Future<bool> _refreshAccessToken() async {
    if (_refreshToken == null || _isRefreshing) return false;

    _isRefreshing = true;
    log('Refreshing access token...', name: 'AuthService');

    try {
      // Use a separate Dio instance without interceptors to avoid loops
      final refreshDio = Dio();
      final response = await refreshDio.post(
        '$directusUrl/auth/refresh',
        data: {
          'refresh_token': _refreshToken,
          'mode': 'json',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data['data'];
        _token = data['access_token'];
        _refreshToken = data['refresh_token'];

        // Calculate expiry (Directus default is 15 minutes = 900000ms)
        final expiresIn = data['expires'] ?? 900000;
        _tokenExpiry = DateTime.now().add(Duration(milliseconds: expiresIn));

        await _saveTokenToStorage();

        log('Token refreshed successfully', name: 'AuthService');
        _isRefreshing = false;
        return true;
      }
    } on DioException catch (e) {
      log('Token refresh failed: ${e.response?.data}', name: 'AuthService');
    } catch (e) {
      log('Token refresh error: $e', name: 'AuthService');
    }

    _isRefreshing = false;
    return false;
  }

  Future<void> _saveTokenToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    if (_token != null) {
      await prefs.setString('auth_token', _token!);
    }
    if (_refreshToken != null) {
      await prefs.setString('refresh_token', _refreshToken!);
    }
    if (_tokenExpiry != null) {
      await prefs.setInt('token_expiry', _tokenExpiry!.millisecondsSinceEpoch);
    }
  }

  Future<void> _clearTokenFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('refresh_token');
    await prefs.remove('token_expiry');
  }

  // ------------------------------------------------------------
  // LINK STUDENT TO USER (Vue-style: search students by user_id/email/name)
  // ------------------------------------------------------------
  Future<void> _linkStudentToUser() async {
    if (_user == null) return;

    final userId = _user!['id'];
    final userEmail = _user!['email'];
    final firstName = _user!['first_name'];
    final lastName = _user!['last_name'];

    log('=== LINKING STUDENT TO USER ===', name: 'AuthService');

    Map<String, dynamic>? studentRecord;

    // Strategy 1: Search by user_id (direct link in students table)
    try {
      final res = await _dio.get(
        '/items/students',
        queryParameters: {
          'filter[user_id][_eq]': userId,
          'fields':
              'id,student_number,first_name,last_name,middle_name,email,user_id,deparment_id,class_id',
          'limit': '1',
        },
      );
      final data = res.data['data'] as List;
      if (data.isNotEmpty) {
        studentRecord = data.first;
        log('Found student by user_id', name: 'AuthService');
      }
    } catch (e) {
      log('Strategy 1 failed: $e', name: 'AuthService');
    }

    // Strategy 2: Search by email
    if (studentRecord == null && userEmail != null) {
      try {
        final res = await _dio.get(
          '/items/students',
          queryParameters: {
            'filter[email][_eq]': userEmail,
            'fields':
                'id,student_number,first_name,last_name,middle_name,email,user_id,deparment_id,class_id',
            'limit': '1',
          },
        );
        final data = res.data['data'] as List;
        if (data.isNotEmpty) {
          studentRecord = data.first;
          log('Found student by email', name: 'AuthService');
        }
      } catch (e) {
        log('Strategy 2 failed: $e', name: 'AuthService');
      }
    }

    // Strategy 3: Search by name
    if (studentRecord == null && firstName != null && lastName != null) {
      try {
        final res = await _dio.get(
          '/items/students',
          queryParameters: {
            'filter[first_name][_eq]': firstName,
            'filter[last_name][_eq]': lastName,
            'fields':
                'id,student_number,first_name,last_name,middle_name,email,user_id,deparment_id,class_id',
            'limit': '1',
          },
        );
        final data = res.data['data'] as List;
        if (data.isNotEmpty) {
          studentRecord = data.first;
          log('Found student by name', name: 'AuthService');
        }
      } catch (e) {
        log('Strategy 3 failed: $e', name: 'AuthService');
      }
    }

    // If found, enrich user object with student data
    if (studentRecord != null) {
      _user!['student'] = studentRecord;
      _user!['student_id'] = studentRecord['id'];

      log('Student linked: ${studentRecord['id']}', name: 'AuthService');

      // If student found by name/email but not yet linked, link it now
      if (studentRecord['user_id'] == null) {
        try {
          await _dio.patch(
            '/items/students/${studentRecord['id']}',
            data: {'user_id': userId},
          );
          log('Linked student to user', name: 'AuthService');
        } catch (e) {
          log('Could not link student to user: $e', name: 'AuthService');
        }
      }
    } else {
      log('No student record found', name: 'AuthService');
    }
  }

  Future<void> _fetchCurrentUser() async {
    if (_token == null) return;

    try {
      final response = await _dio.get(
        '/users/me?fields=*,avatar.*,student.*,student_id.*',
      );

      _user = response.data['data'];

      log('Fetched current user: ${_user?['email']}', name: 'AuthService');

      // Link student to user
      await _linkStudentToUser();

      notifyListeners();
    } catch (e) {
      log('Failed to fetch user: $e', name: 'AuthService');
      rethrow;
    }
  }

  // ------------------------------------------------------------
  // UPDATE USER DETAILS
  // ------------------------------------------------------------
  Future<void> updateUser(Map<String, dynamic> data) async {
    if (_user == null) {
      throw Exception('User not authenticated.');
    }

    final userId = _user!['id'];

    try {
      await _dio.patch('/users/$userId', data: data);
      await _fetchCurrentUser();
    } on DioException catch (e) {
      final msg =
          e.response?.data['errors']?[0]?['message'] ?? 'Update failed.';
      throw Exception(msg);
    }
  }

  // ------------------------------------------------------------
  // UPDATE STUDENT NUMBER
  // ------------------------------------------------------------
  Future<void> updateStudentNumber({
    required String oldStudentNumber,
    required String newStudentNumber,
  }) async {
    try {
      final lookup = await _dio.get(
        '/items/students?filter[studentNumber][_eq]=$oldStudentNumber&fields=id',
      );

      final list = lookup.data['data'] as List;
      if (list.isEmpty) {
        throw Exception('Original student record not found.');
      }

      final studentId = list[0]['id'];

      await _dio.patch(
        '/items/students/$studentId',
        data: {'studentNumber': newStudentNumber},
      );

      await _fetchCurrentUser();
    } on DioException catch (e) {
      final msg = e.response?.data['errors']?[0]?['message'] ??
          'Failed to update student number.';
      throw Exception(msg);
    }
  }

  // ------------------------------------------------------------
  // SIGN-IN (With Role Restriction: Only students can log in)
  // ------------------------------------------------------------
  Future<void> signIn(String email, String password) async {
    try {
      log('=== LOGIN ATTEMPT ===', name: 'AuthService');

      // Use a separate Dio instance for login to avoid interceptor issues
      final loginDio = Dio();
      final response = await loginDio.post(
        '$directusUrl/auth/login',
        data: {
          'email': email,
          'password': password,
          'mode': 'json',
        },
      );

      final data = response.data['data'];
      final accessToken = data['access_token'];
      final refreshToken = data['refresh_token'];
      final expiresIn = data['expires'] ?? 900000; // Default 15 min

      log('Login successful, tokens received', name: 'AuthService');

      // Temporarily store token to check role
      _token = accessToken;
      _refreshToken = refreshToken;
      _tokenExpiry = DateTime.now().add(Duration(milliseconds: expiresIn));

      // Fetch user info to check role
      final userResponse = await _dio.get(
        '/users/me?fields=id,email,role.*,student.*',
      );

      final user = userResponse.data['data'];
      final userRole = user['role']?['name'] ?? '';

      log('User role: $userRole', name: 'AuthService');

      // Block non-students
      if (userRole.toLowerCase() != 'student') {
        _token = null;
        _refreshToken = null;
        _tokenExpiry = null;
        log('LOGIN BLOCKED: Role is not student', name: 'AuthService');
        throw Exception("Only students are allowed to log in.");
      }

      // Role is student → complete login
      _user = user;

      await _saveTokenToStorage();
      await _fetchCurrentUser();

      log('=== LOGIN SUCCESS ===', name: 'AuthService');
      notifyListeners();
    } on DioException catch (e) {
      log('Login failed: ${e.response?.data}', name: 'AuthService');
      final msg =
          e.response?.data['errors']?[0]?['message'] ?? 'Invalid credentials.';
      throw Exception(msg);
    } catch (e) {
      log('Login error: $e', name: 'AuthService');
      throw Exception(e.toString().replaceFirst("Exception: ", ""));
    }
  }

  // ------------------------------------------------------------
  // LOGOUT (Also invalidates refresh token)
  // ------------------------------------------------------------
  Future<void> logout() async {
    // Try to invalidate refresh token on server
    if (_refreshToken != null) {
      try {
        final logoutDio = Dio();
        await logoutDio.post(
          '$directusUrl/auth/logout',
          data: {'refresh_token': _refreshToken},
        );
        log('Refresh token invalidated on server', name: 'AuthService');
      } catch (e) {
        log('Could not invalidate refresh token: $e', name: 'AuthService');
      }
    }

    _token = null;
    _refreshToken = null;
    _tokenExpiry = null;
    _user = null;
    await _clearTokenFromStorage();
    notifyListeners();
  }

  // ------------------------------------------------------------
  // CHANGE PASSWORD
  // ------------------------------------------------------------
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (_user == null) {
      throw Exception('User not authenticated.');
    }

    final userEmail = _user!['email'];

    try {
      // First verify current password by attempting a login
      final verifyDio = Dio();
      try {
        await verifyDio.post(
          '$directusUrl/auth/login',
          data: {
            'email': userEmail,
            'password': currentPassword,
            'mode': 'json',
          },
        );
      } on DioException {
        throw Exception('Current password is incorrect.');
      }

      // If verification successful, update password
      await _dio.patch(
        '/users/me',
        data: {'password': newPassword},
      );

      log('Password changed successfully', name: 'AuthService');
    } on DioException catch (e) {
      final msg =
          e.response?.data['errors']?[0]?['message'] ?? 'Failed to change password.';
      throw Exception(msg);
    }
  }

  // ------------------------------------------------------------
  // MANUAL TOKEN REFRESH (can be called from UI if needed)
  // ------------------------------------------------------------
  Future<bool> refreshToken() async {
    return await _refreshAccessToken();
  }

  // ------------------------------------------------------------
  // FORCE LOGOUT (when session expires)
  // ------------------------------------------------------------
  Future<void> _forceLogout() async {
    log('Session expired - forcing logout', name: 'AuthService');

    _token = null;
    _refreshToken = null;
    _tokenExpiry = null;
    _user = null;
    await _clearTokenFromStorage();

    // Trigger the callback if set
    onSessionExpired?.call();

    notifyListeners();
  }
}
