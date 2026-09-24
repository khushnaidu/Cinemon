import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routes/redirect_hold.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/auth_errors.dart';
import '../../providers/auth/auth_provider.dart';
import '../../providers/auth/onboarding_provider.dart';
import '../../providers/feed/feed_provider.dart';
import '../../providers/friendship/friendship_provider.dart';
import '../widgets/glass_panel.dart';
import '../widgets/glass_text_field.dart';
import 'auth_scaffold.dart';

/// Log in with email and password (ADR 0004 D8).
///
/// On success the splash GIF plays again as the way in, then the router
/// takes over: Home, or onboarding for a new account.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();
  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    // Never leave the router stuck on this screen.
    authRedirectHold.value = false;
    super.dispose();
  }

  bool _validate() {
    final email = _email.text.trim();
    setState(() {
      _emailError = email.isEmpty
          ? 'Enter your email'
          : (!email.contains('@') ? 'That email doesn\'t look right' : null);
      _passwordError = _password.text.isEmpty ? 'Enter your password' : null;
    });
    return _emailError == null && _passwordError == null;
  }

  Future<void> _logIn() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_validate()) return;
    final email = _email.text.trim();

    // Hold the redirect so signing in doesn't jump straight to Home; the
    // splash goes first. Released below either way.
    authRedirectHold.value = true;
    final auth = ref.read(authControllerProvider.notifier);
    await auth.signIn(email: email, password: _password.text);
    if (!mounted) return;

    final error = auth.lastError;
    if (error != null) {
      authRedirectHold.value = false;
      if (isUnconfirmedEmail(error)) {
        // Their code may be long gone: send a fresh one and go enter it.
        try {
          await ref.read(authRepositoryProvider).resendEmailCode(email: email);
        } catch (_) {}
        if (!mounted) return;
        context.push(Uri(
          path: '/verify',
          queryParameters: {'email': email, 'purpose': 'signup'},
        ).toString());
        return;
      }
      showGlassToast(context, describeAuthError(error), destructive: true);
      return;
    }

    // Nothing from the last account carries over.
    ref.invalidate(currentUserProfileProvider);
    ref.invalidate(homeFeedProvider);
    ref.invalidate(friendIdsProvider);
    ref.invalidate(onboardedProvider);

    // The splash plays its GIF, then moves on to /login, which the router
    // turns into Home or onboarding.
    context.go('/');
    authRedirectHold.value = false;
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(authControllerProvider).isLoading;

    return AuthScaffold(
      header: const AuthLogo(),
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GlassTextField(
              controller: _email,
              placeholder: 'Email',
              icon: CupertinoIcons.mail,
              errorText: _emailError,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              onChanged: (_) {
                if (_emailError != null) setState(() => _emailError = null);
              },
              onSubmitted: (_) => _passwordFocus.requestFocus(),
            ),
            const SizedBox(height: AppSpace.md),
            GlassTextField(
              controller: _password,
              focusNode: _passwordFocus,
              placeholder: 'Password',
              icon: CupertinoIcons.lock,
              obscure: true,
              errorText: _passwordError,
              textInputAction: TextInputAction.go,
              autofillHints: const [AutofillHints.password],
              onChanged: (_) {
                if (_passwordError != null) {
                  setState(() => _passwordError = null);
                }
              },
              onSubmitted: (_) => _logIn(),
            ),
            AuthTextButton(
              label: 'Forgot password?',
              alignment: Alignment.centerRight,
              onTap: () => context.push(Uri(
                path: '/forgot',
                queryParameters: {
                  if (_email.text.trim().isNotEmpty)
                    'email': _email.text.trim(),
                },
              ).toString()),
            ),
            const SizedBox(height: AppSpace.md),
            GlassPillButton(
              label: 'Log in',
              prominent: true,
              expand: true,
              busy: busy,
              onTap: _logIn,
            ),
            const SizedBox(height: AppSpace.lg),
            AuthLinkRow(
              prompt: 'New to 35mm?',
              action: 'Create an account',
              onTap: () => context.go('/signup'),
            ),
          ],
        ),
      ],
    );
  }
}
