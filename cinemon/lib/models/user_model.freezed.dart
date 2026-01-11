// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

UserModel _$UserModelFromJson(Map<String, dynamic> json) {
  return _UserModel.fromJson(json);
}

/// @nodoc
mixin _$UserModel {
  /// Firebase Auth UID - unique identifier
  String get uid => throw _privateConstructorUsedError;

  /// User's email address
  String get email => throw _privateConstructorUsedError;

  /// Unique username for search/display (e.g., @filmfan42)
  String get username => throw _privateConstructorUsedError;

  /// Optional display name (can be different from username)
  String? get displayName => throw _privateConstructorUsedError;

  /// Profile photo URL (Firebase Storage)
  String? get photoUrl => throw _privateConstructorUsedError;

  /// User bio/description
  String? get bio => throw _privateConstructorUsedError;

  /// IDs of badges the user has earned
  List<String> get badgeIds => throw _privateConstructorUsedError;

  /// Total number of reviews posted
  int get reviewCount => throw _privateConstructorUsedError;

  /// Number of followers
  int get followerCount => throw _privateConstructorUsedError;

  /// Number of users this user follows
  int get followingCount => throw _privateConstructorUsedError;

  /// User's favorite movie genres
  List<String> get favoriteGenres => throw _privateConstructorUsedError;

  /// Favorite film IDs (TMDB IDs, max 4)
  List<int> get favoriteFilmIds => throw _privateConstructorUsedError;

  /// Favorite actor IDs (TMDB person IDs, max 4)
  List<int> get favoriteActorIds => throw _privateConstructorUsedError;

  /// Favorite director IDs (TMDB person IDs, max 4)
  List<int> get favoriteDirectorIds => throw _privateConstructorUsedError;

  /// Account creation timestamp
  DateTime get createdAt => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $UserModelCopyWith<UserModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $UserModelCopyWith<$Res> {
  factory $UserModelCopyWith(UserModel value, $Res Function(UserModel) then) =
      _$UserModelCopyWithImpl<$Res, UserModel>;
  @useResult
  $Res call(
      {String uid,
      String email,
      String username,
      String? displayName,
      String? photoUrl,
      String? bio,
      List<String> badgeIds,
      int reviewCount,
      int followerCount,
      int followingCount,
      List<String> favoriteGenres,
      List<int> favoriteFilmIds,
      List<int> favoriteActorIds,
      List<int> favoriteDirectorIds,
      DateTime createdAt});
}

/// @nodoc
class _$UserModelCopyWithImpl<$Res, $Val extends UserModel>
    implements $UserModelCopyWith<$Res> {
  _$UserModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? uid = null,
    Object? email = null,
    Object? username = null,
    Object? displayName = freezed,
    Object? photoUrl = freezed,
    Object? bio = freezed,
    Object? badgeIds = null,
    Object? reviewCount = null,
    Object? followerCount = null,
    Object? followingCount = null,
    Object? favoriteGenres = null,
    Object? favoriteFilmIds = null,
    Object? favoriteActorIds = null,
    Object? favoriteDirectorIds = null,
    Object? createdAt = null,
  }) {
    return _then(_value.copyWith(
      uid: null == uid
          ? _value.uid
          : uid // ignore: cast_nullable_to_non_nullable
              as String,
      email: null == email
          ? _value.email
          : email // ignore: cast_nullable_to_non_nullable
              as String,
      username: null == username
          ? _value.username
          : username // ignore: cast_nullable_to_non_nullable
              as String,
      displayName: freezed == displayName
          ? _value.displayName
          : displayName // ignore: cast_nullable_to_non_nullable
              as String?,
      photoUrl: freezed == photoUrl
          ? _value.photoUrl
          : photoUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      bio: freezed == bio
          ? _value.bio
          : bio // ignore: cast_nullable_to_non_nullable
              as String?,
      badgeIds: null == badgeIds
          ? _value.badgeIds
          : badgeIds // ignore: cast_nullable_to_non_nullable
              as List<String>,
      reviewCount: null == reviewCount
          ? _value.reviewCount
          : reviewCount // ignore: cast_nullable_to_non_nullable
              as int,
      followerCount: null == followerCount
          ? _value.followerCount
          : followerCount // ignore: cast_nullable_to_non_nullable
              as int,
      followingCount: null == followingCount
          ? _value.followingCount
          : followingCount // ignore: cast_nullable_to_non_nullable
              as int,
      favoriteGenres: null == favoriteGenres
          ? _value.favoriteGenres
          : favoriteGenres // ignore: cast_nullable_to_non_nullable
              as List<String>,
      favoriteFilmIds: null == favoriteFilmIds
          ? _value.favoriteFilmIds
          : favoriteFilmIds // ignore: cast_nullable_to_non_nullable
              as List<int>,
      favoriteActorIds: null == favoriteActorIds
          ? _value.favoriteActorIds
          : favoriteActorIds // ignore: cast_nullable_to_non_nullable
              as List<int>,
      favoriteDirectorIds: null == favoriteDirectorIds
          ? _value.favoriteDirectorIds
          : favoriteDirectorIds // ignore: cast_nullable_to_non_nullable
              as List<int>,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$UserModelImplCopyWith<$Res>
    implements $UserModelCopyWith<$Res> {
  factory _$$UserModelImplCopyWith(
          _$UserModelImpl value, $Res Function(_$UserModelImpl) then) =
      __$$UserModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String uid,
      String email,
      String username,
      String? displayName,
      String? photoUrl,
      String? bio,
      List<String> badgeIds,
      int reviewCount,
      int followerCount,
      int followingCount,
      List<String> favoriteGenres,
      List<int> favoriteFilmIds,
      List<int> favoriteActorIds,
      List<int> favoriteDirectorIds,
      DateTime createdAt});
}

/// @nodoc
class __$$UserModelImplCopyWithImpl<$Res>
    extends _$UserModelCopyWithImpl<$Res, _$UserModelImpl>
    implements _$$UserModelImplCopyWith<$Res> {
  __$$UserModelImplCopyWithImpl(
      _$UserModelImpl _value, $Res Function(_$UserModelImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? uid = null,
    Object? email = null,
    Object? username = null,
    Object? displayName = freezed,
    Object? photoUrl = freezed,
    Object? bio = freezed,
    Object? badgeIds = null,
    Object? reviewCount = null,
    Object? followerCount = null,
    Object? followingCount = null,
    Object? favoriteGenres = null,
    Object? favoriteFilmIds = null,
    Object? favoriteActorIds = null,
    Object? favoriteDirectorIds = null,
    Object? createdAt = null,
  }) {
    return _then(_$UserModelImpl(
      uid: null == uid
          ? _value.uid
          : uid // ignore: cast_nullable_to_non_nullable
              as String,
      email: null == email
          ? _value.email
          : email // ignore: cast_nullable_to_non_nullable
              as String,
      username: null == username
          ? _value.username
          : username // ignore: cast_nullable_to_non_nullable
              as String,
      displayName: freezed == displayName
          ? _value.displayName
          : displayName // ignore: cast_nullable_to_non_nullable
              as String?,
      photoUrl: freezed == photoUrl
          ? _value.photoUrl
          : photoUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      bio: freezed == bio
          ? _value.bio
          : bio // ignore: cast_nullable_to_non_nullable
              as String?,
      badgeIds: null == badgeIds
          ? _value._badgeIds
          : badgeIds // ignore: cast_nullable_to_non_nullable
              as List<String>,
      reviewCount: null == reviewCount
          ? _value.reviewCount
          : reviewCount // ignore: cast_nullable_to_non_nullable
              as int,
      followerCount: null == followerCount
          ? _value.followerCount
          : followerCount // ignore: cast_nullable_to_non_nullable
              as int,
      followingCount: null == followingCount
          ? _value.followingCount
          : followingCount // ignore: cast_nullable_to_non_nullable
              as int,
      favoriteGenres: null == favoriteGenres
          ? _value._favoriteGenres
          : favoriteGenres // ignore: cast_nullable_to_non_nullable
              as List<String>,
      favoriteFilmIds: null == favoriteFilmIds
          ? _value._favoriteFilmIds
          : favoriteFilmIds // ignore: cast_nullable_to_non_nullable
              as List<int>,
      favoriteActorIds: null == favoriteActorIds
          ? _value._favoriteActorIds
          : favoriteActorIds // ignore: cast_nullable_to_non_nullable
              as List<int>,
      favoriteDirectorIds: null == favoriteDirectorIds
          ? _value._favoriteDirectorIds
          : favoriteDirectorIds // ignore: cast_nullable_to_non_nullable
              as List<int>,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$UserModelImpl implements _UserModel {
  const _$UserModelImpl(
      {required this.uid,
      required this.email,
      required this.username,
      this.displayName,
      this.photoUrl,
      this.bio,
      final List<String> badgeIds = const [],
      this.reviewCount = 0,
      this.followerCount = 0,
      this.followingCount = 0,
      final List<String> favoriteGenres = const [],
      final List<int> favoriteFilmIds = const [],
      final List<int> favoriteActorIds = const [],
      final List<int> favoriteDirectorIds = const [],
      required this.createdAt})
      : _badgeIds = badgeIds,
        _favoriteGenres = favoriteGenres,
        _favoriteFilmIds = favoriteFilmIds,
        _favoriteActorIds = favoriteActorIds,
        _favoriteDirectorIds = favoriteDirectorIds;

  factory _$UserModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$UserModelImplFromJson(json);

  /// Firebase Auth UID - unique identifier
  @override
  final String uid;

  /// User's email address
  @override
  final String email;

  /// Unique username for search/display (e.g., @filmfan42)
  @override
  final String username;

  /// Optional display name (can be different from username)
  @override
  final String? displayName;

  /// Profile photo URL (Firebase Storage)
  @override
  final String? photoUrl;

  /// User bio/description
  @override
  final String? bio;

  /// IDs of badges the user has earned
  final List<String> _badgeIds;

  /// IDs of badges the user has earned
  @override
  @JsonKey()
  List<String> get badgeIds {
    if (_badgeIds is EqualUnmodifiableListView) return _badgeIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_badgeIds);
  }

  /// Total number of reviews posted
  @override
  @JsonKey()
  final int reviewCount;

  /// Number of followers
  @override
  @JsonKey()
  final int followerCount;

  /// Number of users this user follows
  @override
  @JsonKey()
  final int followingCount;

  /// User's favorite movie genres
  final List<String> _favoriteGenres;

  /// User's favorite movie genres
  @override
  @JsonKey()
  List<String> get favoriteGenres {
    if (_favoriteGenres is EqualUnmodifiableListView) return _favoriteGenres;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_favoriteGenres);
  }

  /// Favorite film IDs (TMDB IDs, max 4)
  final List<int> _favoriteFilmIds;

  /// Favorite film IDs (TMDB IDs, max 4)
  @override
  @JsonKey()
  List<int> get favoriteFilmIds {
    if (_favoriteFilmIds is EqualUnmodifiableListView) return _favoriteFilmIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_favoriteFilmIds);
  }

  /// Favorite actor IDs (TMDB person IDs, max 4)
  final List<int> _favoriteActorIds;

  /// Favorite actor IDs (TMDB person IDs, max 4)
  @override
  @JsonKey()
  List<int> get favoriteActorIds {
    if (_favoriteActorIds is EqualUnmodifiableListView)
      return _favoriteActorIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_favoriteActorIds);
  }

  /// Favorite director IDs (TMDB person IDs, max 4)
  final List<int> _favoriteDirectorIds;

  /// Favorite director IDs (TMDB person IDs, max 4)
  @override
  @JsonKey()
  List<int> get favoriteDirectorIds {
    if (_favoriteDirectorIds is EqualUnmodifiableListView)
      return _favoriteDirectorIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_favoriteDirectorIds);
  }

  /// Account creation timestamp
  @override
  final DateTime createdAt;

  @override
  String toString() {
    return 'UserModel(uid: $uid, email: $email, username: $username, displayName: $displayName, photoUrl: $photoUrl, bio: $bio, badgeIds: $badgeIds, reviewCount: $reviewCount, followerCount: $followerCount, followingCount: $followingCount, favoriteGenres: $favoriteGenres, favoriteFilmIds: $favoriteFilmIds, favoriteActorIds: $favoriteActorIds, favoriteDirectorIds: $favoriteDirectorIds, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UserModelImpl &&
            (identical(other.uid, uid) || other.uid == uid) &&
            (identical(other.email, email) || other.email == email) &&
            (identical(other.username, username) ||
                other.username == username) &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName) &&
            (identical(other.photoUrl, photoUrl) ||
                other.photoUrl == photoUrl) &&
            (identical(other.bio, bio) || other.bio == bio) &&
            const DeepCollectionEquality().equals(other._badgeIds, _badgeIds) &&
            (identical(other.reviewCount, reviewCount) ||
                other.reviewCount == reviewCount) &&
            (identical(other.followerCount, followerCount) ||
                other.followerCount == followerCount) &&
            (identical(other.followingCount, followingCount) ||
                other.followingCount == followingCount) &&
            const DeepCollectionEquality()
                .equals(other._favoriteGenres, _favoriteGenres) &&
            const DeepCollectionEquality()
                .equals(other._favoriteFilmIds, _favoriteFilmIds) &&
            const DeepCollectionEquality()
                .equals(other._favoriteActorIds, _favoriteActorIds) &&
            const DeepCollectionEquality()
                .equals(other._favoriteDirectorIds, _favoriteDirectorIds) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      uid,
      email,
      username,
      displayName,
      photoUrl,
      bio,
      const DeepCollectionEquality().hash(_badgeIds),
      reviewCount,
      followerCount,
      followingCount,
      const DeepCollectionEquality().hash(_favoriteGenres),
      const DeepCollectionEquality().hash(_favoriteFilmIds),
      const DeepCollectionEquality().hash(_favoriteActorIds),
      const DeepCollectionEquality().hash(_favoriteDirectorIds),
      createdAt);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$UserModelImplCopyWith<_$UserModelImpl> get copyWith =>
      __$$UserModelImplCopyWithImpl<_$UserModelImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$UserModelImplToJson(
      this,
    );
  }
}

abstract class _UserModel implements UserModel {
  const factory _UserModel(
      {required final String uid,
      required final String email,
      required final String username,
      final String? displayName,
      final String? photoUrl,
      final String? bio,
      final List<String> badgeIds,
      final int reviewCount,
      final int followerCount,
      final int followingCount,
      final List<String> favoriteGenres,
      final List<int> favoriteFilmIds,
      final List<int> favoriteActorIds,
      final List<int> favoriteDirectorIds,
      required final DateTime createdAt}) = _$UserModelImpl;

  factory _UserModel.fromJson(Map<String, dynamic> json) =
      _$UserModelImpl.fromJson;

  @override

  /// Firebase Auth UID - unique identifier
  String get uid;
  @override

  /// User's email address
  String get email;
  @override

  /// Unique username for search/display (e.g., @filmfan42)
  String get username;
  @override

  /// Optional display name (can be different from username)
  String? get displayName;
  @override

  /// Profile photo URL (Firebase Storage)
  String? get photoUrl;
  @override

  /// User bio/description
  String? get bio;
  @override

  /// IDs of badges the user has earned
  List<String> get badgeIds;
  @override

  /// Total number of reviews posted
  int get reviewCount;
  @override

  /// Number of followers
  int get followerCount;
  @override

  /// Number of users this user follows
  int get followingCount;
  @override

  /// User's favorite movie genres
  List<String> get favoriteGenres;
  @override

  /// Favorite film IDs (TMDB IDs, max 4)
  List<int> get favoriteFilmIds;
  @override

  /// Favorite actor IDs (TMDB person IDs, max 4)
  List<int> get favoriteActorIds;
  @override

  /// Favorite director IDs (TMDB person IDs, max 4)
  List<int> get favoriteDirectorIds;
  @override

  /// Account creation timestamp
  DateTime get createdAt;
  @override
  @JsonKey(ignore: true)
  _$$UserModelImplCopyWith<_$UserModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
