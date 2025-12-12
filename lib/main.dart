import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/splash_screen.dart';
import 'services/auth_service.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => AuthService(),
      child: const SurvegioApp(),
    ),
  );
}

class SurvegioApp extends StatelessWidget {
  const SurvegioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Survegio',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle:
            const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ),
      debugShowCheckedModeBanner: false,
      home:
      const SplashScreen(),
    );
  }
}
