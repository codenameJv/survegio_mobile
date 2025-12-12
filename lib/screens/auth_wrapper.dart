import 'package:flutter/material.dart';
import 'sign_in_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override  Widget build(BuildContext context) {
    // For now, we will always start at the SignInScreen.
    return const SignInScreen();
  }
}
