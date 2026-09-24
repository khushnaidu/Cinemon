import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/film_model.dart';
import '../../models/list_model.dart';
import '../../repositories/list_repository.dart';
import '../auth/auth_provider.dart';

final listRepositoryProvider =
    Provider<ListRepository>((ref) => ListRepository());

/// Someone's watchlist; null if it's hidden from you.
final watchlistProvider =
    FutureProvider.autoDispose.family<FilmList?, String>((ref, userId) {
  return ref.watch(listRepositoryProvider).getWatchlist(userId);
});

/// Yours. Every account has one (the database makes it with the profile).
final myWatchlistProvider = FutureProvider<FilmList?>((ref) async {
  final me = ref.watch(currentUserProvider);
  if (me == null) return null;
  return ref.watch(listRepositoryProvider).getWatchlist(me.uid);
});

final listProvider =
    FutureProvider.autoDispose.family<FilmList?, String>((ref, listId) {
  return ref.watch(listRepositoryProvider).getList(listId);
});

final listItemsProvider =
    FutureProvider.autoDispose.family<List<ListItem>, String>((ref, listId) {
  return ref.watch(listRepositoryProvider).getItems(listId);
});

/// What's on your watchlist and not yet watched, by title key, so a film
/// page can light its bookmark without a query of its own.
final myWatchlistKeysProvider = FutureProvider<Set<String>>((ref) async {
  final list = await ref.watch(myWatchlistProvider.future);
  if (list == null) return {};
  final items = await ref.watch(listRepositoryProvider).getItems(list.id);
  return {
    for (final i in items)
      if (!i.watched) i.key,
  };
});

class WatchlistActions {
  WatchlistActions(this._ref);

  final Ref _ref;

  ListRepository get _repo => _ref.read(listRepositoryProvider);

  /// Add if absent, remove if present. Returns whether it's now on the
  /// list, or null if the write failed.
  Future<bool?> toggle(FilmModel film) async {
    final list = await _ref.read(myWatchlistProvider.future);
    if (list == null) return null;
    final mediaType = film.isTv ? 'tv' : 'movie';
    final key = ListItem.titleKey(film.id, mediaType);
    final keys = await _ref.read(myWatchlistKeysProvider.future);
    final adding = !keys.contains(key);
    try {
      if (adding) {
        // Re-adding something you've watched puts it back to watch again.
        await _repo.removeItem(list.id, film.id, mediaType);
        await _repo.addItem(list.id, film);
      } else {
        await _repo.removeItem(list.id, film.id, mediaType);
      }
    } catch (_) {
      return null;
    }
    refresh(list.id);
    return adding;
  }

  Future<bool> setWatched(ListItem item, {required bool watched}) async {
    try {
      await _repo.setWatched(item.listId, item.filmId, item.mediaType,
          watched: watched);
    } catch (_) {
      return false;
    }
    refresh(item.listId);
    return true;
  }

  Future<bool> remove(ListItem item) async {
    try {
      await _repo.removeItem(item.listId, item.filmId, item.mediaType);
    } catch (_) {
      return false;
    }
    refresh(item.listId);
    return true;
  }

  Future<bool> setVisibility(FilmList list, ListVisibility visibility) async {
    try {
      await _repo.setVisibility(list.id, visibility);
    } catch (_) {
      return false;
    }
    refresh(list.id);
    return true;
  }

  /// After anything that can change a watchlist, including logging a film
  /// (the database strikes it off).
  void refresh([String? listId]) {
    _ref.invalidate(myWatchlistProvider);
    _ref.invalidate(myWatchlistKeysProvider);
    _ref.invalidate(watchlistProvider);
    if (listId != null) {
      _ref.invalidate(listItemsProvider(listId));
      _ref.invalidate(listProvider(listId));
    }
  }
}

final watchlistActionsProvider =
    Provider<WatchlistActions>((ref) => WatchlistActions(ref));
