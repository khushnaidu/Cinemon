import 'film_model.dart';

/// Which list the Trailers tab is showing.
enum TrailerFeed {
  trending('trending'),
  latest('latest');

  const TrailerFeed(this.value);
  final String value;
}

/// One page of the Trailers tab: a trailer and the title it's for, as the
/// database's feed job left it (migration 013).
class TrailerItem {
  const TrailerItem({
    required this.rank,
    required this.mediaType,
    required this.tmdbId,
    required this.videoId,
    required this.title,
    this.videoTitle,
    this.category,
    this.publishedAt,
    this.posterPath,
    this.backdropPath,
    this.year,
    this.genreIds = const [],
  });

  final int rank;
  final MediaType mediaType;
  final int tmdbId;

  /// The YouTube video id.
  final String videoId;
  final String title;

  /// The video's own name on YouTube, like "Official Trailer 2".
  final String? videoTitle;

  /// Trailer, Teaser, Clip or Featurette.
  final String? category;
  final DateTime? publishedAt;
  final String? posterPath;
  final String? backdropPath;
  final int? year;
  final List<int> genreIds;

  bool get isTv => mediaType == MediaType.tv;

  String get thumbnailUrl => 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';

  /// Enough of a film for the watchlist and Add to…, which only need the
  /// id, type, title, year and poster.
  FilmModel get film => FilmModel(
        id: tmdbId,
        title: isTv ? null : title,
        name: isTv ? title : null,
        posterPath: posterPath,
        backdropPath: backdropPath,
        releaseDate: !isTv && year != null ? '$year-01-01' : null,
        firstAirDate: isTv && year != null ? '$year-01-01' : null,
        genreIds: genreIds,
        mediaType: mediaType,
      );

  factory TrailerItem.fromRow(Map<String, dynamic> row) => TrailerItem(
        rank: (row['rank'] as num).toInt(),
        mediaType: row['media_type'] == 'tv' ? MediaType.tv : MediaType.movie,
        tmdbId: (row['tmdb_id'] as num).toInt(),
        videoId: row['video_id'] as String,
        title: row['title'] as String,
        videoTitle: row['video_title'] as String?,
        category: row['category'] as String?,
        publishedAt: DateTime.tryParse(row['published_at'] as String? ?? ''),
        posterPath: row['poster_path'] as String?,
        backdropPath: row['backdrop_path'] as String?,
        year: (row['year'] as num?)?.toInt(),
        genreIds: [
          for (final g in (row['genre_ids'] as List?) ?? const [])
            (g as num).toInt()
        ],
      );
}
