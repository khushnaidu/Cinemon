import 'package:cinemon/models/film_model.dart';
import 'package:cinemon/models/trailer_item.dart';
import 'package:cinemon/providers/trailer/trailer_seen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> row(Map<String, dynamic> extra) => {
        'feed': 'trending',
        'rank': 1,
        'media_type': 'movie',
        'tmdb_id': 1153576,
        'video_id': 'T7Xy23pznXY',
        'title': 'Street Fighter',
        ...extra,
      };

  test('parses a feed row from the view', () {
    final t = TrailerItem.fromRow(row({
      'video_title': 'STREET FIGHTER Official Trailer 2 (2026)',
      'category': 'Trailer',
      'published_at': '2026-09-01T16:08:26+00:00',
      'poster_path': '/p.jpg',
      'year': 2026,
      'genre_ids': [28, 14],
    }));
    expect(t.mediaType, MediaType.movie);
    expect(t.videoId, 'T7Xy23pznXY');
    expect(t.year, 2026);
    expect(t.genreIds, [28, 14]);
    expect(t.publishedAt, DateTime.utc(2026, 9, 1, 16, 8, 26));
    expect(t.thumbnailUrl, contains('T7Xy23pznXY'));
  });

  test('TMDB fallback rows have no video title or date', () {
    final t = TrailerItem.fromRow(row({'genre_ids': null}));
    expect(t.videoTitle, isNull);
    expect(t.publishedAt, isNull);
    expect(t.genreIds, isEmpty);
  });

  test('a show becomes a tv film for the watchlist', () {
    final film = TrailerItem.fromRow(
        row({'media_type': 'tv', 'title': 'Severance', 'year': 2025})).film;
    expect(film.isTv, isTrue);
    expect(film.displayTitle, 'Severance');
    expect(film.id, 1153576);
  });

  group('orderUnseenFirst', () {
    TrailerItem t(String v) => TrailerItem.fromRow(row({'video_id': v}));
    final now = DateTime(2026, 9, 24, 12);
    final feed = [t('a'), t('b'), t('c'), t('d')];

    test('unseen keep the feed order, ahead of seen', () {
      final out = orderUnseenFirst(
          feed, {'a': now.subtract(const Duration(hours: 1))},
          now: now);
      expect(out.map((x) => x.videoId), ['b', 'c', 'd', 'a']);
    });

    test('seen ones come back the longest ago first', () {
      final out = orderUnseenFirst(
          feed,
          {
            'a': now.subtract(const Duration(hours: 1)),
            'b': now.subtract(const Duration(days: 2)),
            'c': now.subtract(const Duration(hours: 5)),
            'd': now.subtract(const Duration(minutes: 5)),
          },
          now: now);
      expect(out.map((x) => x.videoId), ['b', 'c', 'a', 'd']);
    });

    test('a week later, a watched trailer is unseen again', () {
      final out = orderUnseenFirst(
          feed, {'a': now.subtract(const Duration(days: 8))},
          now: now);
      expect(out.map((x) => x.videoId), ['a', 'b', 'c', 'd']);
    });
  });
}
