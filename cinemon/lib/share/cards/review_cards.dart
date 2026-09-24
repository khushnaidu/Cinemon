import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/api_constants.dart';
import '../../models/film_model.dart' show MediaType;
import '../../providers/movie/movie_provider.dart';
import '../share_subject.dart';
import '../story_canvas.dart';

/// "2024 · Denis Villeneuve": the year, then who made it once the film page
/// data is in (usually cached from the film page already).
String reviewCredit(WidgetRef ref, ReviewShare review) {
  final extras = ref
      .watch(filmExtrasProvider((
        id: review.filmId,
        mediaType: review.mediaType == 'tv' ? MediaType.tv : MediaType.movie,
      )))
      .valueOrNull;
  final names = extras?.directors.map((d) => d.name).take(2).join(' & ');
  return [
    if ((review.year ?? '').isNotEmpty) review.year,
    if ((names ?? '').isNotEmpty) names,
  ].join(' · ');
}

/// R2: the poster as the hero, glowing in its own colour, then the stars
/// and one line of the review. Spotify's approach.
class PosterVerdictCard extends ConsumerWidget {
  const PosterVerdictCard(
      {super.key, required this.review, required this.look});

  final ReviewShare review;
  final ShareLook look;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final glow = look.tint ?? look.palette.primary;
    final credit = reviewCredit(ref, review);
    final text = (review.text ?? '').trim();

    return StoryCanvas(
      children: [
        Opacity(opacity: 0.55, child: StoryBlur(review.posterUrl, dim: 0.2)),
        // The glow: the poster's colour gathered behind the poster.
        Positioned(
          left: -10.u,
          right: -10.u,
          top: 10.u,
          height: 110.u,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  glow.withValues(alpha: 0.75),
                  glow.withValues(alpha: 0.0),
                ],
                stops: const [0.0, 0.72],
              ),
            ),
          ),
        ),
        ColoredBox(color: Colors.black.withValues(alpha: 0.3)),
        const StoryGrain(),
        Positioned(
          left: 7.u,
          top: 21.u,
          child: StoryAuthor(
            username: review.username,
            photoUrl: review.userPhotoUrl,
            caption: 'reviewed',
          ),
        ),
        Positioned(
          left: 7.u,
          right: 7.u,
          top: 32.u,
          bottom: 16.u,
          child: Column(
            children: [
              StoryPoster(url: review.posterUrl, width: 48.u, radius: 2.u),
              SizedBox(height: 5.u),
              Text(
                review.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 7.u,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.14.u,
                  height: 1.05,
                ),
              ),
              if (credit.isNotEmpty) ...[
                SizedBox(height: 1.2.u),
                Text(
                  credit,
                  style: TextStyle(
                    fontSize: 3.2.u,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ],
              if (review.rating != null) ...[
                SizedBox(height: 3.u),
                StoryStars(rating: review.rating!, size: 6.u),
              ],
              if (text.isNotEmpty) ...[
                SizedBox(height: 3.4.u),
                Text(
                  text,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 4.3.u,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                    color: Colors.white.withValues(alpha: 0.92),
                  ),
                ),
              ],
              const Spacer(),
              const StoryBrand(),
            ],
          ),
        ),
      ],
    );
  }
}

/// The three stills R3 uses, as URLs. The poster stands in if TMDB has no
/// stills for the title.
List<String> filmStripUrls(List<String> stills) => [
      for (final p in stills.take(3))
        ApiConstants.getBackdropUrl(p, size: ApiConstants.backdropSizeMedium),
    ];

/// R3: three stills on a strip of 35mm negative, edge codes down the
/// sides, then the rating and a line of the review.
class FilmStripCard extends ConsumerWidget {
  const FilmStripCard({super.key, required this.review});

  final ReviewShare review;

  static const _edge = Color(0xFFFF9B3D);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stills = filmStripUrls(
        ref.watch(filmStillsProvider(review.stillsKey)).valueOrNull ?? []);
    final frames = [
      for (var i = 0; i < 3; i++)
        stills.isEmpty ? review.posterUrl : stills[i % stills.length],
    ];
    final text = (review.text ?? '').trim();
    final edgeStyle = TextStyle(
      fontFamily: 'IBMPlexMono',
      fontWeight: FontWeight.w600,
      fontSize: 1.9.u,
      letterSpacing: 0.6.u,
      color: _edge.withValues(alpha: 0.85),
      height: 1,
    );
    final title = review.title.toUpperCase();

    return StoryCanvas(
      background: const Color(0xFF070605),
      children: [
        const StoryGrain(),
        Positioned(
          left: 14.u,
          right: 14.u,
          top: 18.u,
          child: Transform.rotate(
            angle: -2 * math.pi / 180,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 10.u, vertical: 1.2.u),
              decoration: BoxDecoration(
                color: const Color(0xFF1B140E),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 10.u,
                    offset: Offset(0, 4.u),
                  ),
                ],
              ),
              child: CustomPaint(
                painter: _Sprockets(),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Column(
                      children: [
                        for (final url in frames)
                          Container(
                            height: 29.u,
                            margin: EdgeInsets.symmetric(vertical: 1.8.u),
                            decoration: BoxDecoration(
                              border:
                                  Border.all(color: Colors.black, width: 0.3.u),
                            ),
                            child: StoryImage(url),
                          ),
                      ],
                    ),
                    Positioned(
                      right: -9.6.u,
                      top: 0,
                      bottom: 0,
                      child: RotatedBox(
                        quarterTurns: 1,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Text('KODAK 5219  ▸ 14', style: edgeStyle),
                            Text('35MM  ▸ 14A', style: edgeStyle),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: -9.6.u,
                      top: 0,
                      bottom: 0,
                      child: RotatedBox(
                        quarterTurns: 3,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Text(
                                [
                                  title,
                                  if ((review.year ?? '').isNotEmpty)
                                    review.year
                                ].join(' · '),
                                style: edgeStyle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            Text('▸ 15', style: edgeStyle),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 8.u,
          right: 8.u,
          bottom: 16.u,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      review.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 6.4.u,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.13.u,
                        height: 1,
                      ),
                    ),
                  ),
                  if (review.rating != null) ...[
                    SizedBox(width: 2.u),
                    StoryStars(rating: review.rating!, size: 4.4.u),
                  ],
                ],
              ),
              if (text.isNotEmpty) ...[
                SizedBox(height: 2.4.u),
                Text(
                  text,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 4.u,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                    color: Colors.white.withValues(alpha: 0.88),
                  ),
                ),
              ],
              SizedBox(height: 2.4.u),
              Row(
                children: [
                  StoryAuthor(
                    username: review.username,
                    photoUrl: review.userPhotoUrl,
                  ),
                  const Spacer(),
                  const StoryBrand(),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The perforations down both edges of the strip.
class _Sprockets extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFE9E2D4);
    final w = 3.6.u;
    final h = 2.6.u;
    final pitch = 5.4.u;
    for (final x in [-7.6.u, size.width + 7.6.u - w]) {
      for (var y = 1.2.u; y + h < size.height; y += pitch) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(x, y, w, h), Radius.circular(0.5.u)),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
