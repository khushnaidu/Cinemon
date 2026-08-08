import 'package:freezed_annotation/freezed_annotation.dart';

part 'friendship_model.freezed.dart';
part 'friendship_model.g.dart';

/// Status of a friendship/follow request
enum FriendshipStatus {
  /// Request sent, waiting for acceptance
  pending,

  /// Both users have accepted - they are friends
  accepted,

  /// Request was declined
  declined,
}

/// Represents a friendship/mutual follow relationship.
///
/// For mutual follows, when user A sends a request to user B:
/// 1. A friendship document is created with status 'pending'
/// 2. When B accepts, status changes to 'accepted'
/// 3. Both users can then see each other's activities in their feeds
@freezed
class FriendshipModel with _$FriendshipModel {
  const FriendshipModel._();

  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory FriendshipModel({
    /// Row id (uuid)
    required String id,

    /// User who sent the friend request
    required String senderId,

    /// User who received the friend request
    required String receiverId,

    /// Current status of the friendship
    required FriendshipStatus status,

    /// When the request was sent
    required DateTime createdAt,

    /// When the request was accepted (null if pending)
    DateTime? acceptedAt,

    /// Sender's username (denormalized for display)
    String? senderUsername,

    /// Sender's photo URL (denormalized)
    String? senderPhotoUrl,

    /// Receiver's username (denormalized)
    String? receiverUsername,

    /// Receiver's photo URL (denormalized)
    String? receiverPhotoUrl,
  }) = _FriendshipModel;

  factory FriendshipModel.fromJson(Map<String, dynamic> json) =>
      _$FriendshipModelFromJson(json);

  /// Creates from a `friendships` row
  /// Whether this friendship is active (accepted)
  bool get isAccepted => status == FriendshipStatus.accepted;

  /// Whether this is a pending request
  bool get isPending => status == FriendshipStatus.pending;

  /// Get the other user's ID given one user's ID
  String getOtherUserId(String currentUserId) {
    return currentUserId == senderId ? receiverId : senderId;
  }

  /// Check if this friendship involves a specific user
  bool involvesUser(String userId) {
    return senderId == userId || receiverId == userId;
  }

  /// Generate document ID from two user IDs (alphabetically sorted for consistency)
  /// The DB assigns a uuid primary key and enforces uniqueness on
  /// (sender_id, receiver_id), so pairs are located by querying both
  /// orderings rather than by reconstructing a composite id.
  @Deprecated('Query by sender/receiver pair instead.')
  static String generateId(String userId1, String userId2) {
    final sorted = [userId1, userId2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  /// Payload for inserting a row in `friendships`.
  /// The sender_*/receiver_* display fields come from profile joins on read.
  Map<String, dynamic> toDbMap() {
    return {
      'sender_id': senderId,
      'receiver_id': receiverId,
      'status': status.name,
    };
  }
}

/// A simplified friend info model for displaying friend lists
@freezed
class FriendInfo with _$FriendInfo {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory FriendInfo({
    required String userId,
    required String username,
    String? photoUrl,
    DateTime? friendsSince,
  }) = _FriendInfo;

  factory FriendInfo.fromJson(Map<String, dynamic> json) =>
      _$FriendInfoFromJson(json);
}
