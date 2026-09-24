import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_config.dart';
import '../models/activity_model.dart';

/// Repository for feed/activity operations.
///
/// Reads go through the `feed_activities` view, which joins the author's
/// current username/photo and aggregates likes + reactions. Writes go to the
/// underlying `activities` table.
class FeedRepository {
  final SupabaseClient _client;

  FeedRepository({SupabaseClient? client})
      : _client = client ?? SupabaseConfig.client;

  static const _view = 'feed_activities';
  static const _table = 'activities';
  static const _mediaBucket = 'review-media';

  // ============ REVIEW MEDIA ============
  //
  // Everything lives at review-media/<uid>/<activity_id>/. The uid has to come
  // first — the storage policy checks that segment against auth.uid() — and
  // the activity id under it means removing a post's media is a prefix delete
  // that can't catch anything else.
  //
  // These upload *before* the row is inserted, which is why the activity id is
  // generated client-side rather than by the database default. The alternative
  // is insert-then-update, which leaves a window where the feed shows a review
  // whose audio isn't there yet.

  /// Upload a spoken review and return its public URL.
  Future<String> uploadVoiceNote({
    required String uid,
    required String activityId,
    required File file,
  }) async {
    final ext = file.path.split('.').last.toLowerCase();
    // Stamped, not a fixed name. Re-recording a review would otherwise write
    // over the old path and leave the CDN serving whatever it cached — the
    // user hears their previous take back and has no way to tell why.
    final path = '$uid/$activityId/voice_${_stamp()}.$ext';

    await _client.storage.from(_mediaBucket).upload(
          path,
          file,
          fileOptions: FileOptions(
            upsert: true,
            contentType: ext == 'm4a' || ext == 'mp4' ? 'audio/mp4' : null,
          ),
        );
    return _client.storage.from(_mediaBucket).getPublicUrl(path);
  }

  /// Upload review photos in order and return their public URLs.
  ///
  /// Sequential rather than concurrent: there are at most four, and a failure
  /// partway through leaves a prefix of uploaded files that the caller can
  /// clean up by activity id, where parallel writes would leave holes.
  Future<List<String>> uploadReviewPhotos({
    required String uid,
    required String activityId,
    required List<File> files,
  }) async {
    final urls = <String>[];
    final stamp = _stamp();
    for (var i = 0; i < files.length; i++) {
      // Stamped for the same reason as the voice note, and because editing can
      // add photos to a post that already has some — a positional name would
      // collide with one that's still there.
      final path = '$uid/$activityId/photo_${stamp}_$i.jpg';
      await _client.storage.from(_mediaBucket).upload(
            path,
            files[i],
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'image/jpeg',
            ),
          );
      urls.add(_client.storage.from(_mediaBucket).getPublicUrl(path));
    }
    return urls;
  }

  static String _stamp() => DateTime.now().millisecondsSinceEpoch.toString();

  /// Remove specific files, addressed by the public URLs we handed out.
  ///
  /// Editing a post replaces some of its media and keeps the rest, so the
  /// prefix delete is too blunt — the only handle the caller has on the ones
  /// being dropped is their URL. Anything that doesn't look like a URL from
  /// this bucket is skipped rather than guessed at.
  Future<void> deleteReviewMediaUrls(List<String> urls) async {
    const marker = '/$_mediaBucket/';
    final paths = <String>[];
    for (final url in urls) {
      final at = url.indexOf(marker);
      if (at == -1) continue;
      // Query strings would make the path not match the stored object.
      final path = url.substring(at + marker.length).split('?').first;
      if (path.isNotEmpty) paths.add(Uri.decodeComponent(path));
    }
    if (paths.isEmpty) return;
    await _client.storage.from(_mediaBucket).remove(paths);
  }

  /// Remove everything stored for one activity.
  ///
  /// Storage has no cascade, so deleting the row leaves the files behind — the
  /// URLs stop being referenced but the bucket keeps paying for them.
  Future<void> deleteReviewMedia({
    required String uid,
    required String activityId,
  }) async {
    final prefix = '$uid/$activityId';
    final files = await _client.storage.from(_mediaBucket).list(path: prefix);
    if (files.isEmpty) return;
    await _client.storage
        .from(_mediaBucket)
        .remove(files.map((f) => '$prefix/${f.name}').toList());
  }

  /// Create a new activity post.
  Future<ActivityModel> createActivity(ActivityModel activity) async {
    final row =
        await _client.from(_table).insert(activity.toDbMap()).select().single();
    // Re-read through the view so the returned model carries username/likes.
    return (await getActivity(row['id'] as String))!;
  }

  /// Get a single activity by id.
  Future<ActivityModel?> getActivity(String activityId) async {
    final row =
        await _client.from(_view).select().eq('id', activityId).maybeSingle();
    return row == null ? null : ActivityModel.fromRow(row);
  }

  /// Home feed: activities from the given users, newest first.
  ///
  /// Pagination is keyset-based on `created_at` — pass the oldest timestamp
  /// you already have as [before]. Unlike offset paging this can't skip or
  /// duplicate rows when new posts land mid-scroll.
  Future<List<ActivityModel>> getFeedActivities({
    required List<String> userIds,
    int limit = 20,
    DateTime? before,
  }) async {
    if (userIds.isEmpty) return [];

    var query = _client.from(_view).select().inFilter('user_id', userIds);
    if (before != null) {
      query = query.lt('created_at', before.toIso8601String());
    }

    final rows = await query.order('created_at', ascending: false).limit(limit);
    return rows.map(ActivityModel.fromRow).toList();
  }

  /// Activities for one user (their profile grid).
  Future<List<ActivityModel>> getUserActivities({
    required String userId,
    int limit = 20,
    DateTime? before,
  }) async {
    var query = _client.from(_view).select().eq('user_id', userId);
    if (before != null) {
      query = query.lt('created_at', before.toIso8601String());
    }

    final rows = await query.order('created_at', ascending: false).limit(limit);
    return rows.map(ActivityModel.fromRow).toList();
  }

  /// Activities for a specific film.
  Future<List<ActivityModel>> getFilmActivities({
    required int filmId,
    int limit = 20,
    DateTime? before,
  }) async {
    var query = _client.from(_view).select().eq('film_id', filmId);
    if (before != null) {
      query = query.lt('created_at', before.toIso8601String());
    }

    final rows = await query.order('created_at', ascending: false).limit(limit);
    return rows.map(ActivityModel.fromRow).toList();
  }

  /// Real-time feed stream.
  ///
  /// Realtime can only subscribe to tables, not views, so this listens to
  /// `activities` and re-reads through the view to hydrate joined fields.
  Stream<List<ActivityModel>> watchFeedActivities({
    required List<String> userIds,
    int limit = 20,
  }) {
    if (userIds.isEmpty) return Stream.value([]);

    return _client
        .from(_table)
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .limit(limit)
        .asyncMap((_) => getFeedActivities(userIds: userIds, limit: limit));
  }

  /// Update an activity.
  Future<void> updateActivity(ActivityModel activity) async {
    // toDbMap carries the id so inserts can mint their own; an update already
    // has it in the filter, and writing a primary key to itself is noise at
    // best.
    final payload = Map<String, dynamic>.from(activity.toDbMap())..remove('id');
    await _client.from(_table).update(payload).eq('id', activity.id);
  }

  /// Delete an activity. Comments, likes and reactions cascade in the DB.
  Future<void> deleteActivity(String activityId) async {
    await _client.from(_table).delete().eq('id', activityId);
  }

  /// Like an activity. Idempotent.
  Future<void> likeActivity({
    required String activityId,
    required String userId,
  }) async {
    await _client.from('activity_likes').upsert(
      {'activity_id': activityId, 'user_id': userId},
      onConflict: 'activity_id,user_id',
    );
  }

  /// Unlike an activity.
  Future<void> unlikeActivity({
    required String activityId,
    required String userId,
  }) async {
    await _client
        .from('activity_likes')
        .delete()
        .eq('activity_id', activityId)
        .eq('user_id', userId);
  }

  /// Add or replace a user's reaction (one sticker per user per activity).
  Future<void> setReaction({
    required String activityId,
    required String userId,
    required String stickerId,
  }) async {
    await _client.from('activity_reactions').upsert(
      {
        'activity_id': activityId,
        'user_id': userId,
        'sticker_id': stickerId,
      },
      onConflict: 'activity_id,user_id',
    );
  }

  /// Remove a user's reaction.
  Future<void> removeReaction({
    required String activityId,
    required String userId,
  }) async {
    await _client
        .from('activity_reactions')
        .delete()
        .eq('activity_id', activityId)
        .eq('user_id', userId);
  }

  /// Add a comment. `comment_count` is maintained by a DB trigger.
  Future<CommentModel> addComment(CommentModel comment) async {
    final row = await _client
        .from('comments')
        .insert(comment.toDbMap())
        .select('*, profiles!inner(username, photo_url)')
        .single();
    return _commentFromRow(row);
  }

  /// Comments for an activity, oldest first.
  Future<List<CommentModel>> getComments({
    required String activityId,
    int limit = 50,
  }) async {
    final rows = await _client
        .from('comments')
        .select('*, profiles!inner(username, photo_url)')
        .eq('activity_id', activityId)
        .order('created_at')
        .limit(limit);

    return rows.map(_commentFromRow).toList();
  }

  /// Delete a comment. `comment_count` is maintained by a DB trigger.
  Future<void> deleteComment({
    required String activityId,
    required String commentId,
  }) async {
    await _client.from('comments').delete().eq('id', commentId);
  }

  /// The user's existing post about a film, if any.
  Future<ActivityModel?> getUserFilmActivity({
    required String userId,
    required int filmId,
  }) async {
    final rows = await _client
        .from(_view)
        .select()
        .eq('user_id', userId)
        .eq('film_id', filmId)
        // Film- or show-level only. Episode posts share the film_id and
        // would otherwise be mistaken for "you've posted about this show".
        .isFilter('season_number', null)
        .order('created_at', ascending: false)
        .limit(1);

    return rows.isEmpty ? null : ActivityModel.fromRow(rows.first);
  }

  /// Every episode post a user has made about one show, newest first.
  Future<List<ActivityModel>> getUserEpisodeActivities({
    required String userId,
    required int showId,
  }) async {
    final rows = await _client
        .from(_view)
        .select()
        .eq('user_id', userId)
        .eq('film_id', showId)
        .not('season_number', 'is', null)
        .order('created_at', ascending: false);
    return rows.map(ActivityModel.fromRow).toList();
  }

  /// Number of reviews a user has posted.
  Future<int> countUserReviews(String userId) async {
    final rows = await _client
        .from(_table)
        .select('id')
        .eq('user_id', userId)
        .eq('activity_type', 'reviewed')
        .count(CountOption.exact);
    return rows.count;
  }

  /// Flattens the nested `profiles` join into the denormalized fields
  /// CommentModel still exposes to the UI.
  CommentModel _commentFromRow(Map<String, dynamic> row) {
    final profile = row['profiles'] as Map<String, dynamic>?;
    return CommentModel.fromJson({
      ...row,
      'username': profile?['username'] ?? 'unknown',
      'user_photo_url': profile?['photo_url'],
    });
  }
}
