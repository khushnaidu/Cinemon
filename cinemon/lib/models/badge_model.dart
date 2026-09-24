/// Badge types for categorization
enum BadgeType {
  reviews, // Review count milestones
  genres, // Genre-specific achievements
  lists, // Watchlist and playlists
  special, // Special achievements
}

/// Represents an achievement badge
class BadgeModel {
  final String id;
  final String name;
  final String description;
  final String emoji;
  final String? imagePath; // Path to badge image asset
  final BadgeType type;
  final int? requiredCount; // For milestone badges

  /// Which count in `my_badge_progress` moves toward [requiredCount], and
  /// what it counts: "12 / 25 reviews". Null for yes-or-no badges.
  final String? progressKey;
  final String? progressNoun;

  const BadgeModel({
    required this.id,
    required this.name,
    required this.description,
    required this.emoji,
    this.imagePath,
    required this.type,
    this.requiredCount,
    this.progressKey,
    this.progressNoun,
  });

  /// "12 / 25 reviews", or null when this badge has no count to show.
  String? progressLabel(Map<String, int> progress) {
    final key = progressKey;
    final target = requiredCount;
    if (key == null || target == null || target <= 1) return null;
    final have = (progress[key] ?? 0).clamp(0, target);
    return '$have / $target ${progressNoun ?? ''}'.trimRight();
  }
}

/// A badge someone has, and when they got it.
class EarnedBadge {
  const EarnedBadge({required this.id, required this.earnedAt});

  factory EarnedBadge.fromRow(Map<String, dynamic> row) => EarnedBadge(
        id: row['badge_id'] as String,
        earnedAt: DateTime.parse(row['earned_at'] as String).toLocal(),
      );

  final String id;
  final DateTime earnedAt;
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
    imagePath: 'assets/badges/22.png',
    type: BadgeType.reviews,
    requiredCount: 1,
  );

  static const reviewer10 = BadgeModel(
    id: 'reviewer_10',
    name: 'Film Buff',
    description: 'Posted 10 reviews',
    emoji: '\u{1F3A5}', // 🎥
    imagePath: 'assets/badges/24.png',
    type: BadgeType.reviews,
    requiredCount: 10,
    progressKey: 'reviews',
    progressNoun: 'reviews',
  );

  static const reviewer25 = BadgeModel(
    id: 'reviewer_25',
    name: 'Cinephile',
    description: 'Posted 25 reviews',
    emoji: '\u{1F37F}', // 🍿
    imagePath: 'assets/badges/23.png',
    type: BadgeType.reviews,
    requiredCount: 25,
    progressKey: 'reviews',
    progressNoun: 'reviews',
  );

  static const reviewer50 = BadgeModel(
    id: 'reviewer_50',
    name: 'Film Critic',
    description: 'Posted 50 reviews',
    emoji: '\u{1F4DD}', // 📝
    imagePath: 'assets/badges/25.png',
    type: BadgeType.reviews,
    requiredCount: 50,
    progressKey: 'reviews',
    progressNoun: 'reviews',
  );

  static const reviewer100 = BadgeModel(
    id: 'reviewer_100',
    name: 'Master Critic',
    description: 'Posted 100 reviews',
    emoji: '\u{1F3C6}', // 🏆
    // No image yet
    type: BadgeType.reviews,
    requiredCount: 100,
    progressKey: 'reviews',
    progressNoun: 'reviews',
  );

  // Genre badges
  static const horrorFan = BadgeModel(
    id: 'horror_fan',
    name: 'Horror Fan',
    description: 'Reviewed your first horror film',
    emoji: '\u{1F47B}', // 👻
    imagePath: 'assets/badges/28.png',
    type: BadgeType.genres,
  );

  static const comedyLover = BadgeModel(
    id: 'comedy_lover',
    name: 'Comedy Lover',
    description: 'Reviewed 5 comedy films',
    emoji: '\u{1F602}', // 😂
    imagePath: 'assets/badges/29.png',
    type: BadgeType.genres,
    requiredCount: 5,
    progressKey: 'comedy',
    progressNoun: 'comedies',
  );

  static const actionHero = BadgeModel(
    id: 'action_hero',
    name: 'Action Hero',
    description: 'Reviewed 5 action films',
    emoji: '\u{1F4A5}', // 💥
    imagePath: 'assets/badges/27.png',
    type: BadgeType.genres,
    requiredCount: 5,
    progressKey: 'action',
    progressNoun: 'action films',
  );

  static const romanticSoul = BadgeModel(
    id: 'romantic_soul',
    name: 'Romantic Soul',
    description: 'Reviewed 5 romance films',
    emoji: '\u{2764}\u{FE0F}', // ❤️
    imagePath: 'assets/badges/26.png',
    type: BadgeType.genres,
    requiredCount: 5,
    progressKey: 'romance',
    progressNoun: 'romances',
  );

  // List badges
  static const curator = BadgeModel(
    id: 'curator',
    name: 'Curator',
    description: 'Made your first public playlist',
    emoji: '\u{1F5C2}\u{FE0F}', // 🗂️
    type: BadgeType.lists,
  );

  static const tastemaker = BadgeModel(
    id: 'tastemaker',
    name: 'Tastemaker',
    description: '10 people saved one of your playlists',
    emoji: '\u{2728}', // ✨
    type: BadgeType.lists,
    requiredCount: 10,
    progressKey: 'top_saves',
    progressNoun: 'saves',
  );

  static const cleanSlate = BadgeModel(
    id: 'clean_slate',
    name: 'Clean Slate',
    description: 'Struck 10 titles off your watchlist',
    emoji: '\u{2705}', // ✅
    type: BadgeType.lists,
    requiredCount: 10,
    progressKey: 'strikes',
    progressNoun: 'struck off',
  );

  // Special badges
  static const nightOwl = BadgeModel(
    id: 'night_owl',
    name: 'Night Owl',
    description: 'Posted a review after midnight',
    emoji: '\u{1F989}', // 🦉
    imagePath: 'assets/badges/20.png',
    type: BadgeType.special,
  );

  static const bingeWatcher = BadgeModel(
    id: 'binge_watcher',
    name: 'Binge Watcher',
    description: 'Posted 3 reviews in one day',
    emoji: '\u{1F4FA}', // 📺
    imagePath: 'assets/badges/21.png',
    type: BadgeType.special,
    requiredCount: 3,
  );

  static const earlyAdopter = BadgeModel(
    id: 'early_adopter',
    name: 'Early Adopter',
    description: 'Joined before 35mm launched',
    emoji: '\u{2B50}', // ⭐
    // No image yet
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
    // List badges
    curator,
    tastemaker,
    cleanSlate,
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
