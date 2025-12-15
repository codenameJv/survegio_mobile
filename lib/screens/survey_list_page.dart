import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/survey_service.dart';
import '../services/eligibility_service.dart';
import './survey_taking_screen.dart';

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
        _surveyService.fetchStudentDepartment(_studentId!),
      ]);

      final allSurveys = results[0] as List<Map<String, dynamic>>;
      final enrolledClasses = results[1] as List<Map<String, dynamic>>;
      final completedResponses = results[2] as List<Map<String, dynamic>>;
      final department = results[3] as Map<String, dynamic>?;

      // Get eligible surveys with eligibility filtering
      final eligibleSurveys = await _eligibilityService.getEligibleSurveys(
        studentId: _studentId!,
        allSurveys: allSurveys,
        enrolledClasses: enrolledClasses,
        studentDepartmentId: department?['id']?.toString(),
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
          color: Theme.of(context).scaffoldBackgroundColor,
          child: TabBar(
            controller: _tabController,
            labelColor: Colors.green.shade700,
            unselectedLabelColor: Colors.grey.shade600,
            indicatorColor: Colors.green.shade700,
            indicatorWeight: 3,
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
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_pendingSurveys.length}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade700,
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
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_completedSurveys.length}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
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
                  child: CircularProgressIndicator(color: Colors.green))
              : _errorMessage != null
                  ? _buildErrorView()
                  : RefreshIndicator(
                      onRefresh: _loadSurveys,
                      color: Colors.green,
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
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: _loadSurveys,
              child: const Text('Retry'),
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
            Icon(
              isPending ? Icons.inbox_outlined : Icons.check_circle_outline,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              isPending ? 'No pending surveys' : 'No completed surveys yet',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isPending
                  ? "You're all caught up!"
                  : 'Complete surveys to see them here',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: surveys.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final survey = surveys[index];
        return _buildSurveyCard(survey, isCompleted: !isPending);
      },
    );
  }

  Widget _buildSurveyCard(Map<String, dynamic> survey,
      {required bool isCompleted}) {
    final title = survey['title'] ?? 'Untitled Survey';
    final instruction = survey['instruction'] ?? '';
    final targetType = survey['target_type'] ?? '';

    // Build subtitle based on target type
    String subtitle = '';
    String? teacherId;
    if (targetType == 'class') {
      final targetClass = survey['target_class'];
      final section = targetClass?['section'] ?? '';
      final course = targetClass?['course_id']?['courseCode'] ?? '';
      final teacher = targetClass?['teacher_id'];
      teacherId = teacher?['id']?.toString();
      final teacherName = teacher != null
          ? '${teacher['first_name'] ?? ''} ${teacher['last_name'] ?? ''}'.trim()
          : '';
      subtitle =
          '$course $section${teacherName.isNotEmpty ? ' - $teacherName' : ''}';
    } else if (targetType == 'office') {
      final office = survey['target_office'];
      subtitle = office?['name'] ?? 'Office Evaluation';
    }

    // Get completion info if completed
    String? completedAt;
    if (isCompleted && survey['response'] != null) {
      final response = survey['response'] as Map<String, dynamic>;
      final submittedAt = response['submitted_at'];
      if (submittedAt != null) {
        try {
          final date = DateTime.parse(submittedAt);
          completedAt =
              '${date.month}/${date.day}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
        } catch (_) {}
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          if (!isCompleted) {
            // Navigate to survey taking screen
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SurveyTakingScreen(
                  surveyId: survey['id'].toString(),
                  surveyTitle: title,
                  classId: survey['target_class_id']?.toString(),
                  officeId: survey['target_office']?['id']?.toString(),
                  evaluatedTeacherId: teacherId,
                ),
              ),
            );

            // Refresh list if survey was submitted
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
                  // Icon
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: isCompleted
                        ? Colors.green.shade100
                        : (targetType == 'class'
                            ? Colors.blue.shade100
                            : Colors.purple.shade100),
                    child: Icon(
                      isCompleted
                          ? Icons.check
                          : (targetType == 'class'
                              ? Icons.class_
                              : Icons.business),
                      color: isCompleted
                          ? Colors.green.shade700
                          : (targetType == 'class'
                              ? Colors.blue.shade700
                              : Colors.purple.shade700),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Title and subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
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
                    Icon(Icons.chevron_right, color: Colors.grey.shade400),
                ],
              ),

              // Instruction preview
              if (instruction.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  instruction,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              const SizedBox(height: 12),

              // Status row
              Row(
                children: [
                  // Type badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: targetType == 'class'
                          ? Colors.blue.shade50
                          : Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      targetType == 'class' ? 'Class' : 'Office',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: targetType == 'class'
                            ? Colors.blue.shade700
                            : Colors.purple.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Status badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? Colors.green.shade50
                          : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isCompleted ? 'Completed' : 'Pending',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isCompleted
                            ? Colors.green.shade700
                            : Colors.orange.shade700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Completed date
                  if (completedAt != null)
                    Text(
                      completedAt,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
