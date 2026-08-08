import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/activity_model.dart';
import '../../providers/feed/feed_provider.dart';
import '../../core/constants/api_constants.dart';

/// Bottom sheet for viewing and editing user's own activity
/// Allows editing rating/review and deleting the post
class ActivityDetailSheet extends ConsumerStatefulWidget {
  final ActivityModel activity;

  const ActivityDetailSheet({super.key, required this.activity});

  @override
  ConsumerState<ActivityDetailSheet> createState() => _ActivityDetailSheetState();
}

class _ActivityDetailSheetState extends ConsumerState<ActivityDetailSheet> {
  late double _rating;
  late TextEditingController _reviewController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _rating = widget.activity.rating ?? 0;
    _reviewController = TextEditingController(text: widget.activity.reviewText ?? '');
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  bool get _hasChanges {
    final originalRating = widget.activity.rating ?? 0;
    final originalReview = widget.activity.reviewText ?? '';
    return _rating != originalRating || _reviewController.text.trim() != originalReview;
  }

  Future<void> _saveChanges() async {
    if (!_hasChanges) return;

    setState(() => _isLoading = true);

    final success = await ref.read(createActivityProvider.notifier).updateActivity(
      activity: widget.activity,
      newRating: _rating > 0 ? _rating : null,
      newReviewText: _reviewController.text.trim().isNotEmpty
          ? _reviewController.text.trim()
          : null,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post updated!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update post'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color.fromARGB(255, 30, 30, 40),
        title: const Text(
          'Delete Post',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete your post for "${widget.activity.filmTitle}"?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              setState(() => _isLoading = true);

              await ref.read(createActivityProvider.notifier).deleteActivity(
                widget.activity.id,
                isReview: widget.activity.activityType == ActivityType.reviewed,
                filmId: widget.activity.filmId,
              );

              if (mounted) {
                Navigator.pop(context); // Close bottom sheet
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Post deleted'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPoster() {
    final posterUrl = ApiConstants.getPosterUrl(
      widget.activity.filmPosterPath,
      size: ApiConstants.posterSizeMedium,
    );

    if (posterUrl.isEmpty) {
      return Container(
        width: 80,
        height: 120,
        color: Colors.grey[800],
        child: const Icon(Icons.movie, color: Colors.grey),
      );
    }

    return Image.network(
      posterUrl,
      width: 80,
      height: 120,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          width: 80,
          height: 120,
          color: Colors.grey[800],
          child: const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
              ),
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: 80,
          height: 120,
          color: Colors.grey[800],
          child: const Icon(Icons.movie, color: Colors.grey),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
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
                  // Film info header
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Poster using regular Image.network (CachedNetworkImage causes iOS freeze)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _buildPoster(),
                      ),
                      const SizedBox(width: 16),

                      // Film info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.activity.filmTitle,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (widget.activity.filmYear != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                widget.activity.filmYear!,
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Text(
                              'Posted ${widget.activity.relativeTime}',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Rating section
                  Text(
                    'Your Rating',
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

                  if (_rating == 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Tap left for half star, right for full',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ),

                  const SizedBox(height: 32),

                  // Review section
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Your Review',
                      style: TextStyle(
                        color: Colors.grey[300],
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Review text input
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
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'What did you think?',
                        hintStyle: TextStyle(color: Colors.grey[600]),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(16),
                        counterStyle: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Save button (only show if changes made)
                  if (_hasChanges)
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveChanges,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                                ),
                              )
                            : const Text(
                                'Save Changes',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Delete button
                  TextButton(
                    onPressed: _isLoading ? null : _showDeleteConfirmation,
                    child: const Text(
                      'Delete Post',
                      style: TextStyle(
                        color: Colors.red,
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
