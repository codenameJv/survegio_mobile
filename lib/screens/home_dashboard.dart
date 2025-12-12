import 'package:flutter/material.dart';

class HomeDashboard extends StatefulWidget {
  final Map<String, dynamic>? user;
  const HomeDashboard({super.key, required this.user});

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {

  @override
  Widget build(BuildContext context) {
    final String firstName = widget.user?['first_name'] ?? 'User';

    return ListView(
      padding: const EdgeInsets.all(20.0),
      children: [
        _buildGreetingHeader(firstName),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildGreetingHeader(String firstName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hi, $firstName!',
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Welcome to your dashboard.',
          style: TextStyle(color: Colors.black54, fontSize: 16),
        ),
      ],
    );
  }
}
