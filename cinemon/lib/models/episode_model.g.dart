// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'episode_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SeasonModelImpl _$$SeasonModelImplFromJson(Map<String, dynamic> json) =>
    _$SeasonModelImpl(
      id: (json['id'] as num).toInt(),
      seasonNumber: (json['season_number'] as num).toInt(),
      name: json['name'] as String?,
      overview: json['overview'] as String?,
      posterPath: json['poster_path'] as String?,
      airDate: json['air_date'] as String?,
      episodeCount: (json['episode_count'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$$SeasonModelImplToJson(_$SeasonModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'season_number': instance.seasonNumber,
      'name': instance.name,
      'overview': instance.overview,
      'poster_path': instance.posterPath,
      'air_date': instance.airDate,
      'episode_count': instance.episodeCount,
    };

_$EpisodeModelImpl _$$EpisodeModelImplFromJson(Map<String, dynamic> json) =>
    _$EpisodeModelImpl(
      id: (json['id'] as num).toInt(),
      episodeNumber: (json['episode_number'] as num).toInt(),
      seasonNumber: (json['season_number'] as num).toInt(),
      name: json['name'] as String?,
      overview: json['overview'] as String?,
      stillPath: json['still_path'] as String?,
      airDate: json['air_date'] as String?,
      runtime: (json['runtime'] as num?)?.toInt(),
      voteAverage: (json['vote_average'] as num?)?.toDouble() ?? 0.0,
      voteCount: (json['vote_count'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$$EpisodeModelImplToJson(_$EpisodeModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'episode_number': instance.episodeNumber,
      'season_number': instance.seasonNumber,
      'name': instance.name,
      'overview': instance.overview,
      'still_path': instance.stillPath,
      'air_date': instance.airDate,
      'runtime': instance.runtime,
      'vote_average': instance.voteAverage,
      'vote_count': instance.voteCount,
    };
