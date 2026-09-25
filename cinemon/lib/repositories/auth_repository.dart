import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/social_auth.dart';
import '../core/config/supabase_config.dart';

/// The person closed the Apple or Google sheet without signing in. Not an
/// error to show.
class SocialSignInCancelled implements Exception {
  const SocialSignInCancelled();
}

/// Repository for Supabase Authentication operations.
///
/// This is the data layer — all direct auth interaction lives here.
/// UI should never call Supabase directly, always go through this repository.
class AuthRepository {
  final SupabaseClient _client;

  AuthRepository({SupabaseClient? client})
      : _client = client ?? SupabaseConfig.client;

  GoTrueClient get _auth => _client.auth;

  static bool _googleReady = false;

  /// Sign in with Apple, natively (ADR 0004 D6). A new account is created
  /// on the first go; the agree screen and onboarding follow.
  ///
  /// The nonce ties Apple's token to this request: Apple signs the hash,
  /// Supabase checks it against the original.
  Future<AuthResponse> signInWithApple() async {
    final rawNonce = _auth.generateRawNonce();
    final hashed = sha256.convert(utf8.encode(rawNonce)).toString();
    final AuthorizationCredentialAppleID credential;
    try {
      credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashed,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        throw const SocialSignInCancelled();
      }
      rethrow;
    }
    final token = credential.identityToken;
    if (token == null) {
      throw const AuthException('Apple didn\'t return a sign-in token.');
    }
    final res = await _auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: token,
      nonce: rawNonce,
    );
    // Apple gives the name only the first time someone signs in, and not in
    // the token: keep it, so onboarding can fill it in (Apple asks that
    // apps don't ask for it again).
    final name = [credential.givenName, credential.familyName]
        .whereType<String>()
        .where((p) => p.trim().isNotEmpty)
        .join(' ');
    final user = res.user;
    if (name.isNotEmpty && user != null) {
      try {
        await _auth.updateUser(UserAttributes(data: {'full_name': name}));
        await _client
            .from('profiles')
            .update({'display_name': name})
            .eq('id', user.id)
            .isFilter('display_name', null);
      } catch (_) {}
    }
    return res;
  }

  /// Sign in with Google, natively (ADR 0004 D6).
  Future<AuthResponse> signInWithGoogle() async {
    final google = GoogleSignIn.instance;
    if (!_googleReady) {
      await google.initialize(
        clientId: kGoogleIosClientId,
        serverClientId: kGoogleWebClientId,
      );
      _googleReady = true;
    }
    final GoogleSignInAccount account;
    try {
      account = await google.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const SocialSignInCancelled();
      }
      rethrow;
    }
    final token = account.authentication.idToken;
    if (token == null) {
      throw const AuthException('Google didn\'t return a sign-in token.');
    }
    return _auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: token,
    );
  }

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
  Future<void> signOut() async {
    // Forget the Google account too, so the next sign-in asks which one.
    if (_googleReady) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {}
    }
    await _auth.signOut();
  }

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
