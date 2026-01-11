import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/film_model.dart';
import '../../repositories/movie_repository.dart';

/// Provider for MovieRepository singleton instance
final movieRepositoryProvider = Provider<MovieRepository>((ref) {
  return MovieRepository();
});

/// Provider for searching movies and TV shows
/// Usage: ref.watch(searchMoviesProvider('query'))
final searchMoviesProvider =
    FutureProvider.family<List<FilmModel>, String>((ref, query) async {
  final repository = ref.watch(movieRepositoryProvider);
  return repository.searchMulti(query);
});

/// Provider for movie search only (no TV)
final searchMoviesOnlyProvider =
    FutureProvider.family<List<FilmModel>, String>((ref, query) async {
  final repository = ref.watch(movieRepositoryProvider);
  return repository.searchMovies(query);
});

/// Provider for TV search only (no movies)
final searchTvOnlyProvider =
    FutureProvider.family<List<FilmModel>, String>((ref, query) async {
  final repository = ref.watch(movieRepositoryProvider);
  return repository.searchTvShows(query);
});

/// Provider for trending movies this week
final trendingMoviesProvider =
    FutureProvider<List<FilmModel>>((ref) async {
  final repository = ref.watch(movieRepositoryProvider);
  return repository.getTrendingMovies();
});

/// Provider for trending TV shows this week
final trendingTvShowsProvider =
    FutureProvider<List<FilmModel>>((ref) async {
  final repository = ref.watch(movieRepositoryProvider);
  return repository.getTrendingTvShows();
});

/// Provider for popular movies
final popularMoviesProvider =
    FutureProvider<List<FilmModel>>((ref) async {
  final repository = ref.watch(movieRepositoryProvider);
  return repository.getPopularMovies();
});

/// Provider for now playing movies
final nowPlayingMoviesProvider =
    FutureProvider<List<FilmModel>>((ref) async {
  final repository = ref.watch(movieRepositoryProvider);
  return repository.getNowPlayingMovies();
});

/// Provider for upcoming movies
final upcomingMoviesProvider =
    FutureProvider<List<FilmModel>>((ref) async {
  final repository = ref.watch(movieRepositoryProvider);
  return repository.getUpcomingMovies();
});

/// Provider for top rated movies
final topRatedMoviesProvider =
    FutureProvider<List<FilmModel>>((ref) async {
  final repository = ref.watch(movieRepositoryProvider);
  return repository.getTopRatedMovies();
});

/// Provider for movie details by ID
/// Usage: ref.watch(movieDetailsProvider(123))
final movieDetailsProvider =
    FutureProvider.family<FilmModel, int>((ref, movieId) async {
  final repository = ref.watch(movieRepositoryProvider);
  return repository.getMovieDetails(movieId);
});

/// Provider for TV show details by ID
/// Usage: ref.watch(tvDetailsProvider(456))
final tvDetailsProvider =
    FutureProvider.family<FilmModel, int>((ref, tvId) async {
  final repository = ref.watch(movieRepositoryProvider);
  return repository.getTvDetails(tvId);
});

/// Provider for film details (movie or TV) by ID and type
/// Usage: ref.watch(filmDetailsProvider((id: 123, mediaType: MediaType.movie)))
final filmDetailsProvider =
    FutureProvider.family<FilmModel, ({int id, MediaType mediaType})>(
        (ref, params) async {
  final repository = ref.watch(movieRepositoryProvider);
  return repository.getFilmDetails(
    id: params.id,
    mediaType: params.mediaType,
  );
});

/// Provider for movie genres
final movieGenresProvider =
    FutureProvider<List<GenreModel>>((ref) async {
  final repository = ref.watch(movieRepositoryProvider);
  return repository.getMovieGenres();
});

/// Provider for TV genres
final tvGenresProvider =
    FutureProvider<List<GenreModel>>((ref) async {
  final repository = ref.watch(movieRepositoryProvider);
  return repository.getTvGenres();
});

/// State notifier for managing search state with debouncing
class SearchNotifier extends StateNotifier<AsyncValue<List<FilmModel>>> {
  final MovieRepository _repository;
  String _lastQuery = '';

  SearchNotifier(this._repository) : super(const AsyncValue.data([]));

  /// Search for movies and TV shows
  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      state = const AsyncValue.data([]);
      return;
    }

    if (query == _lastQuery) return;
    _lastQuery = query;

    state = const AsyncValue.loading();

    try {
      final results = await _repository.searchMulti(query);
      // Only update if this is still the current query
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

/// Provider for search state notifier
final searchNotifierProvider =
    StateNotifierProvider<SearchNotifier, AsyncValue<List<FilmModel>>>((ref) {
  final repository = ref.watch(movieRepositoryProvider);
  return SearchNotifier(repository);
});
