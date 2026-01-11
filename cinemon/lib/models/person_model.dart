import 'package:freezed_annotation/freezed_annotation.dart';

part 'person_model.freezed.dart';
part 'person_model.g.dart';

/// Represents a person (actor/director) from TMDB.
@freezed
class PersonModel with _$PersonModel {
  const PersonModel._();

  const factory PersonModel({
    /// TMDB person ID
    required int id,

    /// Person's name
    required String name,

    /// Profile photo path (TMDB path, not full URL)
    @JsonKey(name: 'profile_path') String? profilePath,

    /// Department they're known for (e.g., "Acting", "Directing")
    @JsonKey(name: 'known_for_department') String? knownForDepartment,

    /// Popularity score from TMDB
    @Default(0.0) double popularity,
  }) = _PersonModel;

  factory PersonModel.fromJson(Map<String, dynamic> json) =>
      _$PersonModelFromJson(json);

  /// Check if this person is primarily an actor
  bool get isActor => knownForDepartment == 'Acting';

  /// Check if this person is primarily a director
  bool get isDirector => knownForDepartment == 'Directing';

  /// Get full profile image URL
  String? get profileUrl {
    if (profilePath == null) return null;
    return 'https://image.tmdb.org/t/p/w185$profilePath';
  }

  /// Get high-res profile image URL
  String? get profileUrlLarge {
    if (profilePath == null) return null;
    return 'https://image.tmdb.org/t/p/w500$profilePath';
  }
}
