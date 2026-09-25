import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/user_model.dart';
import '../../repositories/follow_repository.dart';
import '../auth/auth_provider.dart';
import '../explore/explore_provider.dart' show userExploreFeedProvider;
import '../feed/feed_provider.dart';

export '../../repositories/follow_repository.dart'
    show FollowState, FollowRelation, FollowRequest;

final followRepositoryProvider =
    Provider<FollowRepository>((ref) => FollowRepository());

/// Everyone you follow (accepted). Home rebuilds when it changes.
final followingIdsProvider = FutureProvider<List<String>>((ref) async {
  final me = ref.watch(currentUserProvider);
  if (me == null) return [];
  return ref.watch(followRepositoryProvider).followingIds(me.id);
});

/// You and [otherUserId]: who follows whom.
final followRelationProvider = FutureProvider.autoDispose
    .family<FollowRelation, String>((ref, other) async {
  final me = ref.watch(currentUserProvider);
  if (me == null || me.id == other) return FollowRelation.nothing;
  return ref.watch(followRepositoryProvider).relation(me: me.id, them: other);
});

/// Whether an account is private. Separate from the profile model so the
/// generated model doesn't need rebuilding.
final isPrivateProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, userId) {
  return ref.watch(followRepositoryProvider).isPrivate(userId);
});

/// Requests waiting on your approval.
final followRequestsProvider =
    FutureProvider.autoDispose<List<FollowRequest>>((ref) async {
  final me = ref.watch(currentUserProvider);
  if (me == null) return [];
  return ref.watch(followRepositoryProvider).requests(me.id);
});

/// Live count of those, for the badge on Notifications.
final followRequestCountProvider = StreamProvider<int>((ref) {
  final me = ref.watch(currentUserProvider);
  if (me == null) return Stream.value(0);
  return ref.watch(followRepositoryProvider).watchRequestCount(me.id);
});

/// Someone's followers or following, as profiles.
enum FollowListKind { followers, following }

final followListProvider = FutureProvider.autoDispose
    .family<List<UserModel>, ({String userId, FollowListKind kind})>(
        (ref, p) async {
  final repo = ref.watch(followRepositoryProvider);
  final ids = p.kind == FollowListKind.followers
      ? await repo.followerIds(p.userId)
      : await repo.followingIds(p.userId);
  if (ids.isEmpty) return [];
  final users = await ref.watch(userRepositoryProvider).getUsersByIds(ids);
  final byId = {for (final u in users) u.uid: u};
  // In follow order, newest first; anyone the server hid is simply absent.
  return [
    for (final id in ids)
      if (byId[id] != null) byId[id]!
  ];
});

/// Follow, unfollow, accept, decline, remove, go private. Each one refreshes
/// what it changes: the relation, both profiles' counts, Home, and the
/// lists and requests.
class FollowActions {
  FollowActions(this._ref);

  final Ref _ref;

  FollowRepository get _repo => _ref.read(followRepositoryProvider);
  String? get _me => _ref.read(currentUserProvider)?.id;

  /// Returns the new state, or null if it failed.
  Future<FollowState?> follow(String them) async {
    final me = _me;
    if (me == null) return null;
    try {
      final state = await _repo.follow(me: me, them: them);
      _refresh(them);
      return state;
    } catch (_) {
      return null;
    }
  }

  Future<bool> unfollow(String them) => _run(them, (me) {
        return _repo.unfollow(me: me, them: them);
      });

  Future<bool> accept(String follower) => _run(follower, (me) {
        return _repo.accept(me: me, follower: follower);
      });

  /// Decline a request or remove a follower.
  Future<bool> removeFollower(String follower) => _run(follower, (me) {
        return _repo.removeFollower(me: me, follower: follower);
      });

  Future<bool> setPrivate(bool private) async {
    final me = _me;
    if (me == null) return false;
    try {
      await _repo.setPrivate(me: me, private: private);
    } catch (_) {
      return false;
    }
    _ref.invalidate(isPrivateProvider(me));
    // Going public accepts every waiting request.
    _ref.invalidate(followRequestsProvider);
    _ref.invalidate(currentUserProfileProvider);
    _ref.invalidate(followListProvider);
    return true;
  }

  Future<bool> _run(String other, Future<void> Function(String me) op) async {
    final me = _me;
    if (me == null) return false;
    try {
      await op(me);
    } catch (_) {
      return false;
    }
    _refresh(other);
    return true;
  }

  void _refresh(String other) {
    _ref.invalidate(followRelationProvider(other));
    _ref.invalidate(followingIdsProvider);
    _ref.invalidate(followRequestsProvider);
    _ref.invalidate(followListProvider);
    _ref.invalidate(currentUserProfileProvider);
    _ref.invalidate(userProfileProvider(other));
    // Their posts appear or disappear with access.
    _ref.invalidate(userActivitiesProvider(other));
    _ref.invalidate(userExploreFeedProvider);
    _ref.invalidate(homeFeedProvider);
  }
}

final followActionsProvider =
    Provider<FollowActions>((ref) => FollowActions(ref));
