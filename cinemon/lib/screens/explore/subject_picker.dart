import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart'
    show CupertinoActivityIndicator, CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/api_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/episode_model.dart';
import '../../models/explore_post_model.dart';
import '../../models/film_model.dart';
import '../../providers/movie/movie_provider.dart';
import '../widgets/app_search_field.dart';
import '../widgets/comments_sheet.dart' show GlassHint;
import '../widgets/glass_panel.dart';

/// Pick the film, show or single episode a post is about.
///
/// Films resolve on tap. A show opens a second step in the same pane: the
/// whole show, or a season's episodes to pick one from.
Future<ExploreSubject?> showSubjectPicker(BuildContext context) {
  return showGlassPanel<ExploreSubject>(
    context,
    tall: true,
    builder: (_) => const SubjectPicker(),
  );
}

class SubjectPicker extends ConsumerStatefulWidget {
  const SubjectPicker({super.key});

  @override
  ConsumerState<SubjectPicker> createState() => _SubjectPickerState();
}

class _SubjectPickerState extends ConsumerState<SubjectPicker> {
  final _query = TextEditingController();
  Timer? _debounce;
  MediaType _scope = MediaType.movie;
  String _term = '';

  /// Set once a show is picked: the second step.
  FilmModel? _show;

  @override
  void dispose() {
    _query.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _term = value.trim());
    });
  }

  void _pick(FilmModel film) {
    if (film.isTv) {
      FocusScope.of(context).unfocus();
      setState(() => _show = film);
      return;
    }
    Navigator.of(context).pop(ExploreSubject.fromFilm(film));
  }

  @override
  Widget build(BuildContext context) {
    final show = _show;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: show == null
          ? _searchStep()
          : _EpisodeStep(
              key: ValueKey(show.id),
              show: show,
              onBack: () => setState(() => _show = null),
            ),
    );
  }

  Widget _searchStep() {
    final isTv = _scope == MediaType.tv;
    final AsyncValue<List<FilmModel>> results = _term.isEmpty
        ? ref.watch(isTv ? trendingTvShowsProvider : trendingMoviesProvider)
        : ref.watch(isTv
            ? searchTvOnlyProvider(_term)
            : searchMoviesOnlyProvider(_term));

    return Column(
      key: const ValueKey('search'),
      children: [
        GlassPanelHeader(
          title: 'Tag a title',
          leadingLabel: 'Cancel',
          onLeading: () => Navigator.of(context).pop(),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
          child: GlassSegmentedControl(
            labels: const ['Films', 'Shows'],
            index: isTv ? 1 : 0,
            onChanged: (i) => setState(
                () => _scope = i == 1 ? MediaType.tv : MediaType.movie),
          ),
        ),
        const SizedBox(height: AppSpace.md),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
          child: AppSearchField(
            controller: _query,
            onChanged: _onChanged,
            onGlass: true,
            placeholder: isTv ? 'Search shows' : 'Search films',
          ),
        ),
        const SizedBox(height: AppSpace.sm),
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpace.xl, AppSpace.sm, AppSpace.xl, AppSpace.xs),
          child: GlassSectionLabel(_term.isEmpty ? 'Trending' : 'Results'),
        ),
        Expanded(
          child: results.when(
            loading: () => const Center(
              child: CupertinoActivityIndicator(color: AppColors.inkSecondary),
            ),
            error: (_, __) => const GlassHint(
              icon: CupertinoIcons.wifi_exclamationmark,
              title: 'Couldn\'t search',
              body: 'Check your connection and try again.',
            ),
            data: (films) {
              if (films.isEmpty) {
                return const GlassHint(
                  icon: CupertinoIcons.search,
                  title: 'Nothing found',
                  body: 'Try a different spelling or the original title.',
                );
              }
              return ListView.builder(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(
                    AppSpace.sm, 0, AppSpace.sm, AppSpace.lg),
                itemCount: films.length,
                itemBuilder: (_, i) => MediaResultRow(
                  film: films[i],
                  onTap: () => _pick(films[i]),
                  chevron: films[i].isTv,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// One film or show in a result list: poster pill, title, year and kind.
class MediaResultRow extends StatelessWidget {
  const MediaResultRow({
    super.key,
    required this.film,
    required this.onTap,
    this.chevron = false,
  });

  final FilmModel film;
  final VoidCallback onTap;
  final bool chevron;

  @override
  Widget build(BuildContext context) {
    return GlassPressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.sm, vertical: AppSpace.xs + 2),
        child: Row(
          children: [
            PillPortrait(
              imageUrl: film.posterUrl.isEmpty ? null : film.posterUrl,
              width: 40,
              height: 58,
              placeholderIcon:
                  film.isTv ? CupertinoIcons.tv : CupertinoIcons.film,
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    film.displayTitle,
                    style: AppText.label.copyWith(
                      fontSize: 16,
                      color: AppColors.ink,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if ((film.year ?? '').isNotEmpty) film.year,
                      film.isTv ? 'Series' : 'Film',
                    ].join('  ·  '),
                    style:
                        AppText.caption.copyWith(color: AppColors.inkSecondary),
                  ),
                ],
              ),
            ),
            if (chevron)
              const Icon(CupertinoIcons.chevron_right,
                  size: 15, color: AppColors.inkTertiary),
          ],
        ),
      ),
    );
  }
}

/// Second step for a show: tag the whole show, or one episode.
class _EpisodeStep extends ConsumerStatefulWidget {
  const _EpisodeStep({super.key, required this.show, required this.onBack});

  final FilmModel show;
  final VoidCallback onBack;

  @override
  ConsumerState<_EpisodeStep> createState() => _EpisodeStepState();
}

class _EpisodeStepState extends ConsumerState<_EpisodeStep> {
  int? _season;

  @override
  Widget build(BuildContext context) {
    // Search results don't carry seasons; the details call does.
    final details = ref.watch(tvDetailsProvider(widget.show.id));
    final show = details.valueOrNull ?? widget.show;
    final seasons = show.orderedSeasons;
    final season =
        _season ?? (seasons.isNotEmpty ? seasons.first.seasonNumber : null);

    return Column(
      children: [
        GlassPanelHeader(
          title: show.displayTitle,
          subtitle: 'Whole show or one episode',
          leadingLabel: 'Back',
          onLeading: widget.onBack,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
          child: GlassPillButton(
            label: 'The whole show',
            icon: CupertinoIcons.tv,
            prominent: true,
            expand: true,
            onTap: () =>
                Navigator.of(context).pop(ExploreSubject.fromFilm(show)),
          ),
        ),
        const SizedBox(height: AppSpace.lg),
        if (details.isLoading && seasons.isEmpty)
          const Expanded(
            child: Center(
              child: CupertinoActivityIndicator(color: AppColors.inkSecondary),
            ),
          )
        else if (seasons.isEmpty)
          const Expanded(
            child: GlassHint(
              icon: CupertinoIcons.tv,
              title: 'No episode list',
              body: 'You can still post about the show as a whole.',
            ),
          )
        else ...[
          SizedBox(
            height: 32,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
              itemCount: seasons.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpace.sm),
              itemBuilder: (_, i) => GlassChip(
                label: seasons[i].label,
                selected: seasons[i].seasonNumber == season,
                onTap: () => setState(() => _season = seasons[i].seasonNumber),
              ),
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          Expanded(
            child: season == null
                ? const SizedBox.shrink()
                : _EpisodeList(show: show, season: season),
          ),
        ],
      ],
    );
  }
}

class _EpisodeList extends ConsumerWidget {
  const _EpisodeList({required this.show, required this.season});

  final FilmModel show;
  final int season;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final episodes =
        ref.watch(seasonProvider((tvId: show.id, seasonNumber: season)));
    return episodes.when(
      loading: () => const Center(
        child: CupertinoActivityIndicator(color: AppColors.inkSecondary),
      ),
      error: (_, __) => const GlassHint(
        icon: CupertinoIcons.wifi_exclamationmark,
        title: 'Couldn\'t load episodes',
        body: 'Check your connection and try again.',
      ),
      data: (list) => ListView.builder(
        padding: const EdgeInsets.fromLTRB(
            AppSpace.sm, AppSpace.xs, AppSpace.sm, AppSpace.lg),
        itemCount: list.length,
        itemBuilder: (_, i) => _EpisodeRow(
          episode: list[i],
          onTap: () => Navigator.of(context)
              .pop(ExploreSubject.fromFilm(show, episode: list[i])),
        ),
      ),
    );
  }
}

class _EpisodeRow extends StatelessWidget {
  const _EpisodeRow({required this.episode, required this.onTap});

  final EpisodeModel episode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final still = ApiConstants.getStillUrl(episode.stillPath);
    return GlassPressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.sm, vertical: AppSpace.xs + 2),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: SizedBox(
                width: 96,
                height: 54,
                child: still.isEmpty
                    ? ColoredBox(
                        color: Colors.white.withValues(alpha: 0.06),
                        child: const Icon(CupertinoIcons.tv,
                            size: 16, color: AppColors.inkTertiary),
                      )
                    : CachedNetworkImage(imageUrl: still, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    episode.code,
                    style: AppText.footnote.copyWith(
                      color: AppColors.inkTertiary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    episode.displayName,
                    style: AppText.label.copyWith(
                      fontSize: 15,
                      color: AppColors.ink,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
