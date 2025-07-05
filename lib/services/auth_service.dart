import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Stream of authentication changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with Google - ultra simplified to prevent crashes
  Future<bool> signInWithGoogle() async {
    try {
      // Step 1: Sign out first to ensure clean state
      try {
        await _googleSignIn.signOut();
      } catch (e) {
        if (kDebugMode) {
          print('Pre-signout error (safe to ignore): $e');
        }
      }

      // Step 2: Try to get Google account
      if (kDebugMode) {
        print('Starting Google Sign-In flow');
      }
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        if (kDebugMode) {
          print('Google Sign-In was canceled by user');
        }
        return false;
      }

      if (kDebugMode) {
        print('Google Sign-In selected account: ${googleUser.email}');
      }

      // Step 3: Get authentication data
      try {
        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

        // Step 4: Create Firebase credential
        final OAuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        // Step 5: Sign in with Firebase
        if (kDebugMode) {
          print('Attempting Firebase sign-in');
        }
        await _auth.signInWithCredential(credential);
        if (kDebugMode) {
          print('Firebase sign-in completed');
        }
        return true;
      } catch (authError) {
        if (kDebugMode) {
          print('Auth error: $authError');
        }
        // If user is somehow signed in despite errors, consider it success
        return _auth.currentUser != null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Google Sign-In process error: $e');
      }
      return false;
    }
  }

  // Sign out - simplified
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      await _googleSignIn.signOut();
    } catch (e) {
      if (kDebugMode) {
        print('Sign out error: $e');
      }
    }
  }

  // Check if user is signed in
  bool isSignedIn() {
    return _auth.currentUser != null;
  }
}
