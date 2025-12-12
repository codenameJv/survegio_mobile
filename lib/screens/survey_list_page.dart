import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/survey_service.dart';
import './survey_taking_screen.dart';

class SurveyListScreen extends StatefulWidget {
  const SurveyListScreen({super.key});

  @override
  State<SurveyListScreen> createState() => _SurveyListScreenState();
}

class _SurveyListScreenState extends State<SurveyListScreen> {
  late final SurveyService _surveyService;
  late Future<List<Map<String, dynamic>>> _surveysFuture;

  @override
  void initState() {
    super.initState();
    final token = Provider.of<AuthService>(context, listen: false).token;
    _surveyService = SurveyService(token);
    _surveysFuture = _surveyService.fetchAvailableSurveys();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _surveysFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            // Mas malinaw na error message
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'An error occurred: \n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No available surveys at the moment.'));
          }

          final surveys = snapshot.data!;
          return ListView.builder(
            itemCount: surveys.length,
            itemBuilder: (context, index) {
              final survey = surveys[index];

              final title = survey['title'] ?? 'No Title';
              final instruction = survey['instruction'] ?? 'No Instructions';
              final percentage = survey['percentage']?.toString() ?? '0';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  title: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(instruction),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                  ),
                  onTap: () {
                    final String surveyId = survey['id'].toString();

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SurveyTakingScreen(
                          surveyId: surveyId,
                          surveyTitle: title,
                        ),
                      ),
                    );
                  },

                ),
              );
            },
          );
        },
      ),
    );
  }
}

