import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart'
    show CupertinoActivityIndicator, CupertinoIcons, CupertinoSwitch;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../core/theme/app_theme.dart';
import '../../core/utils/auth_errors.dart';
import '../../core/utils/auth_rules.dart';
import '../../providers/auth/auth_provider.dart';
import '../../providers/auth/onboarding_provider.dart';
import '../../providers/feed/feed_provider.dart';
import '../widgets/glass_panel.dart';
import '../widgets/glass_text_field.dart';
import 'auth_scaffold.dart';

/// The first thing every new account does (ADR 0004 D7): pick a username,
/// then optionally a photo, name and bio. Email, Apple and Google sign-ups
/// all land here; nothing is saved until Finish, so backing out leaves the
/// account as it was.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

enum _Availability { unknown, checking, free, taken, error }

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _username = TextEditingController();
  final _name = TextEditingController();
  final _bio = TextEditingController();
  int _step = 0;
  bool _prefilled = false;
  bool _saving = false;

  String? _usernameError;
  _Availability _availability = _Availability.unknown;
  Timer? _debounce;
  int _checkSeq = 0;

  File? _photo;
  String? _existingPhotoUrl;

  /// Public by default (ADR 0004 D3).
  bool _private = false;

  @override
  void dispose() {
    _username.dispose();
    _name.dispose();
    _bio.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  /// Once the profile arrives: the provider's name and photo, and a username
  /// guessed from them or the email.
  void _prefill() {
    if (_prefilled) return;
    final profile = ref.read(currentUserProfileProvider).valueOrNull;
    final user = ref.read(currentUserProvider);
    if (profile == null || user == null) return;
    _prefilled = true;
    _name.text = profile.displayName ?? '';
    _existingPhotoUrl = profile.photoUrl;
    final suggestion =
        suggestUsername(email: user.email, name: profile.displayName);
    if (suggestion.isNotEmpty) {
      _username.text = suggestion;
      _check(suggestion);
    }
  }

  void _onUsernameChanged(String raw) {
    final name = normaliseUsername(raw);
    if (name != raw) {
      _username.value = TextEditingValue(
        text: name,
        selection: TextSelection.collapsed(offset: name.length),
      );
    }
    _debounce?.cancel();
    final problem = usernameProblem(name);
    setState(() {
      _usernameError = name.isEmpty ? null : problem;
      _availability =
          problem == null ? _Availability.checking : _Availability.unknown;
    });
    if (problem != null) return;
    _debounce = Timer(const Duration(milliseconds: 350), () => _check(name));
  }

  Future<void> _check(String name) async {
    final seq = ++_checkSeq;
    setState(() => _availability = _Availability.checking);
    try {
      final free =
          await ref.read(userRepositoryProvider).isUsernameAvailable(name);
      if (!mounted || seq != _checkSeq) return;
      setState(() {
        _availability = free ? _Availability.free : _Availability.taken;
        _usernameError = free ? null : '@$name is taken';
      });
    } catch (_) {
      if (!mounted || seq != _checkSeq) return;
      setState(() => _availability = _Availability.error);
    }
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 90,
    );
    if (picked == null) return;
    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
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
          rotateClockwiseButtonHidden: true,
        ),
      ],
    );
    if (cropped != null && mounted) {
      setState(() => _photo = File(cropped.path));
    }
  }

  Future<void> _finish() async {
    final user = ref.read(currentUserProvider);
    if (user == null || _saving) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _saving = true);
    final repo = ref.read(userRepositoryProvider);
    try {
      String? photoUrl = _existingPhotoUrl;
      if (_photo != null) photoUrl = await repo.uploadAvatar(user.id, _photo!);
      final name = _name.text.trim();
      final bio = _bio.text.trim();
      await repo.updateUserFields(uid: user.id, fields: {
        'username': _username.text,
        'display_name': name.isEmpty ? null : name,
        'bio': bio.isEmpty ? null : bio,
        'photo_url': photoUrl,
        'is_private': _private,
        'onboarded_at': DateTime.now().toUtc().toIso8601String(),
      });
      ref.invalidate(currentUserProfileProvider);
      // The router hears this and moves on to Home.
      ref.invalidate(onboardedProvider);
    } on PostgrestException catch (e) {
      if (!mounted) return;
      if (e.code == '23505' || e.code == '23514') {
        // Someone took it in the meantime, or it slipped past the rules.
        setState(() {
          _step = 0;
          _availability = _Availability.taken;
          _usernameError = describeAuthError(e);
        });
      } else {
        showGlassToast(context, 'Couldn\'t save. Try again.',
            destructive: true);
      }
    } catch (_) {
      if (mounted) {
        showGlassToast(context, 'Couldn\'t save. Try again.',
            destructive: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(currentUserProfileProvider, (_, __) => _prefill());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _prefill();
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _step > 0) setState(() => _step = 0);
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: _step == 0
            ? KeyedSubtree(key: const ValueKey(0), child: _usernameStep())
            : KeyedSubtree(key: const ValueKey(1), child: _profileStep()),
      ),
    );
  }

  Widget _usernameStep() {
    final ok = _availability == _Availability.free;
    final trailing = switch (_availability) {
      _Availability.checking => const CupertinoActivityIndicator(radius: 9),
      _Availability.free => const Icon(CupertinoIcons.checkmark_circle_fill,
          size: 20, color: AppColors.success),
      _Availability.taken => const Icon(CupertinoIcons.xmark_circle_fill,
          size: 20, color: AppColors.destructive),
      _ => null,
    };
    return AuthScaffold(
      title: 'Choose a username',
      subtitle: 'It\'s how people find you and how you\'re tagged. '
          'You can change it later.',
      children: [
        GlassTextField(
          controller: _username,
          placeholder: 'username',
          icon: CupertinoIcons.at,
          autofocus: true,
          errorText: _usernameError,
          trailing: trailing,
          maxLength: 24,
          keyboardType: TextInputType.visiblePassword,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.newUsername],
          inputFormatters: [
            FilteringTextInputFormatter.deny(RegExp(r'[\s]')),
          ],
          onChanged: _onUsernameChanged,
          onSubmitted: (_) {
            if (ok) setState(() => _step = 1);
          },
          helper: _availability == _Availability.error
              ? Text('Couldn\'t check that name. Check your connection.',
                  style: AppText.caption.copyWith(color: AppColors.inkTertiary))
              : Text('Lowercase letters, numbers, _ and .',
                  style:
                      AppText.caption.copyWith(color: AppColors.inkTertiary)),
        ),
        const SizedBox(height: AppSpace.xl),
        GlassPillButton(
          label: 'Continue',
          prominent: true,
          expand: true,
          onTap: ok ? () => setState(() => _step = 1) : null,
        ),
        const SizedBox(height: AppSpace.md),
        AuthTextButton(
          label: 'Not you? Log out',
          onTap: () async {
            await ref.read(authControllerProvider.notifier).signOut();
            if (mounted) context.go('/login');
          },
        ),
      ],
    );
  }

  Widget _profileStep() {
    const size = 112.0;
    ImageProvider? image;
    if (_photo != null) {
      image = FileImage(_photo!);
    } else if ((_existingPhotoUrl ?? '').isNotEmpty) {
      image = CachedNetworkImageProvider(_existingPhotoUrl!);
    }
    return AuthScaffold(
      title: 'Make it yours',
      subtitle: '@${_username.text}. Add a photo and a few words; both are '
          'optional.',
      onBack: _saving ? null : () => setState(() => _step = 0),
      children: [
        Center(
          child: GestureDetector(
            onTap: _pickPhoto,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.07),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.13),
                        width: 0.8),
                    image: image == null
                        ? null
                        : DecorationImage(image: image, fit: BoxFit.cover),
                  ),
                  child: image == null
                      ? const Icon(CupertinoIcons.person_fill,
                          size: 48, color: AppColors.inkTertiary)
                      : null,
                ),
                Positioned(
                  right: 2,
                  bottom: 2,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.surfaceElevated,
                      border: Border.all(color: AppColors.canvas, width: 2),
                    ),
                    child: const Icon(CupertinoIcons.camera_fill,
                        size: 16, color: AppColors.ink),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpace.xl),
        GlassTextField(
          controller: _name,
          placeholder: 'Name',
          icon: CupertinoIcons.person,
          maxLength: 40,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.name],
        ),
        const SizedBox(height: AppSpace.md),
        GlassTextWell(
          controller: _bio,
          hint: 'Bio: what you watch, what you\'re into',
          maxLength: 150,
          minLines: 3,
          maxLines: 5,
        ),
        const SizedBox(height: AppSpace.md),
        Container(
          decoration: glassWellDecoration(),
          child: GlassMenuRow(
            icon:
                _private ? CupertinoIcons.lock_fill : CupertinoIcons.lock_open,
            title: 'Private account',
            subtitle: _private
                ? 'Only people you approve see your posts'
                : 'Anyone can see your posts and follow you',
            trailing: CupertinoSwitch(
              value: _private,
              activeTrackColor: AppColors.success,
              onChanged: (v) => setState(() => _private = v),
            ),
            onTap: () => setState(() => _private = !_private),
          ),
        ),
        const SizedBox(height: AppSpace.xl),
        GlassPillButton(
          label: 'Finish',
          prominent: true,
          expand: true,
          busy: _saving,
          onTap: _finish,
        ),
      ],
    );
  }
}
