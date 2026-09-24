import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/activity_model.dart';
import '../../models/episode_model.dart';
import '../../models/film_model.dart';
import 'episodes_section.dart' show EpisodeStill;
import 'glass_panel.dart';
import 'star_input.dart' show GlassStar;

/// What the user chose to do from the panel. Returned through
/// `Navigator.pop` so the caller — which still has the screen's context —
/// performs the action after the glass has gone.
enum EpisodeAction { post, edit }

/// A floating glass card for one episode: the still, its metadata and
/// synopsis, and the user's own post about it if there is one.
class EpisodeDetailPanel extends StatelessWidget {
  const EpisodeDetailPanel({
    super.key,
    required this.show,
    required this.episode,
    this.activity,
  });

  final FilmModel show;
  final EpisodeModel episode;
  final ActivityModel? activity;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.78;
    final meta = [
      episode.formattedAirDate,
      episode.formattedRuntime,
      if (episode.voteAverage > 0)
        '★ ${episode.voteAverage.toStringAsFixed(1)}',
    ].whereType<String>().join('  ·  ');

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Hero still, bleeding to the pane's edge with the close button
          // floating over it.
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                child: EpisodeStill(
                    path: episode.stillPath, radius: 0, large: true),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.25),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.55),
                      ],
                      stops: const [0, 0.4, 1],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: AppSpace.md,
                right: AppSpace.md,
                child: RemoveBadge(onTap: () => Navigator.of(context).pop()),
              ),
              Positioned(
                left: AppSpace.lg,
                bottom: AppSpace.md,
                child: GlassTag(episode.code),
              ),
            ],
          ),

          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                  AppSpace.xl, AppSpace.lg, AppSpace.xl, AppSpace.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    show.displayTitle,
                    style: AppText.caption.copyWith(
                      color: AppColors.inkSecondary,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(episode.displayName, style: AppText.title),
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: AppSpace.xs),
                    Text(
                      meta,
                      style: AppText.caption
                          .copyWith(color: AppColors.inkSecondary),
                    ),
                  ],
                  if (episode.overview != null &&
                      episode.overview!.isNotEmpty) ...[
                    const SizedBox(height: AppSpace.lg),
                    Text(
                      episode.overview!,
                      style: AppText.body.copyWith(
                        color: AppColors.ink.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpace.xl),
                  if (activity != null) ...[
                    _YourPost(activity: activity!),
                    const SizedBox(height: AppSpace.lg),
                    GlassPillButton(
                      label: 'Edit your post',
                      icon: CupertinoIcons.pencil,
                      expand: true,
                      onTap: () =>
                          Navigator.of(context).pop(EpisodeAction.edit),
                    ),
                  ] else
                    GlassPillButton(
                      label: 'Post a review',
                      icon: CupertinoIcons.star,
                      prominent: true,
                      expand: true,
                      onTap: () =>
                          Navigator.of(context).pop(EpisodeAction.post),
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

class _YourPost extends StatelessWidget {
  const _YourPost({required this.activity});

  final ActivityModel activity;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpace.lg),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Your post',
                style: AppText.caption.copyWith(
                  color: AppColors.inkSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                activity.relativeTime,
                style: AppText.caption.copyWith(color: AppColors.inkTertiary),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.sm),
          if (activity.hasRating)
            Row(
              children: List.generate(5, (i) {
                final r = activity.rating!;
                return Padding(
                  padding: const EdgeInsets.only(right: 3),
                  child: GlassStar(fill: (r - i).clamp(0.0, 1.0), size: 18),
                );
              }),
            )
          else
            Text(
              'Watched',
              style: AppText.body.copyWith(color: AppColors.inkSecondary),
            ),
          if (activity.hasReview) ...[
            const SizedBox(height: AppSpace.sm),
            Text(
              activity.reviewText!,
              style: AppText.body.copyWith(color: AppColors.ink),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
