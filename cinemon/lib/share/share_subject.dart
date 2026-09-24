import 'package:flutter/material.dart';

import '../core/constants/api_constants.dart';
import '../core/utils/poster_palette.dart';
import '../models/activity_model.dart';
import '../models/explore_post_model.dart';
import 'cards/episode_cards.dart';
import 'cards/hot_take_cards.dart';
import 'cards/review_cards.dart';

/// What the share sheet is sharing (ADR 0003, D4). Each subject knows its
/// card styles, the images those styles draw, and the poster the colours
/// come from.
sealed class ShareSubject {
  const ShareSubject();

  /// "Share hot take".
  String get sheetTitle;

  /// Styles in the order the sheet shows them; the first is the default.
  List<ShareTemplate> get templates;

  /// The poster the swatches and washes are sampled from.
  String get paletteUrl;

  /// Every image any style draws, warmed before export is allowed.
  List<String> get imageUrls;

  /// Where the link sticker should point.
  Uri get link => Uri.parse('https://35mm.contact');
}

/// A share card style.
///
/// A full-story style builds the whole 9:16 canvas. A sticker style builds
/// only the card, which Instagram lets people move and resize; the sheet
/// puts it on a gradient for the preview and for saved images.
class ShareTemplate {
  const ShareTemplate({
    required this.code,
    required this.name,
    required this.build,
    this.sticker = false,
  });

  /// The mockup code, like "H1".
  final String code;
  final String name;
  final bool sticker;
  final Widget Function(ShareLook look) build;
}

/// The colour choice from the sheet's swatches (ADR 0003, D6). [tint] is
/// null for the card's own default look.
class ShareLook {
  const ShareLook({required this.palette, this.tint});

  final PosterPalette palette;
  final Color? tint;

  /// With no poster to sample, stickers sit on the mockups' indigo rather
  /// than the neutral palette's projector white, which darkens to brown.
  static const _fallback = Color(0xFF3B36A8);

  Color get _base =>
      tint ??
      (identical(palette, PosterPalette.neutral) ? _fallback : palette.primary);

  /// A sticker's background: the tint (or the poster's main colour) fading
  /// to near black, like Spotify's song share.
  Color get top => _shade(_base, 0.55);
  Color get bottom => _shade(_base, 0.12);

  static Color _shade(Color c, double lightness) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withLightness((hsl.lightness * lightness * 1.6).clamp(0.04, 0.5))
        .toColor();
  }
}

String _poster(String? path) =>
    ApiConstants.getPosterUrl(path, size: ApiConstants.posterSizeLarge);

// ─────────────────────────────────────────────────────────────
// Hot take
// ─────────────────────────────────────────────────────────────

class TakeShare extends ShareSubject {
  const TakeShare(this.post);

  final ExplorePost post;

  @override
  String get sheetTitle => 'Share hot take';

  @override
  String get paletteUrl => _poster(post.subject?.posterPath);

  @override
  List<String> get imageUrls => [
        paletteUrl,
        if ((post.userPhotoUrl ?? '').isNotEmpty) post.userPhotoUrl!,
      ].where((u) => u.isNotEmpty).toList();

  @override
  List<ShareTemplate> get templates => [
        ShareTemplate(
          code: 'H1',
          name: 'Headline',
          build: (look) => HeadlineTakeCard(post: post, look: look),
        ),
        ShareTemplate(
          code: 'H3',
          name: 'Sticker',
          sticker: true,
          build: (look) => StickerTakeCard(post: post),
        ),
      ];
}

// ─────────────────────────────────────────────────────────────
// Review
// ─────────────────────────────────────────────────────────────

/// A rating and review of one film or show, from a logged activity or an
/// Explore review. Episodes go to [EpisodeShare].
class ReviewShare extends ShareSubject {
  const ReviewShare({
    required this.username,
    required this.userPhotoUrl,
    required this.filmId,
    required this.mediaType,
    required this.title,
    required this.year,
    required this.posterPath,
    required this.rating,
    required this.text,
  });

  factory ReviewShare.fromActivity(ActivityModel a) => ReviewShare(
        username: a.username,
        userPhotoUrl: a.userPhotoUrl,
        filmId: a.filmId,
        mediaType: a.mediaType,
        title: a.filmTitle,
        year: a.filmYear,
        posterPath: a.filmPosterPath,
        rating: a.hasRating ? a.rating : null,
        text: a.reviewText,
      );

  factory ReviewShare.fromPost(ExplorePost p) {
    final s = p.subject!;
    return ReviewShare(
      username: p.username,
      userPhotoUrl: p.userPhotoUrl,
      filmId: s.filmId,
      mediaType: s.mediaType,
      title: s.title,
      year: s.year,
      posterPath: s.posterPath,
      rating: p.rating,
      text: p.body,
    );
  }

  final String username;
  final String? userPhotoUrl;
  final int filmId;
  final String mediaType;
  final String title;
  final String? year;
  final String? posterPath;
  final double? rating;
  final String? text;

  String get posterUrl => _poster(posterPath);

  @override
  String get sheetTitle => 'Share review';

  @override
  String get paletteUrl => posterUrl;

  @override
  List<String> get imageUrls => [
        posterUrl,
        if ((userPhotoUrl ?? '').isNotEmpty) userPhotoUrl!,
      ].where((u) => u.isNotEmpty).toList();

  @override
  List<ShareTemplate> get templates => [
        ShareTemplate(
          code: 'R2',
          name: 'Poster and verdict',
          build: (look) => PosterVerdictCard(review: this, look: look),
        ),
      ];
}

// ─────────────────────────────────────────────────────────────
// Episode review
// ─────────────────────────────────────────────────────────────

class EpisodeShare extends ShareSubject {
  const EpisodeShare({
    required this.username,
    required this.userPhotoUrl,
    required this.showTitle,
    required this.posterPath,
    required this.stillPath,
    required this.seasonNumber,
    required this.episodeNumber,
    required this.episodeTitle,
    required this.rating,
    required this.text,
  });

  factory EpisodeShare.fromActivity(ActivityModel a) => EpisodeShare(
        username: a.username,
        userPhotoUrl: a.userPhotoUrl,
        showTitle: a.filmTitle,
        posterPath: a.filmPosterPath,
        stillPath: a.episodeStillPath,
        seasonNumber: a.seasonNumber!,
        episodeNumber: a.episodeNumber!,
        episodeTitle: a.episodeTitle,
        rating: a.hasRating ? a.rating : null,
        text: a.reviewText,
      );

  factory EpisodeShare.fromPost(ExplorePost p) {
    final s = p.subject!;
    return EpisodeShare(
      username: p.username,
      userPhotoUrl: p.userPhotoUrl,
      showTitle: s.title,
      posterPath: s.posterPath,
      stillPath: s.episodeStillPath,
      seasonNumber: s.seasonNumber!,
      episodeNumber: s.episodeNumber!,
      episodeTitle: s.episodeTitle,
      rating: p.rating,
      text: p.body,
    );
  }

  final String username;
  final String? userPhotoUrl;
  final String showTitle;
  final String? posterPath;
  final String? stillPath;
  final int seasonNumber;
  final int episodeNumber;
  final String? episodeTitle;
  final double? rating;
  final String? text;

  String get code => 'S$seasonNumber E$episodeNumber';
  String get stillUrl =>
      ApiConstants.getStillUrl(stillPath, size: ApiConstants.stillSizeLarge);
  String get posterUrl => _poster(posterPath);

  @override
  String get sheetTitle => 'Share episode review';

  /// The still carries the episode's own colour; the show poster is the
  /// fallback.
  @override
  String get paletteUrl => stillUrl.isNotEmpty ? stillUrl : posterUrl;

  @override
  List<String> get imageUrls => [
        stillUrl,
        posterUrl,
        if ((userPhotoUrl ?? '').isNotEmpty) userPhotoUrl!,
      ].where((u) => u.isNotEmpty).toList();

  @override
  List<ShareTemplate> get templates => [
        ShareTemplate(
          code: 'E1',
          name: 'Episode card',
          build: (look) => EpisodeCardStory(episode: this, look: look),
        ),
      ];
}

/// The share subject for a feed activity, or null if there's nothing on it
/// worth a card.
ShareSubject? shareSubjectForActivity(ActivityModel a) {
  if (!a.hasRating && !a.hasReview) return null;
  return a.isEpisode
      ? EpisodeShare.fromActivity(a)
      : ReviewShare.fromActivity(a);
}

/// The share subject for an Explore post, or null for kinds that have no
/// card yet.
ShareSubject? shareSubjectForPost(ExplorePost p) {
  final s = p.subject;
  return switch (p.kind) {
    ExploreKind.take => TakeShare(p),
    ExploreKind.review when s != null =>
      s.isEpisode ? EpisodeShare.fromPost(p) : ReviewShare.fromPost(p),
    _ => null,
  };
}
