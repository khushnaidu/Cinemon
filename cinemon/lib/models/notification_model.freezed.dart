// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'notification_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

NotificationModel _$NotificationModelFromJson(Map<String, dynamic> json) {
  return _NotificationModel.fromJson(json);
}

/// @nodoc
mixin _$NotificationModel {
  /// Unique notification ID (uuid primary key)
  String get id => throw _privateConstructorUsedError;

  /// User ID who receives this notification (activity owner)
  String get recipientId => throw _privateConstructorUsedError;

  /// User ID who triggered the notification (who liked/commented/etc).
  /// Null for [NotificationType.personNewCredit].
  String? get actorId => throw _privateConstructorUsedError;

  /// Actor's username (denormalized)
  String get actorUsername => throw _privateConstructorUsedError;

  /// Actor's profile photo URL (denormalized)
  String? get actorPhotoUrl => throw _privateConstructorUsedError;

  /// Type of notification
  NotificationType get type => throw _privateConstructorUsedError;

  /// Activity ID this notification relates to (null for follow notifications)
  String? get activityId => throw _privateConstructorUsedError;

  /// Film title for context (denormalized)
  String? get filmTitle => throw _privateConstructorUsedError;

  /// Film poster path for display
  String? get filmPosterPath => throw _privateConstructorUsedError;

  /// Comment text preview (for comment notifications)
  String? get commentPreview => throw _privateConstructorUsedError;

  /// Sticker ID (for reaction notifications)
  String? get stickerId => throw _privateConstructorUsedError;

  /// For [NotificationType.personNewCredit]: who, and on what. The role
  /// ("as Dani", "Director") travels in [commentPreview].
  int? get personId => throw _privateConstructorUsedError;
  String? get personName => throw _privateConstructorUsedError;
  String? get personProfilePath => throw _privateConstructorUsedError;
  int? get filmId => throw _privateConstructorUsedError;
  String? get mediaType => throw _privateConstructorUsedError;

  /// The Explore post a vote or reply was on (migration 018).
  String? get explorePostId => throw _privateConstructorUsedError;

  /// The playlist that was saved (migration 018).
  String? get listId => throw _privateConstructorUsedError;

  /// For [NotificationType.vote]: 1 agreed, -1 disagreed.
  int? get vote => throw _privateConstructorUsedError;

  /// Whether the notification has been read
  bool get isRead => throw _privateConstructorUsedError;

  /// When this notification was created
  DateTime get createdAt => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $NotificationModelCopyWith<NotificationModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $NotificationModelCopyWith<$Res> {
  factory $NotificationModelCopyWith(
          NotificationModel value, $Res Function(NotificationModel) then) =
      _$NotificationModelCopyWithImpl<$Res, NotificationModel>;
  @useResult
  $Res call(
      {String id,
      String recipientId,
      String? actorId,
      String actorUsername,
      String? actorPhotoUrl,
      NotificationType type,
      String? activityId,
      String? filmTitle,
      String? filmPosterPath,
      String? commentPreview,
      String? stickerId,
      int? personId,
      String? personName,
      String? personProfilePath,
      int? filmId,
      String? mediaType,
      String? explorePostId,
      String? listId,
      int? vote,
      bool isRead,
      DateTime createdAt});
}

/// @nodoc
class _$NotificationModelCopyWithImpl<$Res, $Val extends NotificationModel>
    implements $NotificationModelCopyWith<$Res> {
  _$NotificationModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? recipientId = null,
    Object? actorId = freezed,
    Object? actorUsername = null,
    Object? actorPhotoUrl = freezed,
    Object? type = null,
    Object? activityId = freezed,
    Object? filmTitle = freezed,
    Object? filmPosterPath = freezed,
    Object? commentPreview = freezed,
    Object? stickerId = freezed,
    Object? personId = freezed,
    Object? personName = freezed,
    Object? personProfilePath = freezed,
    Object? filmId = freezed,
    Object? mediaType = freezed,
    Object? explorePostId = freezed,
    Object? listId = freezed,
    Object? vote = freezed,
    Object? isRead = null,
    Object? createdAt = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      recipientId: null == recipientId
          ? _value.recipientId
          : recipientId // ignore: cast_nullable_to_non_nullable
              as String,
      actorId: freezed == actorId
          ? _value.actorId
          : actorId // ignore: cast_nullable_to_non_nullable
              as String?,
      actorUsername: null == actorUsername
          ? _value.actorUsername
          : actorUsername // ignore: cast_nullable_to_non_nullable
              as String,
      actorPhotoUrl: freezed == actorPhotoUrl
          ? _value.actorPhotoUrl
          : actorPhotoUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as NotificationType,
      activityId: freezed == activityId
          ? _value.activityId
          : activityId // ignore: cast_nullable_to_non_nullable
              as String?,
      filmTitle: freezed == filmTitle
          ? _value.filmTitle
          : filmTitle // ignore: cast_nullable_to_non_nullable
              as String?,
      filmPosterPath: freezed == filmPosterPath
          ? _value.filmPosterPath
          : filmPosterPath // ignore: cast_nullable_to_non_nullable
              as String?,
      commentPreview: freezed == commentPreview
          ? _value.commentPreview
          : commentPreview // ignore: cast_nullable_to_non_nullable
              as String?,
      stickerId: freezed == stickerId
          ? _value.stickerId
          : stickerId // ignore: cast_nullable_to_non_nullable
              as String?,
      personId: freezed == personId
          ? _value.personId
          : personId // ignore: cast_nullable_to_non_nullable
              as int?,
      personName: freezed == personName
          ? _value.personName
          : personName // ignore: cast_nullable_to_non_nullable
              as String?,
      personProfilePath: freezed == personProfilePath
          ? _value.personProfilePath
          : personProfilePath // ignore: cast_nullable_to_non_nullable
              as String?,
      filmId: freezed == filmId
          ? _value.filmId
          : filmId // ignore: cast_nullable_to_non_nullable
              as int?,
      mediaType: freezed == mediaType
          ? _value.mediaType
          : mediaType // ignore: cast_nullable_to_non_nullable
              as String?,
      explorePostId: freezed == explorePostId
          ? _value.explorePostId
          : explorePostId // ignore: cast_nullable_to_non_nullable
              as String?,
      listId: freezed == listId
          ? _value.listId
          : listId // ignore: cast_nullable_to_non_nullable
              as String?,
      vote: freezed == vote
          ? _value.vote
          : vote // ignore: cast_nullable_to_non_nullable
              as int?,
      isRead: null == isRead
          ? _value.isRead
          : isRead // ignore: cast_nullable_to_non_nullable
              as bool,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$NotificationModelImplCopyWith<$Res>
    implements $NotificationModelCopyWith<$Res> {
  factory _$$NotificationModelImplCopyWith(_$NotificationModelImpl value,
          $Res Function(_$NotificationModelImpl) then) =
      __$$NotificationModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String recipientId,
      String? actorId,
      String actorUsername,
      String? actorPhotoUrl,
      NotificationType type,
      String? activityId,
      String? filmTitle,
      String? filmPosterPath,
      String? commentPreview,
      String? stickerId,
      int? personId,
      String? personName,
      String? personProfilePath,
      int? filmId,
      String? mediaType,
      String? explorePostId,
      String? listId,
      int? vote,
      bool isRead,
      DateTime createdAt});
}

/// @nodoc
class __$$NotificationModelImplCopyWithImpl<$Res>
    extends _$NotificationModelCopyWithImpl<$Res, _$NotificationModelImpl>
    implements _$$NotificationModelImplCopyWith<$Res> {
  __$$NotificationModelImplCopyWithImpl(_$NotificationModelImpl _value,
      $Res Function(_$NotificationModelImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? recipientId = null,
    Object? actorId = freezed,
    Object? actorUsername = null,
    Object? actorPhotoUrl = freezed,
    Object? type = null,
    Object? activityId = freezed,
    Object? filmTitle = freezed,
    Object? filmPosterPath = freezed,
    Object? commentPreview = freezed,
    Object? stickerId = freezed,
    Object? personId = freezed,
    Object? personName = freezed,
    Object? personProfilePath = freezed,
    Object? filmId = freezed,
    Object? mediaType = freezed,
    Object? explorePostId = freezed,
    Object? listId = freezed,
    Object? vote = freezed,
    Object? isRead = null,
    Object? createdAt = null,
  }) {
    return _then(_$NotificationModelImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      recipientId: null == recipientId
          ? _value.recipientId
          : recipientId // ignore: cast_nullable_to_non_nullable
              as String,
      actorId: freezed == actorId
          ? _value.actorId
          : actorId // ignore: cast_nullable_to_non_nullable
              as String?,
      actorUsername: null == actorUsername
          ? _value.actorUsername
          : actorUsername // ignore: cast_nullable_to_non_nullable
              as String,
      actorPhotoUrl: freezed == actorPhotoUrl
          ? _value.actorPhotoUrl
          : actorPhotoUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as NotificationType,
      activityId: freezed == activityId
          ? _value.activityId
          : activityId // ignore: cast_nullable_to_non_nullable
              as String?,
      filmTitle: freezed == filmTitle
          ? _value.filmTitle
          : filmTitle // ignore: cast_nullable_to_non_nullable
              as String?,
      filmPosterPath: freezed == filmPosterPath
          ? _value.filmPosterPath
          : filmPosterPath // ignore: cast_nullable_to_non_nullable
              as String?,
      commentPreview: freezed == commentPreview
          ? _value.commentPreview
          : commentPreview // ignore: cast_nullable_to_non_nullable
              as String?,
      stickerId: freezed == stickerId
          ? _value.stickerId
          : stickerId // ignore: cast_nullable_to_non_nullable
              as String?,
      personId: freezed == personId
          ? _value.personId
          : personId // ignore: cast_nullable_to_non_nullable
              as int?,
      personName: freezed == personName
          ? _value.personName
          : personName // ignore: cast_nullable_to_non_nullable
              as String?,
      personProfilePath: freezed == personProfilePath
          ? _value.personProfilePath
          : personProfilePath // ignore: cast_nullable_to_non_nullable
              as String?,
      filmId: freezed == filmId
          ? _value.filmId
          : filmId // ignore: cast_nullable_to_non_nullable
              as int?,
      mediaType: freezed == mediaType
          ? _value.mediaType
          : mediaType // ignore: cast_nullable_to_non_nullable
              as String?,
      explorePostId: freezed == explorePostId
          ? _value.explorePostId
          : explorePostId // ignore: cast_nullable_to_non_nullable
              as String?,
      listId: freezed == listId
          ? _value.listId
          : listId // ignore: cast_nullable_to_non_nullable
              as String?,
      vote: freezed == vote
          ? _value.vote
          : vote // ignore: cast_nullable_to_non_nullable
              as int?,
      isRead: null == isRead
          ? _value.isRead
          : isRead // ignore: cast_nullable_to_non_nullable
              as bool,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _$NotificationModelImpl extends _NotificationModel {
  const _$NotificationModelImpl(
      {required this.id,
      required this.recipientId,
      this.actorId,
      this.actorUsername = '',
      this.actorPhotoUrl,
      required this.type,
      this.activityId,
      this.filmTitle,
      this.filmPosterPath,
      this.commentPreview,
      this.stickerId,
      this.personId,
      this.personName,
      this.personProfilePath,
      this.filmId,
      this.mediaType,
      this.explorePostId,
      this.listId,
      this.vote,
      this.isRead = false,
      required this.createdAt})
      : super._();

  factory _$NotificationModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$NotificationModelImplFromJson(json);

  /// Unique notification ID (uuid primary key)
  @override
  final String id;

  /// User ID who receives this notification (activity owner)
  @override
  final String recipientId;

  /// User ID who triggered the notification (who liked/commented/etc).
  /// Null for [NotificationType.personNewCredit].
  @override
  final String? actorId;

  /// Actor's username (denormalized)
  @override
  @JsonKey()
  final String actorUsername;

  /// Actor's profile photo URL (denormalized)
  @override
  final String? actorPhotoUrl;

  /// Type of notification
  @override
  final NotificationType type;

  /// Activity ID this notification relates to (null for follow notifications)
  @override
  final String? activityId;

  /// Film title for context (denormalized)
  @override
  final String? filmTitle;

  /// Film poster path for display
  @override
  final String? filmPosterPath;

  /// Comment text preview (for comment notifications)
  @override
  final String? commentPreview;

  /// Sticker ID (for reaction notifications)
  @override
  final String? stickerId;

  /// For [NotificationType.personNewCredit]: who, and on what. The role
  /// ("as Dani", "Director") travels in [commentPreview].
  @override
  final int? personId;
  @override
  final String? personName;
  @override
  final String? personProfilePath;
  @override
  final int? filmId;
  @override
  final String? mediaType;

  /// The Explore post a vote or reply was on (migration 018).
  @override
  final String? explorePostId;

  /// The playlist that was saved (migration 018).
  @override
  final String? listId;

  /// For [NotificationType.vote]: 1 agreed, -1 disagreed.
  @override
  final int? vote;

  /// Whether the notification has been read
  @override
  @JsonKey()
  final bool isRead;

  /// When this notification was created
  @override
  final DateTime createdAt;

  @override
  String toString() {
    return 'NotificationModel(id: $id, recipientId: $recipientId, actorId: $actorId, actorUsername: $actorUsername, actorPhotoUrl: $actorPhotoUrl, type: $type, activityId: $activityId, filmTitle: $filmTitle, filmPosterPath: $filmPosterPath, commentPreview: $commentPreview, stickerId: $stickerId, personId: $personId, personName: $personName, personProfilePath: $personProfilePath, filmId: $filmId, mediaType: $mediaType, explorePostId: $explorePostId, listId: $listId, vote: $vote, isRead: $isRead, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$NotificationModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.recipientId, recipientId) ||
                other.recipientId == recipientId) &&
            (identical(other.actorId, actorId) || other.actorId == actorId) &&
            (identical(other.actorUsername, actorUsername) ||
                other.actorUsername == actorUsername) &&
            (identical(other.actorPhotoUrl, actorPhotoUrl) ||
                other.actorPhotoUrl == actorPhotoUrl) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.activityId, activityId) ||
                other.activityId == activityId) &&
            (identical(other.filmTitle, filmTitle) ||
                other.filmTitle == filmTitle) &&
            (identical(other.filmPosterPath, filmPosterPath) ||
                other.filmPosterPath == filmPosterPath) &&
            (identical(other.commentPreview, commentPreview) ||
                other.commentPreview == commentPreview) &&
            (identical(other.stickerId, stickerId) ||
                other.stickerId == stickerId) &&
            (identical(other.personId, personId) ||
                other.personId == personId) &&
            (identical(other.personName, personName) ||
                other.personName == personName) &&
            (identical(other.personProfilePath, personProfilePath) ||
                other.personProfilePath == personProfilePath) &&
            (identical(other.filmId, filmId) || other.filmId == filmId) &&
            (identical(other.mediaType, mediaType) ||
                other.mediaType == mediaType) &&
            (identical(other.explorePostId, explorePostId) ||
                other.explorePostId == explorePostId) &&
            (identical(other.listId, listId) || other.listId == listId) &&
            (identical(other.vote, vote) || other.vote == vote) &&
            (identical(other.isRead, isRead) || other.isRead == isRead) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        id,
        recipientId,
        actorId,
        actorUsername,
        actorPhotoUrl,
        type,
        activityId,
        filmTitle,
        filmPosterPath,
        commentPreview,
        stickerId,
        personId,
        personName,
        personProfilePath,
        filmId,
        mediaType,
        explorePostId,
        listId,
        vote,
        isRead,
        createdAt
      ]);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$NotificationModelImplCopyWith<_$NotificationModelImpl> get copyWith =>
      __$$NotificationModelImplCopyWithImpl<_$NotificationModelImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$NotificationModelImplToJson(
      this,
    );
  }
}

abstract class _NotificationModel extends NotificationModel {
  const factory _NotificationModel(
      {required final String id,
      required final String recipientId,
      final String? actorId,
      final String actorUsername,
      final String? actorPhotoUrl,
      required final NotificationType type,
      final String? activityId,
      final String? filmTitle,
      final String? filmPosterPath,
      final String? commentPreview,
      final String? stickerId,
      final int? personId,
      final String? personName,
      final String? personProfilePath,
      final int? filmId,
      final String? mediaType,
      final String? explorePostId,
      final String? listId,
      final int? vote,
      final bool isRead,
      required final DateTime createdAt}) = _$NotificationModelImpl;
  const _NotificationModel._() : super._();

  factory _NotificationModel.fromJson(Map<String, dynamic> json) =
      _$NotificationModelImpl.fromJson;

  @override

  /// Unique notification ID (uuid primary key)
  String get id;
  @override

  /// User ID who receives this notification (activity owner)
  String get recipientId;
  @override

  /// User ID who triggered the notification (who liked/commented/etc).
  /// Null for [NotificationType.personNewCredit].
  String? get actorId;
  @override

  /// Actor's username (denormalized)
  String get actorUsername;
  @override

  /// Actor's profile photo URL (denormalized)
  String? get actorPhotoUrl;
  @override

  /// Type of notification
  NotificationType get type;
  @override

  /// Activity ID this notification relates to (null for follow notifications)
  String? get activityId;
  @override

  /// Film title for context (denormalized)
  String? get filmTitle;
  @override

  /// Film poster path for display
  String? get filmPosterPath;
  @override

  /// Comment text preview (for comment notifications)
  String? get commentPreview;
  @override

  /// Sticker ID (for reaction notifications)
  String? get stickerId;
  @override

  /// For [NotificationType.personNewCredit]: who, and on what. The role
  /// ("as Dani", "Director") travels in [commentPreview].
  int? get personId;
  @override
  String? get personName;
  @override
  String? get personProfilePath;
  @override
  int? get filmId;
  @override
  String? get mediaType;
  @override

  /// The Explore post a vote or reply was on (migration 018).
  String? get explorePostId;
  @override

  /// The playlist that was saved (migration 018).
  String? get listId;
  @override

  /// For [NotificationType.vote]: 1 agreed, -1 disagreed.
  int? get vote;
  @override

  /// Whether the notification has been read
  bool get isRead;
  @override

  /// When this notification was created
  DateTime get createdAt;
  @override
  @JsonKey(ignore: true)
  _$$NotificationModelImplCopyWith<_$NotificationModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
