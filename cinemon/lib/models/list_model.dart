/// Lists (migration 008): the watchlist now, playlists in Phase 4.
/// Plain read-only classes; writes go through `ListRepository` as maps.
enum ListVisibility {
  public('Public', 'Anyone on 35mm'),
  // Stored as 'friends'; since one-way follows (ADR 0004) it means your
  // approved followers.
  friends('Followers', 'People who follow you'),
  private('Only you', 'Nobody else can see it');

  const ListVisibility(this.label, this.detail);

  final String label;
  final String detail;

  static ListVisibility parse(String? s) => ListVisibility.values
      .firstWhere((v) => v.name == s, orElse: () => ListVisibility.public);
}

class FilmList {
  const FilmList({
    required this.id,
    required this.userId,
    required this.kind,
    this.title,
    this.description,
    this.visibility = ListVisibility.public,
    this.itemCount = 0,
    this.updatedAt,
  });

  final String id;
  final String userId;

  /// 'watchlist' or 'playlist'.
  final String kind;
  final String? title;
  final String? description;
  final ListVisibility visibility;
  final int itemCount;
  final DateTime? updatedAt;

  bool get isWatchlist => kind == 'watchlist';
  String get displayTitle => title ?? (isWatchlist ? 'Watchlist' : 'Untitled');

  factory FilmList.fromRow(Map<String, dynamic> row) => FilmList(
        id: row['id'] as String,
        userId: row['user_id'] as String,
        kind: row['kind'] as String,
        title: row['title'] as String?,
        description: row['description'] as String?,
        visibility: ListVisibility.parse(row['visibility'] as String?),
        itemCount: row['item_count'] as int? ?? 0,
        updatedAt: DateTime.tryParse(row['updated_at'] as String? ?? ''),
      );

  FilmList copyWith({ListVisibility? visibility, int? itemCount}) => FilmList(
        id: id,
        userId: userId,
        kind: kind,
        title: title,
        description: description,
        visibility: visibility ?? this.visibility,
        itemCount: itemCount ?? this.itemCount,
        updatedAt: updatedAt,
      );
}

/// A title on a list, with the film snapshotted at the time it was added.
class ListItem {
  const ListItem({
    required this.listId,
    required this.filmId,
    required this.mediaType,
    required this.title,
    this.posterPath,
    this.backdropPath,
    this.year,
    this.position = 0,
    this.note,
    this.watchedAt,
    this.addedAt,
  });

  final String listId;
  final int filmId;

  /// 'movie' or 'tv'.
  final String mediaType;
  final String title;
  final String? posterPath;
  final String? backdropPath;
  final String? year;
  final double position;
  final String? note;

  /// Struck off the watchlist.
  final DateTime? watchedAt;
  final DateTime? addedAt;

  bool get watched => watchedAt != null;
  bool get isTv => mediaType == 'tv';
  String get key => titleKey(filmId, mediaType);

  static String titleKey(int filmId, String mediaType) => '$mediaType:$filmId';

  factory ListItem.fromRow(Map<String, dynamic> row) => ListItem(
        listId: row['list_id'] as String,
        filmId: row['film_id'] as int,
        mediaType: row['media_type'] as String,
        title: row['film_title'] as String,
        posterPath: row['film_poster_path'] as String?,
        backdropPath: row['film_backdrop_path'] as String?,
        year: row['film_year'] as String?,
        position: (row['position'] as num?)?.toDouble() ?? 0,
        note: row['note'] as String?,
        watchedAt: DateTime.tryParse(row['watched_at'] as String? ?? ''),
        addedAt: DateTime.tryParse(row['added_at'] as String? ?? ''),
      );

  ListItem withPosition(double position) => ListItem(
        listId: listId,
        filmId: filmId,
        mediaType: mediaType,
        title: title,
        posterPath: posterPath,
        backdropPath: backdropPath,
        year: year,
        position: position,
        note: note,
        watchedAt: watchedAt,
        addedAt: addedAt,
      );

  ListItem withWatched(bool watched) => ListItem(
        listId: listId,
        filmId: filmId,
        mediaType: mediaType,
        title: title,
        posterPath: posterPath,
        backdropPath: backdropPath,
        year: year,
        position: position,
        note: note,
        watchedAt: watched ? DateTime.now() : null,
        addedAt: addedAt,
      );
}
