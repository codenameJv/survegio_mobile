import 'dart:developer';
import 'package:dio/dio.dart';
import '../config.dart';

/// Service for handling survey eligibility filtering
/// Based on class enrollment and office assignment modes
class EligibilityService {
  final Dio _dio = Dio();
  static const String _directusUrl = AppConfig.directusUrl;

  EligibilityService(String? token) {
    if (token != null) {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    }
  }

  /// Check if student is eligible for a class-based survey
  /// Student must be enrolled in the class
  Future<bool> isEligibleForClassSurvey({
    required String studentId,
    required String classId,
  }) async {
    try {
      final url = '$_directusUrl/items/classes/$classId'
          '?fields=student_id.students_id';

      final response = await _dio.get(url);

      if (response.statusCode == 200) {
        final students = response.data['data']?['student_id'] as List? ?? [];
        return students.any((s) => s['students_id'].toString() == studentId);
      }
      return false;
    } catch (e) {
      log('Error checking class eligibility: $e', name: 'EligibilityService');
      return false;
    }
  }

  /// Check if student is eligible for office-based survey based on assignment_mode
  /// - 'all': Any student with at least one enrolled class is eligible
  /// - 'department'/'specific': Students are pre-assigned to survey's students array
  bool isEligibleForOfficeSurvey({
    required String studentId,
    required Map<String, dynamic> survey,
    required String assignmentMode,
    required int enrolledClassCount,
    String? studentDepartmentId,
  }) {
    // If assignment_mode is 'all', student must have at least one enrolled class
    if (assignmentMode.toLowerCase() == 'all') {
      return enrolledClassCount > 0;
    }

    // For 'department' and 'specific' modes, check if student is in the survey's students array
    final students = survey['students'] as List? ?? [];

    // If students array is empty but mode isn't 'all', not eligible
    if (students.isEmpty) {
      return false;
    }

    // Check if student ID is in the junction records
    return students.any((s) {
      final sid = s['students_id'];
      if (sid is Map) {
        return sid['id']?.toString() == studentId;
      }
      return sid?.toString() == studentId;
    });
  }

  /// Filter all surveys by student eligibility
  /// Returns list of eligible surveys with their targets (class/office info)
  Future<List<Map<String, dynamic>>> getEligibleSurveys({
    required String studentId,
    required List<Map<String, dynamic>> allSurveys,
    required List<Map<String, dynamic>> enrolledClasses,
    String? studentDepartmentId,
    String? studentYearLevel,
  }) async {
    final eligibleSurveys = <Map<String, dynamic>>[];
    final enrolledClassIds =
        enrolledClasses.map((c) => c['id'].toString()).toSet();

    log('EligibilityService: Student $studentId enrolled in ${enrolledClasses.length} classes',
        name: 'EligibilityService');
    log('EligibilityService: Enrolled class IDs: $enrolledClassIds',
        name: 'EligibilityService');
    log('EligibilityService: Student year level: $studentYearLevel',
        name: 'EligibilityService');
    log('EligibilityService: Processing ${allSurveys.length} surveys',
        name: 'EligibilityService');

    for (final survey in allSurveys) {
      final evaluationType =
          (survey['evaluation_type'] ?? 'class').toString().toLowerCase();

      log('EligibilityService: Survey "${survey['title']}" type: $evaluationType',
          name: 'EligibilityService');

      // Check year level targeting (matches web app logic)
      final targetYearLevels = survey['target_year_levels'] as List?;
      if (targetYearLevels != null && targetYearLevels.isNotEmpty) {
        if (studentYearLevel == null ||
            !targetYearLevels.contains(studentYearLevel)) {
          log('EligibilityService: Skipping survey - year level mismatch. Target: $targetYearLevels, Student: $studentYearLevel',
              name: 'EligibilityService');
          continue;
        }
      }

      if (evaluationType == 'class') {
        // Class-based survey: check if student is enrolled in any of the survey's classes
        final surveyClasses = survey['classes'] as List? ?? [];

        log('EligibilityService: Survey "${survey['title']}" has ${surveyClasses.length} classes',
            name: 'EligibilityService');

        // Track if we found any eligible class for this student
        bool foundEligibleClass = false;

        for (final surveyClass in surveyClasses) {
          log('EligibilityService: Raw surveyClass junction entry: $surveyClass',
              name: 'EligibilityService');

          final classData = surveyClass['classes_id'];
          log('EligibilityService: classes_id value: $classData (type: ${classData.runtimeType})',
              name: 'EligibilityService');

          String? classId;

          if (classData is Map) {
            classId = classData['id']?.toString();
          } else {
            classId = classData?.toString();
          }

          log('EligibilityService: Extracted class ID: $classId',
              name: 'EligibilityService');
          log('EligibilityService: Enrolled class IDs: $enrolledClassIds',
              name: 'EligibilityService');
          log('EligibilityService: Is enrolled in this class? ${enrolledClassIds.contains(classId)}',
              name: 'EligibilityService');

          if (classId != null && enrolledClassIds.contains(classId)) {
            foundEligibleClass = true;
            // Student is enrolled in this class - add as eligible
            final eligibleSurvey = Map<String, dynamic>.from(survey);
            eligibleSurvey['target_type'] = 'class';
            eligibleSurvey['target_class_id'] = classId;

            // Get class details from enrolled classes or from survey data
            var classDetails = enrolledClasses.firstWhere(
              (c) => c['id'].toString() == classId,
              orElse: () => <String, dynamic>{},
            );

            // If class details not found in enrolled classes, use survey's class data
            if (classDetails.isEmpty && classData is Map) {
              classDetails = Map<String, dynamic>.from(classData);
            }

            eligibleSurvey['target_class'] = classDetails;

            eligibleSurveys.add(eligibleSurvey);
          }
        }

        // Fallback: Check if student is directly assigned to this survey's students list
        if (!foundEligibleClass && surveyClasses.isNotEmpty) {
          final surveyStudents = survey['students'] as List? ?? [];
          final isDirectlyAssigned = surveyStudents.any((s) {
            final sid = s['students_id'];
            if (sid is Map) {
              return sid['id']?.toString() == studentId;
            }
            return sid?.toString() == studentId;
          });

          if (isDirectlyAssigned) {
            log('EligibilityService: Student directly assigned to class survey, adding all survey classes',
                name: 'EligibilityService');

            // Add each class in the survey as eligible
            for (final surveyClass in surveyClasses) {
              final classData = surveyClass['classes_id'];
              String? classId;

              if (classData is Map) {
                classId = classData['id']?.toString();
              } else {
                classId = classData?.toString();
              }

              if (classId != null) {
                final eligibleSurvey = Map<String, dynamic>.from(survey);
                eligibleSurvey['target_type'] = 'class';
                eligibleSurvey['target_class_id'] = classId;
                eligibleSurvey['target_class'] =
                    classData is Map ? Map<String, dynamic>.from(classData) : {};
                eligibleSurveys.add(eligibleSurvey);
              }
            }
          }
        }
      } else if (evaluationType == 'office') {
        // Office-based survey: check assignment mode
        final assignmentMode =
            (survey['assignment_mode'] ?? 'all').toString().toLowerCase();

        final isEligible = isEligibleForOfficeSurvey(
          studentId: studentId,
          survey: survey,
          assignmentMode: assignmentMode,
          enrolledClassCount: enrolledClasses.length,
          studentDepartmentId: studentDepartmentId,
        );

        if (isEligible) {
          final eligibleSurvey = Map<String, dynamic>.from(survey);
          eligibleSurvey['target_type'] = 'office';
          eligibleSurvey['target_office'] = survey['office_id'];
          eligibleSurveys.add(eligibleSurvey);
        }
      }
    }

    return eligibleSurveys;
  }

  /// Get eligible pending surveys (not yet completed by student)
  Future<List<Map<String, dynamic>>> getPendingEligibleSurveys({
    required String studentId,
    required List<Map<String, dynamic>> eligibleSurveys,
    required List<Map<String, dynamic>> completedResponses,
  }) async {
    final pendingSurveys = <Map<String, dynamic>>[];

    for (final survey in eligibleSurveys) {
      final surveyId = survey['id']?.toString();
      final targetType = survey['target_type'];
      final classId = survey['target_class_id']?.toString();
      final officeId = survey['target_office']?['id']?.toString() ??
          survey['target_office']?.toString();

      // Check if already completed
      final isCompleted = completedResponses.any((r) {
        final rSurveyId = r['survey_id']?.toString();
        if (rSurveyId != surveyId) return false;

        if (targetType == 'class') {
          return r['class_id']?.toString() == classId;
        } else if (targetType == 'office') {
          return r['office_id']?.toString() == officeId;
        }
        return false;
      });

      if (!isCompleted) {
        pendingSurveys.add(survey);
      }
    }

    return pendingSurveys;
  }

  /// Get completed surveys from eligible list
  List<Map<String, dynamic>> getCompletedEligibleSurveys({
    required List<Map<String, dynamic>> eligibleSurveys,
    required List<Map<String, dynamic>> completedResponses,
  }) {
    final completedSurveys = <Map<String, dynamic>>[];

    for (final survey in eligibleSurveys) {
      final surveyId = survey['id']?.toString();
      final targetType = survey['target_type'];
      final classId = survey['target_class_id']?.toString();
      final officeId = survey['target_office']?['id']?.toString() ??
          survey['target_office']?.toString();

      // Check if completed
      final response = completedResponses.firstWhere(
        (r) {
          final rSurveyId = r['survey_id']?.toString();
          if (rSurveyId != surveyId) return false;

          if (targetType == 'class') {
            return r['class_id']?.toString() == classId;
          } else if (targetType == 'office') {
            return r['office_id']?.toString() == officeId;
          }
          return false;
        },
        orElse: () => {},
      );

      if (response.isNotEmpty) {
        final completedSurvey = Map<String, dynamic>.from(survey);
        completedSurvey['response'] = response;
        completedSurveys.add(completedSurvey);
      }
    }

    return completedSurveys;
  }
}
