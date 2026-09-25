import 'dart:async';
import '../core/theme/app_theme.dart';
import 'dart:io';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import '../core/utils/auth_rules.dart' show usernameProblem;
import 'widgets/glass_panel.dart';
import 'widgets/glass_text_field.dart';
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
      ref
          .read(editProfileControllerProvider.notifier)
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
    final problem =
        usernameProblem(_usernameController.text.trim().toLowerCase());
    if (problem != null) {
      showGlassToast(context, problem, destructive: true);
      return;
    }

    final editState = ref.read(editProfileControllerProvider);
    final newUsername = _usernameController.text.trim();

    // Check if username changed and if it's available
    if (newUsername.toLowerCase() != _originalUsername?.toLowerCase() &&
        !editState.isUsernameAvailable) {
      showGlassToast(context, 'Please choose an available username',
          destructive: true);
      return;
    }

    final success =
        await ref.read(editProfileControllerProvider.notifier).updateProfile(
              username: newUsername,
              bio: _bioController.text.trim().isEmpty
                  ? null
                  : _bioController.text.trim(),
              photoFile: _selectedImage,
            );

    if (success && mounted) {
      // Posts read your name and photo live, so only the profile needs
      // refreshing.
      ref.invalidate(currentUserProfileProvider);
      showGlassToast(context, 'Profile updated');
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentUserProfileProvider);
    final editState = ref.watch(editProfileControllerProvider);

    // Show error snackbar if there's an error
    ref.listen<EditProfileState>(editProfileControllerProvider, (prev, next) {
      if (next.errorMessage != null &&
          prev?.errorMessage != next.errorMessage) {
        showGlassToast(context, next.errorMessage!, destructive: true);
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
                            child: _selectedImage == null &&
                                    profile.photoUrl == null
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
                    GlassTextField(
                      controller: _usernameController,
                      placeholder: 'username',
                      icon: CupertinoIcons.at,
                      maxLength: 24,
                      keyboardType: TextInputType.visiblePassword,
                      onChanged: _onUsernameChanged,
                      errorText: editState.usernameError,
                      trailing: _buildUsernameSuffix(editState),
                    ),
                    const SizedBox(height: 20),

                    // Bio Field
                    GlassTextWell(
                      controller: _bioController,
                      hint: 'Tell people what you watch',
                      maxLength: 150,
                      minLines: 3,
                      maxLines: 5,
                      onChanged: (_) => _checkForChanges(),
                    ),
                    const SizedBox(height: 32),

                    // Loading indicator
                    if (editState.isLoading)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
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
}
