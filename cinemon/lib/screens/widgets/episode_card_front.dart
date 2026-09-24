import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../../core/constants/api_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/activity_model.dart';
import 'glass_panel.dart';
import 'star_input.dart' show GlassStar;

/// The front of a feed card for a post about one episode.
///
/// A film post's front is the poster and nothing else — the artwork is the
/// message. An episode has no poster of its own, only a 16:9 still, so the
/// still takes the top of the card at its native shape and the rest of the
/// card says, loudly, which show, which season and which episode: the show's
/// poster as a thumbnail beside its name, a glass "S2 E5" tag, and the
/// episode's title at the size a film's title would get on the back.
class EpisodeCardFront extends StatelessWidget {
  const EpisodeCardFront({super.key, required this.activity});

  final ActivityModel activity;

  @override
  Widget build(BuildContext context) {
    final still = ApiConstants.getStillUrl(
      activity.episodeStillPath,
      size: ApiConstants.stillSizeLarge,
    );
    final poster = ApiConstants.getPosterUrl(
      activity.filmPosterPath,
      size: ApiConstants.posterSizeSmall,
    );

    return Container(
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The still, at the still's own aspect ratio.
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (still.isNotEmpty)
                  CachedNetworkImage(
                    imageUrl: still,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => const _StillPlaceholder(),
                    errorWidget: (_, __, ___) => const _StillPlaceholder(),
                  )
                else
                  const _StillPlaceholder(),
                // Settle the still into the card rather than leaving a hard
                // edge where the artwork stops.
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.transparent,
                        AppColors.surface.withValues(alpha: 0.9),
                      ],
                      stops: const [0, 0.55, 1],
                    ),
                  ),
                ),
                Positioned(
                  left: AppSpace.md,
                  top: AppSpace.md,
                  child: GlassTag(activity.episodeCode ?? ''),
                ),
              ],
            ),
          ),

          // Which show, which episode.
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpace.lg, AppSpace.xs, AppSpace.lg, AppSpace.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Show row: poster thumbnail + name. The poster is what a
                  // reader recognises at a glance from the rest of the feed.
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 51,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.14),
                            width: 0.6,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: poster.isEmpty
                              ? Container(
                                  color: Colors.white.withValues(alpha: 0.06),
                                  child: const Icon(CupertinoIcons.tv,
                                      size: 14, color: AppColors.inkTertiary),
                                )
                              : CachedNetworkImage(
                                  imageUrl: poster, fit: BoxFit.cover),
                        ),
                      ),
                      const SizedBox(width: AppSpace.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              activity.filmTitle,
                              style: AppText.headline.copyWith(
                                color: AppColors.ink,
                                fontSize: 16,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Season ${activity.seasonNumber}  ·  Episode ${activity.episodeNumber}',
                              style: AppText.footnote.copyWith(
                                color: AppColors.inkSecondary,
                                letterSpacing: 0.6,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // The episode itself.
                  Text(
                    'EPISODE',
                    style: AppText.footnote.copyWith(
                      color: AppColors.inkTertiary,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    activity.displayTitle,
                    style: AppText.title.copyWith(
                      color: AppColors.ink,
                      fontSize: 24,
                      height: 1.12,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (activity.hasRating) ...[
                    const SizedBox(height: AppSpace.md),
                    Row(
                      children: [
                        for (var i = 0; i < 5; i++)
                          Padding(
                            padding: const EdgeInsets.only(right: 2),
                            child: GlassStar(
                              fill: (activity.rating! - i).clamp(0.0, 1.0),
                              size: 15,
                            ),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: AppSpace.md),
                  Row(
                    children: [
                      const Icon(CupertinoIcons.arrow_2_squarepath,
                          size: 12, color: AppColors.inkTertiary),
                      const SizedBox(width: 5),
                      Text(
                        'Tap to flip',
                        style: AppText.footnote
                            .copyWith(color: AppColors.inkTertiary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StillPlaceholder extends StatelessWidget {
  const _StillPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceElevated,
      alignment: Alignment.center,
      child: const Icon(CupertinoIcons.tv, color: AppColors.inkTertiary),
    );
  }
}

/// The small "S2 E5" mark for poster tiles on profiles, so an episode post
/// isn't mistaken for a post about the whole show.
class EpisodeTileTag extends StatelessWidget {
  const EpisodeTileTag({super.key, required this.activity});

  final ActivityModel activity;

  @override
  Widget build(BuildContext context) {
    if (!activity.isEpisode) return const SizedBox.shrink();
    return Positioned(
      left: 6,
      bottom: 6,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: Text(
          activity.episodeCode!,
          style: AppText.footnote.copyWith(
            color: AppColors.ink,
            fontWeight: FontWeight.w700,
            fontSize: 10,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
