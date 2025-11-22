import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Stream of authentication changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Check if current user is guest
  bool get isGuest => currentUser?.isAnonymous ?? false;

  // Sign in with Google
  Future<bool> signInWithGoogle() async {
    try {
      // Step 1: Sign out first to ensure clean state
      try {
        await _googleSignIn.signOut();
      } catch (e) {
        debugPrint('Pre-signout error (safe to ignore): $e');
      }

      // Step 2: Try to get Google account
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        return false; // Canceled by user
      }

      // Step 3: Get authentication data
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Step 4: Create Firebase credential
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Step 5: Sign in with Firebase
      UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );

      // Step 6: Create or Update User in Firestore
      if (userCredential.user != null) {
        await _syncUserToFirestore(userCredential.user!);
      }

      return true;
    } catch (e) {
      debugPrint('Google Sign-In process error: $e');
      return false;
    }
  }

  // Sign in anonymously (Guest Mode)
  Future<bool> signInAnonymously() async {
    try {
      await _auth.signInAnonymously();
      return true;
    } catch (e) {
      debugPrint('Anonymous sign in error: $e');
      return false;
    }
  }

  // Sync user data to Firestore
  Future<void> _syncUserToFirestore(User user) async {
    try {
      final userRef = _firestore.collection('users').doc(user.uid);

      final doc = await userRef.get();
      if (!doc.exists) {
        // Create new user
        final newUser = UserModel(
          id: user.uid,
          displayName: user.displayName,
          email: user.email,
          photoURL: user.photoURL,
          createdAt: DateTime.now(),
          lastLoginAt: DateTime.now(),
        );
        await userRef.set(newUser.toMap());
      } else {
        // Update last login
        await userRef.update({
          'lastLoginAt': FieldValue.serverTimestamp(),
          'photoURL': user.photoURL, // Update photo if changed
          'displayName': user.displayName, // Update name if changed
        });
      }
    } catch (e) {
      // Log the error but don't fail the sign-in
      debugPrint('Firestore sync error (non-fatal): $e');
      // User is still authenticated even if Firestore sync fails
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      await _googleSignIn.signOut();
    } catch (e) {
      debugPrint('Sign out error: $e');
    }
  }
}
