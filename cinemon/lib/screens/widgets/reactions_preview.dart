import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/sticker_model.dart';

/// Shows a detailed breakdown of all reactions
/// Used when tapping on the stickers
class ReactionsBreakdownSheet extends StatelessWidget {
  final Map<String, String> reactions;

  const ReactionsBreakdownSheet({
    super.key,
    required this.reactions,
  });

  @override
  Widget build(BuildContext context) {
    // Group reactions by sticker
    final stickerCounts = <String, int>{};
    for (final stickerId in reactions.values) {
      stickerCounts[stickerId] = (stickerCounts[stickerId] ?? 0) + 1;
    }

    // Sort by count descending
    final sortedStickers = stickerCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.surface,
            AppColors.canvas,
          ],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Reactions',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          // Reaction breakdown
          ...sortedStickers.map((entry) {
            final sticker = StickerRegistry.getStickerById(entry.key);
            if (sticker == null) return const SizedBox.shrink();

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  // Sticker image
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: Image.asset(
                      sticker.assetPath,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stack) => Text(
                        sticker.emoji,
                        style: const TextStyle(fontSize: 32),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    sticker.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '${entry.value}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// Helper function to show reactions breakdown
Future<void> showReactionsBreakdown({
  required BuildContext context,
  required Map<String, String> reactions,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => ReactionsBreakdownSheet(reactions: reactions),
  );
}
