import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/widgets.dart' show IconData;

import '../core/constants/api_constants.dart';
import 'episode_model.dart';
import 'film_model.dart';

/// What an Explore post is, which decides how it looks.
///
/// Each kind is a layout, not a label: a hot take is set as a headline, a
/// critique as an article, a review around its subject's artwork. The
/// composer restyles itself as you switch, so what you type already looks
/// like what will be posted.
enum ExploreKind {
  thought('thought', 'Thought', 'Thoughts', CupertinoIcons.text_quote,
      'Anything on your mind.'),
  take('take', 'Hot take', 'Hot takes', CupertinoIcons.flame,
      'One bold line. People agree or disagree.'),
  review('review', 'Review', 'Reviews', CupertinoIcons.star,
      'A rating and a verdict on one title.'),
  critique('critique', 'Critique', 'Critiques', CupertinoIcons.book,
      'A titled, long-form piece.'),
  discussion('discussion', 'Discussion', 'Discussions',
      CupertinoIcons.chat_bubble_2, 'Ask a question and start a thread.'),
  list('list', 'List', 'Lists', CupertinoIcons.rectangle_stack,
      'Share one of your public playlists.');

  const ExploreKind(
      this.value, this.label, this.plural, this.icon, this.description);

  final String value;
  final String label;
  final String plural;
  final IconData icon;
  final String description;

  static ExploreKind parse(String? value) => ExploreKind.values.firstWhere(
        (k) => k.value == value,
        orElse: () => ExploreKind.thought,
      );

  int get maxLength => switch (this) {
        ExploreKind.take => 280,
        ExploreKind.critique => 4000,
        ExploreKind.review => 2000,
        ExploreKind.list => 500,
        _ => 1000,
      };

  bool get needsSubject => this == ExploreKind.review;
  bool get needsHeadline => this == ExploreKind.critique;
  bool get hasHeadline => this == ExploreKind.critique;
  bool get hasRating => this == ExploreKind.review;

  /// A list post is about a playlist, never a film, and its text is an
  /// optional caption.
  bool get isList => this == ExploreKind.list;

  /// Hot takes are voted on; everything else is liked.
  bool get isVoted => this == ExploreKind.take;

  /// Only conversational posts take comments. Takes, reviews and critiques
  /// are someone's stated opinion — a reply thread under them turns into a
  /// pile-on. A list invites "you forgot X", so it's open. The database
  /// enforces the same rule (migrations 005 and 010).
  bool get allowsComments =>
      this == ExploreKind.thought ||
      this == ExploreKind.discussion ||
      this == ExploreKind.list;
}

/// The film, show or episode a post is about.
class ExploreSubject {
  const ExploreSubject({
    required this.filmId,
    required this.mediaType,
    required this.title,
    this.posterPath,
    this.backdropPath,
    this.year,
    this.seasonNumber,
    this.episodeNumber,
    this.episodeTitle,
    this.episodeStillPath,
  });

  factory ExploreSubject.fromFilm(FilmModel film, {EpisodeModel? episode}) {
    return ExploreSubject(
      filmId: film.id,
      mediaType: film.isTv ? 'tv' : 'movie',
      title: film.displayTitle,
      posterPath: film.posterPath,
      backdropPath: film.backdropPath,
      year: film.year,
      seasonNumber: episode?.seasonNumber,
      episodeNumber: episode?.episodeNumber,
      episodeTitle: episode?.name,
      episodeStillPath: episode?.stillPath,
    );
  }

  final int filmId;
  final String mediaType;
  final String title;
  final String? posterPath;
  final String? backdropPath;
  final String? year;
  final int? seasonNumber;
  final int? episodeNumber;
  final String? episodeTitle;
  final String? episodeStillPath;

  bool get isTv => mediaType == 'tv';
  bool get isEpisode => seasonNumber != null && episodeNumber != null;

  /// The same title regardless of which episode — what the feed filters on.
  ExploreSubject get titleOnly => isEpisode
      ? ExploreSubject(
          filmId: filmId,
          mediaType: mediaType,
          title: title,
          posterPath: posterPath,
          backdropPath: backdropPath,
          year: year,
        )
      : this;

  String? get episodeCode =>
      isEpisode ? 'S$seasonNumber E$episodeNumber' : null;

  String get posterUrl =>
      ApiConstants.getPosterUrl(posterPath, size: ApiConstants.posterSizeSmall);

  /// Wide artwork: the episode's still if there is one, else the backdrop.
  String get wideUrl {
    if (isEpisode && (episodeStillPath ?? '').isNotEmpty) {
      return ApiConstants.getStillUrl(episodeStillPath,
          size: ApiConstants.stillSizeLarge);
    }
    return ApiConstants.getBackdropUrl(backdropPath);
  }

  /// "Severance · S2 E5 · Chikhai Bardo", "Past Lives · 2023".
  String get caption {
    if (isEpisode) {
      return [episodeCode, if ((episodeTitle ?? '').isNotEmpty) episodeTitle]
          .whereType<String>()
          .join('  ·  ');
    }
    return [if ((year ?? '').isNotEmpty) year, isTv ? 'Series' : 'Film']
        .whereType<String>()
        .join('  ·  ');
  }

  /// Clears every subject column, for an edit that removes the tag.
  static const Map<String, dynamic> emptyDbMap = {
    'film_id': null,
    'media_type': null,
    'film_title': null,
    'film_poster_path': null,
    'film_backdrop_path': null,
    'film_year': null,
    'season_number': null,
    'episode_number': null,
    'episode_title': null,
    'episode_still_path': null,
  };

  Map<String, dynamic> toDbMap() => {
        'film_id': filmId,
        'media_type': mediaType,
        'film_title': title,
        'film_poster_path': posterPath,
        'film_backdrop_path': backdropPath,
        'film_year': year,
        'season_number': seasonNumber,
        'episode_number': episodeNumber,
        'episode_title': episodeTitle,
        'episode_still_path': episodeStillPath,
      };

  @override
  bool operator ==(Object other) =>
      other is ExploreSubject &&
      other.filmId == filmId &&
      other.mediaType == mediaType &&
      other.seasonNumber == seasonNumber &&
      other.episodeNumber == episodeNumber;

  @override
  int get hashCode =>
      Object.hash(filmId, mediaType, seasonNumber, episodeNumber);
}

/// The playlist a list post shares, as `explore_feed` joins it.
class ExploreListRef {
  const ExploreListRef({
    required this.id,
    required this.title,
    this.description,
    this.itemCount = 0,
    this.posters = const [],
  });

  final String id;
  final String title;
  final String? description;
  final int itemCount;

  /// The first four posters, for the cover.
  final List<String?> posters;
}

/// One row of `explore_feed`.
class ExplorePost {
  const ExplorePost({
    required this.id,
    required this.userId,
    required this.username,
    this.userPhotoUrl,
    required this.kind,
    this.headline,
    required this.body,
    this.rating,
    this.hasSpoilers = false,
    this.subject,
    this.list,
    this.agreeCount = 0,
    this.disagreeCount = 0,
    this.commentCount = 0,
    this.myVote = 0,
    required this.createdAt,
    this.updatedAt,
  });

  factory ExplorePost.fromRow(Map<String, dynamic> row) {
    final filmId = row['film_id'] as int?;
    final listId = row['list_id'] as String?;
    return ExplorePost(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      username: row['username'] as String? ?? 'unknown',
      userPhotoUrl: row['user_photo_url'] as String?,
      kind: ExploreKind.parse(row['kind'] as String?),
      headline: row['headline'] as String?,
      body: row['body'] as String? ?? '',
      rating: (row['rating'] as num?)?.toDouble(),
      hasSpoilers: row['has_spoilers'] as bool? ?? false,
      subject: filmId == null
          ? null
          : ExploreSubject(
              filmId: filmId,
              mediaType: row['media_type'] as String? ?? 'movie',
              title: row['film_title'] as String? ?? '',
              posterPath: row['film_poster_path'] as String?,
              backdropPath: row['film_backdrop_path'] as String?,
              year: row['film_year'] as String?,
              seasonNumber: row['season_number'] as int?,
              episodeNumber: row['episode_number'] as int?,
              episodeTitle: row['episode_title'] as String?,
              episodeStillPath: row['episode_still_path'] as String?,
            ),
      list: listId == null
          ? null
          : ExploreListRef(
              id: listId,
              title: row['list_title'] as String? ?? 'Untitled',
              description: row['list_description'] as String?,
              itemCount: row['list_item_count'] as int? ?? 0,
              posters: [
                for (final p in (row['list_posters'] as List?) ?? const [])
                  p as String?,
              ],
            ),
      agreeCount: row['agree_count'] as int? ?? 0,
      disagreeCount: row['disagree_count'] as int? ?? 0,
      commentCount: row['comment_count'] as int? ?? 0,
      myVote: (row['my_vote'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
      updatedAt: row['updated_at'] == null
          ? null
          : DateTime.parse(row['updated_at'] as String).toLocal(),
    );
  }

  final String id;
  final String userId;
  final String username;
  final String? userPhotoUrl;
  final ExploreKind kind;
  final String? headline;
  final String body;
  final double? rating;
  final bool hasSpoilers;
  final ExploreSubject? subject;

  /// Set on list posts only.
  final ExploreListRef? list;
  final int agreeCount;
  final int disagreeCount;
  final int commentCount;

  /// The viewer's vote: 1, -1, or 0 for none.
  final int myVote;
  final DateTime createdAt;

  /// When the content was last edited; null if never.
  final DateTime? updatedAt;

  bool get isEdited => updatedAt != null;

  int get totalVotes => agreeCount + disagreeCount;

  /// Share of voters who agree, 0–1. Null until someone has voted.
  double? get agreeShare => totalVotes == 0 ? null : agreeCount / totalVotes;

  /// Minutes to read, for critiques. ~230 wpm, never less than one.
  int get readMinutes {
    final words = body.trim().split(RegExp(r'\s+')).length;
    return (words / 230).ceil().clamp(1, 99);
  }

  String get relativeTime {
    final d = DateTime.now().difference(createdAt);
    if (d.inDays >= 7) return '${(d.inDays / 7).floor()}w';
    if (d.inDays > 0) return '${d.inDays}d';
    if (d.inHours > 0) return '${d.inHours}h';
    if (d.inMinutes > 0) return '${d.inMinutes}m';
    return 'now';
  }

  /// Applies the viewer's new vote locally so the UI answers the tap at once.
  ExplorePost withVote(int value) {
    var agree = agreeCount - (myVote == 1 ? 1 : 0);
    var disagree = disagreeCount - (myVote == -1 ? 1 : 0);
    if (value == 1) agree++;
    if (value == -1) disagree++;
    return _copy(agreeCount: agree, disagreeCount: disagree, myVote: value);
  }

  ExplorePost withCommentDelta(int delta) =>
      _copy(commentCount: (commentCount + delta).clamp(0, 1 << 30));

  ExplorePost _copy({
    int? agreeCount,
    int? disagreeCount,
    int? commentCount,
    int? myVote,
  }) =>
      ExplorePost(
        id: id,
        userId: userId,
        username: username,
        userPhotoUrl: userPhotoUrl,
        kind: kind,
        headline: headline,
        body: body,
        rating: rating,
        hasSpoilers: hasSpoilers,
        subject: subject,
        list: list,
        agreeCount: agreeCount ?? this.agreeCount,
        disagreeCount: disagreeCount ?? this.disagreeCount,
        commentCount: commentCount ?? this.commentCount,
        myVote: myVote ?? this.myVote,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}
