import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/activity_model.dart';
import '../../models/film_model.dart';
import '../../models/user_model.dart';
import '../../repositories/feed_repository.dart';
import '../../repositories/user_repository.dart';
import '../../services/badge_service.dart';
import '../auth/auth_provider.dart';
import '../friendship/friendship_provider.dart';

/// Provider for FeedRepository singleton
final feedRepositoryProvider = Provider<FeedRepository>((ref) {
  return FeedRepository();
});

/// Provider for UserRepository singleton
final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository();
});

/// Provider for BadgeService
final badgeServiceProvider = Provider<BadgeService>((ref) {
  return BadgeService(
    userRepo: ref.watch(userRepositoryProvider),
    feedRepo: ref.watch(feedRepositoryProvider),
  );
});

/// Provider for current user's profile data
final currentUserProfileProvider = FutureProvider<UserModel?>((ref) async {
  final authUser = ref.watch(currentUserProvider);
  if (authUser == null) return null;

  final userRepo = ref.watch(userRepositoryProvider);
  return userRepo.getUser(authUser.uid);
});

/// Provider for a specific user's profile
final userProfileProvider =
    FutureProvider.family<UserModel?, String>((ref, userId) async {
  final userRepo = ref.watch(userRepositoryProvider);
  return userRepo.getUser(userId);
});

/// Provider for the home feed activities (from friends + self)
final homeFeedProvider = FutureProvider<List<ActivityModel>>((ref) async {
  final currentUser = ref.watch(currentUserProvider);
  if (currentUser == null) {
    throw Exception('Not logged in');
  }

  try {
    final friendIds = await ref.watch(friendIdsProvider.future);

    // Always include current user's own posts, plus friends' posts
    final allUserIds = [currentUser.uid, ...friendIds];

    final feedRepo = ref.watch(feedRepositoryProvider);
    final activities = await feedRepo.getFeedActivities(userIds: allUserIds);
    return activities;
  } catch (e) {
    // Re-throw with more context for debugging
    throw Exception('Failed to load feed: $e');
  }
});

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

/// Provider to get friends' activities for a specific film
final friendsFilmActivitiesProvider =
    FutureProvider.family<List<ActivityModel>, int>((ref, filmId) async {
  final currentUser = ref.watch(currentUserProvider);
  if (currentUser == null) return [];

  final friendIds = await ref.watch(friendIdsProvider.future);
  if (friendIds.isEmpty) return [];

  final feedRepo = ref.watch(feedRepositoryProvider);
  final allActivities = await feedRepo.getFilmActivities(filmId: filmId);

  // Filter to only include friends' activities (exclude own)
  return allActivities
      .where((a) => friendIds.contains(a.userId) && a.userId != currentUser.uid)
      .toList();
});

/// State notifier for creating new activities
class CreateActivityNotifier extends StateNotifier<AsyncValue<void>> {
  final FeedRepository _feedRepo;
  final UserRepository _userRepo;
  final BadgeService _badgeService;
  final Ref _ref;

  /// Stores recently unlocked badges for UI notification
  List<String> lastUnlockedBadges = [];

  CreateActivityNotifier(this._feedRepo, this._userRepo, this._badgeService, this._ref)
      : super(const AsyncValue.data(null));

  /// Post a new "watched" activity (no review required)
  Future<ActivityModel?> postWatched({
    required FilmModel film,
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
        createdAt: DateTime.now(),
      );

      final created = await _feedRepo.createActivity(activity);
      state = const AsyncValue.data(null);

      // Refresh the feed and user's activities
      _ref.invalidate(homeFeedProvider);
      _ref.invalidate(userActivitiesProvider(currentUser.uid));

      return created;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Post a new review activity (with rating and optional text)
  Future<ActivityModel?> postReview({
    required FilmModel film,
    required double rating,
    String? reviewText,
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

      final activity = ActivityModel(
        id: '',
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
        rating: rating,
        reviewText: reviewText,
        createdAt: DateTime.now(),
      );

      final created = await _feedRepo.createActivity(activity);

      // review_count is maintained by the activities_review_count_trg trigger

      // Check for badge unlocks
      // Get first genre ID if available
      final genreId = film.genreIds.isNotEmpty ? film.genreIds.first : null;
      lastUnlockedBadges = await _badgeService.checkAndUnlockBadges(
        userId: currentUser.uid,
        genreId: genreId,
      );

      state = const AsyncValue.data(null);

      // Refresh the feed and profile to show updated review count
      _ref.invalidate(homeFeedProvider);
      _ref.invalidate(currentUserProfileProvider);
      _ref.invalidate(userActivitiesProvider(currentUser.uid));

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
  Future<void> deleteActivity(String activityId, {bool isReview = false, int? filmId}) async {
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

      state = const AsyncValue.data(null);

      // Refresh the feed, profile, and activities
      _ref.invalidate(homeFeedProvider);
      _ref.invalidate(currentUserProfileProvider);
      _ref.invalidate(userActivitiesProvider(currentUser.uid));
      if (filmId != null) {
        _ref.invalidate(userFilmActivityProvider(filmId));
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
  }) async {
    final currentUser = _ref.read(currentUserProvider);
    if (currentUser == null) {
      state = AsyncValue.error('Not logged in', StackTrace.current);
      return false;
    }

    // Verify ownership
    if (activity.userId != currentUser.uid) {
      state = AsyncValue.error('Cannot edit others\' activities', StackTrace.current);
      return false;
    }

    state = const AsyncValue.loading();

    try {
      final wasReview = activity.activityType == ActivityType.reviewed;
      final hasNewRating = newRating != null && newRating > 0;
      final trimmedReviewText = newReviewText?.trim();
      final hasNewReview = trimmedReviewText != null && trimmedReviewText.isNotEmpty;
      final isNowReview = hasNewRating || hasNewReview;

      // Determine new activity type
      final newActivityType = isNowReview ? ActivityType.reviewed : ActivityType.watched;

      // Update the activity
      final updatedActivity = activity.copyWith(
        activityType: newActivityType,
        rating: hasNewRating ? newRating : null,
        reviewText: hasNewReview ? trimmedReviewText : null,
      );

      await _feedRepo.updateActivity(updatedActivity);

      state = const AsyncValue.data(null);

      // Refresh relevant providers
      _ref.invalidate(homeFeedProvider);
      _ref.invalidate(currentUserProfileProvider);
      _ref.invalidate(userActivitiesProvider(currentUser.uid));
      _ref.invalidate(userFilmActivityProvider(activity.filmId));
      _ref.invalidate(friendsFilmActivitiesProvider(activity.filmId));

      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

/// Provider for creating activities
final createActivityProvider =
    StateNotifierProvider<CreateActivityNotifier, AsyncValue<void>>((ref) {
  final feedRepo = ref.watch(feedRepositoryProvider);
  final userRepo = ref.watch(userRepositoryProvider);
  final badgeService = ref.watch(badgeServiceProvider);
  return CreateActivityNotifier(feedRepo, userRepo, badgeService, ref);
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
