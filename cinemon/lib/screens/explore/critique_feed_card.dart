import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/api_constants.dart';
import '../../models/explore_post_model.dart';
import '../../share/cards/critique_cards.dart'
    show critiqueHeadlineSpans, critiqueStandfirst;
import '../../share/story_canvas.dart' show StoryGrain;
import '../widgets/comments_sheet.dart' show CommentAvatar;
import '../widgets/verified_mark.dart';
import 'critique_colors.dart';
import 'critique_reader.dart' show critiqueMonoStyle;

/// A critique in a feed, as a magazine cover: the share card C1 at card
/// size. The film's still across the top, the headline over its foot, the
/// opening sentence as a standfirst, then the byline. Printed on the film's
/// colours, like the article it opens.
///
/// No BackdropFilter, like every feed card; the still's grading is plain
/// gradients.
class CritiqueFeedCard extends StatelessWidget {
  const CritiqueFeedCard({
    super.key,
    required this.post,
    this.onOpen,
    this.onMenu,
    this.onLike,
  });

  final ExplorePost post;
  final VoidCallback? onOpen;
  final VoidCallback? onMenu;
  final VoidCallback? onLike;

  String get _still {
    final s = post.subject;
    if (s == null) return '';
    if (s.isEpisode && (s.episodeStillPath ?? '').isNotEmpty) {
      return ApiConstants.getStillUrl(s.episodeStillPath,
          size: ApiConstants.stillSizeLarge);
    }
    final wide = ApiConstants.getBackdropUrl(s.backdropPath, size: '/w780');
    if (wide.isNotEmpty) return wide;
    return ApiConstants.getPosterUrl(s.posterPath, size: '/w500');
  }

  @override
  Widget build(BuildContext context) {
    return CritiqueColorScope(
      subject: post.subject,
      seed: post.id,
      builder: _card,
    );
  }

  Widget _card(BuildContext context) {
    final c = CritiqueColors.of(context);
    final still = _still;
    final headline = post.headline ?? '';
    final n = headline.characters.length;
    final size = n <= 50
        ? 34.0
        : n <= 90
            ? 29.0
            : 25.0;
    final liked = post.myVote == 1;

    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final stillHeight = still.isEmpty ? 0.0 : width * 0.72;

      return GestureDetector(
        onTap: onOpen,
        behavior: HitTestBehavior.opaque,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: c.ground,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: c.accent.withValues(alpha: 0.16),
                width: 0.6,
              ),
            ),
            child: Stack(
              children: [
                if (still.isNotEmpty) ...[
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: stillHeight,
                    child: CachedNetworkImage(
                      imageUrl: still,
                      fit: BoxFit.cover,
                      fadeInDuration: const Duration(milliseconds: 400),
                      errorWidget: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                  Positioned(
                    top: stillHeight * 0.25,
                    left: 0,
                    right: 0,
                    height: stillHeight * 0.75 + 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            c.ground.withValues(alpha: 0),
                            c.ground.withValues(alpha: 0.75),
                            c.ground,
                          ],
                          stops: const [0, 0.6, 1],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: stillHeight,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(-0.7, 1),
                          radius: 1.1,
                          colors: [
                            c.glow.withValues(alpha: 0.7),
                            c.glow.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Keeps the kicker legible on a bright still.
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 70,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.45),
                            Colors.black.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ] else
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(-0.8, -1),
                          radius: 1.3,
                          colors: [c.glow, c.ground],
                        ),
                      ),
                    ),
                  ),
                const Positioned.fill(child: StoryGrain(opacity: 0.05)),
                Positioned(
                  top: 16,
                  left: 20,
                  right: 8,
                  child: Row(
                    children: [
                      Text('CRITIQUE',
                          style: critiqueMonoStyle(10.5, alpha: 1)
                              .copyWith(color: c.accent)),
                      const Spacer(),
                      Text('${post.readMinutes} MIN READ',
                          style: critiqueMonoStyle(10.5, alpha: 0.85)),
                      if (onMenu != null)
                        GestureDetector(
                          onTap: onMenu,
                          behavior: HitTestBehavior.opaque,
                          child: const Padding(
                            padding: EdgeInsets.fromLTRB(14, 4, 12, 4),
                            child: Icon(CupertinoIcons.ellipsis,
                                size: 18, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    still.isEmpty ? 64 : stillHeight - 64,
                    20,
                    14,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: critiqueHeadlineSpans(
                              headline, post.subject?.title,
                              accent: c.accent),
                        ),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'InstrumentSerif',
                          fontSize: size,
                          height: 1.0,
                          letterSpacing: -size * 0.01,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        post.hasSpoilers
                            ? 'Contains spoilers. Open it to read.'
                            : critiqueStandfirst(post.body),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'InstrumentSerif',
                          fontStyle: FontStyle.italic,
                          fontSize: 17,
                          height: 1.28,
                          color: Colors.white.withValues(alpha: 0.72),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.only(top: 10),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: c.accent.withValues(alpha: 0.25),
                              width: 0.6,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Flexible(
                              child: GestureDetector(
                                onTap: () =>
                                    context.push('/profile/${post.userId}'),
                                behavior: HitTestBehavior.opaque,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CommentAvatar(
                                      photoUrl: post.userPhotoUrl,
                                      username: post.username,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        'BY @${post.username.toUpperCase()}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: critiqueMonoStyle(10.5,
                                            alpha: 0.85),
                                      ),
                                    ),
                                    VerifiedMark(
                                        userId: post.userId, size: 11, gap: 4),
                                  ],
                                ),
                              ),
                            ),
                            Text(
                              '  ·  ${post.relativeTime.toUpperCase()}'
                              '${post.isEdited ? '  ·  EDITED' : ''}',
                              style: critiqueMonoStyle(10.5, alpha: 0.45),
                            ),
                            const Spacer(),
                            if (onLike != null)
                              GestureDetector(
                                onTap: onLike,
                                behavior: HitTestBehavior.opaque,
                                child: Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(12, 4, 0, 4),
                                  child: Row(
                                    children: [
                                      Icon(
                                        liked
                                            ? CupertinoIcons.heart_fill
                                            : CupertinoIcons.heart,
                                        size: 18,
                                        color: liked
                                            ? c.accent
                                            : Colors.white
                                                .withValues(alpha: 0.7),
                                      ),
                                      if (post.agreeCount > 0) ...[
                                        const SizedBox(width: 5),
                                        Text('${post.agreeCount}',
                                            style: critiqueMonoStyle(11,
                                                alpha: 0.7)),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}
