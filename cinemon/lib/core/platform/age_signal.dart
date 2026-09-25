import 'package:flutter/services.dart';

/// Apple's age signal (Declared Age Range) for the person on this device,
/// where state law requires apps to check it (AppDelegate.swift,
/// AgeRangeChannel).
sealed class AgeSignal {
  const AgeSignal();
}

/// Not in a region where it's required, or not available on this iOS.
class AgeSignalNotRequired extends AgeSignal {
  const AgeSignalNotRequired();
}

/// The person shared an age bracket.
class AgeSignalShared extends AgeSignal {
  const AgeSignalShared({this.lower, this.upper});
  final int? lower;
  final int? upper;

  bool get under13 => upper != null && upper! < 13;
  bool get minor => upper != null && upper! < 18;
}

/// Asked, and chose not to share.
class AgeSignalDeclined extends AgeSignal {
  const AgeSignalDeclined();
}

/// The system couldn't answer this time.
class AgeSignalUnavailable extends AgeSignal {
  const AgeSignalUnavailable();
}

const _channel = MethodChannel('app.35mm/age_range');

Future<AgeSignal> checkAgeSignal() async {
  try {
    final r = await _channel.invokeMapMethod<String, dynamic>('check');
    return switch (r?['status']) {
      'sharing' => AgeSignalShared(
          lower: r?['lower'] as int?, upper: r?['upper'] as int?),
      'declined' => const AgeSignalDeclined(),
      'unavailable' => const AgeSignalUnavailable(),
      _ => const AgeSignalNotRequired(),
    };
  } on MissingPluginException {
    return const AgeSignalNotRequired();
  } catch (_) {
    return const AgeSignalUnavailable();
  }
}
