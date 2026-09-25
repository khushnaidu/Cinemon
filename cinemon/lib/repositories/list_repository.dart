import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_config.dart';
import '../models/film_model.dart';
import '../models/list_model.dart';

/// Lists and their items (migration 008). Visibility, ownership, counters,
/// the watchlist's existence and striking-off-on-log all live in the
/// database; this is reads and plain writes.
class ListRepository {
  ListRepository({SupabaseClient? client})
      : _client = client ?? SupabaseConfig.client;

  final SupabaseClient _client;

  SupabaseQueryBuilder get _lists => _client.from('lists');
  SupabaseQueryBuilder get _items => _client.from('list_items');

  /// Someone's watchlist, or null if you aren't allowed to see it.
  Future<FilmList?> getWatchlist(String userId) async {
    final row = await _lists
        .select()
        .eq('user_id', userId)
        .eq('kind', 'watchlist')
        .maybeSingle();
    return row == null ? null : FilmList.fromRow(row);
  }

  Future<FilmList?> getList(String listId) async {
    final row = await _lists.select().eq('id', listId).maybeSingle();
    return row == null ? null : FilmList.fromRow(row);
  }

  /// In list order.
  Future<List<ListItem>> getItems(String listId) async {
    final rows = await _items
        .select()
        .eq('list_id', listId)
        .order('position')
        .limit(1000);
    return rows.map(ListItem.fromRow).toList();
  }

  /// Appended at the end; the database picks the position.
  Future<void> addItem(String listId, FilmModel film) => _items.upsert(
        {
          'list_id': listId,
          'film_id': film.id,
          'media_type': film.isTv ? 'tv' : 'movie',
          'film_title': film.displayTitle,
          'film_poster_path': film.posterPath,
          'film_backdrop_path': film.backdropPath,
          'film_year': film.year,
        },
        onConflict: 'list_id,film_id,media_type',
        ignoreDuplicates: true,
      );

  Future<void> removeItem(String listId, int filmId, String mediaType) => _items
      .delete()
      .eq('list_id', listId)
      .eq('film_id', filmId)
      .eq('media_type', mediaType);

  Future<void> setWatched(
    String listId,
    int filmId,
    String mediaType, {
    required bool watched,
  }) =>
      _items
          .update({
            'watched_at':
                watched ? DateTime.now().toUtc().toIso8601String() : null,
          })
          .eq('list_id', listId)
          .eq('film_id', filmId)
          .eq('media_type', mediaType);

  Future<void> setVisibility(String listId, ListVisibility visibility) =>
      _lists.update({'visibility': visibility.name}).eq('id', listId);

  // ── Playlists ───────────────────────────────────────────────

  /// Someone's playlists you're allowed to see, most recently changed first.
  Future<List<FilmList>> getPlaylists(String userId) async {
    final rows = await _lists
        .select()
        .eq('user_id', userId)
        .eq('kind', 'playlist')
        .order('updated_at', ascending: false);
    return rows.map(FilmList.fromRow).toList();
  }

  /// Other people's playlists you've saved, most recently saved first, with
  /// each owner's username. A list you can no longer see (made private, or
  /// its owner blocked you) drops out.
  Future<List<(FilmList, String?)>> getSavedPlaylists(String userId) async {
    final rows = await _client
        .from('list_saves')
        .select('created_at, '
            'list:lists(*, owner:profiles!lists_user_id_fkey(username))')
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return [
      for (final r in rows)
        if (r['list'] != null)
          (
            FilmList.fromRow(r['list'] as Map<String, dynamic>),
            ((r['list'] as Map)['owner'] as Map?)?['username'] as String?,
          ),
    ];
  }

  /// The first six posters of each list, for covers. One query for a whole
  /// rail of lists.
  Future<Map<String, List<String?>>> getCoverPosters(
      List<String> listIds) async {
    if (listIds.isEmpty) return {};
    final rows = await _items
        .select('list_id, film_poster_path, position')
        .inFilter('list_id', listIds)
        .order('position')
        .limit(listIds.length * 60);
    final covers = <String, List<String?>>{};
    for (final r in rows) {
      final posters = covers.putIfAbsent(r['list_id'] as String, () => []);
      if (posters.length < 6) posters.add(r['film_poster_path'] as String?);
    }
    return covers;
  }

  Future<FilmList> createPlaylist({
    required String userId,
    required String title,
    String? description,
    ListVisibility visibility = ListVisibility.public,
    List<ListMood> moods = const [],
  }) async {
    final row = await _lists
        .insert({
          'user_id': userId,
          'kind': 'playlist',
          'title': title,
          'description': description,
          'visibility': visibility.name,
          if (moods.isNotEmpty) 'moods': [for (final m in moods) m.slug],
        })
        .select()
        .single();
    return FilmList.fromRow(row);
  }

  /// [cover] and [moods] are left alone when null, so an edit that doesn't
  /// show them (the Post flow's make-public) can't clear them.
  Future<void> updatePlaylist(
    String listId, {
    required String title,
    String? description,
    required ListVisibility visibility,
    ({ListCoverStyle style, String? path})? cover,
    List<ListMood>? moods,
  }) =>
      _lists.update({
        'title': title,
        'description': description,
        'visibility': visibility.name,
        if (cover != null) ...{
          'cover_style': cover.style.name,
          'cover_path': cover.path,
        },
        if (moods != null) 'moods': [for (final m in moods) m.slug],
      }).eq('id', listId);

  // ── Explore › Lists (migration 029) ─────────────────────────

  /// 35mm Selects, in our order.
  Future<List<ExploreListEntry>> getSelects() async {
    final rows = await _lists
        .select()
        .eq('is_select', true)
        .eq('kind', 'playlist')
        .order('select_rank', nullsFirst: false)
        .order('updated_at', ascending: false)
        .limit(20);
    final lists = rows.map(FilmList.fromRow).toList();
    final covers = await getCoverPosters([for (final l in lists) l.id]);
    return [
      for (final l in lists)
        ExploreListEntry(
          list: l,
          posters: (covers[l.id] ?? const []).whereType<String>().toList(),
        ),
    ];
  }

  /// People's public playlists, best this week first; with [mood], every
  /// list with that mood, Selects included.
  Future<List<ExploreListEntry>> getExploreLists({
    ListMood? mood,
    int limit = 20,
  }) async {
    final rows = await _client.rpc('explore_lists', params: {
      'p_mood': mood?.slug,
      'p_limit': limit,
    }) as List;
    return [
      for (final r in rows) ExploreListEntry.fromRow(r as Map<String, dynamic>)
    ];
  }

  /// How many public playlists have each mood.
  Future<Map<ListMood, int>> getMoodCounts() async {
    final rows = await _client.rpc('explore_mood_counts') as List;
    return {
      for (final r in rows)
        if (ListMood.parse((r as Map)['mood'] as String?) case final m?)
          m: (r['n'] as num).toInt(),
    };
  }

  Future<void> deleteList(String listId) => _lists.delete().eq('id', listId);

  /// Which of [listIds] have this title on them.
  Future<Set<String>> listsContaining(
    List<String> listIds,
    int filmId,
    String mediaType,
  ) async {
    if (listIds.isEmpty) return {};
    final rows = await _items
        .select('list_id')
        .inFilter('list_id', listIds)
        .eq('film_id', filmId)
        .eq('media_type', mediaType);
    return {for (final r in rows) r['list_id'] as String};
  }

  Future<void> setPosition(ListItem item, double position) => _items
      .update({'position': position})
      .eq('list_id', item.listId)
      .eq('film_id', item.filmId)
      .eq('media_type', item.mediaType);

  // ── Saves ───────────────────────────────────────────────────

  Future<bool> isSaved(String listId, String userId) async {
    final row = await _client
        .from('list_saves')
        .select('list_id')
        .eq('list_id', listId)
        .eq('user_id', userId)
        .maybeSingle();
    return row != null;
  }

  Future<void> save(String listId, String userId) =>
      _client.from('list_saves').upsert(
        {'list_id': listId, 'user_id': userId},
        onConflict: 'list_id,user_id',
        ignoreDuplicates: true,
      );

  Future<void> unsave(String listId, String userId) => _client
      .from('list_saves')
      .delete()
      .eq('list_id', listId)
      .eq('user_id', userId);
}
