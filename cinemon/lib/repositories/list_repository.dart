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
            'watched_at': watched ? DateTime.now().toUtc().toIso8601String() : null,
          })
          .eq('list_id', listId)
          .eq('film_id', filmId)
          .eq('media_type', mediaType);

  Future<void> setVisibility(String listId, ListVisibility visibility) =>
      _lists.update({'visibility': visibility.name}).eq('id', listId);
}
