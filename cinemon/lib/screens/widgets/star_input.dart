import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';

/// Five stars, each half of one settable independently.
///
/// Tap the left half of a star for a half, the right for a full. Tapping the
/// value already held clears it, which is the only way back to no rating.
/// Shared by the new-post panel and the editor so the two never drift.
class StarInput extends StatelessWidget {
  const StarInput({
    super.key,
    required this.rating,
    required this.onChanged,
    this.size = 36,
  });

  final double rating;
  final ValueChanged<double> onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < 5; i++)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) {
              final full = i + 1.0;
              final half = i + 0.5;
              final value = details.localPosition.dx < size / 2 ? half : full;
              HapticFeedback.selectionClick();
              onChanged(rating == value ? 0 : value);
            },
            child: Padding(
              padding: const EdgeInsets.only(right: AppSpace.xs),
              child: AnimatedScale(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutBack,
                scale: rating >= i + 0.5 ? 1.0 : 0.92,
                child:
                    GlassStar(fill: (rating - i).clamp(0.0, 1.0), size: size),
              ),
            ),
          ),
        const Spacer(),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: rating > 0
              ? Text(
                  rating % 1 == 0
                      ? rating.toStringAsFixed(0)
                      : rating.toStringAsFixed(1),
                  key: ValueKey(rating),
                  style: AppText.title.copyWith(color: AppColors.ink),
                )
              : Text(
                  'Tap to rate',
                  key: const ValueKey('hint'),
                  style: AppText.caption.copyWith(color: AppColors.inkTertiary),
                ),
        ),
      ],
    );
  }
}

/// A star the way the rest of the chrome is made: a translucent gold tint
/// with a light edge, not a solid yellow glyph. [fill] is 0, 0.5 or 1.
class GlassStar extends StatelessWidget {
  const GlassStar({super.key, required this.fill, this.size = 18});

  final double fill;
  final double size;

  @override
  Widget build(BuildContext context) {
    final lit = fill >= 0.5;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (lit)
            Icon(
              fill >= 1
                  ? CupertinoIcons.star_fill
                  : CupertinoIcons.star_lefthalf_fill,
              size: size,
              color: AppColors.gold.withValues(alpha: 0.42),
            ),
          Icon(
            CupertinoIcons.star,
            size: size,
            color: lit
                ? AppColors.gold.withValues(alpha: 0.85)
                : AppColors.inkTertiary,
          ),
        ],
      ),
    );
  }
}
