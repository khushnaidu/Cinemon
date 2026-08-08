import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/sticker_model.dart';
import '../../providers/feed/feed_provider.dart';

/// Bottom sheet for selecting a sticker reaction
class StickerPickerSheet extends ConsumerWidget {
  final String activityId;
  final String? currentStickerId;
  final String? activityOwnerId;
  final String? filmTitle;
  final String? filmPosterPath;

  const StickerPickerSheet({
    super.key,
    required this.activityId,
    this.currentStickerId,
    this.activityOwnerId,
    this.filmTitle,
    this.filmPosterPath,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.only(bottom: 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.fromARGB(255, 30, 30, 50),
            Color.fromARGB(255, 15, 15, 30),
          ],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text(
                  'Add a sticker',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (currentStickerId != null)
                  TextButton(
                    onPressed: () async {
                      await ref
                          .read(reactionNotifierProvider.notifier)
                          .removeReaction(activityId);
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Text(
                      'Remove',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
              ],
            ),
          ),

          // Sticker grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.85,
              ),
              itemCount: StickerRegistry.allStickers.length,
              itemBuilder: (context, index) {
                final sticker = StickerRegistry.allStickers[index];
                final isSelected = currentStickerId == sticker.id;

                return _StickerItem(
                  sticker: sticker,
                  isSelected: isSelected,
                  onTap: () async {
                    if (isSelected) {
                      await ref
                          .read(reactionNotifierProvider.notifier)
                          .removeReaction(activityId);
                    } else {
                      await ref
                          .read(reactionNotifierProvider.notifier)
                          .setReaction(activityId, sticker.id);
                    }
                    if (context.mounted) Navigator.pop(context);
                  },
                );
              },
            ),
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _StickerItem extends StatelessWidget {
  final StickerModel sticker;
  final bool isSelected;
  final VoidCallback onTap;

  const _StickerItem({
    required this.sticker,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withOpacity(0.15)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: Colors.white.withOpacity(0.4), width: 2)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Sticker image
            SizedBox(
              width: 48,
              height: 48,
              child: Image.asset(
                sticker.assetPath,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stack) => Text(
                  sticker.emoji,
                  style: const TextStyle(fontSize: 36),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              sticker.name,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[400],
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper function to show the sticker picker
Future<void> showStickerPicker({
  required BuildContext context,
  required String activityId,
  String? currentStickerId,
  String? activityOwnerId,
  String? filmTitle,
  String? filmPosterPath,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => StickerPickerSheet(
      activityId: activityId,
      currentStickerId: currentStickerId,
      activityOwnerId: activityOwnerId,
      filmTitle: filmTitle,
      filmPosterPath: filmPosterPath,
    ),
  );
}
