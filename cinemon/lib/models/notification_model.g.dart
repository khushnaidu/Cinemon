// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$NotificationModelImpl _$$NotificationModelImplFromJson(
        Map<String, dynamic> json) =>
    _$NotificationModelImpl(
      id: json['id'] as String,
      recipientId: json['recipient_id'] as String,
      actorId: json['actor_id'] as String?,
      actorUsername: json['actor_username'] as String? ?? '',
      actorPhotoUrl: json['actor_photo_url'] as String?,
      type: $enumDecode(_$NotificationTypeEnumMap, json['type']),
      activityId: json['activity_id'] as String?,
      filmTitle: json['film_title'] as String?,
      filmPosterPath: json['film_poster_path'] as String?,
      commentPreview: json['comment_preview'] as String?,
      stickerId: json['sticker_id'] as String?,
      personId: (json['person_id'] as num?)?.toInt(),
      personName: json['person_name'] as String?,
      personProfilePath: json['person_profile_path'] as String?,
      filmId: (json['film_id'] as num?)?.toInt(),
      mediaType: json['media_type'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$$NotificationModelImplToJson(
        _$NotificationModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'recipient_id': instance.recipientId,
      'actor_id': instance.actorId,
      'actor_username': instance.actorUsername,
      'actor_photo_url': instance.actorPhotoUrl,
      'type': _$NotificationTypeEnumMap[instance.type]!,
      'activity_id': instance.activityId,
      'film_title': instance.filmTitle,
      'film_poster_path': instance.filmPosterPath,
      'comment_preview': instance.commentPreview,
      'sticker_id': instance.stickerId,
      'person_id': instance.personId,
      'person_name': instance.personName,
      'person_profile_path': instance.personProfilePath,
      'film_id': instance.filmId,
      'media_type': instance.mediaType,
      'is_read': instance.isRead,
      'created_at': instance.createdAt.toIso8601String(),
    };

const _$NotificationTypeEnumMap = {
  NotificationType.like: 'like',
  NotificationType.comment: 'comment',
  NotificationType.reaction: 'reaction',
  NotificationType.followRequest: 'followRequest',
  NotificationType.followAccepted: 'followAccepted',
  NotificationType.personNewCredit: 'personNewCredit',
};
