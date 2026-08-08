import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase configuration and initialization.
///
/// Values are injected at build time and have no defaults, so which backend a
/// build points at is always an explicit choice — a release can't silently
/// ship pointing at a dev project, or vice versa.
///
///   flutter run --dart-define-from-file=dart_defines.json
///
/// Copy `dart_defines.example.json` to `dart_defines.json` and fill it in;
/// that file is gitignored.
///
/// The publishable key is safe to ship in the client — it carries no
/// privileges of its own, and Row Level Security is what actually guards the
/// data. Never put the *secret* / service-role key in here: it bypasses RLS
/// entirely and would be extractable from the app bundle.
class SupabaseConfig {
  static const String url = String.fromEnvironment('SUPABASE_URL');

  static const String publishableKey = String.fromEnvironment('SUPABASE_KEY');

  /// Deep link the auth emails (confirmation, password reset, magic link)
  /// send the user back to.
  ///
  /// Must be listed under Redirect URLs in the Supabase dashboard, and the
  /// `cinemon` scheme must stay in sync with iOS `CFBundleURLSchemes` and the
  /// Android intent filter. Without this, Supabase falls back to the project's
  /// Site URL — `http://localhost:3000` by default, which cannot resolve on a
  /// phone and leaves the user staring at a browser error.
  static const String authRedirectUrl = 'cinemon://login-callback';

  /// Whether both build-time values were supplied.
  static bool get isConfigured => url.isNotEmpty && publishableKey.isNotEmpty;

  static Future<void> initialize() async {
    if (!isConfigured) {
      final missing = [
        if (url.isEmpty) 'SUPABASE_URL',
        if (publishableKey.isEmpty) 'SUPABASE_KEY',
      ].join(', ');
      throw StateError(
        'Missing build-time config: $missing.\n'
        'Run with:  flutter run --dart-define-from-file=dart_defines.json\n'
        '(copy dart_defines.example.json and fill in the values from\n'
        ' Supabase -> Project Settings -> API)',
      );
    }

    // A service-role key bypasses RLS completely. Shipping one in a client
    // would expose every row to anyone who unzips the app, so fail loudly
    // rather than start up with it.
    if (publishableKey.contains('service_role') ||
        publishableKey.startsWith('sb_secret_')) {
      throw StateError(
        'SUPABASE_KEY looks like a secret/service-role key. Use the '
        'publishable (anon) key in client builds.',
      );
    }

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
