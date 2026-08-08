import 'dart:async';
import '../core/theme/app_theme.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/user_model.dart';
import '../providers/user/user_provider.dart';
import '../providers/feed/feed_provider.dart';

/// Edit profile screen for updating username, photo, and bio
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();
  File? _selectedImage;
  Timer? _debounceTimer;
  bool _isInitialized = false;
  String? _originalUsername;
  bool _hasChanges = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _bioController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _initializeFromProfile(UserModel profile) {
    if (!_isInitialized) {
      _usernameController.text = profile.username;
      _bioController.text = profile.bio ?? '';
      _originalUsername = profile.username;
      _isInitialized = true;
    }
  }

  void _onUsernameChanged(String value) {
    _checkForChanges();

    // Don't check availability if it's the same as original
    if (value.toLowerCase() == _originalUsername?.toLowerCase()) {
      ref.read(editProfileControllerProvider.notifier).clearUsernameCheck();
      return;
    }

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      ref.read(editProfileControllerProvider.notifier)
          .checkUsernameAvailability(value.trim());
    });
  }

  void _checkForChanges() {
    final profile = ref.read(currentUserProfileProvider).value;
    if (profile == null) return;

    setState(() {
      _hasChanges = _usernameController.text.trim() != profile.username ||
          _bioController.text.trim() != (profile.bio ?? '') ||
          _selectedImage != null;
    });
  }

  ImageProvider? _getProfileImage(String? photoUrl) {
    if (_selectedImage != null) {
      return FileImage(_selectedImage!);
    }
    if (photoUrl != null) {
      return CachedNetworkImageProvider(photoUrl);
    }
    return null;
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 90,
    );

    if (pickedFile != null) {
      // Crop the image to a circle-friendly square
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        compressQuality: 80,
        maxWidth: 512,
        maxHeight: 512,
        uiSettings: [
          IOSUiSettings(
            title: 'Crop Photo',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
            aspectRatioPickerButtonHidden: true,
            rotateButtonsHidden: false,
            rotateClockwiseButtonHidden: true,
          ),
          AndroidUiSettings(
            toolbarTitle: 'Crop Photo',
            toolbarColor: Colors.black,
            toolbarWidgetColor: Colors.white,
            backgroundColor: Colors.black,
            activeControlsWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
            hideBottomControls: false,
          ),
        ],
      );

      if (croppedFile != null) {
        setState(() {
          _selectedImage = File(croppedFile.path);
          _hasChanges = true;
        });
      }
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final editState = ref.read(editProfileControllerProvider);
    final newUsername = _usernameController.text.trim();

    // Check if username changed and if it's available
    if (newUsername.toLowerCase() != _originalUsername?.toLowerCase() &&
        !editState.isUsernameAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please choose an available username'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final success = await ref.read(editProfileControllerProvider.notifier)
        .updateProfile(
          username: newUsername,
          bio: _bioController.text.trim().isEmpty
              ? null
              : _bioController.text.trim(),
          photoFile: _selectedImage,
        );

    if (success && mounted) {
      // Refresh the profile data
      ref.invalidate(currentUserProfileProvider);

      // Sync user data to all existing activities (updates old posts)
      ref.invalidate(syncUserDataProvider(null));
      await ref.read(syncUserDataProvider(null).future);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentUserProfileProvider);
    final editState = ref.watch(editProfileControllerProvider);

    // Show error snackbar if there's an error
    ref.listen<EditProfileState>(editProfileControllerProvider, (prev, next) {
      if (next.errorMessage != null && prev?.errorMessage != next.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: Colors.red,
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Edit Profile',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _hasChanges && !editState.isLoading ? _handleSave : null,
            child: Text(
              'Save',
              style: TextStyle(
                color: _hasChanges && !editState.isLoading
                    ? Colors.white
                    : Colors.white38,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black,
              AppColors.canvas,
            ],
          ),
        ),
        child: profileAsync.when(
          data: (profile) {
            if (profile == null) {
              return const Center(
                child: Text(
                  'Profile not found',
                  style: TextStyle(color: Colors.white),
                ),
              );
            }

            _initializeFromProfile(profile);

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const SizedBox(height: 20),

                    // Profile Photo
                    GestureDetector(
                      onTap: _pickImage,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 60,
                            backgroundColor: Colors.white24,
                            backgroundImage: _getProfileImage(profile.photoUrl),
                            child: _selectedImage == null && profile.photoUrl == null
                                ? const Icon(
                                    Icons.person,
                                    size: 60,
                                    color: Colors.white54,
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                size: 20,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Tap to change photo',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Username Field
                    TextFormField(
                      controller: _usernameController,
                      onChanged: _onUsernameChanged,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Username',
                        labelStyle: const TextStyle(color: Colors.white70),
                        prefixIcon: const Icon(
                          Icons.alternate_email,
                          color: Colors.white54,
                        ),
                        suffixIcon: _buildUsernameSuffix(editState),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.1),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: _getUsernameBorderColor(editState),
                            width: 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: _getUsernameBorderColor(editState),
                            width: 2,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Username is required';
                        }
                        if (value.length < 3) {
                          return 'Username must be at least 3 characters';
                        }
                        if (value.contains(' ')) {
                          return 'Username cannot contain spaces';
                        }
                        final usernameRegex = RegExp(r'^[a-zA-Z0-9_]+$');
                        if (!usernameRegex.hasMatch(value)) {
                          return 'Only letters, numbers, and underscores';
                        }
                        return null;
                      },
                    ),
                    if (editState.usernameError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          editState.usernameError!,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),

                    // Bio Field
                    TextFormField(
                      controller: _bioController,
                      onChanged: (_) => _checkForChanges(),
                      maxLines: 4,
                      maxLength: 150,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Bio',
                        labelStyle: const TextStyle(color: Colors.white70),
                        hintText: 'Tell us about yourself...',
                        hintStyle: const TextStyle(color: Colors.white38),
                        counterStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.1),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Colors.white24,
                            width: 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Colors.white,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Loading indicator
                    if (editState.isLoading)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          error: (error, _) => Center(
            child: Text(
              'Error: $error',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ),
      ),
    );
  }

  Widget? _buildUsernameSuffix(EditProfileState state) {
    final currentUsername = _usernameController.text.trim().toLowerCase();

    // Don't show indicator if username hasn't changed
    if (currentUsername == _originalUsername?.toLowerCase()) {
      return null;
    }

    if (currentUsername.isEmpty) return null;

    if (state.isCheckingUsername) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white54),
          ),
        ),
      );
    }

    if (state.isUsernameAvailable && state.usernameError == null) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Icon(
          Icons.check_circle,
          color: Colors.greenAccent,
          size: 20,
        ),
      );
    }

    if (state.usernameError != null || !state.isUsernameAvailable) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Icon(
          Icons.cancel,
          color: Colors.redAccent,
          size: 20,
        ),
      );
    }

    return null;
  }

  Color _getUsernameBorderColor(EditProfileState state) {
    final currentUsername = _usernameController.text.trim().toLowerCase();

    // Default color if username hasn't changed
    if (currentUsername == _originalUsername?.toLowerCase()) {
      return Colors.white24;
    }

    if (currentUsername.isEmpty || state.isCheckingUsername) {
      return Colors.white24;
    }
    if (state.isUsernameAvailable && state.usernameError == null) {
      return Colors.greenAccent;
    }
    return Colors.redAccent;
  }
}
