import 'package:flutter/foundation.dart';

/// While true, the router leaves the current screen alone even though the
/// auth state has changed. Log in sets it so its logo zoom can finish before
/// the redirect to Home (or onboarding) takes over.
final authRedirectHold = ValueNotifier<bool>(false);
