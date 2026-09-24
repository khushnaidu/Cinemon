/// Everything on a film page beyond the basic details: trailers, cast, where
/// to watch, and whether it's in cinemas. Parsed from the `append_to_response`
/// parts of one TMDB details call (ADR 0001, D1).
///
/// Kept apart from `FilmModel` so that freezed model doesn't grow a dozen
/// nullable fields that only this one screen reads. Plain classes, read-only,
/// never serialised back.
class FilmExtras {
  const FilmExtras({
    this.videos = const [],
    this.cast = const [],
    this.directors = const [],
    this.watch,
    this.theatrical = const TheatricalStatus.none(),
  });

  static const empty = FilmExtras();

  /// YouTube videos only; other hosts can't be played in the app.
  final List<FilmVideo> videos;
  final List<CastMember> cast;

  /// Directors for a film, creators for a show.
  final List<CrewMember> directors;

  /// Null when TMDB has nothing for the region.
  final WatchProviders? watch;
  final TheatricalStatus theatrical;

  /// The one video to put on the page: an official trailer, else any
  /// trailer, else a teaser. Newest first within each.
  FilmVideo? get trailer {
    FilmVideo? pick(bool Function(FilmVideo v) test) {
      final matches = videos.where(test).toList()
        ..sort((a, b) => (b.publishedAt ?? DateTime(0))
            .compareTo(a.publishedAt ?? DateTime(0)));
      return matches.isEmpty ? null : matches.first;
    }

    return pick((v) => v.type == 'Trailer' && v.official) ??
        pick((v) => v.type == 'Trailer') ??
        pick((v) => v.type == 'Teaser');
  }

  factory FilmExtras.fromTmdb(
    Map<String, dynamic> json, {
    required bool isTv,
    required String region,
    DateTime? now,
  }) {
    final videos = ((json['videos'] as Map?)?['results'] as List? ?? const [])
        .cast<Map<String, dynamic>>()
        .where((v) => v['site'] == 'YouTube' && v['key'] != null)
        .map(FilmVideo.fromJson)
        .toList();

    final List<CastMember> cast;
    final List<CrewMember> directors;
    if (isTv) {
      final credits = json['aggregate_credits'] as Map<String, dynamic>?;
      cast = (credits?['cast'] as List? ?? const [])
          .cast<Map<String, dynamic>>()
          .map(CastMember.fromAggregate)
          .toList();
      directors = (json['created_by'] as List? ?? const [])
          .cast<Map<String, dynamic>>()
          .map((c) => CrewMember.fromJson(c, job: 'Creator'))
          .toList();
    } else {
      final credits = json['credits'] as Map<String, dynamic>?;
      cast = (credits?['cast'] as List? ?? const [])
          .cast<Map<String, dynamic>>()
          .map(CastMember.fromJson)
          .toList();
      directors = (credits?['crew'] as List? ?? const [])
          .cast<Map<String, dynamic>>()
          .where((c) => c['job'] == 'Director')
          .map((c) => CrewMember.fromJson(c, job: 'Director'))
          .toList();
    }
    cast.sort((a, b) => a.order.compareTo(b.order));

    final byRegion =
        ((json['watch/providers'] as Map?)?['results'] as Map?)?[region];
    final watch = byRegion is Map<String, dynamic>
        ? WatchProviders.fromJson(byRegion)
        : null;

    return FilmExtras(
      videos: videos,
      cast: cast,
      directors: directors,
      watch: watch == null || watch.isEmpty ? null : watch,
      theatrical: isTv
          ? const TheatricalStatus.none()
          : TheatricalStatus.fromReleaseDates(
              json['release_dates'] as Map<String, dynamic>?,
              region: region,
              now: now ?? DateTime.now(),
            ),
    );
  }
}

class FilmVideo {
  const FilmVideo({
    required this.key,
    required this.name,
    required this.type,
    this.official = false,
    this.publishedAt,
  });

  /// The YouTube video id.
  final String key;
  final String name;

  /// Trailer, Teaser, Clip, Featurette, Behind the Scenes, Bloopers.
  final String type;
  final bool official;
  final DateTime? publishedAt;

  String get thumbnailUrl => 'https://img.youtube.com/vi/$key/hqdefault.jpg';

  factory FilmVideo.fromJson(Map<String, dynamic> json) => FilmVideo(
        key: json['key'] as String,
        name: json['name'] as String? ?? '',
        type: json['type'] as String? ?? '',
        official: json['official'] as bool? ?? false,
        publishedAt: DateTime.tryParse(json['published_at'] as String? ?? ''),
      );
}

class CastMember {
  const CastMember({
    required this.id,
    required this.name,
    this.character,
    this.profilePath,
    this.order = 999,
  });

  final int id;
  final String name;
  final String? character;
  final String? profilePath;
  final int order;

  factory CastMember.fromJson(Map<String, dynamic> json) => CastMember(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        character: _blankToNull(json['character'] as String?),
        profilePath: json['profile_path'] as String?,
        order: json['order'] as int? ?? 999,
      );

  /// A show's cast lists every role across all seasons; the first is the
  /// one they're known for.
  factory CastMember.fromAggregate(Map<String, dynamic> json) {
    final roles = (json['roles'] as List? ?? const []).cast<Map>();
    return CastMember(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      character: roles.isEmpty
          ? null
          : _blankToNull(roles.first['character'] as String?),
      profilePath: json['profile_path'] as String?,
      order: json['order'] as int? ?? 999,
    );
  }
}

class CrewMember {
  const CrewMember({
    required this.id,
    required this.name,
    required this.job,
    this.profilePath,
  });

  final int id;
  final String name;
  final String job;
  final String? profilePath;

  factory CrewMember.fromJson(Map<String, dynamic> json, {required String job}) =>
      CrewMember(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        job: job,
        profilePath: json['profile_path'] as String?,
      );
}

class WatchProvider {
  const WatchProvider({
    required this.id,
    required this.name,
    this.logoPath,
    this.priority = 999,
  });

  final int id;
  final String name;
  final String? logoPath;
  final int priority;

  factory WatchProvider.fromJson(Map<String, dynamic> json) => WatchProvider(
        id: json['provider_id'] as int,
        name: json['provider_name'] as String? ?? '',
        logoPath: json['logo_path'] as String?,
        priority: json['display_priority'] as int? ?? 999,
      );
}

/// One region's providers, from JustWatch via TMDB. JustWatch must be
/// credited wherever these are shown.
class WatchProviders {
  const WatchProviders({
    this.link,
    this.stream = const [],
    this.free = const [],
    this.rent = const [],
    this.buy = const [],
  });

  /// TMDB's watch page for the title (it links on to JustWatch). TMDB gives
  /// no per-service deep links.
  final String? link;

  /// Subscription services.
  final List<WatchProvider> stream;

  /// Free and free-with-ads.
  final List<WatchProvider> free;
  final List<WatchProvider> rent;
  final List<WatchProvider> buy;

  bool get isEmpty =>
      stream.isEmpty && free.isEmpty && rent.isEmpty && buy.isEmpty;

  /// Services you can watch it on without paying per title, for the row on
  /// the page.
  List<WatchProvider> get included => _dedupe([...stream, ...free]);

  /// Rent and buy together, a service once, for the quieter second group.
  List<WatchProvider> get paid => _dedupe([...rent, ...buy]);

  factory WatchProviders.fromJson(Map<String, dynamic> json) {
    List<WatchProvider> list(String key) =>
        (json[key] as List? ?? const [])
            .cast<Map<String, dynamic>>()
            .map(WatchProvider.fromJson)
            .toList()
          ..sort((a, b) => a.priority.compareTo(b.priority));

    return WatchProviders(
      link: json['link'] as String?,
      stream: list('flatrate'),
      free: _dedupe([...list('free'), ...list('ads')]),
      rent: list('rent'),
      buy: list('buy'),
    );
  }

  static List<WatchProvider> _dedupe(List<WatchProvider> all) {
    final seen = <int>{};
    return all.where((p) => seen.add(p.id)).toList();
  }
}

enum TheatricalPhase { none, inTheaters, comingSoon }

/// Whether a film is in cinemas in the viewer's region, from TMDB release
/// dates.
class TheatricalStatus {
  const TheatricalStatus._(this.phase, this.date);
  const TheatricalStatus.none() : this._(TheatricalPhase.none, null);

  final TheatricalPhase phase;

  /// The theatrical date: when it opened, or when it opens.
  final DateTime? date;

  /// How long after opening a film still counts as "in theaters" when no
  /// digital release has been announced.
  static const window = Duration(days: 75);

  /// In theaters: a theatrical release (type 2 limited or 3 wide) opened in
  /// the last [window] days and it hasn't come out digitally (type 4) since.
  /// Coming soon: the next theatrical date is in the future.
  factory TheatricalStatus.fromReleaseDates(
    Map<String, dynamic>? json, {
    required String region,
    required DateTime now,
  }) {
    final regions = (json?['results'] as List? ?? const []).cast<Map>();
    final mine = regions.where((r) => r['iso_3166_1'] == region).toList();
    if (mine.isEmpty) return const TheatricalStatus.none();

    final dates = (mine.first['release_dates'] as List? ?? const [])
        .cast<Map>()
        .map((d) => (
              type: d['type'] as int? ?? 0,
              at: DateTime.tryParse(d['release_date'] as String? ?? ''),
            ))
        .where((d) => d.at != null)
        .toList();

    final theatrical = dates.where((d) => d.type == 2 || d.type == 3).toList()
      ..sort((a, b) => a.at!.compareTo(b.at!));
    if (theatrical.isEmpty) return const TheatricalStatus.none();

    final opened = theatrical.where((d) => !d.at!.isAfter(now)).toList();
    if (opened.isNotEmpty) {
      final latest = opened.last.at!;
      final digitalSince = dates.any((d) =>
          d.type == 4 && !d.at!.isAfter(now) && !d.at!.isBefore(latest));
      if (now.difference(latest) <= window && !digitalSince) {
        return TheatricalStatus._(TheatricalPhase.inTheaters, latest);
      }
    }

    final upcoming = theatrical.where((d) => d.at!.isAfter(now)).toList();
    if (upcoming.isNotEmpty) {
      return TheatricalStatus._(TheatricalPhase.comingSoon, upcoming.first.at);
    }
    return const TheatricalStatus.none();
  }
}

String? _blankToNull(String? s) => (s == null || s.trim().isEmpty) ? null : s;
