import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/api_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/explore_post_model.dart';
import '../../providers/explore/explore_provider.dart';
import '../widgets/comments_sheet.dart' show CommentAvatar;
import '../widgets/glass_panel.dart';
import '../widgets/liquid_glass.dart' show GlassLens;
import '../widgets/star_input.dart' show GlassStar;

// ─────────────────────────────────────────────────────────────
// Type per kind
// ─────────────────────────────────────────────────────────────
//
// Shared with the composer, so the text you type is already set the way the
// finished post will be. That's the whole "transform" — the kind picks a
// typographic voice, not a colour.

TextStyle exploreBodyStyle(ExploreKind kind, {bool expanded = false}) {
  return switch (kind) {
    ExploreKind.take => AppText.title.copyWith(
        fontSize: 25,
        height: 1.16,
        letterSpacing: -0.4,
        color: AppColors.ink,
      ),
    ExploreKind.discussion => AppText.headline.copyWith(
        fontSize: 19,
        height: 1.3,
        letterSpacing: -0.2,
        color: AppColors.ink,
      ),
    ExploreKind.critique => AppText.body.copyWith(
        fontSize: 15,
        height: 1.5,
        color: expanded
            ? AppColors.ink.withValues(alpha: 0.92)
            : AppColors.inkSecondary,
      ),
    ExploreKind.review => AppText.body.copyWith(
        fontSize: 15.5,
        height: 1.45,
        color: AppColors.ink.withValues(alpha: 0.92),
      ),
    ExploreKind.thought => AppText.body.copyWith(
        fontSize: 16.5,
        height: 1.42,
        color: AppColors.ink.withValues(alpha: 0.94),
      ),
  };
}

/// A critique's title.
TextStyle exploreHeadlineStyle({bool expanded = false}) =>
    AppText.title.copyWith(
        fontSize: expanded ? 24 : 23,
        height: 1.14,
        letterSpacing: -0.5,
        color: AppColors.ink);

// ─────────────────────────────────────────────────────────────
// The card
// ─────────────────────────────────────────────────────────────

/// One Explore post, laid out for its kind.
///
///   * Thought     — plain text, the default voice.
///   * Hot take    — set as a headline over the subject's blurred artwork,
///                   with an agree / disagree split instead of a like.
///   * Review      — built around the subject: its wide artwork, poster,
///                   title and stars, then the verdict.
///   * Critique    — an article: kicker, title, standfirst, read time.
///   * Discussion  — the question, large, and the thread as the call to act.
///
/// [expanded] is the thread view: nothing truncated, critiques at reading
/// size. Cards in the feed avoid BackdropFilter — dozens of live blurs in a
/// scrolling list is what makes one stutter — so their glass is a fill and a
/// hairline, and artwork is blurred once as an image.
class ExplorePostCard extends ConsumerStatefulWidget {
  const ExplorePostCard({
    super.key,
    required this.post,
    this.onOpen,
    this.onSubjectTap,
    this.onMenu,
    this.expanded = false,
  });

  final ExplorePost post;
  final VoidCallback? onOpen;
  final ValueChanged<ExploreSubject>? onSubjectTap;
  final VoidCallback? onMenu;
  final bool expanded;

  @override
  ConsumerState<ExplorePostCard> createState() => _ExplorePostCardState();
}

class _ExplorePostCardState extends ConsumerState<ExplorePostCard> {
  bool _revealed = false;

  ExplorePost get post => widget.post;
  bool get _veiled => post.hasSpoilers && !_revealed;

  Future<void> _vote(int value) async {
    HapticFeedback.selectionClick();
    final ok =
        await ref.read(exploreFeedProvider.notifier).vote(post.id, value);
    if (!ok && mounted) {
      showGlassToast(context, "Couldn't save that. Try again.",
          destructive: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final subject = post.subject;
    final ambient = post.kind == ExploreKind.take && subject != null;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (post.kind == ExploreKind.review && subject != null)
          _ReviewHero(
            subject: subject,
            rating: post.rating,
            onTap: widget.onSubjectTap == null
                ? null
                : () => widget.onSubjectTap!(subject),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpace.lg,
            post.kind == ExploreKind.review && subject != null
                ? AppSpace.md
                : AppSpace.lg,
            AppSpace.lg,
            AppSpace.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AuthorRow(post: post, onMenu: widget.onMenu),
              const SizedBox(height: AppSpace.md),
              ..._kindBody(context),
              if (subject != null && post.kind != ExploreKind.review) ...[
                const SizedBox(height: AppSpace.md),
                SubjectChip(
                  subject: subject,
                  onTap: widget.onSubjectTap == null
                      ? null
                      : () => widget.onSubjectTap!(subject),
                ),
              ],
              const SizedBox(height: AppSpace.md),
              if (post.kind.isVoted)
                _TakeVotes(post: post, onVote: _vote)
              else
                _Footer(
                  post: post,
                  onLike: () => _vote(1),
                  onComments: widget.onOpen,
                ),
            ],
          ),
        ),
      ],
    );

    return GestureDetector(
      onTap: widget.onOpen,
      behavior: HitTestBehavior.opaque,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.055),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.09),
              width: 0.6,
            ),
          ),
          child: ambient
              ? Stack(
                  children: [
                    Positioned.fill(child: _Ambient(subject: subject)),
                    content,
                  ],
                )
              : content,
        ),
      ),
    );
  }

  List<Widget> _kindBody(BuildContext context) {
    final expanded = widget.expanded;
    final bodyStyle = exploreBodyStyle(post.kind, expanded: expanded);

    Widget veil(Widget child) => _SpoilerVeil(
          veiled: _veiled,
          onReveal: () => setState(() => _revealed = true),
          child: child,
        );

    switch (post.kind) {
      case ExploreKind.take:
        return [
          const _Kicker(icon: CupertinoIcons.flame_fill, text: 'Hot take'),
          const SizedBox(height: AppSpace.sm),
          veil(Text(post.body, style: bodyStyle)),
        ];

      case ExploreKind.critique:
        return [
          _Kicker(
            icon: CupertinoIcons.book_fill,
            text: 'Critique  ·  ${post.readMinutes} min read',
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            post.headline ?? '',
            style: exploreHeadlineStyle(expanded: expanded),
            maxLines: expanded ? null : 3,
            overflow: expanded ? null : TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpace.sm),
          veil(Text(
            post.body,
            style: bodyStyle,
            maxLines: expanded ? null : 4,
            overflow: expanded ? null : TextOverflow.ellipsis,
          )),
          if (!expanded) ...[
            const SizedBox(height: AppSpace.sm),
            Row(
              children: [
                Text(
                  'Read critique',
                  style: AppText.label
                      .copyWith(fontSize: 14, color: AppColors.ink),
                ),
                const SizedBox(width: 3),
                const Icon(CupertinoIcons.chevron_right,
                    size: 13, color: AppColors.ink),
              ],
            ),
          ],
        ];

      case ExploreKind.discussion:
        return [
          const _Kicker(
              icon: CupertinoIcons.chat_bubble_2_fill, text: 'Discussion'),
          const SizedBox(height: AppSpace.sm),
          veil(Text(
            post.body,
            style: bodyStyle,
            maxLines: expanded ? null : 6,
            overflow: expanded ? null : TextOverflow.ellipsis,
          )),
        ];

      case ExploreKind.review:
        return [
          if (post.subject == null && post.rating != null) ...[
            GlassStarRow(rating: post.rating!),
            const SizedBox(height: AppSpace.sm),
          ],
          veil(Text(
            post.body,
            style: bodyStyle,
            maxLines: expanded ? null : 6,
            overflow: expanded ? null : TextOverflow.ellipsis,
          )),
        ];

      case ExploreKind.thought:
        return [
          veil(Text(
            post.body,
            style: bodyStyle,
            maxLines: expanded ? null : 8,
            overflow: expanded ? null : TextOverflow.ellipsis,
          )),
        ];
    }
  }
}

// ─────────────────────────────────────────────────────────────
// Pieces
// ─────────────────────────────────────────────────────────────

class _AuthorRow extends StatelessWidget {
  const _AuthorRow({required this.post, this.onMenu});

  final ExplorePost post;
  final VoidCallback? onMenu;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => context.push('/profile/${post.userId}'),
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: [
              CommentAvatar(
                  photoUrl: post.userPhotoUrl, username: post.username),
              const SizedBox(width: AppSpace.sm + 2),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 170),
                child: Text(
                  post.username,
                  style: AppText.label.copyWith(
                    fontSize: 14,
                    color: AppColors.ink,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpace.sm),
        Text(
          post.isEdited ? '${post.relativeTime}  ·  edited' : post.relativeTime,
          style: AppText.caption.copyWith(color: AppColors.inkTertiary),
        ),
        const Spacer(),
        if (post.kind == ExploreKind.thought || post.kind == ExploreKind.review)
          _KindMark(kind: post.kind),
        if (onMenu != null)
          GestureDetector(
            onTap: onMenu,
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding:
                  EdgeInsets.fromLTRB(AppSpace.md, AppSpace.xs, 0, AppSpace.xs),
              child: Icon(CupertinoIcons.ellipsis,
                  size: 18, color: AppColors.inkSecondary),
            ),
          ),
      ],
    );
  }
}

/// A quiet glyph + label for the kinds that don't carry a kicker.
class _KindMark extends StatelessWidget {
  const _KindMark({required this.kind});

  final ExploreKind kind;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(kind.icon, size: 12, color: AppColors.inkTertiary),
        const SizedBox(width: 4),
        Text(
          kind.label,
          style: AppText.footnote.copyWith(
            color: AppColors.inkTertiary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Small tracked label above the body: HOT TAKE, CRITIQUE · 4 MIN READ.
class _Kicker extends StatelessWidget {
  const _Kicker({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 12, color: AppColors.inkSecondary),
        const SizedBox(width: 5),
        Text(
          text.toUpperCase(),
          style: AppText.footnote.copyWith(
            color: AppColors.inkSecondary,
            letterSpacing: 1.3,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// Five glass stars and the number.
class GlassStarRow extends StatelessWidget {
  const GlassStarRow({super.key, required this.rating, this.size = 16});

  final double rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 5; i++)
          Padding(
            padding: const EdgeInsets.only(right: 2),
            child: GlassStar(fill: (rating - i).clamp(0.0, 1.0), size: size),
          ),
        const SizedBox(width: AppSpace.xs),
        Text(
          rating % 1 == 0
              ? rating.toStringAsFixed(0)
              : rating.toStringAsFixed(1),
          style: AppText.label.copyWith(
            fontSize: size - 2,
            color: AppColors.inkSecondary,
          ),
        ),
      ],
    );
  }
}

/// The title a post is about, as a tappable strip set into the card. Tapping
/// narrows Explore to that title.
class SubjectChip extends StatelessWidget {
  const SubjectChip({
    super.key,
    required this.subject,
    this.onTap,
    this.trailing,
  });

  final ExploreSubject subject;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final thumb =
        subject.isEpisode && (subject.episodeStillPath ?? '').isNotEmpty
            ? ApiConstants.getStillUrl(subject.episodeStillPath)
            : subject.posterUrl;
    final wide =
        subject.isEpisode && (subject.episodeStillPath ?? '').isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(AppSpace.sm),
        decoration: glassWellDecoration(radius: AppRadius.md + 2),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: wide ? 64 : 30,
                height: wide ? 36 : 45,
                child: thumb.isEmpty
                    ? ColoredBox(
                        color: Colors.white.withValues(alpha: 0.06),
                        child: Icon(
                          subject.isTv
                              ? CupertinoIcons.tv
                              : CupertinoIcons.film,
                          size: 14,
                          color: AppColors.inkTertiary,
                        ),
                      )
                    : CachedNetworkImage(imageUrl: thumb, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    subject.title,
                    style: AppText.label.copyWith(
                      fontSize: 14,
                      color: AppColors.ink,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subject.caption,
                    style: AppText.caption.copyWith(
                      fontSize: 12,
                      color: AppColors.inkSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            trailing ??
                (onTap == null
                    ? const SizedBox.shrink()
                    : const Padding(
                        padding: EdgeInsets.symmetric(horizontal: AppSpace.xs),
                        child: Icon(CupertinoIcons.chevron_right,
                            size: 13, color: AppColors.inkTertiary),
                      )),
          ],
        ),
      ),
    );
  }
}

/// A review leads with what it's about: the wide artwork, the poster set
/// over its foot, the title and the stars.
class _ReviewHero extends StatelessWidget {
  const _ReviewHero({required this.subject, this.rating, this.onTap});

  final ExploreSubject subject;
  final double? rating;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final wide = subject.wideUrl;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (wide.isNotEmpty)
              CachedNetworkImage(
                imageUrl: wide,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              ),
            // Settle the artwork into the card so the title can sit on it.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.0),
                    Colors.black.withValues(alpha: 0.15),
                    Colors.black.withValues(alpha: 0.82),
                  ],
                  stops: const [0, 0.45, 1],
                ),
              ),
            ),
            if (subject.isEpisode)
              Positioned(
                left: AppSpace.md,
                top: AppSpace.md,
                child: GlassTag(subject.episodeCode!),
              ),
            Positioned(
              left: AppSpace.lg,
              right: AppSpace.lg,
              bottom: AppSpace.md,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    width: 48,
                    height: 72,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18),
                        width: 0.6,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.45),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: subject.posterUrl.isEmpty
                          ? ColoredBox(
                              color: Colors.white.withValues(alpha: 0.08))
                          : CachedNetworkImage(
                              imageUrl: subject.posterUrl, fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(width: AppSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          subject.isEpisode
                              ? (subject.episodeTitle ?? subject.title)
                              : subject.title,
                          style: AppText.title.copyWith(
                            fontSize: 20,
                            height: 1.12,
                            color: AppColors.ink,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subject.isEpisode
                              ? '${subject.title}  ·  Season ${subject.seasonNumber}, Episode ${subject.episodeNumber}'
                              : subject.caption,
                          style: AppText.caption.copyWith(
                            fontSize: 12,
                            color: AppColors.ink.withValues(alpha: 0.7),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (rating != null) ...[
                          const SizedBox(height: 6),
                          GlassStarRow(rating: rating!, size: 15),
                        ],
                      ],
                    ),
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

/// The subject's artwork, blurred once as an image and dimmed, behind a hot
/// take. The take sits on the film's colour without a live backdrop blur.
class _Ambient extends StatelessWidget {
  const _Ambient({required this.subject});

  final ExploreSubject subject;

  @override
  Widget build(BuildContext context) {
    final path =
        subject.isEpisode && (subject.episodeStillPath ?? '').isNotEmpty
            ? ApiConstants.getStillUrl(subject.episodeStillPath)
            : ApiConstants.getPosterUrl(subject.posterPath,
                size: ApiConstants.posterSizeSmall);
    if (path.isEmpty) return const SizedBox.shrink();
    return Stack(
      fit: StackFit.expand,
      children: [
        ImageFiltered(
          imageFilter: ImageFilter.blur(
            sigmaX: 40,
            sigmaY: 40,
            tileMode: TileMode.mirror,
          ),
          child: Transform.scale(
            scale: 1.3,
            child: CachedNetworkImage(
              imageUrl: path,
              fit: BoxFit.cover,
              fadeInDuration: const Duration(milliseconds: 400),
              errorWidget: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        ),
        ColoredBox(color: Colors.black.withValues(alpha: 0.5)),
      ],
    );
  }
}

/// Blurs a spoiler until it's asked for.
class _SpoilerVeil extends StatelessWidget {
  const _SpoilerVeil({
    required this.veiled,
    required this.onReveal,
    required this.child,
  });

  final bool veiled;
  final VoidCallback onReveal;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!veiled) return child;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onReveal();
      },
      behavior: HitTestBehavior.opaque,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: ClipRect(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 9, sigmaY: 9),
                child: child,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.md, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.18),
                width: 0.6,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(CupertinoIcons.eye_slash,
                    size: 14, color: AppColors.ink),
                const SizedBox(width: 6),
                Text(
                  'Spoilers  ·  Tap to reveal',
                  style: AppText.label.copyWith(
                    fontSize: 13,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Like + comments, for every kind but hot takes.
class _Footer extends StatelessWidget {
  const _Footer({required this.post, this.onLike, this.onComments});

  final ExplorePost post;
  final VoidCallback? onLike;
  final VoidCallback? onComments;

  @override
  Widget build(BuildContext context) {
    final liked = post.myVote == 1;
    return Row(
      children: [
        if (onLike != null) ...[
          _FooterAction(
            icon: liked ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
            color: liked ? AppColors.destructive : AppColors.inkSecondary,
            count: post.agreeCount,
            onTap: onLike!,
          ),
          const SizedBox(width: AppSpace.lg),
        ],
        if (post.kind.allowsComments)
          _FooterAction(
            icon: post.kind == ExploreKind.discussion
                ? CupertinoIcons.chat_bubble_2
                : CupertinoIcons.chat_bubble,
            color: AppColors.inkSecondary,
            count: post.commentCount,
            label: post.kind == ExploreKind.discussion
                ? (post.commentCount == 1 ? 'reply' : 'replies')
                : null,
            onTap: onComments,
          ),
      ],
    );
  }
}

class _FooterAction extends StatelessWidget {
  const _FooterAction({
    required this.icon,
    required this.color,
    required this.count,
    this.label,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final int count;
  final String? label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (child, a) =>
                  ScaleTransition(scale: a, child: child),
              child: Icon(icon, key: ValueKey(icon), size: 19, color: color),
            ),
            if (count > 0 || label != null) ...[
              const SizedBox(width: 5),
              Text(
                label == null ? '$count' : '$count $label',
                style: AppText.caption.copyWith(
                  color: AppColors.inkSecondary,
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

/// Agree / disagree for a hot take, with the split once anyone has voted.
class _TakeVotes extends StatelessWidget {
  const _TakeVotes({required this.post, required this.onVote});

  final ExplorePost post;
  final ValueChanged<int> onVote;

  @override
  Widget build(BuildContext context) {
    final share = post.agreeShare;
    final voted = post.myVote != 0;
    // Hide the split until you've voted, so the crowd doesn't vote for you.
    final showSplit = share != null && voted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _VotePill(
                label: 'Agree',
                icon: CupertinoIcons.hand_thumbsup,
                activeIcon: CupertinoIcons.hand_thumbsup_fill,
                active: post.myVote == 1,
                percent: showSplit ? (share * 100).round() : null,
                onTap: () => onVote(1),
              ),
            ),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: _VotePill(
                label: 'Disagree',
                icon: CupertinoIcons.hand_thumbsdown,
                activeIcon: CupertinoIcons.hand_thumbsdown_fill,
                active: post.myVote == -1,
                percent: showSplit ? 100 - (share * 100).round() : null,
                onTap: () => onVote(-1),
              ),
            ),
          ],
        ),
        if (showSplit) ...[
          const SizedBox(height: AppSpace.sm),
          _SplitMeter(share: share),
          const SizedBox(height: 4),
          Text(
            '${post.totalVotes} ${post.totalVotes == 1 ? 'vote' : 'votes'}',
            style: AppText.footnote.copyWith(color: AppColors.inkTertiary),
          ),
        ],
      ],
    );
  }
}

class _VotePill extends StatelessWidget {
  const _VotePill({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.active,
    required this.onTap,
    this.percent,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final bool active;
  final int? percent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const height = 38.0;
    final radius = BorderRadius.circular(height / 2);
    return GlassPressable(
      onTap: onTap,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: radius,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
            width: 0.6,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: active ? 1 : 0,
              child: GlassLens(radius: radius),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(active ? activeIcon : icon,
                    size: 15,
                    color: active ? AppColors.ink : AppColors.inkSecondary),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: AppText.label.copyWith(
                    fontSize: 14,
                    color: active ? AppColors.ink : AppColors.inkSecondary,
                  ),
                ),
                if (percent != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    '$percent%',
                    style: AppText.label.copyWith(
                      fontSize: 13,
                      color: AppColors.inkTertiary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A hairline meter: agree on the left in white, disagree the remainder.
class _SplitMeter extends StatelessWidget {
  const _SplitMeter({required this.share});

  final double share;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        height: 3,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.5, end: share),
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
          builder: (_, v, __) => Row(
            children: [
              Expanded(
                flex: (v * 1000).round().clamp(1, 999),
                child: ColoredBox(color: AppColors.ink.withValues(alpha: 0.85)),
              ),
              const SizedBox(width: 2),
              Expanded(
                flex: ((1 - v) * 1000).round().clamp(1, 999),
                child: ColoredBox(color: Colors.white.withValues(alpha: 0.18)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
