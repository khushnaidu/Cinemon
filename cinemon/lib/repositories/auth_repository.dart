import 'package:firebase_auth/firebase_auth.dart';

/// Repository for Firebase Authentication operations
///
/// This is the data layer - handles all direct Firebase Auth interactions.
/// UI should never call Firebase directly, always go through this repository.
class AuthRepository {
  final FirebaseAuth _auth;

  AuthRepository({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  /// Sign up a new user with email and password
  ///
  /// Returns the Firebase User if successful
  /// Throws FirebaseAuthException on failure (invalid email, weak password, etc.)
  Future<User?> signUp({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user;
    } on FirebaseAuthException catch (e) {
      // Let the provider/UI handle the error
      rethrow;
    }
  }

  /// Sign in an existing user with email and password
  ///
  /// Returns the Firebase User if successful
  /// Throws FirebaseAuthException on failure (wrong password, user not found, etc.)
  Future<User?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user;
    } on FirebaseAuthException catch (e) {
      rethrow;
    }
  }

  /// Sign out the current user
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Get the currently signed-in user (null if not signed in)
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  /// Stream of auth state changes
  ///
  /// Emits the current User when signed in, null when signed out
  /// Use this to listen for auth state changes (login/logout)
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Send password reset email
  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      rethrow;
    }
  }

  /// Check if a user is currently signed in
  bool get isSignedIn => _auth.currentUser != null;

  /// Get current user's UID (null if not signed in)
  String? get currentUserId => _auth.currentUser?.uid;
}
