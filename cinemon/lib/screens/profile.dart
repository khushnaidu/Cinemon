import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/activity_model.dart';
import '../models/user_model.dart';
import '../providers/auth/auth_provider.dart';
import '../providers/feed/feed_provider.dart'
    show
        currentUserProfileProvider,
        userProfileProvider,
        homeFeedProvider,
        userActivitiesProvider,
        syncReviewCountProvider;
import '../providers/friendship/friendship_provider.dart';
import '../providers/user/favorites_provider.dart';
import 'widgets/activity_detail_sheet.dart';
import 'widgets/arch_profile_frame.dart';
import 'profile/recently_watched_section.dart';
import 'profile/favorite_films_picker.dart';
import 'profile/favorite_people_picker.dart';
import 'profile/badge_display.dart';
import 'profile/top3_films_section.dart';

/// Profile page showing user info, stats, and posts
/// Can view own profile (userId = null) or another user's profile
class ProfilePage extends ConsumerWidget {
  final String? userId;

  const ProfilePage({super.key, this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    final isOwnProfile = userId == null || userId == currentUser?.uid;

    // Watch the appropriate profile based on whether it's own or other user
    final profileAsync = isOwnProfile
        ? ref.watch(currentUserProfileProvider)
        : ref.watch(userProfileProvider(userId!));

    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black,
              Color.fromARGB(255, 3, 1, 32),
            ],
          ),
        ),
        child: profileAsync.when(
          data: (profile) {
            if (profile == null) {
              return const Center(
                child: Text(
                  'Profile not found',
                  style: TextStyle(color: Colors.white),
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                // Refresh profile and activities
                if (isOwnProfile) {
                  ref.invalidate(currentUserProfileProvider);
                  ref.invalidate(userActivitiesProvider(profile.uid));
                  ref.invalidate(currentUserFavoriteFilmsProvider);
                  ref.invalidate(currentUserFavoriteActorsProvider);
                  ref.invalidate(currentUserFavoriteDirectorsProvider);
                  ref.invalidate(currentUserRecentlyWatchedProvider);
                } else {
                  ref.invalidate(userProfileProvider(profile.uid));
                  ref.invalidate(userActivitiesProvider(profile.uid));
                  ref.invalidate(recentlyWatchedProvider(profile.uid));
                }
                // Wait for refresh to complete
                await Future.delayed(const Duration(milliseconds: 500));
              },
              color: Colors.white,
              backgroundColor: const Color.fromARGB(255, 30, 30, 50),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // App Bar
                  SliverAppBar(
                    backgroundColor: Colors.transparent,
                    expandedHeight: 0,
                    floating: true,
                    pinned: false,
                    leading: !isOwnProfile
                        ? IconButton(
                            icon: const Icon(Icons.arrow_back,
                                color: Colors.white),
                            onPressed: () => context.pop(),
                          )
                        : null,
                    actions: isOwnProfile
                        ? [
                            IconButton(
                              icon: const Icon(Icons.settings,
                                  color: Colors.white),
                              onPressed: () => _showSettingsMenu(context, ref),
                            ),
                          ]
                        : null,
                  ),

                  // Profile Header with Backdrop
                  SliverToBoxAdapter(
                    child: Stack(
                      alignment: Alignment.topCenter,
                      children: [
                        // Full-width backdrop image (temporarily disabled)
                        // Positioned(
                        //   top: 0,
                        //   left: 0,
                        //   right: 0,
                        //   child: Image.asset(
                        //     'assets/images/profbackdrop.png',
                        //     width: double.infinity,
                        //     fit: BoxFit.fitWidth,
                        //   ),
                        // ),
                        // Profile content
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            children: [
                              const SizedBox(height: 10),

                              // Profile Photo with Arch Frame and Username
                              ArchProfileFrame(
                                photoUrl: profile.photoUrl,
                                username: profile.username,
                                width: 120,
                                height: 160,
                                glowColor: const Color(0xFFFFD54F),
                              ),
                              const SizedBox(height: 8),

                              // Display name if different
                              if (profile.displayName != null &&
                                  profile.displayName != profile.username)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    profile.displayName!,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),

                              // Bio
                              if (profile.bio != null &&
                                  profile.bio!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Text(
                                    profile.bio!,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),

                              const SizedBox(height: 20),

                              // Stats Row
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildStatColumn(
                                      profile.reviewCount.toString(),
                                      'Reviews'),
                                  const SizedBox(width: 40),
                                  _buildStatColumn(
                                      profile.followerCount.toString(),
                                      'Followers'),
                                  const SizedBox(width: 40),
                                  _buildStatColumn(
                                      profile.followingCount.toString(),
                                      'Following'),
                                ],
                              ),

                              const SizedBox(height: 20),

                              // Action Button (Edit Profile or Follow/Unfollow)
                              if (isOwnProfile)
                                _EditProfileButton()
                              else
                                _FollowButton(
                                    targetUserId: profile.uid,
                                    targetProfile: profile),

                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Recently Watched Section
                  SliverToBoxAdapter(
                    child: RecentlyWatchedSection(
                      userId: profile.uid,
                      isOwnProfile: isOwnProfile,
                      username: profile.username,
                    ),
                  ),

                  // Top 3 Films Section
                  SliverToBoxAdapter(
                    child: Top3FilmsSection(
                      filmIds: profile.favoriteFilmIds,
                      isOwnProfile: isOwnProfile,
                    ),
                  ),

                  // Favorite Actors Section
                  SliverToBoxAdapter(
                    child: FavoritePeopleSection(
                      personIds: profile.favoriteActorIds,
                      isOwnProfile: isOwnProfile,
                      title: 'Favorite Actors',
                      isActors: true,
                    ),
                  ),

                  // Favorite Directors Section
                  SliverToBoxAdapter(
                    child: FavoritePeopleSection(
                      personIds: profile.favoriteDirectorIds,
                      isOwnProfile: isOwnProfile,
                      title: 'Favorite Directors',
                      isActors: false,
                    ),
                  ),

                  // Badges Section
                  SliverToBoxAdapter(
                    child: BadgeSection(
                      badgeIds: profile.badgeIds,
                      isOwnProfile: isOwnProfile,
                    ),
                  ),

                  // Activity Section - removed from profile, will be separate page
                  // TODO: Add "View All Activity" button that navigates to activity page
                ],
              ),
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          error: (error, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Error loading profile',
                  style: TextStyle(color: Colors.red[300]),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    if (isOwnProfile) {
                      ref.invalidate(currentUserProfileProvider);
                    } else {
                      ref.invalidate(userProfileProvider(userId!));
                    }
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatColumn(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Isometric3D',
            color: Colors.white,
            fontSize: 40,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  void _showSettingsMenu(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color.fromARGB(255, 20, 20, 30),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.sync, color: Colors.white),
              title: const Text(
                'Sync Review Count',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                'Fix if your review count is incorrect',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              onTap: () async {
                Navigator.pop(context);
                final currentUser = ref.read(currentUserProvider);
                if (currentUser != null) {
                  // Show loading indicator
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Syncing review count...'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                  // Trigger sync
                  final count = await ref
                      .read(syncReviewCountProvider(currentUser.uid).future);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Review count synced: $count reviews'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                'Sign Out',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () async {
                Navigator.pop(context);
                // Clear cached user data before signing out
                ref.invalidate(currentUserProfileProvider);
                ref.invalidate(homeFeedProvider);
                ref.invalidate(friendIdsProvider);
                await ref.read(authControllerProvider.notifier).signOut();
                if (context.mounted) {
                  context.go('/login');
                }
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

/// Edit Profile button for own profile
class _EditProfileButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: OutlinedButton(
        onPressed: () => context.push('/edit-profile'),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.white54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: const Text(
          'Edit Profile',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// Follow/Unfollow button for other users' profiles
class _FollowButton extends ConsumerWidget {
  final String targetUserId;
  final UserModel targetProfile;

  const _FollowButton({
    required this.targetUserId,
    required this.targetProfile,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friendshipAsync = ref.watch(friendshipStatusProvider(targetUserId));
    final friendshipNotifier = ref.watch(friendshipNotifierProvider);
    final currentProfile = ref.watch(currentUserProfileProvider).value;

    return friendshipAsync.when(
      data: (friendship) {
        final isLoading = friendshipNotifier.isLoading;

        // Determine button state based on friendship status
        if (friendship == null) {
          // No relationship - show Follow button
          return _buildButton(
            label: 'Follow',
            isLoading: isLoading,
            isPrimary: true,
            onPressed: () async {
              await ref
                  .read(friendshipNotifierProvider.notifier)
                  .sendFriendRequest(
                    receiverId: targetUserId,
                    senderUsername: currentProfile?.username,
                    senderPhotoUrl: currentProfile?.photoUrl,
                    receiverUsername: targetProfile.username,
                    receiverPhotoUrl: targetProfile.photoUrl,
                  );
              // Refresh the status
              ref.invalidate(friendshipStatusProvider(targetUserId));
            },
          );
        }

        if (friendship.isPending) {
          final currentUser = ref.read(currentUserProvider);
          final isSender = friendship.senderId == currentUser?.uid;

          if (isSender) {
            // Current user sent the request - show Requested
            return _buildButton(
              label: 'Requested',
              isLoading: isLoading,
              isPrimary: false,
              onPressed: () async {
                // Cancel the request
                await ref
                    .read(friendshipNotifierProvider.notifier)
                    .unfriend(targetUserId);
                ref.invalidate(friendshipStatusProvider(targetUserId));
              },
            );
          } else {
            // Current user received the request - show Accept/Decline
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildButton(
                  label: 'Accept',
                  isLoading: isLoading,
                  isPrimary: true,
                  width: 100,
                  onPressed: () async {
                    await ref
                        .read(friendshipNotifierProvider.notifier)
                        .acceptFriendRequest(
                          friendship.id,
                          senderId: friendship.senderId,
                          senderUsername: friendship.senderUsername,
                          senderPhotoUrl: friendship.senderPhotoUrl,
                          receiverUsername: friendship.receiverUsername,
                          receiverPhotoUrl: friendship.receiverPhotoUrl,
                        );
                    ref.invalidate(friendshipStatusProvider(targetUserId));
                    ref.invalidate(currentUserProfileProvider);
                    ref.invalidate(userProfileProvider(targetUserId));
                  },
                ),
                const SizedBox(width: 12),
                _buildButton(
                  label: 'Decline',
                  isLoading: isLoading,
                  isPrimary: false,
                  width: 100,
                  onPressed: () async {
                    await ref
                        .read(friendshipNotifierProvider.notifier)
                        .declineFriendRequest(friendship.id);
                    ref.invalidate(friendshipStatusProvider(targetUserId));
                  },
                ),
              ],
            );
          }
        }

        if (friendship.isAccepted) {
          // Already friends - show Following
          return _buildButton(
            label: 'Following',
            isLoading: isLoading,
            isPrimary: false,
            onPressed: () {
              // Show confirmation dialog before unfollowing
              _showUnfollowDialog(
                  context, ref, targetUserId, targetProfile.username);
            },
          );
        }

        // Declined - show Follow button again
        return _buildButton(
          label: 'Follow',
          isLoading: isLoading,
          isPrimary: true,
          onPressed: () async {
            await ref
                .read(friendshipNotifierProvider.notifier)
                .sendFriendRequest(
                  receiverId: targetUserId,
                  senderUsername: currentProfile?.username,
                  senderPhotoUrl: currentProfile?.photoUrl,
                  receiverUsername: targetProfile.username,
                  receiverPhotoUrl: targetProfile.photoUrl,
                );
            ref.invalidate(friendshipStatusProvider(targetUserId));
          },
        );
      },
      loading: () => _buildButton(
        label: 'Loading...',
        isLoading: true,
        isPrimary: false,
        onPressed: null,
      ),
      error: (_, __) => _buildButton(
        label: 'Follow',
        isLoading: false,
        isPrimary: true,
        onPressed: () async {
          await ref.read(friendshipNotifierProvider.notifier).sendFriendRequest(
                receiverId: targetUserId,
                senderUsername: currentProfile?.username,
                senderPhotoUrl: currentProfile?.photoUrl,
                receiverUsername: targetProfile.username,
                receiverPhotoUrl: targetProfile.photoUrl,
              );
          ref.invalidate(friendshipStatusProvider(targetUserId));
        },
      ),
    );
  }

  Widget _buildButton({
    required String label,
    required bool isLoading,
    required bool isPrimary,
    VoidCallback? onPressed,
    double width = 200,
  }) {
    return SizedBox(
      width: width,
      child: isPrimary
          ? ElevatedButton(
              onPressed: isLoading ? null : onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                      ),
                    )
                  : Text(
                      label,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
            )
          : OutlinedButton(
              onPressed: isLoading ? null : onPressed,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
            ),
    );
  }

  void _showUnfollowDialog(
      BuildContext context, WidgetRef ref, String userId, String username) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color.fromARGB(255, 30, 30, 40),
        title: const Text(
          'Unfollow',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to unfollow @$username?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref
                  .read(friendshipNotifierProvider.notifier)
                  .unfriend(userId);
              ref.invalidate(friendshipStatusProvider(userId));
              ref.invalidate(currentUserProfileProvider);
              ref.invalidate(userProfileProvider(userId));
            },
            child: const Text(
              'Unfollow',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}

/// Grid of user's posts/activities
class _UserPostsGrid extends ConsumerWidget {
  final String userId;

  const _UserPostsGrid({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activitiesAsync = ref.watch(userActivitiesProvider(userId));

    return activitiesAsync.when(
      data: (activities) {
        if (activities.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  Icon(
                    Icons.movie_outlined,
                    size: 64,
                    color: Colors.white.withOpacity(0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No activity yet',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 2 / 3,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _PostGridItem(activity: activities[index]),
              childCount: activities.length,
            ),
          ),
        );
      },
      loading: () => const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white54),
            ),
          ),
        ),
      ),
      error: (error, _) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Center(
            child: Text(
              'Error loading posts',
              style: TextStyle(color: Colors.red[300]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Individual post item in the grid
class _PostGridItem extends ConsumerWidget {
  final ActivityModel activity;

  const _PostGridItem({required this.activity});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    final isOwnActivity = currentUser?.uid == activity.userId;

    return GestureDetector(
      onTap: () {
        if (isOwnActivity) {
          // Show activity detail bottom sheet for editing own posts
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (sheetContext) => ActivityDetailSheet(activity: activity),
          );
        } else {
          final mediaType =
              activity.mediaType.isNotEmpty ? activity.mediaType : 'movie';
          context.push('/film/${activity.filmId}/$mediaType', extra: activity);
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Poster Image
          if (activity.filmPosterPath != null)
            CachedNetworkImage(
              imageUrl:
                  'https://image.tmdb.org/t/p/w300${activity.filmPosterPath}',
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: Colors.grey[900],
                child: const Center(
                  child: Icon(Icons.movie, color: Colors.white24),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                color: Colors.grey[900],
                child: const Center(
                  child: Icon(Icons.broken_image, color: Colors.white24),
                ),
              ),
            )
          else
            Container(
              color: Colors.grey[900],
              child: const Center(
                child: Icon(Icons.movie, color: Colors.white24, size: 32),
              ),
            ),

          // Rating badge (for reviews)
          if (activity.rating != null)
            Positioned(
              bottom: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 12),
                    const SizedBox(width: 2),
                    Text(
                      activity.rating!.toStringAsFixed(1),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Activity type indicator
          Positioned(
            top: 4,
            left: 4,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                activity.activityType == ActivityType.reviewed
                    ? Icons.rate_review
                    : Icons.visibility,
                color: Colors.white70,
                size: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
