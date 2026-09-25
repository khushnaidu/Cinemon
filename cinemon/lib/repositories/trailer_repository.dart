import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_config.dart';
import '../models/film_model.dart' show MediaType;
import '../models/person_model.dart';
import '../models/trailer_item.dart';

/// Discover's feeds, and the trending people that come from it. A
/// job in the database keeps both filled from TMDB (migration 013); the app
/// only reads.
class TrailerRepository {
  TrailerRepository({SupabaseClient? client})
      : _client = client ?? SupabaseConfig.client;

  final SupabaseClient _client;

  /// One feed, narrowed to films or shows and maybe a genre. More than a
  /// session's swiping, so the unwatched ones can go first.
  Future<List<TrailerItem>> getFeed(DiscoverQuery q) async {
    var query = _client
        .from('trailer_feed_items')
        .select()
        .eq('feed', q.feed.value)
        .eq('media_type', q.type == MediaType.tv ? 'tv' : 'movie');
    if (q.genre != null) query = query.contains('genre_ids', [q.genre!]);
    final rows = await query.order('rank').limit(150);
    return rows.map(TrailerItem.fromRow).toList();
  }

  /// The leads and directors of this week's trending titles.
  Future<List<PersonModel>> getTrendingPeople() async {
    final rows =
        await _client.from('trending_people').select().order('score').limit(60);
    return [
      for (final r in rows)
        PersonModel(
          id: (r['person_id'] as num).toInt(),
          name: r['name'] as String,
          profilePath: r['profile_path'] as String?,
          knownForDepartment: r['department'] as String?,
        ),
    ];
  }
}
