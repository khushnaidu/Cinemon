import 'package:cinemon/models/list_model.dart';
import 'package:cinemon/screens/explore/explore_lists.dart' show dailyFeatured;
import 'package:flutter_test/flutter_test.dart';

void main() {
  final row = {
    'id': 'l1',
    'user_id': 'u1',
    'kind': 'playlist',
    'title': 'Films that feel like 2am',
    'visibility': 'public',
    'item_count': 24,
    'save_count': 912,
    'cover_style': 'film',
    'cover_path': '/fallen.jpg',
    'moods': ['late_night', 'neon', 'something_old'],
    'is_select': false,
    'owner_username': 'wongwaves',
    'week_saves': 31,
    'posters': ['/a.jpg', null, '/b.jpg'],
  };

  test('an explore_lists row becomes an entry', () {
    final e = ExploreListEntry.fromRow(row);
    expect(e.list.displayTitle, 'Films that feel like 2am');
    expect(e.list.coverStyle, ListCoverStyle.film);
    expect(e.list.coverPath, '/fallen.jpg');
    expect(e.list.saveCount, 912);
    expect(e.ownerUsername, 'wongwaves');
    expect(e.weekSaves, 31);
    // Missing posters are dropped.
    expect(e.posters, ['/a.jpg', '/b.jpg']);
  });

  test('moods this build does not know are skipped, not an error', () {
    final e = ExploreListEntry.fromRow(row);
    expect(e.list.moods, [ListMood.lateNight, ListMood.neon]);
  });

  test('a list from before migration 029 is a plain six-strip', () {
    final l = FilmList.fromRow(
        {'id': 'l2', 'user_id': 'u2', 'kind': 'playlist', 'title': 'Old'});
    expect(l.coverStyle, ListCoverStyle.strip);
    expect(l.moods, isEmpty);
    expect(l.isSelect, isFalse);
  });

  test('mood slugs match the database', () {
    expect([
      for (final m in ListMood.values) m.slug
    ], [
      'slow_burn',
      'tender',
      'neon',
      'epic',
      'unsettling',
      'rainy_day',
      'sunlit',
      'late_night',
      'funny',
      'heartbreaking',
      'mind_bending',
      'cozy',
    ]);
  });

  group('dailyFeatured', () {
    final six = _selects(6);

    test('three up top, the other three in the row', () {
      final d = dailyFeatured(six, DateTime(2026, 9, 25, 9));
      expect(d.featured, hasLength(3));
      expect(d.rest, hasLength(3));
      expect({..._ids(d.featured), ..._ids(d.rest)}, hasLength(6));
    });

    test('the same all day, and different the next', () {
      final morning = dailyFeatured(six, DateTime(2026, 9, 25, 0, 5));
      final night = dailyFeatured(six, DateTime(2026, 9, 25, 23, 55));
      final tomorrow = dailyFeatured(six, DateTime(2026, 9, 26, 9));
      expect(_ids(night.featured), _ids(morning.featured));
      expect(_ids(tomorrow.featured), isNot(_ids(morning.featured)));
      // Two days in a row feature all six.
      expect({..._ids(morning.featured), ..._ids(tomorrow.featured)},
          hasLength(6));
    });

    test('with three or fewer Selects, all of them are featured', () {
      final d = dailyFeatured(_selects(2), DateTime(2026, 9, 25));
      expect(d.featured, hasLength(2));
      expect(d.rest, isEmpty);
    });
  });
}

List<ExploreListEntry> _selects(int n) => [
      for (var i = 0; i < n; i++)
        ExploreListEntry(
            list: FilmList(id: 's$i', userId: 'o', kind: 'playlist')),
    ];

List<String> _ids(List<ExploreListEntry> es) => [for (final e in es) e.list.id];
