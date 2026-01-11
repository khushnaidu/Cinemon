import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'notification_model.freezed.dart';
part 'notification_model.g.dart';

/// Type of notification
enum NotificationType {
  /// Someone liked your post
  like,

  /// Someone commented on your post
  comment,

  /// Someone reacted to your post with a sticker
  reaction,

  /// Someone requested to follow you
  followRequest,

  /// Someone accepted your follow request
  followAccepted,
}

/// Represents a notification for user activity.
///
/// Created when someone interacts with a user's content.
@freezed
class NotificationModel with _$NotificationModel {
  const NotificationModel._();

  const factory NotificationModel({
    /// Unique notification ID (Firestore document ID)
    required String id,

    /// User ID who receives this notification (activity owner)
    required String recipientId,

    /// User ID who triggered the notification (who liked/commented/etc)
    required String actorId,

    /// Actor's username (denormalized)
    required String actorUsername,

    /// Actor's profile photo URL (denormalized)
    String? actorPhotoUrl,

    /// Type of notification
    required NotificationType type,

    /// Activity ID this notification relates to (null for follow notifications)
    String? activityId,

    /// Film title for context (denormalized)
    String? filmTitle,

    /// Film poster path for display
    String? filmPosterPath,

    /// Comment text preview (for comment notifications)
    String? commentPreview,

    /// Sticker ID (for reaction notifications)
    String? stickerId,

    /// Whether the notification has been read
    @Default(false) bool isRead,

    /// When this notification was created
    required DateTime createdAt,
  }) = _NotificationModel;

  factory NotificationModel.fromJson(Map<String, dynamic> json) =>
      _$NotificationModelFromJson(json);

  /// Creates from Firestore document
  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Parse notification type from string
    final typeStr = data['type'] as String? ?? 'like';
    final type = NotificationType.values.firstWhere(
      (e) => e.name == typeStr,
      orElse: () => NotificationType.like,
    );

    return NotificationModel(
      id: doc.id,
      recipientId: data['recipientId'] as String,
      actorId: data['actorId'] as String,
      actorUsername: data['actorUsername'] as String,
      actorPhotoUrl: data['actorPhotoUrl'] as String?,
      type: type,
      activityId: data['activityId'] as String?,
      filmTitle: data['filmTitle'] as String?,
      filmPosterPath: data['filmPosterPath'] as String?,
      commentPreview: data['commentPreview'] as String?,
      stickerId: data['stickerId'] as String?,
      isRead: data['isRead'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  /// Get display message based on notification type
  String get message {
    switch (type) {
      case NotificationType.like:
        return 'liked your post${filmTitle != null ? ' on $filmTitle' : ''}';
      case NotificationType.comment:
        return 'commented on your post${filmTitle != null ? ' on $filmTitle' : ''}';
      case NotificationType.reaction:
        return 'reacted to your post${filmTitle != null ? ' on $filmTitle' : ''}';
      case NotificationType.followRequest:
        return 'requested to follow you';
      case NotificationType.followAccepted:
        return 'accepted your follow request';
    }
  }

  /// Get relative time string
  String get relativeTime {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return '${years}y';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return '${months}mo';
    } else if (difference.inDays > 7) {
      final weeks = (difference.inDays / 7).floor();
      return '${weeks}w';
    } else if (difference.inDays > 0) {
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
      'recipientId': recipientId,
      'actorId': actorId,
      'actorUsername': actorUsername,
      'actorPhotoUrl': actorPhotoUrl,
      'type': type.name,
      'activityId': activityId,
      'filmTitle': filmTitle,
      'filmPosterPath': filmPosterPath,
      'commentPreview': commentPreview,
      'stickerId': stickerId,
      'isRead': isRead,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
