import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/user_model.dart';
import '../../person/follow_rails.dart';
import '../favorite_people_picker.dart';
import '../top3_films_section.dart';

/// A profile's Favorites tab: Top 3, favorite actors and directors, and
/// the people they follow for new work.
class FavoritesTab extends StatelessWidget {
  const FavoritesTab({
    super.key,
    required this.profile,
    required this.isOwnProfile,
  });

  final UserModel profile;
  final bool isOwnProfile;

  @override
  Widget build(BuildContext context) {
    return SliverList.list(
      children: [
        const SizedBox(height: AppSpace.lg),
        // Films, swipe for shows.
        Top3Section(
          filmIds: profile.favoriteFilmIds,
          showIds: profile.favoriteShowIds,
          isOwnProfile: isOwnProfile,
        ),
        FavoritePeopleSection(
          personIds: profile.favoriteActorIds,
          isOwnProfile: isOwnProfile,
          title: 'Favorite Actors',
          isActors: true,
        ),
        FavoritePeopleSection(
          personIds: profile.favoriteDirectorIds,
          isOwnProfile: isOwnProfile,
          title: 'Favorite Directors',
          isActors: false,
        ),
        FollowingPeopleRail(userId: profile.uid, isOwnProfile: isOwnProfile),
      ],
    );
  }
}
