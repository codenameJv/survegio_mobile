import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'package:provider/provider.dart';
import 'dart:developer';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _firstNameController;
  late final TextEditingController _middleNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _studentNumberController;
  late final TextEditingController _emailController;

  String _originalStudentNumber = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;

    _firstNameController = TextEditingController(text: user?['first_name']?.toString() ?? '');
    _middleNameController = TextEditingController(text: user?['middle_initial']?.toString() ?? '');
    _lastNameController = TextEditingController(text: user?['last_name']?.toString() ?? '');
    _emailController = TextEditingController(text: user?['email']?.toString() ?? 'No email found');


    final studentData = user?['student'];
    final studentNumber = (studentData is Map) ? studentData['student_number']?.toString() : null;


    _originalStudentNumber = studentNumber ?? '';
    _studentNumberController = TextEditingController(text: studentNumber ?? 'N/A');
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _studentNumberController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);
    final authService = Provider.of<AuthService>(context, listen: false);


    final Map<String, dynamic> updatedUserData = {
      "first_name": _firstNameController.text.trim(),
      "middle_initial": _middleNameController.text.trim(),
      "last_name": _lastNameController.text.trim(),
    };


    final String newStudentNumber = _studentNumberController.text.trim();

    try {
      await authService.updateUser(updatedUserData);

      if (newStudentNumber.isNotEmpty && newStudentNumber != _originalStudentNumber) {

        await authService.updateStudentNumber(
          oldStudentNumber: _originalStudentNumber,
          newStudentNumber: newStudentNumber,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      log('Save Profile Error: $e', name: 'EditProfilePage');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile: ${e.toString().replaceFirst("Exception: ", "")}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),

      ),
      body: Form(
        key: _formKey,
        child: AbsorbPointer(
          absorbing: _isLoading,
          child: Opacity(
            opacity: _isLoading ? 0.5 : 1.0,
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                const SizedBox(height: 24),
                _buildTextField(
                  controller: _firstNameController,
                  labelText: 'First Name',
                  icon: Icons.person_outline,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _middleNameController,
                  labelText: 'Middle Name',
                  icon: Icons.person_outline,
                  isOptional: true,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _lastNameController,
                  labelText: 'Last Name',
                  icon: Icons.person_outline,
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 24),
                _buildTextField(
                  controller: _studentNumberController,
                  labelText: 'Student Number',
                  icon: Icons.numbers_outlined,
                  // Add validation for student number format
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your Student Number';
                    }
                    final pattern = r'^[A-Z][0-9]{4}-[0-9]{6}$';
                    final regExp = RegExp(pattern);
                    if (!regExp.hasMatch(value)) {
                      return 'Format must be like A2022-000000';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _emailController,
                  labelText: 'Email Address',
                  icon: Icons.email_outlined,
                  readOnly: true,
                ),
                const SizedBox(height: 40),
                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else
                  FilledButton.icon(
                    icon: const Icon(Icons.save),
                    label: const Text('Save Changes'),
                    onPressed: _saveProfile,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    bool readOnly = false,
    bool isOptional = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      decoration: InputDecoration(
        labelText: labelText,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: readOnly,
        fillColor: readOnly ? Colors.grey.shade200 : null,
      ),
      validator: validator ??
              (value) {
            if (!isOptional && (value == null || value.isEmpty)) {
              return 'Please enter your $labelText';
            }
            return null;
          },
    );
  }
}
