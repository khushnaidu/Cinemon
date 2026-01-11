/// Badge types for categorization
enum BadgeType {
  reviews,  // Review count milestones
  genres,   // Genre-specific achievements
  special,  // Special achievements
}

/// Represents an achievement badge
class BadgeModel {
  final String id;
  final String name;
  final String description;
  final String emoji;
  final BadgeType type;
  final int? requiredCount; // For milestone badges

  const BadgeModel({
    required this.id,
    required this.name,
    required this.description,
    required this.emoji,
    required this.type,
    this.requiredCount,
  });
}

/// Static registry of all available badges
class BadgeRegistry {
  BadgeRegistry._();

  // Review milestone badges
  static const firstReview = BadgeModel(
    id: 'first_review',
    name: 'First Take',
    description: 'Posted your first review',
    emoji: '\u{1F3AC}', // 🎬
    type: BadgeType.reviews,
    requiredCount: 1,
  );

  static const reviewer10 = BadgeModel(
    id: 'reviewer_10',
    name: 'Film Buff',
    description: 'Posted 10 reviews',
    emoji: '\u{1F3A5}', // 🎥
    type: BadgeType.reviews,
    requiredCount: 10,
  );

  static const reviewer25 = BadgeModel(
    id: 'reviewer_25',
    name: 'Cinephile',
    description: 'Posted 25 reviews',
    emoji: '\u{1F37F}', // 🍿
    type: BadgeType.reviews,
    requiredCount: 25,
  );

  static const reviewer50 = BadgeModel(
    id: 'reviewer_50',
    name: 'Film Critic',
    description: 'Posted 50 reviews',
    emoji: '\u{1F4DD}', // 📝
    type: BadgeType.reviews,
    requiredCount: 50,
  );

  static const reviewer100 = BadgeModel(
    id: 'reviewer_100',
    name: 'Master Critic',
    description: 'Posted 100 reviews',
    emoji: '\u{1F3C6}', // 🏆
    type: BadgeType.reviews,
    requiredCount: 100,
  );

  // Genre badges
  static const horrorFan = BadgeModel(
    id: 'horror_fan',
    name: 'Horror Fan',
    description: 'Reviewed your first horror film',
    emoji: '\u{1F47B}', // 👻
    type: BadgeType.genres,
  );

  static const comedyLover = BadgeModel(
    id: 'comedy_lover',
    name: 'Comedy Lover',
    description: 'Reviewed 5 comedy films',
    emoji: '\u{1F602}', // 😂
    type: BadgeType.genres,
    requiredCount: 5,
  );

  static const actionHero = BadgeModel(
    id: 'action_hero',
    name: 'Action Hero',
    description: 'Reviewed 5 action films',
    emoji: '\u{1F4A5}', // 💥
    type: BadgeType.genres,
    requiredCount: 5,
  );

  static const romanticSoul = BadgeModel(
    id: 'romantic_soul',
    name: 'Romantic Soul',
    description: 'Reviewed 5 romance films',
    emoji: '\u{2764}\u{FE0F}', // ❤️
    type: BadgeType.genres,
    requiredCount: 5,
  );

  // Special badges
  static const nightOwl = BadgeModel(
    id: 'night_owl',
    name: 'Night Owl',
    description: 'Posted a review after midnight',
    emoji: '\u{1F989}', // 🦉
    type: BadgeType.special,
  );

  static const bingeWatcher = BadgeModel(
    id: 'binge_watcher',
    name: 'Binge Watcher',
    description: 'Posted 3 reviews in one day',
    emoji: '\u{1F4FA}', // 📺
    type: BadgeType.special,
    requiredCount: 3,
  );

  static const earlyAdopter = BadgeModel(
    id: 'early_adopter',
    name: 'Early Adopter',
    description: 'Joined during the beta',
    emoji: '\u{2B50}', // ⭐
    type: BadgeType.special,
  );

  /// All available badges
  static const List<BadgeModel> allBadges = [
    // Review milestones
    firstReview,
    reviewer10,
    reviewer25,
    reviewer50,
    reviewer100,
    // Genre badges
    horrorFan,
    comedyLover,
    actionHero,
    romanticSoul,
    // Special badges
    nightOwl,
    bingeWatcher,
    earlyAdopter,
  ];

  /// Get badge by ID
  static BadgeModel? getBadgeById(String id) {
    for (final badge in allBadges) {
      if (badge.id == id) return badge;
    }
    return null;
  }

  /// Get all review milestone badges
  static List<BadgeModel> get reviewBadges =>
      allBadges.where((b) => b.type == BadgeType.reviews).toList();

  /// Get all genre badges
  static List<BadgeModel> get genreBadges =>
      allBadges.where((b) => b.type == BadgeType.genres).toList();

  /// Get all special badges
  static List<BadgeModel> get specialBadges =>
      allBadges.where((b) => b.type == BadgeType.special).toList();
}
