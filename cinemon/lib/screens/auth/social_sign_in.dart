import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../core/routes/redirect_hold.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/auth_errors.dart';
import '../../providers/auth/auth_provider.dart';
import '../../providers/auth/onboarding_provider.dart';
import '../../providers/feed/feed_provider.dart';
import '../../providers/follow/follow_provider.dart' show followingIdsProvider;
import '../../repositories/auth_repository.dart' show SocialSignInCancelled;
import '../widgets/glass_panel.dart';

/// "or", then Continue with Apple and Continue with Google (ADR 0004 D6).
///
/// Apple's button is Apple's own, first and the same size as Google's, as
/// Apple's guidelines ask. Either one signs in or creates the account; new
/// accounts then meet the agree screen (age and terms) and onboarding, the
/// same as an email sign-up.
class SocialSignInButtons extends ConsumerStatefulWidget {
  const SocialSignInButtons({super.key});

  @override
  ConsumerState<SocialSignInButtons> createState() =>
      _SocialSignInButtonsState();
}

/// Both buttons' height. Apple's text is 0.43 of it; Google's matches.
const _kHeight = 40.0;

class _SocialSignInButtonsState extends ConsumerState<SocialSignInButtons> {
  bool _busy = false;

  Future<void> _run(Future<Object?> Function() signIn) async {
    if (_busy) return;
    setState(() => _busy = true);
    // As with email: the splash plays before Home.
    authRedirectHold.value = true;
    try {
      await signIn();
      if (!mounted) return;
      ref.invalidate(currentUserProfileProvider);
      ref.invalidate(homeFeedProvider);
      ref.invalidate(followingIdsProvider);
      ref.invalidate(onboardedProvider);
      ref.invalidate(termsStatusProvider);
      context.go('/');
    } on SocialSignInCancelled {
      // Closed the sheet: nothing to say.
    } catch (e) {
      if (mounted) {
        showGlassToast(context, describeAuthError(e), destructive: true);
      }
    } finally {
      authRedirectHold.value = false;
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(authRepositoryProvider);
    return IgnorePointer(
      ignoring: _busy,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: _busy ? 0.5 : 1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                    child: Divider(color: AppColors.separator, thickness: 0.5)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
                  child: Text('or',
                      style: AppText.caption
                          .copyWith(color: AppColors.inkTertiary)),
                ),
                const Expanded(
                    child: Divider(color: AppColors.separator, thickness: 0.5)),
              ],
            ),
            const SizedBox(height: AppSpace.md),
            // Narrower than the fields, so Log in stays the main action.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SignInWithAppleButton(
                    text: 'Continue with Apple',
                    height: _kHeight,
                    style: SignInWithAppleButtonStyle.white,
                    borderRadius: BorderRadius.circular(_kHeight / 2),
                    onPressed: () => _run(repo.signInWithApple),
                  ),
                  const SizedBox(height: AppSpace.sm),
                  _GoogleButton(onPressed: () => _run(repo.signInWithGoogle)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Google's standard light button: white, the four-colour G, and
/// "Continue with Google" (Google's sign-in branding guidelines).
class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.onPressed});

  final VoidCallback onPressed;

  static const _g = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">
<path fill="#EA4335" d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z"/>
<path fill="#4285F4" d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z"/>
<path fill="#FBBC05" d="M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z"/>
<path fill="#34A853" d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z"/>
</svg>''';

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Continue with Google',
      child: GlassPressable(
        onTap: onPressed,
        child: Container(
          height: _kHeight,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(_kHeight / 2),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.string(_g, width: 15, height: 15),
              const SizedBox(width: 8),
              const Text(
                'Continue with Google',
                style: TextStyle(
                  color: Color(0xFF1F1F1F),
                  fontSize: _kHeight * 0.43,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.41,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
