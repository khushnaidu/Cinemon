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
/// On success the fields fall away and the logo zooms through the screen,
/// then the router takes over: Home, or onboarding for a new account.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();
  String? _emailError;
  String? _passwordError;

  late final _exit = AnimationController(
    duration: const Duration(milliseconds: 1400),
    vsync: this,
  );
  late final _fieldsFade = CurvedAnimation(
      parent: _exit, curve: const Interval(0, 0.25, curve: Curves.easeInCubic));
  late final _logoZoom = CurvedAnimation(
      parent: _exit,
      curve: const Interval(0.2, 1, curve: Curves.easeInOutCubic));
  late final _logoFade = CurvedAnimation(
      parent: _exit, curve: const Interval(0.7, 1, curve: Curves.easeInCubic));

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    _exit.dispose();
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

    // Hold the redirect so the zoom plays; released below either way.
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

    await _exit.forward();
    authRedirectHold.value = false;
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(authControllerProvider).isLoading;

    Widget fading(Widget child) => AnimatedBuilder(
          animation: _fieldsFade,
          builder: (_, c) => Opacity(
            opacity: 1 - _fieldsFade.value,
            child:
                Transform.scale(scale: 1 - 0.25 * _fieldsFade.value, child: c),
          ),
          child: child,
        );

    return AuthScaffold(
      header: AnimatedBuilder(
        animation: _exit,
        builder: (_, child) => Opacity(
          opacity: 1 - _logoFade.value,
          child: Transform.scale(scale: 1 + 3 * _logoZoom.value, child: child),
        ),
        child: const AuthLogo(),
      ),
      children: [
        fading(Column(
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
        )),
      ],
    );
  }
}
