import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/notification_model.dart';
import '../../models/person_follow.dart';
import '../../models/person_page.dart';
import '../../repositories/person_follow_repository.dart';
import '../auth/auth_provider.dart';

final personFollowRepositoryProvider =
    Provider<PersonFollowRepository>((ref) => PersonFollowRepository());

/// Everyone [userId] follows.
final personFollowsProvider = FutureProvider.autoDispose
    .family<List<PersonFollow>, String>((ref, userId) {
  return ref.watch(personFollowRepositoryProvider).getFollows(userId);
});

/// The ids you follow, for Follow buttons.
final myFollowedPersonIdsProvider =
    FutureProvider.autoDispose<Set<int>>((ref) async {
  final me = ref.watch(currentUserProvider)?.uid;
  if (me == null) return const {};
  final follows = await ref.watch(personFollowsProvider(me).future);
  return {for (final f in follows) f.personId};
});

final personFollowerCountProvider =
    FutureProvider.autoDispose.family<int, int>((ref, personId) {
  return ref.watch(personFollowRepositoryProvider).followerCount(personId);
});

/// New work from people you follow, from the last month's alerts.
final newFromFollowedProvider =
    FutureProvider.autoDispose<List<NotificationModel>>((ref) async {
  final me = ref.watch(currentUserProvider)?.uid;
  if (me == null) return const [];
  return ref.watch(personFollowRepositoryProvider).getRecentCredits(me);
});

class PersonFollowActions {
  PersonFollowActions(this._ref);

  final Ref _ref;

  /// Follow or unfollow. Returns whether you now follow them, or null if
  /// the write failed.
  Future<bool?> toggle(PersonPage person, {required bool following}) async {
    final me = _ref.read(currentUserProvider)?.uid;
    if (me == null) return null;
    final repo = _ref.read(personFollowRepositoryProvider);
    try {
      if (following) {
        await repo.unfollow(userId: me, personId: person.id);
      } else {
        await repo.follow(
          userId: me,
          personId: person.id,
          name: person.name,
          profilePath: person.profilePath,
          department: person.knownForDepartment,
        );
      }
    } catch (_) {
      return null;
    }
    _ref.invalidate(personFollowsProvider(me));
    _ref.invalidate(personFollowerCountProvider(person.id));
    return !following;
  }
}

final personFollowActionsProvider =
    Provider<PersonFollowActions>((ref) => PersonFollowActions(ref));
