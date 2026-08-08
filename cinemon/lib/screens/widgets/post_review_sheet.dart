import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../models/film_model.dart';
import '../../providers/feed/feed_provider.dart';

/// Bottom sheet for posting a review/watch
class PostReviewSheet extends ConsumerStatefulWidget {
  final FilmModel film;

  const PostReviewSheet({super.key, required this.film});

  @override
  ConsumerState<PostReviewSheet> createState() => _PostReviewSheetState();
}

class _PostReviewSheetState extends ConsumerState<PostReviewSheet> {
  double _rating = 0;
  final _reviewController = TextEditingController();
  bool _isPosting = false;

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _postWatch() async {
    setState(() => _isPosting = true);

    final notifier = ref.read(createActivityProvider.notifier);

    if (_rating > 0 || _reviewController.text.isNotEmpty) {
      // Post as a review
      await notifier.postReview(
        film: widget.film,
        rating: _rating,
        reviewText: _reviewController.text.isNotEmpty
            ? _reviewController.text
            : null,
      );
    } else {
      // Post as just watched
      await notifier.postWatched(film: widget.film);
    }

    if (mounted) {
      context.pop(); // Close bottom sheet

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Posted ${widget.film.displayTitle}!'),
          backgroundColor: Colors.green[700],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.surface,
            AppColors.canvas,
          ],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: 24 + bottomInset,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Film poster and info
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Poster
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: widget.film.posterUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: widget.film.posterUrl,
                                width: 100,
                                height: 150,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                width: 100,
                                height: 150,
                                color: Colors.grey[800],
                                child: const Icon(Icons.movie, color: Colors.grey),
                              ),
                      ),
                      const SizedBox(width: 16),

                      // Film info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.film.displayTitle,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (widget.film.year != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                widget.film.year!,
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
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
                                widget.film.isMovie ? 'Movie' : 'TV Show',
                                style: TextStyle(
                                  color: Colors.grey[300],
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            if (widget.film.overview != null &&
                                widget.film.overview!.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Text(
                                widget.film.overview!,
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Rating section
                  Text(
                    'Your Rating (optional)',
                    style: TextStyle(
                      color: Colors.grey[300],
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Star rating input (supports half stars)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final fullValue = index + 1.0;
                      final halfValue = index + 0.5;
                      return GestureDetector(
                        onTapUp: (details) {
                          setState(() {
                            // Determine if tap was on left half (half star) or right half (full star)
                            final tapX = details.localPosition.dx;
                            final isLeftHalf = tapX < 20; // Half of 40px icon
                            final newRating = isLeftHalf ? halfValue : fullValue;

                            // Toggle: tap same value to remove rating
                            if (_rating == newRating) {
                              _rating = 0;
                            } else {
                              _rating = newRating;
                            }
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            _rating >= fullValue
                                ? Icons.star
                                : _rating >= halfValue
                                    ? Icons.star_half
                                    : Icons.star_border,
                            color: _rating >= halfValue
                                ? Colors.amber
                                : Colors.grey[600],
                            size: 40,
                          ),
                        ),
                      );
                    }),
                  ),

                  // Rating hint
                  if (_rating == 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Tap left side for half star, right side for full star',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 11,
                        ),
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Review text input
                  Text(
                    'Your Review (optional)',
                    style: TextStyle(
                      color: Colors.grey[300],
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                    child: TextField(
                      controller: _reviewController,
                      maxLines: 4,
                      maxLength: 500,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'What did you think?',
                        hintStyle: TextStyle(color: Colors.grey[600]),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(16),
                        counterStyle: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Post button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isPosting ? null : _postWatch,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                        elevation: 0,
                      ),
                      child: _isPosting
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(Colors.black),
                              ),
                            )
                          : Text(
                              _rating > 0 || _reviewController.text.isNotEmpty
                                  ? 'Post Review'
                                  : 'Post Watch',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Cancel button
                  TextButton(
                    onPressed: () => context.pop(),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Helper function to show the post review sheet
void showPostReviewSheet(BuildContext context, FilmModel film) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => PostReviewSheet(film: film),
  );
}
