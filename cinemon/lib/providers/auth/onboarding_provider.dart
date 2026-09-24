import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/supabase_config.dart';
import 'auth_provider.dart';

/// Whether the signed-in account has finished onboarding (ADR 0004 D7).
///
/// Null when signed out. The router sends anyone for whom this is false to
/// `/onboarding`; if the lookup fails the app lets them in rather than
/// locking them out, since everyone from before onboarding counts as done.
final onboardedProvider = FutureProvider<bool?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  final row = await SupabaseConfig.client
      .from('profiles')
      .select('onboarded_at')
      .eq('id', user.id)
      .maybeSingle();
  // No profile row yet means the sign-up trigger hasn't landed: onboarding
  // will find it by the time the username is saved.
  return row != null && row['onboarded_at'] != null;
});
