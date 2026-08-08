// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$UserModelImpl _$$UserModelImplFromJson(Map<String, dynamic> json) =>
    _$UserModelImpl(
      uid: json['id'] as String,
      email: json['email'] as String,
      username: json['username'] as String,
      displayName: json['display_name'] as String?,
      photoUrl: json['photo_url'] as String?,
      bio: json['bio'] as String?,
      badgeIds: (json['badge_ids'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      reviewCount: (json['review_count'] as num?)?.toInt() ?? 0,
      followerCount: (json['follower_count'] as num?)?.toInt() ?? 0,
      followingCount: (json['following_count'] as num?)?.toInt() ?? 0,
      favoriteGenres: (json['favorite_genres'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      favoriteFilmIds: (json['favorite_film_ids'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
      favoriteActorIds: (json['favorite_actor_ids'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
      favoriteDirectorIds: (json['favorite_director_ids'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
      createdAt: DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$$UserModelImplToJson(_$UserModelImpl instance) =>
    <String, dynamic>{
      'id': instance.uid,
      'email': instance.email,
      'username': instance.username,
      'display_name': instance.displayName,
      'photo_url': instance.photoUrl,
      'bio': instance.bio,
      'badge_ids': instance.badgeIds,
      'review_count': instance.reviewCount,
      'follower_count': instance.followerCount,
      'following_count': instance.followingCount,
      'favorite_genres': instance.favoriteGenres,
      'favorite_film_ids': instance.favoriteFilmIds,
      'favorite_actor_ids': instance.favoriteActorIds,
      'favorite_director_ids': instance.favoriteDirectorIds,
      'created_at': instance.createdAt.toIso8601String(),
    };
