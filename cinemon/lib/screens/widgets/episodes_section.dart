import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart'
    show CupertinoActivityIndicator, CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../models/activity_model.dart';
import '../../models/episode_model.dart';
import '../../models/film_model.dart';
import '../../providers/feed/feed_provider.dart';
import '../../providers/movie/movie_provider.dart';
import 'episode_detail_panel.dart';
import 'glass_panel.dart';
import 'star_input.dart' show GlassStar;

/// Seasons and episodes of a show, on its detail screen.
///
/// A row of season chips, then the season's episodes as still + title + meta
/// rows. Episodes the user has already posted about carry their rating on
/// the right. Tapping any episode opens [EpisodeDetailPanel].
class EpisodesSection extends ConsumerStatefulWidget {
  const EpisodesSection({
    super.key,
    required this.show,
    required this.onPostReview,
    required this.onEditPost,
  });

  final FilmModel show;

  /// Called after the panel closes, with the screen's own context still
  /// valid, so the post sheet opens where the screen expects it.
  final void Function(EpisodeModel episode) onPostReview;
  final void Function(ActivityModel activity) onEditPost;

  @override
  ConsumerState<EpisodesSection> createState() => _EpisodesSectionState();
}

class _EpisodesSectionState extends ConsumerState<EpisodesSection> {
  int? _season;

  List<SeasonModel> get _seasons => widget.show.orderedSeasons;

  int get _selected =>
      _season ?? (_seasons.isEmpty ? 1 : _seasons.first.seasonNumber);

  @override
  Widget build(BuildContext context) {
    final seasons = _seasons;
    if (seasons.isEmpty) return const SizedBox.shrink();

    final episodesAsync = ref.watch(
      seasonProvider((tvId: widget.show.id, seasonNumber: _selected)),
    );
    final posted =
        ref.watch(userEpisodeActivitiesProvider(widget.show.id)).valueOrNull ??
            const <String, ActivityModel>{};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Episodes', style: AppText.headline),
            const Spacer(),
            if (widget.show.numberOfEpisodes != null)
              Text(
                '${widget.show.numberOfEpisodes} total',
                style: AppText.caption.copyWith(color: AppColors.inkTertiary),
              ),
          ],
        ),
        const SizedBox(height: AppSpace.md),

        // Season chips. Scrolls when a show runs long.
        SizedBox(
          height: 32,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: seasons.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpace.sm),
            itemBuilder: (context, i) {
              final s = seasons[i];
              return GlassChip(
                label: s.isSpecials ? 'Specials' : 'Season ${s.seasonNumber}',
                selected: s.seasonNumber == _selected,
                onTap: () => setState(() => _season = s.seasonNumber),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpace.lg),

        episodesAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpace.xxl),
            child: Center(
              child: CupertinoActivityIndicator(color: AppColors.inkSecondary),
            ),
          ),
          error: (_, __) => Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.xl),
            child: Text(
              'Couldn\'t load this season.',
              style: AppText.body.copyWith(color: AppColors.inkSecondary),
            ),
          ),
          data: (episodes) {
            if (episodes.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpace.xl),
                child: Text(
                  'No episodes listed yet.',
                  style: AppText.body.copyWith(color: AppColors.inkSecondary),
                ),
              );
            }
            return Column(
              children: [
                for (var i = 0; i < episodes.length; i++) ...[
                  if (i > 0)
                    const Padding(
                      padding: EdgeInsets.only(left: 128),
                      child: Divider(),
                    ),
                  _EpisodeRow(
                    episode: episodes[i],
                    activity: posted[episodes[i].code],
                    onTap: () => _open(episodes[i], posted[episodes[i].code]),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _open(EpisodeModel episode, ActivityModel? activity) async {
    final action = await showGlassPanel<EpisodeAction>(
      context,
      builder: (_) => EpisodeDetailPanel(
        show: widget.show,
        episode: episode,
        activity: activity,
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case EpisodeAction.post:
        widget.onPostReview(episode);
      case EpisodeAction.edit:
        if (activity != null) widget.onEditPost(activity);
    }
  }
}

class _EpisodeRow extends StatelessWidget {
  const _EpisodeRow({
    required this.episode,
    required this.activity,
    required this.onTap,
  });

  final EpisodeModel episode;
  final ActivityModel? activity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final aired = episode.hasAired;
    final meta = [
      if (aired)
        episode.formattedAirDate
      else
        'Airs ${episode.formattedAirDate ?? 'soon'}',
      episode.formattedRuntime,
    ].whereType<String>().join('  ·  ');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.sm + 2),
        child: Opacity(
          opacity: aired ? 1 : 0.55,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              EpisodeStill(path: episode.stillPath, width: 112),
              const SizedBox(width: AppSpace.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${episode.episodeNumber}.  ${episode.displayName}',
                      style: AppText.body.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        meta,
                        style: AppText.caption
                            .copyWith(color: AppColors.inkSecondary),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              if (activity != null)
                _PostedMark(activity: activity!)
              else
                const Icon(
                  CupertinoIcons.chevron_right,
                  size: 14,
                  color: AppColors.inkTertiary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The user's rating for an episode they've posted about, or a tick for a
/// bare "watched".
class _PostedMark extends StatelessWidget {
  const _PostedMark({required this.activity});

  final ActivityModel activity;

  @override
  Widget build(BuildContext context) {
    if (!activity.hasRating) {
      return const Icon(
        CupertinoIcons.checkmark_circle_fill,
        size: 20,
        color: AppColors.ink,
      );
    }
    final r = activity.rating!;
    final label =
        r == r.roundToDouble() ? r.toStringAsFixed(0) : r.toStringAsFixed(1);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const GlassStar(fill: 1, size: 14),
        const SizedBox(width: 3),
        Text(
          label,
          style: AppText.label.copyWith(fontSize: 14, color: AppColors.ink),
        ),
      ],
    );
  }
}

/// A 16:9 episode still with rounded corners, shared by rows, the detail
/// panel and the post sheet.
class EpisodeStill extends StatelessWidget {
  const EpisodeStill({
    super.key,
    required this.path,
    this.width,
    this.radius = AppRadius.sm + 2,
    this.large = false,
  });

  final String? path;
  final double? width;
  final double radius;

  /// Use the larger TMDB rendition (for the panel's hero).
  final bool large;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      color: Colors.white.withValues(alpha: 0.06),
      alignment: Alignment.center,
      child: const Icon(CupertinoIcons.tv, color: AppColors.inkTertiary),
    );
    final url = path == null || path!.isEmpty
        ? ''
        : 'https://image.tmdb.org/t/p/${large ? 'w780' : 'w300'}$path';

    return SizedBox(
      width: width,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: url.isEmpty
              ? placeholder
              : CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => placeholder,
                  errorWidget: (_, __, ___) => placeholder,
                ),
        ),
      ),
    );
  }
}
