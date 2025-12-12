
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
      final url = '$_directusUrl/items/questions'
          '?filter[survey_id][_eq]=$surveyId'
          '&fields=id,question_text,question_type,scale_description,questionNumber'
          '&sort=questionNumber';

      log('URL: $url', name: 'SurveyService');

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
}
