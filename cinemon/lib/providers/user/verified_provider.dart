import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/supabase_config.dart';

/// The verified accounts (migration 029): the official one and the
/// founder's. A handful of ids, so any username anywhere can show its seal
/// without carrying the flag itself. Looked up again every ten minutes and
/// on pull to refresh, so a seal granted from the dashboard turns up
/// without restarting the app.
final verifiedUsersProvider = FutureProvider<Set<String>>((ref) async {
  final again = Timer(const Duration(minutes: 10), ref.invalidateSelf);
  ref.onDispose(again.cancel);
  try {
    final rows = await SupabaseConfig.client
        .from('profiles')
        .select('id')
        .eq('is_verified', true)
        .limit(50);
    return {for (final r in rows) r['id'] as String};
  } catch (_) {
    // Before migration 029 there's no column: nobody is verified.
    return const {};
  }
});
