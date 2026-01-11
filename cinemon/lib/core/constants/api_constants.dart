/// TMDB API Configuration
/// Get your API key from: https://www.themoviedb.org/settings/api
class ApiConstants {
  ApiConstants._();

  // TODO: Replace with your TMDB API key
  static const String tmdbApiKey = '9b0096cbe7fa89cf7eabcba8c5ba5a91';

  // Base URLs
  static const String tmdbBaseUrl = 'https://api.themoviedb.org/3';
  static const String tmdbImageBaseUrl = 'https://image.tmdb.org/t/p';

  // Image sizes
  static const String posterSizeSmall = '/w185';
  static const String posterSizeMedium = '/w342';
  static const String posterSizeLarge = '/w500';
  static const String posterSizeOriginal = '/original';
  static const String backdropSizeMedium = '/w780';
  static const String backdropSizeOriginal = '/original';
  static const String profileSizeMedium = '/w185';

  // Endpoints
  static const String searchMovie = '/search/movie';
  static const String searchTv = '/search/tv';
  static const String searchMulti = '/search/multi';
  static const String movieDetails = '/movie';
  static const String tvDetails = '/tv';
  static const String trendingMovies = '/trending/movie/week';
  static const String trendingTv = '/trending/tv/week';
  static const String popularMovies = '/movie/popular';
  static const String popularTv = '/tv/popular';
  static const String nowPlayingMovies = '/movie/now_playing';
  static const String upcomingMovies = '/movie/upcoming';
  static const String topRatedMovies = '/movie/top_rated';
  static const String movieCredits = '/movie/{id}/credits';
  static const String tvCredits = '/tv/{id}/credits';
  static const String movieGenres = '/genre/movie/list';
  static const String tvGenres = '/genre/tv/list';
  static const String searchPerson = '/search/person';
  static const String personDetails = '/person';

  // Helper methods
  static String getPosterUrl(String? path, {String size = posterSizeMedium}) {
    if (path == null || path.isEmpty) return '';
    return '$tmdbImageBaseUrl$size$path';
  }

  static String getBackdropUrl(String? path,
      {String size = backdropSizeMedium}) {
    if (path == null || path.isEmpty) return '';
    return '$tmdbImageBaseUrl$size$path';
  }

  static String getProfileUrl(String? path, {String size = profileSizeMedium}) {
    if (path == null || path.isEmpty) return '';
    return '$tmdbImageBaseUrl$size$path';
  }
}
