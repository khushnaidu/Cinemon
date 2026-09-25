import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/film_model.dart';
import '../../models/list_model.dart';
import '../../repositories/list_repository.dart';
import '../auth/auth_provider.dart';
import '../explore/explore_provider.dart'
    show exploreFeedProvider, userExploreFeedProvider;
import '../feed/feed_provider.dart' show homeFeedProvider;

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

// ── Playlists (Phase 4) ─────────────────────────────────────────

/// A playlist with the four posters its cover is drawn from.
class PlaylistSummary {
  const PlaylistSummary({required this.list, required this.posters});

  final FilmList list;
  final List<String?> posters;
}

/// Someone's playlists you're allowed to see, with covers.
final playlistsProvider = FutureProvider.autoDispose
    .family<List<PlaylistSummary>, String>((ref, userId) async {
  final repo = ref.watch(listRepositoryProvider);
  final lists = await repo.getPlaylists(userId);
  final covers = await repo.getCoverPosters([for (final l in lists) l.id]);
  return [
    for (final l in lists)
      PlaylistSummary(list: l, posters: covers[l.id] ?? const []),
  ];
});

/// Whether you've saved someone else's playlist.
/// A playlist someone else made that you saved, for your Lists tab.
class SavedPlaylist {
  const SavedPlaylist({
    required this.list,
    required this.posters,
    this.ownerUsername,
  });

  final FilmList list;
  final List<String?> posters;
  final String? ownerUsername;
}

/// Your saved playlists, most recently saved first.
final savedPlaylistsProvider =
    FutureProvider.autoDispose<List<SavedPlaylist>>((ref) async {
  final me = ref.watch(currentUserProvider);
  if (me == null) return [];
  final repo = ref.watch(listRepositoryProvider);
  final saved = await repo.getSavedPlaylists(me.uid);
  final covers = await repo.getCoverPosters([for (final s in saved) s.$1.id]);
  return [
    for (final (list, owner) in saved)
      SavedPlaylist(
        list: list,
        posters: covers[list.id] ?? const [],
        ownerUsername: owner,
      ),
  ];
});

final listSavedProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, listId) async {
  final me = ref.watch(currentUserProvider);
  if (me == null) return false;
  return ref.watch(listRepositoryProvider).isSaved(listId, me.uid);
});

/// Which of your lists (watchlist included) a title is on, for Add to….
final listsContainingProvider = FutureProvider.autoDispose
    .family<Set<String>, ({int filmId, String mediaType})>((ref, title) async {
  final me = ref.watch(currentUserProvider);
  if (me == null) return {};
  final watchlist = await ref.watch(myWatchlistProvider.future);
  final playlists = await ref.watch(playlistsProvider(me.uid).future);
  return ref.watch(listRepositoryProvider).listsContaining(
    [
      if (watchlist != null) watchlist.id,
      for (final p in playlists) p.list.id,
    ],
    title.filmId,
    title.mediaType,
  );
});

class PlaylistActions {
  PlaylistActions(this._ref);

  final Ref _ref;

  ListRepository get _repo => _ref.read(listRepositoryProvider);
  String? get _me => _ref.read(currentUserProvider)?.uid;

  /// Creates the playlist, and adds [first] to it if given (from Add to…).
  Future<FilmList?> create({
    required String title,
    String? description,
    required ListVisibility visibility,
    FilmModel? first,
  }) async {
    final me = _me;
    if (me == null) return null;
    try {
      final list = await _repo.createPlaylist(
        userId: me,
        title: title,
        description: description,
        visibility: visibility,
      );
      if (first != null) await _repo.addItem(list.id, first);
      _refresh(list.id);
      return list;
    } catch (_) {
      return null;
    }
  }

  Future<bool> update(
    FilmList list, {
    required String title,
    String? description,
    required ListVisibility visibility,
  }) async {
    try {
      await _repo.updatePlaylist(list.id,
          title: title, description: description, visibility: visibility);
    } catch (_) {
      return false;
    }
    _refresh(list.id);
    // Leaving public hides its Explore posts, and coming back shows them.
    if (visibility != list.visibility) _refreshPosts();
    return true;
  }

  Future<bool> delete(FilmList list) async {
    try {
      await _repo.deleteList(list.id);
    } catch (_) {
      return false;
    }
    _refresh(list.id);
    // Its Explore posts went with it.
    _refreshPosts();
    return true;
  }

  void _refreshPosts() {
    _ref.invalidate(exploreFeedProvider);
    _ref.invalidate(userExploreFeedProvider);
    _ref.invalidate(homeFeedProvider);
  }

  /// Put a title on a list or take it off. Returns whether it's now on it,
  /// or null if the write failed.
  Future<bool?> toggle(String listId, FilmModel film,
      {required bool on}) async {
    final mediaType = film.isTv ? 'tv' : 'movie';
    try {
      if (on) {
        await _repo.removeItem(listId, film.id, mediaType);
      } else {
        await _repo.addItem(listId, film);
      }
    } catch (_) {
      return null;
    }
    _refresh(listId);
    return !on;
  }

  Future<bool> remove(ListItem item) async {
    try {
      await _repo.removeItem(item.listId, item.filmId, item.mediaType);
    } catch (_) {
      return false;
    }
    _refresh(item.listId);
    return true;
  }

  /// Move [items][from] to index [to] and save it (see [planMove]).
  /// Returns the new order with positions, or null if the write failed.
  Future<List<ListItem>?> move(List<ListItem> items, int from, int to) async {
    final plan = planMove(items, from, to);
    try {
      if (plan.renumbered) {
        for (final i in plan.order) {
          await _repo.setPosition(i, i.position);
        }
      } else if (from != to) {
        await _repo.setPosition(plan.order[to], plan.order[to].position);
      }
    } catch (_) {
      _refresh(items[from].listId);
      return null;
    }
    _refresh(items[from].listId);
    return plan.order;
  }

  Future<bool> setSaved(String listId, {required bool saved}) async {
    final me = _me;
    if (me == null) return false;
    try {
      saved ? await _repo.save(listId, me) : await _repo.unsave(listId, me);
    } catch (_) {
      return false;
    }
    _ref.invalidate(listSavedProvider(listId));
    _ref.invalidate(listProvider(listId));
    _ref.invalidate(savedPlaylistsProvider);
    return true;
  }

  void _refresh(String listId) {
    _ref.invalidate(playlistsProvider);
    _ref.invalidate(listsContainingProvider);
    _ref.read(watchlistActionsProvider).refresh(listId);
  }
}

final playlistActionsProvider =
    Provider<PlaylistActions>((ref) => PlaylistActions(ref));

/// The new order after moving [items][from] to [to] (an after-removal
/// index). Only the moved row gets a new position, the midpoint of its new
/// neighbours, so a reorder is one write. When the neighbours are too close
/// to split, every row is renumbered 1…n instead.
({List<ListItem> order, bool renumbered}) planMove(
    List<ListItem> items, int from, int to) {
  final order = [...items];
  if (from == to) return (order: order, renumbered: false);
  final moving = order.removeAt(from);
  order.insert(to, moving);
  final before = to > 0 ? order[to - 1].position : null;
  final after = to < order.length - 1 ? order[to + 1].position : null;

  if (before != null && after != null && (after - before).abs() < 1e-9) {
    for (var i = 0; i < order.length; i++) {
      order[i] = order[i].withPosition(i + 1.0);
    }
    return (order: order, renumbered: true);
  }
  final position = before == null
      ? after! - 1
      : after == null
          ? before + 1
          : (before + after) / 2;
  order[to] = moving.withPosition(position);
  return (order: order, renumbered: false);
}
