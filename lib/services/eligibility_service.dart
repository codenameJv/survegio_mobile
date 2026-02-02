import 'dart:developer';

/// Service for handling survey eligibility filtering
/// Matches the Vue.js web app logic where students MUST be in the survey's
/// students junction table (enforces student_percentage setting)
class EligibilityService {
  // ignore: unused_field
  final String? _token;

  EligibilityService(this._token);

  /// Check if student is in the survey's students junction table
  /// This enforces the student_percentage assignment setting
  bool _isStudentAssignedToSurvey({
    required String studentId,
    required Map<String, dynamic> survey,
  }) {
    final surveyStudents = survey['students'] as List? ?? [];

    if (surveyStudents.isEmpty) {
      return false;
    }

    // Convert student ID to number for comparison (Vue app uses Number())
    final studentIdNum = int.tryParse(studentId);

    return surveyStudents.any((s) {
      final sid = s['students_id'];
      if (sid is Map) {
        final sidValue = sid['id'];
        if (studentIdNum != null && sidValue is int) {
          return sidValue == studentIdNum;
        }
        return sidValue?.toString() == studentId;
      }
      if (studentIdNum != null && sid is int) {
        return sid == studentIdNum;
      }
      return sid?.toString() == studentId;
    });
  }

  /// Filter all surveys by student eligibility
  /// Returns list of eligible surveys with their targets (class/office info)
  ///
  /// IMPORTANT: This matches the Vue.js web app logic where students MUST be
  /// in the survey's students junction table (enforces student_percentage setting)
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

    // Track added evaluations to prevent duplicates
    final addedEvaluationKeys = <String>{};

    log('EligibilityService: Student $studentId enrolled in ${enrolledClasses.length} classes',
        name: 'EligibilityService');
    log('EligibilityService: Enrolled class IDs: $enrolledClassIds',
        name: 'EligibilityService');
    log('EligibilityService: Student year level: $studentYearLevel',
        name: 'EligibilityService');
    log('EligibilityService: Processing ${allSurveys.length} surveys',
        name: 'EligibilityService');

    for (final survey in allSurveys) {
      final surveyId = survey['id']?.toString();
      final evaluationType =
          (survey['evaluation_type'] ?? 'class').toString().toLowerCase();

      log('EligibilityService: Survey "${survey['title']}" type: $evaluationType',
          name: 'EligibilityService');

      // CRITICAL: Student must be in the survey's students junction table
      // This enforces the student_percentage assignment setting (matches Vue.js app)
      final isAssigned = _isStudentAssignedToSurvey(
        studentId: studentId,
        survey: survey,
      );

      if (!isAssigned) {
        log('EligibilityService: Skipping survey "${survey['title']}" - student not in assigned students list',
            name: 'EligibilityService');
        continue;
      }

      if (evaluationType == 'class') {
        // Class-based survey: student must be assigned AND enrolled in survey's classes
        final surveyClasses = survey['classes'] as List? ?? [];

        log('EligibilityService: Survey "${survey['title']}" has ${surveyClasses.length} classes',
            name: 'EligibilityService');

        // Extract survey class IDs and their course IDs (with deduplication like Vue.js app)
        final surveyClassIds = <String>{};
        final classIdToCourseId = <String, String>{}; // Map class ID to course ID
        for (final surveyClass in surveyClasses) {
          final classData = surveyClass['classes_id'];
          String? classId;
          String? courseId;

          if (classData is Map) {
            classId = classData['id']?.toString();
            // Extract course ID from class data
            final courseData = classData['course_id'];
            if (courseData is Map) {
              courseId = courseData['id']?.toString();
            } else if (courseData != null) {
              courseId = courseData.toString();
            }
          } else if (classData != null) {
            classId = classData.toString();
          }

          if (classId != null) {
            surveyClassIds.add(classId);
            if (courseId != null) {
              classIdToCourseId[classId] = courseId;
            }
          }
        }

        log('EligibilityService: Survey class IDs: $surveyClassIds',
            name: 'EligibilityService');

        // Check for fair distribution: student_course_assignments
        // This field contains which courses each student is specifically assigned to evaluate
        final studentCourseAssignments = survey['student_course_assignments'] as List?;
        Set<String>? assignedCourseIds;

        if (studentCourseAssignments != null && studentCourseAssignments.isNotEmpty) {
          // Find this student's course assignments
          final studentIdNum = int.tryParse(studentId);
          for (final assignment in studentCourseAssignments) {
            final assignmentStudentId = assignment['studentId'];
            final matches = (studentIdNum != null && assignmentStudentId == studentIdNum) ||
                assignmentStudentId?.toString() == studentId;

            if (matches) {
              final courseIds = assignment['courseIds'] as List? ?? [];
              assignedCourseIds = courseIds.map((id) => id.toString()).toSet();
              log('EligibilityService: Fair distribution - student assigned to courses: $assignedCourseIds',
                  name: 'EligibilityService');
              break;
            }
          }

          // If fair distribution exists but student has no assignments, skip
          if (assignedCourseIds == null) {
            log('EligibilityService: Skipping survey "${survey['title']}" - student has no course assignments in fair distribution',
                name: 'EligibilityService');
            continue;
          }
        }

        // Find matching classes (student enrolled AND in survey AND assigned via fair distribution)
        for (final enrolledClass in enrolledClasses) {
          final classId = enrolledClass['id']?.toString();

          if (classId != null && surveyClassIds.contains(classId)) {
            // If fair distribution is active, check if this class's course is assigned
            if (assignedCourseIds != null) {
              // Get course ID from enrolled class or from our mapping
              String? classCourseId;
              final enrolledCourseData = enrolledClass['course_id'];
              if (enrolledCourseData is Map) {
                classCourseId = enrolledCourseData['id']?.toString();
              } else if (enrolledCourseData != null) {
                classCourseId = enrolledCourseData.toString();
              }
              // Fallback to mapping from survey data
              classCourseId ??= classIdToCourseId[classId];

              if (classCourseId == null || !assignedCourseIds.contains(classCourseId)) {
                log('EligibilityService: Skipping class $classId - course $classCourseId not in assigned courses',
                    name: 'EligibilityService');
                continue;
              }
            }

            // Create unique key to prevent duplicates
            final evaluationKey = 'class-$surveyId-$classId';

            if (addedEvaluationKeys.contains(evaluationKey)) {
              continue;
            }
            addedEvaluationKeys.add(evaluationKey);

            log('EligibilityService: Adding eligible class evaluation for class $classId',
                name: 'EligibilityService');

            final eligibleSurvey = Map<String, dynamic>.from(survey);
            eligibleSurvey['target_type'] = 'class';
            eligibleSurvey['target_class_id'] = classId;
            eligibleSurvey['target_class'] = enrolledClass;

            eligibleSurveys.add(eligibleSurvey);
          }
        }
      } else if (evaluationType == 'office') {
        // Office-based survey: student must be assigned AND office must exist
        final office = survey['office_id'];

        if (office == null) {
          log('EligibilityService: Skipping office survey "${survey['title']}" - no office assigned',
              name: 'EligibilityService');
          continue;
        }

        final officeId = office is Map ? office['id']?.toString() : office.toString();

        // Create unique key to prevent duplicates
        final evaluationKey = 'office-$surveyId-$officeId';

        if (addedEvaluationKeys.contains(evaluationKey)) {
          continue;
        }
        addedEvaluationKeys.add(evaluationKey);

        log('EligibilityService: Adding eligible office evaluation for office $officeId',
            name: 'EligibilityService');

        final eligibleSurvey = Map<String, dynamic>.from(survey);
        eligibleSurvey['target_type'] = 'office';
        eligibleSurvey['target_office'] = office;
        eligibleSurveys.add(eligibleSurvey);
      }
    }

    log('EligibilityService: Found ${eligibleSurveys.length} eligible evaluations',
        name: 'EligibilityService');

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
