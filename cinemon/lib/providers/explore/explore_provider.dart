import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/activity_model.dart' show CommentModel;
import '../../models/explore_post_model.dart';
import '../../repositories/explore_repository.dart';
import '../auth/auth_provider.dart';
import '../feed/feed_provider.dart' show homeFeedProvider;

final exploreRepositoryProvider =
    Provider<ExploreRepository>((ref) => ExploreRepository());

/// What the Explore feed is narrowed to.
class ExploreFilter {
  const ExploreFilter({
    this.kind,
    this.subject,
    this.sort = ExploreSort.latest,
    this.userId,
  });

  /// Null means every kind.
  final ExploreKind? kind;

  /// Null means everyone. Set for a profile's Posts tab.
  final String? userId;

  /// Null means every title. Always title-level: filtering a show includes
  /// posts about its episodes.
  final ExploreSubject? subject;
  final ExploreSort sort;

  ExploreFilter copyWith({
    ExploreKind? kind,
    bool clearKind = false,
    ExploreSubject? subject,
    bool clearSubject = false,
    ExploreSort? sort,
  }) {
    return ExploreFilter(
      kind: clearKind ? null : (kind ?? this.kind),
      subject: clearSubject ? null : (subject?.titleOnly ?? this.subject),
      sort: sort ?? this.sort,
      userId: userId,
    );
  }
}

final exploreFilterProvider =
    StateProvider<ExploreFilter>((ref) => const ExploreFilter());

class ExploreFeedState {
  const ExploreFeedState({
    this.posts = const [],
    this.loading = true,
    this.loadingMore = false,
    this.hasMore = true,
    this.error,
  });

  final List<ExplorePost> posts;
  final bool loading;
  final bool loadingMore;
  final bool hasMore;
  final Object? error;

  ExploreFeedState copyWith({
    List<ExplorePost>? posts,
    bool? loading,
    bool? loadingMore,
    bool? hasMore,
    Object? error,
    bool clearError = false,
  }) {
    return ExploreFeedState(
      posts: posts ?? this.posts,
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// The paged feed for the current filter.
///
/// Rebuilt whenever the filter changes, so a page landing after the user has
/// moved on is dropped by the `mounted` checks rather than mixed in.
class ExploreFeedNotifier extends StateNotifier<ExploreFeedState> {
  ExploreFeedNotifier(this._repo, this._filter)
      : super(const ExploreFeedState()) {
    refresh();
  }

  final ExploreRepository _repo;
  final ExploreFilter _filter;

  static const _pageSize = 20;

  Future<List<ExplorePost>> _page(int offset) => _repo.getFeed(
        kind: _filter.kind,
        userId: _filter.userId,
        filmId: _filter.subject?.filmId,
        mediaType: _filter.subject?.mediaType,
        sort: _filter.sort,
        offset: offset,
        limit: _pageSize,
      );

  Future<void> refresh() async {
    state = state.copyWith(loading: state.posts.isEmpty, clearError: true);
    try {
      final posts = await _page(0);
      if (!mounted) return;
      state = ExploreFeedState(
        posts: posts,
        loading: false,
        hasMore: posts.length == _pageSize,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(loading: false, error: e);
    }
  }

  Future<void> loadMore() async {
    if (state.loading || state.loadingMore || !state.hasMore) return;
    state = state.copyWith(loadingMore: true);
    try {
      final more = await _page(state.posts.length);
      if (!mounted) return;
      // A post created between pages shifts the offsets by one; skip repeats
      // rather than showing a card twice.
      final seen = state.posts.map((p) => p.id).toSet();
      state = state.copyWith(
        posts: [...state.posts, ...more.where((p) => !seen.contains(p.id))],
        loadingMore: false,
        hasMore: more.length == _pageSize,
      );
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(loadingMore: false);
    }
  }

  void insert(ExplorePost post) {
    if (!_matches(post)) return;
    state = state.copyWith(posts: [post, ...state.posts]);
  }

  /// Swap in a fresh copy of a post, keeping its place in the feed.
  void replace(ExplorePost post) => _replace(post);

  void remove(String postId) {
    state = state.copyWith(
      posts: state.posts.where((p) => p.id != postId).toList(),
    );
  }

  /// Drop everything by one author, after blocking them.
  void removeAuthor(String userId) {
    state = state.copyWith(
      posts: state.posts.where((p) => p.userId != userId).toList(),
    );
  }

  void _replace(ExplorePost post) {
    state = state.copyWith(
      posts: [
        for (final p in state.posts) p.id == post.id ? post : p,
      ],
    );
  }

  bool _matches(ExplorePost post) {
    if (_filter.kind != null && post.kind != _filter.kind) return false;
    if (_filter.userId != null && post.userId != _filter.userId) return false;
    final s = _filter.subject;
    if (s != null &&
        (post.subject?.filmId != s.filmId ||
            post.subject?.mediaType != s.mediaType)) {
      return false;
    }
    return true;
  }
}

final exploreFeedProvider =
    StateNotifierProvider<ExploreFeedNotifier, ExploreFeedState>((ref) {
  // Rows carry the viewer's own vote, so a different account starts over.
  ref.watch(currentUserProvider);
  return ExploreFeedNotifier(
    ref.watch(exploreRepositoryProvider),
    ref.watch(exploreFilterProvider),
  );
});

/// One person's posts, newest first: their profile's Posts tab.
final userExploreFeedProvider = StateNotifierProvider.autoDispose.family<
    ExploreFeedNotifier,
    ExploreFeedState,
    ({String userId, ExploreKind? kind})>((ref, key) {
  ref.watch(currentUserProvider);
  return ExploreFeedNotifier(
    ref.watch(exploreRepositoryProvider),
    ExploreFilter(userId: key.userId, kind: key.kind),
  );
});

/// The newest copy of every post the viewer has changed this session: a
/// vote, a reply, an edit.
///
/// The same post can be drawn on Explore, on Home and on a profile, each
/// from its own page of rows. Cards read through this so a like on one shows
/// on all of them, without the three feeds having to know about each other.
final explorePostPatchesProvider =
    StateProvider<Map<String, ExplorePost>>((ref) {
  ref.watch(currentUserProvider);
  return const {};
});

/// [post], or the newer copy of it if the viewer has changed it.
ExplorePost watchLivePost(WidgetRef ref, ExplorePost post) => newerExplorePost(
    post, ref.watch(explorePostPatchesProvider.select((m) => m[post.id])));

/// Post count for the subject banner.
final exploreSubjectCountProvider =
    FutureProvider.family<int, ({int filmId, String mediaType})>(
        (ref, key) async {
  return ref.watch(exploreRepositoryProvider).countForSubject(
        filmId: key.filmId,
        mediaType: key.mediaType,
      );
});

final exploreCommentsProvider =
    FutureProvider.family<List<CommentModel>, String>((ref, postId) async {
  return ref.watch(exploreRepositoryProvider).getComments(postId);
});

/// Everything that writes. Each returns whether it worked, so the caller can
/// answer with a toast rather than an exception.
class ExploreActions {
  ExploreActions(this._ref);

  final Ref _ref;

  ExploreRepository get _repo => _ref.read(exploreRepositoryProvider);
  String? get _uid => _ref.read(currentUserProvider)?.id;

  /// The newest copy of a post this session knows: patched, in the Explore
  /// feed, or the one the caller is holding.
  ExplorePost _current(ExplorePost post) {
    var best = post;
    for (final p in _ref.read(exploreFeedProvider).posts) {
      if (p.id == post.id) best = newerExplorePost(best, p);
    }
    return newerExplorePost(
        best, _ref.read(explorePostPatchesProvider)[post.id]);
  }

  void _patch(ExplorePost post) {
    final stamped = post.stamped();
    final patches = _ref.read(explorePostPatchesProvider.notifier);
    patches.state = {...patches.state, post.id: stamped};
    _ref.read(exploreFeedProvider.notifier).replace(stamped);
  }

  /// After a reply is added or deleted: the post as the server now counts
  /// it (a deleted reply takes its answers with it), falling back to the
  /// local guess if that read fails.
  Future<void> _reconcile(ExplorePost post, int guess) async {
    try {
      final fresh = await _repo.getPost(post.id);
      if (fresh != null) {
        _patch(fresh);
        _refreshElsewhere();
        return;
      }
    } catch (_) {}
    _patch(_current(post).withCommentDelta(guess));
  }

  /// Every list of posts that isn't Explore itself: profiles and Home.
  void _refreshElsewhere() {
    _ref.invalidate(userExploreFeedProvider);
    _ref.invalidate(homeFeedProvider);
  }

  /// Tap a vote. Tapping the one you already hold clears it.
  ///
  /// Optimistic: the count moves on the tap and moves back if the write fails.
  Future<bool> vote(ExplorePost post, int value) async {
    final uid = _uid;
    if (uid == null) return false;
    final before = _current(post);
    final next = before.myVote == value ? 0 : value;
    _patch(before.withVote(next));
    try {
      await _repo.vote(postId: post.id, userId: uid, value: next);
      return true;
    } catch (_) {
      _patch(before);
      return false;
    }
  }

  Future<ExplorePost?> createPost({
    required ExploreKind kind,
    required String body,
    String? headline,
    double? rating,
    bool hasSpoilers = false,
    ExploreSubject? subject,
    String? listId,
  }) async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      final post = await _repo.createPost(
        userId: uid,
        kind: kind,
        body: body,
        headline: headline,
        rating: rating,
        hasSpoilers: hasSpoilers,
        subject: subject,
        listId: listId,
      );
      _ref.read(exploreFeedProvider.notifier).insert(post);
      _refreshElsewhere();
      final s = subject;
      if (s != null) {
        _ref.invalidate(exploreSubjectCountProvider(
            (filmId: s.filmId, mediaType: s.mediaType)));
      }
      return post;
    } catch (_) {
      return null;
    }
  }

  Future<ExplorePost?> updatePost(
    ExplorePost original, {
    required String body,
    String? headline,
    double? rating,
    bool hasSpoilers = false,
    ExploreSubject? subject,
  }) async {
    try {
      final post = await _repo.updatePost(
        id: original.id,
        body: body,
        headline: headline,
        rating: rating,
        hasSpoilers: hasSpoilers,
        subject: subject,
      );
      _patch(post);
      for (final s in {original.subject, subject}) {
        if (s == null) continue;
        _ref.invalidate(exploreSubjectCountProvider(
            (filmId: s.filmId, mediaType: s.mediaType)));
      }
      return post;
    } catch (_) {
      return null;
    }
  }

  Future<bool> deletePost(ExplorePost post) async {
    try {
      await _repo.deletePost(post.id);
      _ref.read(exploreFeedProvider.notifier).remove(post.id);
      _refreshElsewhere();
      final s = post.subject;
      if (s != null) {
        _ref.invalidate(exploreSubjectCountProvider(
            (filmId: s.filmId, mediaType: s.mediaType)));
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<CommentModel?> addComment(
    ExplorePost post,
    String content, {
    String? parentId,
  }) async {
    final postId = post.id;
    final uid = _uid;
    if (uid == null) return null;
    try {
      final c = await _repo.addComment(
        postId: postId,
        userId: uid,
        content: content,
        parentId: parentId,
      );
      _ref.invalidate(exploreCommentsProvider(postId));
      _patch(_current(post).withCommentDelta(1));
      await _reconcile(post, 0);
      return c;
    } catch (_) {
      return null;
    }
  }

  Future<bool> deleteComment(ExplorePost post, String commentId) async {
    final postId = post.id;
    try {
      await _repo.deleteComment(commentId);
      _ref.invalidate(exploreCommentsProvider(postId));
      _patch(_current(post).withCommentDelta(-1));
      await _reconcile(post, 0);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// After a report (sent by `showReportSheet`): out of every loaded feed
  /// now. The server hides it from this reader on every later read.
  void forgetReported(String postId) {
    _ref.read(exploreFeedProvider.notifier).remove(postId);
    _refreshElsewhere();
  }
}

final exploreActionsProvider =
    Provider<ExploreActions>((ref) => ExploreActions(ref));
