import '../models/badge_model.dart';
import '../models/user_model.dart';
import '../repositories/user_repository.dart';
import '../repositories/feed_repository.dart';

/// Service for checking and unlocking badges based on user activity
class BadgeService {
  final UserRepository _userRepo;
  final FeedRepository _feedRepo;

  BadgeService({
    required UserRepository userRepo,
    required FeedRepository feedRepo,
  })  : _userRepo = userRepo,
        _feedRepo = feedRepo;

  /// Check and unlock all applicable badges after posting a review
  /// Returns list of newly unlocked badge IDs
  Future<List<String>> checkAndUnlockBadges({
    required String userId,
    required int? genreId,
  }) async {
    final user = await _userRepo.getUser(userId);
    if (user == null) return [];

    final unlockedBadges = <String>[];

    // Check review milestone badges
    final reviewMilestones = await _checkReviewMilestones(user);
    unlockedBadges.addAll(reviewMilestones);

    // Check time-based badges (night owl)
    final timeBadges = _checkTimeBadges(user);
    unlockedBadges.addAll(timeBadges);

    // Check binge watcher badge
    final bingeBadges = await _checkBingeWatcher(userId, user);
    unlockedBadges.addAll(bingeBadges);

    // Check genre badges if genreId provided
    if (genreId != null) {
      final genreBadges = await _checkGenreBadges(userId, genreId, user);
      unlockedBadges.addAll(genreBadges);
    }

    // Unlock all new badges
    for (final badgeId in unlockedBadges) {
      await _userRepo.unlockBadge(userId, badgeId);
    }

    return unlockedBadges;
  }

  /// Check review count milestones
  Future<List<String>> _checkReviewMilestones(UserModel user) async {
    final unlocked = <String>[];
    final reviewCount = user.reviewCount;
    final earnedBadges = user.badgeIds;

    // First review
    if (reviewCount >= 1 && !earnedBadges.contains('first_review')) {
      unlocked.add('first_review');
    }

    // 10 reviews
    if (reviewCount >= 10 && !earnedBadges.contains('reviewer_10')) {
      unlocked.add('reviewer_10');
    }

    // 25 reviews
    if (reviewCount >= 25 && !earnedBadges.contains('reviewer_25')) {
      unlocked.add('reviewer_25');
    }

    // 50 reviews
    if (reviewCount >= 50 && !earnedBadges.contains('reviewer_50')) {
      unlocked.add('reviewer_50');
    }

    // 100 reviews
    if (reviewCount >= 100 && !earnedBadges.contains('reviewer_100')) {
      unlocked.add('reviewer_100');
    }

    return unlocked;
  }

  /// Check time-based badges (night owl)
  List<String> _checkTimeBadges(UserModel user) {
    final unlocked = <String>[];
    final now = DateTime.now();
    final hour = now.hour;

    // Night owl: posting after midnight (0:00 - 4:00)
    if (hour >= 0 && hour < 4 && !user.badgeIds.contains('night_owl')) {
      unlocked.add('night_owl');
    }

    return unlocked;
  }

  /// Check binge watcher badge (3+ reviews in one day)
  Future<List<String>> _checkBingeWatcher(String userId, UserModel user) async {
    if (user.badgeIds.contains('binge_watcher')) {
      return [];
    }

    // Get today's activities
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);

    final activities = await _feedRepo.getUserActivities(userId: userId, limit: 10);

    // Count reviews posted today
    final todayReviews = activities.where((a) {
      return a.activityType.name == 'reviewed' &&
          a.createdAt.isAfter(startOfDay);
    }).length;

    if (todayReviews >= 3) {
      return ['binge_watcher'];
    }

    return [];
  }

  /// Check genre-specific badges
  Future<List<String>> _checkGenreBadges(
    String userId,
    int genreId,
    UserModel user,
  ) async {
    final unlocked = <String>[];

    // Map TMDB genre IDs to badge IDs
    // Horror: 27
    // Comedy: 35
    // Action: 28
    // Romance: 10749

    // Horror fan badge (first horror review)
    if (genreId == 27 && !user.badgeIds.contains('horror_fan')) {
      unlocked.add('horror_fan');
    }

    // For other genres, we'd need to count reviews per genre
    // This would require storing genre info with activities
    // For now, we'll skip the count-based genre badges

    return unlocked;
  }

  /// Check for early adopter badge (call during signup if applicable)
  Future<bool> checkEarlyAdopter(String userId) async {
    final user = await _userRepo.getUser(userId);
    if (user == null || user.badgeIds.contains('early_adopter')) {
      return false;
    }

    // Define beta period (you can adjust this date)
    final betaEndDate = DateTime(2025, 12, 31);

    if (user.createdAt.isBefore(betaEndDate)) {
      await _userRepo.unlockBadge(userId, 'early_adopter');
      return true;
    }

    return false;
  }

  /// Get badge notification message
  static String getBadgeNotification(String badgeId) {
    final badge = BadgeRegistry.getBadgeById(badgeId);
    if (badge == null) return 'Badge unlocked!';

    return '${badge.emoji} ${badge.name} unlocked!';
  }
}
