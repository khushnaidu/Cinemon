// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$NotificationModelImpl _$$NotificationModelImplFromJson(
        Map<String, dynamic> json) =>
    _$NotificationModelImpl(
      id: json['id'] as String,
      recipientId: json['recipientId'] as String,
      actorId: json['actorId'] as String,
      actorUsername: json['actorUsername'] as String,
      actorPhotoUrl: json['actorPhotoUrl'] as String?,
      type: $enumDecode(_$NotificationTypeEnumMap, json['type']),
      activityId: json['activityId'] as String?,
      filmTitle: json['filmTitle'] as String?,
      filmPosterPath: json['filmPosterPath'] as String?,
      commentPreview: json['commentPreview'] as String?,
      stickerId: json['stickerId'] as String?,
      isRead: json['isRead'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$$NotificationModelImplToJson(
        _$NotificationModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'recipientId': instance.recipientId,
      'actorId': instance.actorId,
      'actorUsername': instance.actorUsername,
      'actorPhotoUrl': instance.actorPhotoUrl,
      'type': _$NotificationTypeEnumMap[instance.type]!,
      'activityId': instance.activityId,
      'filmTitle': instance.filmTitle,
      'filmPosterPath': instance.filmPosterPath,
      'commentPreview': instance.commentPreview,
      'stickerId': instance.stickerId,
      'isRead': instance.isRead,
      'createdAt': instance.createdAt.toIso8601String(),
    };

const _$NotificationTypeEnumMap = {
  NotificationType.like: 'like',
  NotificationType.comment: 'comment',
  NotificationType.reaction: 'reaction',
  NotificationType.followRequest: 'followRequest',
  NotificationType.followAccepted: 'followAccepted',
};
