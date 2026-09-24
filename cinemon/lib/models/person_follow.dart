import '../core/constants/api_constants.dart';

/// Someone a user follows (migration 011). The name and portrait are
/// snapshotted when they follow, so a list of follows needs no TMDB call.
class PersonFollow {
  const PersonFollow({
    required this.personId,
    required this.name,
    this.profilePath,
    this.department,
    this.createdAt,
  });

  factory PersonFollow.fromRow(Map<String, dynamic> row) => PersonFollow(
        personId: row['person_id'] as int,
        name: row['person_name'] as String,
        profilePath: row['profile_path'] as String?,
        department: row['department'] as String?,
        createdAt: DateTime.tryParse(row['created_at'] as String? ?? ''),
      );

  final int personId;
  final String name;
  final String? profilePath;
  final String? department;
  final DateTime? createdAt;

  String get profileUrl => ApiConstants.getProfileUrl(profilePath);
}
