import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/feed/feed_provider.dart' show userRepositoryProvider;
import '../widgets/glass_panel.dart';

/// Ask for the username, then delete the account. Resolves true once the
/// account is gone; the caller signs out and leaves.
///
/// Typing the username rather than tapping a second button: this can't be
/// undone, and a confirm pill sits exactly where the last tap landed.
Future<bool> showDeleteAccountPanel(
  BuildContext context, {
  required String uid,
  required String username,
}) async {
  final result = await showGlassPanel<bool>(
    context,
    // Not dismissible by tapping outside while a delete may be in flight.
    dismissible: false,
    builder: (_) => _DeleteAccountPanel(uid: uid, username: username),
  );
  return result ?? false;
}

class _DeleteAccountPanel extends ConsumerStatefulWidget {
  const _DeleteAccountPanel({required this.uid, required this.username});

  final String uid;
  final String username;

  @override
  ConsumerState<_DeleteAccountPanel> createState() =>
      _DeleteAccountPanelState();
}

class _DeleteAccountPanelState extends ConsumerState<_DeleteAccountPanel> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _matches =>
      _controller.text.trim().replaceFirst('@', '').toLowerCase() ==
      widget.username.toLowerCase();

  Future<void> _delete() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(userRepositoryProvider).deleteAccount(widget.uid);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('Account deletion failed: $e');
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = "Couldn't delete your account. Check your connection and "
            'try again. If it keeps failing, email support@35mm.contact.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpace.xl, AppSpace.xl, AppSpace.xl, AppSpace.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Delete account', style: AppText.title, textAlign: TextAlign.center),
          const SizedBox(height: AppSpace.sm),
          Text(
            'This permanently deletes your profile, logs, reviews, posts, '
            'comments, votes, follows, photos and voice notes. It can\'t be '
            'undone.',
            style: AppText.body.copyWith(color: AppColors.inkSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpace.lg),
          Text(
            'Type @${widget.username} to confirm.',
            style: AppText.footnote.copyWith(color: AppColors.inkSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpace.sm),
          GlassTextWell(
            controller: _controller,
            hint: widget.username,
            minLines: 1,
            maxLines: 1,
            textCapitalization: TextCapitalization.none,
            onChanged: (_) => setState(() {}),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpace.sm),
            Text(
              _error!,
              style: AppText.footnote.copyWith(color: AppColors.destructive),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: AppSpace.xl),
          Row(
            children: [
              Expanded(
                child: GlassPillButton(
                  label: 'Cancel',
                  expand: true,
                  onTap: _busy ? null : () => Navigator.of(context).pop(false),
                ),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: GlassPillButton(
                  label: 'Delete',
                  expand: true,
                  prominent: true,
                  destructive: true,
                  busy: _busy,
                  onTap: _matches ? _delete : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
