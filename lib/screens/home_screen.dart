import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'home_dashboard.dart';
import 'survey_list_page.dart';
import 'profile_page.dart';
import 'settings_page.dart';
import'../config.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  static const String directusUrl = AppConfig.directusUrl;

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        final user = authService.currentUser;

        if (user == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: Colors.green)),
          );
        }

        final String avatarId = user['avatar'] ?? '';
        final String avatarUrl =
        avatarId.isNotEmpty ? '$directusUrl/assets/$avatarId' : '';
        final String firstName = user['first_name'] ?? '';
        final String lastName = user['last_name'] ?? '';

        final List<Widget> pages = [
          HomeDashboard(user: user),
          const SurveyListScreen(),
          const SettingsPage(),
        ];

        return Scaffold(
          appBar: AppBar(
            title: _selectedIndex == 0
                ? null
                : Text(['Home', 'Surveys', 'Settings'][_selectedIndex]),
            centerTitle: false,
            automaticallyImplyLeading: false,
            elevation: _selectedIndex == 0 ? 0 : 1,
            backgroundColor: _selectedIndex == 0
                ? const Color(0xFF43A047)
                : Theme.of(context).scaffoldBackgroundColor,
            foregroundColor: _selectedIndex == 0 ? Colors.white : null,
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Notifications Page coming soon!')),
                  );
                },
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (context) => const ProfilePage()),
                    );
                  },
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.grey.shade300,
                    backgroundImage:
                    avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                    child: avatarUrl.isEmpty
                        ? Text(
                      '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold),
                    )
                        : null,
                  ),
                ),
              ),
            ],
          ),
          body: pages[_selectedIndex],
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _selectedIndex,
            selectedItemColor: Colors.green,
            unselectedItemColor: Colors.grey,
            onTap: _onItemTapped,
            type: BottomNavigationBarType.fixed,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.assignment), label: 'Surveys'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.settings), label: 'Settings'),
            ],
          ),
        );
      },
    );
  }
}
