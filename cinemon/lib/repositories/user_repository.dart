import '../core/utils/image_check.dart';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_config.dart';
import '../models/badge_model.dart';
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
  ///
  /// Through `username_available()` (migration 015), which also sees accounts
  /// hidden from you by a block, and counts your own current name as free.
  Future<bool> isUsernameAvailable(String username) async {
    final trimmed = username.trim();
    if (trimmed.isEmpty) return false;
    return await _client.rpc('username_available', params: {'name': trimmed})
        as bool;
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

  // ============ ACCOUNT DELETION ============

  /// Delete the signed-in account and everything it owns.
  ///
  /// Storage goes first because it has no cascade and can't be cleared from
  /// SQL. If it fails, nothing else has been touched and the whole thing can
  /// be retried. `delete_my_account` (migration 006) then deletes the auth
  /// user, which cascades through `profiles` to every row the account owns.
  /// The caller signs out afterwards.
  Future<void> deleteAccount(String uid) async {
    await _removeFolder('avatars', uid);
    await _removeFolder('review-media', uid);
    await _client.rpc('delete_my_account');
  }

  /// Remove every object under [prefix], descending into folders.
  /// `list` isn't recursive, and it returns folders as entries with no id.
  Future<void> _removeFolder(String bucket, String prefix) async {
    const page = 1000;
    final files = <String>[];
    for (var offset = 0;; offset += page) {
      final entries = await _client.storage.from(bucket).list(
            path: prefix,
            searchOptions: SearchOptions(limit: page, offset: offset),
          );
      for (final e in entries) {
        final path = '$prefix/${e.name}';
        if (e.id == null) {
          await _removeFolder(bucket, path);
        } else {
          files.add(path);
        }
      }
      if (entries.length < page) break;
    }
    if (files.isNotEmpty) {
      await _client.storage.from(bucket).remove(files);
    }
  }

  // ============ AVATARS ============

  /// Upload a profile photo and return its public URL.
  ///
  /// Stored at `avatars/<uid>/avatar_<stamp>.<ext>` — the storage RLS policy
  /// requires the first path segment to equal the caller's uid. A new name
  /// each time, so the photo check (migration 022) sees every photo as new.
  ///
  /// Throws [ImageRejected] if the photo check refuses it.
  Future<String> uploadAvatar(String uid, File file) async {
    final ext = file.path.split('.').last.toLowerCase();
    final path = '$uid/avatar_${DateTime.now().millisecondsSinceEpoch}.$ext';

    await _client.storage.from('avatars').upload(
          path,
          file,
          fileOptions: const FileOptions(upsert: true),
        );

    await checkUploadedImage(_client, 'avatars', path);
    // Earlier photos go, now that this one is in.
    try {
      final files = await _client.storage.from('avatars').list(path: uid);
      final old = [
        for (final f in files)
          if ('$uid/${f.name}' != path) '$uid/${f.name}'
      ];
      if (old.isNotEmpty) await _client.storage.from('avatars').remove(old);
    } catch (_) {}
    return _client.storage.from('avatars').getPublicUrl(path);
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

  // ============ FAVORITE SHOWS ============

  /// Replace the ranked top-3 shows.
  Future<void> setFavoriteShows(String uid, List<int> showIds) =>
      updateUserFields(
          uid: uid, fields: {'favorite_show_ids': showIds.take(3).toList()});

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

  // The database awards badges (migration 009); the app only reads them.

  /// Everything [uid] has earned, newest first.
  Future<List<EarnedBadge>> getEarnedBadges(String uid) async {
    final rows = await _client
        .from('user_badges')
        .select('badge_id, earned_at')
        .eq('user_id', uid)
        .order('earned_at', ascending: false);
    return rows.map(EarnedBadge.fromRow).toList();
  }

  /// The signed-in user's counts toward badges they haven't earned yet:
  /// reviews, per-genre reviews, top playlist saves, watchlist strikes.
  Future<Map<String, int>> getMyBadgeProgress() async {
    final res = await _client.rpc('my_badge_progress');
    return {
      for (final e in (res as Map<String, dynamic>).entries)
        e.key: (e.value as num).toInt(),
    };
  }

  static bool _reportedTimeZone = false;

  /// Tell the server this device's UTC offset, once per launch, so Night Owl
  /// and Binge Watcher go by the poster's own clock.
  Future<void> reportTimeZone(String uid) async {
    if (_reportedTimeZone) return;
    _reportedTimeZone = true;
    final offset = DateTime.now().timeZoneOffset;
    final minutes = offset.inMinutes.abs();
    final zone = '${offset.isNegative ? '-' : '+'}'
        '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
        '${(minutes % 60).toString().padLeft(2, '0')}';
    try {
      await updateUserFields(uid: uid, fields: {'time_zone': zone});
    } catch (_) {
      // Before migration 009 there's no column; badges fall back to UTC.
      _reportedTimeZone = false;
    }
  }

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
