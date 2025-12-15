
import 'dart:convert';
import 'dart:developer';
import '../config.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService extends ChangeNotifier {
  static const String directusUrl = AppConfig.directusUrl;
  final Dio _dio = Dio();

  String? _token;
  Map<String, dynamic>? _user;

  String? get token => _token;
  Map<String, dynamic>? get currentUser => _user;
  bool get isAuthenticated => _token != null;

  AuthService() {
    _loadTokenFromStorage();
  }

  Future<void> _loadTokenFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final storedToken = prefs.getString('auth_token');

    if (storedToken != null) {
      _token = storedToken;
      _dio.options.headers['Authorization'] = 'Bearer $_token';
      try {
        await _fetchCurrentUser();
        notifyListeners();
      } catch (e) {
        // Token expired or invalid - clear and require fresh login
        log('Stored token invalid, clearing: $e', name: 'AuthService');
        await _clearTokenFromStorage();
        _token = null;
        _user = null;
        _dio.options.headers.remove('Authorization');
      }
    }
  }

  Future<void> _saveTokenToStorage(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  Future<void> _clearTokenFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
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
    log('User ID: $userId', name: 'AuthService');
    log('User Email: $userEmail', name: 'AuthService');
    log('User Name: $firstName $lastName', name: 'AuthService');

    Map<String, dynamic>? studentRecord;

    // Strategy 1: Search by user_id (direct link in students table)
    try {
      log('Strategy 1: Searching by user_id...', name: 'AuthService');
      final res = await _dio.get(
        '$directusUrl/items/students',
        queryParameters: {
          'filter[user_id][_eq]': userId,
          'fields': 'id,student_number,first_name,last_name,middle_name,email,user_id,deparment_id,class_id',
          'limit': '1',
        },
      );
      final data = res.data['data'] as List;
      if (data.isNotEmpty) {
        studentRecord = data.first;
        log('Strategy 1 SUCCESS: Found student by user_id', name: 'AuthService');
      }
    } catch (e) {
      log('Strategy 1 failed: $e', name: 'AuthService');
    }

    // Strategy 2: Search by email
    if (studentRecord == null && userEmail != null) {
      try {
        log('Strategy 2: Searching by email...', name: 'AuthService');
        final res = await _dio.get(
          '$directusUrl/items/students',
          queryParameters: {
            'filter[email][_eq]': userEmail,
            'fields': 'id,student_number,first_name,last_name,middle_name,email,user_id,deparment_id,class_id',
            'limit': '1',
          },
        );
        final data = res.data['data'] as List;
        if (data.isNotEmpty) {
          studentRecord = data.first;
          log('Strategy 2 SUCCESS: Found student by email', name: 'AuthService');
        }
      } catch (e) {
        log('Strategy 2 failed: $e', name: 'AuthService');
      }
    }

    // Strategy 3: Search by name
    if (studentRecord == null && firstName != null && lastName != null) {
      try {
        log('Strategy 3: Searching by name...', name: 'AuthService');
        final res = await _dio.get(
          '$directusUrl/items/students',
          queryParameters: {
            'filter[first_name][_eq]': firstName,
            'filter[last_name][_eq]': lastName,
            'fields': 'id,student_number,first_name,last_name,middle_name,email,user_id,deparment_id,class_id',
            'limit': '1',
          },
        );
        final data = res.data['data'] as List;
        if (data.isNotEmpty) {
          studentRecord = data.first;
          log('Strategy 3 SUCCESS: Found student by name', name: 'AuthService');
        }
      } catch (e) {
        log('Strategy 3 failed: $e', name: 'AuthService');
      }
    }

    // If found, enrich user object with student data
    if (studentRecord != null) {
      _user!['student'] = studentRecord;
      _user!['student_id'] = studentRecord['id'];

      log('Student record found: ${studentRecord['id']}', name: 'AuthService');
      log('Student: ${studentRecord['first_name']} ${studentRecord['last_name']}', name: 'AuthService');

      // If student found by name/email but not yet linked, link it now
      if (studentRecord['user_id'] == null) {
        try {
          log('Linking student to user...', name: 'AuthService');
          await _dio.patch(
            '$directusUrl/items/students/${studentRecord['id']}',
            data: {'user_id': userId},
          );
          log('Successfully linked student ${studentRecord['id']} to user $userId', name: 'AuthService');
        } catch (e) {
          log('Could not link student to user: $e', name: 'AuthService');
        }
      }

      log('=== STUDENT LINKED SUCCESSFULLY ===', name: 'AuthService');
    } else {
      log('=== NO STUDENT RECORD FOUND ===', name: 'AuthService');
    }
  }

  Future<void> _fetchCurrentUser() async {
    if (_token == null) return;

    try {
      final response = await _dio.get(
        '$directusUrl/users/me?fields=*,avatar.*,student.*,student_id.*',
      );

      _user = response.data['data'];

      // DEBUG: Log the user data structure
      log('=== FETCH CURRENT USER ===', name: 'AuthService');
      log('User data: $_user', name: 'AuthService');
      log('student field: ${_user?['student']}', name: 'AuthService');
      log('student_id field: ${_user?['student_id']}', name: 'AuthService');
 
      // Link student to user (Vue-style: search by user_id → email → name)
      await _linkStudentToUser();

      notifyListeners();
    } catch (e) {
      log('Failed to fetch user: $e', name: 'AuthService');
      logout();
    }
  }

  // ------------------------------------------------------------
  // STUDENT VERIFICATION (NO MORE user_created READ)
  // ------------------------------------------------------------
  Future<Map<String, dynamic>> verifyStudent({
    required String studentId,
    required String firstName,
    required String lastName,
    required String middleInitial,
  }) async {
    try {
      final sid = studentId.trim();
      final fn = firstName.trim();
      final ln = lastName.trim();
      final mi = middleInitial.trim();

      final url = Uri.parse(
        '$directusUrl/items/students'
            '?filter[studentNumber][_eq]=$sid'
            '&filter[firstName][_eq]=$fn'
            '&filter[lastName][_eq]=$ln'
            '&fields=id,studentNumber,firstName,lastName,middleInitial',
      );

      final response = await http.get(url);

      if (response.statusCode >= 300) {
        final err = json.decode(response.body);
        final msg = err['errors']?[0]?['message'] ?? 'Server error.';
        throw Exception(msg);
      }

      final decoded = json.decode(response.body);
      final data = decoded['data'] as List?;

      if (data == null || data.isEmpty) {
        throw Exception('No matching student record found.');
      }

      final student = data.first;
      final recordMI = (student['middleInitial'] ?? '').toString().trim();

      // NEW RULE:
      // ---------------------------------------------------------
      // If student record HAS middle initial, enforce matching
      // If student record does NOT have MI, allow blank input
      // ---------------------------------------------------------

      if (recordMI.isNotEmpty) {
        // record has MI → user must type it correctly
        if (mi.isEmpty) {
          throw Exception('Middle Initial is required for this student.');
        }
        if (mi != recordMI) {
          throw Exception('Middle Initial does not match school record.');
        }
      } else {
        // record has NO MI → user must leave it empty
        if (mi.isNotEmpty) {
          throw Exception(
            'Your school record shows **no middle name**. Leave Middle Initial empty.',
          );
        }
      }

      return {
        'studentNumber': student['studentNumber'],
        'firstName': student['firstName'],
        'middleInitial': recordMI,
        'lastName': student['lastName'],
        'studentId': student['id'],
      };
    } catch (e) {
      log('Error in verifyStudent: $e', name: 'AuthService');
      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }
  }


  // ------------------------------------------------------------
  // SIGN UP
  // ------------------------------------------------------------
  Future<void> signUp({
    required String studentId,
    required String firstName,
    String? middleInitial,
    required String lastName,
    required String email,
    required String password,
  }) async {
    try {
      // Lookup student record
      final studentLookup = Uri.parse(
        '$directusUrl/items/students'
            '?filter[studentNumber][_eq]=$studentId'
            '&fields=id',
      );

      final lookupResponse = await http.get(studentLookup);
      final lookupData = json.decode(lookupResponse.body)['data'] as List;

      if (lookupData.isEmpty) {
        throw Exception('Student record not found during sign-up.');
      }

      final String studentPrimaryKey = lookupData[0]['id'].toString();

      // Your student role UUID
      const String userRoleId = '9d994507-5b03-418f-b594-27e2dd7db837';

      // Create user
      final response = await _dio.post(
        '$directusUrl/users',
        data: {
          'first_name': firstName,
          'last_name': lastName,
          'middle_initial': middleInitial,
          'email': email,
          'password': password,
          'role': userRoleId,
          'student_id': studentPrimaryKey,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        // Mark student as used (if this field exists)
        try {
          await _dio.patch(
            '$directusUrl/items/students/$studentPrimaryKey',
            data: {'user_created': true},
          );
        } catch (_) {
          log('Warning: Could not update user_created. Check permissions.',
              name: 'AuthService');
        }
      } else {
        throw Exception('Failed to create user.');
      }
    } on DioException catch (e) {
      final errorMsg =
          e.response?.data['errors']?[0]?['message'] ?? 'Sign-up failed.';
      throw Exception(errorMsg);
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }

  // -----------------------------------------------------------
  // UPDATE USER DETAILS
  // ------------------------------------------------------------
  Future<void> updateUser(Map<String, dynamic> data) async {
    if (_user == null) {
      throw Exception('User not authenticated.');
    }

    final userId = _user!['id'];

    try {
      await _dio.patch('$directusUrl/users/$userId', data: data);
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
        '$directusUrl/items/students?filter[studentNumber][_eq]=$oldStudentNumber&fields=id',
      );

      final list = lookup.data['data'] as List;
      if (list.isEmpty) {
        throw Exception('Original student record not found.');
      }

      final studentId = list[0]['id'];

      await _dio.patch(
        '$directusUrl/items/students/$studentId',
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
  // REQUEST PASSWORD RESET
  // ------------------------------------------------------------
  Future<void> requestPasswordReset({required String email}) async {
    const resetUrl = 'https://survegio.app/reset-password';

    try {
      await http.post(
        Uri.parse('$directusUrl/auth/password/request'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'reset_url': resetUrl,
        }),
      );
    } catch (e) {
      log('Password reset request error: $e', name: 'AuthService');
    }
  }

  // ------------------------------------------------------------
// SIGN-IN (With Role Restriction: Only students can log in)
// ------------------------------------------------------------
  Future<void> signIn(String email, String password) async {
    try {
      // DEBUG: Log the login attempt
      log('=== LOGIN ATTEMPT ===', name: 'AuthService');
      log('Directus URL: $directusUrl', name: 'AuthService');
      log('Email: $email', name: 'AuthService');

      final loginUrl = '$directusUrl/auth/login';
      log('Full login URL: $loginUrl', name: 'AuthService');

      final response = await _dio.post(
        loginUrl,
        data: {'email': email, 'password': password},
      );

      log('Login response status: ${response.statusCode}', name: 'AuthService');
      log('Login response data: ${response.data}', name: 'AuthService');

      final data = response.data['data'];
      final accessToken = data['access_token'];

      log('Access token received: ${accessToken != null ? 'YES' : 'NO'}', name: 'AuthService');

      // 1) Temporarily store token to check role
      _dio.options.headers['Authorization'] = 'Bearer $accessToken';

      // 2) Fetch user info INCLUDING role
      log('Fetching user info...', name: 'AuthService');
      final userResponse = await _dio.get(
        '$directusUrl/users/me?fields=id,email,role.*,student.*',
      );

      log('User response status: ${userResponse.statusCode}', name: 'AuthService');
      log('User response data: ${userResponse.data}', name: 'AuthService');

      final user = userResponse.data['data'];
      final userRole = user['role']?['name'] ?? '';

      log('User role: $userRole', name: 'AuthService');
      log('User student data: ${user['student']}', name: 'AuthService');

      // 3) Block non-students
      if (userRole.toLowerCase() != 'student') {
        _dio.options.headers.remove('Authorization');
        log('LOGIN BLOCKED: Role is not student', name: 'AuthService');
        throw Exception("Only students are allowed to log in.");
      }

      // 4) Role is student → allow login
      _token = accessToken;
      _user = user;

      await _saveTokenToStorage(_token!);

      await _fetchCurrentUser();

      log('=== LOGIN SUCCESS ===', name: 'AuthService');
      notifyListeners();
    } on DioException catch (e) {
      log('=== LOGIN FAILED (DioException) ===', name: 'AuthService');
      log('Error type: ${e.type}', name: 'AuthService');
      log('Error message: ${e.message}', name: 'AuthService');
      log('Response status: ${e.response?.statusCode}', name: 'AuthService');
      log('Response data: ${e.response?.data}', name: 'AuthService');

      final msg =
          e.response?.data['errors']?[0]?['message'] ?? 'Invalid credentials.';
      throw Exception(msg);
    } catch (e) {
      log('=== LOGIN FAILED (Exception) ===', name: 'AuthService');
      log('Error: $e', name: 'AuthService');
      throw Exception(e.toString().replaceFirst("Exception: ", ""));
    }
  }


  void logout() {
    _token = null;
    _user = null;
    _dio.options.headers.remove('Authorization');
    _clearTokenFromStorage();
    notifyListeners();
  }
}
