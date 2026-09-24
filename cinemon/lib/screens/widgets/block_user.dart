import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/block/block_provider.dart';
import '../../repositories/block_repository.dart';
import 'glass_panel.dart';

/// Confirm, then block. Resolves true once the block is saved, so the caller
/// can leave a screen that belonged to that person.
Future<bool> confirmAndBlock(
  BuildContext context,
  WidgetRef ref, {
  required String userId,
  required String username,
}) async {
  final ok = await showGlassConfirm(
    context,
    title: 'Block @$username?',
    message: "You won't see each other's profiles, posts or comments, and "
        "any follow between you ends. They won't be told. You can unblock "
        'them in Settings.',
    confirmLabel: 'Block',
    destructive: true,
  );
  if (!ok || !context.mounted) return false;

  final done = await ref.read(blockActionsProvider).block(userId);
  if (!context.mounted) return done;
  showGlassToast(
    context,
    done ? '@$username is blocked' : "Couldn't block @$username. Try again.",
    icon: done ? CupertinoIcons.hand_raised_fill : null,
    destructive: !done,
  );
  return done;
}

/// Settings → Blocked accounts.
Future<void> showBlockedAccountsPanel(BuildContext context) {
  return showGlassPanel<void>(
    context,
    tall: true,
    builder: (panelContext) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassPanelHeader(
          title: 'Blocked accounts',
          trailingLabel: 'Done',
          onTrailing: () => Navigator.of(panelContext).pop(),
        ),
        const Expanded(child: _BlockedList()),
      ],
    ),
  );
}

class _BlockedList extends ConsumerWidget {
  const _BlockedList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocked = ref.watch(blockedAccountsProvider);
    return blocked.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => _Note(
        "Couldn't load your blocked accounts.",
        action: GlassPillButton(
          label: 'Try again',
          compact: true,
          onTap: () => ref.invalidate(blockedAccountsProvider),
        ),
      ),
      data: (accounts) {
        if (accounts.isEmpty) {
          return const _Note("You haven't blocked anyone.");
        }
        return ListView.separated(
          padding: const EdgeInsets.only(bottom: AppSpace.lg),
          itemCount: accounts.length,
          separatorBuilder: (_, __) => const GlassMenuDivider(),
          itemBuilder: (_, i) => _BlockedRow(account: accounts[i]),
        );
      },
    );
  }
}

class _BlockedRow extends ConsumerStatefulWidget {
  const _BlockedRow({required this.account});

  final BlockedAccount account;

  @override
  ConsumerState<_BlockedRow> createState() => _BlockedRowState();
}

class _BlockedRowState extends ConsumerState<_BlockedRow> {
  bool _busy = false;

  Future<void> _unblock() async {
    setState(() => _busy = true);
    final done =
        await ref.read(blockActionsProvider).unblock(widget.account.id);
    if (!mounted) return;
    // On success the list reloads without this row.
    if (!done) {
      setState(() => _busy = false);
      showGlassToast(context, "Couldn't unblock. Try again.",
          destructive: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.account;
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.lg, vertical: AppSpace.sm),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.surfaceElevated,
            backgroundImage: a.photoUrl != null
                ? CachedNetworkImageProvider(a.photoUrl!)
                : null,
            child: a.photoUrl == null
                ? const Icon(CupertinoIcons.person_fill,
                    size: 18, color: AppColors.inkTertiary)
                : null,
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Text(
              '@${a.username}',
              style: AppText.body.copyWith(color: AppColors.ink),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GlassPillButton(
            label: 'Unblock',
            compact: true,
            busy: _busy,
            onTap: _unblock,
          ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text, {this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              style: AppText.body.copyWith(color: AppColors.inkSecondary),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              const SizedBox(height: AppSpace.md),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
