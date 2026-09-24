import 'package:freezed_annotation/freezed_annotation.dart';
import '../core/constants/api_constants.dart';

part 'episode_model.freezed.dart';
part 'episode_model.g.dart';

/// One season of a TV show, as listed on the show's TMDB details.
@freezed
class SeasonModel with _$SeasonModel {
  const SeasonModel._();

  const factory SeasonModel({
    required int id,
    @JsonKey(name: 'season_number') required int seasonNumber,
    String? name,
    String? overview,
    @JsonKey(name: 'poster_path') String? posterPath,
    @JsonKey(name: 'air_date') String? airDate,
    @JsonKey(name: 'episode_count') @Default(0) int episodeCount,
  }) = _SeasonModel;

  factory SeasonModel.fromJson(Map<String, dynamic> json) =>
      _$SeasonModelFromJson(json);

  /// TMDB files specials under season 0.
  bool get isSpecials => seasonNumber == 0;

  /// "Season 3", or the show's own name for it when it has one that isn't
  /// just the number restated.
  String get label {
    final n = name;
    if (n != null && n.isNotEmpty && n != 'Season $seasonNumber') return n;
    return isSpecials ? 'Specials' : 'Season $seasonNumber';
  }

  String? get year {
    final d = airDate;
    if (d == null || d.isEmpty) return null;
    return d.split('-').first;
  }
}

/// One episode, from `/tv/{id}/season/{n}`.
@freezed
class EpisodeModel with _$EpisodeModel {
  const EpisodeModel._();

  const factory EpisodeModel({
    required int id,
    @JsonKey(name: 'episode_number') required int episodeNumber,
    @JsonKey(name: 'season_number') required int seasonNumber,
    String? name,
    String? overview,
    @JsonKey(name: 'still_path') String? stillPath,
    @JsonKey(name: 'air_date') String? airDate,
    int? runtime,
    @JsonKey(name: 'vote_average') @Default(0.0) double voteAverage,
    @JsonKey(name: 'vote_count') @Default(0) int voteCount,
  }) = _EpisodeModel;

  factory EpisodeModel.fromJson(Map<String, dynamic> json) =>
      _$EpisodeModelFromJson(json);

  /// "S2 E5" — the compact tag that goes on every card and row.
  String get code => 'S$seasonNumber E$episodeNumber';

  String get displayName =>
      (name == null || name!.isEmpty) ? 'Episode $episodeNumber' : name!;

  String get stillUrl => ApiConstants.getStillUrl(stillPath);

  String? get formattedRuntime {
    final r = runtime;
    if (r == null || r <= 0) return null;
    final h = r ~/ 60, m = r % 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }

  /// Whether the episode has aired yet, judged against the device clock.
  bool get hasAired {
    final d = airDate;
    if (d == null || d.isEmpty) return true;
    final date = DateTime.tryParse(d);
    return date == null || !date.isAfter(DateTime.now());
  }

  /// "12 Mar 2024".
  String? get formattedAirDate {
    final d = airDate;
    if (d == null || d.isEmpty) return null;
    final date = DateTime.tryParse(d);
    if (date == null) return d;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
