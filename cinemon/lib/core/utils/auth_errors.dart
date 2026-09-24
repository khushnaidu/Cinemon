import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthException, PostgrestException;

/// Plain words for what went wrong signing in, signing up or verifying.
///
/// Goes by Supabase's error codes where it sends them, and by the message
/// where older endpoints don't.
String describeAuthError(Object error) {
  if (error is PostgrestException) {
    if (error.code == '23505') return 'That username is taken';
    if (error.code == '23514') return 'That username isn\'t allowed';
    return 'Something went wrong. Try again.';
  }
  if (error is! AuthException) {
    return 'Couldn\'t reach 35mm. Check your connection and try again.';
  }

  final code = error.code ?? '';
  final msg = error.message.toLowerCase();

  if (code == 'invalid_credentials' ||
      msg.contains('invalid login credentials')) {
    return 'Wrong email or password';
  }
  if (code == 'email_not_confirmed' || msg.contains('email not confirmed')) {
    return 'Confirm your email first';
  }
  if (code == 'user_already_exists' ||
      code == 'email_exists' ||
      msg.contains('already registered')) {
    return 'There\'s already an account with this email. Log in instead.';
  }
  if (code == 'weak_password' || msg.contains('password should')) {
    return 'Use at least 8 characters, with a letter and a number';
  }
  if (code == 'same_password') {
    return 'Choose a password you haven\'t used here before';
  }
  if (code == 'otp_expired' ||
      msg.contains('token has expired') ||
      msg.contains('invalid token') ||
      msg.contains('otp')) {
    return 'That code is wrong or has expired. Send a new one.';
  }
  if (code == 'validation_failed' ||
      code == 'email_address_invalid' ||
      msg.contains('unable to validate email') ||
      msg.contains('invalid email')) {
    return 'That email address doesn\'t look right';
  }
  if (code.contains('rate_limit') ||
      error.statusCode == '429' ||
      msg.contains('rate limit')) {
    return 'Too many tries. Wait a minute and try again.';
  }
  if (code == 'user_banned') return 'This account is suspended';
  return error.message;
}

/// Sign-in failed only because the email hasn't been confirmed yet, so the
/// right next step is the code screen rather than an error.
bool isUnconfirmedEmail(Object error) =>
    error is AuthException &&
    (error.code == 'email_not_confirmed' ||
        error.message.toLowerCase().contains('email not confirmed'));
