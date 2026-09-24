import 'package:supabase_flutter/supabase_flutter.dart' show User;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/auth_errors.dart';
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

/// Controller for signing in and out, with a loading flag and a readable
/// error. Sign-up, codes and password resets live on their own screens and
/// call [AuthRepository] directly (ADR 0004 D4).
class AuthController extends StateNotifier<AuthState> {
  final AuthRepository _authRepository;

  AuthController(this._authRepository) : super(AuthState());

  /// The raw error from the last sign-in, so the screen can tell an
  /// unconfirmed email (go to the code screen) from a wrong password.
  Object? lastError;

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    lastError = null;
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _authRepository.signIn(email: email, password: password);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      lastError = e;
      state =
          state.copyWith(isLoading: false, errorMessage: describeAuthError(e));
    }
  }

  Future<void> signOut() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _authRepository.signOut();
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state =
          state.copyWith(isLoading: false, errorMessage: 'Failed to sign out');
    }
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}
