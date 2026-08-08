import 'package:supabase_flutter/supabase_flutter.dart'
    show User, AuthException, PostgrestException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../repositories/auth_repository.dart';

/// Bridges Supabase's `User.id` to the `uid` name used throughout the app.
///
/// UserModel exposes `uid` (it maps to `profiles.id`), so keeping one name for
/// "the current user's identifier" avoids a mix of `.id` and `.uid` at call
/// sites — and avoids a rename sweep that could not distinguish the two types.
extension SupabaseUserCompat on User {
  String get uid => id;
}

/// Provider for AuthRepository instance
///
/// Makes the repository available throughout the app
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

/// Stream provider that watches Supabase auth state changes
///
/// Emits User when signed in, null when signed out
/// Use this to check if user is authenticated:
/// ```dart
/// final authState = ref.watch(authStateProvider);
/// authState.when(
///   data: (user) => user != null ? HomeScreen() : LoginScreen(),
///   loading: () => LoadingScreen(),
///   error: (err, stack) => ErrorScreen(),
/// )
/// ```
final authStateProvider = StreamProvider<User?>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  return authRepository.authStateChanges;
});

/// Provider for current user (reactive)
///
/// Returns User if signed in, null otherwise
/// This provider reacts to auth state changes - when user logs in/out,
/// all dependent providers will automatically update
final currentUserProvider = Provider<User?>((ref) {
  // Watch the auth state stream to react to auth changes
  final authState = ref.watch(authStateProvider);
  return authState.valueOrNull;
});

/// Provider for auth controller (sign in/up/out actions)
///
/// Use this to call auth methods from UI:
/// ```dart
/// final authController = ref.read(authControllerProvider.notifier);
/// await authController.signIn(email, password);
/// ```
final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  return AuthController(authRepository);
});

/// State for auth operations (loading, error, success)
class AuthState {
  final bool isLoading;
  final String? errorMessage;

  AuthState({
    this.isLoading = false,
    this.errorMessage,
  });

  AuthState copyWith({
    bool? isLoading,
    String? errorMessage,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

/// Controller for authentication actions
///
/// Handles sign in, sign up, sign out with loading states and error handling
class AuthController extends StateNotifier<AuthState> {
  final AuthRepository _authRepository;

  AuthController(this._authRepository) : super(AuthState());

  /// Sign in with email and password
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      await _authRepository.signIn(email: email, password: password);
      state = state.copyWith(isLoading: false);
    } on AuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _getErrorMessage(e),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'An unexpected error occurred',
      );
    }
  }

  /// Sign up with email and password
  ///
  /// The `on_auth_user_created` DB trigger creates the matching `profiles`
  /// row from the username metadata, so there is no second write here.
  Future<void> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      await _authRepository.signUp(
        email: email,
        password: password,
        username: username,
      );
      state = state.copyWith(isLoading: false);
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: _getErrorMessage(e));
    } on PostgrestException catch (e) {
      // unique_violation from the profiles.username index
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.code == '23505'
            ? 'That username is already taken'
            : 'Could not create your profile',
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'An unexpected error occurred',
      );
    }
  }

  /// Sign out current user
  Future<void> signOut() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      await _authRepository.signOut();
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to sign out',
      );
    }
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail({required String email}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      await _authRepository.sendPasswordResetEmail(email: email);
      state = state.copyWith(isLoading: false);
    } on AuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _getErrorMessage(e),
      );
    }
  }

  /// Convert Supabase auth errors to user-friendly messages
  String _getErrorMessage(AuthException e) {
    final msg = e.message.toLowerCase();

    if (msg.contains('invalid login credentials')) {
      return 'Incorrect email or password';
    }
    if (msg.contains('email not confirmed')) {
      return 'Please confirm your email before signing in';
    }
    if (msg.contains('already registered') ||
        msg.contains('already been registered')) {
      return 'An account already exists with this email';
    }
    if (msg.contains('password') && msg.contains('at least')) {
      return 'Password must be at least 6 characters';
    }
    if (msg.contains('unable to validate email') ||
        msg.contains('invalid email')) {
      return 'Invalid email address';
    }
    if (msg.contains('rate limit') || e.statusCode == '429') {
      return 'Too many attempts. Please try again later';
    }
    if (msg.contains('user not found')) {
      return 'No user found with this email';
    }
    return e.message;
  }

  /// Clear error message
  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}
