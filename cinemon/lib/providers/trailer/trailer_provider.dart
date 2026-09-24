import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/trailer_item.dart';
import '../../repositories/trailer_repository.dart';

final trailerRepositoryProvider =
    Provider<TrailerRepository>((ref) => TrailerRepository());

/// One feed, kept for the session: the tab lives in the shell's indexed
/// stack, and the feed only changes every 6 hours. Pull to refresh on the
/// first page invalidates it.
final trailerFeedProvider =
    FutureProvider.family<List<TrailerItem>, TrailerFeed>((ref, feed) {
  return ref.watch(trailerRepositoryProvider).getFeed(feed);
});
