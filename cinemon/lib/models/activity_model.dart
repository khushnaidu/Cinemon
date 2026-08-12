import 'package:freezed_annotation/freezed_annotation.dart';

part 'activity_model.freezed.dart';
part 'activity_model.g.dart';

/// Type of activity in the feed
enum ActivityType {
  /// User watched a film (no review required)
  watched,

  /// User reviewed a film (has rating and/or review text)
  reviewed,
}

/// Represents a feed activity post.
///
/// Created when a user posts that they watched or reviewed a film.
/// Contains user info, film info, and optional rating/review.
@freezed
class ActivityModel with _$ActivityModel {
  const ActivityModel._();

  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory ActivityModel({
    /// Unique activity ID (uuid primary key)
    required String id,

    /// User ID who created this activity
    required String userId,

    /// Username for display (denormalized for performance)
    required String username,

    /// User's profile photo URL (denormalized)
    String? userPhotoUrl,

    /// Type of activity (watched or reviewed)
    required ActivityType activityType,

    /// TMDB film ID
    required int filmId,

    /// Film title (denormalized for display)
    required String filmTitle,

    /// Film poster path from TMDB
    String? filmPosterPath,

    /// Film backdrop path from TMDB
    String? filmBackdropPath,

    /// Film release year
    String? filmYear,

    /// Media type (movie or tv)
    @Default('movie') String mediaType,

    /// User's rating (0-5 stars, nullable if just "watched")
    double? rating,

    /// User's review text (nullable)
    String? reviewText,

    /// Public URL of a spoken review, if one was recorded.
    String? voiceNoteUrl,

    /// How long that recording runs. Stored rather than read off the file so
    /// the waveform can be drawn, and the duration labelled, before a single
    /// byte of audio is fetched.
    @Default(0) int voiceNoteDurationMs,

    /// Peak amplitude per slice of the recording, 0..1, sampled live while it
    /// was being made.
    ///
    /// Kept alongside the audio because the alternative is decoding the file
    /// on every device that scrolls past it just to draw a picture of it.
    @Default([]) List<double> voiceNoteWaveform,

    /// Public URLs of photos taken with the review, in capture order.
    @Default([]) List<String> photoUrls,

    /// When this activity was created
    required DateTime createdAt,

    /// User IDs who liked this activity
    @Default([]) List<String> likes,

    /// Number of comments (denormalized count)
    @Default(0) int commentCount,

    /// Reactions map: userId -> stickerId
    /// Each user can only have one reaction per activity
    @Default({}) Map<String, String> reactions,
  }) = _ActivityModel;

  factory ActivityModel.fromJson(Map<String, dynamic> json) =>
      _$ActivityModelFromJson(json);

  /// Creates from a `feed_activities` view row.
  ///
  /// Rows from the plain `activities` table lack the joined columns
  /// (username, likes, reactions); those are defaulted here so a bare
  /// table row still deserializes instead of throwing.
  factory ActivityModel.fromRow(Map<String, dynamic> row) {
    return ActivityModel.fromJson({
      ...row,
      'username': row['username'] ?? 'unknown',
      'likes': List<String>.from(row['likes'] as List? ?? const []),
      'reactions':
          Map<String, String>.from(row['reactions'] as Map? ?? const {}),
      // Postgres `numeric` can arrive as num or String depending on driver
      'rating': row['rating'] == null
          ? null
          : double.tryParse(row['rating'].toString()),
    });
  }

  /// Whether this activity has a rating
  bool get hasRating => rating != null && rating! > 0;

  /// Whether this activity has a review
  bool get hasReview => reviewText != null && reviewText!.isNotEmpty;

  /// Whether a spoken review was recorded.
  bool get hasVoiceNote =>
      voiceNoteUrl != null && voiceNoteUrl!.isNotEmpty;

  /// Whether any photos were taken with the review.
  bool get hasPhotos => photoUrls.isNotEmpty;

  /// Whether the review carries anything beyond its text.
  bool get hasArtifacts => hasVoiceNote || hasPhotos;

  /// Get like count
  int get likeCount => likes.length;

  /// Check if a user has liked this activity
  bool isLikedBy(String userId) => likes.contains(userId);

  /// Get the total reaction count
  int get reactionCount => reactions.length;

  /// Check if a user has reacted to this activity
  bool hasReactionFrom(String userId) => reactions.containsKey(userId);

  /// Get a user's reaction sticker ID (null if no reaction)
  String? getReactionFrom(String userId) => reactions[userId];

  /// Get unique sticker IDs used in reactions
  Set<String> get uniqueReactionStickers => reactions.values.toSet();

  /// Get relative time string (e.g., "2h ago")
  String get relativeTime {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return '${years}y ago';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return '${months}mo ago';
    } else if (difference.inDays > 7) {
      final weeks = (difference.inDays / 7).floor();
      return '${weeks}w ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  /// Payload for inserting/updating a row in `activities`.
  ///
  /// username / user_photo_url / likes / reactions are deliberately absent:
  /// they are view-only columns assembled by `feed_activities` from joins,
  /// and comment_count is trigger-maintained. Writing them would fail.
  Map<String, dynamic> toDbMap() {
    return {
      // Only when the caller minted one. Posts with media generate their id up
      // front so the files can be uploaded to a path under it before the row
      // exists; everything else leaves it to the column default.
      if (id.isNotEmpty) 'id': id,
      'user_id': userId,
      'activity_type': activityType.name,
      'film_id': filmId,
      'film_title': filmTitle,
      'film_poster_path': filmPosterPath,
      'film_backdrop_path': filmBackdropPath,
      'film_year': filmYear,
      'media_type': mediaType,
      'rating': rating,
      'review_text': reviewText,
      'voice_note_url': voiceNoteUrl,
      'voice_note_duration_ms': voiceNoteDurationMs,
      'voice_note_waveform': voiceNoteWaveform,
      'photo_urls': photoUrls,
    };
  }
}

/// Comment on an activity
@freezed
class CommentModel with _$CommentModel {
  const CommentModel._();

  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory CommentModel({
    /// Comment ID
    required String id,

    /// Activity ID this comment belongs to
    required String activityId,

    /// User ID who wrote the comment
    required String userId,

    /// Username (denormalized)
    required String username,

    /// User photo URL (denormalized)
    String? userPhotoUrl,

    /// Comment text
    required String content,

    /// When comment was created
    required DateTime createdAt,
  }) = _CommentModel;

  factory CommentModel.fromJson(Map<String, dynamic> json) =>
      _$CommentModelFromJson(json);

  /// Get relative time string
  String get relativeTime {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'now';
    }
  }

  /// Payload for inserting a row in `comments`.
  /// username / user_photo_url come from the profiles join on read.
  Map<String, dynamic> toDbMap() {
    return {
      'activity_id': activityId,
      'user_id': userId,
      'content': content,
    };
  }
}
