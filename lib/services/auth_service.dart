import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  User? user;

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
}
