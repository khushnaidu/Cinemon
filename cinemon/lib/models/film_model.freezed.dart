// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'film_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

FilmModel _$FilmModelFromJson(Map<String, dynamic> json) {
  return _FilmModel.fromJson(json);
}

/// @nodoc
mixin _$FilmModel {
  /// TMDB unique identifier
  int get id => throw _privateConstructorUsedError;

  /// Movie title or TV show name
  /// TMDB uses 'title' for movies, 'name' for TV
  String? get title => throw _privateConstructorUsedError;
  String? get name => throw _privateConstructorUsedError;

  /// Original title (in original language)
  @JsonKey(name: 'original_title')
  String? get originalTitle => throw _privateConstructorUsedError;
  @JsonKey(name: 'original_name')
  String? get originalName => throw _privateConstructorUsedError;

  /// Plot overview/description
  String? get overview => throw _privateConstructorUsedError;

  /// Poster image path (append to base URL)
  @JsonKey(name: 'poster_path')
  String? get posterPath => throw _privateConstructorUsedError;

  /// Backdrop image path (append to base URL)
  @JsonKey(name: 'backdrop_path')
  String? get backdropPath => throw _privateConstructorUsedError;

  /// Release date for movies
  @JsonKey(name: 'release_date')
  String? get releaseDate => throw _privateConstructorUsedError;

  /// First air date for TV shows
  @JsonKey(name: 'first_air_date')
  String? get firstAirDate => throw _privateConstructorUsedError;

  /// TMDB user rating (0-10)
  @JsonKey(name: 'vote_average')
  double get voteAverage => throw _privateConstructorUsedError;

  /// Number of votes
  @JsonKey(name: 'vote_count')
  int get voteCount => throw _privateConstructorUsedError;

  /// Popularity score
  double get popularity => throw _privateConstructorUsedError;

  /// Genre IDs from TMDB
  @JsonKey(name: 'genre_ids')
  List<int> get genreIds => throw _privateConstructorUsedError;

  /// Original language code
  @JsonKey(name: 'original_language')
  String? get originalLanguage => throw _privateConstructorUsedError;

  /// Media type (movie or tv)
  @JsonKey(name: 'media_type')
  MediaType? get mediaType => throw _privateConstructorUsedError;

  /// Is adult content
  bool get adult => throw _privateConstructorUsedError;

  /// Runtime in minutes (for movies, from details endpoint)
  int? get runtime => throw _privateConstructorUsedError;

  /// Number of seasons (for TV, from details endpoint)
  @JsonKey(name: 'number_of_seasons')
  int? get numberOfSeasons => throw _privateConstructorUsedError;

  /// Number of episodes (for TV, from details endpoint)
  @JsonKey(name: 'number_of_episodes')
  int? get numberOfEpisodes => throw _privateConstructorUsedError;

  /// Tagline (from details endpoint)
  String? get tagline => throw _privateConstructorUsedError;

  /// Production status
  String? get status => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $FilmModelCopyWith<FilmModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FilmModelCopyWith<$Res> {
  factory $FilmModelCopyWith(FilmModel value, $Res Function(FilmModel) then) =
      _$FilmModelCopyWithImpl<$Res, FilmModel>;
  @useResult
  $Res call(
      {int id,
      String? title,
      String? name,
      @JsonKey(name: 'original_title') String? originalTitle,
      @JsonKey(name: 'original_name') String? originalName,
      String? overview,
      @JsonKey(name: 'poster_path') String? posterPath,
      @JsonKey(name: 'backdrop_path') String? backdropPath,
      @JsonKey(name: 'release_date') String? releaseDate,
      @JsonKey(name: 'first_air_date') String? firstAirDate,
      @JsonKey(name: 'vote_average') double voteAverage,
      @JsonKey(name: 'vote_count') int voteCount,
      double popularity,
      @JsonKey(name: 'genre_ids') List<int> genreIds,
      @JsonKey(name: 'original_language') String? originalLanguage,
      @JsonKey(name: 'media_type') MediaType? mediaType,
      bool adult,
      int? runtime,
      @JsonKey(name: 'number_of_seasons') int? numberOfSeasons,
      @JsonKey(name: 'number_of_episodes') int? numberOfEpisodes,
      String? tagline,
      String? status});
}

/// @nodoc
class _$FilmModelCopyWithImpl<$Res, $Val extends FilmModel>
    implements $FilmModelCopyWith<$Res> {
  _$FilmModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = freezed,
    Object? name = freezed,
    Object? originalTitle = freezed,
    Object? originalName = freezed,
    Object? overview = freezed,
    Object? posterPath = freezed,
    Object? backdropPath = freezed,
    Object? releaseDate = freezed,
    Object? firstAirDate = freezed,
    Object? voteAverage = null,
    Object? voteCount = null,
    Object? popularity = null,
    Object? genreIds = null,
    Object? originalLanguage = freezed,
    Object? mediaType = freezed,
    Object? adult = null,
    Object? runtime = freezed,
    Object? numberOfSeasons = freezed,
    Object? numberOfEpisodes = freezed,
    Object? tagline = freezed,
    Object? status = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as int,
      title: freezed == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String?,
      name: freezed == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String?,
      originalTitle: freezed == originalTitle
          ? _value.originalTitle
          : originalTitle // ignore: cast_nullable_to_non_nullable
              as String?,
      originalName: freezed == originalName
          ? _value.originalName
          : originalName // ignore: cast_nullable_to_non_nullable
              as String?,
      overview: freezed == overview
          ? _value.overview
          : overview // ignore: cast_nullable_to_non_nullable
              as String?,
      posterPath: freezed == posterPath
          ? _value.posterPath
          : posterPath // ignore: cast_nullable_to_non_nullable
              as String?,
      backdropPath: freezed == backdropPath
          ? _value.backdropPath
          : backdropPath // ignore: cast_nullable_to_non_nullable
              as String?,
      releaseDate: freezed == releaseDate
          ? _value.releaseDate
          : releaseDate // ignore: cast_nullable_to_non_nullable
              as String?,
      firstAirDate: freezed == firstAirDate
          ? _value.firstAirDate
          : firstAirDate // ignore: cast_nullable_to_non_nullable
              as String?,
      voteAverage: null == voteAverage
          ? _value.voteAverage
          : voteAverage // ignore: cast_nullable_to_non_nullable
              as double,
      voteCount: null == voteCount
          ? _value.voteCount
          : voteCount // ignore: cast_nullable_to_non_nullable
              as int,
      popularity: null == popularity
          ? _value.popularity
          : popularity // ignore: cast_nullable_to_non_nullable
              as double,
      genreIds: null == genreIds
          ? _value.genreIds
          : genreIds // ignore: cast_nullable_to_non_nullable
              as List<int>,
      originalLanguage: freezed == originalLanguage
          ? _value.originalLanguage
          : originalLanguage // ignore: cast_nullable_to_non_nullable
              as String?,
      mediaType: freezed == mediaType
          ? _value.mediaType
          : mediaType // ignore: cast_nullable_to_non_nullable
              as MediaType?,
      adult: null == adult
          ? _value.adult
          : adult // ignore: cast_nullable_to_non_nullable
              as bool,
      runtime: freezed == runtime
          ? _value.runtime
          : runtime // ignore: cast_nullable_to_non_nullable
              as int?,
      numberOfSeasons: freezed == numberOfSeasons
          ? _value.numberOfSeasons
          : numberOfSeasons // ignore: cast_nullable_to_non_nullable
              as int?,
      numberOfEpisodes: freezed == numberOfEpisodes
          ? _value.numberOfEpisodes
          : numberOfEpisodes // ignore: cast_nullable_to_non_nullable
              as int?,
      tagline: freezed == tagline
          ? _value.tagline
          : tagline // ignore: cast_nullable_to_non_nullable
              as String?,
      status: freezed == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$FilmModelImplCopyWith<$Res>
    implements $FilmModelCopyWith<$Res> {
  factory _$$FilmModelImplCopyWith(
          _$FilmModelImpl value, $Res Function(_$FilmModelImpl) then) =
      __$$FilmModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int id,
      String? title,
      String? name,
      @JsonKey(name: 'original_title') String? originalTitle,
      @JsonKey(name: 'original_name') String? originalName,
      String? overview,
      @JsonKey(name: 'poster_path') String? posterPath,
      @JsonKey(name: 'backdrop_path') String? backdropPath,
      @JsonKey(name: 'release_date') String? releaseDate,
      @JsonKey(name: 'first_air_date') String? firstAirDate,
      @JsonKey(name: 'vote_average') double voteAverage,
      @JsonKey(name: 'vote_count') int voteCount,
      double popularity,
      @JsonKey(name: 'genre_ids') List<int> genreIds,
      @JsonKey(name: 'original_language') String? originalLanguage,
      @JsonKey(name: 'media_type') MediaType? mediaType,
      bool adult,
      int? runtime,
      @JsonKey(name: 'number_of_seasons') int? numberOfSeasons,
      @JsonKey(name: 'number_of_episodes') int? numberOfEpisodes,
      String? tagline,
      String? status});
}

/// @nodoc
class __$$FilmModelImplCopyWithImpl<$Res>
    extends _$FilmModelCopyWithImpl<$Res, _$FilmModelImpl>
    implements _$$FilmModelImplCopyWith<$Res> {
  __$$FilmModelImplCopyWithImpl(
      _$FilmModelImpl _value, $Res Function(_$FilmModelImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = freezed,
    Object? name = freezed,
    Object? originalTitle = freezed,
    Object? originalName = freezed,
    Object? overview = freezed,
    Object? posterPath = freezed,
    Object? backdropPath = freezed,
    Object? releaseDate = freezed,
    Object? firstAirDate = freezed,
    Object? voteAverage = null,
    Object? voteCount = null,
    Object? popularity = null,
    Object? genreIds = null,
    Object? originalLanguage = freezed,
    Object? mediaType = freezed,
    Object? adult = null,
    Object? runtime = freezed,
    Object? numberOfSeasons = freezed,
    Object? numberOfEpisodes = freezed,
    Object? tagline = freezed,
    Object? status = freezed,
  }) {
    return _then(_$FilmModelImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as int,
      title: freezed == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String?,
      name: freezed == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String?,
      originalTitle: freezed == originalTitle
          ? _value.originalTitle
          : originalTitle // ignore: cast_nullable_to_non_nullable
              as String?,
      originalName: freezed == originalName
          ? _value.originalName
          : originalName // ignore: cast_nullable_to_non_nullable
              as String?,
      overview: freezed == overview
          ? _value.overview
          : overview // ignore: cast_nullable_to_non_nullable
              as String?,
      posterPath: freezed == posterPath
          ? _value.posterPath
          : posterPath // ignore: cast_nullable_to_non_nullable
              as String?,
      backdropPath: freezed == backdropPath
          ? _value.backdropPath
          : backdropPath // ignore: cast_nullable_to_non_nullable
              as String?,
      releaseDate: freezed == releaseDate
          ? _value.releaseDate
          : releaseDate // ignore: cast_nullable_to_non_nullable
              as String?,
      firstAirDate: freezed == firstAirDate
          ? _value.firstAirDate
          : firstAirDate // ignore: cast_nullable_to_non_nullable
              as String?,
      voteAverage: null == voteAverage
          ? _value.voteAverage
          : voteAverage // ignore: cast_nullable_to_non_nullable
              as double,
      voteCount: null == voteCount
          ? _value.voteCount
          : voteCount // ignore: cast_nullable_to_non_nullable
              as int,
      popularity: null == popularity
          ? _value.popularity
          : popularity // ignore: cast_nullable_to_non_nullable
              as double,
      genreIds: null == genreIds
          ? _value._genreIds
          : genreIds // ignore: cast_nullable_to_non_nullable
              as List<int>,
      originalLanguage: freezed == originalLanguage
          ? _value.originalLanguage
          : originalLanguage // ignore: cast_nullable_to_non_nullable
              as String?,
      mediaType: freezed == mediaType
          ? _value.mediaType
          : mediaType // ignore: cast_nullable_to_non_nullable
              as MediaType?,
      adult: null == adult
          ? _value.adult
          : adult // ignore: cast_nullable_to_non_nullable
              as bool,
      runtime: freezed == runtime
          ? _value.runtime
          : runtime // ignore: cast_nullable_to_non_nullable
              as int?,
      numberOfSeasons: freezed == numberOfSeasons
          ? _value.numberOfSeasons
          : numberOfSeasons // ignore: cast_nullable_to_non_nullable
              as int?,
      numberOfEpisodes: freezed == numberOfEpisodes
          ? _value.numberOfEpisodes
          : numberOfEpisodes // ignore: cast_nullable_to_non_nullable
              as int?,
      tagline: freezed == tagline
          ? _value.tagline
          : tagline // ignore: cast_nullable_to_non_nullable
              as String?,
      status: freezed == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$FilmModelImpl extends _FilmModel {
  const _$FilmModelImpl(
      {required this.id,
      this.title,
      this.name,
      @JsonKey(name: 'original_title') this.originalTitle,
      @JsonKey(name: 'original_name') this.originalName,
      this.overview,
      @JsonKey(name: 'poster_path') this.posterPath,
      @JsonKey(name: 'backdrop_path') this.backdropPath,
      @JsonKey(name: 'release_date') this.releaseDate,
      @JsonKey(name: 'first_air_date') this.firstAirDate,
      @JsonKey(name: 'vote_average') this.voteAverage = 0.0,
      @JsonKey(name: 'vote_count') this.voteCount = 0,
      this.popularity = 0.0,
      @JsonKey(name: 'genre_ids') final List<int> genreIds = const [],
      @JsonKey(name: 'original_language') this.originalLanguage,
      @JsonKey(name: 'media_type') this.mediaType,
      this.adult = false,
      this.runtime,
      @JsonKey(name: 'number_of_seasons') this.numberOfSeasons,
      @JsonKey(name: 'number_of_episodes') this.numberOfEpisodes,
      this.tagline,
      this.status})
      : _genreIds = genreIds,
        super._();

  factory _$FilmModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$FilmModelImplFromJson(json);

  /// TMDB unique identifier
  @override
  final int id;

  /// Movie title or TV show name
  /// TMDB uses 'title' for movies, 'name' for TV
  @override
  final String? title;
  @override
  final String? name;

  /// Original title (in original language)
  @override
  @JsonKey(name: 'original_title')
  final String? originalTitle;
  @override
  @JsonKey(name: 'original_name')
  final String? originalName;

  /// Plot overview/description
  @override
  final String? overview;

  /// Poster image path (append to base URL)
  @override
  @JsonKey(name: 'poster_path')
  final String? posterPath;

  /// Backdrop image path (append to base URL)
  @override
  @JsonKey(name: 'backdrop_path')
  final String? backdropPath;

  /// Release date for movies
  @override
  @JsonKey(name: 'release_date')
  final String? releaseDate;

  /// First air date for TV shows
  @override
  @JsonKey(name: 'first_air_date')
  final String? firstAirDate;

  /// TMDB user rating (0-10)
  @override
  @JsonKey(name: 'vote_average')
  final double voteAverage;

  /// Number of votes
  @override
  @JsonKey(name: 'vote_count')
  final int voteCount;

  /// Popularity score
  @override
  @JsonKey()
  final double popularity;

  /// Genre IDs from TMDB
  final List<int> _genreIds;

  /// Genre IDs from TMDB
  @override
  @JsonKey(name: 'genre_ids')
  List<int> get genreIds {
    if (_genreIds is EqualUnmodifiableListView) return _genreIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_genreIds);
  }

  /// Original language code
  @override
  @JsonKey(name: 'original_language')
  final String? originalLanguage;

  /// Media type (movie or tv)
  @override
  @JsonKey(name: 'media_type')
  final MediaType? mediaType;

  /// Is adult content
  @override
  @JsonKey()
  final bool adult;

  /// Runtime in minutes (for movies, from details endpoint)
  @override
  final int? runtime;

  /// Number of seasons (for TV, from details endpoint)
  @override
  @JsonKey(name: 'number_of_seasons')
  final int? numberOfSeasons;

  /// Number of episodes (for TV, from details endpoint)
  @override
  @JsonKey(name: 'number_of_episodes')
  final int? numberOfEpisodes;

  /// Tagline (from details endpoint)
  @override
  final String? tagline;

  /// Production status
  @override
  final String? status;

  @override
  String toString() {
    return 'FilmModel(id: $id, title: $title, name: $name, originalTitle: $originalTitle, originalName: $originalName, overview: $overview, posterPath: $posterPath, backdropPath: $backdropPath, releaseDate: $releaseDate, firstAirDate: $firstAirDate, voteAverage: $voteAverage, voteCount: $voteCount, popularity: $popularity, genreIds: $genreIds, originalLanguage: $originalLanguage, mediaType: $mediaType, adult: $adult, runtime: $runtime, numberOfSeasons: $numberOfSeasons, numberOfEpisodes: $numberOfEpisodes, tagline: $tagline, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FilmModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.originalTitle, originalTitle) ||
                other.originalTitle == originalTitle) &&
            (identical(other.originalName, originalName) ||
                other.originalName == originalName) &&
            (identical(other.overview, overview) ||
                other.overview == overview) &&
            (identical(other.posterPath, posterPath) ||
                other.posterPath == posterPath) &&
            (identical(other.backdropPath, backdropPath) ||
                other.backdropPath == backdropPath) &&
            (identical(other.releaseDate, releaseDate) ||
                other.releaseDate == releaseDate) &&
            (identical(other.firstAirDate, firstAirDate) ||
                other.firstAirDate == firstAirDate) &&
            (identical(other.voteAverage, voteAverage) ||
                other.voteAverage == voteAverage) &&
            (identical(other.voteCount, voteCount) ||
                other.voteCount == voteCount) &&
            (identical(other.popularity, popularity) ||
                other.popularity == popularity) &&
            const DeepCollectionEquality().equals(other._genreIds, _genreIds) &&
            (identical(other.originalLanguage, originalLanguage) ||
                other.originalLanguage == originalLanguage) &&
            (identical(other.mediaType, mediaType) ||
                other.mediaType == mediaType) &&
            (identical(other.adult, adult) || other.adult == adult) &&
            (identical(other.runtime, runtime) || other.runtime == runtime) &&
            (identical(other.numberOfSeasons, numberOfSeasons) ||
                other.numberOfSeasons == numberOfSeasons) &&
            (identical(other.numberOfEpisodes, numberOfEpisodes) ||
                other.numberOfEpisodes == numberOfEpisodes) &&
            (identical(other.tagline, tagline) || other.tagline == tagline) &&
            (identical(other.status, status) || other.status == status));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        id,
        title,
        name,
        originalTitle,
        originalName,
        overview,
        posterPath,
        backdropPath,
        releaseDate,
        firstAirDate,
        voteAverage,
        voteCount,
        popularity,
        const DeepCollectionEquality().hash(_genreIds),
        originalLanguage,
        mediaType,
        adult,
        runtime,
        numberOfSeasons,
        numberOfEpisodes,
        tagline,
        status
      ]);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$FilmModelImplCopyWith<_$FilmModelImpl> get copyWith =>
      __$$FilmModelImplCopyWithImpl<_$FilmModelImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$FilmModelImplToJson(
      this,
    );
  }
}

abstract class _FilmModel extends FilmModel {
  const factory _FilmModel(
      {required final int id,
      final String? title,
      final String? name,
      @JsonKey(name: 'original_title') final String? originalTitle,
      @JsonKey(name: 'original_name') final String? originalName,
      final String? overview,
      @JsonKey(name: 'poster_path') final String? posterPath,
      @JsonKey(name: 'backdrop_path') final String? backdropPath,
      @JsonKey(name: 'release_date') final String? releaseDate,
      @JsonKey(name: 'first_air_date') final String? firstAirDate,
      @JsonKey(name: 'vote_average') final double voteAverage,
      @JsonKey(name: 'vote_count') final int voteCount,
      final double popularity,
      @JsonKey(name: 'genre_ids') final List<int> genreIds,
      @JsonKey(name: 'original_language') final String? originalLanguage,
      @JsonKey(name: 'media_type') final MediaType? mediaType,
      final bool adult,
      final int? runtime,
      @JsonKey(name: 'number_of_seasons') final int? numberOfSeasons,
      @JsonKey(name: 'number_of_episodes') final int? numberOfEpisodes,
      final String? tagline,
      final String? status}) = _$FilmModelImpl;
  const _FilmModel._() : super._();

  factory _FilmModel.fromJson(Map<String, dynamic> json) =
      _$FilmModelImpl.fromJson;

  @override

  /// TMDB unique identifier
  int get id;
  @override

  /// Movie title or TV show name
  /// TMDB uses 'title' for movies, 'name' for TV
  String? get title;
  @override
  String? get name;
  @override

  /// Original title (in original language)
  @JsonKey(name: 'original_title')
  String? get originalTitle;
  @override
  @JsonKey(name: 'original_name')
  String? get originalName;
  @override

  /// Plot overview/description
  String? get overview;
  @override

  /// Poster image path (append to base URL)
  @JsonKey(name: 'poster_path')
  String? get posterPath;
  @override

  /// Backdrop image path (append to base URL)
  @JsonKey(name: 'backdrop_path')
  String? get backdropPath;
  @override

  /// Release date for movies
  @JsonKey(name: 'release_date')
  String? get releaseDate;
  @override

  /// First air date for TV shows
  @JsonKey(name: 'first_air_date')
  String? get firstAirDate;
  @override

  /// TMDB user rating (0-10)
  @JsonKey(name: 'vote_average')
  double get voteAverage;
  @override

  /// Number of votes
  @JsonKey(name: 'vote_count')
  int get voteCount;
  @override

  /// Popularity score
  double get popularity;
  @override

  /// Genre IDs from TMDB
  @JsonKey(name: 'genre_ids')
  List<int> get genreIds;
  @override

  /// Original language code
  @JsonKey(name: 'original_language')
  String? get originalLanguage;
  @override

  /// Media type (movie or tv)
  @JsonKey(name: 'media_type')
  MediaType? get mediaType;
  @override

  /// Is adult content
  bool get adult;
  @override

  /// Runtime in minutes (for movies, from details endpoint)
  int? get runtime;
  @override

  /// Number of seasons (for TV, from details endpoint)
  @JsonKey(name: 'number_of_seasons')
  int? get numberOfSeasons;
  @override

  /// Number of episodes (for TV, from details endpoint)
  @JsonKey(name: 'number_of_episodes')
  int? get numberOfEpisodes;
  @override

  /// Tagline (from details endpoint)
  String? get tagline;
  @override

  /// Production status
  String? get status;
  @override
  @JsonKey(ignore: true)
  _$$FilmModelImplCopyWith<_$FilmModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

GenreModel _$GenreModelFromJson(Map<String, dynamic> json) {
  return _GenreModel.fromJson(json);
}

/// @nodoc
mixin _$GenreModel {
  int get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $GenreModelCopyWith<GenreModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $GenreModelCopyWith<$Res> {
  factory $GenreModelCopyWith(
          GenreModel value, $Res Function(GenreModel) then) =
      _$GenreModelCopyWithImpl<$Res, GenreModel>;
  @useResult
  $Res call({int id, String name});
}

/// @nodoc
class _$GenreModelCopyWithImpl<$Res, $Val extends GenreModel>
    implements $GenreModelCopyWith<$Res> {
  _$GenreModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as int,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$GenreModelImplCopyWith<$Res>
    implements $GenreModelCopyWith<$Res> {
  factory _$$GenreModelImplCopyWith(
          _$GenreModelImpl value, $Res Function(_$GenreModelImpl) then) =
      __$$GenreModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({int id, String name});
}

/// @nodoc
class __$$GenreModelImplCopyWithImpl<$Res>
    extends _$GenreModelCopyWithImpl<$Res, _$GenreModelImpl>
    implements _$$GenreModelImplCopyWith<$Res> {
  __$$GenreModelImplCopyWithImpl(
      _$GenreModelImpl _value, $Res Function(_$GenreModelImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
  }) {
    return _then(_$GenreModelImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as int,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$GenreModelImpl implements _GenreModel {
  const _$GenreModelImpl({required this.id, required this.name});

  factory _$GenreModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$GenreModelImplFromJson(json);

  @override
  final int id;
  @override
  final String name;

  @override
  String toString() {
    return 'GenreModel(id: $id, name: $name)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$GenreModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, id, name);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$GenreModelImplCopyWith<_$GenreModelImpl> get copyWith =>
      __$$GenreModelImplCopyWithImpl<_$GenreModelImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$GenreModelImplToJson(
      this,
    );
  }
}

abstract class _GenreModel implements GenreModel {
  const factory _GenreModel(
      {required final int id, required final String name}) = _$GenreModelImpl;

  factory _GenreModel.fromJson(Map<String, dynamic> json) =
      _$GenreModelImpl.fromJson;

  @override
  int get id;
  @override
  String get name;
  @override
  @JsonKey(ignore: true)
  _$$GenreModelImplCopyWith<_$GenreModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
