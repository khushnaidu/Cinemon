import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/notification_model.dart';
import '../../repositories/notification_repository.dart';
import '../auth/auth_provider.dart';

/// Provider for NotificationRepository singleton
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository();
});

/// Provider for user's notifications list
final notificationsProvider = FutureProvider<List<NotificationModel>>((ref) async {
  final currentUser = ref.watch(currentUserProvider);
  if (currentUser == null) return [];

  final notificationRepo = ref.watch(notificationRepositoryProvider);
  return notificationRepo.getNotifications(userId: currentUser.uid);
});

/// Stream provider for real-time notification updates
final notificationsStreamProvider = StreamProvider<List<NotificationModel>>((ref) {
  final currentUser = ref.watch(currentUserProvider);
  if (currentUser == null) return Stream.value([]);

  final notificationRepo = ref.watch(notificationRepositoryProvider);
  return notificationRepo.watchNotifications(userId: currentUser.uid);
});

/// Stream provider for unread notification count (for badge)
final unreadNotificationCountProvider = StreamProvider<int>((ref) {
  final currentUser = ref.watch(currentUserProvider);
  if (currentUser == null) return Stream.value(0);

  final notificationRepo = ref.watch(notificationRepositoryProvider);
  return notificationRepo.watchUnreadCount(currentUser.uid);
});

/// State notifier for notification actions
class NotificationNotifier extends StateNotifier<AsyncValue<void>> {
  final NotificationRepository _notificationRepo;
  final String? _userId;
  final Ref _ref;

  NotificationNotifier(this._notificationRepo, this._userId, this._ref)
      : super(const AsyncValue.data(null));

  // Creating and retracting notifications is handled by database triggers on
  // activity_likes / activity_reactions / comments / friendships. Liking a
  // post *is* the notification; there is no second call to make here.

  /// Mark a notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _notificationRepo.markAsRead(notificationId);
      _ref.invalidate(notificationsProvider);
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    if (_userId == null) return;

    try {
      await _notificationRepo.markAllAsRead(_userId!);
      _ref.invalidate(notificationsProvider);
    } catch (e) {
      print('Error marking all notifications as read: $e');
    }
  }

  /// Delete a notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _notificationRepo.deleteNotification(notificationId);
      _ref.invalidate(notificationsProvider);
    } catch (e) {
      print('Error deleting notification: $e');
    }
  }

  /// Clear all notifications
  Future<void> clearAllNotifications() async {
    if (_userId == null) return;

    try {
      await _notificationRepo.deleteAllNotifications(_userId!);
      _ref.invalidate(notificationsProvider);
    } catch (e) {
      print('Error clearing notifications: $e');
    }
  }
}

/// Provider for notification actions
final notificationNotifierProvider =
    StateNotifierProvider<NotificationNotifier, AsyncValue<void>>((ref) {
  final notificationRepo = ref.watch(notificationRepositoryProvider);
  final currentUser = ref.watch(currentUserProvider);
  return NotificationNotifier(notificationRepo, currentUser?.uid, ref);
});
