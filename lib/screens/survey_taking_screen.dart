import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
      appBar: AppBar(
        title: Text(widget.surveyTitle),
      ),
      body: _hasAgreed ? _buildQuestionsList() : _buildAgreementPendingView(),
      bottomNavigationBar: _hasAgreed ? _buildSubmitButton() : null,
    );
  }

  Widget _buildAgreementPendingView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text("Awaiting data privacy agreement..."),
        ],
      ),
    );
  }

  Widget _buildQuestionsList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _questionsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              "Error loading questions:\n${snapshot.error}",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Text("This survey has no questions."),
          );
        }

        final questions = snapshot.data!;

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 16),
          itemCount: questions.length,
          itemBuilder: (context, index) {
            final q = questions[index];
            final groupInfo = q['group_id'] as Map<String, dynamic>?;
            final groupTitle = groupInfo?['title'] ?? '';

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (groupTitle.isNotEmpty) ...[
                      Text(
                        groupTitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    Text(
                      "Question ${index + 1}",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(q["question"] ?? "No question text"),
                    const SizedBox(height: 16),
                    _buildAnswerWidget(q),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAnswerWidget(Map<String, dynamic> question) {
    final String qId = question["id"].toString();
    final groupInfo = question['group_id'] as Map<String, dynamic>?;
    final String responseStyle =
        (groupInfo?['response_style'] as String? ?? "").toLowerCase().trim();

    // Available response styles:
    // - "Rating-Scale Questions" → 5-point rating scale
    // - "Comment" → text field (short)
    // - "Open-Ended Question" → text field (long)
    if (responseStyle.contains("rating")) {
      return _buildRatingWidget(qId, question);
    } else if (responseStyle.contains("comment")) {
      return _buildCommentWidget(qId, question);
    } else if (responseStyle.contains("open")) {
      return _buildOpenEndedWidget(qId, question);
    } else {
      // Fallback to rating
      return _buildRatingWidget(qId, question);
    }
  }

  /// Rating-Scale Widget (1-5 scale)
  Widget _buildRatingWidget(String questionId, Map<String, dynamic> question) {
    final questionText = question["question"] ?? "";
    final groupInfo = question['group_id'] as Map<String, dynamic>?;
    final int number = groupInfo?['number'] ?? 0;
    const int scale = 5;

    final labels = ['Poor', 'Fair', 'Good', 'Very Good', 'Excellent'];

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.green : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? Colors.green.shade700 : Colors.grey.shade300,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        value.toString(),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(labels[0], style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            Text(labels[4], style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          ],
        ),
      ],
    );
  }

  /// Comment Widget (short text)
  Widget _buildCommentWidget(String questionId, Map<String, dynamic> question) {
    final questionText = question["question"] ?? "";
    final groupInfo = question['group_id'] as Map<String, dynamic>?;
    final int number = groupInfo?['number'] ?? 0;

    return TextFormField(
      decoration: const InputDecoration(
        hintText: "Enter your comment...",
        border: OutlineInputBorder(),
      ),
      maxLines: 2,
      initialValue: _responses[questionId]?['answer'] as String?,
      onChanged: (value) {
        _responses[questionId] = {
          "questionId": questionId,
          "questionText": questionText,
          "questionNumber": number,
          "answer": value,
          "answerText": value,
          "type": "comment",
        };
      },
    );
  }

  /// Open-Ended Widget (longer text)
  Widget _buildOpenEndedWidget(String questionId, Map<String, dynamic> question) {
    final questionText = question["question"] ?? "";
    final groupInfo = question['group_id'] as Map<String, dynamic>?;
    final int number = groupInfo?['number'] ?? 0;

    return TextFormField(
      decoration: const InputDecoration(
        hintText: "Type your detailed response...",
        border: OutlineInputBorder(),
      ),
      maxLines: 5,
      initialValue: _responses[questionId]?['answer'] as String?,
      onChanged: (value) {
        _responses[questionId] = {
          "questionId": questionId,
          "questionText": questionText,
          "questionNumber": number,
          "answer": value,
          "answerText": value,
          "type": "open_ended",
        };
      },
    );
  }

  Widget _buildSubmitButton() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: FilledButton(
        onPressed: _isSubmitting ? null : _submitSurvey,
        child: _isSubmitting
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text("Submit Survey"),
      ),
    );
  }

  Future<void> _submitSurvey() async {
    if (_responses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please answer at least one question."),
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

      // TWO-STEP SUBMISSION FLOW

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
          const SnackBar(
            content: Text("Survey submitted successfully!"),
            backgroundColor: Colors.green,
          ),
        );

        // Return true to indicate successful submission
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to submit survey: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
