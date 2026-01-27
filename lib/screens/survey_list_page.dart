import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../services/auth_service.dart';
import '../services/survey_service.dart';
import '../services/eligibility_service.dart';
import './survey_taking_screen.dart';
import './submission_receipt_screen.dart';

class SurveyListScreen extends StatefulWidget {
  const SurveyListScreen({super.key});

  @override
  State<SurveyListScreen> createState() => _SurveyListScreenState();
}

class _SurveyListScreenState extends State<SurveyListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late SurveyService _surveyService;
  late EligibilityService _eligibilityService;

  bool _isLoading = true;
  String? _errorMessage;
  String? _studentId;

  List<Map<String, dynamic>> _pendingSurveys = [];
  List<Map<String, dynamic>> _completedSurveys = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    final authService = Provider.of<AuthService>(context, listen: false);
    _surveyService = SurveyService(authService.token);
    _eligibilityService = EligibilityService(authService.token);
    _studentId = authService.currentUser?['student']?['id']?.toString();

    _loadSurveys();
  }

  Future<void> _loadSurveys() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_studentId == null) {
        setState(() {
          _errorMessage = 'Student information not found.';
          _isLoading = false;
        });
        return;
      }

      // Fetch all data in parallel
      final results = await Future.wait([
        _surveyService.fetchStudentEvaluationSurveys(),
        _surveyService.fetchStudentClasses(_studentId!),
        _surveyService.fetchStudentSurveyResponses(_studentId!),
        _surveyService.fetchStudentInfo(_studentId!),
      ]);

      final allSurveys = results[0] as List<Map<String, dynamic>>;
      final enrolledClasses = results[1] as List<Map<String, dynamic>>;
      final completedResponses = results[2] as List<Map<String, dynamic>>;
      final studentInfo = results[3] as Map<String, dynamic>?;

      final department = studentInfo?['deparment_id'];
      final yearLevel = studentInfo?['year_level']?.toString();

      // Get eligible surveys with eligibility filtering
      final eligibleSurveys = await _eligibilityService.getEligibleSurveys(
        studentId: _studentId!,
        allSurveys: allSurveys,
        enrolledClasses: enrolledClasses,
        studentDepartmentId: department?['id']?.toString(),
        studentYearLevel: yearLevel,
      );

      // Separate into pending and completed
      final pending = await _eligibilityService.getPendingEligibleSurveys(
        studentId: _studentId!,
        eligibleSurveys: eligibleSurveys,
        completedResponses: completedResponses,
      );

      final completed = _eligibilityService.getCompletedEligibleSurveys(
        eligibleSurveys: eligibleSurveys,
        completedResponses: completedResponses,
      );

      setState(() {
        _pendingSurveys = pending;
        _completedSurveys = completed;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load surveys: $e';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Tab Bar
        Container(
          margin: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          decoration: BoxDecoration(
            color: AppColors.inputFill,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: AppColors.surface,
            unselectedLabelColor: AppColors.textSecondary,
            indicator: BoxDecoration(
              color: AppColors.primaryGreen,
              borderRadius: BorderRadius.circular(10),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            padding: const EdgeInsets.all(4),
            labelPadding: EdgeInsets.zero,
            tabs: [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Pending'),
                    if (_pendingSurveys.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withAlpha(51),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_pendingSurveys.length}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.warning,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Completed'),
                    if (_completedSurveys.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.success.withAlpha(51),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_completedSurveys.length}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.success,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),

        // Tab Bar View
        Expanded(
          child: _isLoading
              ? const Center(
                  child:
                      CircularProgressIndicator(color: AppColors.primaryGreen))
              : _errorMessage != null
                  ? _buildErrorView()
                  : RefreshIndicator(
                      onRefresh: _loadSurveys,
                      color: AppColors.primaryGreen,
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildSurveyList(_pendingSurveys, isPending: true),
                          _buildSurveyList(_completedSurveys, isPending: false),
                        ],
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.error.withAlpha(26),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                size: 48,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _loadSurveys,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSurveyList(List<Map<String, dynamic>> surveys,
      {required bool isPending}) {
    if (surveys.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isPending
                    ? AppColors.surfaceGreen
                    : AppColors.success.withAlpha(26),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPending
                    ? Icons.inbox_outlined
                    : Icons.check_circle_outline,
                size: 48,
                color: isPending ? AppColors.primaryGreen : AppColors.success,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isPending ? 'No Pending Surveys' : 'No Completed Surveys',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isPending
                  ? 'You have completed all available surveys.'
                  : 'Completed surveys will appear here.',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: surveys.length,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemBuilder: (context, index) {
        final survey = surveys[index];
        return _buildSurveyCard(survey, isCompleted: !isPending);
      },
    );
  }

  Widget _buildSurveyCard(Map<String, dynamic> survey,
      {required bool isCompleted}) {
    final title = survey['title'] ?? 'Untitled Survey';
    final targetType = survey['target_type'] ?? '';

    // Build subtitle based on target type
    String subtitle = '';
    String? teacherId;
    String? teacherFullName;
    if (targetType == 'class') {
      final targetClass = survey['target_class'];
      final section = targetClass?['section'] ?? '';
      final course = targetClass?['course_id']?['courseCode'] ?? '';
      final teacher = targetClass?['teacher_id'];
      teacherId = teacher?['id']?.toString();
      teacherFullName = teacher != null
          ? '${teacher['first_name'] ?? ''} ${teacher['last_name'] ?? ''}'.trim()
          : null;
      subtitle =
          '$course $section${teacherFullName != null && teacherFullName.isNotEmpty ? ' - $teacherFullName' : ''}';
    } else if (targetType == 'office') {
      final office = survey['target_office'];
      subtitle = office?['name'] ?? 'Office Evaluation';
    }

    // Get deadline info
    String? deadlineText;
    bool isUrgent = false;
    final surveyEnd = survey['survey_end'];
    if (surveyEnd != null && !isCompleted) {
      try {
        final endDate = DateTime.parse(surveyEnd);
        final now = DateTime.now();
        final daysLeft = endDate.difference(now).inDays;

        if (daysLeft < 0) {
          deadlineText = 'Expired';
          isUrgent = true;
        } else if (daysLeft == 0) {
          deadlineText = 'Due today';
          isUrgent = true;
        } else if (daysLeft == 1) {
          deadlineText = 'Due tomorrow';
          isUrgent = true;
        } else if (daysLeft <= 3) {
          deadlineText = 'Due in $daysLeft days';
          isUrgent = true;
        } else {
          deadlineText = 'Due ${_formatDate(endDate)}';
        }
      } catch (_) {}
    }

    // Get completion info if completed
    String? completedAt;
    String? responseId;
    if (isCompleted && survey['response'] != null) {
      final response = survey['response'] as Map<String, dynamic>;
      responseId = response['id']?.toString();
      final submittedAt = response['submitted_at'];
      if (submittedAt != null) {
        try {
          final date = DateTime.parse(submittedAt);
          completedAt = _formatDate(date);
        } catch (_) {}
      }
    }

    final isClass = targetType == 'class';
    final accentColor = isClass ? AppColors.info : const Color(0xFF9C27B0);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            if (isCompleted) {
              // Show receipt for completed survey
              final office = survey['target_office'];
              final response = survey['response'] as Map<String, dynamic>?;
              DateTime? submittedDate;
              if (response?['submitted_at'] != null) {
                try {
                  submittedDate = DateTime.parse(response!['submitted_at']);
                } catch (_) {}
              }

              // Get student information from auth service
              final authService =
                  Provider.of<AuthService>(context, listen: false);
              final currentUser = authService.currentUser;
              final student = currentUser?['student'];
              String? studentName;
              String? studentNumber;
              String? studentProgram;

              if (student is Map<String, dynamic>) {
                final studentFirstName =
                    student['first_name']?.toString() ?? '';
                final studentLastName = student['last_name']?.toString() ?? '';
                studentName = '$studentFirstName $studentLastName'.trim();
                if (studentName.isEmpty) studentName = null;
                studentNumber = student['student_number']?.toString();

                final departmentField = student['deparment_id'];
                if (departmentField is Map<String, dynamic>) {
                  studentProgram = departmentField['name']?.toString();
                }
              }

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SubmissionReceiptScreen(
                    surveyTitle: title,
                    referenceId: responseId ?? 'N/A',
                    submittedAt: submittedDate ?? DateTime.now(),
                    questionsAnswered: 0, // We don't store this
                    className: subtitle.isNotEmpty ? subtitle : null,
                    teacherName: teacherFullName,
                    officeName: office?['name']?.toString(),
                    evaluationType: targetType,
                    studentName: studentName,
                    studentId: studentNumber,
                    studentProgram: studentProgram,
                  ),
                ),
              );
            } else {
              // Open survey for taking
              final office = survey['target_office'];
              final officeFullName = office?['name']?.toString();

              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SurveyTakingScreen(
                    surveyId: survey['id'].toString(),
                    surveyTitle: title,
                    classId: survey['target_class_id']?.toString(),
                    officeId: office?['id']?.toString(),
                    evaluatedTeacherId: teacherId,
                    className: subtitle.isNotEmpty ? subtitle : null,
                    teacherName: teacherFullName,
                    officeName: officeFullName,
                    instruction: survey['instruction']?.toString(),
                  ),
                ),
              );

              if (result == true) {
                _loadSurveys();
              }
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left accent bar
                    Container(
                      width: 4,
                      height: 56,
                      decoration: BoxDecoration(
                        color: isCompleted ? AppColors.success : accentColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Icon
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? AppColors.success.withAlpha(26)
                            : accentColor.withAlpha(26),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isCompleted
                            ? Icons.check
                            : (isClass
                                ? Icons.class_outlined
                                : Icons.business_outlined),
                        color: isCompleted ? AppColors.success : accentColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Title and subtitle
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (subtitle.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Arrow for pending
                    if (!isCompleted)
                      const Icon(
                        Icons.chevron_right,
                        color: AppColors.textSecondary,
                      ),
                  ],
                ),

                const SizedBox(height: 14),

                // Status row
                Padding(
                  padding: const EdgeInsets.only(left: 18),
                  child: Row(
                    children: [
                      // Type badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: accentColor.withAlpha(26),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isClass ? 'Class' : 'Office',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: accentColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Status badge or deadline
                      if (isCompleted)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.success.withAlpha(26),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle,
                                size: 14,
                                color: AppColors.success,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Completed',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.success,
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (deadlineText != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: isUrgent
                                ? AppColors.error.withAlpha(26)
                                : AppColors.warning.withAlpha(26),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.schedule,
                                size: 14,
                                color: isUrgent
                                    ? AppColors.error
                                    : AppColors.warning,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                deadlineText,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isUrgent
                                      ? AppColors.error
                                      : AppColors.warning,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const Spacer(),
                      // Completed date or view receipt hint
                      if (isCompleted) ...[
                        Text(
                          completedAt ?? '',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.receipt_long,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
