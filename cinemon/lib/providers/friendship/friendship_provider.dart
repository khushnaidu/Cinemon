import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/friendship_model.dart';
import '../../repositories/friendship_repository.dart';
import '../auth/auth_provider.dart';

/// Provider for FriendshipRepository singleton
final friendshipRepositoryProvider = Provider<FriendshipRepository>((ref) {
  return FriendshipRepository();
});

/// Provider for current user's friend IDs
final friendIdsProvider = FutureProvider<List<String>>((ref) async {
  final currentUser = ref.watch(currentUserProvider);
  if (currentUser == null) return [];

  final friendshipRepo = ref.watch(friendshipRepositoryProvider);
  return friendshipRepo.getFriendIds(currentUser.uid);
});

/// Stream provider for real-time friend IDs updates
final friendIdsStreamProvider = StreamProvider<List<String>>((ref) {
  final currentUser = ref.watch(currentUserProvider);
  if (currentUser == null) return Stream.value([]);

  final friendshipRepo = ref.watch(friendshipRepositoryProvider);
  return friendshipRepo.watchFriendIds(currentUser.uid);
});

/// Provider for pending friend requests (received)
final pendingRequestsProvider = FutureProvider<List<FriendshipModel>>((ref) async {
  final currentUser = ref.watch(currentUserProvider);
  if (currentUser == null) return [];

  final friendshipRepo = ref.watch(friendshipRepositoryProvider);
  return friendshipRepo.getPendingRequests(currentUser.uid);
});

/// Stream provider for real-time pending requests
final pendingRequestsStreamProvider = StreamProvider<List<FriendshipModel>>((ref) {
  final currentUser = ref.watch(currentUserProvider);
  if (currentUser == null) return Stream.value([]);

  final friendshipRepo = ref.watch(friendshipRepositoryProvider);
  return friendshipRepo.watchPendingRequests(currentUser.uid);
});

/// Provider for sent friend requests
final sentRequestsProvider = FutureProvider<List<FriendshipModel>>((ref) async {
  final currentUser = ref.watch(currentUserProvider);
  if (currentUser == null) return [];

  final friendshipRepo = ref.watch(friendshipRepositoryProvider);
  return friendshipRepo.getSentRequests(currentUser.uid);
});

/// Provider to check friendship status with a specific user
final friendshipStatusProvider =
    FutureProvider.family<FriendshipModel?, String>((ref, otherUserId) async {
  final currentUser = ref.watch(currentUserProvider);
  if (currentUser == null) return null;

  final friendshipRepo = ref.watch(friendshipRepositoryProvider);
  return friendshipRepo.getFriendship(
    userId1: currentUser.uid,
    userId2: otherUserId,
  );
});

/// Provider to check if user is a friend
final isFriendProvider =
    FutureProvider.family<bool, String>((ref, otherUserId) async {
  final currentUser = ref.watch(currentUserProvider);
  if (currentUser == null) return false;

  final friendshipRepo = ref.watch(friendshipRepositoryProvider);
  return friendshipRepo.areFriends(
    userId1: currentUser.uid,
    userId2: otherUserId,
  );
});

/// State notifier for friendship actions
class FriendshipNotifier extends StateNotifier<AsyncValue<void>> {
  final FriendshipRepository _friendshipRepo;
  final Ref _ref;

  FriendshipNotifier(this._friendshipRepo, this._ref)
      : super(const AsyncValue.data(null));

  /// Send a friend request
  Future<void> sendFriendRequest({
    required String receiverId,
    String? senderUsername,
    String? senderPhotoUrl,
    String? receiverUsername,
    String? receiverPhotoUrl,
  }) async {
    final currentUser = _ref.read(currentUserProvider);
    if (currentUser == null) return;

    state = const AsyncValue.loading();

    try {
      await _friendshipRepo.sendFriendRequest(
        senderId: currentUser.uid,
        receiverId: receiverId,
        senderUsername: senderUsername,
        senderPhotoUrl: senderPhotoUrl,
        receiverUsername: receiverUsername,
        receiverPhotoUrl: receiverPhotoUrl,
      );

      // The receiver's "requested to follow you" notification comes from the
      // trigger on `friendships`, which also clears it once they answer.

      state = const AsyncValue.data(null);

      // Refresh sent requests
      _ref.invalidate(sentRequestsProvider);
      _ref.invalidate(friendshipStatusProvider(receiverId));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Accept a friend request
  Future<void> acceptFriendRequest(
    String friendshipId, {
    String? senderId,
    String? senderUsername,
    String? senderPhotoUrl,
    String? receiverUsername,
    String? receiverPhotoUrl,
  }) async {
    state = const AsyncValue.loading();

    try {
      await _friendshipRepo.acceptFriendRequest(friendshipId);

      // The status change to 'accepted' is what notifies the sender — see the
      // trigger on `friendships`.

      state = const AsyncValue.data(null);

      // Refresh all relevant providers
      _ref.invalidate(pendingRequestsProvider);
      _ref.invalidate(friendIdsProvider);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Decline a friend request
  Future<void> declineFriendRequest(String friendshipId) async {
    state = const AsyncValue.loading();

    try {
      await _friendshipRepo.declineFriendRequest(friendshipId);

      state = const AsyncValue.data(null);

      // Refresh pending requests
      _ref.invalidate(pendingRequestsProvider);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Remove a friend
  Future<void> unfriend(String otherUserId) async {
    final currentUser = _ref.read(currentUserProvider);
    if (currentUser == null) return;

    state = const AsyncValue.loading();

    try {
      await _friendshipRepo.removeFriendship(
        userId1: currentUser.uid,
        userId2: otherUserId,
      );

      state = const AsyncValue.data(null);

      // Refresh friend list
      _ref.invalidate(friendIdsProvider);
      _ref.invalidate(friendshipStatusProvider(otherUserId));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

/// Provider for friendship actions
final friendshipNotifierProvider =
    StateNotifierProvider<FriendshipNotifier, AsyncValue<void>>((ref) {
  final friendshipRepo = ref.watch(friendshipRepositoryProvider);
  return FriendshipNotifier(friendshipRepo, ref);
});

/// Provider for friend count
final friendCountProvider = FutureProvider<int>((ref) async {
  final friendIds = await ref.watch(friendIdsProvider.future);
  return friendIds.length;
});

/// Provider for pending request count (for badge)
final pendingRequestCountProvider = FutureProvider<int>((ref) async {
  final requests = await ref.watch(pendingRequestsProvider.future);
  return requests.length;
});
