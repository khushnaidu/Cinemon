import 'package:flutter/cupertino.dart'
    show CupertinoActivityIndicator, CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/badge_model.dart';
import '../../../providers/feed/feed_provider.dart'
    show earnedBadgesProvider, myBadgeProgressProvider;
import '../../widgets/glass_panel.dart';

/// A profile's Badges tab: every badge, earned ones lit with the date, the
/// rest dimmed. On your own profile the locked ones show how close you are.
class BadgesTab extends ConsumerWidget {
  const BadgesTab({
    super.key,
    required this.userId,
    required this.isOwnProfile,
    this.fallbackIds = const [],
  });

  final String userId;
  final bool isOwnProfile;

  /// profiles.badge_ids, used without dates if the dated list won't load.
  final List<String> fallbackIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final earnedAsync = ref.watch(earnedBadgesProvider(userId));
    final progress = isOwnProfile
        ? (ref.watch(myBadgeProgressProvider).valueOrNull ?? const {})
        : const <String, int>{};

    if (earnedAsync.isLoading && !earnedAsync.hasValue) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(AppSpace.xxl),
          child: CupertinoActivityIndicator(color: AppColors.inkSecondary),
        ),
      );
    }

    final earned = <String, DateTime?>{
      for (final id in fallbackIds) id: null,
      for (final b in earnedAsync.valueOrNull ?? const <EarnedBadge>[])
        b.id: b.earnedAt,
    };

    // Earned first, newest first; then the rest in the registry's order.
    final all = BadgeRegistry.allBadges;
    final lit = all.where((b) => earned.containsKey(b.id)).toList()
      ..sort((a, b) {
        final da = earned[a.id], db = earned[b.id];
        if (da == null || db == null) return 0;
        return db.compareTo(da);
      });
    final dim = all.where((b) => !earned.containsKey(b.id)).toList();
    final ordered = [...lit, ...dim];

    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.xl, AppSpace.lg, AppSpace.xl, AppSpace.md),
            child: GlassSectionLabel('${lit.length} of ${all.length} earned'),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: AppSpace.lg,
              crossAxisSpacing: AppSpace.sm,
              childAspectRatio: 0.72,
            ),
            itemCount: ordered.length,
            itemBuilder: (context, i) {
              final badge = ordered[i];
              final isEarned = earned.containsKey(badge.id);
              final date = earned[badge.id];
              final caption = isEarned
                  ? (date == null ? 'Earned' : DateFormat.yMMM().format(date))
                  : badge.progressLabel(progress);
              return GlassPressable(
                onTap: () => _showDetail(
                  context,
                  badge,
                  earned: isEarned,
                  earnedAt: date,
                  progress: isEarned ? null : badge.progressLabel(progress),
                ),
                child: Column(
                  children: [
                    BadgeArt(badge: badge, earned: isEarned, size: 76),
                    const SizedBox(height: AppSpace.sm),
                    Text(
                      badge.name,
                      style: AppText.label.copyWith(
                        fontSize: 13,
                        color:
                            isEarned ? AppColors.ink : AppColors.inkSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    if (caption != null)
                      Text(
                        caption,
                        style: AppText.footnote.copyWith(
                          fontSize: 11,
                          color: AppColors.inkTertiary,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  static Future<void> _showDetail(
    BuildContext context,
    BadgeModel badge, {
    required bool earned,
    DateTime? earnedAt,
    String? progress,
  }) {
    return showGlassPanel<void>(
      context,
      builder: (panelContext) => Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpace.xl, AppSpace.xl, AppSpace.xl, AppSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BadgeArt(badge: badge, earned: earned, size: 120),
            const SizedBox(height: AppSpace.lg),
            Text(
              badge.name,
              style: AppText.title.copyWith(color: AppColors.ink),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpace.xs),
            Text(
              badge.description,
              style: AppText.body.copyWith(color: AppColors.inkSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpace.lg),
            GlassTag(
              earned
                  ? (earnedAt == null
                      ? 'Earned'
                      : 'Earned ${DateFormat.yMMMMd().format(earnedAt)}')
                  : (progress ?? 'Not earned yet'),
            ),
            const SizedBox(height: AppSpace.lg),
            GlassPillButton(
              label: 'Done',
              onTap: () => Navigator.of(panelContext).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

/// A badge's artwork: its image if it has one, else its emoji on a disc in
/// its category's colour. Locked badges are grey and faded.
class BadgeArt extends StatelessWidget {
  const BadgeArt({
    super.key,
    required this.badge,
    required this.earned,
    this.size = 76,
  });

  final BadgeModel badge;
  final bool earned;
  final double size;

  static Color colorFor(BadgeType type) => switch (type) {
        BadgeType.reviews => const Color(0xFFFCD34D),
        BadgeType.genres => AppColors.info,
        BadgeType.lists => const Color(0xFFC4B5FD),
        BadgeType.special => const Color(0xFF34D399),
      };

  // Luminance-weighted greyscale.
  static const _grey = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    final color = colorFor(badge.type);
    final art = badge.imagePath != null
        ? Image.asset(badge.imagePath!,
            width: size, height: size, fit: BoxFit.contain)
        : Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color, color.withValues(alpha: 0.55)],
              ),
            ),
            alignment: Alignment.center,
            child: Text(badge.emoji, style: TextStyle(fontSize: size * 0.44)),
          );
    if (earned) return SizedBox(width: size, height: size, child: art);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Opacity(
            opacity: 0.32,
            child: ColorFiltered(colorFilter: _grey, child: art),
          ),
          Icon(CupertinoIcons.lock_fill,
              size: size * 0.24, color: AppColors.inkSecondary),
        ],
      ),
    );
  }
}
