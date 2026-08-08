import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/activity_model.dart';
import '../../models/film_model.dart';
import '../../models/person_model.dart';
import '../../repositories/movie_repository.dart';
import '../../repositories/user_repository.dart';
import '../auth/auth_provider.dart';
import '../feed/feed_provider.dart';
import '../movie/movie_provider.dart';

// =============================================================================
// PERSON SEARCH
// =============================================================================

/// Provider for searching people (actors, directors, etc.)
final searchPeopleProvider =
    FutureProvider.family<List<PersonModel>, String>((ref, query) async {
  if (query.trim().isEmpty) return [];
  final repository = ref.watch(movieRepositoryProvider);
  return repository.searchPeople(query);
});

/// State notifier for person search with debouncing
class PersonSearchNotifier extends StateNotifier<AsyncValue<List<PersonModel>>> {
  final MovieRepository _repository;
  String _lastQuery = '';

  PersonSearchNotifier(this._repository) : super(const AsyncValue.data([]));

  /// Search for people
  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      state = const AsyncValue.data([]);
      return;
    }

    if (query == _lastQuery) return;
    _lastQuery = query;

    state = const AsyncValue.loading();

    try {
      final results = await _repository.searchPeople(query);
      if (query == _lastQuery) {
        state = AsyncValue.data(results);
      }
    } catch (e, st) {
      if (query == _lastQuery) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  /// Clear search results
  void clear() {
    _lastQuery = '';
    state = const AsyncValue.data([]);
  }
}

/// Provider for person search notifier
final personSearchNotifierProvider =
    StateNotifierProvider<PersonSearchNotifier, AsyncValue<List<PersonModel>>>(
        (ref) {
  final repository = ref.watch(movieRepositoryProvider);
  return PersonSearchNotifier(repository);
});

// =============================================================================
// FAVORITE FILMS
// =============================================================================

/// Helper to create a stable key from film IDs list
/// This ensures Riverpod family provider uses proper equality comparison
String _filmIdsKey(List<int> ids) => ids.join(',');

/// Helper to parse film IDs from key string
List<int> _parseFilmIdsKey(String key) {
  if (key.isEmpty) return [];
  return key.split(',').map((s) => int.parse(s)).toList();
}

/// Provider for fetching favorite films with full data
/// Uses a string key for stable equality comparison in Riverpod family
final favoriteFilmsDataProvider =
    FutureProvider.family<List<FilmModel>, String>((ref, filmIdsKey) async {
  final filmIds = _parseFilmIdsKey(filmIdsKey);
  if (filmIds.isEmpty) return [];
  final repository = ref.watch(movieRepositoryProvider);
  return repository.getFilmsByIds(filmIds);
});

/// Convenience function to watch favorite films by ID list
/// Converts list to stable string key for the provider
String favoriteFilmsKey(List<int> filmIds) => _filmIdsKey(filmIds);

/// Provider for current user's favorite films
final currentUserFavoriteFilmsProvider = FutureProvider<List<FilmModel>>((ref) async {
  final userProfile = await ref.watch(currentUserProfileProvider.future);
  if (userProfile == null) return [];

  final filmIds = userProfile.favoriteFilmIds;
  if (filmIds.isEmpty) return [];

  return ref.watch(favoriteFilmsDataProvider(favoriteFilmsKey(filmIds)).future);
});

// =============================================================================
// FAVORITE PEOPLE (ACTORS & DIRECTORS)
// =============================================================================

/// Helper to create a stable key from person IDs list
String _personIdsKey(List<int> ids) => ids.join(',');

/// Helper to parse person IDs from key string
List<int> _parsePersonIdsKey(String key) {
  if (key.isEmpty) return [];
  return key.split(',').map((s) => int.parse(s)).toList();
}

/// Provider for fetching people by their IDs (uses string key for stable equality)
final _peopleByIdsKeyProvider =
    FutureProvider.family<List<PersonModel>, String>((ref, personIdsKey) async {
  final personIds = _parsePersonIdsKey(personIdsKey);
  if (personIds.isEmpty) return [];
  final repository = ref.watch(movieRepositoryProvider);
  return repository.getPeopleByIds(personIds);
});

/// Convenience function to create key for peopleByIdsProvider
String peopleByIdsKey(List<int> personIds) => _personIdsKey(personIds);

/// Provider for fetching people by their IDs (wrapper for easy use)
final peopleByIdsProvider =
    FutureProvider.family<List<PersonModel>, List<int>>((ref, personIds) async {
  if (personIds.isEmpty) return [];
  return ref.watch(_peopleByIdsKeyProvider(peopleByIdsKey(personIds)).future);
});

/// Provider for fetching a single person by ID
final personByIdProvider =
    FutureProvider.family<PersonModel?, int>((ref, personId) async {
  final repository = ref.watch(movieRepositoryProvider);
  try {
    return await repository.getPersonDetails(personId);
  } catch (e) {
    return null;
  }
});

/// Provider for current user's favorite actors
final currentUserFavoriteActorsProvider = FutureProvider<List<PersonModel>>((ref) async {
  final userProfile = await ref.watch(currentUserProfileProvider.future);
  if (userProfile == null) return [];

  final actorIds = userProfile.favoriteActorIds;
  if (actorIds.isEmpty) return [];

  return ref.watch(peopleByIdsProvider(actorIds).future);
});

/// Provider for current user's favorite directors
final currentUserFavoriteDirectorsProvider = FutureProvider<List<PersonModel>>((ref) async {
  final userProfile = await ref.watch(currentUserProfileProvider.future);
  if (userProfile == null) return [];

  final directorIds = userProfile.favoriteDirectorIds;
  if (directorIds.isEmpty) return [];

  return ref.watch(peopleByIdsProvider(directorIds).future);
});

// =============================================================================
// RECENTLY WATCHED
// =============================================================================

/// Provider for a user's recently watched films (from activities)
/// Returns the most recent unique films they've posted about
final recentlyWatchedProvider =
    FutureProvider.family<List<ActivityModel>, String>((ref, userId) async {
  final feedRepo = ref.watch(feedRepositoryProvider);
  final activities = await feedRepo.getUserActivities(userId: userId, limit: 20);

  // Get unique films (most recent appearance of each film)
  final seenFilmIds = <int>{};
  final uniqueActivities = <ActivityModel>[];

  for (final activity in activities) {
    if (!seenFilmIds.contains(activity.filmId)) {
      seenFilmIds.add(activity.filmId);
      uniqueActivities.add(activity);
      if (uniqueActivities.length >= 8) break; // Limit to 8 recent films
    }
  }

  return uniqueActivities;
});

/// Provider for current user's recently watched films
final currentUserRecentlyWatchedProvider = FutureProvider<List<ActivityModel>>((ref) async {
  final currentUser = ref.watch(currentUserProvider);
  if (currentUser == null) return [];

  return ref.watch(recentlyWatchedProvider(currentUser.uid).future);
});

// =============================================================================
// FAVORITES MANAGEMENT NOTIFIER
// =============================================================================

/// State for favorites management
class FavoritesState {
  final bool isLoading;
  final String? errorMessage;
  final bool success;

  const FavoritesState({
    this.isLoading = false,
    this.errorMessage,
    this.success = false,
  });

  FavoritesState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool? success,
  }) {
    return FavoritesState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      success: success ?? this.success,
    );
  }
}

/// Controller for managing favorites
class FavoritesController extends StateNotifier<FavoritesState> {
  final UserRepository _userRepo;
  final Ref _ref;

  FavoritesController(this._userRepo, this._ref) : super(const FavoritesState());

  // ========== FILMS ==========

  /// Add a favorite film
  Future<bool> addFavoriteFilm(int filmId) async {
    final currentUser = _ref.read(currentUserProvider);
    if (currentUser == null) {
      state = state.copyWith(errorMessage: 'Not logged in');
      return false;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final success = await _userRepo.addFavoriteFilm(currentUser.uid, filmId);
      state = state.copyWith(isLoading: false, success: success);

      if (success) {
        _invalidateFavorites();
      }
      return success;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  /// Remove a favorite film
  Future<void> removeFavoriteFilm(int filmId) async {
    final currentUser = _ref.read(currentUserProvider);
    if (currentUser == null) return;

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      await _userRepo.removeFavoriteFilm(currentUser.uid, filmId);
      state = state.copyWith(isLoading: false, success: true);
      _invalidateFavorites();
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  /// Set all favorite films (for reordering)
  Future<void> setFavoriteFilms(List<int> filmIds) async {
    final currentUser = _ref.read(currentUserProvider);
    if (currentUser == null) return;

    try {
      await _userRepo.setFavoriteFilms(currentUser.uid, filmIds);
      _invalidateFavorites();
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  // ========== ACTORS ==========

  /// Add a favorite actor
  Future<bool> addFavoriteActor(int personId) async {
    final currentUser = _ref.read(currentUserProvider);
    if (currentUser == null) {
      state = state.copyWith(errorMessage: 'Not logged in');
      return false;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final success = await _userRepo.addFavoriteActor(currentUser.uid, personId);
      state = state.copyWith(isLoading: false, success: success);

      if (success) {
        _invalidateFavorites();
      }
      return success;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  /// Remove a favorite actor
  Future<void> removeFavoriteActor(int personId) async {
    final currentUser = _ref.read(currentUserProvider);
    if (currentUser == null) return;

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      await _userRepo.removeFavoriteActor(currentUser.uid, personId);
      state = state.copyWith(isLoading: false, success: true);
      _invalidateFavorites();
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  /// Set all favorite actors (for reordering)
  Future<void> setFavoriteActors(List<int> personIds) async {
    final currentUser = _ref.read(currentUserProvider);
    if (currentUser == null) return;

    try {
      await _userRepo.setFavoriteActors(currentUser.uid, personIds);
      _invalidateFavorites();
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  // ========== DIRECTORS ==========

  /// Add a favorite director
  Future<bool> addFavoriteDirector(int personId) async {
    final currentUser = _ref.read(currentUserProvider);
    if (currentUser == null) {
      state = state.copyWith(errorMessage: 'Not logged in');
      return false;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final success = await _userRepo.addFavoriteDirector(currentUser.uid, personId);
      state = state.copyWith(isLoading: false, success: success);

      if (success) {
        _invalidateFavorites();
      }
      return success;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  /// Remove a favorite director
  Future<void> removeFavoriteDirector(int personId) async {
    final currentUser = _ref.read(currentUserProvider);
    if (currentUser == null) return;

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      await _userRepo.removeFavoriteDirector(currentUser.uid, personId);
      state = state.copyWith(isLoading: false, success: true);
      _invalidateFavorites();
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  /// Set all favorite directors (for reordering)
  Future<void> setFavoriteDirectors(List<int> personIds) async {
    final currentUser = _ref.read(currentUserProvider);
    if (currentUser == null) return;

    try {
      await _userRepo.setFavoriteDirectors(currentUser.uid, personIds);
      _invalidateFavorites();
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  /// Invalidate all favorite-related providers
  void _invalidateFavorites() {
    _ref.invalidate(currentUserProfileProvider);
    _ref.invalidate(currentUserFavoriteFilmsProvider);
    _ref.invalidate(currentUserFavoriteActorsProvider);
    _ref.invalidate(currentUserFavoriteDirectorsProvider);
  }

  /// Clear error state
  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  /// Reset state
  void reset() {
    state = const FavoritesState();
  }
}

/// Provider for favorites controller
final favoritesControllerProvider =
    StateNotifierProvider<FavoritesController, FavoritesState>((ref) {
  final userRepo = ref.watch(userRepositoryProvider);
  return FavoritesController(userRepo, ref);
});
