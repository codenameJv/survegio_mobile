// lib/screens/privacy_policy_page.dart

import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(      appBar: AppBar(
      title: const Text('Privacy Policy'),
      elevation: 1,
    ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Privacy Policy for Survegio',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildParagraph(
              'Your privacy is important to us. It is the policy of the Survegio development team to respect your privacy regarding any information we may collect from you through our app, Survegio.',
            ),
            _buildSectionHeader('1. Information We Collect'),
            _buildParagraph(
              'We only ask for personal information when we truly need it to provide a service to you. We collect it by fair and lawful means, with your knowledge and consent. We primarily collect information related to your user account, such as your name, email, and user role (student, dean, admin).',
            ),
            _buildSectionHeader('2. How We Use Your Information'),
            _buildParagraph(
              'We use the information we collect to operate and maintain our application, to provide you with the features and functionality of the service, and to communicate with you. Survey responses are collected for analytical purposes to improve the services and educational environment of the institution.',
            ),
            _buildSectionHeader('3. Data Storage and Security'),
            _buildParagraph(
              'We only retain collected information for as long as necessary to provide you with your requested service. What data we store, we’ll protect within commercially acceptable means to prevent loss and theft, as well as unauthorized access, disclosure, copying, use or modification.',
            ),
            _buildSectionHeader('4. Your Consent'),
            _buildParagraph(
              'By using our application, you hereby consent to our Privacy Policy and agree to its terms.',
            ),
            const SizedBox(height: 24),
            const Text(
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
