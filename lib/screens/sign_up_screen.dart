import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

const Color brandDarkGreen = Color(0xFF09330D);
const Color brandYellow = Color(0xFFFFCA02);

class SignUpScreen extends StatefulWidget {
  final Map<String, dynamic> verifiedStudentData;

  const SignUpScreen({
    super.key,
    required this.verifiedStudentData,
  });

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmpasswordController = TextEditingController();

  bool _isLoading = false;
  bool _isPasswordObscured = true;
  bool _isConfirmPasswordObscured = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmpasswordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);
    final authService = Provider.of<AuthService>(context, listen: false);

    try {
      await authService.signUp(
        studentId: widget.verifiedStudentData['studentNumber'],
        firstName: widget.verifiedStudentData['firstName'],
        middleInitial: widget.verifiedStudentData['middleInitial'],
        lastName: widget.verifiedStudentData['lastName'],
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sign up successful! Please log in to continue.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      log('SIGN-UP ERROR: ', error: e, name: 'SignUpScreen');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
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
    final String fullName =
        '${widget.verifiedStudentData['firstName'] ?? ''} ${widget.verifiedStudentData['middleInitial'] ?? ''} ${widget.verifiedStudentData['lastName'] ?? ''}';

    return Scaffold(
      backgroundColor: const Color(0xFFFFFCEB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/survegioLogo.png', height: 28),
            const SizedBox(width: 8),
            Text(
              'Survegio',
              style: GoogleFonts.lato(
                color: brandDarkGreen,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      body: Center(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Complete Your Account',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.lato(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: brandDarkGreen,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your details are verified. Just add an email and password.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.lato(color: const Color(0xFF333333)),
                ),
                const SizedBox(height: 32),

                _buildReadOnlyField(
                  label: 'Student Number (Verified)',
                  value: widget.verifiedStudentData['studentNumber'],
                ),
                const SizedBox(height: 16),
                _buildReadOnlyField(
                  label: 'Full Name (Verified)',
                  value: fullName,
                ),
                const SizedBox(height: 24),

                _buildEditableField(
                  controller: _emailController,
                  labelText: 'Email Address',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!RegExp(r'\S+@\S+\.\S+').hasMatch(value)) {
                      return 'Please enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _buildEditableField(
                  controller: _passwordController,
                  labelText: 'Password',
                  icon: Icons.lock_outline,
                  isPassword: true,
                  isObscured: _isPasswordObscured,
                  onObscureToggle: () =>
                      setState(() => _isPasswordObscured = !_isPasswordObscured),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    if (value.length < 8) {
                      return 'Password must be at least 8 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _buildEditableField(
                  controller: _confirmpasswordController,
                  labelText: 'Confirm Password',
                  icon: Icons.lock_outline,
                  isPassword: true,
                  isObscured: _isConfirmPasswordObscured,
                  onObscureToggle: () => setState(() =>
                  _isConfirmPasswordObscured = !_isConfirmPasswordObscured),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your password';
                    }
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : FilledButton(
                  onPressed: _signUp,
                  style: FilledButton.styleFrom(
                    backgroundColor: brandYellow,
                    foregroundColor: brandDarkGreen,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    textStyle: GoogleFonts.lato(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  child: const Text('Complete Sign Up'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildReadOnlyField({required String label, required String value}) {
    return TextFormField(
      initialValue: value,
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.check_circle, color: Colors.green),
        filled: true,
        fillColor: Colors.grey.shade200,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }


  Widget _buildEditableField({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    String? Function(String?)? validator,
    bool isPassword = false,
    bool isObscured = false,
    VoidCallback? onObscureToggle,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      obscureText: isObscured,
      decoration: InputDecoration(
        labelText: labelText,
        prefixIcon: Icon(icon, color: brandDarkGreen.withAlpha(153)),
        suffixIcon: isPassword
            ? IconButton(
          icon: Icon(isObscured ? Icons.visibility_off : Icons.visibility),
          onPressed: onObscureToggle,
        )
            : null,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: brandDarkGreen, width: 2.0),
        ),
      ),
    );
  }
}
