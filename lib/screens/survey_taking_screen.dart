import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../services/auth_service.dart';
import '../services/survey_service.dart';
import './data_privacy.dart';
import './submission_receipt_screen.dart';

class SurveyTakingScreen extends StatefulWidget {
  final String surveyId;
  final String surveyTitle;
  final String? classId;
  final String? officeId;
  final String? evaluatedTeacherId;
  final String? className;
  final String? teacherName;
  final String? officeName;
  final String? instruction;

  const SurveyTakingScreen({
    super.key,
    required this.surveyId,
    required this.surveyTitle,
    this.classId,
    this.officeId,
    this.evaluatedTeacherId,
    this.className,
    this.teacherName,
    this.officeName,
    this.instruction,
  });

  @override
  State<SurveyTakingScreen> createState() => _SurveyTakingScreenState();
}

class _SurveyTakingScreenState extends State<SurveyTakingScreen> {
  late final SurveyService _surveyService;
  Future<List<Map<String, dynamic>>>? _questionsFuture;

  bool _hasAgreed = false;
  bool _isSubmitting = false;

  final Map<String, dynamic> _responses = {};

  // Check if this is an office-based evaluation
  bool get isOfficeBased => widget.officeId != null;

  // Rating options for class-based evaluations
  final List<Map<String, dynamic>> _classRatingOptions = [
    {'value': 5, 'label': '5 - Always manifested'},
    {'value': 4, 'label': '4 - Often manifested'},
    {'value': 3, 'label': '3 - Sometimes manifested'},
    {'value': 2, 'label': '2 - Seldom manifested'},
    {'value': 1, 'label': '1 - Never/Rarely manifested'},
  ];

  // Rating options for office-based evaluations
  final List<Map<String, dynamic>> _officeRatingOptions = [
    {'value': 5, 'label': '5 - Outstanding'},
    {'value': 4, 'label': '4 - Very Satisfactory'},
    {'value': 3, 'label': '3 - Satisfactory'},
    {'value': 2, 'label': '2 - Unsatisfactory'},
    {'value': 1, 'label': '1 - Poor'},
  ];

  List<Map<String, dynamic>> get ratingOptions =>
      isOfficeBased ? _officeRatingOptions : _classRatingOptions;

  @override
  void initState() {
    super.initState();
    final token = Provider.of<AuthService>(context, listen: false).token;
    _surveyService = SurveyService(token);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _promptForDataPrivacy();
    });
  }

  Future<void> _promptForDataPrivacy() async {
    final bool agreed = await showDataPrivacyDialog(context);

    if (!mounted) return;

    if (agreed) {
      setState(() {
        _hasAgreed = true;
        _questionsFuture = _surveyService.fetchSurveyQuestions(widget.surveyId);
      });
    } else {
      Navigator.of(context).pop();
    }
  }

  // Group questions by their group_id
  Map<String, List<Map<String, dynamic>>> _groupQuestions(
      List<Map<String, dynamic>> questions) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    final groupOrder = <String, int>{};

    for (final q in questions) {
      final groupInfo = q['group_id'] as Map<String, dynamic>?;
      final groupId = groupInfo?['id']?.toString() ?? 'default';
      final groupNumber = groupInfo?['number'] as int? ?? 0;

      if (!grouped.containsKey(groupId)) {
        grouped[groupId] = [];
        groupOrder[groupId] = groupNumber;
      }
      grouped[groupId]!.add(q);
    }

    // Sort groups by number
    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) => (groupOrder[a] ?? 0).compareTo(groupOrder[b] ?? 0));

    final sortedGrouped = <String, List<Map<String, dynamic>>>{};
    for (final key in sortedKeys) {
      sortedGrouped[key] = grouped[key]!;
    }

    return sortedGrouped;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          widget.surveyTitle,
          style: const TextStyle(fontSize: 16),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => _showExitConfirmation(),
        ),
      ),
      body: _hasAgreed ? _buildQuestionsList() : _buildAgreementPendingView(),
    );
  }

  Future<void> _showExitConfirmation() async {
    if (_responses.isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit Survey?'),
        content: const Text(
            'Your progress will be lost. Are you sure you want to exit?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Exit'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  Widget _buildAgreementPendingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppColors.primaryGreen),
          const SizedBox(height: 20),
          const Text(
            "Awaiting data privacy agreement...",
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionsList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _questionsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primaryGreen),
          );
        }

        if (snapshot.hasError) {
          return _buildErrorView(snapshot.error.toString());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyView();
        }

        final questions = snapshot.data!;
        final groupedQuestions = _groupQuestions(questions);
        final totalQuestions = questions.length;
        final answeredCount = _responses.length;

        return Column(
          children: [
            // Progress bar
            _buildProgressBar(answeredCount, totalQuestions),

            // Questions list
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                children: [
                  // Evaluation target info
                  _buildEvaluationTargetInfo(),

                  // Instructions
                  if (widget.instruction != null &&
                      widget.instruction!.isNotEmpty)
                    _buildInstructionsCard(),

                  // Question groups
                  ...groupedQuestions.entries.map((entry) {
                    final groupQuestions = entry.value;
                    final groupInfo =
                        groupQuestions.first['group_id'] as Map<String, dynamic>?;
                    final groupTitle = groupInfo?['title'] ?? '';

                    return _buildQuestionGroup(groupTitle, groupQuestions);
                  }),

                  // Warning notice
                  _buildWarningNotice(),

                  // Submit button
                  _buildSubmitButton(answeredCount, totalQuestions),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProgressBar(int answered, int total) {
    final progress = total > 0 ? answered / total : 0.0;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.divider),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$answered of $total answered',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: const TextStyle(
                  color: AppColors.primaryGreen,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppColors.divider,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEvaluationTargetInfo() {
    final isOffice = isOfficeBased;

    return Container(
      margin: const EdgeInsets.only(top: 16, bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isOffice ? Icons.business_outlined : Icons.school_outlined,
              color: AppColors.info,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOffice ? 'Office Evaluation' : 'Class Evaluation',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.info,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                if (isOffice && widget.officeName != null)
                  Text(
                    widget.officeName!,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  )
                else if (!isOffice) ...[
                  if (widget.className != null)
                    Text(
                      widget.className!,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  if (widget.teacherName != null &&
                      widget.teacherName!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        widget.teacherName!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionsCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 20,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Instructions',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.instruction!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionGroup(
      String groupTitle, List<Map<String, dynamic>> questions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (groupTitle.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 16),
            child: Text(
              groupTitle,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
        ...questions.asMap().entries.map((entry) {
          final index = entry.key;
          final question = entry.value;
          return _buildQuestionCard(question, index + 1);
        }),
      ],
    );
  }

  Widget _buildQuestionCard(Map<String, dynamic> question, int number) {
    final qId = question["id"].toString();
    final questionText = question["question"] ?? "No question text";
    final groupInfo = question['group_id'] as Map<String, dynamic>?;
    final responseStyle =
        (groupInfo?['response_style'] as String? ?? "").toLowerCase().trim();
    final isAnswered = _responses.containsKey(qId);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isAnswered
              ? AppColors.primaryGreen.withValues(alpha: 0.5)
              : AppColors.divider,
          width: isAnswered ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Question text with number
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isAnswered
                        ? AppColors.primaryGreen
                        : AppColors.surfaceGreen,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$number',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color:
                          isAnswered ? Colors.white : AppColors.primaryGreen,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      questionText,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Answer widget based on response style
            _buildAnswerWidget(qId, questionText, responseStyle),
          ],
        ),
      ),
    );
  }

  Widget _buildAnswerWidget(
      String questionId, String questionText, String responseStyle) {
    if (responseStyle.contains("open") || responseStyle.contains("comment")) {
      return _buildTextAreaWidget(questionId, questionText);
    } else if (responseStyle.contains("yes") || responseStyle.contains("no")) {
      return _buildYesNoWidget(questionId, questionText);
    } else {
      // Default: Rating scale (Likert or Rating)
      return _buildRatingWidget(questionId, questionText);
    }
  }

  Widget _buildRatingWidget(String questionId, String questionText) {
    final currentValue = _responses[questionId]?['answer'];

    return Column(
      children: ratingOptions.map((option) {
        final value = option['value'] as int;
        final label = option['label'] as String;
        final isSelected = currentValue == value;

        return GestureDetector(
          onTap: () {
            setState(() {
              _responses[questionId] = {
                "questionId": questionId,
                "questionText": questionText,
                "answer": value,
                "answerText": label,
                "type": "rating",
              };
            });
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primaryGreen.withValues(alpha: 0.1)
                  : AppColors.inputFill,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? AppColors.primaryGreen : AppColors.divider,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? AppColors.primaryGreen : Colors.transparent,
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primaryGreen
                          : AppColors.textSecondary,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected
                          ? AppColors.primaryGreen
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildYesNoWidget(String questionId, String questionText) {
    final currentValue = _responses[questionId]?['answer'];

    return Row(
      children: ['Yes', 'No'].map((option) {
        final isSelected = currentValue == option;

        return Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _responses[questionId] = {
                  "questionId": questionId,
                  "questionText": questionText,
                  "answer": option,
                  "answerText": option,
                  "type": "yes_no",
                };
              });
            },
            child: Container(
              margin: EdgeInsets.only(right: option == 'Yes' ? 8 : 0),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primaryGreen.withValues(alpha: 0.1)
                    : AppColors.inputFill,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? AppColors.primaryGreen : AppColors.divider,
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? AppColors.primaryGreen : Colors.transparent,
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primaryGreen
                            : AppColors.textSecondary,
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, size: 12, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    option,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected
                          ? AppColors.primaryGreen
                          : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTextAreaWidget(String questionId, String questionText) {
    return TextFormField(
      decoration: InputDecoration(
        hintText: "Type your response here...",
        hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.7)),
        filled: true,
        fillColor: AppColors.inputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2),
        ),
        contentPadding: const EdgeInsets.all(16),
      ),
      maxLines: 4,
      initialValue: _responses[questionId]?['answer'] as String?,
      onChanged: (value) {
        setState(() {
          if (value.isNotEmpty) {
            _responses[questionId] = {
              "questionId": questionId,
              "questionText": questionText,
              "answer": value,
              "answerText": value,
              "type": "open_ended",
            };
          } else {
            _responses.remove(questionId);
          }
        });
      },
    );
  }

  Widget _buildWarningNotice() {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 22,
            color: AppColors.warning,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Important Notice',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Once you submit this evaluation, you will not be able to view or modify your answers. Please review your responses carefully before submitting.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(int answered, int total) {
    final allAnswered = answered == total && total > 0;

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: _isSubmitting ? null : _submitSurvey,
        style: FilledButton.styleFrom(
          backgroundColor:
              allAnswered ? AppColors.primaryGreen : AppColors.textSecondary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isSubmitting
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                allAnswered
                    ? "Submit Evaluation"
                    : "Answer all questions to submit",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Widget _buildErrorView(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
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
              "Error loading questions:\n$error",
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceGreen,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.quiz_outlined,
              size: 48,
              color: AppColors.primaryGreen,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "This survey has no questions.",
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitSurvey() async {
    // Prevent duplicate submissions
    if (_isSubmitting) return;

    if (_responses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Please answer at least one question."),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final studentId = authService.currentUser?['student']?['id']?.toString();

      if (studentId == null) {
        throw Exception('Student ID not found');
      }

      // STEP 1: Create StudentSurveyResponse record
      final responseId = await _surveyService.createSurveyResponse(
        surveyId: widget.surveyId,
        studentId: studentId,
        classId: widget.classId,
        officeId: widget.officeId,
        evaluatedTeacherId: widget.evaluatedTeacherId,
      );

      // STEP 2: Create StudentSurveyAnswers records
      final answers = _responses.values.map((response) {
        return {
          'questionId': response['questionId'],
          'answer': response['answer'],
          'answerText': response['answerText'] ?? response['answer'].toString(),
        };
      }).toList();

      await _surveyService.submitSurveyAnswers(
        responseId: responseId,
        answers: answers,
      );

      if (mounted) {
        // Navigate to receipt screen and wait for result
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => SubmissionReceiptScreen(
              surveyTitle: widget.surveyTitle,
              referenceId: responseId,
              submittedAt: DateTime.now(),
              questionsAnswered: _responses.length,
              className: widget.className,
              teacherName: widget.teacherName,
              officeName: widget.officeName,
              evaluationType: widget.classId != null ? 'class' : 'office',
            ),
          ),
        );

        // Pop back to survey list with success result
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to submit survey: $e"),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }
}
