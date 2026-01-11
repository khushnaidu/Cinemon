import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/user_repository.dart';
import '../../models/user_model.dart';

/// Provider for AuthRepository instance
///
/// Makes the repository available throughout the app
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

/// Stream provider that watches Firebase auth state changes
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
    } on FirebaseAuthException catch (e) {
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
  Future<void> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final user = await _authRepository.signUp(email: email, password: password);

      // Create user profile in Firestore with username
      if (user != null) {
        final userRepo = UserRepository();
        final userModel = UserModel(
          uid: user.uid,
          email: email,
          username: username.toLowerCase(),
          displayName: username,
          createdAt: DateTime.now(),
        );
        await userRepo.createUser(userModel);
      }

      state = state.copyWith(isLoading: false);
    } on FirebaseAuthException catch (e) {
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
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _getErrorMessage(e),
      );
    }
  }

  /// Convert Firebase auth errors to user-friendly messages
  String _getErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email';
      case 'wrong-password':
        return 'Wrong password';
      case 'email-already-in-use':
        return 'An account already exists with this email';
      case 'weak-password':
        return 'Password is too weak';
      case 'invalid-email':
        return 'Invalid email address';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later';
      default:
        return 'Authentication error: ${e.message}';
    }
  }

  /// Clear error message
  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}
