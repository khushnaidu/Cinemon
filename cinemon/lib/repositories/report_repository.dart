import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_config.dart';

/// Everything that can be reported (ADR 0004 D1). [column] is the
/// `content_reports` column that points at it.
enum ReportKind {
  post('post_id', 'post'),
  postComment('comment_id', 'reply'),
  activity('activity_id', 'review'),
  activityComment('activity_comment_id', 'comment'),
  list('list_id', 'playlist'),
  profile('profile_id', 'account');

  const ReportKind(this.column, this.noun);

  final String column;

  /// How the sheet names it: "Report review".
  final String noun;
}

/// Reports (migrations 004, 014). Whatever you report disappears for you on
/// the next read; the server's read policies do that, not the client.
class ReportRepository {
  ReportRepository({SupabaseClient? client})
      : _client = client ?? SupabaseConfig.client;

  final SupabaseClient _client;

  Future<void> report({
    required ReportKind kind,
    required String targetId,
    required String reporterId,
    required String reason,
  }) async {
    try {
      await _client.from('content_reports').insert({
        'reporter_id': reporterId,
        kind.column: targetId,
        'reason': reason,
      });
    } on PostgrestException catch (e) {
      // Reported it before: from the reporter's side that's still a report.
      if (e.code != '23505') rethrow;
    }
  }
}
