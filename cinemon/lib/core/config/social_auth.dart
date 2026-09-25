/// Google sign-in client IDs (Google Cloud → Google Auth Platform →
/// Clients). Not secrets: they ship inside every copy of the app.
///
/// The iOS client identifies this app to Google. The web client is the
/// audience of the ID token Supabase checks, and must be listed first in
/// Supabase → Authentication → Providers → Google → Client IDs.
const kGoogleIosClientId =
    '742855162897-1ka401bbm0siprp3llvkp4482c9n21u5.apps.googleusercontent.com';
const kGoogleWebClientId =
    '742855162897-kvgmv7l4ge1n2j2l3rv2945tan6bntln.apps.googleusercontent.com';
