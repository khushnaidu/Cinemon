import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/activity_model.dart';

/// Repository for feed/activity operations with Firestore.
///
/// Handles creating, reading, updating, and deleting activities (posts).
class FeedRepository {
  final FirebaseFirestore _firestore;

  FeedRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Collection reference for activities
  CollectionReference<Map<String, dynamic>> get _activitiesRef =>
      _firestore.collection('activities');

  /// Collection reference for comments (subcollection)
  CollectionReference<Map<String, dynamic>> _commentsRef(String activityId) =>
      _activitiesRef.doc(activityId).collection('comments');

  /// Create a new activity post
  Future<ActivityModel> createActivity(ActivityModel activity) async {
    final docRef = await _activitiesRef.add(activity.toFirestore());
    return activity.copyWith(id: docRef.id);
  }

  /// Get a single activity by ID
  Future<ActivityModel?> getActivity(String activityId) async {
    final doc = await _activitiesRef.doc(activityId).get();
    if (!doc.exists) return null;
    return ActivityModel.fromFirestore(doc);
  }

  /// Get activities for the home feed (from specific user IDs)
  /// Returns activities from friends, paginated
  Future<List<ActivityModel>> getFeedActivities({
    required List<String> userIds,
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    if (userIds.isEmpty) return [];

    // Firestore 'whereIn' supports max 30 values
    // If more friends, we'd need to batch queries
    final limitedUserIds = userIds.take(30).toList();

    try {
      Query<Map<String, dynamic>> query = _activitiesRef
          .where('userId', whereIn: limitedUserIds)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();
      return snapshot.docs.map((doc) => ActivityModel.fromFirestore(doc)).toList();
    } catch (e) {
      // If composite index doesn't exist, fall back to simple query without ordering
      // This allows the app to work while the index is being created
      print('Firestore composite index needed. Falling back to unordered query: $e');

      final snapshot = await _activitiesRef
          .where('userId', whereIn: limitedUserIds)
          .limit(limit)
          .get();

      final activities = snapshot.docs
          .map((doc) => ActivityModel.fromFirestore(doc))
          .toList();

      // Sort client-side as fallback
      activities.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return activities;
    }
  }

  /// Get activities for a specific user (their profile)
  Future<List<ActivityModel>> getUserActivities({
    required String userId,
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _activitiesRef
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      // Add timeout to prevent indefinite blocking if index is missing
      final snapshot = await query.get().timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Query timeout - index may be building'),
      );
      return snapshot.docs.map((doc) => ActivityModel.fromFirestore(doc)).toList();
    } catch (e) {
      print('getUserActivities error: $e');
      return []; // Return empty on error instead of freezing
    }
  }

  /// Get activities for a specific film
  Future<List<ActivityModel>> getFilmActivities({
    required int filmId,
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _activitiesRef
          .where('filmId', isEqualTo: filmId)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      // Add timeout to prevent indefinite blocking if index is missing
      final snapshot = await query.get().timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Query timeout - index may be building'),
      );
      return snapshot.docs.map((doc) => ActivityModel.fromFirestore(doc)).toList();
    } catch (e) {
      print('getFilmActivities error: $e');
      return []; // Return empty on error
    }
  }

  /// Stream of activities for real-time feed updates
  Stream<List<ActivityModel>> watchFeedActivities({
    required List<String> userIds,
    int limit = 20,
  }) {
    if (userIds.isEmpty) return Stream.value([]);

    final limitedUserIds = userIds.take(30).toList();

    return _activitiesRef
        .where('userId', whereIn: limitedUserIds)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => ActivityModel.fromFirestore(doc)).toList());
  }

  /// Update an activity
  Future<void> updateActivity(ActivityModel activity) async {
    await _activitiesRef.doc(activity.id).update(activity.toFirestore());
  }

  /// Delete an activity
  Future<void> deleteActivity(String activityId) async {
    // Delete all comments first
    final comments = await _commentsRef(activityId).get();
    for (final doc in comments.docs) {
      await doc.reference.delete();
    }
    // Then delete the activity
    await _activitiesRef.doc(activityId).delete();
  }

  /// Like an activity
  Future<void> likeActivity({
    required String activityId,
    required String userId,
  }) async {
    await _activitiesRef.doc(activityId).update({
      'likes': FieldValue.arrayUnion([userId]),
    });
  }

  /// Unlike an activity
  Future<void> unlikeActivity({
    required String activityId,
    required String userId,
  }) async {
    await _activitiesRef.doc(activityId).update({
      'likes': FieldValue.arrayRemove([userId]),
    });
  }

  /// Add or update a reaction on an activity
  /// Each user can only have one reaction per activity
  Future<void> setReaction({
    required String activityId,
    required String userId,
    required String stickerId,
  }) async {
    await _activitiesRef.doc(activityId).update({
      'reactions.$userId': stickerId,
    });
  }

  /// Remove a user's reaction from an activity
  Future<void> removeReaction({
    required String activityId,
    required String userId,
  }) async {
    await _activitiesRef.doc(activityId).update({
      'reactions.$userId': FieldValue.delete(),
    });
  }

  /// Add a comment to an activity
  Future<CommentModel> addComment(CommentModel comment) async {
    final docRef = await _commentsRef(comment.activityId).add(comment.toFirestore());

    // Increment comment count
    await _activitiesRef.doc(comment.activityId).update({
      'commentCount': FieldValue.increment(1),
    });

    return comment.copyWith(id: docRef.id);
  }

  /// Get comments for an activity
  Future<List<CommentModel>> getComments({
    required String activityId,
    int limit = 50,
  }) async {
    final snapshot = await _commentsRef(activityId)
        .orderBy('createdAt', descending: false)
        .limit(limit)
        .get();

    return snapshot.docs.map((doc) => CommentModel.fromFirestore(doc)).toList();
  }

  /// Delete a comment
  Future<void> deleteComment({
    required String activityId,
    required String commentId,
  }) async {
    await _commentsRef(activityId).doc(commentId).delete();

    // Decrement comment count
    await _activitiesRef.doc(activityId).update({
      'commentCount': FieldValue.increment(-1),
    });
  }

  /// Check if user has already posted about a film
  Future<ActivityModel?> getUserFilmActivity({
    required String userId,
    required int filmId,
  }) async {
    try {
      final snapshot = await _activitiesRef
          .where('userId', isEqualTo: userId)
          .where('filmId', isEqualTo: filmId)
          .limit(1)
          .get()
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('Query timeout - index may be building'),
          );

      if (snapshot.docs.isEmpty) return null;
      return ActivityModel.fromFirestore(snapshot.docs.first);
    } catch (e) {
      print('getUserFilmActivity error: $e');
      return null; // Return null on error
    }
  }

  /// Count the number of reviews a user has posted
  Future<int> countUserReviews(String userId) async {
    final snapshot = await _activitiesRef
        .where('userId', isEqualTo: userId)
        .where('activityType', isEqualTo: 'reviewed')
        .get();

    return snapshot.docs.length;
  }
}
