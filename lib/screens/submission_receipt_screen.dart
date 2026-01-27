import 'package:flutter/material.dart';
import '../main.dart';

class SubmissionReceiptScreen extends StatelessWidget {
  final String surveyTitle;
  final String referenceId;
  final DateTime submittedAt;
  final int questionsAnswered;
  final String? className;
  final String? teacherName;
  final String? officeName;
  final String evaluationType;

  // Student information
  final String? studentName;
  final String? studentId;
  final String? studentProgram;

  const SubmissionReceiptScreen({
    super.key,
    required this.surveyTitle,
    required this.referenceId,
    required this.submittedAt,
    required this.questionsAnswered,
    this.className,
    this.teacherName,
    this.officeName,
    required this.evaluationType,
    this.studentName,
    this.studentId,
    this.studentProgram,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Confirmation'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Success header row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_circle,
                              size: 28,
                              color: AppColors.success,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Survey Submitted',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const Text(
                                'Your response has been recorded',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Receipt card
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Column(
                          children: [
                            // Reference Number Header
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14, horizontal: 16),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceGreen,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(15),
                                  topRight: Radius.circular(15),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    'Reference No.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '#$referenceId',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primaryGreen,
                                      fontFamily: 'monospace',
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Student Information Section
                            if (studentName != null ||
                                studentId != null ||
                                studentProgram != null)
                              _buildSection(
                                title: 'STUDENT INFORMATION',
                                icon: Icons.person_outline,
                                children: [
                                  if (studentName != null)
                                    _buildInfoRow('Name', studentName!),
                                  if (studentId != null)
                                    _buildInfoRow('Student ID', studentId!),
                                  if (studentProgram != null)
                                    _buildInfoRow('Program', studentProgram!),
                                ],
                              ),

                            // Survey Information Section
                            _buildSection(
                              title: 'SURVEY INFORMATION',
                              icon: Icons.assignment_outlined,
                              children: [
                                _buildInfoRow('Survey', surveyTitle),
                                _buildInfoRow(
                                  'Type',
                                  evaluationType == 'class'
                                      ? 'Class Evaluation'
                                      : 'Office Evaluation',
                                ),
                                if (evaluationType == 'class' &&
                                    className != null)
                                  _buildInfoRow('Course', className!),
                                if (evaluationType == 'class' &&
                                    teacherName != null &&
                                    teacherName!.isNotEmpty)
                                  _buildInfoRow('Instructor', teacherName!),
                                if (evaluationType == 'office' &&
                                    officeName != null)
                                  _buildInfoRow('Office', officeName!),
                                if (questionsAnswered > 0)
                                  _buildInfoRow('Questions Answered',
                                      questionsAnswered.toString()),
                                _buildInfoRow(
                                    'Submitted At', _formatDateTime(submittedAt)),
                              ],
                            ),

                            // Footer
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 16),
                              decoration: BoxDecoration(
                                color: AppColors.inputFill,
                                borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(15),
                                  bottomRight: Radius.circular(15),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.verified,
                                    size: 14,
                                    color: AppColors.success,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Response Recorded',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.success,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Done button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Row(
            children: [
              Icon(
                icon,
                size: 14,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),

        // Section content
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
          child: Column(
            children: children,
          ),
        ),

        // Divider
        const Divider(height: 1, indent: 16, endIndent: 16),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final hour = dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour;
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : hour;

    return '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year}, '
        '${displayHour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')} $period';
  }
}
