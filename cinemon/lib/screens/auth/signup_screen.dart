import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/auth_errors.dart';
import '../../core/utils/auth_rules.dart';
import '../../providers/auth/auth_provider.dart';
import '../widgets/glass_panel.dart';
import '../widgets/glass_text_field.dart';
import 'auth_scaffold.dart';

/// Create an account: email and password only (ADR 0004 D4, D5, D7).
///
/// Supabase emails a 6-digit code, entered on the next screen. The username
/// comes after that, in onboarding, the same way for every kind of sign-up.
class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();
  String? _emailError;
  String? _passwordError;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _password.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final email = _email.text.trim();
    setState(() {
      _emailError = email.isEmpty
          ? 'Enter your email'
          : (!email.contains('@') || !email.contains('.')
              ? 'That email doesn\'t look right'
              : null);
      _passwordError = passwordOk(_password.text)
          ? null
          : 'Use at least 8 characters, with a letter and a number';
    });
    if (_emailError != null || _passwordError != null) return;

    setState(() => _busy = true);
    try {
      final res = await ref
          .read(authRepositoryProvider)
          .signUp(email: email, password: _password.text);
      if (!mounted) return;
      // With confirmation off there's a session already, and the router
      // moves on to onboarding by itself.
      if (res.session == null) {
        context.push(Uri(
          path: '/verify',
          queryParameters: {'email': email, 'purpose': 'signup'},
        ).toString());
      }
    } catch (e) {
      if (mounted)
        showGlassToast(context, describeAuthError(e), destructive: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pw = _password.text;
    return AuthScaffold(
      title: 'Create your account',
      subtitle: 'Log what you watch, see what your friends think.',
      onBack: () => context.go('/login'),
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
          errorText: pw.isEmpty ? _passwordError : null,
          textInputAction: TextInputAction.go,
          autofillHints: const [AutofillHints.newPassword],
          onSubmitted: (_) => _create(),
          helper: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final rule in passwordRules)
                ChecklistLine(label: rule.label, met: rule.test(pw)),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.xl),
        GlassPillButton(
          label: 'Continue',
          prominent: true,
          expand: true,
          busy: _busy,
          onTap: _create,
        ),
        const SizedBox(height: AppSpace.lg),
        const AuthLegalNote(),
        const SizedBox(height: AppSpace.md),
        AuthLinkRow(
          prompt: 'Have an account?',
          action: 'Log in',
          onTap: () => context.go('/login'),
        ),
      ],
    );
  }
}
