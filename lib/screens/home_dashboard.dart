import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../services/auth_service.dart';
import '../services/survey_service.dart';
import '../services/eligibility_service.dart';
import './survey_taking_screen.dart';

class HomeDashboard extends StatefulWidget {
  final Map<String, dynamic>? user;
  const HomeDashboard({super.key, required this.user});

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  late SurveyService _surveyService;
  late EligibilityService _eligibilityService;

  bool _isLoading = true;
  String? _errorMessage;

  Map<String, dynamic>? _currentTerm;
  Map<String, dynamic> _stats = {
    'total': 0,
    'pending': 0,
    'completed': 0,
    'completionRate': 0,
  };
  List<Map<String, dynamic>> _activeSurveys = [];
  List<Map<String, dynamic>> _recentActivity = [];

  @override
  void initState() {
    super.initState();
    final token = Provider.of<AuthService>(context, listen: false).token;
    _surveyService = SurveyService(token);
    _eligibilityService = EligibilityService(token);
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Try different ways to get student ID
      var studentId = widget.user?['student']?['id']?.toString();

      // If student is not an object, it might be just the ID directly
      if (studentId == null) {
        final studentField = widget.user?['student'];
        if (studentField != null && studentField is! Map) {
          studentId = studentField.toString();
        }
      }

      // Also check student_id field
      if (studentId == null) {
        studentId = widget.user?['student_id']?.toString();
      }

      if (studentId == null) {
        setState(() {
          _errorMessage =
              'Student information not found. Please check that your account is linked to a student record.';
          _isLoading = false;
        });
        return;
      }

      // Fetch all data in parallel
      final results = await Future.wait([
        _surveyService.fetchCurrentAcademicTerm(),
        _surveyService.fetchStudentEvaluationSurveys(),
        _surveyService.fetchStudentClasses(studentId),
        _surveyService.fetchStudentSurveyResponses(studentId),
        _surveyService.fetchStudentInfo(studentId),
        _surveyService.fetchRecentActivity(studentId),
      ]);

      final currentTerm = results[0] as Map<String, dynamic>?;
      final allSurveys = results[1] as List<Map<String, dynamic>>;
      final enrolledClasses = results[2] as List<Map<String, dynamic>>;
      final completedResponses = results[3] as List<Map<String, dynamic>>;
      final studentInfo = results[4] as Map<String, dynamic>?;
      final recentActivity = results[5] as List<Map<String, dynamic>>;

      final department = studentInfo?['deparment_id'];
      final yearLevel = studentInfo?['year_level']?.toString();

      // Get eligible surveys
      final eligibleSurveys = await _eligibilityService.getEligibleSurveys(
        studentId: studentId,
        allSurveys: allSurveys,
        enrolledClasses: enrolledClasses,
        studentDepartmentId: department?['id']?.toString(),
        studentYearLevel: yearLevel,
      );

      // Get pending surveys
      final pendingSurveys =
          await _eligibilityService.getPendingEligibleSurveys(
        studentId: studentId,
        eligibleSurveys: eligibleSurveys,
        completedResponses: completedResponses,
      );

      // Calculate stats - only count responses for eligible surveys
      final eligibleSurveyIds = eligibleSurveys
          .map((s) => s['id']?.toString())
          .where((id) => id != null)
          .toSet();
      final completedForEligible = completedResponses
          .where((r) => eligibleSurveyIds.contains(r['survey_id']?.toString()))
          .length;
      final total = eligibleSurveys.length;
      final completed = completedForEligible;
      final pending = pendingSurveys.length;
      final completionRate =
          total > 0 ? ((completed / total) * 100).clamp(0, 100).round() : 0;

      setState(() {
        _currentTerm = currentTerm;
        _stats = {
          'total': total,
          'pending': pending,
          'completed': completed,
          'completionRate': completionRate,
        };
        _activeSurveys = pendingSurveys.take(5).toList();
        _recentActivity = recentActivity;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load dashboard data: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final String firstName = widget.user?['first_name'] ?? 'User';

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryGreen),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
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
                onPressed: _loadDashboardData,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      color: AppColors.primaryGreen,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildGreetingHeader(firstName),
          const SizedBox(height: 24),

          // Academic Term Card
          if (_currentTerm != null) ...[
            _buildAcademicTermCard(),
            const SizedBox(height: 24),
          ],

          // Stats Cards
          _buildStatsSection(),
          const SizedBox(height: 28),

          // Active Surveys Section
          _buildActiveSurveysSection(),
          const SizedBox(height: 28),

          // Recent Activity Section
          _buildRecentActivitySection(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildGreetingHeader(String firstName) {
    final hour = DateTime.now().hour;
    String greeting;
    if (hour < 12) {
      greeting = 'Good morning';
    } else if (hour < 17) {
      greeting = 'Good afternoon';
    } else {
      greeting = 'Good evening';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$greeting,',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          firstName,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildAcademicTermCard() {
    final semester = _currentTerm?['semester'] ?? '';
    final schoolYear = _currentTerm?['schoolYear'] ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceGreen,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryGreen.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.school_outlined,
              color: AppColors.primaryGreen,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Current Academic Term',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.primaryGreen,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$semester - $schoolYear',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Overview',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'Total',
                value: '${_stats['total']}',
                icon: Icons.assignment_outlined,
                color: AppColors.info,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                title: 'Pending',
                value: '${_stats['pending']}',
                icon: Icons.pending_actions_outlined,
                color: AppColors.warning,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                title: 'Done',
                value: '${_stats['completed']}',
                icon: Icons.check_circle_outline,
                color: AppColors.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildCompletionRateCard(),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionRateCard() {
    final rate = _stats['completionRate'] as int;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Completion Rate',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surfaceGreen,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$rate%',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryGreen,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: rate / 100,
              minHeight: 8,
              backgroundColor: AppColors.divider,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveSurveysSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Pending Surveys',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            if (_activeSurveys.isNotEmpty)
              TextButton(
                onPressed: () {
                  // Navigate to surveys tab
                },
                child: const Text('View All'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_activeSurveys.isEmpty)
          _buildEmptyState()
        else
          ...(_activeSurveys.map((survey) => _buildSurveyCard(survey))),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceGreen,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_outline,
              size: 40,
              color: AppColors.primaryGreen,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Pending Surveys',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'You have completed all available surveys.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSurveyCard(Map<String, dynamic> survey) {
    final title = survey['title'] ?? 'Untitled Survey';
    final targetType = survey['target_type'] ?? '';
    final targetClass = survey['target_class'] as Map<String, dynamic>?;

    String subtitle = '';
    if (targetType == 'class') {
      final section = targetClass?['section'] ?? '';
      final course = targetClass?['course_id']?['courseCode'] ?? '';
      final teacher = targetClass?['teacher_id'];
      final teacherName = teacher != null
          ? '${teacher['first_name'] ?? ''} ${teacher['last_name'] ?? ''}'
              .trim()
          : '';
      subtitle =
          '$course $section${teacherName.isNotEmpty ? ' - $teacherName' : ''}';
    } else if (targetType == 'office') {
      final office = survey['target_office'];
      subtitle = office?['name'] ?? 'Office Evaluation';
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
          onTap: () async {
            // Get teacher info for receipt
            final teacher = targetClass?['teacher_id'];
            final teacherFullName = teacher != null
                ? '${teacher['first_name'] ?? ''} ${teacher['last_name'] ?? ''}'
                    .trim()
                : null;
            final teacherId = teacher?['id']?.toString();

            // Get office name
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
              _loadDashboardData();
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 50,
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isClass ? Icons.class_outlined : Icons.business_outlined,
                    color: accentColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isClass ? 'Class' : 'Office',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: accentColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentActivitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Activity',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        if (_recentActivity.isEmpty)
          _buildRecentActivityEmptyState()
        else
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              children: _recentActivity.asMap().entries.map((entry) {
                final index = entry.key;
                final activity = entry.value;
                final isLast = index == _recentActivity.length - 1;
                return _buildRecentActivityItem(activity, isLast);
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildRecentActivityEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.divider.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.inbox_outlined,
              size: 40,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No recent activity',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your completed surveys will appear here.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivityItem(Map<String, dynamic> activity, bool isLast) {
    final surveyTitle = activity['surveyTitle'] ?? 'Survey';
    final submittedAt = activity['submittedAt'];

    String formattedDate = '';
    if (submittedAt != null) {
      try {
        final date = DateTime.parse(submittedAt);
        formattedDate =
            '${_getMonthName(date.month)} ${date.day}, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      } catch (_) {
        formattedDate = submittedAt.toString();
      }
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.check_circle_outline,
                  color: AppColors.success,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      surveyTitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Completed survey',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (formattedDate.isNotEmpty)
                Text(
                  formattedDate,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
        if (!isLast) const Divider(height: 1, indent: 16, endIndent: 16),
      ],
    );
  }

  String _getMonthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }
}
