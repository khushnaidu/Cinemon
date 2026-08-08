import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_config.dart';

/// Repository for Supabase Authentication operations.
///
/// This is the data layer — all direct auth interaction lives here.
/// UI should never call Supabase directly, always go through this repository.
class AuthRepository {
  final SupabaseClient _client;

  AuthRepository({SupabaseClient? client})
      : _client = client ?? SupabaseConfig.client;

  GoTrueClient get _auth => _client.auth;

  /// Sign up a new user with email and password.
  ///
  /// [username] is passed as user metadata; the `on_auth_user_created`
  /// trigger reads it to seed the `profiles` row, so there is no window
  /// where an auth user exists without a profile.
  ///
  /// Throws [AuthException] on failure.
  Future<User?> signUp({
    required String email,
    required String password,
    String? username,
  }) async {
    final response = await _auth.signUp(
      email: email,
      password: password,
      data: username != null ? {'username': username.toLowerCase()} : null,
      emailRedirectTo: SupabaseConfig.authRedirectUrl,
    );
    return response.user;
  }

  /// Sign in an existing user with email and password.
  ///
  /// Throws [AuthException] on failure.
  Future<User?> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _auth.signInWithPassword(
      email: email,
      password: password,
    );
    return response.user;
  }

  /// Sign out the current user.
  Future<void> signOut() => _auth.signOut();

  /// The currently signed-in user, or null.
  User? getCurrentUser() => _auth.currentUser;

  /// Stream of the signed-in user; emits null when signed out.
  ///
  /// Supabase emits a rich [AuthState] (event + session); this narrows it to
  /// just the user so nothing downstream needs to know about Supabase types.
  ///
  /// The current user is emitted synchronously up front: `onAuthStateChange`
  /// is a broadcast stream that does not replay its `initialSession` event, so
  /// a subscriber attaching after startup would otherwise sit at "no user"
  /// until the next login — flashing the login screen on a warm launch.
  Stream<User?> get authStateChanges async* {
    yield _auth.currentUser;
    yield* _auth.onAuthStateChange
        .map((state) => state.session?.user)
        .distinct((a, b) => a?.id == b?.id);
  }

  /// Send a password reset email.
  Future<void> sendPasswordResetEmail({required String email}) =>
      _auth.resetPasswordForEmail(
        email,
        redirectTo: SupabaseConfig.authRedirectUrl,
      );

  /// Whether a user is currently signed in.
  bool get isSignedIn => _auth.currentUser != null;

  /// Current user's id, or null.
  String? get currentUserId => _auth.currentUser?.id;
}
