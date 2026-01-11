// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'activity_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ActivityModelImpl _$$ActivityModelImplFromJson(Map<String, dynamic> json) =>
    _$ActivityModelImpl(
      id: json['id'] as String,
      userId: json['userId'] as String,
      username: json['username'] as String,
      userPhotoUrl: json['userPhotoUrl'] as String?,
      activityType: $enumDecode(_$ActivityTypeEnumMap, json['activityType']),
      filmId: (json['filmId'] as num).toInt(),
      filmTitle: json['filmTitle'] as String,
      filmPosterPath: json['filmPosterPath'] as String?,
      filmBackdropPath: json['filmBackdropPath'] as String?,
      filmYear: json['filmYear'] as String?,
      mediaType: json['mediaType'] as String? ?? 'movie',
      rating: (json['rating'] as num?)?.toDouble(),
      reviewText: json['reviewText'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      likes:
          (json['likes'] as List<dynamic>?)?.map((e) => e as String).toList() ??
              const [],
      commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
      reactions: (json['reactions'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, e as String),
          ) ??
          const {},
    );

Map<String, dynamic> _$$ActivityModelImplToJson(_$ActivityModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'username': instance.username,
      'userPhotoUrl': instance.userPhotoUrl,
      'activityType': _$ActivityTypeEnumMap[instance.activityType]!,
      'filmId': instance.filmId,
      'filmTitle': instance.filmTitle,
      'filmPosterPath': instance.filmPosterPath,
      'filmBackdropPath': instance.filmBackdropPath,
      'filmYear': instance.filmYear,
      'mediaType': instance.mediaType,
      'rating': instance.rating,
      'reviewText': instance.reviewText,
      'createdAt': instance.createdAt.toIso8601String(),
      'likes': instance.likes,
      'commentCount': instance.commentCount,
      'reactions': instance.reactions,
    };

const _$ActivityTypeEnumMap = {
  ActivityType.watched: 'watched',
  ActivityType.reviewed: 'reviewed',
};

_$CommentModelImpl _$$CommentModelImplFromJson(Map<String, dynamic> json) =>
    _$CommentModelImpl(
      id: json['id'] as String,
      activityId: json['activityId'] as String,
      userId: json['userId'] as String,
      username: json['username'] as String,
      userPhotoUrl: json['userPhotoUrl'] as String?,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$$CommentModelImplToJson(_$CommentModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'activityId': instance.activityId,
      'userId': instance.userId,
      'username': instance.username,
      'userPhotoUrl': instance.userPhotoUrl,
      'content': instance.content,
      'createdAt': instance.createdAt.toIso8601String(),
    };
