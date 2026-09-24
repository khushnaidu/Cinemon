import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/auth_errors.dart';
import '../../providers/auth/auth_provider.dart';
import '../../providers/auth/onboarding_provider.dart';
import '../widgets/glass_panel.dart';
import '../widgets/glass_text_field.dart';
import 'auth_scaffold.dart';

/// What the code is for.
enum CodePurpose { signup, recovery }

/// Enter the 6-digit code from the email (ADR 0004 D4).
///
/// For a sign-up it signs you in and the router moves on to onboarding. For
/// a password reset it signs you in and goes on to choose the new password.
class VerifyCodeScreen extends ConsumerStatefulWidget {
  const VerifyCodeScreen({
    super.key,
    required this.email,
    required this.purpose,
  });

  final String email;
  final CodePurpose purpose;

  @override
  ConsumerState<VerifyCodeScreen> createState() => _VerifyCodeScreenState();
}

class _VerifyCodeScreenState extends ConsumerState<VerifyCodeScreen> {
  static const _length = 6;
  static const _cooldown = 60;

  final _code = TextEditingController();
  String? _error;
  bool _busy = false;
  int _wait = _cooldown;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    _code.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _wait = _cooldown);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _wait--);
      if (_wait <= 0) t.cancel();
    });
  }

  Future<void> _verify() async {
    final code = _code.text.trim();
    if (code.length != _length || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final repo = ref.read(authRepositoryProvider);
    try {
      if (widget.purpose == CodePurpose.signup) {
        await repo.verifyEmailCode(email: widget.email, code: code);
        ref.invalidate(onboardedProvider);
        // Signed in now; the router takes it from here.
      } else {
        await repo.verifyResetCode(email: widget.email, code: code);
        if (mounted) context.go('/new-password');
      }
    } catch (e) {
      if (!mounted) return;
      _code.clear();
      setState(() => _error = describeAuthError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    final repo = ref.read(authRepositoryProvider);
    try {
      if (widget.purpose == CodePurpose.signup) {
        await repo.resendEmailCode(email: widget.email);
      } else {
        await repo.sendPasswordResetCode(email: widget.email);
      }
      if (!mounted) return;
      _startCooldown();
      showGlassToast(context, 'New code sent', icon: CupertinoIcons.mail);
    } catch (e) {
      if (mounted)
        showGlassToast(context, describeAuthError(e), destructive: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final signup = widget.purpose == CodePurpose.signup;
    return AuthScaffold(
      title: 'Check your email',
      subtitle: 'We sent a $_length-digit code to ${widget.email}. '
          '${signup ? 'Enter it to finish creating your account.' : 'Enter it to reset your password.'}',
      onBack: () => context.canPop() ? context.pop() : context.go('/login'),
      children: [
        GlassTextField(
          controller: _code,
          placeholder: '000000',
          autofocus: true,
          errorText: _error,
          keyboardType: TextInputType.number,
          autofillHints: const [AutofillHints.oneTimeCode],
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          maxLength: _length,
          textAlign: TextAlign.center,
          style: AppText.title.copyWith(
            fontSize: 26,
            letterSpacing: 10,
            color: AppColors.ink,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
          onChanged: (v) {
            if (_error != null) setState(() => _error = null);
            if (v.length == _length) _verify();
          },
        ),
        const SizedBox(height: AppSpace.xl),
        GlassPillButton(
          label: 'Continue',
          prominent: true,
          expand: true,
          busy: _busy,
          onTap: _verify,
        ),
        const SizedBox(height: AppSpace.md),
        GlassPillButton(
          label: 'Open Mail',
          icon: CupertinoIcons.envelope_open,
          expand: true,
          onTap: () => launchUrl(Uri.parse('message://')),
        ),
        const SizedBox(height: AppSpace.md),
        AuthTextButton(
          label: _wait > 0 ? 'Resend code in ${_wait}s' : 'Resend code',
          onTap: _wait > 0 ? null : _resend,
        ),
        const SizedBox(height: AppSpace.sm),
        Text(
          'Can\'t find it? Check your junk folder. The code works for an hour.',
          textAlign: TextAlign.center,
          style: AppText.caption.copyWith(color: AppColors.inkTertiary),
        ),
      ],
    );
  }
}
