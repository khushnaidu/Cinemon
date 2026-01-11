import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../models/activity_model.dart';
import '../../providers/auth/auth_provider.dart';
import '../../providers/feed/feed_provider.dart';
import '../widgets/activity_detail_sheet.dart';

/// Screen showing all user activity/posts in a grid format
class UserActivityScreen extends ConsumerWidget {
  final String userId;
  final String? username;

  const UserActivityScreen({
    super.key,
    required this.userId,
    this.username,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activitiesAsync = ref.watch(userActivitiesProvider(userId));
    final currentUser = ref.watch(currentUserProvider);
    final isOwnProfile = currentUser?.uid == userId;

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
        child: CustomScrollView(
          slivers: [
            // App Bar
            SliverAppBar(
              backgroundColor: Colors.transparent,
              expandedHeight: 0,
              floating: true,
              pinned: true,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => context.pop(),
              ),
              title: Text(
                isOwnProfile
                    ? 'Your Activity'
                    : username != null
                        ? '@$username\'s Activity'
                        : 'Activity',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              centerTitle: true,
            ),

            // Activity Grid
            activitiesAsync.when(
              data: (activities) {
                if (activities.isEmpty) {
                  return SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.movie_outlined,
                            size: 64,
                            color: Colors.white.withOpacity(0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            isOwnProfile
                                ? 'No activity yet\nStart reviewing films!'
                                : 'No activity yet',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 4,
                      crossAxisSpacing: 4,
                      childAspectRatio: 2 / 3,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _ActivityGridItem(
                        activity: activities[index],
                        isOwnActivity: isOwnProfile,
                      ),
                      childCount: activities.length,
                    ),
                  ),
                );
              },
              loading: () => const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white54),
                  ),
                ),
              ),
              error: (error, _) => SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        'Error loading activity',
                        style: TextStyle(color: Colors.red[300]),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => ref.invalidate(userActivitiesProvider(userId)),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Individual activity item in the grid
class _ActivityGridItem extends StatelessWidget {
  final ActivityModel activity;
  final bool isOwnActivity;

  const _ActivityGridItem({
    required this.activity,
    required this.isOwnActivity,
  });

  @override
  Widget build(BuildContext context) {
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
          final mediaType = activity.mediaType.isNotEmpty ? activity.mediaType : 'movie';
          context.push('/film/${activity.filmId}/$mediaType', extra: activity);
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Poster Image
          if (activity.filmPosterPath != null && activity.filmPosterPath!.isNotEmpty)
            CachedNetworkImage(
              imageUrl: 'https://image.tmdb.org/t/p/w300${activity.filmPosterPath}',
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
