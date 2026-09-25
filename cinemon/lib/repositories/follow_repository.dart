import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_config.dart';

/// One direction of a follow, as seen from one side.
enum FollowState {
  none,

  /// A request to a private account, waiting.
  requested,
  following,
}

/// You and one other account (ADR 0004 D2): whether you follow them, and
/// whether they follow you. Each is one-way and independent.
class FollowRelation {
  const FollowRelation({required this.outgoing, required this.incoming});

  static const nothing =
      FollowRelation(outgoing: FollowState.none, incoming: FollowState.none);

  /// You → them.
  final FollowState outgoing;

  /// Them → you. [FollowState.requested] means they've asked to follow you.
  final FollowState incoming;

  bool get followsYou => incoming == FollowState.following;
}

/// Someone asking to follow your private account.
class FollowRequest {
  const FollowRequest({
    required this.followerId,
    required this.username,
    required this.createdAt,
    this.photoUrl,
  });

  final String followerId;
  final String username;
  final String? photoUrl;
  final DateTime createdAt;
}

/// One-way follows (migration 017). The server decides whether a new follow
/// is accepted at once (a public account) or a request (a private one), and
/// every read goes through its visibility rules.
class FollowRepository {
  FollowRepository({SupabaseClient? client})
      : _client = client ?? SupabaseConfig.client;

  final SupabaseClient _client;

  SupabaseQueryBuilder get _follows => _client.from('follows');

  /// Follow [them]. Returns the resulting state: following, or requested
  /// when their account is private.
  Future<FollowState> follow({required String me, required String them}) async {
    final row = await _follows
        .upsert(
          {'follower_id': me, 'followee_id': them},
          onConflict: 'follower_id,followee_id',
          ignoreDuplicates: true,
        )
        .select('status')
        .maybeSingle();
    if (row == null) return (await relation(me: me, them: them)).outgoing;
    return row['status'] == 'pending'
        ? FollowState.requested
        : FollowState.following;
  }

  /// Unfollow, or cancel a request.
  Future<void> unfollow({required String me, required String them}) =>
      _follows.delete().eq('follower_id', me).eq('followee_id', them);

  /// Approve a request to follow you.
  Future<void> accept({required String me, required String follower}) =>
      _follows
          .update({'status': 'accepted'})
          .eq('follower_id', follower)
          .eq('followee_id', me);

  /// Decline a request, or remove someone who follows you.
  Future<void> removeFollower({required String me, required String follower}) =>
      _follows.delete().eq('follower_id', follower).eq('followee_id', me);

  Future<FollowRelation> relation({
    required String me,
    required String them,
  }) async {
    final rows = await _follows
        .select('follower_id, status')
        .or('and(follower_id.eq.$me,followee_id.eq.$them),'
            'and(follower_id.eq.$them,followee_id.eq.$me)');
    var outgoing = FollowState.none;
    var incoming = FollowState.none;
    for (final r in rows) {
      final state = r['status'] == 'pending'
          ? FollowState.requested
          : FollowState.following;
      if (r['follower_id'] == me) {
        outgoing = state;
      } else {
        incoming = state;
      }
    }
    return FollowRelation(outgoing: outgoing, incoming: incoming);
  }

  /// Who [userId] follows, accepted only. Rows the viewer can't see (a
  /// private account they don't follow) are left out by the server.
  Future<List<String>> followingIds(String userId) async {
    final rows = await _follows
        .select('followee_id')
        .eq('follower_id', userId)
        .eq('status', 'accepted')
        .order('accepted_at', ascending: false);
    return [for (final r in rows) r['followee_id'] as String];
  }

  /// Who follows [userId], accepted only.
  Future<List<String>> followerIds(String userId) async {
    final rows = await _follows
        .select('follower_id')
        .eq('followee_id', userId)
        .eq('status', 'accepted')
        .order('accepted_at', ascending: false);
    return [for (final r in rows) r['follower_id'] as String];
  }

  /// Requests waiting on your approval, newest first.
  Future<List<FollowRequest>> requests(String me) async {
    final rows = await _follows
        .select('follower_id, created_at, '
            'follower:profiles!follows_follower_id_fkey(username, photo_url)')
        .eq('followee_id', me)
        .eq('status', 'pending')
        .order('created_at', ascending: false);
    return [
      for (final r in rows)
        if (r['follower'] != null)
          FollowRequest(
            followerId: r['follower_id'] as String,
            username: (r['follower'] as Map)['username'] as String,
            photoUrl: (r['follower'] as Map)['photo_url'] as String?,
            createdAt: DateTime.parse(r['created_at'] as String),
          ),
    ];
  }

  /// Live count of requests waiting on you, for the badge.
  Stream<int> watchRequestCount(String me) => _follows
      .stream(primaryKey: ['follower_id', 'followee_id'])
      .eq('followee_id', me)
      .map((rows) => rows.where((r) => r['status'] == 'pending').length);

  /// Whether [userId]'s account is private.
  Future<bool> isPrivate(String userId) async {
    final row = await _client
        .from('profiles')
        .select('is_private')
        .eq('id', userId)
        .maybeSingle();
    return row?['is_private'] as bool? ?? false;
  }

  /// Make your account private or public. Going public accepts every
  /// waiting request (the server does that).
  Future<void> setPrivate({required String me, required bool private}) =>
      _client.from('profiles').update({'is_private': private}).eq('id', me);
}
