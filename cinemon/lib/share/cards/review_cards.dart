import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
