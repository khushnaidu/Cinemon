import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/trailer_item.dart';

/// How long a watched trailer stays at the back. After that it counts as
/// unseen again: it's still trending or new, just not new to you any more.
const kTrailerSeenCycle = Duration(days: 7);

/// The trailers you've watched on this device, and when, so a refresh can
/// put the ones you haven't seen first.
class TrailerSeenStore {
  TrailerSeenStore._(this._prefs, this._seen);

  static const _key = 'trailers.seen.v1';

  /// Enough for weeks of both feeds; the oldest go first beyond it.
  static const _cap = 600;

  final SharedPreferences? _prefs;
  final Map<String, DateTime> _seen;

  Map<String, DateTime> get seen => Map.unmodifiable(_seen);

  static Future<TrailerSeenStore> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      final seen = <String, DateTime>{};
      if (raw != null) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        map.forEach((k, v) =>
            seen[k] = DateTime.fromMillisecondsSinceEpoch((v as num).toInt()));
      }
      return TrailerSeenStore._(prefs, seen);
    } catch (_) {
      // Only an ordering nicety: without storage, everything is unseen.
      return TrailerSeenStore._(null, {});
    }
  }

  void markSeen(String videoId, {DateTime? at}) {
    _seen[videoId] = at ?? DateTime.now();
    if (_seen.length > _cap) {
      final oldest = _seen.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));
      for (final e in oldest.take(_seen.length - _cap)) {
        _seen.remove(e.key);
      }
    }
    _prefs?.setString(
      _key,
      jsonEncode(_seen.map((k, v) => MapEntry(k, v.millisecondsSinceEpoch))),
    );
  }
}

/// A feed with what you haven't watched first, in the feed's own order,
/// then what you have, the longest ago first. Anything watched more than
/// [cycle] ago counts as unseen again.
List<TrailerItem> orderUnseenFirst(
  List<TrailerItem> feed,
  Map<String, DateTime> seen, {
  required DateTime now,
  Duration cycle = kTrailerSeenCycle,
}) {
  DateTime? watched(TrailerItem t) {
    final at = seen[t.videoId];
    return at != null && now.difference(at) < cycle ? at : null;
  }

  final unseen = [
    for (final t in feed)
      if (watched(t) == null) t
  ];
  final rewatch = [
    for (final t in feed)
      if (watched(t) != null) t
  ]..sort((a, b) => watched(a)!.compareTo(watched(b)!));
  return [...unseen, ...rewatch];
}
