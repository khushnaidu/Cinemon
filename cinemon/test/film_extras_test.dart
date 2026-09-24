import 'package:cinemon/models/film_extras.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> releases(List<(int, String)> dates, {String region = 'US'}) => {
      'results': [
        {
          'iso_3166_1': region,
          'release_dates': [
            for (final (type, at) in dates) {'type': type, 'release_date': at},
          ],
        },
      ],
    };

void main() {
  final now = DateTime.utc(2026, 9, 23);

  TheatricalPhase phase(Map<String, dynamic> json, {String region = 'US'}) =>
      TheatricalStatus.fromReleaseDates(json, region: region, now: now).phase;

  group('TheatricalStatus', () {
    test('opened three weeks ago, no digital release: in theaters', () {
      expect(phase(releases([(3, '2026-09-01T00:00:00.000Z')])),
          TheatricalPhase.inTheaters);
    });

    test('limited release counts as theatrical', () {
      expect(phase(releases([(2, '2026-09-10T00:00:00.000Z')])),
          TheatricalPhase.inTheaters);
    });

    test('out digitally since opening: not in theaters', () {
      expect(
        phase(releases([
          (3, '2026-08-01T00:00:00.000Z'),
          (4, '2026-09-15T00:00:00.000Z'),
        ])),
        TheatricalPhase.none,
      );
    });

    test('digital date announced for later: still in theaters', () {
      expect(
        phase(releases([
          (3, '2026-09-01T00:00:00.000Z'),
          (4, '2026-10-20T00:00:00.000Z'),
        ])),
        TheatricalPhase.inTheaters,
      );
    });

    test('opened longer ago than the window: not in theaters', () {
      expect(phase(releases([(3, '2026-06-01T00:00:00.000Z')])),
          TheatricalPhase.none);
    });

    test('re-release in the window counts, despite an old digital date', () {
      expect(
        phase(releases([
          (3, '2010-07-16T00:00:00.000Z'),
          (4, '2010-12-07T00:00:00.000Z'),
          (3, '2026-09-18T00:00:00.000Z'),
        ])),
        TheatricalPhase.inTheaters,
      );
    });

    test('future theatrical date: coming soon, with the date', () {
      final s = TheatricalStatus.fromReleaseDates(
        releases([(3, '2026-10-02T00:00:00.000Z')]),
        region: 'US',
        now: now,
      );
      expect(s.phase, TheatricalPhase.comingSoon);
      expect(s.date, DateTime.utc(2026, 10, 2));
    });

    test('other regions are ignored', () {
      expect(
        phase(releases([(3, '2026-09-01T00:00:00.000Z')], region: 'GB')),
        TheatricalPhase.none,
      );
    });
  });

  group('FilmExtras.fromTmdb', () {
    final movie = {
      'videos': {
        'results': [
          {'site': 'YouTube', 'key': 'clip', 'name': 'Clip', 'type': 'Clip', 'official': true, 'published_at': '2026-09-01T00:00:00.000Z'},
          {'site': 'YouTube', 'key': 'old', 'name': 'Trailer 1', 'type': 'Trailer', 'official': true, 'published_at': '2026-05-01T00:00:00.000Z'},
          {'site': 'YouTube', 'key': 'new', 'name': 'Trailer 2', 'type': 'Trailer', 'official': true, 'published_at': '2026-08-01T00:00:00.000Z'},
          {'site': 'YouTube', 'key': 'fan', 'name': 'Fan', 'type': 'Trailer', 'official': false, 'published_at': '2026-09-10T00:00:00.000Z'},
          {'site': 'Vimeo', 'key': 'vimeo', 'name': 'Elsewhere', 'type': 'Trailer', 'official': true},
        ],
      },
      'credits': {
        'cast': [
          {'id': 2, 'name': 'Second', 'character': 'B', 'order': 1},
          {'id': 1, 'name': 'First', 'character': '', 'order': 0},
        ],
        'crew': [
          {'id': 9, 'name': 'Dir', 'job': 'Director'},
          {'id': 8, 'name': 'Writer', 'job': 'Screenplay'},
        ],
      },
      'watch/providers': {
        'results': {
          'US': {
            'link': 'https://www.themoviedb.org/movie/1/watch?locale=US',
            'flatrate': [
              {'provider_id': 8, 'provider_name': 'Netflix', 'display_priority': 5},
              {'provider_id': 15, 'provider_name': 'Hulu', 'display_priority': 1},
            ],
            'rent': [{'provider_id': 2, 'provider_name': 'Apple TV', 'display_priority': 3}],
            'buy': [{'provider_id': 2, 'provider_name': 'Apple TV', 'display_priority': 3}],
          },
        },
      },
    };

    test('picks the newest official trailer and drops non-YouTube videos', () {
      final e = FilmExtras.fromTmdb(movie, isTv: false, region: 'US');
      expect(e.trailer?.key, 'new');
      expect(e.videos.map((v) => v.key), isNot(contains('vimeo')));
    });

    test('cast in billing order, blank character is null, directors only', () {
      final e = FilmExtras.fromTmdb(movie, isTv: false, region: 'US');
      expect(e.cast.map((c) => c.name), ['First', 'Second']);
      expect(e.cast.first.character, isNull);
      expect(e.directors.map((d) => d.name), ['Dir']);
    });

    test('providers sorted by priority; rent and buy merged once', () {
      final e = FilmExtras.fromTmdb(movie, isTv: false, region: 'US');
      expect(e.watch!.included.map((p) => p.name), ['Hulu', 'Netflix']);
      expect(e.watch!.paid.map((p) => p.name), ['Apple TV']);
    });

    test('no providers for the region: watch is null', () {
      final e = FilmExtras.fromTmdb(movie, isTv: false, region: 'FR');
      expect(e.watch, isNull);
    });

    test('shows read aggregate credits and creators', () {
      final e = FilmExtras.fromTmdb({
        'aggregate_credits': {
          'cast': [
            {'id': 1, 'name': 'Bryan', 'order': 0, 'roles': [{'character': 'Walter White'}]},
          ],
        },
        'created_by': [{'id': 5, 'name': 'Vince'}],
      }, isTv: true, region: 'US');
      expect(e.cast.single.character, 'Walter White');
      expect(e.directors.single.job, 'Creator');
      expect(e.theatrical.phase, TheatricalPhase.none);
    });
  });
}
