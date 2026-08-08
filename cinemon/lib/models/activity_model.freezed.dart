// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'activity_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

ActivityModel _$ActivityModelFromJson(Map<String, dynamic> json) {
  return _ActivityModel.fromJson(json);
}

/// @nodoc
mixin _$ActivityModel {
  /// Unique activity ID (Firestore document ID)
  String get id => throw _privateConstructorUsedError;

  /// User ID who created this activity
  String get userId => throw _privateConstructorUsedError;

  /// Username for display (denormalized for performance)
  String get username => throw _privateConstructorUsedError;

  /// User's profile photo URL (denormalized)
  String? get userPhotoUrl => throw _privateConstructorUsedError;

  /// Type of activity (watched or reviewed)
  ActivityType get activityType => throw _privateConstructorUsedError;

  /// TMDB film ID
  int get filmId => throw _privateConstructorUsedError;

  /// Film title (denormalized for display)
  String get filmTitle => throw _privateConstructorUsedError;

  /// Film poster path from TMDB
  String? get filmPosterPath => throw _privateConstructorUsedError;

  /// Film backdrop path from TMDB
  String? get filmBackdropPath => throw _privateConstructorUsedError;

  /// Film release year
  String? get filmYear => throw _privateConstructorUsedError;

  /// Media type (movie or tv)
  String get mediaType => throw _privateConstructorUsedError;

  /// User's rating (0-5 stars, nullable if just "watched")
  double? get rating => throw _privateConstructorUsedError;

  /// User's review text (nullable)
  String? get reviewText => throw _privateConstructorUsedError;

  /// When this activity was created
  DateTime get createdAt => throw _privateConstructorUsedError;

  /// User IDs who liked this activity
  List<String> get likes => throw _privateConstructorUsedError;

  /// Number of comments (denormalized count)
  int get commentCount => throw _privateConstructorUsedError;

  /// Reactions map: userId -> stickerId
  /// Each user can only have one reaction per activity
  Map<String, String> get reactions => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $ActivityModelCopyWith<ActivityModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ActivityModelCopyWith<$Res> {
  factory $ActivityModelCopyWith(
          ActivityModel value, $Res Function(ActivityModel) then) =
      _$ActivityModelCopyWithImpl<$Res, ActivityModel>;
  @useResult
  $Res call(
      {String id,
      String userId,
      String username,
      String? userPhotoUrl,
      ActivityType activityType,
      int filmId,
      String filmTitle,
      String? filmPosterPath,
      String? filmBackdropPath,
      String? filmYear,
      String mediaType,
      double? rating,
      String? reviewText,
      DateTime createdAt,
      List<String> likes,
      int commentCount,
      Map<String, String> reactions});
}

/// @nodoc
class _$ActivityModelCopyWithImpl<$Res, $Val extends ActivityModel>
    implements $ActivityModelCopyWith<$Res> {
  _$ActivityModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? username = null,
    Object? userPhotoUrl = freezed,
    Object? activityType = null,
    Object? filmId = null,
    Object? filmTitle = null,
    Object? filmPosterPath = freezed,
    Object? filmBackdropPath = freezed,
    Object? filmYear = freezed,
    Object? mediaType = null,
    Object? rating = freezed,
    Object? reviewText = freezed,
    Object? createdAt = null,
    Object? likes = null,
    Object? commentCount = null,
    Object? reactions = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      username: null == username
          ? _value.username
          : username // ignore: cast_nullable_to_non_nullable
              as String,
      userPhotoUrl: freezed == userPhotoUrl
          ? _value.userPhotoUrl
          : userPhotoUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      activityType: null == activityType
          ? _value.activityType
          : activityType // ignore: cast_nullable_to_non_nullable
              as ActivityType,
      filmId: null == filmId
          ? _value.filmId
          : filmId // ignore: cast_nullable_to_non_nullable
              as int,
      filmTitle: null == filmTitle
          ? _value.filmTitle
          : filmTitle // ignore: cast_nullable_to_non_nullable
              as String,
      filmPosterPath: freezed == filmPosterPath
          ? _value.filmPosterPath
          : filmPosterPath // ignore: cast_nullable_to_non_nullable
              as String?,
      filmBackdropPath: freezed == filmBackdropPath
          ? _value.filmBackdropPath
          : filmBackdropPath // ignore: cast_nullable_to_non_nullable
              as String?,
      filmYear: freezed == filmYear
          ? _value.filmYear
          : filmYear // ignore: cast_nullable_to_non_nullable
              as String?,
      mediaType: null == mediaType
          ? _value.mediaType
          : mediaType // ignore: cast_nullable_to_non_nullable
              as String,
      rating: freezed == rating
          ? _value.rating
          : rating // ignore: cast_nullable_to_non_nullable
              as double?,
      reviewText: freezed == reviewText
          ? _value.reviewText
          : reviewText // ignore: cast_nullable_to_non_nullable
              as String?,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      likes: null == likes
          ? _value.likes
          : likes // ignore: cast_nullable_to_non_nullable
              as List<String>,
      commentCount: null == commentCount
          ? _value.commentCount
          : commentCount // ignore: cast_nullable_to_non_nullable
              as int,
      reactions: null == reactions
          ? _value.reactions
          : reactions // ignore: cast_nullable_to_non_nullable
              as Map<String, String>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ActivityModelImplCopyWith<$Res>
    implements $ActivityModelCopyWith<$Res> {
  factory _$$ActivityModelImplCopyWith(
          _$ActivityModelImpl value, $Res Function(_$ActivityModelImpl) then) =
      __$$ActivityModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String userId,
      String username,
      String? userPhotoUrl,
      ActivityType activityType,
      int filmId,
      String filmTitle,
      String? filmPosterPath,
      String? filmBackdropPath,
      String? filmYear,
      String mediaType,
      double? rating,
      String? reviewText,
      DateTime createdAt,
      List<String> likes,
      int commentCount,
      Map<String, String> reactions});
}

/// @nodoc
class __$$ActivityModelImplCopyWithImpl<$Res>
    extends _$ActivityModelCopyWithImpl<$Res, _$ActivityModelImpl>
    implements _$$ActivityModelImplCopyWith<$Res> {
  __$$ActivityModelImplCopyWithImpl(
      _$ActivityModelImpl _value, $Res Function(_$ActivityModelImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? username = null,
    Object? userPhotoUrl = freezed,
    Object? activityType = null,
    Object? filmId = null,
    Object? filmTitle = null,
    Object? filmPosterPath = freezed,
    Object? filmBackdropPath = freezed,
    Object? filmYear = freezed,
    Object? mediaType = null,
    Object? rating = freezed,
    Object? reviewText = freezed,
    Object? createdAt = null,
    Object? likes = null,
    Object? commentCount = null,
    Object? reactions = null,
  }) {
    return _then(_$ActivityModelImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      username: null == username
          ? _value.username
          : username // ignore: cast_nullable_to_non_nullable
              as String,
      userPhotoUrl: freezed == userPhotoUrl
          ? _value.userPhotoUrl
          : userPhotoUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      activityType: null == activityType
          ? _value.activityType
          : activityType // ignore: cast_nullable_to_non_nullable
              as ActivityType,
      filmId: null == filmId
          ? _value.filmId
          : filmId // ignore: cast_nullable_to_non_nullable
              as int,
      filmTitle: null == filmTitle
          ? _value.filmTitle
          : filmTitle // ignore: cast_nullable_to_non_nullable
              as String,
      filmPosterPath: freezed == filmPosterPath
          ? _value.filmPosterPath
          : filmPosterPath // ignore: cast_nullable_to_non_nullable
              as String?,
      filmBackdropPath: freezed == filmBackdropPath
          ? _value.filmBackdropPath
          : filmBackdropPath // ignore: cast_nullable_to_non_nullable
              as String?,
      filmYear: freezed == filmYear
          ? _value.filmYear
          : filmYear // ignore: cast_nullable_to_non_nullable
              as String?,
      mediaType: null == mediaType
          ? _value.mediaType
          : mediaType // ignore: cast_nullable_to_non_nullable
              as String,
      rating: freezed == rating
          ? _value.rating
          : rating // ignore: cast_nullable_to_non_nullable
              as double?,
      reviewText: freezed == reviewText
          ? _value.reviewText
          : reviewText // ignore: cast_nullable_to_non_nullable
              as String?,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      likes: null == likes
          ? _value._likes
          : likes // ignore: cast_nullable_to_non_nullable
              as List<String>,
      commentCount: null == commentCount
          ? _value.commentCount
          : commentCount // ignore: cast_nullable_to_non_nullable
              as int,
      reactions: null == reactions
          ? _value._reactions
          : reactions // ignore: cast_nullable_to_non_nullable
              as Map<String, String>,
    ));
  }
}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _$ActivityModelImpl extends _ActivityModel {
  const _$ActivityModelImpl(
      {required this.id,
      required this.userId,
      required this.username,
      this.userPhotoUrl,
      required this.activityType,
      required this.filmId,
      required this.filmTitle,
      this.filmPosterPath,
      this.filmBackdropPath,
      this.filmYear,
      this.mediaType = 'movie',
      this.rating,
      this.reviewText,
      required this.createdAt,
      final List<String> likes = const [],
      this.commentCount = 0,
      final Map<String, String> reactions = const {}})
      : _likes = likes,
        _reactions = reactions,
        super._();

  factory _$ActivityModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$ActivityModelImplFromJson(json);

  /// Unique activity ID (Firestore document ID)
  @override
  final String id;

  /// User ID who created this activity
  @override
  final String userId;

  /// Username for display (denormalized for performance)
  @override
  final String username;

  /// User's profile photo URL (denormalized)
  @override
  final String? userPhotoUrl;

  /// Type of activity (watched or reviewed)
  @override
  final ActivityType activityType;

  /// TMDB film ID
  @override
  final int filmId;

  /// Film title (denormalized for display)
  @override
  final String filmTitle;

  /// Film poster path from TMDB
  @override
  final String? filmPosterPath;

  /// Film backdrop path from TMDB
  @override
  final String? filmBackdropPath;

  /// Film release year
  @override
  final String? filmYear;

  /// Media type (movie or tv)
  @override
  @JsonKey()
  final String mediaType;

  /// User's rating (0-5 stars, nullable if just "watched")
  @override
  final double? rating;

  /// User's review text (nullable)
  @override
  final String? reviewText;

  /// When this activity was created
  @override
  final DateTime createdAt;

  /// User IDs who liked this activity
  final List<String> _likes;

  /// User IDs who liked this activity
  @override
  @JsonKey()
  List<String> get likes {
    if (_likes is EqualUnmodifiableListView) return _likes;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_likes);
  }

  /// Number of comments (denormalized count)
  @override
  @JsonKey()
  final int commentCount;

  /// Reactions map: userId -> stickerId
  /// Each user can only have one reaction per activity
  final Map<String, String> _reactions;

  /// Reactions map: userId -> stickerId
  /// Each user can only have one reaction per activity
  @override
  @JsonKey()
  Map<String, String> get reactions {
    if (_reactions is EqualUnmodifiableMapView) return _reactions;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_reactions);
  }

  @override
  String toString() {
    return 'ActivityModel(id: $id, userId: $userId, username: $username, userPhotoUrl: $userPhotoUrl, activityType: $activityType, filmId: $filmId, filmTitle: $filmTitle, filmPosterPath: $filmPosterPath, filmBackdropPath: $filmBackdropPath, filmYear: $filmYear, mediaType: $mediaType, rating: $rating, reviewText: $reviewText, createdAt: $createdAt, likes: $likes, commentCount: $commentCount, reactions: $reactions)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ActivityModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.username, username) ||
                other.username == username) &&
            (identical(other.userPhotoUrl, userPhotoUrl) ||
                other.userPhotoUrl == userPhotoUrl) &&
            (identical(other.activityType, activityType) ||
                other.activityType == activityType) &&
            (identical(other.filmId, filmId) || other.filmId == filmId) &&
            (identical(other.filmTitle, filmTitle) ||
                other.filmTitle == filmTitle) &&
            (identical(other.filmPosterPath, filmPosterPath) ||
                other.filmPosterPath == filmPosterPath) &&
            (identical(other.filmBackdropPath, filmBackdropPath) ||
                other.filmBackdropPath == filmBackdropPath) &&
            (identical(other.filmYear, filmYear) ||
                other.filmYear == filmYear) &&
            (identical(other.mediaType, mediaType) ||
                other.mediaType == mediaType) &&
            (identical(other.rating, rating) || other.rating == rating) &&
            (identical(other.reviewText, reviewText) ||
                other.reviewText == reviewText) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            const DeepCollectionEquality().equals(other._likes, _likes) &&
            (identical(other.commentCount, commentCount) ||
                other.commentCount == commentCount) &&
            const DeepCollectionEquality()
                .equals(other._reactions, _reactions));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      userId,
      username,
      userPhotoUrl,
      activityType,
      filmId,
      filmTitle,
      filmPosterPath,
      filmBackdropPath,
      filmYear,
      mediaType,
      rating,
      reviewText,
      createdAt,
      const DeepCollectionEquality().hash(_likes),
      commentCount,
      const DeepCollectionEquality().hash(_reactions));

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$ActivityModelImplCopyWith<_$ActivityModelImpl> get copyWith =>
      __$$ActivityModelImplCopyWithImpl<_$ActivityModelImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ActivityModelImplToJson(
      this,
    );
  }
}

abstract class _ActivityModel extends ActivityModel {
  const factory _ActivityModel(
      {required final String id,
      required final String userId,
      required final String username,
      final String? userPhotoUrl,
      required final ActivityType activityType,
      required final int filmId,
      required final String filmTitle,
      final String? filmPosterPath,
      final String? filmBackdropPath,
      final String? filmYear,
      final String mediaType,
      final double? rating,
      final String? reviewText,
      required final DateTime createdAt,
      final List<String> likes,
      final int commentCount,
      final Map<String, String> reactions}) = _$ActivityModelImpl;
  const _ActivityModel._() : super._();

  factory _ActivityModel.fromJson(Map<String, dynamic> json) =
      _$ActivityModelImpl.fromJson;

  @override

  /// Unique activity ID (Firestore document ID)
  String get id;
  @override

  /// User ID who created this activity
  String get userId;
  @override

  /// Username for display (denormalized for performance)
  String get username;
  @override

  /// User's profile photo URL (denormalized)
  String? get userPhotoUrl;
  @override

  /// Type of activity (watched or reviewed)
  ActivityType get activityType;
  @override

  /// TMDB film ID
  int get filmId;
  @override

  /// Film title (denormalized for display)
  String get filmTitle;
  @override

  /// Film poster path from TMDB
  String? get filmPosterPath;
  @override

  /// Film backdrop path from TMDB
  String? get filmBackdropPath;
  @override

  /// Film release year
  String? get filmYear;
  @override

  /// Media type (movie or tv)
  String get mediaType;
  @override

  /// User's rating (0-5 stars, nullable if just "watched")
  double? get rating;
  @override

  /// User's review text (nullable)
  String? get reviewText;
  @override

  /// When this activity was created
  DateTime get createdAt;
  @override

  /// User IDs who liked this activity
  List<String> get likes;
  @override

  /// Number of comments (denormalized count)
  int get commentCount;
  @override

  /// Reactions map: userId -> stickerId
  /// Each user can only have one reaction per activity
  Map<String, String> get reactions;
  @override
  @JsonKey(ignore: true)
  _$$ActivityModelImplCopyWith<_$ActivityModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

CommentModel _$CommentModelFromJson(Map<String, dynamic> json) {
  return _CommentModel.fromJson(json);
}

/// @nodoc
mixin _$CommentModel {
  /// Comment ID
  String get id => throw _privateConstructorUsedError;

  /// Activity ID this comment belongs to
  String get activityId => throw _privateConstructorUsedError;

  /// User ID who wrote the comment
  String get userId => throw _privateConstructorUsedError;

  /// Username (denormalized)
  String get username => throw _privateConstructorUsedError;

  /// User photo URL (denormalized)
  String? get userPhotoUrl => throw _privateConstructorUsedError;

  /// Comment text
  String get content => throw _privateConstructorUsedError;

  /// When comment was created
  DateTime get createdAt => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $CommentModelCopyWith<CommentModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CommentModelCopyWith<$Res> {
  factory $CommentModelCopyWith(
          CommentModel value, $Res Function(CommentModel) then) =
      _$CommentModelCopyWithImpl<$Res, CommentModel>;
  @useResult
  $Res call(
      {String id,
      String activityId,
      String userId,
      String username,
      String? userPhotoUrl,
      String content,
      DateTime createdAt});
}

/// @nodoc
class _$CommentModelCopyWithImpl<$Res, $Val extends CommentModel>
    implements $CommentModelCopyWith<$Res> {
  _$CommentModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? activityId = null,
    Object? userId = null,
    Object? username = null,
    Object? userPhotoUrl = freezed,
    Object? content = null,
    Object? createdAt = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      activityId: null == activityId
          ? _value.activityId
          : activityId // ignore: cast_nullable_to_non_nullable
              as String,
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      username: null == username
          ? _value.username
          : username // ignore: cast_nullable_to_non_nullable
              as String,
      userPhotoUrl: freezed == userPhotoUrl
          ? _value.userPhotoUrl
          : userPhotoUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      content: null == content
          ? _value.content
          : content // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$CommentModelImplCopyWith<$Res>
    implements $CommentModelCopyWith<$Res> {
  factory _$$CommentModelImplCopyWith(
          _$CommentModelImpl value, $Res Function(_$CommentModelImpl) then) =
      __$$CommentModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String activityId,
      String userId,
      String username,
      String? userPhotoUrl,
      String content,
      DateTime createdAt});
}

/// @nodoc
class __$$CommentModelImplCopyWithImpl<$Res>
    extends _$CommentModelCopyWithImpl<$Res, _$CommentModelImpl>
    implements _$$CommentModelImplCopyWith<$Res> {
  __$$CommentModelImplCopyWithImpl(
      _$CommentModelImpl _value, $Res Function(_$CommentModelImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? activityId = null,
    Object? userId = null,
    Object? username = null,
    Object? userPhotoUrl = freezed,
    Object? content = null,
    Object? createdAt = null,
  }) {
    return _then(_$CommentModelImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      activityId: null == activityId
          ? _value.activityId
          : activityId // ignore: cast_nullable_to_non_nullable
              as String,
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      username: null == username
          ? _value.username
          : username // ignore: cast_nullable_to_non_nullable
              as String,
      userPhotoUrl: freezed == userPhotoUrl
          ? _value.userPhotoUrl
          : userPhotoUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      content: null == content
          ? _value.content
          : content // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _$CommentModelImpl extends _CommentModel {
  const _$CommentModelImpl(
      {required this.id,
      required this.activityId,
      required this.userId,
      required this.username,
      this.userPhotoUrl,
      required this.content,
      required this.createdAt})
      : super._();

  factory _$CommentModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$CommentModelImplFromJson(json);

  /// Comment ID
  @override
  final String id;

  /// Activity ID this comment belongs to
  @override
  final String activityId;

  /// User ID who wrote the comment
  @override
  final String userId;

  /// Username (denormalized)
  @override
  final String username;

  /// User photo URL (denormalized)
  @override
  final String? userPhotoUrl;

  /// Comment text
  @override
  final String content;

  /// When comment was created
  @override
  final DateTime createdAt;

  @override
  String toString() {
    return 'CommentModel(id: $id, activityId: $activityId, userId: $userId, username: $username, userPhotoUrl: $userPhotoUrl, content: $content, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CommentModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.activityId, activityId) ||
                other.activityId == activityId) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.username, username) ||
                other.username == username) &&
            (identical(other.userPhotoUrl, userPhotoUrl) ||
                other.userPhotoUrl == userPhotoUrl) &&
            (identical(other.content, content) || other.content == content) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, id, activityId, userId, username,
      userPhotoUrl, content, createdAt);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$CommentModelImplCopyWith<_$CommentModelImpl> get copyWith =>
      __$$CommentModelImplCopyWithImpl<_$CommentModelImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$CommentModelImplToJson(
      this,
    );
  }
}

abstract class _CommentModel extends CommentModel {
  const factory _CommentModel(
      {required final String id,
      required final String activityId,
      required final String userId,
      required final String username,
      final String? userPhotoUrl,
      required final String content,
      required final DateTime createdAt}) = _$CommentModelImpl;
  const _CommentModel._() : super._();

  factory _CommentModel.fromJson(Map<String, dynamic> json) =
      _$CommentModelImpl.fromJson;

  @override

  /// Comment ID
  String get id;
  @override

  /// Activity ID this comment belongs to
  String get activityId;
  @override

  /// User ID who wrote the comment
  String get userId;
  @override

  /// Username (denormalized)
  String get username;
  @override

  /// User photo URL (denormalized)
  String? get userPhotoUrl;
  @override

  /// Comment text
  String get content;
  @override

  /// When comment was created
  DateTime get createdAt;
  @override
  @JsonKey(ignore: true)
  _$$CommentModelImplCopyWith<_$CommentModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
