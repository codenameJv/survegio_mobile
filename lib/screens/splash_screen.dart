import 'dart:async';
import 'package:flutter/material.dart';
import 'auth_wrapper.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Setup animation
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    _controller.forward();

    // After animation completes + 1s delay → navigate to AuthWrapper
    Timer(const Duration(seconds: 5), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AuthWrapper()),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF282425),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/survegioLogo.png', // make sure this path is correct
                height: 120,
              ),
              const SizedBox(height: 20),
              const Text(
                'Survegio',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Gilroy-Bold',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
