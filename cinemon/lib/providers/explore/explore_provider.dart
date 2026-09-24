import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/activity_model.dart' show CommentModel;
import '../../models/explore_post_model.dart';
import '../../repositories/explore_repository.dart';
import '../auth/auth_provider.dart';

final exploreRepositoryProvider =
    Provider<ExploreRepository>((ref) => ExploreRepository());

/// What the Explore feed is narrowed to.
class ExploreFilter {
  const ExploreFilter({
    this.kind,
    this.subject,
    this.sort = ExploreSort.latest,
  });

  /// Null means every kind.
  final ExploreKind? kind;

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
  ExploreFeedNotifier(this._repo, this._filter, this._userId)
      : super(const ExploreFeedState()) {
    refresh();
  }

  final ExploreRepository _repo;
  final ExploreFilter _filter;
  final String? _userId;

  static const _pageSize = 20;

  Future<List<ExplorePost>> _page(int offset) => _repo.getFeed(
        kind: _filter.kind,
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

  /// Tap a vote. Tapping the one you already hold clears it.
  ///
  /// Optimistic: the count moves on the tap and moves back if the write fails.
  Future<bool> vote(String postId, int value) async {
    final uid = _userId;
    final index = state.posts.indexWhere((p) => p.id == postId);
    if (uid == null || index == -1) return false;

    final before = state.posts[index];
    final next = before.myVote == value ? 0 : value;
    _replace(before.withVote(next));
    try {
      await _repo.vote(postId: postId, userId: uid, value: next);
      return true;
    } catch (_) {
      if (mounted) _replace(before);
      return false;
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

  void bumpComments(String postId, int delta) {
    final i = state.posts.indexWhere((p) => p.id == postId);
    if (i != -1) _replace(state.posts[i].withCommentDelta(delta));
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
  return ExploreFeedNotifier(
    ref.watch(exploreRepositoryProvider),
    ref.watch(exploreFilterProvider),
    ref.watch(currentUserProvider)?.id,
  );
});

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

  Future<ExplorePost?> createPost({
    required ExploreKind kind,
    required String body,
    String? headline,
    double? rating,
    bool hasSpoilers = false,
    ExploreSubject? subject,
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
      );
      _ref.read(exploreFeedProvider.notifier).insert(post);
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
      _ref.read(exploreFeedProvider.notifier).replace(post);
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
    String postId,
    String content, {
    String? parentId,
  }) async {
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
      _ref.read(exploreFeedProvider.notifier).bumpComments(postId, 1);
      return c;
    } catch (_) {
      return null;
    }
  }

  Future<bool> deleteComment(String postId, String commentId) async {
    try {
      await _repo.deleteComment(commentId);
      _ref.invalidate(exploreCommentsProvider(postId));
      _ref.read(exploreFeedProvider.notifier).bumpComments(postId, -1);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> report(String postId, String reason) async {
    final uid = _uid;
    if (uid == null) return false;
    try {
      await _repo.reportPost(postId: postId, reporterId: uid, reason: reason);
      return true;
    } catch (_) {
      return false;
    }
  }
}

final exploreActionsProvider =
    Provider<ExploreActions>((ref) => ExploreActions(ref));
