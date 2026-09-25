import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/legal.dart';
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

/// Where the signed-in account stands with the Terms (migration 021): null
/// when signed out.
class TermsStatus {
  const TermsStatus({required this.accepted, required this.ageKnown});

  /// Agreed to the current version.
  final bool accepted;

  /// Confirmed their age at some point.
  final bool ageKnown;
}

/// The router sends anyone who hasn't agreed to the current Terms to
/// `/agree`. Unlike onboarding, a failed lookup doesn't wave them through:
/// the agree screen itself retries.
final termsStatusProvider = FutureProvider<TermsStatus?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  final row = await SupabaseConfig.client
      .from('profiles')
      .select('terms_version, age_confirmed_at')
      .eq('id', user.id)
      .maybeSingle();
  // No profile yet: the sign-up trigger fills it in from the sign-up
  // screen's agreement, so check again once it exists.
  if (row == null) return const TermsStatus(accepted: true, ageKnown: true);
  return TermsStatus(
    accepted: row['terms_version'] == kTermsVersion,
    ageKnown: row['age_confirmed_at'] != null,
  );
});
