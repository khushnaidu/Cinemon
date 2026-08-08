import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_config.dart';
import '../models/friendship_model.dart';

/// Repository for friendship / mutual-follow operations.
///
/// Friendship is mutual and direction-agnostic once accepted: a row where
/// you are the sender means the same thing as one where you are the receiver.
/// Every pair lookup therefore checks both orderings.
class FriendshipRepository {
  final SupabaseClient _client;

  FriendshipRepository({SupabaseClient? client})
      : _client = client ?? SupabaseConfig.client;

  SupabaseQueryBuilder get _friendships => _client.from('friendships');

  /// Selects the row plus both participants' display info. The `!fk` hints are
  /// required because `friendships` has two foreign keys into `profiles`, so
  /// PostgREST cannot infer which one each alias refers to.
  static const _withProfiles = '*, '
      'sender:profiles!friendships_sender_id_fkey(username, photo_url), '
      'receiver:profiles!friendships_receiver_id_fkey(username, photo_url)';

  /// Send a friend request.
  ///
  /// Throws if a request already exists in either direction.
  Future<FriendshipModel> sendFriendRequest({
    required String senderId,
    required String receiverId,
    String? senderUsername,
    String? senderPhotoUrl,
    String? receiverUsername,
    String? receiverPhotoUrl,
  }) async {
    final existing = await getFriendship(userId1: senderId, userId2: receiverId);
    if (existing != null) {
      throw Exception('Friend request already exists');
    }

    final row = await _friendships.insert({
      'sender_id': senderId,
      'receiver_id': receiverId,
      'status': FriendshipStatus.pending.name,
    }).select(_withProfiles).single();

    return _fromRow(row);
  }

  /// Accept a friend request. Follower/following counts are trigger-maintained.
  Future<void> acceptFriendRequest(String friendshipId) async {
    await _friendships.update({
      'status': FriendshipStatus.accepted.name,
      'accepted_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', friendshipId);
  }

  /// Decline a friend request.
  Future<void> declineFriendRequest(String friendshipId) async {
    await _friendships
        .update({'status': FriendshipStatus.declined.name})
        .eq('id', friendshipId);
  }

  /// Remove a friendship (unfriend), whichever direction it was created in.
  Future<void> removeFriendship({
    required String userId1,
    required String userId2,
  }) async {
    await _friendships.delete().or(
          'and(sender_id.eq.$userId1,receiver_id.eq.$userId2),'
          'and(sender_id.eq.$userId2,receiver_id.eq.$userId1)',
        );
  }

  /// The friendship row between two users, in either direction.
  Future<FriendshipModel?> getFriendship({
    required String userId1,
    required String userId2,
  }) async {
    final rows = await _friendships
        .select(_withProfiles)
        .or('and(sender_id.eq.$userId1,receiver_id.eq.$userId2),'
            'and(sender_id.eq.$userId2,receiver_id.eq.$userId1)')
        .limit(1);

    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  /// Whether two users are accepted friends.
  Future<bool> areFriends({
    required String userId1,
    required String userId2,
  }) async {
    final friendship = await getFriendship(userId1: userId1, userId2: userId2);
    return friendship?.isAccepted ?? false;
  }

  /// Ids of all accepted friends for a user.
  Future<List<String>> getFriendIds(String userId) async {
    final rows = await _friendships
        .select('sender_id, receiver_id')
        .eq('status', FriendshipStatus.accepted.name)
        .or('sender_id.eq.$userId,receiver_id.eq.$userId');

    return rows
        .map((r) => r['sender_id'] == userId
            ? r['receiver_id'] as String
            : r['sender_id'] as String)
        .toSet()
        .toList();
  }

  /// Pending requests received by a user.
  Future<List<FriendshipModel>> getPendingRequests(String userId) async {
    final rows = await _friendships
        .select(_withProfiles)
        .eq('receiver_id', userId)
        .eq('status', FriendshipStatus.pending.name)
        .order('created_at', ascending: false);

    return rows.map(_fromRow).toList();
  }

  /// Pending requests sent by a user.
  Future<List<FriendshipModel>> getSentRequests(String userId) async {
    final rows = await _friendships
        .select(_withProfiles)
        .eq('sender_id', userId)
        .eq('status', FriendshipStatus.pending.name)
        .order('created_at', ascending: false);

    return rows.map(_fromRow).toList();
  }

  /// Real-time stream of pending requests.
  ///
  /// `.stream()` cannot express the status filter or the profile joins, so it
  /// is used purely as a change signal and the full query is re-run.
  Stream<List<FriendshipModel>> watchPendingRequests(String userId) {
    return _client
        .from('friendships')
        .stream(primaryKey: ['id'])
        .eq('receiver_id', userId)
        .asyncMap((_) => getPendingRequests(userId));
  }

  /// Real-time stream of accepted friend ids.
  Stream<List<String>> watchFriendIds(String userId) {
    return _client
        .from('friendships')
        .stream(primaryKey: ['id'])
        .asyncMap((_) => getFriendIds(userId));
  }

  /// Number of accepted friends.
  Future<int> getFriendCount(String userId) async =>
      (await getFriendIds(userId)).length;

  /// Flattens the nested sender/receiver joins into the denormalized fields
  /// FriendshipModel exposes to the UI.
  FriendshipModel _fromRow(Map<String, dynamic> row) {
    final sender = row['sender'] as Map<String, dynamic>?;
    final receiver = row['receiver'] as Map<String, dynamic>?;
    return FriendshipModel.fromJson({
      ...row,
      'sender_username': sender?['username'],
      'sender_photo_url': sender?['photo_url'],
      'receiver_username': receiver?['username'],
      'receiver_photo_url': receiver?['photo_url'],
    }..remove('sender')
      ..remove('receiver'));
  }
}
