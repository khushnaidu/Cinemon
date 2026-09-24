import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../repositories/block_repository.dart';
import '../auth/auth_provider.dart';
import '../explore/explore_provider.dart';
import '../feed/feed_provider.dart'
    show homeFeedProvider, userProfileProvider, userActivitiesProvider;
import '../friendship/friendship_provider.dart';

final blockRepositoryProvider =
    Provider<BlockRepository>((ref) => BlockRepository());

final blockedAccountsProvider =
    FutureProvider.autoDispose<List<BlockedAccount>>((ref) {
  return ref.watch(blockRepositoryProvider).blockedAccounts();
});

class BlockActions {
  BlockActions(this._ref);

  final Ref _ref;

  BlockRepository get _repo => _ref.read(blockRepositoryProvider);

  /// Returns false if the write failed.
  Future<bool> block(String userId) async {
    final me = _ref.read(currentUserProvider)?.uid;
    if (me == null || me == userId) return false;
    try {
      await _repo.block(blockerId: me, blockedId: userId);
    } catch (_) {
      return false;
    }
    // Their posts leave the loaded Explore page now; everything else is
    // filtered by the server on the next read.
    _ref.read(exploreFeedProvider.notifier).removeAuthor(userId);
    _refresh(userId);
    return true;
  }

  Future<bool> unblock(String userId) async {
    final me = _ref.read(currentUserProvider)?.uid;
    if (me == null) return false;
    try {
      await _repo.unblock(blockerId: me, blockedId: userId);
    } catch (_) {
      return false;
    }
    _ref.invalidate(exploreFeedProvider);
    _refresh(userId);
    return true;
  }

  void _refresh(String userId) {
    _ref.invalidate(blockedAccountsProvider);
    _ref.invalidate(homeFeedProvider);
    _ref.invalidate(friendIdsProvider);
    _ref.invalidate(userProfileProvider(userId));
    _ref.invalidate(userActivitiesProvider(userId));
    _ref.invalidate(friendshipStatusProvider(userId));
  }
}

final blockActionsProvider = Provider<BlockActions>((ref) => BlockActions(ref));
