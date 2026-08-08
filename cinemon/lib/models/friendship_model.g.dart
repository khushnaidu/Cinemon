// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'friendship_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$FriendshipModelImpl _$$FriendshipModelImplFromJson(
        Map<String, dynamic> json) =>
    _$FriendshipModelImpl(
      id: json['id'] as String,
      senderId: json['sender_id'] as String,
      receiverId: json['receiver_id'] as String,
      status: $enumDecode(_$FriendshipStatusEnumMap, json['status']),
      createdAt: DateTime.parse(json['created_at'] as String),
      acceptedAt: json['accepted_at'] == null
          ? null
          : DateTime.parse(json['accepted_at'] as String),
      senderUsername: json['sender_username'] as String?,
      senderPhotoUrl: json['sender_photo_url'] as String?,
      receiverUsername: json['receiver_username'] as String?,
      receiverPhotoUrl: json['receiver_photo_url'] as String?,
    );

Map<String, dynamic> _$$FriendshipModelImplToJson(
        _$FriendshipModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'sender_id': instance.senderId,
      'receiver_id': instance.receiverId,
      'status': _$FriendshipStatusEnumMap[instance.status]!,
      'created_at': instance.createdAt.toIso8601String(),
      'accepted_at': instance.acceptedAt?.toIso8601String(),
      'sender_username': instance.senderUsername,
      'sender_photo_url': instance.senderPhotoUrl,
      'receiver_username': instance.receiverUsername,
      'receiver_photo_url': instance.receiverPhotoUrl,
    };

const _$FriendshipStatusEnumMap = {
  FriendshipStatus.pending: 'pending',
  FriendshipStatus.accepted: 'accepted',
  FriendshipStatus.declined: 'declined',
};

_$FriendInfoImpl _$$FriendInfoImplFromJson(Map<String, dynamic> json) =>
    _$FriendInfoImpl(
      userId: json['user_id'] as String,
      username: json['username'] as String,
      photoUrl: json['photo_url'] as String?,
      friendsSince: json['friends_since'] == null
          ? null
          : DateTime.parse(json['friends_since'] as String),
    );

Map<String, dynamic> _$$FriendInfoImplToJson(_$FriendInfoImpl instance) =>
    <String, dynamic>{
      'user_id': instance.userId,
      'username': instance.username,
      'photo_url': instance.photoUrl,
      'friends_since': instance.friendsSince?.toIso8601String(),
    };
