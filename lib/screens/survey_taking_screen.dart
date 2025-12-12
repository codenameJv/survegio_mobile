import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/survey_service.dart';
import './data_privacy.dart';

class SurveyTakingScreen extends StatefulWidget {
  final String surveyId;
  final String surveyTitle;

  const SurveyTakingScreen({
    super.key,
    required this.surveyId,
    required this.surveyTitle,
  });

  @override
  State<SurveyTakingScreen> createState() => _SurveyTakingScreenState();
}

class _SurveyTakingScreenState extends State<SurveyTakingScreen> {
  late final SurveyService _surveyService;
  Future<List<Map<String, dynamic>>>? _questionsFuture;

  bool _hasAgreed = false;


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

      body: _hasAgreed
          ? _buildQuestionsList()
          : _buildAgreementPendingView(),

      bottomNavigationBar:
      _hasAgreed ? _buildSubmitButton() : null,
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

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Question ${index + 1}",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(q["question_text"] ?? "No question text"),

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
    final String type =
    (question["question_type"] as String? ?? "").toLowerCase().trim();

    final questionText = question["question_text"] ?? "";
    final int number = int.tryParse(question["questionNumber"].toString()) ?? 0;

    switch (type) {
      case "rating":
        return _buildRatingWidget(qId, question);

      case "text":
        return TextFormField(
          decoration: const InputDecoration(
            hintText: "Type your answer...",
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          onChanged: (value) {
            _responses[qId] = {
              "questionId": qId,
              "questionText": questionText,
              "questionNumber": number,
              "answer": value,
              "type": type,
            };
          },
        );

      default:
        print("⚠ Unsupported question type: $type");

        return Text(
          "Unsupported question type: $type",
          style: const TextStyle(color: Colors.red),
        );
    }
  }


  Widget _buildRatingWidget(String questionId, Map<String, dynamic> question) {
    final questionText = question["question_text"] ?? "";
    final int number = int.tryParse(question["questionNumber"].toString()) ?? 0;

    String? scaleDescription = question["scale_description"];
    int scale = 5;

    if (scaleDescription != null) {
      final clean = scaleDescription.replaceAll(RegExp(r'[^0-9\-]'), '');

      if (clean.contains("-")) {
        final parts = clean.split("-");
        if (parts.length == 2) {
          final end = int.tryParse(parts[1]);
          if (end != null) scale = end;
        }
      } else {
        final single = int.tryParse(clean);
        if (single != null) scale = single;
      }
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(scale, (index) {
        final value = index + 1;

        return Column(
          children: [
            Text(value.toString()),

            Radio<int>(
              value: value,
              groupValue: (_responses[questionId]?['answer'] as int?),

              onChanged: (selected) {
                setState(() {
                  _responses[questionId] = {
                    "questionId": questionId,
                    "questionText": questionText,
                    "questionNumber": number,
                    "answer": selected,
                    "type": "rating",
                  };
                });
              },
            ),
          ],
        );
      }),
    );
  }
  

  Widget _buildSubmitButton() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: FilledButton(
        child: const Text("Submit Survey"),
        onPressed: () async {
          if (_responses.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Please answer at least one question."),
              ),
            );
            return;
          }

          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) =>
            const Center(child: CircularProgressIndicator()),
          );

          try {
            await _surveyService.submitSurveyResponses(
              widget.surveyId,
              _responses,
            );

            if (mounted) Navigator.of(context).pop();

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Survey submitted successfully!"),
              ),
            );

            Navigator.of(context).pop();
          } catch (e) {
            if (mounted) Navigator.of(context).pop();

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Failed to submit survey: $e"),
              ),
            );
          }
        },
      ),
    );
  }
}
