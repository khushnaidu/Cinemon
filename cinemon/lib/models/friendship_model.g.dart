// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'friendship_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$FriendshipModelImpl _$$FriendshipModelImplFromJson(
        Map<String, dynamic> json) =>
    _$FriendshipModelImpl(
      id: json['id'] as String,
      senderId: json['senderId'] as String,
      receiverId: json['receiverId'] as String,
      status: $enumDecode(_$FriendshipStatusEnumMap, json['status']),
      createdAt: DateTime.parse(json['createdAt'] as String),
      acceptedAt: json['acceptedAt'] == null
          ? null
          : DateTime.parse(json['acceptedAt'] as String),
      senderUsername: json['senderUsername'] as String?,
      senderPhotoUrl: json['senderPhotoUrl'] as String?,
      receiverUsername: json['receiverUsername'] as String?,
      receiverPhotoUrl: json['receiverPhotoUrl'] as String?,
    );

Map<String, dynamic> _$$FriendshipModelImplToJson(
        _$FriendshipModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'senderId': instance.senderId,
      'receiverId': instance.receiverId,
      'status': _$FriendshipStatusEnumMap[instance.status]!,
      'createdAt': instance.createdAt.toIso8601String(),
      'acceptedAt': instance.acceptedAt?.toIso8601String(),
      'senderUsername': instance.senderUsername,
      'senderPhotoUrl': instance.senderPhotoUrl,
      'receiverUsername': instance.receiverUsername,
      'receiverPhotoUrl': instance.receiverPhotoUrl,
    };

const _$FriendshipStatusEnumMap = {
  FriendshipStatus.pending: 'pending',
  FriendshipStatus.accepted: 'accepted',
  FriendshipStatus.declined: 'declined',
};

_$FriendInfoImpl _$$FriendInfoImplFromJson(Map<String, dynamic> json) =>
    _$FriendInfoImpl(
      userId: json['userId'] as String,
      username: json['username'] as String,
      photoUrl: json['photoUrl'] as String?,
      friendsSince: json['friendsSince'] == null
          ? null
          : DateTime.parse(json['friendsSince'] as String),
    );

Map<String, dynamic> _$$FriendInfoImplToJson(_$FriendInfoImpl instance) =>
    <String, dynamic>{
      'userId': instance.userId,
      'username': instance.username,
      'photoUrl': instance.photoUrl,
      'friendsSince': instance.friendsSince?.toIso8601String(),
    };
