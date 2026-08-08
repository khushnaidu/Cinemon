import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_config.dart';
import '../models/user_model.dart';

/// Repository for user profile operations against the `profiles` table.
///
/// Handles creating, reading, updating user profiles, avatar uploads,
/// and searching users.
class UserRepository {
  final SupabaseClient _client;

  UserRepository({SupabaseClient? client})
      : _client = client ?? SupabaseConfig.client;

  SupabaseQueryBuilder get _users => _client.from('profiles');

  /// Create a user profile.
  ///
  /// Normally unnecessary — the `on_auth_user_created` trigger inserts the
  /// row at signup. Kept as an upsert for repair/backfill paths.
  Future<void> createUser(UserModel user) async {
    await _users.upsert(user.toDbMap());
  }

  /// Get user profile by id.
  Future<UserModel?> getUser(String uid) async {
    final row = await _users.select().eq('id', uid).maybeSingle();
    return row == null ? null : UserModel.fromJson(row);
  }

  /// Get user profile by username (case-insensitive).
  Future<UserModel?> getUserByUsername(String username) async {
    final row =
        await _users.select().ilike('username', username.trim()).maybeSingle();
    return row == null ? null : UserModel.fromJson(row);
  }

  /// Update user profile.
  Future<void> updateUser(UserModel user) async {
    await _users.update(user.toDbMap()).eq('id', user.uid);
  }

  /// Update specific user fields. Keys must be column names (snake_case).
  Future<void> updateUserFields({
    required String uid,
    required Map<String, dynamic> fields,
  }) async {
    await _users.update(fields).eq('id', uid);
  }

  /// Check if a username is free (case-insensitive).
  Future<bool> isUsernameAvailable(String username) async {
    final trimmed = username.trim();
    if (trimmed.isEmpty) return false;
    final row = await _users.select('id').ilike('username', trimmed).maybeSingle();
    return row == null;
  }

  /// Search users by username prefix.
  Future<List<UserModel>> searchUsers(String query, {int limit = 20}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    // `%` is a LIKE wildcard — escape it so a literal % can't match everything.
    final safe = trimmed.replaceAll('%', r'\%').replaceAll('_', r'\_');
    final rows = await _users
        .select()
        .ilike('username', '$safe%')
        .order('username')
        .limit(limit);

    return rows.map(UserModel.fromJson).toList();
  }

  /// Get multiple users by id.
  ///
  /// No 30-item batching needed here — Postgres `in` has no such limit.
  Future<List<UserModel>> getUsersByIds(List<String> uids) async {
    if (uids.isEmpty) return [];
    final rows = await _users.select().inFilter('id', uids);
    return rows.map(UserModel.fromJson).toList();
  }

  /// Stream a user profile for real-time updates.
  Stream<UserModel?> watchUser(String uid) {
    return _client
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', uid)
        .map((rows) => rows.isEmpty ? null : UserModel.fromJson(rows.first));
  }

  /// Delete user profile.
  Future<void> deleteUser(String uid) async {
    await _users.delete().eq('id', uid);
  }

  // ============ AVATARS ============

  /// Upload a profile photo and return its public URL.
  ///
  /// Stored at `avatars/<uid>/avatar.<ext>` — the storage RLS policy requires
  /// the first path segment to equal the caller's uid.
  Future<String> uploadAvatar(String uid, File file) async {
    final ext = file.path.split('.').last.toLowerCase();
    final path = '$uid/avatar.$ext';

    await _client.storage.from('avatars').upload(
          path,
          file,
          fileOptions: const FileOptions(upsert: true),
        );

    // Bust the CDN cache so a re-upload to the same path actually shows up.
    final url = _client.storage.from('avatars').getPublicUrl(path);
    return '$url?v=${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Remove a user's stored avatars.
  Future<void> deleteAvatar(String uid) async {
    final files = await _client.storage.from('avatars').list(path: uid);
    if (files.isEmpty) return;
    await _client.storage
        .from('avatars')
        .remove(files.map((f) => '$uid/${f.name}').toList());
  }

  // ============ FAVORITE FILMS ============

  /// Add a favorite film (max 4).
  Future<bool> addFavoriteFilm(String uid, int filmId) =>
      _addFavorite(uid, 'favorite_film_ids', filmId);

  /// Remove a favorite film.
  Future<void> removeFavoriteFilm(String uid, int filmId) =>
      _removeFavorite(uid, 'favorite_film_ids', filmId);

  /// Reorder favorite films.
  Future<void> setFavoriteFilms(String uid, List<int> filmIds) =>
      updateUserFields(
          uid: uid, fields: {'favorite_film_ids': filmIds.take(4).toList()});

  // ============ FAVORITE ACTORS ============

  Future<bool> addFavoriteActor(String uid, int personId) =>
      _addFavorite(uid, 'favorite_actor_ids', personId);

  Future<void> removeFavoriteActor(String uid, int personId) =>
      _removeFavorite(uid, 'favorite_actor_ids', personId);

  Future<void> setFavoriteActors(String uid, List<int> personIds) =>
      updateUserFields(
          uid: uid, fields: {'favorite_actor_ids': personIds.take(4).toList()});

  // ============ FAVORITE DIRECTORS ============

  Future<bool> addFavoriteDirector(String uid, int personId) =>
      _addFavorite(uid, 'favorite_director_ids', personId);

  Future<void> removeFavoriteDirector(String uid, int personId) =>
      _removeFavorite(uid, 'favorite_director_ids', personId);

  Future<void> setFavoriteDirectors(String uid, List<int> personIds) =>
      updateUserFields(
          uid: uid,
          fields: {'favorite_director_ids': personIds.take(4).toList()});

  // ============ BADGES ============

  /// Unlock a badge. Returns false if already unlocked.
  Future<bool> unlockBadge(String uid, String badgeId) async {
    final user = await getUser(uid);
    if (user == null || user.badgeIds.contains(badgeId)) return false;
    await updateUserFields(
      uid: uid,
      fields: {
        'badge_ids': [...user.badgeIds, badgeId]
      },
    );
    return true;
  }

  /// Get a user's unlocked badge ids.
  Future<List<String>> getUserBadgeIds(String uid) async =>
      (await getUser(uid))?.badgeIds ?? [];

  // ============ INTERNAL ============

  /// Read-modify-write on an int[] column, capped at 4 entries.
  Future<bool> _addFavorite(String uid, String column, int id) async {
    final row = await _users.select(column).eq('id', uid).maybeSingle();
    if (row == null) return false;

    final current = List<int>.from(row[column] as List? ?? const []);
    if (current.length >= 4 || current.contains(id)) return false;

    current.add(id);
    await updateUserFields(uid: uid, fields: {column: current});
    return true;
  }

  Future<void> _removeFavorite(String uid, String column, int id) async {
    final row = await _users.select(column).eq('id', uid).maybeSingle();
    if (row == null) return;

    final current = List<int>.from(row[column] as List? ?? const [])
      ..remove(id);
    await updateUserFields(uid: uid, fields: {column: current});
  }
}
