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

  /// Create an account with email and password (ADR 0004 D4).
  ///
  /// With email confirmation on, there's no session yet: Supabase emails a
  /// 6-digit code and [verifyEmailCode] finishes the sign-up. The username is
  /// chosen afterwards, in onboarding.
  ///
  /// Throws [AuthException] on failure, including when the email is already
  /// registered: Supabase hides that by returning a user with no identities,
  /// which would leave someone waiting for a code that never comes.
  /// [agreement] is what the sign-up screen confirmed (terms version, age
  /// confirmed, under 18); migration 021 copies it onto the profile.
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    Map<String, dynamic>? agreement,
  }) async {
    final response =
        await _auth.signUp(email: email, password: password, data: agreement);
    final identities = response.user?.identities;
    if (response.session == null && identities != null && identities.isEmpty) {
      throw const AuthException('User already registered',
          code: 'user_already_exists');
    }
    return response;
  }

  /// Finish a sign-up with the code from the email. Signs the user in.
  Future<void> verifyEmailCode({
    required String email,
    required String code,
  }) =>
      _auth.verifyOTP(email: email, token: code, type: OtpType.signup);

  /// Send the sign-up code again.
  Future<void> resendEmailCode({required String email}) =>
      _auth.resend(email: email, type: OtpType.signup);

  /// Start a password reset: Supabase emails a 6-digit code.
  Future<void> sendPasswordResetCode({required String email}) =>
      _auth.resetPasswordForEmail(email);

  /// Check the reset code. Signs the user in, so [updatePassword] can follow.
  Future<void> verifyResetCode({
    required String email,
    required String code,
  }) =>
      _auth.verifyOTP(email: email, token: code, type: OtpType.recovery);

  /// Set a new password for the signed-in user.
  Future<void> updatePassword(String password) =>
      _auth.updateUser(UserAttributes(password: password));

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

  /// Whether a user is currently signed in.
  bool get isSignedIn => _auth.currentUser != null;

  /// Current user's id, or null.
  String? get currentUserId => _auth.currentUser?.id;
}
