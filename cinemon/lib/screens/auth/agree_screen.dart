import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/legal.dart';
import '../../core/config/supabase_config.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth/auth_provider.dart';
import '../../providers/auth/onboarding_provider.dart';
import '../../providers/feed/feed_provider.dart' show userRepositoryProvider;
import '../../providers/follow/follow_provider.dart' show isPrivateProvider;
import '../widgets/glass_panel.dart';
import 'age_gate.dart';
import 'auth_scaffold.dart';

/// Agree to the current Terms before going on (migration 021): accounts
/// from before the age gate, anyone signing in with Apple or Google, and
/// everyone again whenever the Terms change.
///
/// Asks for a date of birth only if the account has never confirmed one.
/// Under 13, the account is deleted there and then (COPPA), and sign-up is
/// closed on this device.
class AgreeScreen extends ConsumerStatefulWidget {
  const AgreeScreen({super.key});

  @override
  ConsumerState<AgreeScreen> createState() => _AgreeScreenState();
}

class _AgreeScreenState extends ConsumerState<AgreeScreen> {
  DateTime? _birth;
  bool _agreed = false;
  bool _busy = false;
  String? _error;

  Future<void> _continue(bool askAge) async {
    final birth = _birth;
    setState(() {
      _error = askAge && birth == null
          ? 'Enter your date of birth'
          : (!_agreed ? 'Agree to the Terms of Use to continue' : null);
    });
    if (_error != null) return;
    final age = askAge ? ageOn(birth!, DateTime.now()) : null;

    setState(() => _busy = true);
    if (age != null && age < kMinimumAge) {
      await _closeUnderage();
      return;
    }
    try {
      await SupabaseConfig.client.rpc('accept_terms', params: {
        'version': kTermsVersion,
        if (age != null) 'minor': age < kAdultAge,
      });
      final me = ref.read(currentUserProvider)?.id;
      if (me != null) ref.invalidate(isPrivateProvider(me));
      // The router hears this and moves on.
      ref.invalidate(termsStatusProvider);
      if (mounted && age != null && age < kAdultAge) {
        showGlassToast(
          context,
          'Your account is private. You can change that in Settings.',
          icon: CupertinoIcons.lock_fill,
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      showGlassToast(context, 'Couldn\'t save that. Try again.',
          destructive: true);
    }
  }

  /// Under 13: the account and everything in it go, now.
  Future<void> _closeUnderage() async {
    final me = ref.read(currentUserProvider)?.id;
    await blockAgeGate();
    try {
      if (me != null) await ref.read(userRepositoryProvider).deleteAccount(me);
    } catch (_) {
      // Signing out still happens; the account is left for the deletion
      // runbook if the call failed.
    }
    await ref.read(authControllerProvider.notifier).signOut();
    if (!mounted) return;
    context.go('/login');
    showGlassToast(
      context,
      'Sorry, you can\'t use 35mm. Your account has been deleted.',
    );
  }

  Future<void> _signOut() async {
    await ref.read(authControllerProvider.notifier).signOut();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(termsStatusProvider).valueOrNull;
    final askAge = !(status?.ageKnown ?? false);

    return AuthScaffold(
      title: 'Before you continue',
      subtitle: askAge
          ? 'We\'ve updated our Terms of Use and Privacy Policy, and we now '
              'ask everyone for their date of birth.'
          : 'We\'ve updated our Terms of Use and Privacy Policy.',
      children: [
        const _Point(
          icon: CupertinoIcons.hand_raised,
          text: 'No hate, harassment, sexual content or threats. Posts that '
              'break the rules come down, and accounts can be suspended.',
        ),
        const _Point(
          icon: CupertinoIcons.flag,
          text: 'Report anything with its ••• menu, and block anyone. We '
              'review reports within 24 hours.',
        ),
        const _Point(
          icon: CupertinoIcons.lock_shield,
          text: 'We don\'t sell your data or show ads. You can delete your '
              'account at any time in Settings.',
        ),
        const SizedBox(height: AppSpace.md),
        if (askAge) ...[
          DateOfBirthField(
            value: _birth,
            onChanged: (d) => setState(() {
              _birth = d;
              _error = null;
            }),
          ),
          const SizedBox(height: AppSpace.lg),
        ],
        TermsCheckbox(
          value: _agreed,
          onChanged: (v) => setState(() {
            _agreed = v;
            _error = null;
          }),
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpace.sm),
          Text(_error!,
              style: AppText.caption.copyWith(color: AppColors.destructive)),
        ],
        const SizedBox(height: AppSpace.xl),
        GlassPillButton(
          label: 'Agree and continue',
          prominent: true,
          expand: true,
          busy: _busy,
          onTap: () => _continue(askAge),
        ),
        const SizedBox(height: AppSpace.md),
        AuthLinkRow(
          prompt: 'Not now?',
          action: 'Sign out',
          onTap: _busy ? () {} : _signOut,
        ),
      ],
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.inkSecondary),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Text(text,
                style: AppText.body.copyWith(color: AppColors.inkSecondary)),
          ),
        ],
      ),
    );
  }
}
