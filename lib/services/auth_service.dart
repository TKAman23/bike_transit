import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  User? user;

  User? get currentUser => _auth.currentUser;

  static bool get isSignedIn => FirebaseAuth.instance.currentUser != null;

  /// Waits for Firebase to restore a saved session (asynchronous on web).
  static Future<void> restoreSession() => FirebaseAuth.instance
      .authStateChanges()
      .first
      .timeout(const Duration(seconds: 5), onTimeout: () => null);

  /// Human-readable message for a Firebase Auth error code.
  static String messageFor(String? code) => switch (code) {
        'invalid-email' => 'That email address is not valid.',
        'missing-email' || 'channel-error' =>
          'Enter both your email and password.',
        'missing-password' => 'Enter your password.',
        'invalid-credential' ||
        'wrong-password' ||
        'user-not-found' =>
          'Invalid credentials. Please check your email and password.',
        'weak-password' => 'Choose a stronger password (at least 6 characters).',
        'email-already-in-use' =>
          'This email is already in use. Please sign in instead.',
        'user-disabled' => 'This account has been disabled.',
        'too-many-requests' => 'Too many attempts. Please wait and try again.',
        'network-request-failed' => 'No connection. Check your network and try again.',
        'operation-not-allowed' =>
          'This sign-in method is not enabled for the app.',
        _ => 'Something went wrong signing in ($code). Please try again.',
      };

  /// True when the account signs in with email + password (so a reset email applies).
  bool get isPasswordUser =>
      _auth.currentUser?.providerData.any((p) => p.providerId == 'password') ??
      false;

  Future<String?> signInWithEmailAndPassword({required String email, required String password,}) async {
    try {
      final UserCredential userCredential = await _auth.signInWithEmailAndPassword(email: email.trim(), password: password.trim());
      user = userCredential.user;
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        debugPrint('User not found. Signing up.');
        return signUpWithEmailAndPassword(
          email: email.trim(),
          password: password.trim(),
        );
      } else if (e.code == 'invalid-credential') {
        debugPrint('Invalid credentials. Check email and password.');
        return e.code;
      }
      debugPrint('Error signing in with email and password: $e');
      return e.code;
    } catch (e) {
      debugPrint('Error signing in with email and password: $e');
      return 'unknown';
    }
  }

  Future<String?> signUpWithEmailAndPassword({required String email, required String password}) async {
    try {
      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password.trim());
      user = userCredential.user;
      return null;
    } on FirebaseAuthException catch (e) {
      debugPrint('Error signing up with email and password: $e');
      return e.code;
    } catch (e) {
      debugPrint('Error signing up with email and password: $e');
      return 'unknown';
    }
  }

  Future<String?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // The supported Google sign-in flow in browsers is Firebase's popup.
        final credential = await _auth.signInWithPopup(GoogleAuthProvider());
        user = credential.user;
        return null;
      }
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return null; // User canceled the sign-in
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      user = userCredential.user;
      return null;

    } on FirebaseAuthException catch (e) {
      debugPrint('Error signing in with Google: $e');
      return e.code;
    } catch (e) {
      debugPrint('Error signing in with Google: $e');
      return 'unknown';
    }
  }

  Future<String?> signOut() async {
    try {
      await _auth.signOut();
      await _googleSignIn.signOut();
      user = null;
      return null;
    } on FirebaseAuthException catch (e) {
      return e.code;
    } catch (_) {
      return 'unknown';
    }
  }

  Future<String> resetPassword({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return 'Email sent. Please check your inbox.';
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        return 'No user found for that email.';
      } else if (e.code == 'invalid-email') {
        return 'Invalid email address.';
      }
      return 'Firebase Error: $e';
    } catch (e) {
      return 'Error sending password reset email: $e';
    }
  }
}
