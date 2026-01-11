import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

/// Repository for user profile operations with Firestore.
///
/// Handles creating, reading, updating user profiles and searching users.
class UserRepository {
  final FirebaseFirestore _firestore;

  UserRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Collection reference for users
  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _firestore.collection('users');

  /// Create a new user profile
  Future<void> createUser(UserModel user) async {
    await _usersRef.doc(user.uid).set(user.toJson());
  }

  /// Get user profile by UID
  Future<UserModel?> getUser(String uid) async {
    final doc = await _usersRef.doc(uid).get();
    if (!doc.exists) return null;

    final data = doc.data()!;
    // Handle DateTime conversion from Firestore Timestamp
    if (data['createdAt'] is Timestamp) {
      data['createdAt'] = (data['createdAt'] as Timestamp).toDate().toIso8601String();
    }
    return UserModel.fromJson(data);
  }

  /// Get user profile by username
  Future<UserModel?> getUserByUsername(String username) async {
    final snapshot = await _usersRef
        .where('username', isEqualTo: username.toLowerCase())
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;

    final data = snapshot.docs.first.data();
    if (data['createdAt'] is Timestamp) {
      data['createdAt'] = (data['createdAt'] as Timestamp).toDate().toIso8601String();
    }
    return UserModel.fromJson(data);
  }

  /// Update user profile
  Future<void> updateUser(UserModel user) async {
    await _usersRef.doc(user.uid).update(user.toJson());
  }

  /// Update specific user fields
  Future<void> updateUserFields({
    required String uid,
    required Map<String, dynamic> fields,
  }) async {
    await _usersRef.doc(uid).update(fields);
  }

  /// Check if username is available
  Future<bool> isUsernameAvailable(String username) async {
    final snapshot = await _usersRef
        .where('username', isEqualTo: username.toLowerCase())
        .limit(1)
        .get();
    return snapshot.docs.isEmpty;
  }

  /// Search users by username (prefix search)
  Future<List<UserModel>> searchUsers(String query, {int limit = 20}) async {
    if (query.trim().isEmpty) return [];

    final lowercaseQuery = query.toLowerCase();

    // Firestore prefix search using range query
    final snapshot = await _usersRef
        .where('username', isGreaterThanOrEqualTo: lowercaseQuery)
        .where('username', isLessThan: '$lowercaseQuery\uf8ff')
        .limit(limit)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      if (data['createdAt'] is Timestamp) {
        data['createdAt'] = (data['createdAt'] as Timestamp).toDate().toIso8601String();
      }
      return UserModel.fromJson(data);
    }).toList();
  }

  /// Get multiple users by UIDs
  Future<List<UserModel>> getUsersByIds(List<String> uids) async {
    if (uids.isEmpty) return [];

    // Firestore 'whereIn' supports max 30 values
    final results = <UserModel>[];

    // Batch the queries if needed
    for (var i = 0; i < uids.length; i += 30) {
      final batch = uids.skip(i).take(30).toList();
      final snapshot = await _usersRef.where('uid', whereIn: batch).get();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data['createdAt'] is Timestamp) {
          data['createdAt'] = (data['createdAt'] as Timestamp).toDate().toIso8601String();
        }
        results.add(UserModel.fromJson(data));
      }
    }

    return results;
  }

  /// Stream user profile for real-time updates
  Stream<UserModel?> watchUser(String uid) {
    return _usersRef.doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      final data = doc.data()!;
      if (data['createdAt'] is Timestamp) {
        data['createdAt'] = (data['createdAt'] as Timestamp).toDate().toIso8601String();
      }
      return UserModel.fromJson(data);
    });
  }

  /// Increment review count for a user
  Future<void> incrementReviewCount(String uid) async {
    await _usersRef.doc(uid).update({
      'reviewCount': FieldValue.increment(1),
    });
  }

  /// Decrement review count for a user
  Future<void> decrementReviewCount(String uid) async {
    await _usersRef.doc(uid).update({
      'reviewCount': FieldValue.increment(-1),
    });
  }

  /// Delete user profile
  Future<void> deleteUser(String uid) async {
    await _usersRef.doc(uid).delete();
  }

  /// Set the review count directly (for syncing)
  Future<void> setReviewCount(String uid, int count) async {
    await _usersRef.doc(uid).update({
      'reviewCount': count,
    });
  }

  // ============ FAVORITE FILMS ============

  /// Add a favorite film (max 4)
  Future<bool> addFavoriteFilm(String uid, int filmId) async {
    final user = await getUser(uid);
    if (user == null) return false;

    final currentFilms = List<int>.from(user.favoriteFilmIds);
    if (currentFilms.length >= 4 || currentFilms.contains(filmId)) {
      return false;
    }

    currentFilms.add(filmId);
    await _usersRef.doc(uid).update({'favoriteFilmIds': currentFilms});
    return true;
  }

  /// Remove a favorite film
  Future<void> removeFavoriteFilm(String uid, int filmId) async {
    await _usersRef.doc(uid).update({
      'favoriteFilmIds': FieldValue.arrayRemove([filmId]),
    });
  }

  /// Reorder favorite films
  Future<void> setFavoriteFilms(String uid, List<int> filmIds) async {
    // Enforce max 4
    final ids = filmIds.take(4).toList();
    await _usersRef.doc(uid).update({'favoriteFilmIds': ids});
  }

  // ============ FAVORITE ACTORS ============

  /// Add a favorite actor (max 4)
  Future<bool> addFavoriteActor(String uid, int personId) async {
    final user = await getUser(uid);
    if (user == null) return false;

    final currentActors = List<int>.from(user.favoriteActorIds);
    if (currentActors.length >= 4 || currentActors.contains(personId)) {
      return false;
    }

    currentActors.add(personId);
    await _usersRef.doc(uid).update({'favoriteActorIds': currentActors});
    return true;
  }

  /// Remove a favorite actor
  Future<void> removeFavoriteActor(String uid, int personId) async {
    await _usersRef.doc(uid).update({
      'favoriteActorIds': FieldValue.arrayRemove([personId]),
    });
  }

  /// Reorder favorite actors
  Future<void> setFavoriteActors(String uid, List<int> personIds) async {
    final ids = personIds.take(4).toList();
    await _usersRef.doc(uid).update({'favoriteActorIds': ids});
  }

  // ============ FAVORITE DIRECTORS ============

  /// Add a favorite director (max 4)
  Future<bool> addFavoriteDirector(String uid, int personId) async {
    final user = await getUser(uid);
    if (user == null) return false;

    final currentDirectors = List<int>.from(user.favoriteDirectorIds);
    if (currentDirectors.length >= 4 || currentDirectors.contains(personId)) {
      return false;
    }

    currentDirectors.add(personId);
    await _usersRef.doc(uid).update({'favoriteDirectorIds': currentDirectors});
    return true;
  }

  /// Remove a favorite director
  Future<void> removeFavoriteDirector(String uid, int personId) async {
    await _usersRef.doc(uid).update({
      'favoriteDirectorIds': FieldValue.arrayRemove([personId]),
    });
  }

  /// Reorder favorite directors
  Future<void> setFavoriteDirectors(String uid, List<int> personIds) async {
    final ids = personIds.take(4).toList();
    await _usersRef.doc(uid).update({'favoriteDirectorIds': ids});
  }

  // ============ BADGES ============

  /// Unlock a badge for a user
  Future<bool> unlockBadge(String uid, String badgeId) async {
    final user = await getUser(uid);
    if (user == null) return false;

    if (user.badgeIds.contains(badgeId)) {
      return false; // Already unlocked
    }

    await _usersRef.doc(uid).update({
      'badgeIds': FieldValue.arrayUnion([badgeId]),
    });
    return true;
  }

  /// Get user's unlocked badge IDs
  Future<List<String>> getUserBadgeIds(String uid) async {
    final user = await getUser(uid);
    return user?.badgeIds ?? [];
  }
}
