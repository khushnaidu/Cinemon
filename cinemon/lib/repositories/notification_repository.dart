import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_model.dart';

/// Repository for notification operations with Firestore.
///
/// Handles creating, reading, and updating notifications.
class NotificationRepository {
  final FirebaseFirestore _firestore;

  NotificationRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Collection reference for notifications
  CollectionReference<Map<String, dynamic>> get _notificationsRef =>
      _firestore.collection('notifications');

  /// Create a new notification
  Future<NotificationModel> createNotification(NotificationModel notification) async {
    final docRef = await _notificationsRef.add(notification.toFirestore());
    return notification.copyWith(id: docRef.id);
  }

  /// Get notifications for a user
  Future<List<NotificationModel>> getNotifications({
    required String userId,
    int limit = 50,
    DocumentSnapshot? startAfter,
  }) async {
    Query<Map<String, dynamic>> query = _notificationsRef
        .where('recipientId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snapshot = await query.get();
    return snapshot.docs.map((doc) => NotificationModel.fromFirestore(doc)).toList();
  }

  /// Stream notifications for real-time updates
  Stream<List<NotificationModel>> watchNotifications({
    required String userId,
    int limit = 50,
  }) {
    return _notificationsRef
        .where('recipientId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => NotificationModel.fromFirestore(doc)).toList());
  }

  /// Get unread notification count
  Future<int> getUnreadCount(String userId) async {
    final snapshot = await _notificationsRef
        .where('recipientId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();

    return snapshot.docs.length;
  }

  /// Stream unread notification count for real-time badge
  Stream<int> watchUnreadCount(String userId) {
    return _notificationsRef
        .where('recipientId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Mark a notification as read
  Future<void> markAsRead(String notificationId) async {
    await _notificationsRef.doc(notificationId).update({'isRead': true});
  }

  /// Mark all notifications as read for a user
  Future<void> markAllAsRead(String userId) async {
    final snapshot = await _notificationsRef
        .where('recipientId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();

    if (snapshot.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  /// Delete a notification
  Future<void> deleteNotification(String notificationId) async {
    await _notificationsRef.doc(notificationId).delete();
  }

  /// Delete all notifications for a user
  Future<void> deleteAllNotifications(String userId) async {
    final snapshot = await _notificationsRef
        .where('recipientId', isEqualTo: userId)
        .get();

    if (snapshot.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  /// Check if a notification already exists (to prevent duplicates)
  /// Used when user rapidly likes/unlikes
  Future<bool> notificationExists({
    required String recipientId,
    required String actorId,
    required NotificationType type,
    String? activityId,
  }) async {
    Query<Map<String, dynamic>> query = _notificationsRef
        .where('recipientId', isEqualTo: recipientId)
        .where('actorId', isEqualTo: actorId)
        .where('type', isEqualTo: type.name);

    if (activityId != null) {
      query = query.where('activityId', isEqualTo: activityId);
    }

    final snapshot = await query.limit(1).get();
    return snapshot.docs.isNotEmpty;
  }

  /// Delete a specific notification (for unlike/unreact scenarios)
  Future<void> deleteNotificationByDetails({
    required String recipientId,
    required String actorId,
    required NotificationType type,
    String? activityId,
  }) async {
    Query<Map<String, dynamic>> query = _notificationsRef
        .where('recipientId', isEqualTo: recipientId)
        .where('actorId', isEqualTo: actorId)
        .where('type', isEqualTo: type.name);

    if (activityId != null) {
      query = query.where('activityId', isEqualTo: activityId);
    }

    final snapshot = await query.get();
    for (final doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }
}
