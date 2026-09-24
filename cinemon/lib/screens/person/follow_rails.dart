import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/api_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/person/person_follow_provider.dart';
import '../widgets/glass_panel.dart';

/// "New from people you follow": the last month's new-work alerts as a
/// poster rail, at the top of Explore. Takes no space when there are none.
class NewFromFollowedRail extends ConsumerWidget {
  const NewFromFollowedRail({super.key});

  static const _poster = Size(96, 144);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(newFromFollowedProvider).valueOrNull ?? const [];
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(
                AppSpace.xl, AppSpace.md, AppSpace.xl, AppSpace.sm),
            child: GlassSectionLabel('New from people you follow'),
          ),
          SizedBox(
            height: _poster.height + 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpace.md),
              itemBuilder: (context, i) {
                final n = items[i];
                final poster = ApiConstants.getPosterUrl(n.filmPosterPath,
                    size: ApiConstants.posterSizeSmall);
                return GlassPressable(
                  onTap: n.filmId == null
                      ? null
                      : () => context
                          .push('/film/${n.filmId}/${n.mediaType ?? 'movie'}'),
                  child: SizedBox(
                    width: _poster.width,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox.fromSize(
                            size: _poster,
                            child: poster.isEmpty
                                ? ColoredBox(
                                    color: Colors.white.withValues(alpha: 0.06),
                                    child: const Icon(CupertinoIcons.film,
                                        color: AppColors.inkTertiary),
                                  )
                                : CachedNetworkImage(
                                    imageUrl: poster, fit: BoxFit.cover),
                          ),
                        ),
                        const SizedBox(height: AppSpace.xs),
                        Text(
                          n.filmTitle ?? '',
                          style:
                              AppText.footnote.copyWith(color: AppColors.ink),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          n.personName ?? '',
                          style: AppText.footnote.copyWith(
                              fontSize: 11, color: AppColors.inkTertiary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// The people a profile follows, as a rail of portraits. On your own
/// profile it explains itself when empty; on anyone else's it's hidden.
class FollowingPeopleRail extends ConsumerWidget {
  const FollowingPeopleRail({
    super.key,
    required this.userId,
    required this.isOwnProfile,
  });

  final String userId;
  final bool isOwnProfile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final follows = ref.watch(personFollowsProvider(userId)).valueOrNull;
    if (follows == null) return const SizedBox.shrink();
    if (follows.isEmpty && !isOwnProfile) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              follows.isEmpty ? 'Following' : 'Following · ${follows.length}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: AppSpace.md),
          if (follows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Follow actors and directors from their pages to hear when '
                'they have something new.',
                style: AppText.footnote.copyWith(color: AppColors.inkTertiary),
              ),
            )
          else
            SizedBox(
              height: 118,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: follows.length,
                separatorBuilder: (_, __) => const SizedBox(width: AppSpace.md),
                itemBuilder: (context, i) {
                  final f = follows[i];
                  return GlassPressable(
                    onTap: () => context.push('/person/${f.personId}'),
                    child: SizedBox(
                      width: 64,
                      child: Column(
                        children: [
                          PillPortrait(
                            imageUrl:
                                f.profileUrl.isEmpty ? null : f.profileUrl,
                            width: 60,
                            height: 84,
                          ),
                          const SizedBox(height: AppSpace.xs),
                          Text(
                            f.name,
                            style: AppText.footnote.copyWith(
                                fontSize: 11, color: AppColors.inkSecondary),
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
