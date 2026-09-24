import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/gestures.dart' show TapGestureRecognizer;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';

/// The frame every auth screen shares (ADR 0004 D8): black to canvas, one
/// centred column no wider than a phone, a back chevron when there's
/// somewhere to go back to, and a large title in the app's own type.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.children,
    this.title,
    this.subtitle,
    this.onBack,
    this.header,
  });

  final List<Widget> children;
  final String? title;
  final String? subtitle;

  /// Shows the back chevron.
  final VoidCallback? onBack;

  /// Above the title: the logo on the first screens.
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      resizeToAvoidBottomInset: true,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black, AppColors.canvas],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(AppSpace.xl,
                      AppSpace.xxl + AppSpace.lg, AppSpace.xl, AppSpace.xl),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 380),
                    child: AutofillGroup(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (header != null) header!,
                          if (title != null)
                            Text(title!, style: AppText.largeTitle),
                          if (subtitle != null) ...[
                            const SizedBox(height: AppSpace.sm),
                            Text(
                              subtitle!,
                              style: AppText.body.copyWith(
                                color: AppColors.inkSecondary,
                                height: 1.35,
                              ),
                            ),
                          ],
                          if (title != null || subtitle != null)
                            const SizedBox(height: AppSpace.xl),
                          ...children,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (onBack != null)
                Positioned(
                  top: AppSpace.xs,
                  left: AppSpace.xs,
                  child: IconButton(
                    onPressed: onBack,
                    icon: const Icon(CupertinoIcons.chevron_back,
                        color: AppColors.ink),
                    tooltip: 'Back',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The 35mm wordmark at the top of log in and sign up.
class AuthLogo extends StatelessWidget {
  const AuthLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.lg),
      child: Image.asset(
        'assets/images/35mm_final_logo.png',
        height: 260,
        fit: BoxFit.contain,
      ),
    );
  }
}

/// "Prompt  Action" on one line, such as "New to 35mm?  Create an account".
class AuthLinkRow extends StatelessWidget {
  const AuthLinkRow({
    super.key,
    required this.prompt,
    required this.action,
    required this.onTap,
  });

  final String prompt;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
          child: Text.rich(
            TextSpan(
              style: AppText.body.copyWith(color: AppColors.inkSecondary),
              children: [
                TextSpan(text: '$prompt  '),
                TextSpan(
                  text: action,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A quiet text button: "Forgot password?", "Resend code".
class AuthTextButton extends StatelessWidget {
  const AuthTextButton({
    super.key,
    required this.label,
    required this.onTap,
    this.alignment = Alignment.center,
  });

  final String label;
  final VoidCallback? onTap;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              vertical: AppSpace.sm, horizontal: AppSpace.xs),
          child: Text(
            label,
            style: AppText.label.copyWith(
              fontSize: 15,
              color: onTap == null
                  ? AppColors.inkQuaternary
                  : AppColors.inkSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// The line under sign-up that points at the terms and the privacy policy.
class AuthLegalNote extends StatefulWidget {
  const AuthLegalNote({super.key, this.prefix = 'By continuing, you agree to'});

  final String prefix;

  @override
  State<AuthLegalNote> createState() => _AuthLegalNoteState();
}

class _AuthLegalNoteState extends State<AuthLegalNote> {
  late final _terms = TapGestureRecognizer()
    ..onTap = () => _open('https://35mm.contact/terms');
  late final _privacy = TapGestureRecognizer()
    ..onTap = () => _open('https://35mm.contact/privacy');

  static Future<void> _open(String url) =>
      launchUrl(Uri.parse(url), mode: LaunchMode.inAppBrowserView);

  @override
  void dispose() {
    _terms.dispose();
    _privacy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const link = TextStyle(
      color: AppColors.inkSecondary,
      decoration: TextDecoration.underline,
      decorationColor: AppColors.inkTertiary,
    );
    return Text.rich(
      TextSpan(
        style:
            AppText.caption.copyWith(color: AppColors.inkTertiary, height: 1.4),
        children: [
          TextSpan(text: '${widget.prefix} 35mm\'s '),
          TextSpan(text: 'Terms of Use', style: link, recognizer: _terms),
          const TextSpan(
              text: ', including zero tolerance for abusive content, and its '),
          TextSpan(text: 'Privacy Policy', style: link, recognizer: _privacy),
          const TextSpan(text: '.'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
