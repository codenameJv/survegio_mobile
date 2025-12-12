// lib/screens/terms_of_use_page.dart

import 'package:flutter/material.dart';

class TermsOfUsePage extends StatelessWidget {
  const TermsOfUsePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms of Use'),
        elevation: 1, // Adds a subtle shadow
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome to Survegio!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text(
              'These terms and conditions outline the rules and regulations for the use of the Survegio application, developed by CCT IT Students.',
              style: TextStyle(fontSize: 16, height: 1.5),
            ),
            SizedBox(height: 24),

            _buildSectionHeader('1. Acceptance of Terms'),
            _buildParagraph(
                'By accessing and using this application, you accept and agree to be bound by the terms and provision of this agreement. If you do not agree to abide by these terms, please do not use this application.'
            ),

            _buildSectionHeader('2. Use License'),
            _buildParagraph(
                'Permission is granted to temporarily download one copy of the materials (information or software) on Survegio\'s application for personal, non-commercial transitory viewing only. This is the grant of a license, not a transfer of title.'
            ),

            _buildSectionHeader('3. User Conduct'),
            _buildParagraph(
                'You agree not to use the application in a way that may impair the performance, corrupt the content or otherwise reduce the overall functionality of the application. You also agree not to compromise the security of the application or attempt to gain access to secured areas or sensitive information.'
            ),

            _buildSectionHeader('4. Disclaimer'),
            _buildParagraph(
                'The materials on Survegio\'s application are provided \'as is\'. The developers make no warranties, expressed or implied, and hereby disclaim and negate all other warranties, including without limitation, implied warranties or conditions of merchantability.'
            ),

            SizedBox(height: 24),
            Text(
              'Last Updated: November 2025',
              style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  // Helper widget for section titles
  static Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  // Helper widget for paragraphs
  static Widget _buildParagraph(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 16, height: 1.5),
    );
  }
}
