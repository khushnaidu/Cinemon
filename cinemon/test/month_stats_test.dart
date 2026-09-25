import 'package:cinemon/models/activity_model.dart';
import 'package:cinemon/models/explore_post_model.dart';
import 'package:cinemon/repositories/movie_repository.dart' show TitleFacts;
import 'package:cinemon/share/month_stats.dart';
import 'package:flutter_test/flutter_test.dart';

ActivityModel _log(
  int filmId, {
  String type = 'movie',
  double? rating,
  int? season,
  int? episode,
  int day = 10,
  String? poster,
}) =>
    ActivityModel(
      id: '$filmId-$day-$episode',
      userId: 'u',
      username: 'me',
      activityType: ActivityType.watched,
      filmId: filmId,
      filmTitle: 'Title $filmId',
      filmPosterPath: poster ?? '/p$filmId.jpg',
      mediaType: type,
      seasonNumber: season,
      episodeNumber: episode,
      rating: rating,
      createdAt: DateTime(2026, 9, day),
    );

ExplorePost _take(int agree, int disagree) => ExplorePost(
      id: 't$agree',
      userId: 'u',
      username: 'me',
      kind: ExploreKind.take,
      body: 'x',
      agreeCount: agree,
      disagreeCount: disagree,
      createdAt: DateTime(2026, 9, 5),
    );

void main() {
  final month = DateTime(2026, 9);

  test('films and shows are counted apart', () {
    final m = buildMonthInFilm(
      month: month,
      activities: [
        _log(1, day: 20),
        _log(1, day: 12), // rewatch: still one film
        _log(2, day: 11),
        _log(9, type: 'tv', season: 1, episode: 3, day: 9, rating: 5),
        _log(9, type: 'tv', season: 1, episode: 2, day: 9),
        _log(9, type: 'tv', season: 1, episode: 1, day: 8),
        _log(7, type: 'tv', season: 2, episode: 1, day: 7),
      ],
      facts: const {
        'movie:1': TitleFacts(runtime: 120, genres: ['Drama'], makers: ['A']),
        'movie:2':
            TitleFacts(runtime: 90, genres: ['Drama', 'Crime'], makers: ['A']),
        'tv:9': TitleFacts(runtime: null, genres: ['Comedy'], makers: ['B']),
        'tv:7': TitleFacts(runtime: 60, genres: ['Comedy'], makers: ['C']),
      },
      takes: const [],
    );
    final f = m.films;
    expect(f.isTv, isFalse);
    expect(f.titles, 2);
    expect(f.episodes, 0);
    expect(f.minutes, 210);
    expect(f.topGenre, 'Drama');
    expect(f.topGenreShare, 1);
    expect(f.mostWatched, 'A');
    expect(f.mostWatchedCount, 2);
    expect(f.posterPaths, ['/p1.jpg', '/p2.jpg']);
    expect(f.highestRated, isNull);

    final s = m.shows;
    expect(s.isTv, isTrue);
    expect(s.titles, 2);
    expect(s.episodes, 4);
    // Three at the 40-minute default, one at 60.
    expect(s.minutes, 180);
    expect(s.topGenre, 'Comedy');
    // The show with the most episodes, not its creator.
    expect(s.mostWatched, 'Title 9');
    expect(s.mostWatchedCount, 3);
    expect(s.highestRated, 'Title 9 S1 E3');
    expect(s.posterPaths, ['/p9.jpg', '/p7.jpg']);
  });

  test('one title per maker says nothing, so there is no most watched', () {
    final m = buildMonthInFilm(
      month: month,
      activities: [_log(1), _log(2)],
      facts: const {
        'movie:1': TitleFacts(runtime: 100, genres: [], makers: ['A']),
        'movie:2': TitleFacts(runtime: 100, genres: [], makers: ['B']),
      },
      takes: const [],
    ).films;
    expect(m.mostWatched, isNull);
    expect(m.topGenre, isNull);
  });

  test('highest rated and the most-voted take', () {
    final m = buildMonthInFilm(
      month: month,
      activities: [_log(1, rating: 3.5), _log(2, rating: 4.5), _log(3)],
      facts: const {},
      takes: [_take(1, 0), _take(71, 29), _take(0, 0)],
    );
    expect(m.films.highestRated, 'Title 2');
    expect(m.films.highestRating, 4.5);
    // Takes about no title count toward the films.
    expect(m.films.hottestTakeAgree, 71);
    expect(m.shows.hottestTakeAgree, isNull);
    expect(m.shows.isEmpty, isTrue);
  });

  test('an empty month is empty', () {
    final m = buildMonthInFilm(
        month: month, activities: const [], facts: const {}, takes: const []);
    expect(m.isEmpty, isTrue);
    expect(m.films.hottestTakeAgree, isNull);
  });
}
