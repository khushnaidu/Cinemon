import 'package:cinemon/models/explore_post_model.dart';
import 'package:flutter_test/flutter_test.dart';

ExplorePost _post({int comments = 0, DateTime? fetchedAt}) => ExplorePost(
      id: 'p1',
      userId: 'u1',
      username: 'alice',
      kind: ExploreKind.parse('thought'),
      body: 'hot take',
      commentCount: comments,
      createdAt: DateTime(2026, 9, 24),
      fetchedAt: fetchedAt,
    );

void main() {
  test('a change shows until the server catches up', () {
    final loaded = _post(comments: 1, fetchedAt: DateTime(2026, 9, 24, 10));
    final changed = _post(comments: 2, fetchedAt: DateTime(2026, 9, 24, 11));
    expect(newerExplorePost(loaded, changed).commentCount, 2);
  });

  test('a later server copy wins over an old change', () {
    // Someone else replied after our change: the server's count shows.
    final changed = _post(comments: 2, fetchedAt: DateTime(2026, 9, 24, 11));
    final reloaded = _post(comments: 5, fetchedAt: DateTime(2026, 9, 24, 12));
    expect(newerExplorePost(reloaded, changed).commentCount, 5);
  });

  test('no change: the loaded copy', () {
    final loaded = _post(comments: 3, fetchedAt: DateTime(2026, 9, 24));
    expect(newerExplorePost(loaded, null).commentCount, 3);
  });

  test('stamping marks a copy as newer than what was loaded', () {
    final loaded = _post(comments: 1, fetchedAt: DateTime(2026, 1, 1));
    final changed = loaded.withCommentDelta(-1).stamped();
    expect(newerExplorePost(loaded, changed).commentCount, 0);
  });
}
