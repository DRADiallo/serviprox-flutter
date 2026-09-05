import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/splash_screen.dart';

void main() {
  runApp(const ServiProxApp());
}

class ServiProxApp extends StatelessWidget {
  const ServiProxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ServiProx',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const SplashScreen(), // ← décommentez et mettez SplashScreen
    );
  }
}