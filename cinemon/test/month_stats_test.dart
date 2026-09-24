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

  test('counts films once, episodes each, and adds up the runtime', () {
    final m = buildMonthInFilm(
      month: month,
      activities: [
        _log(1, day: 20),
        _log(1, day: 12), // rewatch: still one film
        _log(2, day: 11),
        _log(9, type: 'tv', season: 1, episode: 2, day: 9),
        _log(9, type: 'tv', season: 1, episode: 1, day: 8),
      ],
      facts: const {
        'movie:1': TitleFacts(runtime: 120, genres: ['Drama'], makers: ['A']),
        'movie:2':
            TitleFacts(runtime: 90, genres: ['Drama', 'Crime'], makers: ['A']),
        'tv:9': TitleFacts(runtime: null, genres: ['Comedy'], makers: ['B']),
      },
      takes: const [],
    );
    expect(m.films, 2);
    expect(m.episodes, 2);
    // 120 + 90 + two episodes at the 40-minute default.
    expect(m.minutes, 290);
    expect(m.topGenre, 'Drama');
    expect(m.topGenreShare, closeTo(2 / 3, 0.001));
    expect(m.mostWatched, 'A');
    expect(m.mostWatchedCount, 2);
    expect(m.posterPaths, ['/p1.jpg', '/p2.jpg', '/p9.jpg']);
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
    );
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
    expect(m.highestRated, 'Title 2');
    expect(m.highestRating, 4.5);
    expect(m.hottestTakeAgree, 71);
  });

  test('an empty month is empty', () {
    final m = buildMonthInFilm(
        month: month, activities: const [], facts: const {}, takes: const []);
    expect(m.isEmpty, isTrue);
    expect(m.hottestTakeAgree, isNull);
  });
}
