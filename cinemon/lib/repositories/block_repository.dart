import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_config.dart';

/// One row in Settings → Blocked accounts.
class BlockedAccount {
  const BlockedAccount({
    required this.id,
    required this.username,
    this.photoUrl,
  });

  final String id;
  final String username;
  final String? photoUrl;

  factory BlockedAccount.fromRow(Map<String, dynamic> row) => BlockedAccount(
        id: row['id'] as String,
        username: row['username'] as String,
        photoUrl: row['photo_url'] as String?,
      );
}

/// Blocking (migration 007).
///
/// Enforcement is entirely server-side: a block hides each person's profile
/// from the other, and every feed and comment query inner-joins the author's
/// profile, so their content disappears with it. It also ends any follow
/// between them. The client only writes the row and refreshes.
class BlockRepository {
  BlockRepository({SupabaseClient? client})
      : _client = client ?? SupabaseConfig.client;

  final SupabaseClient _client;

  Future<void> block({required String blockerId, required String blockedId}) =>
      _client.from('user_blocks').upsert(
        {'blocker_id': blockerId, 'blocked_id': blockedId},
        onConflict: 'blocker_id,blocked_id',
        ignoreDuplicates: true,
      );

  Future<void> unblock({
    required String blockerId,
    required String blockedId,
  }) =>
      _client
          .from('user_blocks')
          .delete()
          .eq('blocker_id', blockerId)
          .eq('blocked_id', blockedId);

  /// Through an RPC because the blocked profiles are hidden from the table.
  Future<List<BlockedAccount>> blockedAccounts() async {
    final rows = await _client.rpc('my_blocked_accounts') as List<dynamic>;
    return rows
        .map((r) => BlockedAccount.fromRow(r as Map<String, dynamic>))
        .toList();
  }
}
