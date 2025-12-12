import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'sign_in_screen.dart';
import 'terms_of_use.dart';
import 'privacy_policy.dart';
import 'edit_profile_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _pushNotificationsEnabled = true;
  bool _emailNotificationsEnabled = false;

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Colors.green.shade800,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey.shade600),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: ListView(
        children: [
          // --- ACCOUNT SECTION ---
          _buildSectionTitle('Account'),
          _buildSettingsTile(
            icon: Icons.edit_outlined,
            title: 'Edit Profile',
            subtitle: 'Update name, student number, etc.',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const EditProfilePage()),
              );
            },
          ),

          // --- APP PREFERENCES SECTION ---
          _buildSectionTitle('App Preferences'),
          SwitchListTile(
            title: const Text('Dark Mode'),
            secondary: Icon(Icons.dark_mode_outlined, color: Colors.grey.shade600),
            value: isDarkMode,
            onChanged: (val) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Theme switching will be implemented soon!')),
              );
            },
          ),


          // --- NOTIFICATIONS SECTION ---
          _buildSectionTitle('Notifications'),
          SwitchListTile(
            title: const Text('Push Notifications'),
            secondary: Icon(Icons.notifications_active_outlined, color: Colors.grey.shade600),
            value: _pushNotificationsEnabled,
            onChanged: (val) {
              setState(() => _pushNotificationsEnabled = val);
            },
          ),
          SwitchListTile(
            title: const Text('Email Notifications'),
            secondary: Icon(Icons.email_outlined, color: Colors.grey.shade600),
            value: _emailNotificationsEnabled,
            onChanged: (val) {
              setState(() => _emailNotificationsEnabled = val);
            },
          ),

          // --- ABOUT SECTION ---
          _buildSectionTitle('About'),
          _buildSettingsTile(
            icon: Icons.info_outline,
            title: 'Privacy Policy',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const PrivacyPolicyPage()),
              );
            },
          ),
          _buildSettingsTile(
            icon: Icons.description_outlined,
            title: 'Terms of Use',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const TermsOfUsePage()),
              );
            },
          ),

          const SizedBox(height: 20),
          Center(
            child: TextButton(
              onPressed: () {
                authService.logout();

                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const SignInScreen()),
                        (Route<dynamic> route) => false,
                  );
                }
              },
              child: const Text(
                "Logout",
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
            child: Column(
              children: [
                Text(
                  'App Version 1.0.0',
                  style: TextStyle(color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  'Developed by CCT Students',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
