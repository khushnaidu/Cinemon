import 'package:dio/dio.dart';
import '../core/constants/api_constants.dart';
import '../models/film_model.dart';
import '../models/person_model.dart';

/// Repository for TMDB API operations.
///
/// Handles all movie and TV show data fetching from The Movie Database API.
class MovieRepository {
  final Dio _dio;

  MovieRepository({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: ApiConstants.tmdbBaseUrl,
              queryParameters: {
                'api_key': ApiConstants.tmdbApiKey,
              },
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
            ));

  /// Search for movies by query string
  Future<List<FilmModel>> searchMovies(String query, {int page = 1}) async {
    if (query.trim().isEmpty) return [];

    try {
      final response = await _dio.get(
        ApiConstants.searchMovie,
        queryParameters: {
          'query': query,
          'page': page,
          'include_adult': false,
        },
      );

      final results = response.data['results'] as List<dynamic>;
      return results
          .map((json) => FilmModel.fromJson({
                ...json as Map<String, dynamic>,
                'media_type': 'movie',
              }))
          .toList();
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Search for TV shows by query string
  Future<List<FilmModel>> searchTvShows(String query, {int page = 1}) async {
    if (query.trim().isEmpty) return [];

    try {
      final response = await _dio.get(
        ApiConstants.searchTv,
        queryParameters: {
          'query': query,
          'page': page,
          'include_adult': false,
        },
      );

      final results = response.data['results'] as List<dynamic>;
      return results
          .map((json) => FilmModel.fromJson({
                ...json as Map<String, dynamic>,
                'media_type': 'tv',
              }))
          .toList();
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Search for both movies and TV shows (multi search)
  Future<List<FilmModel>> searchMulti(String query, {int page = 1}) async {
    if (query.trim().isEmpty) return [];

    try {
      final response = await _dio.get(
        ApiConstants.searchMulti,
        queryParameters: {
          'query': query,
          'page': page,
          'include_adult': false,
        },
      );

      final results = response.data['results'] as List<dynamic>;
      // Filter out person results, only keep movie and tv
      return results
          .where((json) =>
              json['media_type'] == 'movie' || json['media_type'] == 'tv')
          .map((json) => FilmModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Get detailed movie information by ID
  Future<FilmModel> getMovieDetails(int movieId) async {
    try {
      final response = await _dio.get('${ApiConstants.movieDetails}/$movieId');

      return FilmModel.fromJson({
        ...response.data as Map<String, dynamic>,
        'media_type': 'movie',
      });
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Get detailed TV show information by ID
  Future<FilmModel> getTvDetails(int tvId) async {
    try {
      final response = await _dio.get('${ApiConstants.tvDetails}/$tvId');

      return FilmModel.fromJson({
        ...response.data as Map<String, dynamic>,
        'media_type': 'tv',
      });
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Get trending movies this week
  Future<List<FilmModel>> getTrendingMovies({int page = 1}) async {
    try {
      final response = await _dio.get(
        ApiConstants.trendingMovies,
        queryParameters: {'page': page},
      );

      final results = response.data['results'] as List<dynamic>;
      return results
          .map((json) => FilmModel.fromJson({
                ...json as Map<String, dynamic>,
                'media_type': 'movie',
              }))
          .toList();
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Get trending TV shows this week
  Future<List<FilmModel>> getTrendingTvShows({int page = 1}) async {
    try {
      final response = await _dio.get(
        ApiConstants.trendingTv,
        queryParameters: {'page': page},
      );

      final results = response.data['results'] as List<dynamic>;
      return results
          .map((json) => FilmModel.fromJson({
                ...json as Map<String, dynamic>,
                'media_type': 'tv',
              }))
          .toList();
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Get popular movies
  Future<List<FilmModel>> getPopularMovies({int page = 1}) async {
    try {
      final response = await _dio.get(
        ApiConstants.popularMovies,
        queryParameters: {'page': page},
      );

      final results = response.data['results'] as List<dynamic>;
      return results
          .map((json) => FilmModel.fromJson({
                ...json as Map<String, dynamic>,
                'media_type': 'movie',
              }))
          .toList();
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Get now playing movies in theaters
  Future<List<FilmModel>> getNowPlayingMovies({int page = 1}) async {
    try {
      final response = await _dio.get(
        ApiConstants.nowPlayingMovies,
        queryParameters: {'page': page},
      );

      final results = response.data['results'] as List<dynamic>;
      return results
          .map((json) => FilmModel.fromJson({
                ...json as Map<String, dynamic>,
                'media_type': 'movie',
              }))
          .toList();
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Get upcoming movies
  Future<List<FilmModel>> getUpcomingMovies({int page = 1}) async {
    try {
      final response = await _dio.get(
        ApiConstants.upcomingMovies,
        queryParameters: {'page': page},
      );

      final results = response.data['results'] as List<dynamic>;
      return results
          .map((json) => FilmModel.fromJson({
                ...json as Map<String, dynamic>,
                'media_type': 'movie',
              }))
          .toList();
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Get top rated movies
  Future<List<FilmModel>> getTopRatedMovies({int page = 1}) async {
    try {
      final response = await _dio.get(
        ApiConstants.topRatedMovies,
        queryParameters: {'page': page},
      );

      final results = response.data['results'] as List<dynamic>;
      return results
          .map((json) => FilmModel.fromJson({
                ...json as Map<String, dynamic>,
                'media_type': 'movie',
              }))
          .toList();
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Get movie genres list
  Future<List<GenreModel>> getMovieGenres() async {
    try {
      final response = await _dio.get(ApiConstants.movieGenres);

      final genres = response.data['genres'] as List<dynamic>;
      return genres
          .map((json) => GenreModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Get TV genres list
  Future<List<GenreModel>> getTvGenres() async {
    try {
      final response = await _dio.get(ApiConstants.tvGenres);

      final genres = response.data['genres'] as List<dynamic>;
      return genres
          .map((json) => GenreModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Get film by ID (auto-detects movie vs TV if mediaType provided)
  Future<FilmModel> getFilmDetails({
    required int id,
    required MediaType mediaType,
  }) async {
    if (mediaType == MediaType.movie) {
      return getMovieDetails(id);
    } else {
      return getTvDetails(id);
    }
  }

  /// Get multiple films by their IDs
  /// Tries to fetch as movie first, then TV if that fails
  /// Fetches each film in parallel for efficiency
  Future<List<FilmModel>> getFilmsByIds(List<int> ids) async {
    if (ids.isEmpty) return [];

    final List<FilmModel> results = [];

    for (final id in ids) {
      try {
        // Try as movie first
        final film = await getMovieDetails(id);
        results.add(film);
      } catch (_) {
        try {
          // If movie fails, try as TV show
          final tvShow = await getTvDetails(id);
          results.add(tvShow);
        } catch (_) {
          // Skip this ID if both fail
        }
      }
    }

    return results;
  }

  /// Search for people (actors, directors, etc.) by name
  Future<List<PersonModel>> searchPeople(String query, {int page = 1}) async {
    if (query.trim().isEmpty) return [];

    try {
      final response = await _dio.get(
        ApiConstants.searchPerson,
        queryParameters: {
          'query': query,
          'page': page,
          'include_adult': false,
        },
      );

      final results = response.data['results'] as List<dynamic>;
      return results
          .map((json) => PersonModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Get detailed information about a person by ID
  Future<PersonModel> getPersonDetails(int personId) async {
    try {
      final response = await _dio.get('${ApiConstants.personDetails}/$personId');

      return PersonModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Get multiple people by their IDs
  Future<List<PersonModel>> getPeopleByIds(List<int> ids) async {
    if (ids.isEmpty) return [];

    try {
      final futures = ids.map((id) => getPersonDetails(id));
      return await Future.wait(futures);
    } catch (e) {
      return [];
    }
  }

  /// Handle Dio errors and convert to user-friendly exceptions
  Exception _handleDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return Exception('Connection timed out. Please try again.');
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        if (statusCode == 401) {
          return Exception('Invalid API key. Please check your TMDB API key.');
        } else if (statusCode == 404) {
          return Exception('Content not found.');
        } else if (statusCode == 429) {
          return Exception('Too many requests. Please wait a moment.');
        }
        return Exception('Server error: $statusCode');
      case DioExceptionType.cancel:
        return Exception('Request cancelled.');
      case DioExceptionType.connectionError:
        return Exception('No internet connection.');
      default:
        return Exception('Something went wrong. Please try again.');
    }
  }
}
