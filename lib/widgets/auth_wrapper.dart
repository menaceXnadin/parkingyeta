import 'package:flutter/material.dart';
import '../screens/home_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // Always show HomeScreen regardless of authentication status
    // This allows users to use the app without authentication
    return const HomeScreen();
  }
}
