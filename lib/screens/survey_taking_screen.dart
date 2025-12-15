import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../services/auth_service.dart';
import '../services/survey_service.dart';
import './data_privacy.dart';

class SurveyTakingScreen extends StatefulWidget {
  final String surveyId;
  final String surveyTitle;
  final String? classId;
  final String? officeId;
  final String? evaluatedTeacherId;

  const SurveyTakingScreen({
    super.key,
    required this.surveyId,
    required this.surveyTitle,
    this.classId,
    this.officeId,
    this.evaluatedTeacherId,
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
        _questionsFuture =
            _surveyService.fetchSurveyQuestions(widget.surveyId);
      });
    } else {
      Navigator.of(context).pop();
    }
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
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _hasAgreed ? _buildQuestionsList() : _buildAgreementPendingView(),
      bottomNavigationBar: _hasAgreed ? _buildSubmitButton() : null,
    );
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
                    "Error loading questions:\n${snapshot.error}",
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
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

        final questions = snapshot.data!;

        return Column(
          children: [
            // Progress indicator
            Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_responses.length} of ${questions.length} answered',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        '${((_responses.length / questions.length) * 100).round()}%',
                        style: const TextStyle(
                          color: AppColors.primaryGreen,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _responses.length / questions.length,
                      minHeight: 6,
                      backgroundColor: AppColors.divider,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.primaryGreen),
                    ),
                  ),
                ],
              ),
            ),
            // Questions list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                itemCount: questions.length,
                itemBuilder: (context, index) {
                  final q = questions[index];
                  final groupInfo = q['group_id'] as Map<String, dynamic>?;
                  final groupTitle = groupInfo?['title'] ?? '';
                  final qId = q["id"].toString();
                  final isAnswered = _responses.containsKey(qId);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isAnswered
                            ? AppColors.primaryGreen.withAlpha(128)
                            : AppColors.divider,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Question header
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceGreen,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Q${index + 1}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primaryGreen,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              if (groupTitle.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    groupTitle,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                              if (isAnswered)
                                const Icon(
                                  Icons.check_circle,
                                  size: 20,
                                  color: AppColors.primaryGreen,
                                ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          // Question text
                          Text(
                            q["question"] ?? "No question text",
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildAnswerWidget(q),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAnswerWidget(Map<String, dynamic> question) {
    final String qId = question["id"].toString();
    final groupInfo = question['group_id'] as Map<String, dynamic>?;
    final String responseStyle =
        (groupInfo?['response_style'] as String? ?? "").toLowerCase().trim();

    if (responseStyle.contains("rating")) {
      return _buildRatingWidget(qId, question);
    } else if (responseStyle.contains("comment")) {
      return _buildCommentWidget(qId, question);
    } else if (responseStyle.contains("open")) {
      return _buildOpenEndedWidget(qId, question);
    } else {
      return _buildRatingWidget(qId, question);
    }
  }

  Widget _buildRatingWidget(String questionId, Map<String, dynamic> question) {
    final questionText = question["question"] ?? "";
    final groupInfo = question['group_id'] as Map<String, dynamic>?;
    final int number = groupInfo?['number'] ?? 0;
    const int scale = 5;

    final labels = ['Poor', 'Fair', 'Good', 'Very Good', 'Excellent'];

    return Column(
      children: [
        Row(
          children: List.generate(scale, (index) {
            final value = index + 1;
            final isSelected = _responses[questionId]?['answer'] == value;

            return Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _responses[questionId] = {
                      "questionId": questionId,
                      "questionText": questionText,
                      "questionNumber": number,
                      "answer": value,
                      "answerText": labels[index],
                      "type": "rating",
                    };
                  });
                },
                child: Container(
                  margin: EdgeInsets.only(
                    left: index == 0 ? 0 : 4,
                    right: index == scale - 1 ? 0 : 4,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primaryGreen
                        : AppColors.inputFill,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primaryGreen
                          : AppColors.divider,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        value.toString(),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? Colors.white
                              : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              labels[0],
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              labels[4],
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCommentWidget(String questionId, Map<String, dynamic> question) {
    final questionText = question["question"] ?? "";
    final groupInfo = question['group_id'] as Map<String, dynamic>?;
    final int number = groupInfo?['number'] ?? 0;

    return TextFormField(
      decoration: InputDecoration(
        hintText: "Enter your comment...",
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
      maxLines: 2,
      initialValue: _responses[questionId]?['answer'] as String?,
      onChanged: (value) {
        setState(() {
          _responses[questionId] = {
            "questionId": questionId,
            "questionText": questionText,
            "questionNumber": number,
            "answer": value,
            "answerText": value,
            "type": "comment",
          };
        });
      },
    );
  }

  Widget _buildOpenEndedWidget(
      String questionId, Map<String, dynamic> question) {
    final questionText = question["question"] ?? "";
    final groupInfo = question['group_id'] as Map<String, dynamic>?;
    final int number = groupInfo?['number'] ?? 0;

    return TextFormField(
      decoration: InputDecoration(
        hintText: "Type your detailed response...",
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
      maxLines: 5,
      initialValue: _responses[questionId]?['answer'] as String?,
      onChanged: (value) {
        setState(() {
          _responses[questionId] = {
            "questionId": questionId,
            "questionText": questionText,
            "questionNumber": number,
            "answer": value,
            "answerText": value,
            "type": "open_ended",
          };
        });
      },
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: _isSubmitting ? null : _submitSurvey,
            style: FilledButton.styleFrom(
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
                : const Text(
                    "Submit Survey",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitSurvey() async {
    if (_responses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Please answer at least one question."),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final studentId =
          authService.currentUser?['student']?['id']?.toString();

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Survey submitted successfully!"),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );

        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to submit survey: $e"),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }
}
