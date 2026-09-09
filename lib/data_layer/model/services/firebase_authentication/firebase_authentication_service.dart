import 'package:firebase_auth/firebase_auth.dart';

import '../../../../external_data_sources/firebase/firebase_data_source.dart';

class FirebaseAuthenticationService {
  final FirebaseDataSource _firebaseDataSource;

  FirebaseAuthenticationService({FirebaseDataSource? firebaseDataSource})
    : _firebaseDataSource = firebaseDataSource ?? FirebaseDataSource.instance;

  FirebaseAuth get _auth => _firebaseDataSource.auth;

  // Get currently logged-in user
  User? get currentUser => _auth.currentUser;

  // Check if a user is logged in
  bool get isLoggedIn => currentUser != null;

  // Listen for login/logout changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Register new user
  Future<UserCredential> register({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        throw Exception('EMAIL_ALREADY_REGISTERED');
      }

      throw Exception(e.message ?? 'Unable to create account.');
    }
  }

  // Login
  Future<UserCredential> login({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'Unable to sign in.');
    }
  } // Reload the current Firebase user from Firebase.

  Future<void> reloadCurrentUser() async {
    final user = currentUser;
    if (user != null) {
      await user.reload();
    }
  }

  // Whether the currently signed-in user's email has been verified.
  bool get isEmailVerified => currentUser?.emailVerified ?? false;

  // Send Firebase's verification email to the current user.
  Future<void> sendEmailVerification() async {
    final user = currentUser;

    if (user == null) {
      throw Exception('No signed-in user.');
    }

    if (user.emailVerified) {
      return;
    }

    try {
      await user.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'Unable to send verification email.');
    }
  }

  // Logout
  Future<void> logout() async {
    await _auth.signOut();
  }

  // Forgot password
  Future<void> sendPasswordResetEmail({required String email}) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }
}
