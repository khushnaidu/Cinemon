import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_model.freezed.dart';
part 'user_model.g.dart';

/// Represents a Cinémon user profile — the `public.profiles` table.
///
/// Contains all user data including profile info, social stats, and badges.
/// Uses Freezed for immutability and automatic JSON serialization.
///
/// `fieldRename: snake` maps Dart camelCase to Postgres snake_case columns
/// (displayName <-> display_name), so rows round-trip without hand-mapping.
@freezed
class UserModel with _$UserModel {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory UserModel({
    /// Supabase Auth user id — primary key of `profiles`
    @JsonKey(name: 'id') required String uid,
    
    /// User's email address
    required String email,
    
    /// Unique username for search/display (e.g., @filmfan42)
    required String username,
    
    /// Optional display name (can be different from username)
    String? displayName,
    
    /// Profile photo URL (Supabase Storage, `avatars` bucket)
    String? photoUrl,
    
    /// User bio/description
    String? bio,
    
    /// IDs of badges the user has earned
    @Default([]) List<String> badgeIds,
    
    /// Total number of reviews posted
    @Default(0) int reviewCount,
    
    /// Number of followers
    @Default(0) int followerCount,
    
    /// Number of users this user follows
    @Default(0) int followingCount,
    
    /// User's favorite movie genres
    @Default([]) List<String> favoriteGenres,

    /// Favorite film IDs (TMDB IDs, max 4)
    @Default([]) List<int> favoriteFilmIds,

    /// Favorite actor IDs (TMDB person IDs, max 4)
    @Default([]) List<int> favoriteActorIds,

    /// Favorite director IDs (TMDB person IDs, max 4)
    @Default([]) List<int> favoriteDirectorIds,

    /// Account creation timestamp
    required DateTime createdAt,
  }) = _UserModel;

  /// Creates a UserModel from a `profiles` row
  factory UserModel.fromJson(Map<String, dynamic> json) => 
      _$UserModelFromJson(json);
}

/// Extension for database-specific operations
extension UserModelDb on UserModel {
  /// Columns that are maintained by DB triggers, not the client.
  /// Sending them in an update is a no-op at best and a lost-update race
  /// at worst, so they are stripped before writing.
  static const _serverManaged = {
    'review_count',
    'follower_count',
    'following_count',
    'created_at',
  };

  /// Converts to a payload safe to `upsert` into `profiles`.
  Map<String, dynamic> toDbMap() {
    final json = toJson()..removeWhere((k, _) => _serverManaged.contains(k));
    return json;
  }

  /// Creates a new user with minimal required fields
  static UserModel createNew({
    required String uid,
    required String email,
    required String username,
  }) {
    return UserModel(
      uid: uid,
      email: email,
      username: username,
      createdAt: DateTime.now(),
    );
  }
}

