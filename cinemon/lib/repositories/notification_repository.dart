import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_config.dart';
import '../models/notification_model.dart';

/// Repository for notification operations.
class NotificationRepository {
  final SupabaseClient _client;

  NotificationRepository({SupabaseClient? client})
      : _client = client ?? SupabaseConfig.client;

  SupabaseQueryBuilder get _notifications => _client.from('notifications');

  /// Row plus the acting user's current username/photo.
  static const _withActor =
      '*, actor:profiles!notifications_actor_id_fkey(username, photo_url)';

  // Notifications are created by database triggers, never from here — see
  // `14. NOTIFICATION TRIGGERS` in schema.sql. A client can't write one
  // anyway: a notification is always for someone else, and the select policy
  // only exposes a row to its recipient, so an insert that reads itself back
  // is rolled back by RLS. This repository is read/dismiss only.

  /// Notifications for a user, newest first.
  ///
  /// [before] is a keyset cursor — pass the oldest `createdAt` you already
  /// hold to fetch the next page.
  Future<List<NotificationModel>> getNotifications({
    required String userId,
    int limit = 50,
    DateTime? before,
  }) async {
    var query =
        _notifications.select(_withActor).eq('recipient_id', userId);
    if (before != null) {
      query = query.lt('created_at', before.toIso8601String());
    }

    final rows = await query.order('created_at', ascending: false).limit(limit);
    return rows.map(NotificationModel.fromRow).toList();
  }

  /// Real-time notification stream.
  ///
  /// `.stream()` cannot express the profile join, so it acts as a change
  /// signal and the full query is re-run to hydrate actor details.
  Stream<List<NotificationModel>> watchNotifications({
    required String userId,
    int limit = 50,
  }) {
    return _client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('recipient_id', userId)
        .asyncMap((_) => getNotifications(userId: userId, limit: limit));
  }

  /// Unread count.
  Future<int> getUnreadCount(String userId) async {
    final res = await _notifications
        .select('id')
        .eq('recipient_id', userId)
        .eq('is_read', false)
        .count(CountOption.exact);
    return res.count;
  }

  /// Real-time unread count, for the badge.
  Stream<int> watchUnreadCount(String userId) {
    return _client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('recipient_id', userId)
        .map((rows) => rows.where((r) => r['is_read'] == false).length);
  }

  /// Mark a notification as read.
  Future<void> markAsRead(String notificationId) async {
    await _notifications.update({'is_read': true}).eq('id', notificationId);
  }

  /// Mark all of a user's notifications as read — one statement, no batching.
  Future<void> markAllAsRead(String userId) async {
    await _notifications
        .update({'is_read': true})
        .eq('recipient_id', userId)
        .eq('is_read', false);
  }

  /// Delete a notification.
  Future<void> deleteNotification(String notificationId) async {
    await _notifications.delete().eq('id', notificationId);
  }

  /// Delete all of a user's notifications.
  Future<void> deleteAllNotifications(String userId) async {
    await _notifications.delete().eq('recipient_id', userId);
  }

  // Retracting a notification on unlike / un-react is likewise the trigger's
  // job: deleting the like row deletes the notification with it.
}
