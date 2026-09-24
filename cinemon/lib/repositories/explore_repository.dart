import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_config.dart';
import '../models/activity_model.dart' show CommentModel;
import '../models/explore_post_model.dart';

/// How the Explore feed is ordered.
enum ExploreSort { latest, top }

/// Reads and writes for Explore — public posts from everyone.
///
/// Reads go through the `explore_feed` view (author joined, viewer's vote
/// attached); writes go to the tables underneath. Counts are trigger-kept.
class ExploreRepository {
  ExploreRepository({SupabaseClient? client})
      : _client = client ?? SupabaseConfig.client;

  final SupabaseClient _client;

  static const _view = 'explore_feed';
  static const _table = 'explore_posts';

  /// One page of the feed.
  ///
  /// [filmId] + [mediaType] narrow it to posts about one title — episodes of
  /// a show included, since that's what someone searching a show wants.
  /// [userId] narrows it to one author, for their profile.
  Future<List<ExplorePost>> getFeed({
    ExploreKind? kind,
    String? userId,
    int? filmId,
    String? mediaType,
    ExploreSort sort = ExploreSort.latest,
    int offset = 0,
    int limit = 20,
  }) async {
    var query = _client.from(_view).select();
    if (kind != null) query = query.eq('kind', kind.value);
    if (userId != null) query = query.eq('user_id', userId);
    if (filmId != null) {
      query = query.eq('film_id', filmId);
      if (mediaType != null) query = query.eq('media_type', mediaType);
    }

    final ordered = sort == ExploreSort.top
        // "Top" is the last month's most engaged, not all-time: an all-time
        // board freezes the day a handful of posts pull ahead.
        ? query
            .gte(
              'created_at',
              DateTime.now()
                  .toUtc()
                  .subtract(const Duration(days: 30))
                  .toIso8601String(),
            )
            .order('agree_count', ascending: false)
            .order('comment_count', ascending: false)
            .order('created_at', ascending: false)
        : query.order('created_at', ascending: false);

    final rows = await ordered.range(offset, offset + limit - 1);
    return rows.map(ExplorePost.fromRow).toList();
  }

  Future<ExplorePost?> getPost(String id) async {
    final row = await _client.from(_view).select().eq('id', id).maybeSingle();
    return row == null ? null : ExplorePost.fromRow(row);
  }

  /// Posts by id, in no particular order. Missing ids are posts the viewer
  /// can't see (reported, or a list that's gone private).
  Future<List<ExplorePost>> getPostsByIds(List<String> ids) async {
    if (ids.isEmpty) return const [];
    final rows = await _client.from(_view).select().inFilter('id', ids);
    return rows.map(ExplorePost.fromRow).toList();
  }

  /// How many times a playlist has been posted. The database allows three.
  Future<int> countListPosts(String listId) async {
    final res = await _client
        .from(_table)
        .select('id')
        .eq('list_id', listId)
        .count(CountOption.exact);
    return res.count;
  }

  /// How many posts there are about one title, for the filter banner.
  Future<int> countForSubject({
    required int filmId,
    required String mediaType,
  }) async {
    final res = await _client
        .from(_table)
        .select('id')
        .eq('film_id', filmId)
        .eq('media_type', mediaType)
        .count(CountOption.exact);
    return res.count;
  }

  Future<ExplorePost> createPost({
    required String userId,
    required ExploreKind kind,
    required String body,
    String? headline,
    double? rating,
    bool hasSpoilers = false,
    ExploreSubject? subject,
    String? listId,
  }) async {
    final row = await _client
        .from(_table)
        .insert({
          'user_id': userId,
          'kind': kind.value,
          'body': body,
          'headline': headline,
          'rating': rating,
          'has_spoilers': hasSpoilers,
          ...?subject?.toDbMap(),
          if (listId != null) 'list_id': listId,
        })
        .select('id')
        .single();
    return (await getPost(row['id'] as String))!;
  }

  /// Rewrite a post's content. The kind is fixed once posted (a trigger
  /// enforces it), and `updated_at` is stamped server-side.
  Future<ExplorePost> updatePost({
    required String id,
    required String body,
    String? headline,
    double? rating,
    bool hasSpoilers = false,
    ExploreSubject? subject,
  }) async {
    await _client.from(_table).update({
      'body': body,
      'headline': headline,
      'rating': rating,
      'has_spoilers': hasSpoilers,
      ...(subject?.toDbMap() ?? ExploreSubject.emptyDbMap),
    }).eq('id', id);
    return (await getPost(id))!;
  }

  Future<void> deletePost(String id) async {
    await _client.from(_table).delete().eq('id', id);
  }

  /// Set the viewer's vote. 0 clears it.
  Future<void> vote({
    required String postId,
    required String userId,
    required int value,
  }) async {
    if (value == 0) {
      await _client
          .from('explore_post_votes')
          .delete()
          .eq('post_id', postId)
          .eq('user_id', userId);
      return;
    }
    await _client.from('explore_post_votes').upsert(
      {'post_id': postId, 'user_id': userId, 'value': value},
      onConflict: 'post_id,user_id',
    );
  }

  // ── Comments ────────────────────────────────────────────────
  // Returned as CommentModel so the comment rows and composer are shared with
  // the home feed's threads. `activityId` carries the post id.

  Future<List<CommentModel>> getComments(String postId) async {
    final rows = await _client
        .from('explore_comments')
        .select('*, profiles!inner(username, photo_url)')
        .eq('post_id', postId)
        .order('created_at')
        .limit(200);
    return rows.map(_commentFromRow).toList();
  }

  Future<CommentModel> addComment({
    required String postId,
    required String userId,
    required String content,
    String? parentId,
  }) async {
    final row = await _client
        .from('explore_comments')
        .insert({
          'post_id': postId,
          'user_id': userId,
          'content': content,
          if (parentId != null) 'parent_id': parentId,
        })
        .select('*, profiles!inner(username, photo_url)')
        .single();
    return _commentFromRow(row);
  }

  Future<void> deleteComment(String commentId) async {
    await _client.from('explore_comments').delete().eq('id', commentId);
  }

  // ── Reports ─────────────────────────────────────────────────

  Future<void> reportPost({
    required String postId,
    required String reporterId,
    required String reason,
  }) async {
    await _client.from('content_reports').upsert(
      {'post_id': postId, 'reporter_id': reporterId, 'reason': reason},
      onConflict: 'reporter_id,post_id',
      // Reporting twice is not an error from the reporter's side.
      ignoreDuplicates: true,
    );
  }

  CommentModel _commentFromRow(Map<String, dynamic> row) {
    final profile = row['profiles'] as Map<String, dynamic>?;
    return CommentModel.fromJson({
      ...row,
      'activity_id': row['post_id'],
      'username': profile?['username'] ?? 'unknown',
      'user_photo_url': profile?['photo_url'],
    });
  }
}
