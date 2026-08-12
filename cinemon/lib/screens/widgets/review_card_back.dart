import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/poster_palette.dart';
import '../../models/activity_model.dart';
import '../../models/sticker_model.dart';
import 'review_photo_stack.dart';
import 'voice_note_player.dart';

/// The reverse of a feed card: what the person actually said about the film.
///
/// Laid out as a journal entry rather than a form. The old back stacked
/// everything down the centre — title, year, stars, review, a full-width
/// button, a labelled toolbar — which is why it read as dead: centred text has
/// no edge to follow, and six centred blocks have no hierarchy between them.
/// Here one edge runs down the left and the eye follows it, the grade is the
/// only thing allowed to be large, and the chrome shrinks to hairlines and
/// counts.
///
/// The film's own colour does the rest. Everything tinted here — the grade,
/// the rule, the quote bar, the wash behind it all — comes from the poster on
/// the other side of the card, so the two faces belong to the same object and
/// no two films look alike.
class ReviewCardBack extends ConsumerWidget {
  const ReviewCardBack({
    super.key,
    required this.activity,
    required this.width,
    required this.height,
    required this.posterUrl,
    required this.onOpenFilm,
    required this.onReact,
    required this.onComment,
    required this.onLike,
    this.currentUserId,
    this.artifacts = const [],
  });

  final ActivityModel activity;
  final double width;
  final double height;

  /// Sampled for the tint, and shared with the ambience behind the card so the
  /// two agree.
  final String posterUrl;

  final VoidCallback onOpenFilm;
  final VoidCallback onReact;
  final VoidCallback onComment;
  final VoidCallback onLike;
  final String? currentUserId;

  /// Anything extra to hang on the media row, beyond the voice note and photos
  /// the activity already carries. Empty today; the row is built to take more.
  final List<Widget> artifacts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(posterPaletteProvider(posterUrl)).valueOrNull ??
        PosterPalette.neutral;
    final tint = palette.primary;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        color: AppColors.surface,
        border: Border.all(color: AppColors.separator, width: 0.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Stack(
          children: [
            // The film's colour, washed in from the top-left corner and pooling
            // out of the bottom-right. Faint enough to stay a surface rather
            // than become a colour, but it's the difference between a card and
            // a grey rectangle.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      tint.withValues(alpha: 0.16),
                      tint.withValues(alpha: 0),
                    ],
                    stops: const [0, 0.6],
                  ),
                ),
              ),
            ),
            Positioned(
              right: -70,
              bottom: -70,
              width: 200,
              height: 200,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      palette.secondary.withValues(alpha: 0.14),
                      palette.secondary.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Header(
                    activity: activity,
                    tint: tint,
                    onOpenFilm: onOpenFilm,
                  ),
                  const SizedBox(height: AppSpace.md),
                  _Rule(tint: tint),
                  const SizedBox(height: AppSpace.md),
                  Expanded(
                    child: activity.hasReview
                        ? _Review(text: activity.reviewText!, tint: tint)
                        : _NoReview(tint: tint),
                  ),
                  if (activity.hasArtifacts || artifacts.isNotEmpty) ...[
                    const SizedBox(height: AppSpace.md),
                    _MediaRow(
                      activity: activity,
                      tint: tint,
                      extra: artifacts,
                    ),
                  ],
                  const SizedBox(height: AppSpace.md),
                  _Tallies(
                    activity: activity,
                    currentUserId: currentUserId,
                    tint: tint,
                    onReact: onReact,
                    onComment: onComment,
                    onLike: onLike,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The voice note and the photo pile, sharing one line above the tallies.
///
/// The pile goes on the right and keeps its natural size while the voice note
/// takes whatever's left. That ordering is the whole layout: a spoken review
/// is the thing you're meant to press, so it gets the width, and the photos
/// stack into a corner rather than spreading across a card that has none to
/// spare.
class _MediaRow extends StatelessWidget {
  const _MediaRow({
    required this.activity,
    required this.tint,
    required this.extra,
  });

  final ActivityModel activity;
  final Color tint;
  final List<Widget> extra;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (activity.hasVoiceNote)
          Expanded(
            child: VoiceNotePlayer(
              url: activity.voiceNoteUrl!,
              durationMs: activity.voiceNoteDurationMs,
              waveform: activity.voiceNoteWaveform,
              tint: tint,
            ),
          )
        else
          const Spacer(),
        for (final widget in extra) ...[
          const SizedBox(width: AppSpace.sm),
          widget,
        ],
        if (activity.hasPhotos) ...[
          const SizedBox(width: AppSpace.sm),
          ReviewPhotoStack(urls: activity.photoUrls, tint: tint),
        ],
      ],
    );
  }
}

/// Grade, title, and where the film lives — one block, three sizes.
class _Header extends StatelessWidget {
  const _Header({
    required this.activity,
    required this.tint,
    required this.onOpenFilm,
  });

  final ActivityModel activity;
  final Color tint;
  final VoidCallback onOpenFilm;

  @override
  Widget build(BuildContext context) {
    final meta = [
      activity.filmYear,
      activity.mediaType.toUpperCase(),
    ].whereType<String>().join('  ·  ');

    return GestureDetector(
      // The whole block opens the film. This is what replaced the full-width
      // "View Film" button: a 44pt-tall primary action for a secondary
      // destination was the single biggest thing crowding the card, and the
      // title is a more obvious place to press than a button repeating it.
      onTap: onOpenFilm,
      behavior: HitTestBehavior.opaque,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (activity.hasRating) ...[
            _Grade(rating: activity.rating!, tint: tint),
            const SizedBox(width: AppSpace.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.filmTitle,
                  style: AppText.title.copyWith(
                    color: AppColors.ink,
                    fontSize: 19,
                    height: 1.15,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    meta,
                    style: AppText.footnote.copyWith(
                      color: AppColors.inkTertiary,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(left: AppSpace.sm, top: 2),
            child: Icon(
              CupertinoIcons.chevron_right,
              size: 15,
              color: AppColors.inkTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

/// The rating, as a number rather than five glyphs.
///
/// Stars are the one thing every film app draws the same way, and at this size
/// five of them are five near-identical shapes carrying one value between
/// them. A numeral says it in one mark, leaves room for the title beside it
/// instead of a row below it, and is the only place on the card where the
/// film's colour is allowed to be at full strength.
class _Grade extends StatelessWidget {
  const _Grade({required this.rating, required this.tint});

  final double rating;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final value =
        rating % 1 == 0 ? rating.toStringAsFixed(0) : rating.toStringAsFixed(1);

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: value,
            style: TextStyle(
              fontFamily: '.SF Pro Display',
              fontSize: 40,
              fontWeight: FontWeight.w700,
              letterSpacing: -2,
              height: 1,
              color: tint,
            ),
          ),
          TextSpan(
            // Sits on the numeral's baseline for free — spans in one Text
            // share it, which a Row of two Texts would not.
            text: ' /5',
            style: AppText.footnote.copyWith(
              color: AppColors.inkTertiary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// A hairline that starts in the film's colour and dissolves across the card.
/// A flat rule all the way over reads as a divider between two things; this
/// reads as an underline belonging to the block above it.
class _Rule extends StatelessWidget {
  const _Rule({required this.tint});

  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            tint.withValues(alpha: 0.55),
            tint.withValues(alpha: 0.04),
          ],
        ),
      ),
    );
  }
}

/// The review itself, against a pull-quote bar.
///
/// Left-aligned and ragged-right, which is the whole point: the bar gives the
/// text an edge to hang off, and an edge is what centred body copy can never
/// have. It also makes the block obviously scrollable when the review is long,
/// where centred text just looked cut off.
class _Review extends StatelessWidget {
  const _Review({required this.text, required this.tint});

  final String text;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: 2,
          decoration: BoxDecoration(
            color: tint.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(1),
          ),
        ),
        const SizedBox(width: AppSpace.md),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Text(
              text,
              style: AppText.body.copyWith(
                color: AppColors.ink,
                height: 1.55,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// What fills the well when someone logged a film without saying anything.
/// A stated absence, rather than the old greyed-out sentence that read like
/// something had failed to load.
class _NoReview extends StatelessWidget {
  const _NoReview({required this.tint});

  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            CupertinoIcons.film,
            size: 26,
            color: tint.withValues(alpha: 0.55),
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            'NO NOTES',
            style: AppText.footnote.copyWith(
              color: AppColors.inkTertiary,
              letterSpacing: 1.6,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// React, comment, like — as counts under a hairline.
///
/// The labels are gone. "React / Comment / Like" under three unmistakable
/// glyphs was three words of chrome on a card whose whole problem was that
/// there was no room left for content.
class _Tallies extends StatelessWidget {
  const _Tallies({
    required this.activity,
    required this.currentUserId,
    required this.tint,
    required this.onReact,
    required this.onComment,
    required this.onLike,
  });

  final ActivityModel activity;
  final String? currentUserId;
  final Color tint;
  final VoidCallback onReact;
  final VoidCallback onComment;
  final VoidCallback onLike;

  @override
  Widget build(BuildContext context) {
    final liked = currentUserId != null && activity.isLikedBy(currentUserId!);
    final reaction =
        currentUserId != null ? activity.getReactionFrom(currentUserId!) : null;
    final sticker =
        reaction != null ? StickerRegistry.getStickerById(reaction) : null;

    return Container(
      padding: const EdgeInsets.only(top: AppSpace.sm),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.separator, width: 0.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _Tally(
            icon: sticker == null ? CupertinoIcons.smiley : null,
            stickerAsset: sticker?.assetPath,
            count: activity.reactionCount,
            active: sticker != null,
            activeColor: tint,
            onTap: onReact,
          ),
          _Tally(
            icon: CupertinoIcons.bubble_left,
            count: activity.commentCount,
            onTap: onComment,
          ),
          _Tally(
            icon: liked ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
            count: activity.likeCount,
            active: liked,
            activeColor: AppColors.destructive,
            onTap: onLike,
          ),
        ],
      ),
    );
  }
}

class _Tally extends StatelessWidget {
  const _Tally({
    this.icon,
    this.stickerAsset,
    required this.count,
    required this.onTap,
    this.active = false,
    this.activeColor,
  });

  final IconData? icon;
  final String? stickerAsset;
  final int count;
  final VoidCallback onTap;
  final bool active;
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    final colour =
        active ? (activeColor ?? AppColors.ink) : AppColors.inkSecondary;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        // Horizontal only. The row is already at the bottom of a fixed-height
        // card, so padding the tap target vertically would eat the well above
        // it — the space either side is free.
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (stickerAsset != null)
              Image.asset(stickerAsset!, width: 20, height: 20)
            else
              Icon(icon, size: 19, color: colour),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Text(
                '$count',
                style: AppText.caption.copyWith(
                  color: colour,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
