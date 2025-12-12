
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
      await _fetchCurrentUser();
      notifyListeners();
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

  Future<void> _fetchCurrentUser() async {
    if (_token == null) return;

    try {
      final response = await _dio.get(
        '$directusUrl/users/me?fields=*,avatar.*,student.*',
      );

      _user = response.data['data'];
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
      final response = await _dio.post(
        '$directusUrl/auth/login',
        data: {'email': email, 'password': password},
      );

      final data = response.data['data'];
      final accessToken = data['access_token'];

      // 1) Temporarily store token to check role
      _dio.options.headers['Authorization'] = 'Bearer $accessToken';

      // 2) Fetch user info INCLUDING role
      final userResponse = await _dio.get(
        '$directusUrl/users/me?fields=id,email,role.*,student.*',
      );

      final user = userResponse.data['data'];
      final userRole = user['role']?['name'] ?? '';

      // 3) Block non-students
      if (userRole.toLowerCase() != 'student') {
        _dio.options.headers.remove('Authorization');
        throw Exception("Only students are allowed to log in.");
      }

      // 4) Role is student → allow login
      _token = accessToken;
      _user = user;

      await _saveTokenToStorage(_token!);

      await _fetchCurrentUser();

      notifyListeners();
    } on DioException catch (e) {
      final msg =
          e.response?.data['errors']?[0]?['message'] ?? 'Invalid credentials.';
      throw Exception(msg);
    } catch (e) {
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
