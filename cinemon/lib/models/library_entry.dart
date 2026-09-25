/// A film or show in someone's library (migration 024): seen, whether or not
/// they posted about it.
class LibraryEntry {
  const LibraryEntry({
    required this.filmId,
    required this.mediaType,
    required this.title,
    required this.addedAt,
    this.posterPath,
    this.year,
  });

  factory LibraryEntry.fromRow(Map<String, dynamic> row) => LibraryEntry(
        filmId: row['film_id'] as int,
        mediaType: row['media_type'] as String,
        title: row['film_title'] as String,
        posterPath: row['film_poster_path'] as String?,
        year: row['film_year'] as String?,
        addedAt: DateTime.parse(row['added_at'] as String),
      );

  final int filmId;

  /// 'movie' or 'tv'.
  final String mediaType;
  final String title;
  final String? posterPath;
  final String? year;
  final DateTime addedAt;

  bool get isTv => mediaType == 'tv';

  /// Same shape as ListItem.titleKey, so the two can be compared.
  String get key => keyFor(filmId, mediaType);

  static String keyFor(int filmId, String mediaType) => '$mediaType:$filmId';
}
