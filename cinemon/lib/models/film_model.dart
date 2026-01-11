import 'package:freezed_annotation/freezed_annotation.dart';
import '../core/constants/api_constants.dart';

part 'film_model.freezed.dart';
part 'film_model.g.dart';

/// Type of media from TMDB
enum MediaType {
  @JsonValue('movie')
  movie,
  @JsonValue('tv')
  tv,
}

/// Represents a movie or TV show from TMDB API.
///
/// Contains all relevant film data for display and storage.
/// Uses Freezed for immutability and automatic JSON serialization.
@freezed
class FilmModel with _$FilmModel {
  const FilmModel._();

  const factory FilmModel({
    /// TMDB unique identifier
    required int id,

    /// Movie title or TV show name
    /// TMDB uses 'title' for movies, 'name' for TV
    String? title,
    String? name,

    /// Original title (in original language)
    @JsonKey(name: 'original_title') String? originalTitle,
    @JsonKey(name: 'original_name') String? originalName,

    /// Plot overview/description
    String? overview,

    /// Poster image path (append to base URL)
    @JsonKey(name: 'poster_path') String? posterPath,

    /// Backdrop image path (append to base URL)
    @JsonKey(name: 'backdrop_path') String? backdropPath,

    /// Release date for movies
    @JsonKey(name: 'release_date') String? releaseDate,

    /// First air date for TV shows
    @JsonKey(name: 'first_air_date') String? firstAirDate,

    /// TMDB user rating (0-10)
    @JsonKey(name: 'vote_average') @Default(0.0) double voteAverage,

    /// Number of votes
    @JsonKey(name: 'vote_count') @Default(0) int voteCount,

    /// Popularity score
    @Default(0.0) double popularity,

    /// Genre IDs from TMDB
    @JsonKey(name: 'genre_ids') @Default([]) List<int> genreIds,

    /// Original language code
    @JsonKey(name: 'original_language') String? originalLanguage,

    /// Media type (movie or tv)
    @JsonKey(name: 'media_type') MediaType? mediaType,

    /// Is adult content
    @Default(false) bool adult,

    /// Runtime in minutes (for movies, from details endpoint)
    int? runtime,

    /// Number of seasons (for TV, from details endpoint)
    @JsonKey(name: 'number_of_seasons') int? numberOfSeasons,

    /// Number of episodes (for TV, from details endpoint)
    @JsonKey(name: 'number_of_episodes') int? numberOfEpisodes,

    /// Tagline (from details endpoint)
    String? tagline,

    /// Production status
    String? status,
  }) = _FilmModel;

  /// Creates a FilmModel from TMDB JSON response
  factory FilmModel.fromJson(Map<String, dynamic> json) =>
      _$FilmModelFromJson(json);

  /// Get the display title (works for both movies and TV)
  String get displayTitle => title ?? name ?? 'Unknown';

  /// Get the original display title
  String get displayOriginalTitle => originalTitle ?? originalName ?? displayTitle;

  /// Get the release/air date string
  String? get displayDate => releaseDate ?? firstAirDate;

  /// Get the release year
  String? get year {
    final date = displayDate;
    if (date == null || date.isEmpty) return null;
    return date.split('-').first;
  }

  /// Get full poster URL
  String get posterUrl => ApiConstants.getPosterUrl(posterPath);

  /// Get large poster URL
  String get posterUrlLarge => ApiConstants.getPosterUrl(
        posterPath,
        size: ApiConstants.posterSizeLarge,
      );

  /// Get full backdrop URL
  String get backdropUrl => ApiConstants.getBackdropUrl(backdropPath);

  /// Check if this is a movie
  bool get isMovie => mediaType == MediaType.movie || title != null;

  /// Check if this is a TV show
  bool get isTv => mediaType == MediaType.tv || name != null;

  /// Get formatted runtime (e.g., "2h 15m")
  String? get formattedRuntime {
    if (runtime == null) return null;
    final hours = runtime! ~/ 60;
    final minutes = runtime! % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }
}

/// Genre model for TMDB genres
@freezed
class GenreModel with _$GenreModel {
  const factory GenreModel({
    required int id,
    required String name,
  }) = _GenreModel;

  factory GenreModel.fromJson(Map<String, dynamic> json) =>
      _$GenreModelFromJson(json);
}
