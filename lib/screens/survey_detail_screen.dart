import 'package:flutter/material.dart';
import 'survey_taking_screen.dart';

class SurveyDetailScreen extends StatelessWidget {
  final Map<String, dynamic> survey;
  final bool isCompleted;

  const SurveyDetailScreen({
    super.key,
    required this.survey,
    this.isCompleted = false,
  });

  @override
  Widget build(BuildContext context) {
    final title = survey['title'] ?? 'Untitled Survey';
    final instruction = survey['instruction'] ?? '';
    final targetType = survey['target_type'] ?? '';

    // Build target info based on type
    String targetInfo = '';
    String? teacherId;
    if (targetType == 'class') {
      final targetClass = survey['target_class'];
      final section = targetClass?['section'] ?? '';
      final course = targetClass?['course_id']?['courseCode'] ?? '';
      final courseName = targetClass?['course_id']?['courseName'] ?? '';
      final teacher = targetClass?['teacher_id'];
      teacherId = teacher?['id']?.toString();
      final teacherName = teacher != null
          ? '${teacher['first_name'] ?? ''} ${teacher['last_name'] ?? ''}'.trim()
          : '';
      targetInfo = '$course $section';
      if (courseName.isNotEmpty) {
        targetInfo += '\n$courseName';
      }
      if (teacherName.isNotEmpty) {
        targetInfo += '\nInstructor: $teacherName';
      }
    } else if (targetType == 'office') {
      final office = survey['target_office'];
      targetInfo = office?['name'] ?? 'Office Evaluation';
    }

    // Get completion info
    String? completedAt;
    if (isCompleted && survey['response'] != null) {
      final response = survey['response'] as Map<String, dynamic>;
      final submittedAt = response['submitted_at'];
      if (submittedAt != null) {
        try {
          final date = DateTime.parse(submittedAt);
          completedAt =
              '${_getMonthName(date.month)} ${date.day}, ${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
        } catch (_) {}
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Survey Details'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status badge
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? Colors.green.shade100
                        : Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isCompleted ? Icons.check_circle : Icons.pending,
                        size: 16,
                        color: isCompleted
                            ? Colors.green.shade700
                            : Colors.orange.shade700,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isCompleted ? 'Completed' : 'Pending',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isCompleted
                              ? Colors.green.shade700
                              : Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: targetType == 'class'
                        ? Colors.blue.shade100
                        : Colors.purple.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        targetType == 'class' ? Icons.class_ : Icons.business,
                        size: 16,
                        color: targetType == 'class'
                            ? Colors.blue.shade700
                            : Colors.purple.shade700,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        targetType == 'class' ? 'Class' : 'Office',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: targetType == 'class'
                              ? Colors.blue.shade700
                              : Colors.purple.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Survey Title Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (instruction.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        instruction,
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey.shade700,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Target Info Card
            if (targetInfo.isNotEmpty)
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            targetType == 'class'
                                ? Icons.school
                                : Icons.business,
                            color: Colors.green.shade700,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            targetType == 'class'
                                ? 'Evaluation Target'
                                : 'Office',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        targetInfo,
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey.shade700,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Completion Info for completed surveys
            if (isCompleted && completedAt != null) ...[
              const SizedBox(height: 16),
              Card(
                elevation: 2,
                color: Colors.green.shade50,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green.shade700),
                          const SizedBox(width: 10),
                          const Text(
                            'Submission Details',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Submitted on $completedAt',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Thank you for completing this evaluation!',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: isCompleted
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SurveyTakingScreen(
                          surveyId: survey['id'].toString(),
                          surveyTitle: title,
                          classId: survey['target_class_id']?.toString(),
                          officeId:
                              survey['target_office']?['id']?.toString(),
                          evaluatedTeacherId: teacherId,
                        ),
                      ),
                    );

                    // If survey was submitted, pop this screen too
                    if (result == true && context.mounted) {
                      Navigator.of(context).pop(true);
                    }
                  },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    'Start Evaluation',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return months[month - 1];
  }
}
