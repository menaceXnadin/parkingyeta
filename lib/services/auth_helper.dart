import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthHelper {
  // Check if user is logged in
  static bool isLoggedIn() {
    return FirebaseAuth.instance.currentUser != null;
  }

  // Show login dialog if not authenticated and return whether user is authenticated after dialog
  static Future<bool> checkAuthAndShowLoginIfNeeded(
    BuildContext context,
  ) async {
    // If already logged in, return true
    if (isLoggedIn()) {
      return true;
    }

    // If not logged in, show dialog asking to log in
    final bool? shouldLogin = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Authentication Required'),
        content: const Text(
          'You need to log in or create an account to add parking spots.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Log In / Sign Up'),
          ),
        ],
      ),
    );

    // If user chose to log in, navigate to login screen and wait for result
    if (shouldLogin == true) {
      if (context.mounted) {
        await Navigator.pushNamed(context, '/login');
      }

      // After returning from login screen, check if now logged in
      return isLoggedIn();
    }

    // User chose not to log in
    return false;
  }
}
