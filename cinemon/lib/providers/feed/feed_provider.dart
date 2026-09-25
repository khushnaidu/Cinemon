import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../models/activity_model.dart';
import '../../models/badge_model.dart';
import '../../models/episode_model.dart';
import '../../models/film_model.dart';
import '../../models/home_feed.dart';
import '../../models/person_page.dart';
import '../../models/user_model.dart';
import '../../repositories/feed_repository.dart';
import '../../repositories/user_repository.dart';
import '../auth/auth_provider.dart';
import '../explore/explore_provider.dart' show exploreRepositoryProvider;
import '../follow/follow_provider.dart' show followingIdsProvider;
import '../lists/list_provider.dart' show watchlistActionsProvider;
import '../movie/movie_provider.dart' show personPageProvider;

/// Provider for FeedRepository singleton
final feedRepositoryProvider = Provider<FeedRepository>((ref) {
  return FeedRepository();
});

/// Provider for UserRepository singleton
final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository();
});

/// Provider for current user's profile data
final currentUserProfileProvider = FutureProvider<UserModel?>((ref) async {
  final authUser = ref.watch(currentUserProvider);
  if (authUser == null) return null;

  final userRepo = ref.watch(userRepositoryProvider);
  // Once a launch, for the badges that go by the poster's own clock.
  unawaited(userRepo.reportTimeZone(authUser.uid));
  return userRepo.getUser(authUser.uid);
});

/// What someone has earned, newest first, with dates (migration 009).
final earnedBadgesProvider = FutureProvider.autoDispose
    .family<List<EarnedBadge>, String>((ref, userId) async {
  return ref.watch(userRepositoryProvider).getEarnedBadges(userId);
});

/// Your counts toward badges you haven't earned. Only ever your own.
final myBadgeProgressProvider =
    FutureProvider.autoDispose<Map<String, int>>((ref) async {
  if (ref.watch(currentUserProvider) == null) return const {};
  return ref.watch(userRepositoryProvider).getMyBadgeProgress();
});

/// Provider for a specific user's profile
final userProfileProvider =
    FutureProvider.family<UserModel?, String>((ref, userId) async {
  final userRepo = ref.watch(userRepositoryProvider);
  return userRepo.getUser(userId);
});

/// Home: your logs and those of people you follow, and their Explore posts, in one
/// timeline (ADR 0001, 4.6). Each page is a list of references from the
/// `home_feed` view, then two batch reads to fill them in.
class HomeFeedNotifier extends AsyncNotifier<HomeFeed> {
  static const _pageSize = 20;

  @override
  Future<HomeFeed> build() async {
    final currentUser = ref.watch(currentUserProvider);
    if (currentUser == null) {
      throw Exception('Not logged in');
    }
    // The view works out who you follow itself; this only rebuilds
    // Home when that changes.
    await ref.watch(followingIdsProvider.future);
    try {
      return await _page(null, const []);
    } catch (e) {
      throw Exception('Failed to load feed: $e');
    }
  }

  Future<HomeFeed> _page(HomeFeedRef? after, List<HomeFeedItem> before) async {
    final refs = await ref
        .read(feedRepositoryProvider)
        .getHomeFeedRefs(after: after, limit: _pageSize);
    final activityIds = [
      for (final r in refs)
        if (!r.isExplore) r.id
    ];
    final postIds = [
      for (final r in refs)
        if (r.isExplore) r.id
    ];
    final (activities, posts) = await (
      ref.read(feedRepositoryProvider).getActivitiesByIds(activityIds),
      ref.read(exploreRepositoryProvider).getPostsByIds(postIds),
    ).wait;
    final items = zipHomeFeed(
      refs,
      activities: {for (final a in activities) a.id: a},
      posts: {for (final p in posts) p.id: p},
    );
    return HomeFeed(
      items: [...before, ...items],
      cursor: refs.isEmpty ? after : refs.last,
      hasMore: refs.length == _pageSize,
    );
  }

  /// The next page, once the reader is near the end.
  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.loadingMore) return;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final next = await _page(current.cursor, current.items);
      state = AsyncData(next);
    } catch (_) {
      // Keep what's shown; the next swipe will try again.
      state = AsyncData(current.copyWith(loadingMore: false));
    }
  }
}

final homeFeedProvider =
    AsyncNotifierProvider<HomeFeedNotifier, HomeFeed>(HomeFeedNotifier.new);

/// Stream provider for real-time feed updates
final homeFeedStreamProvider = StreamProvider<List<ActivityModel>>((ref) {
  final currentUser = ref.watch(currentUserProvider);
  if (currentUser == null) return Stream.value([]);

  // We need to get friend IDs first, but for streams this is tricky
  // For now, return empty and let the FutureProvider handle it
  // In production, you'd want to combine streams properly
  final feedRepo = ref.watch(feedRepositoryProvider);

  // This is a simplified version - ideally you'd combine with friend IDs stream
  return feedRepo.watchFeedActivities(userIds: [currentUser.uid]);
});

/// Provider for a specific user's activities
/// Fetches up to 100 activities for the profile page
final userActivitiesProvider =
    FutureProvider.family<List<ActivityModel>, String>((ref, userId) async {
  final feedRepo = ref.watch(feedRepositoryProvider);
  return feedRepo.getUserActivities(userId: userId, limit: 100);
});

/// Provider for activities about a specific film
final filmActivitiesProvider =
    FutureProvider.family<List<ActivityModel>, int>((ref, filmId) async {
  final feedRepo = ref.watch(feedRepositoryProvider);
  return feedRepo.getFilmActivities(filmId: filmId);
});

/// Provider to get current user's activity for a specific film
/// Returns null if user hasn't posted about this film
final userFilmActivityProvider =
    FutureProvider.family<ActivityModel?, int>((ref, filmId) async {
  final currentUser = ref.watch(currentUserProvider);
  if (currentUser == null) return null;

  final feedRepo = ref.watch(feedRepositoryProvider);
  return feedRepo.getUserFilmActivity(
    userId: currentUser.uid,
    filmId: filmId,
  );
});

/// How many of a person's titles you've logged, and your average rating.
final personHistoryProvider = FutureProvider.autoDispose
    .family<PersonHistory, int>((ref, personId) async {
  final currentUser = ref.watch(currentUserProvider);
  if (currentUser == null) return PersonHistory.none;
  final page = await ref.watch(personPageProvider(personId).future);
  return ref.watch(feedRepositoryProvider).getPersonHistory(
        userId: currentUser.uid,
        titles: page.titles,
      );
});

/// The current user's episode posts for one show, keyed "S{n}E{m}" so the
/// episode list can mark what's already been reviewed in O(1).
final userEpisodeActivitiesProvider =
    FutureProvider.family<Map<String, ActivityModel>, int>((ref, showId) async {
  final currentUser = ref.watch(currentUserProvider);
  if (currentUser == null) return const {};

  final feedRepo = ref.watch(feedRepositoryProvider);
  final rows = await feedRepo.getUserEpisodeActivities(
    userId: currentUser.uid,
    showId: showId,
  );
  final map = <String, ActivityModel>{};
  for (final a in rows) {
    // Newest first, so the first one seen per episode wins.
    map.putIfAbsent(a.episodeCode!, () => a);
  }
  return map;
});

/// Reviews of a film by the people you follow, for its page.
final friendsFilmActivitiesProvider =
    FutureProvider.family<List<ActivityModel>, int>((ref, filmId) async {
  final currentUser = ref.watch(currentUserProvider);
  if (currentUser == null) return [];

  final followingIds = await ref.watch(followingIdsProvider.future);
  if (followingIds.isEmpty) return [];

  final feedRepo = ref.watch(feedRepositoryProvider);
  final allActivities = await feedRepo.getFilmActivities(filmId: filmId);

  // The people you follow, not you.
  return allActivities
      .where(
          (a) => followingIds.contains(a.userId) && a.userId != currentUser.uid)
      .toList();
});

/// State notifier for creating new activities
class CreateActivityNotifier extends StateNotifier<AsyncValue<void>> {
  final FeedRepository _feedRepo;
  final UserRepository _userRepo;
  final Ref _ref;

  /// Badges the last post earned, for the toast. The database awards them
  /// (migration 009); this is only the difference it made.
  List<String> lastUnlockedBadges = [];

  CreateActivityNotifier(this._feedRepo, this._userRepo, this._ref)
      : super(const AsyncValue.data(null));

  /// What [before] didn't have that the profile has now.
  Future<List<String>> _newBadges(String uid, List<String> before) async {
    try {
      final after = await _userRepo.getUser(uid);
      final had = before.toSet();
      return [...?after?.badgeIds.where((b) => !had.contains(b))];
    } catch (_) {
      return const [];
    }
  }

  /// Post a new "watched" activity (no review required)
  Future<ActivityModel?> postWatched({
    required FilmModel film,
    EpisodeModel? episode,
  }) async {
    final currentUser = _ref.read(currentUserProvider);
    if (currentUser == null) {
      state = AsyncValue.error('Not logged in', StackTrace.current);
      return null;
    }

    state = const AsyncValue.loading();

    try {
      // Get current user's profile for denormalized data
      final userProfile = await _userRepo.getUser(currentUser.uid);

      final activity = ActivityModel(
        id: '', // assigned by the database on insert
        userId: currentUser.uid,
        username: userProfile?.username ?? 'Unknown',
        userPhotoUrl: userProfile?.photoUrl,
        activityType: ActivityType.watched,
        filmId: film.id,
        filmTitle: film.displayTitle,
        filmPosterPath: film.posterPath,
        filmBackdropPath: film.backdropPath,
        filmYear: film.year,
        mediaType: film.isMovie ? 'movie' : 'tv',
        seasonNumber: episode?.seasonNumber,
        episodeNumber: episode?.episodeNumber,
        episodeTitle: episode?.name,
        episodeStillPath: episode?.stillPath,
        createdAt: DateTime.now(),
      );

      final created =
          await _feedRepo.createActivity(activity, genreIds: film.genreIds);
      // A log can strike a watchlist title, which can earn Clean Slate.
      lastUnlockedBadges =
          await _newBadges(currentUser.uid, userProfile?.badgeIds ?? const []);
      state = const AsyncValue.data(null);

      // Refresh the feed and user's activities
      _ref.invalidate(homeFeedProvider);
      _ref.invalidate(userActivitiesProvider(currentUser.uid));
      _ref.invalidate(userFilmActivityProvider(film.id));
      // Logging strikes it off your watchlist (migration 008 trigger).
      _ref.read(watchlistActionsProvider).refresh();
      _ref.invalidate(userEpisodeActivitiesProvider(film.id));

      return created;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Post a new review activity (with rating and optional text)
  Future<ActivityModel?> postReview({
    required FilmModel film,
    EpisodeModel? episode,
    required double rating,
    String? reviewText,
    File? voiceNote,
    int voiceNoteDurationMs = 0,
    List<double> voiceNoteWaveform = const [],
    List<File> photos = const [],
  }) async {
    final currentUser = _ref.read(currentUserProvider);
    if (currentUser == null) {
      state = AsyncValue.error('Not logged in', StackTrace.current);
      return null;
    }

    state = const AsyncValue.loading();

    try {
      // Get current user's profile
      final userProfile = await _userRepo.getUser(currentUser.uid);

      // Media is uploaded before the row is written, so the id has to exist
      // first — the storage path is keyed on it. A post with no media leaves
      // the id blank and lets the column default assign one.
      final hasMedia = voiceNote != null || photos.isNotEmpty;
      final activityId = hasMedia ? const Uuid().v4() : '';

      String? voiceNoteUrl;
      var photoUrls = const <String>[];
      if (hasMedia) {
        try {
          if (voiceNote != null) {
            voiceNoteUrl = await _feedRepo.uploadVoiceNote(
              uid: currentUser.uid,
              activityId: activityId,
              file: voiceNote,
            );
          }
          if (photos.isNotEmpty) {
            photoUrls = await _feedRepo.uploadReviewPhotos(
              uid: currentUser.uid,
              activityId: activityId,
              files: photos,
            );
          }
        } catch (_) {
          // Don't leave half an upload in the bucket paying rent for a post
          // that was never made.
          await _feedRepo
              .deleteReviewMedia(
                uid: currentUser.uid,
                activityId: activityId,
              )
              .catchError((_) {});
          rethrow;
        }
      }

      final activity = ActivityModel(
        id: activityId,
        userId: currentUser.uid,
        username: userProfile?.username ?? 'Unknown',
        userPhotoUrl: userProfile?.photoUrl,
        activityType: ActivityType.reviewed,
        filmId: film.id,
        filmTitle: film.displayTitle,
        filmPosterPath: film.posterPath,
        filmBackdropPath: film.backdropPath,
        filmYear: film.year,
        mediaType: film.isMovie ? 'movie' : 'tv',
        seasonNumber: episode?.seasonNumber,
        episodeNumber: episode?.episodeNumber,
        episodeTitle: episode?.name,
        episodeStillPath: episode?.stillPath,
        rating: rating,
        reviewText: reviewText,
        voiceNoteUrl: voiceNoteUrl,
        voiceNoteDurationMs: voiceNoteUrl == null ? 0 : voiceNoteDurationMs,
        voiceNoteWaveform: voiceNoteUrl == null ? const [] : voiceNoteWaveform,
        photoUrls: photoUrls,
        createdAt: DateTime.now(),
      );

      final created =
          await _feedRepo.createActivity(activity, genreIds: film.genreIds);

      // review_count and badges are both the database's now (triggers on
      // activities); this only reads back what changed.
      lastUnlockedBadges =
          await _newBadges(currentUser.uid, userProfile?.badgeIds ?? const []);

      state = const AsyncValue.data(null);

      // Refresh the feed and profile to show updated review count
      _ref.invalidate(homeFeedProvider);
      _ref.invalidate(currentUserProfileProvider);
      _ref.invalidate(userActivitiesProvider(currentUser.uid));
      _ref.invalidate(userFilmActivityProvider(film.id));
      // Logging strikes it off your watchlist (migration 008 trigger).
      _ref.read(watchlistActionsProvider).refresh();
      _ref.invalidate(userEpisodeActivitiesProvider(film.id));

      return created;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Get the last unlocked badges (for showing notification)
  List<String> getAndClearUnlockedBadges() {
    final badges = List<String>.from(lastUnlockedBadges);
    lastUnlockedBadges = [];
    return badges;
  }

  /// Delete an activity
  /// Pass isReview=true to also decrement the review count
  Future<void> deleteActivity(String activityId,
      {bool isReview = false, int? filmId}) async {
    final currentUser = _ref.read(currentUserProvider);
    if (currentUser == null) {
      state = AsyncValue.error('Not logged in', StackTrace.current);
      return;
    }

    state = const AsyncValue.loading();

    try {
      // Comments, likes and reactions cascade; review_count is
      // decremented by the activities_review_count_trg trigger.
      await _feedRepo.deleteActivity(activityId);

      // Storage has no cascade, so the files outlive the row unless we go and
      // get them. Best-effort and after the delete: the post being gone is
      // what the user asked for, and failing that on a storage hiccup would
      // leave the row they wanted removed still standing.
      try {
        await _feedRepo.deleteReviewMedia(
          uid: currentUser.uid,
          activityId: activityId,
        );
      } catch (_) {}

      state = const AsyncValue.data(null);

      // Refresh the feed, profile, and activities
      _ref.invalidate(homeFeedProvider);
      _ref.invalidate(currentUserProfileProvider);
      _ref.invalidate(userActivitiesProvider(currentUser.uid));
      if (filmId != null) {
        _ref.invalidate(userFilmActivityProvider(filmId));
        _ref.invalidate(userEpisodeActivitiesProvider(filmId));
        _ref.invalidate(friendsFilmActivitiesProvider(filmId));
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Update an existing activity (edit rating/review)
  /// Handles upgrade from watched to reviewed and downgrade from reviewed to watched
  Future<bool> updateActivity({
    required ActivityModel activity,
    double? newRating,
    String? newReviewText,
    ReviewMediaEdit? media,
  }) async {
    final currentUser = _ref.read(currentUserProvider);
    if (currentUser == null) {
      state = AsyncValue.error('Not logged in', StackTrace.current);
      return false;
    }

    // Verify ownership
    if (activity.userId != currentUser.uid) {
      state = AsyncValue.error(
          'Cannot edit others\' activities', StackTrace.current);
      return false;
    }

    state = const AsyncValue.loading();

    try {
      final hasNewRating = newRating != null && newRating > 0;
      final trimmedReviewText = newReviewText?.trim();
      final hasNewReview =
          trimmedReviewText != null && trimmedReviewText.isNotEmpty;

      // Media the post will end up with. A null [media] means the caller isn't
      // touching it, so the activity keeps whatever it already had.
      var voiceNoteUrl = activity.voiceNoteUrl;
      var voiceNoteDurationMs = activity.voiceNoteDurationMs;
      var voiceNoteWaveform = activity.voiceNoteWaveform;
      var photoUrls = activity.photoUrls;

      // Files that are no longer referenced once this save lands. Collected
      // first and deleted last: a storage error must not be able to leave the
      // row pointing at something that's already gone.
      final orphaned = <String>[];

      if (media != null) {
        if (media.newVoiceNote != null) {
          voiceNoteUrl = await _feedRepo.uploadVoiceNote(
            uid: currentUser.uid,
            activityId: activity.id,
            file: media.newVoiceNote!,
          );
          voiceNoteDurationMs = media.newVoiceNoteDurationMs;
          voiceNoteWaveform = media.newWaveform;
          if (activity.voiceNoteUrl != null) {
            orphaned.add(activity.voiceNoteUrl!);
          }
        } else if (media.keptVoiceNoteUrl == null) {
          if (activity.voiceNoteUrl != null) {
            orphaned.add(activity.voiceNoteUrl!);
          }
          voiceNoteUrl = null;
          voiceNoteDurationMs = 0;
          voiceNoteWaveform = const [];
        }

        final uploaded = media.newPhotos.isEmpty
            ? const <String>[]
            : await _feedRepo.uploadReviewPhotos(
                uid: currentUser.uid,
                activityId: activity.id,
                files: media.newPhotos,
              );
        photoUrls = [...media.keptPhotoUrls, ...uploaded];
        orphaned.addAll(
          activity.photoUrls.where((u) => !media.keptPhotoUrls.contains(u)),
        );
      }

      // A spoken review with no stars and no text is still a review — the type
      // has to follow the media too, or removing the text off a voice-only
      // post would silently downgrade it to a bare "watched".
      final isNowReview = hasNewRating ||
          hasNewReview ||
          voiceNoteUrl != null ||
          photoUrls.isNotEmpty;

      final updatedActivity = activity.copyWith(
        activityType:
            isNowReview ? ActivityType.reviewed : ActivityType.watched,
        rating: hasNewRating ? newRating : null,
        reviewText: hasNewReview ? trimmedReviewText : null,
        voiceNoteUrl: voiceNoteUrl,
        voiceNoteDurationMs: voiceNoteDurationMs,
        voiceNoteWaveform: voiceNoteWaveform,
        photoUrls: photoUrls,
      );

      await _feedRepo.updateActivity(updatedActivity);

      // Only now that the row no longer points at them.
      if (orphaned.isNotEmpty) {
        try {
          await _feedRepo.deleteReviewMediaUrls(orphaned);
        } catch (_) {}
      }

      state = const AsyncValue.data(null);

      // Refresh relevant providers
      _ref.invalidate(homeFeedProvider);
      _ref.invalidate(currentUserProfileProvider);
      _ref.invalidate(userActivitiesProvider(currentUser.uid));
      _ref.invalidate(userFilmActivityProvider(activity.filmId));
      _ref.invalidate(userEpisodeActivitiesProvider(activity.filmId));
      _ref.invalidate(friendsFilmActivitiesProvider(activity.filmId));

      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

/// The media half of an edit: what to keep, what's new, what goes.
///
/// Only what changed is described. Deletions are implied by absence — an
/// existing URL that isn't in [keptPhotoUrls] is being removed — because the
/// editor works by removing things from a list, and asking it to also report
/// what it removed would just be the same information twice.
@immutable
class ReviewMediaEdit {
  const ReviewMediaEdit({
    this.keptVoiceNoteUrl,
    this.newVoiceNote,
    this.newVoiceNoteDurationMs = 0,
    this.newWaveform = const [],
    this.keptPhotoUrls = const [],
    this.newPhotos = const [],
  });

  /// The existing voice note, if it survived. Null with no [newVoiceNote]
  /// means the post is losing its audio.
  final String? keptVoiceNoteUrl;

  final File? newVoiceNote;
  final int newVoiceNoteDurationMs;
  final List<double> newWaveform;

  final List<String> keptPhotoUrls;
  final List<File> newPhotos;
}

/// Provider for creating activities
final createActivityProvider =
    StateNotifierProvider<CreateActivityNotifier, AsyncValue<void>>((ref) {
  final feedRepo = ref.watch(feedRepositoryProvider);
  final userRepo = ref.watch(userRepositoryProvider);
  return CreateActivityNotifier(feedRepo, userRepo, ref);
});

/// State notifier for like/unlike actions
class LikeNotifier extends StateNotifier<Set<String>> {
  final FeedRepository _feedRepo;
  final String? _userId;
  final Ref _ref;

  LikeNotifier(this._feedRepo, this._userId, this._ref) : super({});

  /// Toggle like on an activity.
  ///
  /// The recipient's notification is created (and retracted on unlike) by a
  /// trigger on `activity_likes`, so there is nothing to do here beyond the
  /// like itself.
  Future<void> toggleLike(String activityId, bool isCurrentlyLiked) async {
    if (_userId == null) return;

    // Optimistic update
    if (isCurrentlyLiked) {
      state = {...state}..remove(activityId);
      await _feedRepo.unlikeActivity(activityId: activityId, userId: _userId!);
    } else {
      state = {...state, activityId};
      await _feedRepo.likeActivity(activityId: activityId, userId: _userId!);
    }

    // Refresh the feed to reflect the change
    _ref.invalidate(homeFeedProvider);
  }
}

/// Provider for managing likes
final likeNotifierProvider =
    StateNotifierProvider<LikeNotifier, Set<String>>((ref) {
  final feedRepo = ref.watch(feedRepositoryProvider);
  final currentUser = ref.watch(currentUserProvider);
  return LikeNotifier(feedRepo, currentUser?.uid, ref);
});

/// Provider for comments on an activity
final activityCommentsProvider =
    FutureProvider.family<List<CommentModel>, String>((ref, activityId) async {
  final feedRepo = ref.watch(feedRepositoryProvider);
  return feedRepo.getComments(activityId: activityId);
});

/// Provider to sync a user's review count with actual reviews in database
/// Call this to fix any discrepancy between stored count and actual reviews
final syncReviewCountProvider =
    FutureProvider.family<int, String>((ref, userId) async {
  final feedRepo = ref.watch(feedRepositoryProvider);

  // review_count is trigger-maintained now, so this only reports the
  // authoritative count rather than writing it back.
  final actualCount = await feedRepo.countUserReviews(userId);

  // Invalidate the profile to refresh with new count
  ref.invalidate(currentUserProfileProvider);
  ref.invalidate(userProfileProvider(userId));

  return actualCount;
});

/// State notifier for managing reactions on activities
class ReactionNotifier extends StateNotifier<Map<String, String>> {
  final FeedRepository _feedRepo;
  final String? _userId;
  final Ref _ref;

  ReactionNotifier(this._feedRepo, this._userId, this._ref) : super({});

  /// Set a reaction on an activity (replaces any existing reaction).
  ///
  /// A trigger on `activity_reactions` raises the notification; swapping
  /// stickers updates that one row rather than stacking a new one.
  Future<void> setReaction(String activityId, String stickerId) async {
    if (_userId == null) return;

    // Optimistic update
    state = {...state, activityId: stickerId};

    try {
      await _feedRepo.setReaction(
        activityId: activityId,
        userId: _userId!,
        stickerId: stickerId,
      );

      // Refresh the feed to get updated data
      _ref.invalidate(homeFeedProvider);
    } catch (e) {
      // Revert on error
      final newState = {...state};
      newState.remove(activityId);
      state = newState;
    }
  }

  /// Remove reaction from an activity
  Future<void> removeReaction(String activityId) async {
    if (_userId == null) return;

    // Store old value for potential rollback
    final oldValue = state[activityId];

    // Optimistic update
    final newState = {...state};
    newState.remove(activityId);
    state = newState;

    try {
      await _feedRepo.removeReaction(
        activityId: activityId,
        userId: _userId!,
      );

      _ref.invalidate(homeFeedProvider);
    } catch (e) {
      // Revert on error
      if (oldValue != null) {
        state = {...state, activityId: oldValue};
      }
    }
  }

  /// Toggle reaction: if same sticker, remove; otherwise, set new sticker
  Future<void> toggleReaction(String activityId, String stickerId) async {
    final currentReaction = state[activityId];
    if (currentReaction == stickerId) {
      await removeReaction(activityId);
    } else {
      await setReaction(activityId, stickerId);
    }
  }
}

/// Provider for managing reactions
final reactionNotifierProvider =
    StateNotifierProvider<ReactionNotifier, Map<String, String>>((ref) {
  final feedRepo = ref.watch(feedRepositoryProvider);
  final currentUser = ref.watch(currentUserProvider);
  return ReactionNotifier(feedRepo, currentUser?.uid, ref);
});

/// State notifier for managing comments
class CommentNotifier extends StateNotifier<AsyncValue<void>> {
  final FeedRepository _feedRepo;
  final UserRepository _userRepo;
  final Ref _ref;

  CommentNotifier(this._feedRepo, this._userRepo, this._ref)
      : super(const AsyncValue.data(null));

  /// Add a comment to an activity.
  ///
  /// A trigger on `comments` notifies the activity's author, preview text
  /// included.
  Future<CommentModel?> addComment({
    required String activityId,
    required String content,
    String? parentId,
  }) async {
    final currentUser = _ref.read(currentUserProvider);
    if (currentUser == null) {
      state = AsyncValue.error('Not logged in', StackTrace.current);
      return null;
    }

    state = const AsyncValue.loading();

    try {
      // Get user profile for denormalized data
      final userProfile = await _userRepo.getUser(currentUser.uid);

      final comment = CommentModel(
        id: '',
        activityId: activityId,
        userId: currentUser.uid,
        username: userProfile?.username ?? 'Unknown',
        userPhotoUrl: userProfile?.photoUrl,
        content: content.trim(),
        parentId: parentId,
        createdAt: DateTime.now(),
      );

      final created = await _feedRepo.addComment(comment);
      state = const AsyncValue.data(null);

      // Refresh comments for this activity
      _ref.invalidate(activityCommentsProvider(activityId));
      _ref.invalidate(homeFeedProvider);

      return created;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Delete a comment
  Future<void> deleteComment({
    required String activityId,
    required String commentId,
  }) async {
    state = const AsyncValue.loading();

    try {
      await _feedRepo.deleteComment(
        activityId: activityId,
        commentId: commentId,
      );
      state = const AsyncValue.data(null);

      // Refresh comments
      _ref.invalidate(activityCommentsProvider(activityId));
      _ref.invalidate(homeFeedProvider);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

/// Provider for managing comments
final commentNotifierProvider =
    StateNotifierProvider<CommentNotifier, AsyncValue<void>>((ref) {
  final feedRepo = ref.watch(feedRepositoryProvider);
  final userRepo = ref.watch(userRepositoryProvider);
  return CommentNotifier(feedRepo, userRepo, ref);
});

/// Provider to sync current user's profile data to all their activities
/// Call this after updating profile photo or username to update old posts
/// Previously backfilled denormalized username/photo onto every activity.
///
/// Obsolete: `feed_activities` joins `profiles` at read time, so a profile
/// edit is reflected everywhere immediately and there is nothing to sync.
/// Kept as a no-op so existing call sites keep compiling.
@Deprecated('Activities join profiles live; no backfill is needed.')
final syncUserDataProvider = FutureProvider.family<int, void>((ref, _) async {
  return 0;
});
