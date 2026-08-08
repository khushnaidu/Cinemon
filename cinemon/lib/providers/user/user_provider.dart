import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/user_model.dart';
import '../../repositories/user_repository.dart';
import '../auth/auth_provider.dart';
import '../feed/feed_provider.dart' show userRepositoryProvider;

// Re-export userRepositoryProvider from feed_provider for convenience
export '../feed/feed_provider.dart' show userRepositoryProvider;

/// Provider to check if the current user has completed profile setup
/// Returns true if profile exists with a username set, false otherwise
final isProfileCompleteProvider = FutureProvider<bool>((ref) async {
  final authState = ref.watch(authStateProvider);

  return authState.when(
    data: (user) async {
      if (user == null) return false;

      final userRepo = ref.read(userRepositoryProvider);
      final userProfile = await userRepo.getUser(user.uid);

      // Profile is complete if user document exists and has a username
      return userProfile != null && userProfile.username.isNotEmpty;
    },
    loading: () => false,
    error: (_, __) => false,
  );
});

/// Stream provider for real-time current user profile updates
/// Use this when you need live updates to the profile
final currentUserProfileStreamProvider = StreamProvider<UserModel?>((ref) {
  final authState = ref.watch(authStateProvider);

  return authState.when(
    data: (user) {
      if (user == null) return Stream.value(null);

      final userRepo = ref.read(userRepositoryProvider);
      return userRepo.watchUser(user.uid);
    },
    loading: () => Stream.value(null),
    error: (_, __) => Stream.value(null),
  );
});

/// State for profile setup operations
class ProfileSetupState {
  final bool isLoading;
  final bool isCheckingUsername;
  final bool isUsernameAvailable;
  final String? usernameError;
  final String? errorMessage;
  final bool isComplete;

  ProfileSetupState({
    this.isLoading = false,
    this.isCheckingUsername = false,
    this.isUsernameAvailable = true,
    this.usernameError,
    this.errorMessage,
    this.isComplete = false,
  });

  ProfileSetupState copyWith({
    bool? isLoading,
    bool? isCheckingUsername,
    bool? isUsernameAvailable,
    String? usernameError,
    String? errorMessage,
    bool? isComplete,
  }) {
    return ProfileSetupState(
      isLoading: isLoading ?? this.isLoading,
      isCheckingUsername: isCheckingUsername ?? this.isCheckingUsername,
      isUsernameAvailable: isUsernameAvailable ?? this.isUsernameAvailable,
      usernameError: usernameError,
      errorMessage: errorMessage,
      isComplete: isComplete ?? this.isComplete,
    );
  }
}

/// Controller for profile setup operations
final profileSetupControllerProvider =
    StateNotifierProvider<ProfileSetupController, ProfileSetupState>((ref) {
  final userRepo = ref.watch(userRepositoryProvider);
  final currentUser = ref.watch(currentUserProvider);
  return ProfileSetupController(userRepo, currentUser);
});

class ProfileSetupController extends StateNotifier<ProfileSetupState> {
  final UserRepository _userRepo;
  final User? _currentUser;

  ProfileSetupController(this._userRepo, this._currentUser)
      : super(ProfileSetupState());

  /// Check if a username is available
  Future<void> checkUsernameAvailability(String username) async {
    if (username.isEmpty || username.length < 3) {
      state = state.copyWith(
        isCheckingUsername: false,
        isUsernameAvailable: false,
        usernameError: username.isEmpty ? null : 'Username must be at least 3 characters',
      );
      return;
    }

    // Validate username format
    final usernameRegex = RegExp(r'^[a-zA-Z0-9_]+$');
    if (!usernameRegex.hasMatch(username)) {
      state = state.copyWith(
        isCheckingUsername: false,
        isUsernameAvailable: false,
        usernameError: 'Only letters, numbers, and underscores allowed',
      );
      return;
    }

    state = state.copyWith(isCheckingUsername: true, usernameError: null);

    try {
      final isAvailable = await _userRepo.isUsernameAvailable(username.toLowerCase());
      state = state.copyWith(
        isCheckingUsername: false,
        isUsernameAvailable: isAvailable,
        usernameError: isAvailable ? null : 'Username is already taken',
      );
    } catch (e) {
      state = state.copyWith(
        isCheckingUsername: false,
        isUsernameAvailable: false,
        usernameError: 'Error checking username',
      );
    }
  }

  /// Upload profile photo to Supabase Storage; returns its public URL.
  Future<String?> uploadProfilePhoto(File imageFile) async {
    final user = _currentUser;
    if (user == null) return null;

    try {
      return await _userRepo.uploadAvatar(user.uid, imageFile);
    } catch (e) {
      debugPrint('Error uploading profile photo: $e');
      return null;
    }
  }

  /// Complete profile setup - fills in the auto-created profiles row
  Future<bool> completeProfileSetup({
    required String username,
    String? bio,
    File? photoFile,
  }) async {
    final user = _currentUser;
    if (user == null) {
      state = state.copyWith(errorMessage: 'Not authenticated');
      return false;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      // Upload photo if provided
      String? photoUrl;
      if (photoFile != null) {
        photoUrl = await uploadProfilePhoto(photoFile);
      }

      // Create user profile
      final userModel = UserModel(
        uid: user.uid,
        email: user.email ?? '',
        username: username.toLowerCase(),
        displayName: username,
        photoUrl: photoUrl,
        bio: bio,
        createdAt: DateTime.now(),
      );

      await _userRepo.createUser(userModel);

      state = state.copyWith(isLoading: false, isComplete: true);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to create profile: ${e.toString()}',
      );
      return false;
    }
  }

  /// Clear error message
  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  /// Reset state
  void reset() {
    state = ProfileSetupState();
  }
}

// ============================================================================
// Edit Profile (for existing users)
// ============================================================================

/// State for edit profile operations
class EditProfileState {
  final bool isLoading;
  final bool isCheckingUsername;
  final bool isUsernameAvailable;
  final String? usernameError;
  final String? errorMessage;

  EditProfileState({
    this.isLoading = false,
    this.isCheckingUsername = false,
    this.isUsernameAvailable = true,
    this.usernameError,
    this.errorMessage,
  });

  EditProfileState copyWith({
    bool? isLoading,
    bool? isCheckingUsername,
    bool? isUsernameAvailable,
    String? usernameError,
    String? errorMessage,
  }) {
    return EditProfileState(
      isLoading: isLoading ?? this.isLoading,
      isCheckingUsername: isCheckingUsername ?? this.isCheckingUsername,
      isUsernameAvailable: isUsernameAvailable ?? this.isUsernameAvailable,
      usernameError: usernameError,
      errorMessage: errorMessage,
    );
  }
}

/// Controller for edit profile operations
final editProfileControllerProvider =
    StateNotifierProvider<EditProfileController, EditProfileState>((ref) {
  final userRepo = ref.watch(userRepositoryProvider);
  final currentUser = ref.watch(currentUserProvider);
  return EditProfileController(userRepo, currentUser);
});

class EditProfileController extends StateNotifier<EditProfileState> {
  final UserRepository _userRepo;
  final User? _currentUser;

  EditProfileController(this._userRepo, this._currentUser)
      : super(EditProfileState());

  /// Check if a username is available
  Future<void> checkUsernameAvailability(String username) async {
    if (username.isEmpty || username.length < 3) {
      state = state.copyWith(
        isCheckingUsername: false,
        isUsernameAvailable: false,
        usernameError: username.isEmpty ? null : 'Username must be at least 3 characters',
      );
      return;
    }

    // Validate username format
    final usernameRegex = RegExp(r'^[a-zA-Z0-9_]+$');
    if (!usernameRegex.hasMatch(username)) {
      state = state.copyWith(
        isCheckingUsername: false,
        isUsernameAvailable: false,
        usernameError: 'Only letters, numbers, and underscores allowed',
      );
      return;
    }

    state = state.copyWith(isCheckingUsername: true, usernameError: null);

    try {
      final isAvailable = await _userRepo.isUsernameAvailable(username.toLowerCase());
      state = state.copyWith(
        isCheckingUsername: false,
        isUsernameAvailable: isAvailable,
        usernameError: isAvailable ? null : 'Username is already taken',
      );
    } catch (e) {
      state = state.copyWith(
        isCheckingUsername: false,
        isUsernameAvailable: false,
        usernameError: 'Error checking username',
      );
    }
  }

  /// Clear username check state (when username matches original)
  void clearUsernameCheck() {
    state = state.copyWith(
      isCheckingUsername: false,
      isUsernameAvailable: true,
      usernameError: null,
    );
  }

  /// Upload profile photo to Supabase Storage; returns its public URL.
  Future<String?> _uploadProfilePhoto(File imageFile) async {
    final user = _currentUser;
    if (user == null) return null;

    try {
      return await _userRepo.uploadAvatar(user.uid, imageFile);
    } catch (e) {
      debugPrint('Error uploading profile photo: $e');
      return null;
    }
  }

  /// Update user profile
  Future<bool> updateProfile({
    required String username,
    String? bio,
    File? photoFile,
  }) async {
    final user = _currentUser;
    if (user == null) {
      state = state.copyWith(errorMessage: 'Not authenticated');
      return false;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      // Get current profile
      final currentProfile = await _userRepo.getUser(user.uid);
      if (currentProfile == null) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Profile not found',
        );
        return false;
      }

      // Upload new photo if provided
      String? photoUrl = currentProfile.photoUrl;
      if (photoFile != null) {
        final uploadedUrl = await _uploadProfilePhoto(photoFile);
        if (uploadedUrl != null) {
          photoUrl = uploadedUrl;
        }
      }

      // Update profile
      final updatedProfile = currentProfile.copyWith(
        username: username.toLowerCase(),
        displayName: username,
        photoUrl: photoUrl,
        bio: bio,
      );

      await _userRepo.updateUser(updatedProfile);

      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to update profile: ${e.toString()}',
      );
      return false;
    }
  }

  /// Clear error message
  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  /// Reset state
  void reset() {
    state = EditProfileState();
  }
}
