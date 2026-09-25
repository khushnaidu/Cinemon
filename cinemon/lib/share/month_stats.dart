import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/activity_model.dart';
import '../models/explore_post_model.dart';
import '../models/film_model.dart' show MediaType;
import '../providers/explore/explore_provider.dart';
import '../providers/feed/feed_provider.dart';
import '../providers/movie/movie_provider.dart';
import '../repositories/movie_repository.dart' show TitleFacts;

/// One side of a person's month of watching (ADR 0003, P2): the films, or
/// the shows. Kept apart so a month of Severance doesn't pass itself off as
/// a month of cinema. Drawn as a share card and on your own profile.
class MonthInFilm {
  const MonthInFilm({
    required this.month,
    this.isTv = false,
    required this.titles,
    this.episodes = 0,
    required this.minutes,
    required this.posterPaths,
    this.topGenre,
    this.topGenreShare = 0,
    this.mostWatched,
    this.mostWatchedCount = 0,
    this.highestRated,
    this.highestRating,
    this.hottestTakeAgree,
  });

  /// The first day of the month.
  final DateTime month;

  /// Shows rather than films.
  final bool isTv;

  /// Different films, or different shows, logged.
  final int titles;

  /// Episodes logged; always 0 for films.
  final int episodes;

  /// Films' runtimes, or episodes' typical runtime.
  final int minutes;

  /// Newest first, one per title, at most 12.
  final List<String> posterPaths;

  final String? topGenre;

  /// Of the month's titles, the share in [topGenre], 0 to 1.
  final double topGenreShare;

  /// Films: the director behind the most of them. Shows: the one with the
  /// most episodes. Only when that's two or more; one each says nothing.
  final String? mostWatched;
  final int mostWatchedCount;

  final String? highestRated;
  final double? highestRating;

  /// Agreement on the month's most-voted hot take about this side, 0 to 100.
  final int? hottestTakeAgree;

  bool get isEmpty => titles == 0 && episodes == 0;
  double get hours => minutes / 60;

  /// Whether the month is still running, so the card says "so far".
  bool get isCurrent {
    final now = DateTime.now();
    return now.year == month.year && now.month == month.month;
  }
}

/// A month, films and shows apart.
class MonthStats {
  const MonthStats({required this.films, required this.shows});

  final MonthInFilm films;
  final MonthInFilm shows;

  DateTime get month => films.month;
  bool get isEmpty => films.isEmpty && shows.isEmpty;
  bool get isCurrent => films.isCurrent;
}

/// A title the month touched, keyed as 'movie:123' or 'tv:456'.
typedef TitleKey = String;

String _key(ActivityModel a) => '${a.mediaType}:${a.filmId}';

/// A typical episode, when TMDB has no runtime for the show.
const _episodeMinutes = 40;

MapEntry<String, int>? _top(Map<String, int> counts) => counts.isEmpty
    ? null
    : (counts.entries.toList()
          ..sort((a, b) =>
              b.value != a.value ? b.value - a.value : a.key.compareTo(b.key)))
        .first;

/// Builds the month from what was logged, what TMDB says about those titles,
/// and the month's hot takes. Pure, so it can be tested without a network.
MonthStats buildMonthInFilm({
  required DateTime month,
  required List<ActivityModel> activities,
  required Map<TitleKey, TitleFacts> facts,
  required List<ExplorePost> takes,
}) {
  bool isTv(ActivityModel a) => a.mediaType == 'tv';
  // A take about no title in particular counts toward the films.
  bool takeIsTv(ExplorePost t) => t.subject?.mediaType == 'tv';
  return MonthStats(
    films: _side(
      month: month,
      tv: false,
      activities: activities.where((a) => !isTv(a)).toList(),
      facts: facts,
      takes: takes.where((t) => !takeIsTv(t)).toList(),
    ),
    shows: _side(
      month: month,
      tv: true,
      activities: activities.where(isTv).toList(),
      facts: facts,
      takes: takes.where(takeIsTv).toList(),
    ),
  );
}

MonthInFilm _side({
  required DateTime month,
  required bool tv,
  required List<ActivityModel> activities,
  required Map<TitleKey, TitleFacts> facts,
  required List<ExplorePost> takes,
}) {
  // Newest first already; the first log of a title is its newest.
  final titles = <TitleKey, ActivityModel>{};
  final episodeCounts = <TitleKey, int>{};
  for (final a in activities) {
    titles.putIfAbsent(_key(a), () => a);
    if (a.isEpisode) {
      episodeCounts[_key(a)] = (episodeCounts[_key(a)] ?? 0) + 1;
    }
  }
  final episodes = tv ? activities.where((a) => a.isEpisode).length : 0;

  var minutes = 0;
  for (final entry in titles.entries) {
    final runtime = facts[entry.key]?.runtime;
    minutes += tv
        ? (episodeCounts[entry.key] ?? 0) * (runtime ?? _episodeMinutes)
        : runtime ?? 0;
  }

  final genreCounts = <String, int>{};
  final makerCounts = <String, int>{};
  for (final key in titles.keys) {
    final f = facts[key];
    if (f == null) continue;
    for (final g in f.genres.toSet()) {
      genreCounts[g] = (genreCounts[g] ?? 0) + 1;
    }
    for (final m in f.makers.toSet()) {
      makerCounts[m] = (makerCounts[m] ?? 0) + 1;
    }
  }
  final genre = _top(genreCounts);
  // A show's most-watched is the show itself, by episodes.
  final most = tv
      ? _top({
          for (final e in episodeCounts.entries)
            titles[e.key]!.filmTitle: e.value,
        })
      : _top(makerCounts);

  ActivityModel? best;
  for (final a in activities) {
    if (!a.hasRating) continue;
    if (best == null || a.rating! > best.rating!) best = a;
  }

  ExplorePost? hottest;
  for (final t in takes) {
    if (t.totalVotes == 0) continue;
    if (hottest == null || t.totalVotes > hottest.totalVotes) hottest = t;
  }

  return MonthInFilm(
    month: DateTime(month.year, month.month),
    isTv: tv,
    titles: titles.length,
    episodes: episodes,
    minutes: minutes,
    posterPaths: [
      for (final a in titles.values)
        if ((a.filmPosterPath ?? '').isNotEmpty) a.filmPosterPath!,
    ].take(12).toList(),
    topGenre: genre?.key,
    topGenreShare:
        genre == null || titles.isEmpty ? 0 : genre.value / titles.length,
    mostWatched: (most?.value ?? 0) >= 2 ? most!.key : null,
    mostWatchedCount: most?.value ?? 0,
    highestRated: best == null
        ? null
        : best.isEpisode
            ? '${best.filmTitle} ${best.episodeCode}'
            : best.filmTitle,
    highestRating: best?.rating,
    hottestTakeAgree:
        hottest == null ? null : (hottest.agreeShare! * 100).round(),
  );
}

/// A user's month. Six TMDB lookups at a time, each one cached for the
/// session so the profile card and the share sheet share them.
final monthInFilmProvider = FutureProvider.autoDispose
    .family<MonthStats, ({String userId, int year, int month})>((ref, p) async {
  // Kept ten minutes after the last reader, so opening the share sheet from
  // the profile card doesn't redo the lookups.
  final link = ref.keepAlive();
  final timer = Timer(const Duration(minutes: 10), link.close);
  ref.onDispose(timer.cancel);

  final from = DateTime(p.year, p.month);
  final to = DateTime(p.year, p.month + 1);

  final activities =
      await ref.watch(feedRepositoryProvider).getUserActivitiesBetween(
            userId: p.userId,
            from: from,
            to: to,
          );
  final takes = await ref.watch(exploreRepositoryProvider).getUserPostsBetween(
        userId: p.userId,
        kind: ExploreKind.take,
        from: from,
        to: to,
      );

  final keys = <TitleKey, ActivityModel>{};
  for (final a in activities) {
    keys.putIfAbsent(_key(a), () => a);
  }
  final facts = <TitleKey, TitleFacts>{};
  final entries = keys.entries.toList();
  for (var i = 0; i < entries.length; i += 6) {
    await Future.wait([
      for (final e in entries.skip(i).take(6))
        ref
            .read(titleFactsProvider((
              id: e.value.filmId,
              mediaType:
                  e.value.mediaType == 'tv' ? MediaType.tv : MediaType.movie,
            )).future)
            .then((f) => facts[e.key] = f)
            .catchError(
                (_) => const TitleFacts(runtime: null, genres: [], makers: [])),
    ]);
  }

  return buildMonthInFilm(
    month: from,
    activities: activities,
    facts: facts,
    takes: takes,
  );
});
