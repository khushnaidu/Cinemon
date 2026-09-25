import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/film_model.dart';
import '../../models/library_entry.dart';
import '../../repositories/library_repository.dart';
import '../auth/auth_provider.dart';
import '../lists/list_provider.dart' show watchlistActionsProvider;

final libraryRepositoryProvider =
    Provider<LibraryRepository>((ref) => LibraryRepository());

/// Someone's library, most recent first.
final libraryProvider = FutureProvider.autoDispose
    .family<List<LibraryEntry>, String>((ref, userId) {
  return ref.watch(libraryRepositoryProvider).entries(userId);
});

/// How many titles are in someone's library, for the profile header.
final libraryCountProvider = FutureProvider.autoDispose
    .family<({int films, int shows}), String>((ref, userId) {
  return ref.watch(libraryRepositoryProvider).counts(userId);
});

/// What's in your own library, for the Watched buttons and the add panel.
final myLibraryKeysProvider = FutureProvider<Set<String>>((ref) async {
  final me = ref.watch(currentUserProvider);
  if (me == null) return const {};
  return ref.watch(libraryRepositoryProvider).keys(me.id);
});

/// Add to and remove from your library. Nothing is posted.
class LibraryActions {
  LibraryActions(this._ref);

  final Ref _ref;

  LibraryRepository get _repo => _ref.read(libraryRepositoryProvider);

  /// Returns whether it's now in the library, or null if the write failed.
  Future<bool?> toggle(FilmModel film, {required bool inLibrary}) async {
    final me = _ref.read(currentUserProvider)?.id;
    if (me == null) return null;
    try {
      if (inLibrary) {
        await _repo.remove(me, film.id, film.isTv ? 'tv' : 'movie');
      } else {
        await _repo.add(me, film);
      }
    } catch (_) {
      return null;
    }
    _refresh(me);
    return !inLibrary;
  }

  Future<bool> remove(LibraryEntry entry) async {
    final me = _ref.read(currentUserProvider)?.id;
    if (me == null) return false;
    try {
      await _repo.remove(me, entry.filmId, entry.mediaType);
    } catch (_) {
      return false;
    }
    _refresh(me);
    return true;
  }

  void _refresh(String me) {
    _ref.invalidate(libraryProvider(me));
    _ref.invalidate(libraryCountProvider(me));
    _ref.invalidate(myLibraryKeysProvider);
    // Adding strikes it off the watchlist (migration 024).
    _ref.read(watchlistActionsProvider).refresh();
  }
}

final libraryActionsProvider =
    Provider<LibraryActions>((ref) => LibraryActions(ref));
