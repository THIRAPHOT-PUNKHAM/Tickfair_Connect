import 'package:firebase_auth/firebase_auth.dart';

/// A simple wrapper around FirebaseAuth for authentication flows.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Registers a user with email and password.
  Future<UserCredential> signUp(String email, String password) async {
    return await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Signs in an existing user.
  Future<UserCredential> signIn(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Signs out the current user.
  Future<void> signOut() async {
    return await _auth.signOut();
  }

  /// Current user stream for listening to auth state changes.
  Stream<User?> get authStateChanges => _auth.authStateChanges();
}
