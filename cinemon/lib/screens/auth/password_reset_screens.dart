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

/// Forgot password, step one: where to send the code (ADR 0004 D4).
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key, this.email});

  final String? email;

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  late final _email = TextEditingController(text: widget.email ?? '');
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final email = _email.text.trim();
    if (!email.contains('@')) {
      setState(() => _error = 'Enter the email you signed up with');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .sendPasswordResetCode(email: email);
      if (!mounted) return;
      // Supabase answers the same whether or not the account exists, so the
      // next screen doesn't say either.
      context.pushReplacement(Uri(
        path: '/verify',
        queryParameters: {'email': email, 'purpose': 'recovery'},
      ).toString());
    } catch (e) {
      if (mounted) setState(() => _error = describeAuthError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Reset your password',
      subtitle: 'Enter your email and we\'ll send you a code.',
      onBack: () => context.canPop() ? context.pop() : context.go('/login'),
      children: [
        GlassTextField(
          controller: _email,
          placeholder: 'Email',
          icon: CupertinoIcons.mail,
          autofocus: widget.email == null,
          errorText: _error,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.send,
          autofillHints: const [AutofillHints.email],
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          onSubmitted: (_) => _send(),
        ),
        const SizedBox(height: AppSpace.xl),
        GlassPillButton(
          label: 'Send code',
          prominent: true,
          expand: true,
          busy: _busy,
          onTap: _send,
        ),
      ],
    );
  }
}

/// Forgot password, last step: the code signed you in, so choose the new
/// password and carry on into the app.
class NewPasswordScreen extends ConsumerStatefulWidget {
  const NewPasswordScreen({super.key});

  @override
  ConsumerState<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends ConsumerState<NewPasswordScreen> {
  final _password = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _password.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!passwordOk(_password.text)) {
      setState(() =>
          _error = 'Use at least 8 characters, with a letter and a number');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).updatePassword(_password.text);
      if (!mounted) return;
      showGlassToast(context, 'Password changed',
          icon: CupertinoIcons.checkmark_alt);
      context.go('/home');
    } catch (e) {
      if (mounted) setState(() => _error = describeAuthError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pw = _password.text;
    return AuthScaffold(
      title: 'Choose a new password',
      children: [
        GlassTextField(
          controller: _password,
          placeholder: 'New password',
          icon: CupertinoIcons.lock,
          obscure: true,
          autofocus: true,
          errorText: pw.isEmpty || _error != null ? _error : null,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.newPassword],
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          onSubmitted: (_) => _save(),
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
          label: 'Save password',
          prominent: true,
          expand: true,
          busy: _busy,
          onTap: _save,
        ),
      ],
    );
  }
}
