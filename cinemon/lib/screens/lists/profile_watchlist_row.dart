import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../models/list_model.dart';
import '../../providers/lists/list_provider.dart';
import '../widgets/glass_panel.dart';

/// The Watchlist row pinned to the top of a profile's Lists tab. Takes no
/// space when the watchlist is hidden from you.
class ProfileWatchlistRow extends ConsumerWidget {
  const ProfileWatchlistRow({
    super.key,
    required this.userId,
    required this.isOwnProfile,
  });

  final String userId;
  final bool isOwnProfile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = (isOwnProfile
            ? ref.watch(myWatchlistProvider)
            : ref.watch(watchlistProvider(userId)))
        .valueOrNull;
    if (list == null) return const SizedBox.shrink();

    final count = list.itemCount;
    final detail = [
      count == 0 ? 'Empty' : '$count title${count == 1 ? '' : 's'}',
      if (isOwnProfile && list.visibility != ListVisibility.public)
        list.visibility.label,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, AppSpace.xl),
      child: GlassPressable(
        onTap: () => context.push('/lists/${list.id}'),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.lg, vertical: AppSpace.md),
          decoration: glassWellDecoration(),
          child: Row(
            children: [
              const Icon(CupertinoIcons.bookmark_fill,
                  size: 18, color: AppColors.ink),
              const SizedBox(width: AppSpace.md),
              Text('Watchlist',
                  style: AppText.body.copyWith(color: AppColors.ink)),
              const Spacer(),
              Text(detail,
                  style:
                      AppText.footnote.copyWith(color: AppColors.inkTertiary)),
              const SizedBox(width: AppSpace.sm),
              const Icon(CupertinoIcons.chevron_right,
                  size: 14, color: AppColors.inkTertiary),
            ],
          ),
        ),
      ),
    );
  }
}
