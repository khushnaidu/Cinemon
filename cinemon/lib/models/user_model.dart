import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_model.freezed.dart';
part 'user_model.g.dart';

/// Represents a Cinémon user profile stored in Firestore.
/// 
/// Contains all user data including profile info, social stats, and badges.
/// Uses Freezed for immutability and automatic JSON serialization.
@freezed
class UserModel with _$UserModel {
  const factory UserModel({
    /// Firebase Auth UID - unique identifier
    required String uid,
    
    /// User's email address
    required String email,
    
    /// Unique username for search/display (e.g., @filmfan42)
    required String username,
    
    /// Optional display name (can be different from username)
    String? displayName,
    
    /// Profile photo URL (Firebase Storage)
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

  /// Creates a UserModel from Firestore document data
  factory UserModel.fromJson(Map<String, dynamic> json) => 
      _$UserModelFromJson(json);
}

/// Extension for Firestore-specific operations
extension UserModelFirestore on UserModel {
  /// Converts to Firestore-compatible map
  /// Handles DateTime conversion for Firestore Timestamps
  Map<String, dynamic> toFirestore() {
    final json = toJson();
    // Firestore stores DateTime as Timestamp, but we keep it as ISO string
    // for simplicity. If needed, convert here.
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

