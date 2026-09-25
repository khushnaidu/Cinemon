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

/// How a playlist's cover is drawn (migration 029).
enum ListCoverStyle {
  /// The first six posters side by side. The default.
  strip,

  /// One film the curator picked: its poster, or for a Select, a still.
  film,

  /// Our own artwork. 35mm Selects only.
  artwork;

  static ListCoverStyle parse(String? s) => ListCoverStyle.values
      .firstWhere((v) => v.name == s, orElse: () => ListCoverStyle.strip);
}

/// The moods a playlist can have, up to three (migration 029,
/// `list_moods()`). The slugs are what's stored.
enum ListMood {
  slowBurn('slow_burn', 'Slow-burn'),
  tender('tender', 'Tender'),
  neon('neon', 'Neon'),
  epic('epic', 'Epic'),
  unsettling('unsettling', 'Unsettling'),
  rainyDay('rainy_day', 'Rainy day'),
  sunlit('sunlit', 'Sunlit'),
  lateNight('late_night', 'Late night'),
  funny('funny', 'Funny'),
  heartbreaking('heartbreaking', 'Heartbreaking'),
  mindBending('mind_bending', 'Mind-bending'),
  cozy('cozy', 'Cozy');

  const ListMood(this.slug, this.label);

  final String slug;
  final String label;

  static const maxPerList = 3;

  static ListMood? parse(String? slug) {
    for (final m in values) {
      if (m.slug == slug) return m;
    }
    return null;
  }
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
    this.saveCount = 0,
    this.updatedAt,
    this.coverStyle = ListCoverStyle.strip,
    this.coverPath,
    this.coverUrl,
    this.moods = const [],
    this.isSelect = false,
    this.tagline,
  });

  final String id;
  final String userId;

  /// 'watchlist' or 'playlist'.
  final String kind;
  final String? title;
  final String? description;
  final ListVisibility visibility;
  final int itemCount;
  final int saveCount;
  final DateTime? updatedAt;

  final ListCoverStyle coverStyle;

  /// A TMDB image path for a one-film cover: a poster, or a backdrop on a
  /// Select.
  final String? coverPath;

  /// The artwork's address, for a Select with its own.
  final String? coverUrl;
  final List<ListMood> moods;

  /// One of ours: a 35mm Select.
  final bool isSelect;

  /// A Select's one line, under its title.
  final String? tagline;

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
        saveCount: row['save_count'] as int? ?? 0,
        updatedAt: DateTime.tryParse(row['updated_at'] as String? ?? ''),
        coverStyle: ListCoverStyle.parse(row['cover_style'] as String?),
        coverPath: row['cover_path'] as String?,
        coverUrl: row['cover_url'] as String?,
        moods: [
          for (final m in (row['moods'] as List?) ?? const [])
            if (ListMood.parse(m as String?) case final mood?) mood,
        ],
        isSelect: row['is_select'] as bool? ?? false,
        tagline: row['tagline'] as String?,
      );

  FilmList copyWith({ListVisibility? visibility, int? itemCount}) => FilmList(
        id: id,
        userId: userId,
        kind: kind,
        title: title,
        description: description,
        visibility: visibility ?? this.visibility,
        itemCount: itemCount ?? this.itemCount,
        saveCount: saveCount,
        updatedAt: updatedAt,
        coverStyle: coverStyle,
        coverPath: coverPath,
        coverUrl: coverUrl,
        moods: moods,
        isSelect: isSelect,
        tagline: tagline,
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

/// A playlist as Explore › Lists shows it: the list, who made it, and its
/// first posters (migration 029, `explore_lists`).
class ExploreListEntry {
  const ExploreListEntry({
    required this.list,
    this.ownerUsername,
    this.weekSaves = 0,
    this.posters = const [],
  });

  final FilmList list;
  final String? ownerUsername;

  /// Saves in the last seven days, which rank the community lists.
  final int weekSaves;

  /// Up to six poster paths, in list order.
  final List<String> posters;

  factory ExploreListEntry.fromRow(Map<String, dynamic> row) =>
      ExploreListEntry(
        list: FilmList.fromRow(row),
        ownerUsername: row['owner_username'] as String?,
        weekSaves: row['week_saves'] as int? ?? 0,
        posters: [
          for (final p in (row['posters'] as List?) ?? const [])
            if (p is String) p,
        ],
      );
}
