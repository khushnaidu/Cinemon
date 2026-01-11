import 'dart:math';

/// Model for individual stickers used in reactions
class StickerModel {
  /// Unique identifier for the sticker
  final String id;

  /// Display name of the sticker
  final String name;

  /// Asset path to the sticker image
  final String assetPath;

  /// Emoji fallback when custom asset isn't available
  final String emoji;

  const StickerModel({
    required this.id,
    required this.name,
    required this.assetPath,
    required this.emoji,
  });
}

/// Predefined position/rotation for scattered sticker effect
class StickerPlacement {
  final double top;
  final double right;
  final double rotation; // in radians

  const StickerPlacement({
    required this.top,
    required this.right,
    required this.rotation,
  });
}

/// Static registry of all available stickers
class StickerRegistry {
  StickerRegistry._();

  static const List<StickerModel> allStickers = [
    StickerModel(
      id: 'tomato',
      name: 'Rotten',
      assetPath: 'assets/images/stickers/3.png',
      emoji: '\u{1F345}', // 🍅
    ),
    StickerModel(
      id: 'popcorn',
      name: 'Popcorn',
      assetPath: 'assets/images/stickers/4.png',
      emoji: '\u{1F37F}', // 🍿
    ),
    StickerModel(
      id: 'money',
      name: 'Box Office',
      assetPath: 'assets/images/stickers/5.png',
      emoji: '\u{1F4B0}', // 💰
    ),
    StickerModel(
      id: 'ghost',
      name: 'Spooky',
      assetPath: 'assets/images/stickers/6.png',
      emoji: '\u{1F47B}', // 👻
    ),
    StickerModel(
      id: 'oscar',
      name: 'Oscar',
      assetPath: 'assets/images/stickers/7.png',
      emoji: '\u{1F3C6}', // 🏆
    ),
    StickerModel(
      id: 'emmy',
      name: 'Emmy',
      assetPath: 'assets/images/stickers/8.png',
      emoji: '\u{1F3C6}', // 🏆
    ),
    StickerModel(
      id: 'creepy',
      name: 'Unsettling',
      assetPath: 'assets/images/stickers/9.png',
      emoji: '\u{1F628}', // 😨
    ),
    StickerModel(
      id: 'larry',
      name: 'Pretty Good',
      assetPath: 'assets/images/stickers/10.png',
      emoji: '\u{1F44D}', // 👍
    ),
  ];

  /// Find a sticker by ID
  static StickerModel? getStickerById(String id) {
    for (final sticker in allStickers) {
      if (sticker.id == id) return sticker;
    }
    return null;
  }

  /// Predefined scattered positions for stickers on cards
  /// These create an organic "stuck on" look with varying rotations
  static const List<StickerPlacement> scatteredPlacements = [
    StickerPlacement(top: -15, right: -10, rotation: 0.15),
    StickerPlacement(top: 25, right: -20, rotation: -0.12),
    StickerPlacement(top: -10, right: 35, rotation: 0.20),
    StickerPlacement(top: 50, right: -15, rotation: -0.08),
    StickerPlacement(top: 40, right: 40, rotation: 0.18),
    StickerPlacement(top: -20, right: 70, rotation: -0.15),
    StickerPlacement(top: 70, right: 25, rotation: 0.10),
    StickerPlacement(top: 85, right: -10, rotation: -0.20),
  ];

  /// Get a deterministic but varied placement based on sticker index
  static StickerPlacement getPlacement(int index) {
    return scatteredPlacements[index % scatteredPlacements.length];
  }

  /// Generate a seeded random placement for consistent display
  /// Places stickers at top-right corner, slightly spilling off card edge
  static StickerPlacement getSeededPlacement(String activityId, int index, {int totalStickers = 1}) {
    final seed = activityId.hashCode + index * 17;
    final random = Random(seed);

    // Top-right corner cluster - slight spill off the card edge
    // Positive right = on the card, negative = spilling off
    const minRight = -20.0;  // Max spill: only 20px off the card edge
    const maxRight = 40.0;   // Can go up to 40px into the card

    // Vertical spread in top area
    const minTop = -15.0;    // Slight spill above card
    const maxTop = 60.0;     // Spread down into top portion

    // Random position within the cluster zone
    final right = minRight + random.nextDouble() * (maxRight - minRight);
    final top = minTop + random.nextDouble() * (maxTop - minTop);

    // Ensure meaningful rotation - avoid too straight
    // Generate rotation between 0.15 and 0.35 radians, randomly positive or negative
    final rotationMagnitude = 0.15 + random.nextDouble() * 0.2; // 0.15 to 0.35
    final rotationSign = random.nextBool() ? 1.0 : -1.0;
    final rotation = rotationMagnitude * rotationSign;

    return StickerPlacement(
      top: top,
      right: right,
      rotation: rotation,
    );
  }
}
