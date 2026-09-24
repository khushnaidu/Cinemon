/// A person page (ADR 0001, Phase 2): who they are and everything they've
/// worked on, from one TMDB `person/{id}?append_to_response=combined_credits`
/// call. Plain read-only classes, like `FilmExtras`.
class PersonPage {
  const PersonPage({
    required this.id,
    required this.name,
    this.profilePath,
    this.knownForDepartment,
    this.birthday,
    this.deathday,
    this.placeOfBirth,
    this.biography,
    this.credits = const [],
  });

  final int id;
  final String name;
  final String? profilePath;
  final String? knownForDepartment;
  final DateTime? birthday;
  final DateTime? deathday;
  final String? placeOfBirth;
  final String? biography;

  /// One entry per title per department: several jobs on the same film
  /// (Director, Screenplay) sit on one credit in each department.
  final List<PersonCredit> credits;

  /// The filmography tabs, in this order, and only those with credits.
  static const departments = ['Acting', 'Directing', 'Writing', 'Production'];

  static String departmentLabel(String department) =>
      department == 'Production' ? 'Producing' : department;

  List<String> get availableDepartments =>
      departments.where((d) => credits.any((c) => c.department == d)).toList();

  /// The department to open on: what they're known for, if it has credits.
  String? get defaultDepartment {
    final available = availableDepartments;
    if (available.isEmpty) return null;
    return available.contains(knownForDepartment)
        ? knownForDepartment
        : available.first;
  }

  /// Their best-known titles: the most-voted, one per title, with a poster.
  /// Talk shows, news and playing themselves are left out; a guest spot on
  /// a late-night show outvotes most films. So is anything unreleased or
  /// unrated, which nobody knows them for yet.
  List<PersonCredit> get knownFor {
    final now = DateTime.now();
    final seen = <String>{};
    final eligible = credits
        .where((c) =>
            c.posterPath != null &&
            !c.isAppearance &&
            c.voteCount > 0 &&
            c.date != null &&
            !c.date!.isAfter(now))
        .toList()
      ..sort((a, b) => b.voteCount.compareTo(a.voteCount));
    return eligible.where((c) => seen.add(c.titleKey)).take(10).toList();
  }

  /// Every title they're credited on, once. For "your history with them".
  Set<({int id, String mediaType})> get titles =>
      {for (final c in credits) (id: c.filmId, mediaType: c.mediaType)};

  /// One department's credits: undated and future titles first as
  /// "Upcoming", then released ones grouped by year, newest first.
  Filmography filmography(String department, {DateTime? now}) {
    final today = now ?? DateTime.now();
    final inDept = credits.where((c) => c.department == department).toList();

    final upcoming = inDept
        .where((c) => c.date == null || c.date!.isAfter(today))
        .toList()
      ..sort((a, b) =>
          (a.date ?? DateTime(9999)).compareTo(b.date ?? DateTime(9999)));

    final released = inDept
        .where((c) => c.date != null && !c.date!.isAfter(today))
        .toList()
      ..sort((a, b) => b.date!.compareTo(a.date!));

    final years = <int, List<PersonCredit>>{};
    for (final c in released) {
      (years[c.date!.year] ??= []).add(c);
    }
    return Filmography(
      upcoming: upcoming,
      years: years.entries.map((e) => (year: e.key, credits: e.value)).toList(),
    );
  }

  factory PersonPage.fromTmdb(Map<String, dynamic> json) {
    final combined = json['combined_credits'] as Map<String, dynamic>?;
    final merged = <String, PersonCredit>{};

    void add(Map<String, dynamic> raw, {required bool cast}) {
      final credit = PersonCredit.fromJson(raw, cast: cast);
      if (credit == null) return;
      final key = '${credit.department}:${credit.titleKey}';
      final existing = merged[key];
      merged[key] = existing == null ? credit : existing.mergedWith(credit);
    }

    for (final c in (combined?['cast'] as List? ?? const [])) {
      add(c as Map<String, dynamic>, cast: true);
    }
    for (final c in (combined?['crew'] as List? ?? const [])) {
      add(c as Map<String, dynamic>, cast: false);
    }

    return PersonPage(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      profilePath: json['profile_path'] as String?,
      knownForDepartment: json['known_for_department'] as String?,
      birthday: DateTime.tryParse(json['birthday'] as String? ?? ''),
      deathday: DateTime.tryParse(json['deathday'] as String? ?? ''),
      placeOfBirth: _blankToNull(json['place_of_birth'] as String?),
      biography: _blankToNull(json['biography'] as String?),
      credits: merged.values.toList(),
    );
  }
}

class Filmography {
  const Filmography({required this.upcoming, required this.years});

  final List<PersonCredit> upcoming;
  final List<({int year, List<PersonCredit> credits})> years;

  bool get isEmpty => upcoming.isEmpty && years.isEmpty;
}

class PersonCredit {
  const PersonCredit({
    required this.filmId,
    required this.mediaType,
    required this.title,
    required this.department,
    this.posterPath,
    this.date,
    this.voteCount = 0,
    this.roles = const [],
    this.episodeCount,
    this.genreIds = const [],
  });

  final int filmId;

  /// 'movie' or 'tv', as the rest of the app spells it.
  final String mediaType;
  final String title;

  /// 'Acting' for cast credits, TMDB's crew department otherwise.
  final String department;
  final String? posterPath;

  /// Release date, or first air date for a show.
  final DateTime? date;
  final int voteCount;

  /// Characters for acting, jobs for crew.
  final List<String> roles;

  /// Shows only: how many episodes they're in.
  final int? episodeCount;
  final List<int> genreIds;

  bool get isTv => mediaType == 'tv';
  String get titleKey => '$mediaType:$filmId';
  String? get year => date?.year.toString();

  /// "Walter White", "Director, Screenplay"; null when TMDB has no role.
  String? get roleLabel => roles.isEmpty ? null : roles.join(', ');

  static const _talk = 10767;
  static const _news = 10763;
  static final _self =
      RegExp(r'^(him|her|them)?sel(f|ves)\b', caseSensitive: false);

  /// Talk shows, news, and appearances as themselves.
  bool get isAppearance =>
      genreIds.contains(_talk) ||
      genreIds.contains(_news) ||
      (department == 'Acting' && roles.any(_self.hasMatch));

  PersonCredit mergedWith(PersonCredit other) => PersonCredit(
        filmId: filmId,
        mediaType: mediaType,
        title: title,
        department: department,
        posterPath: posterPath ?? other.posterPath,
        date: date ?? other.date,
        voteCount: voteCount,
        roles: {...roles, ...other.roles}.toList(),
        episodeCount: (episodeCount ?? 0) + (other.episodeCount ?? 0) == 0
            ? null
            : (episodeCount ?? 0) + (other.episodeCount ?? 0),
        genreIds: genreIds,
      );

  /// Null for anything that isn't a film or a show.
  static PersonCredit? fromJson(Map<String, dynamic> json,
      {required bool cast}) {
    final mediaType = json['media_type'];
    if (mediaType != 'movie' && mediaType != 'tv') return null;
    final title = (json['title'] ?? json['name']) as String?;
    if (title == null || title.isEmpty) return null;

    final role =
        _blankToNull((cast ? json['character'] : json['job']) as String?);
    return PersonCredit(
      filmId: json['id'] as int,
      mediaType: mediaType as String,
      title: title,
      department: cast ? 'Acting' : (json['department'] as String? ?? 'Crew'),
      posterPath: json['poster_path'] as String?,
      date: DateTime.tryParse(
          (json['release_date'] ?? json['first_air_date']) as String? ?? ''),
      voteCount: json['vote_count'] as int? ?? 0,
      roles: role == null ? const [] : [role],
      episodeCount: json['episode_count'] as int?,
      genreIds: (json['genre_ids'] as List? ?? const []).cast<int>(),
    );
  }
}

/// How the viewer's own logs overlap with a person's work.
class PersonHistory {
  const PersonHistory({required this.logged, this.averageRating});

  static const none = PersonHistory(logged: 0);

  /// Distinct titles of theirs you've logged.
  final int logged;

  /// Mean of your whole-title ratings, out of 5; null if you rated none.
  final double? averageRating;
}

String? _blankToNull(String? s) => (s == null || s.trim().isEmpty) ? null : s;
