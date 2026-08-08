import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase configuration and initialization.
///
/// The publishable key is safe to ship in the client — it carries no
/// privileges of its own. Row Level Security is what actually guards the
/// data. Never put the *secret* / service-role key in here.
///
/// Both values can be overridden at build time without touching source:
///   flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_KEY=...
class SupabaseConfig {
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://juarrrjrlxsymrxvsdcu.supabase.co',
  );

  static const String publishableKey = String.fromEnvironment(
    'SUPABASE_KEY',
    defaultValue: 'sb_publishable_F7Ju3Gc5UB-nND3aE2Pq_g_m-9edP-U',
  );

  /// Deep link the auth emails (confirmation, password reset, magic link)
  /// send the user back to.
  ///
  /// Must be listed under Redirect URLs in the Supabase dashboard, and the
  /// `cinemon` scheme must stay in sync with iOS `CFBundleURLSchemes` and the
  /// Android intent filter. Without this, Supabase falls back to the project's
  /// Site URL — `http://localhost:3000` by default, which cannot resolve on a
  /// phone and leaves the user staring at a browser error.
  static const String authRedirectUrl = 'cinemon://login-callback';

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: url,
      anonKey: publishableKey,
      authOptions: const FlutterAuthClientOptions(
        // Persists the session to disk so users stay logged in across
        // launches.
        authFlowType: AuthFlowType.pkce,
      ),
    );
  }

  /// Shorthand for the global client.
  static SupabaseClient get client => Supabase.instance.client;

  /// Currently signed-in user, or null.
  static User? get currentUser => client.auth.currentUser;

  /// Currently signed-in user's id, or null.
  static String? get currentUserId => client.auth.currentUser?.id;
}
