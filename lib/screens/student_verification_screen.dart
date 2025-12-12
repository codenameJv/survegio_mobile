import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'sign_up_screen.dart';

const Color brandDarkGreen = Color(0xFF09330D);
const Color brandYellow = Color(0xFFFFCA02);

class StudentVerificationScreen extends StatefulWidget {
  const StudentVerificationScreen({super.key});

  @override
  State<StudentVerificationScreen> createState() =>
      _StudentVerificationScreenState();
}

class _StudentVerificationScreenState extends State<StudentVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _studentNumberController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _middleInitialController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _studentNumberController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _middleInitialController.dispose();
    super.dispose();
  }

  Future<void> _verifyStudent() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final authService = Provider.of<AuthService>(context, listen: false);

    try {
      final studentData = await authService.verifyStudent(
        studentId: _studentNumberController.text.trim(),
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        middleInitial: _middleInitialController.text.trim(),
      );

      // Middle Initial Logic
      final recordMI = (studentData['middleInitial'] ?? '').trim();
      final inputMI = _middleInitialController.text.trim();

      if (recordMI.isNotEmpty && inputMI.isEmpty) {
        throw Exception(
            "Your school record includes a middle name. Please enter your middle initial.");
      }

      if (recordMI.isNotEmpty &&
          inputMI.toLowerCase() != recordMI[0].toLowerCase()) {
        throw Exception("Middle initial does not match the school record.");
      }

      // Proceed to Sign Up Screen
      FocusScope.of(context).unfocus();
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) =>
                  SignUpScreen(verifiedStudentData: studentData),
            ),
          );
        });
      }
    } catch (e) {
      log('STUDENT VERIFICATION ERROR: ', error: e, name: 'VerificationScreen');
      if (mounted) {
        // Display friendly and professional message
        final errorMessage = e.toString().replaceFirst('Exception: ', '');
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text("Verification Failed",
                style: TextStyle(fontWeight: FontWeight.bold)),
            content: Text(errorMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text("OK"),
              )
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Verification'),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      backgroundColor: Colors.grey[50],
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Transform.translate(
                  offset: const Offset(0, -40),
                  child: Image.asset('assets/survegioLogo.png', height: 80),
                ),
                Text(
                  'Verify Your Identity',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.lato(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: brandDarkGreen,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Enter your details exactly as they appear in your school record.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.lato(color: Colors.grey[700]),
                ),
                const SizedBox(height: 32),

                _buildTextField(
                    controller: _studentNumberController,
                    label: 'Student Number',
                    isRequired: true),
                const SizedBox(height: 16),
                _buildTextField(
                    controller: _lastNameController,
                    label: 'Last Name',
                    isRequired: true),
                const SizedBox(height: 16),
                _buildTextField(
                    controller: _firstNameController,
                    label: 'First Name',
                    isRequired: true),
                const SizedBox(height: 16),
                _buildTextField(
                    controller: _middleInitialController,
                    label: 'Middle Initial',
                    maxLength: 1,
                    isRequired: false),

                const SizedBox(height: 32),

                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : FilledButton(
                  onPressed: _verifyStudent,
                  style: FilledButton.styleFrom(
                    backgroundColor: brandYellow,
                    foregroundColor: brandDarkGreen,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28)),
                  ),
                  child: const Text('Verify My Identity'),
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
    required String label,
    required bool isRequired,
    int? maxLength,
  }) {
    return TextFormField(
      controller: controller,
      maxLength: maxLength,
      decoration: InputDecoration(
        labelText: label,
        counterText: '',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: (value) {
        if (isRequired && (value == null || value.isEmpty)) {
          return 'This field cannot be empty';
        }
        return null;
      },
    );
  }
}
