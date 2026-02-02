
import 'dart:developer';
import 'package:dio/dio.dart';
import '../config.dart';

class SurveyService {
  final Dio _dio = Dio();
  static const String _directusUrl = AppConfig.directusUrl;

  SurveyService(String? token) {
    if (token != null) {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    }
  }

  Future<List<Map<String, dynamic>>> fetchAvailableSurveys() async {
    try {
      const url =
          '$_directusUrl/items/surveys?filter[status][_eq]=Active&fields=id,title,instruction,percentage';

      final response = await _dio.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> surveyData = response.data['data'];
        return surveyData.cast<Map<String, dynamic>>();
      }
      return [];
    } on DioException catch (e) {
      log('Error fetching surveys: ${e.response?.data}', name: 'SurveyService');
      throw Exception("Failed to fetch surveys.");
    }
  }

  Future<List<Map<String, dynamic>>> fetchSurveyQuestions(String surveyId) async {
    try {
      final url = '$_directusUrl/items/StudentQuestion'
          '?filter[group_id][survey_id][_eq]=$surveyId'
          '&fields=id,question,group_id.id,group_id.number,group_id.title,group_id.response_style'
          '&sort=group_id.number';

      log('Fetching questions URL: $url', name: 'SurveyService');

      final response = await _dio.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> questionData = response.data['data'];
        return questionData.cast<Map<String, dynamic>>();
      }
      return [];
    } on DioException catch (e) {
      log('Error fetching questions: ${e.response?.data}', name: 'SurveyService');
      throw Exception("Could not load survey questions.");
    }
  }

  Future<void> submitSurveyResponses(
      String surveyId, Map<String, dynamic> responses) async {
    try {
      final url = '$_directusUrl/items/survey_responses';

      final payload = {
        'survey_id': surveyId,
        'responses': responses,
      };

      final response = await _dio.post(url, data: payload);

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception("Failed to submit survey.");
      }
    } on DioException catch (e) {
      log('Submit error: ${e.response?.data}', name: 'SurveyService');
      throw Exception("Failed to submit survey responses.");
    }
  }
  Future<List<Map<String, dynamic>>> getStudentResponses(String studentId) async {
    try {
      final url = '$_directusUrl/items/survey_responses'
          '?filter[student_id][_eq]=$studentId'
          '&fields=id,survey_id,responses,date_created';

      final response = await _dio.get(url);

      if (response.statusCode == 200) {
        return (response.data['data'] as List)
            .map((e) => e as Map<String, dynamic>)
            .toList();
      }
      return [];
    } on DioException catch (e) {
      log('Error fetching student responses: ${e.response?.data}',
          name: 'SurveyService');
      throw Exception("Unable to fetch student responses.");
    }
  }

  Future<List<Map<String, dynamic>>> getSurveysForSection(
      String yearLevel, String section) async {
    try {
      final url = '$_directusUrl/items/surveys'
          '?filter[year_level][_contains]=$yearLevel'
          '&filter[section][_contains]=$section'
          '&filter[status][_eq]=Active'
          '&fields=id,title,instruction,percentage';

      final response = await _dio.get(url);

      if (response.statusCode == 200) {
        return (response.data['data'] as List)
            .map((e) => e as Map<String, dynamic>)
            .toList();
      }
      return [];
    } on DioException catch (e) {
      log('Error fetching surveys by section: ${e.response?.data}',
          name: 'SurveyService');
      throw Exception("Unable to load surveys for student section.");
    }
  }

  // ============================================================
  // NEW METHODS FOR StudentEvaluationSurvey COLLECTIONS
  // ============================================================

  /// Fetch StudentEvaluationSurvey items (active surveys with eligibility data)
  Future<List<Map<String, dynamic>>> fetchStudentEvaluationSurveys() async {
    try {
      // Match the web app's query exactly
      final response = await _dio.get(
        '$_directusUrl/items/StudentEvaluationSurvey',
        queryParameters: {
          'filter[is_active][_eq]': 'Active',
          'fields': [
            '*',
            'target_year_levels',
            'office_id.id',
            'office_id.name',
            'students.students_id',
            'student_course_assignments', // Fair distribution: which courses each student is assigned to
            'classes.classes_id.*',  // Get all class fields
            'classes.classes_id.course_id.*',
            'classes.classes_id.teacher_id.*',
            'question_group.*',
            'question_group.questions.*',
          ].join(','),
        },
      );

      if (response.statusCode == 200) {
        final surveys = (response.data['data'] as List).cast<Map<String, dynamic>>();
        log('Fetched ${surveys.length} active surveys', name: 'SurveyService');

        // Log survey details for debugging
        for (final s in surveys) {
          final classes = s['classes'] as List? ?? [];
          log('Survey "${s['title']}": type=${s['evaluation_type']}, classes=${classes.length}',
              name: 'SurveyService');
        }

        return surveys;
      }
      return [];
    } on DioException catch (e) {
      log('Error fetching StudentEvaluationSurvey: ${e.response?.data}',
          name: 'SurveyService');
      throw Exception("Failed to fetch evaluation surveys.");
    }
  }

  /// Fetch student's completed survey responses from StudentSurveyResponses
  Future<List<Map<String, dynamic>>> fetchStudentSurveyResponses(
      String studentId) async {
    try {
      final url = '$_directusUrl/items/StudentSurveyResponses'
          '?filter[student_id][_eq]=$studentId'
          '&fields=id,survey_id,class_id,office_id,submitted_at';

      final response = await _dio.get(url);

      if (response.statusCode == 200) {
        return (response.data['data'] as List).cast<Map<String, dynamic>>();
      }
      return [];
    } on DioException catch (e) {
      log('Error fetching StudentSurveyResponses: ${e.response?.data}',
          name: 'SurveyService');
      throw Exception("Failed to fetch student survey responses.");
    }
  }

  /// Fetch recent activity (last 5 completed surveys with titles)
  Future<List<Map<String, dynamic>>> fetchRecentActivity(
      String studentId) async {
    try {
      final url = '$_directusUrl/items/StudentSurveyResponses'
          '?filter[student_id][_eq]=$studentId'
          '&fields=id,submitted_at,survey_id.title'
          '&sort=-submitted_at'
          '&limit=5';

      final response = await _dio.get(url);

      if (response.statusCode == 200) {
        final data = response.data['data'] as List;
        return data.map((r) {
          final surveyId = r['survey_id'];
          String surveyTitle;
          if (surveyId is Map) {
            surveyTitle = surveyId['title'] ?? 'Survey';
          } else {
            surveyTitle = 'Survey #$surveyId';
          }
          return {
            'id': r['id'],
            'surveyTitle': surveyTitle,
            'submittedAt': r['submitted_at'],
          };
        }).toList().cast<Map<String, dynamic>>();
      }
      return [];
    } on DioException catch (e) {
      log('Error fetching recent activity: ${e.response?.data}',
          name: 'SurveyService');
      return [];
    }
  }

  /// Fetch current active academic term
  Future<Map<String, dynamic>?> fetchCurrentAcademicTerm() async {
    try {
      final url = '$_directusUrl/items/academicTerms'
          '?filter[status][_eq]=Active'
          '&limit=1';

      final response = await _dio.get(url);

      if (response.statusCode == 200) {
        final data = response.data['data'] as List;
        return data.isNotEmpty ? data.first : null;
      }
      return null;
    } on DioException catch (e) {
      log('Error fetching academic term: ${e.response?.data}',
          name: 'SurveyService');
      return null;
    }
  }

  /// Fetch student's enrolled classes via junction table
  Future<List<Map<String, dynamic>>> fetchStudentClasses(
      String studentId) async {
    try {
      log('Fetching classes for student ID: $studentId', name: 'SurveyService');

      // Use params structure like the web app does
      final response = await _dio.get(
        '$_directusUrl/items/classes',
        queryParameters: {
          'filter[student_id][students_id][_eq]': studentId,
          'fields': 'id,section,course_id.*,teacher_id.*,acadTerm_id.*',
        },
      );

      if (response.statusCode == 200) {
        var classes = (response.data['data'] as List).cast<Map<String, dynamic>>();
        log('Found ${classes.length} classes for student $studentId',
            name: 'SurveyService');

        // Log class details for debugging
        for (final c in classes) {
          log('  Class: id=${c['id']}, section=${c['section']}',
              name: 'SurveyService');
        }

        return classes;
      }
      return [];
    } on DioException catch (e) {
      log('Error fetching student classes: ${e.response?.statusCode} - ${e.response?.data}',
          name: 'SurveyService');
      throw Exception("Failed to fetch student classes.");
    }
  }

  /// Fetch student's department and year level
  Future<Map<String, dynamic>?> fetchStudentInfo(
      String studentId) async {
    try {
      final url = '$_directusUrl/items/students/$studentId'
          '?fields=id,deparment_id.*,year_level';

      final response = await _dio.get(url);

      if (response.statusCode == 200) {
        return response.data['data'];
      }
      return null;
    } on DioException catch (e) {
      log('Error fetching student info: ${e.response?.data}',
          name: 'SurveyService');
      return null;
    }
  }

  /// Fetch student's department (backwards compatibility)
  Future<Map<String, dynamic>?> fetchStudentDepartment(
      String studentId) async {
    final info = await fetchStudentInfo(studentId);
    return info?['deparment_id'];
  }

  /// Check if student has completed a specific survey for a target
  Future<bool> hasCompletedSurvey({
    required String studentId,
    required String surveyId,
    String? classId,
    String? officeId,
  }) async {
    try {
      String url = '$_directusUrl/items/StudentSurveyResponses'
          '?filter[student_id][_eq]=$studentId'
          '&filter[survey_id][_eq]=$surveyId';

      if (classId != null) {
        url += '&filter[class_id][_eq]=$classId';
      }
      if (officeId != null) {
        url += '&filter[office_id][_eq]=$officeId';
      }

      final response = await _dio.get(url);

      if (response.statusCode == 200) {
        final data = response.data['data'] as List;
        return data.isNotEmpty;
      }
      return false;
    } on DioException catch (e) {
      log('Error checking survey completion: ${e.response?.data}',
          name: 'SurveyService');
      return false;
    }
  }

  /// Two-step submission: Step 1 - Create StudentSurveyResponse record
  Future<String> createSurveyResponse({
    required String surveyId,
    required String studentId,
    String? classId,
    String? officeId,
    String? evaluatedTeacherId,
  }) async {
    try {
      final url = '$_directusUrl/items/StudentSurveyResponses';

      final payload = {
        'survey_id': surveyId,
        'student_id': studentId,
        'submitted_at': DateTime.now().toIso8601String(),
        'status': 'completed',
      };

      if (classId != null) payload['class_id'] = classId;
      if (officeId != null) payload['office_id'] = officeId;
      if (evaluatedTeacherId != null) {
        payload['evaluated_teacher_id'] = evaluatedTeacherId;
      }

      final response = await _dio.post(url, data: payload);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data['data']['id'].toString();
      }
      throw Exception("Failed to create survey response.");
    } on DioException catch (e) {
      log('Error creating survey response: ${e.response?.data}',
          name: 'SurveyService');
      throw Exception("Failed to create survey response.");
    }
  }

  /// Two-step submission: Step 2 - Create StudentSurveyAnswers records
  Future<void> submitSurveyAnswers({
    required String responseId,
    required List<Map<String, dynamic>> answers,
  }) async {
    try {
      final url = '$_directusUrl/items/StudentSurveyAnswers';

      // Batch insert all answers
      for (final answer in answers) {
        await _dio.post(url, data: {
          'response_id': responseId,
          'question_id': answer['questionId'],
          'answer_value': answer['answer']?.toString() ?? '',
        });
      }
    } on DioException catch (e) {
      log('Error submitting survey answers: ${e.response?.data}',
          name: 'SurveyService');
      throw Exception("Failed to submit survey answers.");
    }
  }

  /// Get survey statistics for dashboard
  Future<Map<String, dynamic>> getSurveyStats({
    required String studentId,
    required List<Map<String, dynamic>> eligibleSurveys,
  }) async {
    try {
      // Fetch completed responses
      final completedResponses =
          await fetchStudentSurveyResponses(studentId);

      final total = eligibleSurveys.length;
      final completed = completedResponses.length;
      final pending = total > completed ? total - completed : 0;
      final completionRate =
          total > 0 ? ((completed / total) * 100).round() : 0;

      return {
        'total': total,
        'completed': completed,
        'pending': pending,
        'completionRate': completionRate,
      };
    } catch (e) {
      log('Error calculating survey stats: $e', name: 'SurveyService');
      return {
        'total': 0,
        'completed': 0,
        'pending': 0,
        'completionRate': 0,
      };
    }
  }

  /// Fetch office details by ID
  Future<Map<String, dynamic>?> fetchOfficeDetails(String officeId) async {
    try {
      final url = '$_directusUrl/items/SchoolOffices/$officeId';

      final response = await _dio.get(url);

      if (response.statusCode == 200) {
        return response.data['data'];
      }
      return null;
    } on DioException catch (e) {
      log('Error fetching office details: ${e.response?.data}',
          name: 'SurveyService');
      return null;
    }
  }
}
