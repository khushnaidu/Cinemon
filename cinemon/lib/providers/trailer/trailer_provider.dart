import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/trailer_item.dart';
import '../../repositories/trailer_repository.dart';

final trailerRepositoryProvider =
    Provider<TrailerRepository>((ref) => TrailerRepository());

/// One feed per feed, type and genre, kept for the session: the tab lives
/// in the shell's indexed stack, and the pool only changes every 6 hours.
/// Pull to refresh on the first page invalidates it.
final trailerFeedProvider =
    FutureProvider.family<List<TrailerItem>, DiscoverQuery>((ref, q) {
  return ref.watch(trailerRepositoryProvider).getFeed(q);
});
