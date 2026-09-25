import 'film_model.dart' show MediaType;

/// A TMDB genre as Discover shows it.
typedef Genre = ({int id, String name});

/// The genres Discover can narrow to, the same ones the database asks TMDB
/// about (migration 027, `trailer_genres`). Films and shows have their own:
/// TMDB's TV list folds Sci-Fi into Fantasy and Action into Adventure.
const kMovieGenres = <Genre>[
  (id: 28, name: 'Action'),
  (id: 12, name: 'Adventure'),
  (id: 16, name: 'Animation'),
  (id: 35, name: 'Comedy'),
  (id: 80, name: 'Crime'),
  (id: 99, name: 'Documentary'),
  (id: 18, name: 'Drama'),
  (id: 10751, name: 'Family'),
  (id: 14, name: 'Fantasy'),
  (id: 36, name: 'History'),
  (id: 27, name: 'Horror'),
  (id: 10402, name: 'Music'),
  (id: 9648, name: 'Mystery'),
  (id: 10749, name: 'Romance'),
  (id: 878, name: 'Sci-Fi'),
  (id: 53, name: 'Thriller'),
  (id: 10752, name: 'War'),
  (id: 37, name: 'Western'),
];

const kTvGenres = <Genre>[
  (id: 10759, name: 'Action & Adventure'),
  (id: 16, name: 'Animation'),
  (id: 35, name: 'Comedy'),
  (id: 80, name: 'Crime'),
  (id: 99, name: 'Documentary'),
  (id: 18, name: 'Drama'),
  (id: 10751, name: 'Family'),
  (id: 10762, name: 'Kids'),
  (id: 9648, name: 'Mystery'),
  (id: 10765, name: 'Sci-Fi & Fantasy'),
  (id: 10768, name: 'War & Politics'),
  (id: 37, name: 'Western'),
];

/// The few shown as buttons; the rest are behind the filter.
const _popularMovie = [28, 35, 27, 53, 878, 10749, 99, 16];
const _popularTv = [18, 35, 80, 10765, 10759, 99, 9648, 16];

List<Genre> genresFor(MediaType type) =>
    type == MediaType.tv ? kTvGenres : kMovieGenres;

List<Genre> popularGenresFor(MediaType type) {
  final all = genresFor(type);
  return [
    for (final id in type == MediaType.tv ? _popularTv : _popularMovie)
      all.firstWhere((g) => g.id == id),
  ];
}

Genre? genreById(MediaType type, int? id) {
  if (id == null) return null;
  for (final g in genresFor(type)) {
    if (g.id == id) return g;
  }
  return null;
}
