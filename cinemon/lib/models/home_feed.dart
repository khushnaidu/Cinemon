import 'activity_model.dart';
import 'explore_post_model.dart';

/// One row of the `home_feed` view: which table, which row, and when.
///
/// [createdAt] is kept as the server sent it, so the next page's cursor
/// compares against exactly the value Postgres holds.
class HomeFeedRef {
  const HomeFeedRef({
    required this.source,
    required this.id,
    required this.createdAt,
  });

  factory HomeFeedRef.fromRow(Map<String, dynamic> row) => HomeFeedRef(
        source: row['source'] as String,
        id: row['id'] as String,
        createdAt: row['created_at'] as String,
      );

  /// 'activity' or 'explore'.
  final String source;
  final String id;
  final String createdAt;

  bool get isExplore => source == 'explore';
}

/// Something on Home: a friend's log, or one of their Explore posts.
sealed class HomeFeedItem {
  const HomeFeedItem();

  String get id;
}

class HomeActivity extends HomeFeedItem {
  const HomeActivity(this.activity);

  final ActivityModel activity;

  @override
  String get id => activity.id;
}

class HomeExplorePost extends HomeFeedItem {
  const HomeExplorePost(this.post);

  final ExplorePost post;

  @override
  String get id => post.id;
}

/// Puts a page back in the view's order from the two lookups. A ref with no
/// row is one the viewer can't see (a reported post, a list gone private) or
/// that was deleted between the two queries; it's skipped.
List<HomeFeedItem> zipHomeFeed(
  List<HomeFeedRef> refs, {
  required Map<String, ActivityModel> activities,
  required Map<String, ExplorePost> posts,
}) {
  final items = <HomeFeedItem>[];
  for (final r in refs) {
    if (r.isExplore) {
      final p = posts[r.id];
      if (p != null) items.add(HomeExplorePost(p));
    } else {
      final a = activities[r.id];
      if (a != null) items.add(HomeActivity(a));
    }
  }
  return items;
}

/// Loaded pages of Home.
class HomeFeed {
  const HomeFeed({
    this.items = const [],
    this.cursor,
    this.hasMore = false,
    this.loadingMore = false,
  });

  final List<HomeFeedItem> items;

  /// The last ref of the last page, including any that were skipped.
  final HomeFeedRef? cursor;
  final bool hasMore;
  final bool loadingMore;

  HomeFeed copyWith({bool? loadingMore}) => HomeFeed(
        items: items,
        cursor: cursor,
        hasMore: hasMore,
        loadingMore: loadingMore ?? this.loadingMore,
      );
}
