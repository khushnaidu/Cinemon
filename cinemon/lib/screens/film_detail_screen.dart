import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/activity_model.dart';
import '../models/film_model.dart';
import '../providers/movie/movie_provider.dart';
import '../providers/feed/feed_provider.dart';
import '../core/constants/api_constants.dart';
import 'widgets/activity_detail_sheet.dart';
import 'widgets/post_review_sheet.dart';

/// Film detail screen showing full film info and friends' reviews
class FilmDetailScreen extends ConsumerWidget {
  final int filmId;
  final String mediaType;
  final ActivityModel? existingActivity;

  const FilmDetailScreen({
    super.key,
    required this.filmId,
    required this.mediaType,
    this.existingActivity,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filmAsync = ref.watch(
      filmDetailsProvider((
        id: filmId,
        mediaType: mediaType == 'tv' ? MediaType.tv : MediaType.movie,
      )),
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: filmAsync.when(
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
                'Failed to load film details',
                style: TextStyle(color: Colors.red[300]),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.invalidate(
                  filmDetailsProvider((
                    id: filmId,
                    mediaType: mediaType == 'tv' ? MediaType.tv : MediaType.movie,
                  )),
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (film) => _FilmDetailContent(
          film: film,
          filmId: filmId,
          existingActivity: existingActivity,
        ),
      ),
    );
  }
}

class _FilmDetailContent extends ConsumerWidget {
  final FilmModel film;
  final int filmId;
  final ActivityModel? existingActivity;

  const _FilmDetailContent({
    required this.film,
    required this.filmId,
    this.existingActivity,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backdropUrl = ApiConstants.getBackdropUrl(film.backdropPath);
    final posterUrl = film.posterUrl;

    // Fetch current user's activity for this film (not the passed activity which could be anyone's)
    final userActivityAsync = ref.watch(userFilmActivityProvider(filmId));
    final userActivity = userActivityAsync.valueOrNull;

    // Use user's own activity, only fall back to existingActivity if it belongs to current user
    final activity = userActivity;

    return CustomScrollView(
      slivers: [
        // Backdrop with back button
        SliverAppBar(
          expandedHeight: 250,
          pinned: true,
          backgroundColor: Colors.black,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => context.pop(),
          ),
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: [
                if (backdropUrl.isNotEmpty)
                  Image.network(
                    backdropUrl,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(color: Colors.grey[900]);
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(color: Colors.grey[900]);
                    },
                  )
                else
                  Container(color: Colors.grey[900]),
                // Gradient overlay
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.8),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Film info section
        SliverToBoxAdapter(
          child: Container(
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
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Poster and title row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Poster
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: posterUrl.isNotEmpty
                            ? Image.network(
                                posterUrl,
                                width: 100,
                                height: 150,
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Container(
                                    width: 100,
                                    height: 150,
                                    color: Colors.grey[800],
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: 100,
                                    height: 150,
                                    color: Colors.grey[800],
                                    child: const Icon(Icons.movie, color: Colors.grey),
                                  );
                                },
                              )
                            : Container(
                                width: 100,
                                height: 150,
                                color: Colors.grey[800],
                                child: const Icon(Icons.movie, color: Colors.grey),
                              ),
                      ),
                      const SizedBox(width: 16),

                      // Title and metadata
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              film.displayTitle,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Year and runtime
                            Row(
                              children: [
                                if (film.year != null) ...[
                                  Text(
                                    film.year!,
                                    style: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                ],
                                if (film.formattedRuntime != null)
                                  Text(
                                    film.formattedRuntime!,
                                    style: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 14,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Media type badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                film.isMovie ? 'Movie' : 'TV Show',
                                style: TextStyle(
                                  color: Colors.grey[300],
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // TMDB rating
                            if (film.voteAverage > 0)
                              Row(
                                children: [
                                  const Icon(
                                    Icons.star,
                                    color: Colors.amber,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${film.voteAverage.toStringAsFixed(1)}/10',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (film.voteCount > 0)
                                    Text(
                                      ' (${_formatVoteCount(film.voteCount)})',
                                      style: TextStyle(
                                        color: Colors.grey[500],
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Tagline
                  if (film.tagline != null && film.tagline!.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text(
                      '"${film.tagline}"',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],

                  // Overview
                  if (film.overview != null && film.overview!.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Text(
                      'Overview',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      film.overview!,
                      style: TextStyle(
                        color: Colors.grey[300],
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ],

                  // User's activity section
                  const SizedBox(height: 24),
                  _buildUserActivitySection(context, ref, activity, film),

                  // Friends' reviews section - loaded separately to avoid blocking
                  const SizedBox(height: 24),
                  _FriendsReviewsSection(filmId: filmId),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUserActivitySection(
    BuildContext context,
    WidgetRef ref,
    ActivityModel? activity,
    FilmModel film,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your Activity',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),

        if (activity != null) ...[
          // Show user's existing activity
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Rating
                if (activity.rating != null && activity.rating! > 0)
                  Row(
                    children: List.generate(5, (index) {
                      return Icon(
                        activity.rating! >= index + 1
                            ? Icons.star
                            : Icons.star_border,
                        color: activity.rating! >= index + 1
                            ? Colors.amber
                            : Colors.grey[600],
                        size: 24,
                      );
                    }),
                  )
                else
                  Text(
                    'Watched',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14,
                    ),
                  ),

                // Review text
                if (activity.reviewText != null &&
                    activity.reviewText!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    activity.reviewText!,
                    style: TextStyle(
                      color: Colors.grey[300],
                      fontSize: 14,
                      height: 1.4,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                const SizedBox(height: 12),
                Text(
                  'Posted ${activity.relativeTime}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Edit button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => ActivityDetailSheet(activity: activity),
                );
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                'Edit Your Post',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ] else ...[
          // No activity yet - show post button
          Text(
            'You haven\'t posted about this film yet.',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                // Show post review sheet
                showPostReviewSheet(context, film);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
              ),
              child: const Text(
                'Post a Review',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _formatVoteCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
}

/// Card showing a friend's review
class _FriendReviewCard extends StatelessWidget {
  final ActivityModel activity;

  const _FriendReviewCard({required this.activity});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User info row
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.grey[800],
                backgroundImage: activity.userPhotoUrl != null
                    ? NetworkImage(activity.userPhotoUrl!)
                    : null,
                child: activity.userPhotoUrl == null
                    ? const Icon(Icons.person, color: Colors.white54, size: 16)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '@${activity.username}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      activity.relativeTime,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              // Rating
              if (activity.rating != null && activity.rating! > 0)
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      activity.rating!.toStringAsFixed(0),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // Review text
          if (activity.reviewText != null && activity.reviewText!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              activity.reviewText!,
              style: TextStyle(
                color: Colors.grey[300],
                fontSize: 13,
                height: 1.4,
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

/// Friends reviews section that loads independently with timeout
class _FriendsReviewsSection extends ConsumerWidget {
  final int filmId;

  const _FriendsReviewsSection({required this.filmId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friendsActivitiesAsync = ref.watch(friendsFilmActivitiesProvider(filmId));

    return friendsActivitiesAsync.when(
      loading: () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Friends\' Reviews',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[600]!),
                ),
              ),
            ),
          ),
        ],
      ),
      error: (_, __) => const SizedBox.shrink(), // Hide on error (index might be building)
      data: (activities) {
        if (activities.isEmpty) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Friends\' Reviews (${activities.length})',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...activities.map((activity) => _FriendReviewCard(activity: activity)),
          ],
        );
      },
    );
  }
}
