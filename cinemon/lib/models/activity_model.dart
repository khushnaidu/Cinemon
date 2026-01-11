import 'package:cloud_firestore/cloud_firestore.dart';
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

  const factory ActivityModel({
    /// Unique activity ID (Firestore document ID)
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

  /// Creates an ActivityModel from Firestore document
  factory ActivityModel.fromJson(Map<String, dynamic> json) =>
      _$ActivityModelFromJson(json);

  /// Creates from Firestore document with ID
  factory ActivityModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Parse activityType from string
    final activityTypeStr = data['activityType'] as String? ?? 'watched';
    final activityType = ActivityType.values.firstWhere(
      (e) => e.name == activityTypeStr,
      orElse: () => ActivityType.watched,
    );

    return ActivityModel(
      id: doc.id,
      userId: data['userId'] as String,
      username: data['username'] as String,
      userPhotoUrl: data['userPhotoUrl'] as String?,
      activityType: activityType,
      filmId: data['filmId'] as int,
      filmTitle: data['filmTitle'] as String,
      filmPosterPath: data['filmPosterPath'] as String?,
      filmBackdropPath: data['filmBackdropPath'] as String?,
      filmYear: data['filmYear'] as String?,
      mediaType: data['mediaType'] as String? ?? 'movie',
      rating: (data['rating'] as num?)?.toDouble(),
      reviewText: data['reviewText'] as String?,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      likes: List<String>.from(data['likes'] ?? []),
      commentCount: data['commentCount'] as int? ?? 0,
      reactions: Map<String, String>.from(data['reactions'] ?? {}),
    );
  }

  /// Whether this activity has a rating
  bool get hasRating => rating != null && rating! > 0;

  /// Whether this activity has a review
  bool get hasReview => reviewText != null && reviewText!.isNotEmpty;

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

  /// Convert to Firestore document data
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'username': username,
      'userPhotoUrl': userPhotoUrl,
      'activityType': activityType.name,
      'filmId': filmId,
      'filmTitle': filmTitle,
      'filmPosterPath': filmPosterPath,
      'filmBackdropPath': filmBackdropPath,
      'filmYear': filmYear,
      'mediaType': mediaType,
      'rating': rating,
      'reviewText': reviewText,
      'createdAt': Timestamp.fromDate(createdAt),
      'likes': likes,
      'commentCount': commentCount,
      'reactions': reactions,
    };
  }
}

/// Comment on an activity
@freezed
class CommentModel with _$CommentModel {
  const CommentModel._();

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

  /// Creates from Firestore document
  factory CommentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CommentModel.fromJson({
      ...data,
      'id': doc.id,
      'createdAt': (data['createdAt'] as Timestamp).toDate().toIso8601String(),
    });
  }

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

  /// Convert to Firestore data
  Map<String, dynamic> toFirestore() {
    return {
      'activityId': activityId,
      'userId': userId,
      'username': username,
      'userPhotoUrl': userPhotoUrl,
      'content': content,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
