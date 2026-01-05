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
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      // Success icon
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_circle,
                          size: 64,
                          color: AppColors.success,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Survey Submitted',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Your response has been recorded',
                        style: TextStyle(
                          fontSize: 15,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 32),

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
                            // Header
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceGreen,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(15),
                                  topRight: Radius.circular(15),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryGreen
                                          .withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.receipt_long,
                                      color: AppColors.primaryGreen,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Text(
                                      'Details',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primaryGreen,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Details
                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                children: [
                                  _buildDetailRow(
                                    label: 'Reference No.',
                                    value: referenceId,
                                    isHighlighted: true,
                                  ),
                                  const Divider(height: 24),
                                  _buildDetailRow(
                                    label: 'Survey',
                                    value: surveyTitle,
                                  ),
                                  const SizedBox(height: 16),
                                  _buildDetailRow(
                                    label: 'Type',
                                    value: evaluationType == 'class'
                                        ? 'Class Evaluation'
                                        : 'Office Evaluation',
                                  ),
                                  if (evaluationType == 'class' &&
                                      className != null) ...[
                                    const SizedBox(height: 16),
                                    _buildDetailRow(
                                      label: 'Class',
                                      value: className!,
                                    ),
                                  ],
                                  if (evaluationType == 'class' &&
                                      teacherName != null) ...[
                                    const SizedBox(height: 16),
                                    _buildDetailRow(
                                      label: 'Instructor',
                                      value: teacherName!,
                                    ),
                                  ],
                                  if (evaluationType == 'office' &&
                                      officeName != null) ...[
                                    const SizedBox(height: 16),
                                    _buildDetailRow(
                                      label: 'Office',
                                      value: officeName!,
                                    ),
                                  ],
                                  if (questionsAnswered > 0) ...[
                                    const SizedBox(height: 16),
                                    _buildDetailRow(
                                      label: 'Questions Answered',
                                      value: questionsAnswered.toString(),
                                    ),
                                  ],
                                  const SizedBox(height: 16),
                                  _buildDetailRow(
                                    label: 'Submitted',
                                    value: _formatDateTime(submittedAt),
                                  ),
                                ],
                              ),
                            ),

                            // Footer
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
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
                                    size: 16,
                                    color: AppColors.success,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Recorded',
                                    style: TextStyle(
                                      fontSize: 13,
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

              const SizedBox(height: 16),

              // Done button
              SizedBox(
                width: double.infinity,
                height: 52,
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

  Widget _buildDetailRow({
    required String label,
    required String value,
    bool isHighlighted = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: isHighlighted ? 15 : 14,
              fontWeight: isHighlighted ? FontWeight.w700 : FontWeight.w500,
              color: isHighlighted
                  ? AppColors.primaryGreen
                  : AppColors.textPrimary,
              fontFamily: isHighlighted ? 'monospace' : null,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
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

    return '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year} '
        'at ${displayHour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')} $period';
  }
}
