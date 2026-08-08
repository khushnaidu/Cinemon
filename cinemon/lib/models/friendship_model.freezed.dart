// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'friendship_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

FriendshipModel _$FriendshipModelFromJson(Map<String, dynamic> json) {
  return _FriendshipModel.fromJson(json);
}

/// @nodoc
mixin _$FriendshipModel {
  /// Row id (uuid)
  String get id => throw _privateConstructorUsedError;

  /// User who sent the friend request
  String get senderId => throw _privateConstructorUsedError;

  /// User who received the friend request
  String get receiverId => throw _privateConstructorUsedError;

  /// Current status of the friendship
  FriendshipStatus get status => throw _privateConstructorUsedError;

  /// When the request was sent
  DateTime get createdAt => throw _privateConstructorUsedError;

  /// When the request was accepted (null if pending)
  DateTime? get acceptedAt => throw _privateConstructorUsedError;

  /// Sender's username (denormalized for display)
  String? get senderUsername => throw _privateConstructorUsedError;

  /// Sender's photo URL (denormalized)
  String? get senderPhotoUrl => throw _privateConstructorUsedError;

  /// Receiver's username (denormalized)
  String? get receiverUsername => throw _privateConstructorUsedError;

  /// Receiver's photo URL (denormalized)
  String? get receiverPhotoUrl => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $FriendshipModelCopyWith<FriendshipModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FriendshipModelCopyWith<$Res> {
  factory $FriendshipModelCopyWith(
          FriendshipModel value, $Res Function(FriendshipModel) then) =
      _$FriendshipModelCopyWithImpl<$Res, FriendshipModel>;
  @useResult
  $Res call(
      {String id,
      String senderId,
      String receiverId,
      FriendshipStatus status,
      DateTime createdAt,
      DateTime? acceptedAt,
      String? senderUsername,
      String? senderPhotoUrl,
      String? receiverUsername,
      String? receiverPhotoUrl});
}

/// @nodoc
class _$FriendshipModelCopyWithImpl<$Res, $Val extends FriendshipModel>
    implements $FriendshipModelCopyWith<$Res> {
  _$FriendshipModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? senderId = null,
    Object? receiverId = null,
    Object? status = null,
    Object? createdAt = null,
    Object? acceptedAt = freezed,
    Object? senderUsername = freezed,
    Object? senderPhotoUrl = freezed,
    Object? receiverUsername = freezed,
    Object? receiverPhotoUrl = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      senderId: null == senderId
          ? _value.senderId
          : senderId // ignore: cast_nullable_to_non_nullable
              as String,
      receiverId: null == receiverId
          ? _value.receiverId
          : receiverId // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as FriendshipStatus,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      acceptedAt: freezed == acceptedAt
          ? _value.acceptedAt
          : acceptedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      senderUsername: freezed == senderUsername
          ? _value.senderUsername
          : senderUsername // ignore: cast_nullable_to_non_nullable
              as String?,
      senderPhotoUrl: freezed == senderPhotoUrl
          ? _value.senderPhotoUrl
          : senderPhotoUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      receiverUsername: freezed == receiverUsername
          ? _value.receiverUsername
          : receiverUsername // ignore: cast_nullable_to_non_nullable
              as String?,
      receiverPhotoUrl: freezed == receiverPhotoUrl
          ? _value.receiverPhotoUrl
          : receiverPhotoUrl // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$FriendshipModelImplCopyWith<$Res>
    implements $FriendshipModelCopyWith<$Res> {
  factory _$$FriendshipModelImplCopyWith(_$FriendshipModelImpl value,
          $Res Function(_$FriendshipModelImpl) then) =
      __$$FriendshipModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String senderId,
      String receiverId,
      FriendshipStatus status,
      DateTime createdAt,
      DateTime? acceptedAt,
      String? senderUsername,
      String? senderPhotoUrl,
      String? receiverUsername,
      String? receiverPhotoUrl});
}

/// @nodoc
class __$$FriendshipModelImplCopyWithImpl<$Res>
    extends _$FriendshipModelCopyWithImpl<$Res, _$FriendshipModelImpl>
    implements _$$FriendshipModelImplCopyWith<$Res> {
  __$$FriendshipModelImplCopyWithImpl(
      _$FriendshipModelImpl _value, $Res Function(_$FriendshipModelImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? senderId = null,
    Object? receiverId = null,
    Object? status = null,
    Object? createdAt = null,
    Object? acceptedAt = freezed,
    Object? senderUsername = freezed,
    Object? senderPhotoUrl = freezed,
    Object? receiverUsername = freezed,
    Object? receiverPhotoUrl = freezed,
  }) {
    return _then(_$FriendshipModelImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      senderId: null == senderId
          ? _value.senderId
          : senderId // ignore: cast_nullable_to_non_nullable
              as String,
      receiverId: null == receiverId
          ? _value.receiverId
          : receiverId // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as FriendshipStatus,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      acceptedAt: freezed == acceptedAt
          ? _value.acceptedAt
          : acceptedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      senderUsername: freezed == senderUsername
          ? _value.senderUsername
          : senderUsername // ignore: cast_nullable_to_non_nullable
              as String?,
      senderPhotoUrl: freezed == senderPhotoUrl
          ? _value.senderPhotoUrl
          : senderPhotoUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      receiverUsername: freezed == receiverUsername
          ? _value.receiverUsername
          : receiverUsername // ignore: cast_nullable_to_non_nullable
              as String?,
      receiverPhotoUrl: freezed == receiverPhotoUrl
          ? _value.receiverPhotoUrl
          : receiverPhotoUrl // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _$FriendshipModelImpl extends _FriendshipModel {
  const _$FriendshipModelImpl(
      {required this.id,
      required this.senderId,
      required this.receiverId,
      required this.status,
      required this.createdAt,
      this.acceptedAt,
      this.senderUsername,
      this.senderPhotoUrl,
      this.receiverUsername,
      this.receiverPhotoUrl})
      : super._();

  factory _$FriendshipModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$FriendshipModelImplFromJson(json);

  /// Row id (uuid)
  @override
  final String id;

  /// User who sent the friend request
  @override
  final String senderId;

  /// User who received the friend request
  @override
  final String receiverId;

  /// Current status of the friendship
  @override
  final FriendshipStatus status;

  /// When the request was sent
  @override
  final DateTime createdAt;

  /// When the request was accepted (null if pending)
  @override
  final DateTime? acceptedAt;

  /// Sender's username (denormalized for display)
  @override
  final String? senderUsername;

  /// Sender's photo URL (denormalized)
  @override
  final String? senderPhotoUrl;

  /// Receiver's username (denormalized)
  @override
  final String? receiverUsername;

  /// Receiver's photo URL (denormalized)
  @override
  final String? receiverPhotoUrl;

  @override
  String toString() {
    return 'FriendshipModel(id: $id, senderId: $senderId, receiverId: $receiverId, status: $status, createdAt: $createdAt, acceptedAt: $acceptedAt, senderUsername: $senderUsername, senderPhotoUrl: $senderPhotoUrl, receiverUsername: $receiverUsername, receiverPhotoUrl: $receiverPhotoUrl)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FriendshipModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.senderId, senderId) ||
                other.senderId == senderId) &&
            (identical(other.receiverId, receiverId) ||
                other.receiverId == receiverId) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.acceptedAt, acceptedAt) ||
                other.acceptedAt == acceptedAt) &&
            (identical(other.senderUsername, senderUsername) ||
                other.senderUsername == senderUsername) &&
            (identical(other.senderPhotoUrl, senderPhotoUrl) ||
                other.senderPhotoUrl == senderPhotoUrl) &&
            (identical(other.receiverUsername, receiverUsername) ||
                other.receiverUsername == receiverUsername) &&
            (identical(other.receiverPhotoUrl, receiverPhotoUrl) ||
                other.receiverPhotoUrl == receiverPhotoUrl));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      senderId,
      receiverId,
      status,
      createdAt,
      acceptedAt,
      senderUsername,
      senderPhotoUrl,
      receiverUsername,
      receiverPhotoUrl);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$FriendshipModelImplCopyWith<_$FriendshipModelImpl> get copyWith =>
      __$$FriendshipModelImplCopyWithImpl<_$FriendshipModelImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$FriendshipModelImplToJson(
      this,
    );
  }
}

abstract class _FriendshipModel extends FriendshipModel {
  const factory _FriendshipModel(
      {required final String id,
      required final String senderId,
      required final String receiverId,
      required final FriendshipStatus status,
      required final DateTime createdAt,
      final DateTime? acceptedAt,
      final String? senderUsername,
      final String? senderPhotoUrl,
      final String? receiverUsername,
      final String? receiverPhotoUrl}) = _$FriendshipModelImpl;
  const _FriendshipModel._() : super._();

  factory _FriendshipModel.fromJson(Map<String, dynamic> json) =
      _$FriendshipModelImpl.fromJson;

  @override

  /// Row id (uuid)
  String get id;
  @override

  /// User who sent the friend request
  String get senderId;
  @override

  /// User who received the friend request
  String get receiverId;
  @override

  /// Current status of the friendship
  FriendshipStatus get status;
  @override

  /// When the request was sent
  DateTime get createdAt;
  @override

  /// When the request was accepted (null if pending)
  DateTime? get acceptedAt;
  @override

  /// Sender's username (denormalized for display)
  String? get senderUsername;
  @override

  /// Sender's photo URL (denormalized)
  String? get senderPhotoUrl;
  @override

  /// Receiver's username (denormalized)
  String? get receiverUsername;
  @override

  /// Receiver's photo URL (denormalized)
  String? get receiverPhotoUrl;
  @override
  @JsonKey(ignore: true)
  _$$FriendshipModelImplCopyWith<_$FriendshipModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

FriendInfo _$FriendInfoFromJson(Map<String, dynamic> json) {
  return _FriendInfo.fromJson(json);
}

/// @nodoc
mixin _$FriendInfo {
  String get userId => throw _privateConstructorUsedError;
  String get username => throw _privateConstructorUsedError;
  String? get photoUrl => throw _privateConstructorUsedError;
  DateTime? get friendsSince => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $FriendInfoCopyWith<FriendInfo> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FriendInfoCopyWith<$Res> {
  factory $FriendInfoCopyWith(
          FriendInfo value, $Res Function(FriendInfo) then) =
      _$FriendInfoCopyWithImpl<$Res, FriendInfo>;
  @useResult
  $Res call(
      {String userId,
      String username,
      String? photoUrl,
      DateTime? friendsSince});
}

/// @nodoc
class _$FriendInfoCopyWithImpl<$Res, $Val extends FriendInfo>
    implements $FriendInfoCopyWith<$Res> {
  _$FriendInfoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? userId = null,
    Object? username = null,
    Object? photoUrl = freezed,
    Object? friendsSince = freezed,
  }) {
    return _then(_value.copyWith(
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      username: null == username
          ? _value.username
          : username // ignore: cast_nullable_to_non_nullable
              as String,
      photoUrl: freezed == photoUrl
          ? _value.photoUrl
          : photoUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      friendsSince: freezed == friendsSince
          ? _value.friendsSince
          : friendsSince // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$FriendInfoImplCopyWith<$Res>
    implements $FriendInfoCopyWith<$Res> {
  factory _$$FriendInfoImplCopyWith(
          _$FriendInfoImpl value, $Res Function(_$FriendInfoImpl) then) =
      __$$FriendInfoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String userId,
      String username,
      String? photoUrl,
      DateTime? friendsSince});
}

/// @nodoc
class __$$FriendInfoImplCopyWithImpl<$Res>
    extends _$FriendInfoCopyWithImpl<$Res, _$FriendInfoImpl>
    implements _$$FriendInfoImplCopyWith<$Res> {
  __$$FriendInfoImplCopyWithImpl(
      _$FriendInfoImpl _value, $Res Function(_$FriendInfoImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? userId = null,
    Object? username = null,
    Object? photoUrl = freezed,
    Object? friendsSince = freezed,
  }) {
    return _then(_$FriendInfoImpl(
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      username: null == username
          ? _value.username
          : username // ignore: cast_nullable_to_non_nullable
              as String,
      photoUrl: freezed == photoUrl
          ? _value.photoUrl
          : photoUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      friendsSince: freezed == friendsSince
          ? _value.friendsSince
          : friendsSince // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _$FriendInfoImpl implements _FriendInfo {
  const _$FriendInfoImpl(
      {required this.userId,
      required this.username,
      this.photoUrl,
      this.friendsSince});

  factory _$FriendInfoImpl.fromJson(Map<String, dynamic> json) =>
      _$$FriendInfoImplFromJson(json);

  @override
  final String userId;
  @override
  final String username;
  @override
  final String? photoUrl;
  @override
  final DateTime? friendsSince;

  @override
  String toString() {
    return 'FriendInfo(userId: $userId, username: $username, photoUrl: $photoUrl, friendsSince: $friendsSince)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FriendInfoImpl &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.username, username) ||
                other.username == username) &&
            (identical(other.photoUrl, photoUrl) ||
                other.photoUrl == photoUrl) &&
            (identical(other.friendsSince, friendsSince) ||
                other.friendsSince == friendsSince));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode =>
      Object.hash(runtimeType, userId, username, photoUrl, friendsSince);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$FriendInfoImplCopyWith<_$FriendInfoImpl> get copyWith =>
      __$$FriendInfoImplCopyWithImpl<_$FriendInfoImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$FriendInfoImplToJson(
      this,
    );
  }
}

abstract class _FriendInfo implements FriendInfo {
  const factory _FriendInfo(
      {required final String userId,
      required final String username,
      final String? photoUrl,
      final DateTime? friendsSince}) = _$FriendInfoImpl;

  factory _FriendInfo.fromJson(Map<String, dynamic> json) =
      _$FriendInfoImpl.fromJson;

  @override
  String get userId;
  @override
  String get username;
  @override
  String? get photoUrl;
  @override
  DateTime? get friendsSince;
  @override
  @JsonKey(ignore: true)
  _$$FriendInfoImplCopyWith<_$FriendInfoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
