import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/friendship_model.dart';
import '../models/user_model.dart';

/// Repository for friendship/mutual follow operations with Firestore.
///
/// Handles sending, accepting, declining friend requests and
/// querying friend relationships.
class FriendshipRepository {
  final FirebaseFirestore _firestore;

  FriendshipRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Collection reference for friendships
  CollectionReference<Map<String, dynamic>> get _friendshipsRef =>
      _firestore.collection('friendships');

  /// Collection reference for users (for denormalization)
  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _firestore.collection('users');

  /// Send a friend request
  Future<FriendshipModel> sendFriendRequest({
    required String senderId,
    required String receiverId,
    String? senderUsername,
    String? senderPhotoUrl,
    String? receiverUsername,
    String? receiverPhotoUrl,
  }) async {
    final id = FriendshipModel.generateId(senderId, receiverId);

    // Check if friendship already exists
    final existing = await _friendshipsRef.doc(id).get();
    if (existing.exists) {
      throw Exception('Friend request already exists');
    }

    final friendship = FriendshipModel(
      id: id,
      senderId: senderId,
      receiverId: receiverId,
      status: FriendshipStatus.pending,
      createdAt: DateTime.now(),
      senderUsername: senderUsername,
      senderPhotoUrl: senderPhotoUrl,
      receiverUsername: receiverUsername,
      receiverPhotoUrl: receiverPhotoUrl,
    );

    await _friendshipsRef.doc(id).set(friendship.toFirestore());
    return friendship;
  }

  /// Accept a friend request
  Future<void> acceptFriendRequest(String friendshipId) async {
    await _friendshipsRef.doc(friendshipId).update({
      'status': FriendshipStatus.accepted.name,
      'acceptedAt': Timestamp.now(),
    });

    // Update follower/following counts for both users
    final doc = await _friendshipsRef.doc(friendshipId).get();
    final data = doc.data()!;
    final senderId = data['senderId'] as String;
    final receiverId = data['receiverId'] as String;

    // Increment counts using batch
    final batch = _firestore.batch();
    batch.update(_usersRef.doc(senderId), {
      'followingCount': FieldValue.increment(1),
      'followerCount': FieldValue.increment(1),
    });
    batch.update(_usersRef.doc(receiverId), {
      'followingCount': FieldValue.increment(1),
      'followerCount': FieldValue.increment(1),
    });
    await batch.commit();
  }

  /// Decline a friend request
  Future<void> declineFriendRequest(String friendshipId) async {
    await _friendshipsRef.doc(friendshipId).update({
      'status': FriendshipStatus.declined.name,
    });
  }

  /// Remove a friendship (unfriend)
  Future<void> removeFriendship({
    required String userId1,
    required String userId2,
  }) async {
    final id = FriendshipModel.generateId(userId1, userId2);

    // Get the friendship first to check it was accepted
    final doc = await _friendshipsRef.doc(id).get();
    if (doc.exists) {
      final data = doc.data()!;
      final wasAccepted = data['status'] == FriendshipStatus.accepted.name;

      await _friendshipsRef.doc(id).delete();

      // Only decrement counts if it was an accepted friendship
      if (wasAccepted) {
        final batch = _firestore.batch();
        batch.update(_usersRef.doc(userId1), {
          'followingCount': FieldValue.increment(-1),
          'followerCount': FieldValue.increment(-1),
        });
        batch.update(_usersRef.doc(userId2), {
          'followingCount': FieldValue.increment(-1),
          'followerCount': FieldValue.increment(-1),
        });
        await batch.commit();
      }
    }
  }

  /// Get friendship status between two users
  Future<FriendshipModel?> getFriendship({
    required String userId1,
    required String userId2,
  }) async {
    final id = FriendshipModel.generateId(userId1, userId2);
    final doc = await _friendshipsRef.doc(id).get();
    if (!doc.exists) return null;
    return FriendshipModel.fromFirestore(doc);
  }

  /// Check if two users are friends (accepted)
  Future<bool> areFriends({
    required String userId1,
    required String userId2,
  }) async {
    final friendship = await getFriendship(
      userId1: userId1,
      userId2: userId2,
    );
    return friendship?.isAccepted ?? false;
  }

  /// Get all accepted friends for a user
  Future<List<String>> getFriendIds(String userId) async {
    // Query where user is sender
    final sentQuery = await _friendshipsRef
        .where('senderId', isEqualTo: userId)
        .where('status', isEqualTo: FriendshipStatus.accepted.name)
        .get();

    // Query where user is receiver
    final receivedQuery = await _friendshipsRef
        .where('receiverId', isEqualTo: userId)
        .where('status', isEqualTo: FriendshipStatus.accepted.name)
        .get();

    final friendIds = <String>{};

    for (final doc in sentQuery.docs) {
      friendIds.add(doc.data()['receiverId'] as String);
    }

    for (final doc in receivedQuery.docs) {
      friendIds.add(doc.data()['senderId'] as String);
    }

    return friendIds.toList();
  }

  /// Get pending friend requests received by a user
  Future<List<FriendshipModel>> getPendingRequests(String userId) async {
    final snapshot = await _friendshipsRef
        .where('receiverId', isEqualTo: userId)
        .where('status', isEqualTo: FriendshipStatus.pending.name)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => FriendshipModel.fromFirestore(doc))
        .toList();
  }

  /// Get pending friend requests sent by a user
  Future<List<FriendshipModel>> getSentRequests(String userId) async {
    final snapshot = await _friendshipsRef
        .where('senderId', isEqualTo: userId)
        .where('status', isEqualTo: FriendshipStatus.pending.name)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => FriendshipModel.fromFirestore(doc))
        .toList();
  }

  /// Stream of pending requests for real-time updates
  Stream<List<FriendshipModel>> watchPendingRequests(String userId) {
    return _friendshipsRef
        .where('receiverId', isEqualTo: userId)
        .where('status', isEqualTo: FriendshipStatus.pending.name)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => FriendshipModel.fromFirestore(doc))
            .toList());
  }

  /// Stream of friend IDs for real-time friend list updates
  Stream<List<String>> watchFriendIds(String userId) {
    // This is a simplified version - in production, you might want to
    // use a different data structure for more efficient querying
    return _friendshipsRef
        .where('status', isEqualTo: FriendshipStatus.accepted.name)
        .snapshots()
        .map((snapshot) {
      final friendIds = <String>{};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final senderId = data['senderId'] as String;
        final receiverId = data['receiverId'] as String;
        if (senderId == userId) {
          friendIds.add(receiverId);
        } else if (receiverId == userId) {
          friendIds.add(senderId);
        }
      }
      return friendIds.toList();
    });
  }

  /// Get friend count for a user
  Future<int> getFriendCount(String userId) async {
    final friendIds = await getFriendIds(userId);
    return friendIds.length;
  }
}
