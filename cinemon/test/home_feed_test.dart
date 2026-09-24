import 'package:cinemon/models/activity_model.dart';
import 'package:cinemon/models/badge_model.dart';
import 'package:cinemon/models/explore_post_model.dart';
import 'package:cinemon/models/home_feed.dart';
import 'package:flutter_test/flutter_test.dart';

ActivityModel _activity(String id) => ActivityModel(
      id: id,
      userId: 'u',
      username: 'u',
      activityType: ActivityType.watched,
      filmId: 1,
      filmTitle: 'F',
      createdAt: DateTime(2026),
    );

ExplorePost _post(String id) => ExplorePost(
      id: id,
      userId: 'u',
      username: 'u',
      kind: ExploreKind.thought,
      body: 'b',
      createdAt: DateTime(2026),
    );

HomeFeedRef _ref(String source, String id) =>
    HomeFeedRef(source: source, id: id, createdAt: '2026-09-23T10:00:00Z');

void main() {
  group('zipHomeFeed', () {
    test('keeps the view order across both tables', () {
      final items = zipHomeFeed(
        [
          _ref('explore', 'p1'),
          _ref('activity', 'a1'),
          _ref('explore', 'p2'),
          _ref('activity', 'a2'),
        ],
        activities: {'a2': _activity('a2'), 'a1': _activity('a1')},
        posts: {'p2': _post('p2'), 'p1': _post('p1')},
      );
      expect(items.map((i) => i.id), ['p1', 'a1', 'p2', 'a2']);
      expect(items[0], isA<HomeExplorePost>());
      expect(items[1], isA<HomeActivity>());
    });

    test('skips rows the viewer can no longer see', () {
      final items = zipHomeFeed(
        [_ref('explore', 'reported'), _ref('activity', 'a1')],
        activities: {'a1': _activity('a1')},
        posts: const {},
      );
      expect(items.map((i) => i.id), ['a1']);
    });

    test('an id in the wrong table does not cross over', () {
      final items = zipHomeFeed(
        [_ref('activity', 'x')],
        activities: const {},
        posts: {'x': _post('x')},
      );
      expect(items, isEmpty);
    });
  });

  group('ExplorePost list rows', () {
    Map<String, dynamic> row(Map<String, dynamic> extra) => {
          'id': 'p',
          'user_id': 'u',
          'username': 'alice',
          'kind': 'list',
          'body': '',
          'created_at': '2026-09-23T10:00:00Z',
          ...extra,
        };

    test('parses the joined playlist, nulls in the posters kept', () {
      final p = ExplorePost.fromRow(row({
        'list_id': 'l1',
        'list_title': 'Rainy day',
        'list_item_count': 7,
        'list_posters': ['/a.jpg', null, '/c.jpg'],
      }));
      expect(p.kind, ExploreKind.list);
      expect(p.list!.id, 'l1');
      expect(p.list!.title, 'Rainy day');
      expect(p.list!.itemCount, 7);
      expect(p.list!.posters, ['/a.jpg', null, '/c.jpg']);
      expect(p.subject, isNull);
    });

    test('a vote keeps the playlist', () {
      final p = ExplorePost.fromRow(row({'list_id': 'l1', 'list_title': 'X'}))
          .withVote(1);
      expect(p.agreeCount, 1);
      expect(p.list?.id, 'l1');
    });

    test('list posts take comments; takes still do not', () {
      expect(ExploreKind.list.allowsComments, isTrue);
      expect(ExploreKind.take.allowsComments, isFalse);
    });
  });

  group('badge progress', () {
    test('counts toward the target, capped at it', () {
      expect(BadgeRegistry.reviewer25.progressLabel({'reviews': 12}),
          '12 / 25 reviews');
      expect(BadgeRegistry.reviewer10.progressLabel({'reviews': 40}),
          '10 / 10 reviews');
      expect(BadgeRegistry.cleanSlate.progressLabel(const {}),
          '0 / 10 struck off');
    });

    test('yes-or-no badges have no count', () {
      expect(BadgeRegistry.curator.progressLabel({'reviews': 3}), isNull);
      expect(BadgeRegistry.firstReview.progressLabel({'reviews': 0}), isNull);
    });

    test('every badge id is unique', () {
      final ids = BadgeRegistry.allBadges.map((b) => b.id).toList();
      expect(ids.toSet().length, ids.length);
    });
  });
}
