import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/activity_model.dart';
import '../models/explore_post_model.dart';
import '../models/film_model.dart' show MediaType;
import '../providers/explore/explore_provider.dart';
import '../providers/feed/feed_provider.dart';
import '../providers/movie/movie_provider.dart';
import '../repositories/movie_repository.dart' show TitleFacts;

/// One person's month of watching (ADR 0003, P2). Drawn as a share card and
/// as a card on your own profile.
class MonthInFilm {
  const MonthInFilm({
    required this.month,
    required this.films,
    required this.episodes,
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

  /// Different films logged.
  final int films;

  /// Episodes logged.
  final int episodes;

  /// Films' runtimes plus episodes' typical runtime.
  final int minutes;

  /// Newest first, one per title, at most 12.
  final List<String> posterPaths;

  final String? topGenre;

  /// Of the month's titles, the share in [topGenre], 0 to 1.
  final double topGenreShare;

  /// The director or creator behind the most titles, when that's two or
  /// more; one title each says nothing.
  final String? mostWatched;
  final int mostWatchedCount;

  final String? highestRated;
  final double? highestRating;

  /// Agreement on the month's most-voted hot take, 0 to 100.
  final int? hottestTakeAgree;

  bool get isEmpty => films == 0 && episodes == 0;
  double get hours => minutes / 60;

  /// Whether the month is still running, so the card says "so far".
  bool get isCurrent {
    final now = DateTime.now();
    return now.year == month.year && now.month == month.month;
  }
}

/// A title the month touched, keyed as 'movie:123' or 'tv:456'.
typedef TitleKey = String;

String _key(ActivityModel a) => '${a.mediaType}:${a.filmId}';

/// A typical episode, when TMDB has no runtime for the show.
const _episodeMinutes = 40;

/// Builds the month from what was logged, what TMDB says about those titles,
/// and the month's hot takes. Pure, so it can be tested without a network.
MonthInFilm buildMonthInFilm({
  required DateTime month,
  required List<ActivityModel> activities,
  required Map<TitleKey, TitleFacts> facts,
  required List<ExplorePost> takes,
}) {
  // Newest first already; the first log of a title is its newest.
  final titles = <TitleKey, ActivityModel>{};
  for (final a in activities) {
    titles.putIfAbsent(_key(a), () => a);
  }

  final films = titles.values.where((a) => a.mediaType != 'tv').length;
  final episodes = activities.where((a) => a.isEpisode).length;

  var minutes = 0;
  for (final entry in titles.entries) {
    final a = entry.value;
    final runtime = facts[entry.key]?.runtime;
    if (a.mediaType == 'tv') {
      final count =
          activities.where((x) => _key(x) == entry.key && x.isEpisode).length;
      minutes += count * (runtime ?? _episodeMinutes);
    } else {
      minutes += runtime ?? 0;
    }
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
  MapEntry<String, int>? top(Map<String, int> counts) => counts.isEmpty
      ? null
      : (counts.entries.toList()
            ..sort((a, b) => b.value != a.value
                ? b.value - a.value
                : a.key.compareTo(b.key)))
          .first;
  final genre = top(genreCounts);
  final maker = top(makerCounts);

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
    films: films,
    episodes: episodes,
    minutes: minutes,
    posterPaths: [
      for (final a in titles.values)
        if ((a.filmPosterPath ?? '').isNotEmpty) a.filmPosterPath!,
    ].take(12).toList(),
    topGenre: genre?.key,
    topGenreShare:
        genre == null || titles.isEmpty ? 0 : genre.value / titles.length,
    mostWatched: (maker?.value ?? 0) >= 2 ? maker!.key : null,
    mostWatchedCount: maker?.value ?? 0,
    highestRated: best?.displayTitle,
    highestRating: best?.rating,
    hottestTakeAgree:
        hottest == null ? null : (hottest.agreeShare! * 100).round(),
  );
}

/// A user's month. Six TMDB lookups at a time, each one cached for the
/// session so the profile card and the share sheet share them.
final monthInFilmProvider = FutureProvider.autoDispose
    .family<MonthInFilm, ({String userId, int year, int month})>(
        (ref, p) async {
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
