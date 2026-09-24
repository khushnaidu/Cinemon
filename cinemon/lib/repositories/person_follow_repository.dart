import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_config.dart';
import '../models/notification_model.dart';
import '../models/person_follow.dart';

/// Following people (migration 011). The database checks each followed
/// person's credits daily and writes the alerts; the app only follows,
/// unfollows and reads.
class PersonFollowRepository {
  PersonFollowRepository({SupabaseClient? client})
      : _client = client ?? SupabaseConfig.client;

  final SupabaseClient _client;

  SupabaseQueryBuilder get _follows => _client.from('person_follows');

  Future<void> follow({
    required String userId,
    required int personId,
    required String name,
    String? profilePath,
    String? department,
  }) =>
      _follows.upsert({
        'user_id': userId,
        'person_id': personId,
        'person_name': name,
        'profile_path': profilePath,
        'department': department,
      }, onConflict: 'user_id,person_id');

  Future<void> unfollow({required String userId, required int personId}) =>
      _follows.delete().eq('user_id', userId).eq('person_id', personId);

  /// Everyone [userId] follows, most recent first.
  Future<List<PersonFollow>> getFollows(String userId) async {
    final rows = await _follows
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return rows.map(PersonFollow.fromRow).toList();
  }

  /// How many people on 35mm follow [personId].
  Future<int> followerCount(int personId) async {
    final res = await _follows
        .select('user_id')
        .eq('person_id', personId)
        .count(CountOption.exact);
    return res.count;
  }

  /// Your recent new-work alerts, for the "New from people you follow" rail.
  Future<List<NotificationModel>> getRecentCredits(String userId,
      {int days = 30}) async {
    final rows = await _client
        .from('notifications')
        .select()
        .eq('recipient_id', userId)
        .eq('type', 'personNewCredit')
        .gte(
            'created_at',
            DateTime.now()
                .toUtc()
                .subtract(Duration(days: days))
                .toIso8601String())
        .order('created_at', ascending: false)
        .limit(20);
    return rows.map(NotificationModel.fromRow).toList();
  }
}
