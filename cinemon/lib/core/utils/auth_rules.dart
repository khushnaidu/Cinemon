/// The rules sign-up and onboarding check as you type (ADR 0004 D5, D7).
///
/// The server is the authority: Supabase enforces the password rules, and
/// migration 015 the username format. These exist so the screens can say
/// what's missing before a round trip does.
library;

/// One line of the password checklist.
class PasswordRule {
  const PasswordRule(this.label, this.test);

  final String label;
  final bool Function(String) test;
}

const passwordRules = [
  PasswordRule('At least 8 characters', _long),
  PasswordRule('A letter', _hasLetter),
  PasswordRule('A number', _hasDigit),
];

bool _long(String p) => p.length >= 8;
bool _hasLetter(String p) => RegExp(r'[A-Za-z]').hasMatch(p);
bool _hasDigit(String p) => RegExp(r'\d').hasMatch(p);

bool passwordOk(String p) => passwordRules.every((r) => r.test(p));

/// 3 to 24 of a–z, 0–9, _ and ., not starting or ending with a full stop.
/// Matches `guard_username()` in migration 015.
final _usernamePattern = RegExp(r'^[a-z0-9_][a-z0-9_.]{1,22}[a-z0-9_]$');

/// Why [name] can't be a username, or null when it can.
String? usernameProblem(String name) {
  if (name.isEmpty) return 'Choose a username';
  if (name.length < 3) return 'At least 3 characters';
  if (name.length > 24) return 'At most 24 characters';
  if (RegExp(r'[^a-z0-9_.]').hasMatch(name)) {
    return 'Only lowercase letters, numbers, _ and .';
  }
  if (name.startsWith('.') || name.endsWith('.')) {
    return "Can't start or end with a full stop";
  }
  if (!_usernamePattern.hasMatch(name)) return 'Not a valid username';
  return null;
}

/// What people type, as a username: lowercased, spaces to underscores,
/// anything else outside the set dropped.
String normaliseUsername(String input) => input
    .toLowerCase()
    .replaceAll(' ', '_')
    .replaceAll(RegExp(r'[^a-z0-9_.]'), '');

/// A first suggestion from the email address or name, for onboarding to
/// start from. Empty when nothing usable is left.
String suggestUsername({String? email, String? name}) {
  final seeds = [
    if (name != null && name.trim().isNotEmpty) name.trim(),
    if (email != null && email.contains('@')) email.split('@').first,
  ];
  for (final seed in seeds) {
    var s = normaliseUsername(seed.replaceAll(RegExp(r'[\s\-]+'), '_'));
    s = s.replaceAll(RegExp(r'^\.+|\.+$'), '');
    if (s.length > 24) s = s.substring(0, 24).replaceAll(RegExp(r'\.+$'), '');
    if (usernameProblem(s) == null) return s;
  }
  return '';
}
