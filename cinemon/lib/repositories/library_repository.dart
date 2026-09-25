import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_config.dart';
import '../models/film_model.dart';
import '../models/library_entry.dart';

/// The library (migration 024). Reads go through its visibility rules, so a
/// private account's library comes back empty to anyone not following it.
class LibraryRepository {
  LibraryRepository({SupabaseClient? client})
      : _client = client ?? SupabaseConfig.client;

  final SupabaseClient _client;

  SupabaseQueryBuilder get _table => _client.from('library');

  /// Everything in [userId]'s library, most recently added first.
  Future<List<LibraryEntry>> entries(String userId) async {
    final rows = await _table
        .select()
        .eq('user_id', userId)
        .order('added_at', ascending: false)
        .limit(5000);
    return rows.map(LibraryEntry.fromRow).toList();
  }

  /// Keys ('movie:603') of everything in [userId]'s library.
  Future<Set<String>> keys(String userId) async {
    final rows = await _table
        .select('film_id, media_type')
        .eq('user_id', userId)
        .limit(5000);
    return {
      for (final r in rows)
        LibraryEntry.keyFor(r['film_id'] as int, r['media_type'] as String)
    };
  }

  Future<void> add(String userId, FilmModel film) => _table.upsert(
        {
          'user_id': userId,
          'film_id': film.id,
          'media_type': film.isTv ? 'tv' : 'movie',
          'film_title': film.displayTitle,
          'film_poster_path': film.posterPath,
          'film_year': film.year,
        },
        onConflict: 'user_id,film_id,media_type',
        ignoreDuplicates: true,
      );

  Future<void> remove(String userId, int filmId, String mediaType) => _table
      .delete()
      .eq('user_id', userId)
      .eq('film_id', filmId)
      .eq('media_type', mediaType);

  /// How many titles [userId] has in their library.
  Future<int> count(String userId) async {
    final row = await _client
        .from('profiles')
        .select('library_count')
        .eq('id', userId)
        .maybeSingle();
    return row?['library_count'] as int? ?? 0;
  }
}
