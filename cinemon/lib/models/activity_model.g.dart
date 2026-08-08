// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'activity_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ActivityModelImpl _$$ActivityModelImplFromJson(Map<String, dynamic> json) =>
    _$ActivityModelImpl(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      username: json['username'] as String,
      userPhotoUrl: json['user_photo_url'] as String?,
      activityType: $enumDecode(_$ActivityTypeEnumMap, json['activity_type']),
      filmId: (json['film_id'] as num).toInt(),
      filmTitle: json['film_title'] as String,
      filmPosterPath: json['film_poster_path'] as String?,
      filmBackdropPath: json['film_backdrop_path'] as String?,
      filmYear: json['film_year'] as String?,
      mediaType: json['media_type'] as String? ?? 'movie',
      rating: (json['rating'] as num?)?.toDouble(),
      reviewText: json['review_text'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      likes:
          (json['likes'] as List<dynamic>?)?.map((e) => e as String).toList() ??
              const [],
      commentCount: (json['comment_count'] as num?)?.toInt() ?? 0,
      reactions: (json['reactions'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, e as String),
          ) ??
          const {},
    );

Map<String, dynamic> _$$ActivityModelImplToJson(_$ActivityModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'username': instance.username,
      'user_photo_url': instance.userPhotoUrl,
      'activity_type': _$ActivityTypeEnumMap[instance.activityType]!,
      'film_id': instance.filmId,
      'film_title': instance.filmTitle,
      'film_poster_path': instance.filmPosterPath,
      'film_backdrop_path': instance.filmBackdropPath,
      'film_year': instance.filmYear,
      'media_type': instance.mediaType,
      'rating': instance.rating,
      'review_text': instance.reviewText,
      'created_at': instance.createdAt.toIso8601String(),
      'likes': instance.likes,
      'comment_count': instance.commentCount,
      'reactions': instance.reactions,
    };

const _$ActivityTypeEnumMap = {
  ActivityType.watched: 'watched',
  ActivityType.reviewed: 'reviewed',
};

_$CommentModelImpl _$$CommentModelImplFromJson(Map<String, dynamic> json) =>
    _$CommentModelImpl(
      id: json['id'] as String,
      activityId: json['activity_id'] as String,
      userId: json['user_id'] as String,
      username: json['username'] as String,
      userPhotoUrl: json['user_photo_url'] as String?,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$$CommentModelImplToJson(_$CommentModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'activity_id': instance.activityId,
      'user_id': instance.userId,
      'username': instance.username,
      'user_photo_url': instance.userPhotoUrl,
      'content': instance.content,
      'created_at': instance.createdAt.toIso8601String(),
    };
