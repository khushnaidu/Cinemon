import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../core/constants/api_constants.dart';
import '../core/theme/app_theme.dart';
import 'shell/glass_shell.dart' show kFloatingTabBarInset;
import '../models/activity_model.dart';
import '../models/sticker_model.dart';
import '../providers/auth/auth_provider.dart';
import '../providers/feed/feed_provider.dart';
import '../providers/notification/notification_provider.dart';
import 'widgets/activity_detail_sheet.dart';
import 'widgets/comments_sheet.dart';

import 'widgets/sticker_picker_sheet.dart';
import 'widgets/reactions_preview.dart' show showReactionsBreakdown;

class HomeFeedPage extends ConsumerStatefulWidget {
  const HomeFeedPage({super.key});

  @override
  ConsumerState<HomeFeedPage> createState() => _HomeFeedPageState();
}

class _HomeFeedPageState extends ConsumerState<HomeFeedPage> {
  late PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _pageController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final currentIndex = _pageController.page?.round() ?? 0;
    if (currentIndex != _currentIndex) {
      setState(() {
        _currentIndex = currentIndex;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final feedAsync = ref.watch(homeFeedProvider);
    final unreadCount = ref.watch(unreadNotificationCountProvider);

    return Scaffold(
      // extendBody so the feed runs under the shell's floating tab bar, which
      // is what the glass refracts. Deliberately NOT extendBodyBehindAppBar:
      // this page now sits inside GlassShell's Scaffold, which has already
      // consumed the status-bar inset, so letting the body run behind the app
      // bar as well made the card's manual top inset double-count and pushed
      // it to the bottom of the screen.
      extendBody: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(color: Colors.white.withValues(alpha: 0.05)),
          ),
        ),
        leading: IconButton(
          icon: const Icon(CupertinoIcons.person_2),
          onPressed: () => context.push('/friends'),
          tooltip: 'Friends',
        ),
        title: const _Wordmark(),
        actions: [
          Stack(
            alignment: Alignment.topRight,
            children: [
              IconButton(
                icon: const Icon(CupertinoIcons.heart),
                onPressed: () => context.push('/notifications'),
                tooltip: 'Activity',
              ),
              unreadCount.when(
                data: (count) => count > 0
                    ? Positioned(
                        right: 4,
                        top: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.destructive,
                            borderRadius:
                                BorderRadius.circular(AppRadius.pill),
                          ),
                          constraints: const BoxConstraints(minWidth: 17),
                          child: Text(
                            count > 99 ? '99+' : '$count',
                            style: AppText.footnote.copyWith(
                              color: AppColors.ink,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
          ),
        ],
      ),
      body: SizedBox.expand(
        child: feedAsync.when(
          loading: () => const _LoadingShimmer(),
          error: (error, _) => _ErrorView(
            error: error.toString(),
            onRetry: () => ref.refresh(homeFeedProvider),
          ),
          data: (activities) {
            if (activities.isEmpty) {
              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(homeFeedProvider);
                  await Future.delayed(const Duration(milliseconds: 500));
                },
                color: AppColors.accent,
                backgroundColor: AppColors.surface,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: SizedBox(
                    height: MediaQuery.of(context).size.height - 150,
                    child: _EmptyFeedView(
                      onRefresh: () => ref.refresh(homeFeedProvider),
                    ),
                  ),
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(homeFeedProvider);
                // Wait a bit for the refresh to complete
                await Future.delayed(const Duration(milliseconds: 500));
              },
              color: AppColors.accent,
              backgroundColor: AppColors.surface,
              child: PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                itemCount: activities.length,
                itemBuilder: (context, index) {
                  return _ActivityCard(activity: activities[index]);
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Individual activity card with flip animation
class _ActivityCard extends ConsumerStatefulWidget {
  final ActivityModel activity;

  const _ActivityCard({required this.activity});

  @override
  ConsumerState<_ActivityCard> createState() => _ActivityCardState();
}

class _ActivityCardState extends ConsumerState<_ActivityCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  bool _showBack = false;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  void _toggleCard() {
    if (_showBack) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }
    setState(() {
      _showBack = !_showBack;
    });
  }

  void _onCardTap() {
    final currentUser = ref.read(currentUserProvider);
    final isOwnActivity = currentUser?.uid == widget.activity.userId;

    if (isOwnActivity) {
      // Show activity detail bottom sheet for editing
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => ActivityDetailSheet(activity: widget.activity),
      );
    } else {
      // Keep flip animation for others' posts
      _toggleCard();
    }
  }

  void _navigateToFilmDetail() {
    final mediaType = widget.activity.mediaType.isNotEmpty
        ? widget.activity.mediaType
        : 'movie';
    context.push(
      '/film/${widget.activity.filmId}/$mediaType',
      extra: widget.activity,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final isOwnActivity = currentUser?.uid == widget.activity.userId;

    return Padding(
      // Both chrome layers float over the feed, so the page is full-height.
      // Insetting here keeps the card centred in the *visible* band without
      // shrinking the page — posters still slide under the glass on scroll.
      // Only the bottom needs insetting now — the Scaffold lays the body out
      // below the app bar, so the top is already accounted for.
      padding: const EdgeInsets.only(bottom: kFloatingTabBarInset),
      child: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        // max, not min: the card below is Flexible, so the Column needs the
        // full band to hand it. The header and actions keep their natural
        // size and stay crisp — only the artwork scales.
        mainAxisSize: MainAxisSize.max,
        children: [
          // User info row - tap to view profile
          GestureDetector(
            onTap: () => context.push('/profile/${widget.activity.userId}'),
            child: SizedBox(
              width: 280,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.grey[800],
                    backgroundImage: widget.activity.userPhotoUrl != null
                        ? CachedNetworkImageProvider(widget.activity.userPhotoUrl!)
                        : null,
                    child: widget.activity.userPhotoUrl == null
                        ? const Icon(Icons.person, color: Colors.white54, size: 20)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.activity.username,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          widget.activity.activityType == ActivityType.reviewed
                              ? 'reviewed ${widget.activity.filmTitle}'
                              : 'watched ${widget.activity.filmTitle}',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Flip card. Wrapped in Flexible + FittedBox so a short screen
          // scales the poster down rather than overflowing: the card's
          // internals (and the sticker spill offsets) are built against fixed
          // 300x440 metrics, so scaling the whole thing keeps that geometry
          // intact where recomputing it would not.
          Flexible(
            child: FittedBox(
              fit: BoxFit.contain,
              child: GestureDetector(
            onTap: _onCardTap,
            child: AnimatedBuilder(
              animation: _flipAnimation,
              builder: (context, child) {
                final angle = _flipAnimation.value * math.pi;
                final transform = Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY(angle);

                return Transform(
                  alignment: Alignment.center,
                  transform: transform,
                  child: angle < math.pi / 2
                      ? _buildFrontCard()
                      : Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()..rotateY(math.pi),
                          child: _buildBackCard(),
                        ),
                );
              },
            ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Timestamp
          Text(
            widget.activity.relativeTime,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 12,
            ),
          ),

          // Tap hint
          if (!_showBack)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                isOwnActivity
                    ? 'Tap to edit'
                    : (widget.activity.hasRating || widget.activity.hasReview)
                        ? 'Tap to see review'
                        : 'Tap to view',
                style: TextStyle(
                  color: AppColors.inkTertiary,
                  fontSize: 11,
                ),
              ),
            ),
        ],
      ),
      ),
    );
  }

  Widget _buildFrontCard() {
    final posterUrl = ApiConstants.getPosterUrl(
      widget.activity.filmPosterPath,
      size: ApiConstants.posterSizeLarge,
    );

    // Get unique stickers from reactions for scattered display (up to 5)
    final reactionStickers = widget.activity.reactions.values.toList();
    final uniqueStickers = reactionStickers.toSet().toList();

    return SizedBox(
      width: 300, // Slight extra width for sticker spill
      height: 440, // Slight extra height for sticker spill
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Main poster card - centered
          Positioned(
            left: 10,
            top: 15,
            child: Container(
              width: 280,
              height: 420,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    // Poster
                    Positioned.fill(
                      child: posterUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: posterUrl,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => _buildPosterPlaceholder(),
                              errorWidget: (context, url, error) => _buildPosterPlaceholder(),
                            )
                          : _buildPosterPlaceholder(),
                    ),

                    // Comment count badge at bottom-left
                    if (widget.activity.commentCount > 0)
                      Positioned(
                        left: 10,
                        bottom: 10,
                        child: GestureDetector(
                          onTap: _showComments,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.chat_bubble,
                                  color: Colors.white,
                                  size: 14,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  '${widget.activity.commentCount}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Scattered stickers at top-right corner (spilling off card)
          ..._buildScatteredStickers(uniqueStickers, reactionStickers),
        ],
      ),
    );
  }

  List<Widget> _buildScatteredStickers(List<String> uniqueStickers, List<String> allStickers) {
    if (uniqueStickers.isEmpty) return [];

    final widgets = <Widget>[];
    final count = uniqueStickers.length.clamp(0, 5);

    // Card position within the SizedBox: left=10, top=15, width=280
    // Card right edge is at 10 + 280 = 290, SizedBox width = 300
    // So from SizedBox right edge, card right edge is at 300 - 290 = 10
    const cardRightOffset = 10.0;
    const cardTop = 15.0;

    for (int i = 0; i < count; i++) {
      final stickerId = uniqueStickers[i];
      final sticker = StickerRegistry.getStickerById(stickerId);
      if (sticker == null) continue;

      // Get deterministic placement at top-right corner
      final placement = StickerRegistry.getSeededPlacement(
        widget.activity.id,
        i,
        totalStickers: count,
      );

      // Count how many of this sticker
      final stickerCount = allStickers.where((s) => s == stickerId).length;

      // Position relative to card's top-right corner
      final stickerRight = cardRightOffset + placement.right;
      final stickerTop = cardTop + placement.top;

      widgets.add(
        Positioned(
          top: stickerTop,
          right: stickerRight,
          child: Transform.rotate(
            angle: placement.rotation,
            child: GestureDetector(
              onTap: () => showReactionsBreakdown(
                context: context,
                reactions: widget.activity.reactions,
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Sticker image with shadow
                  Container(
                    width: 95,
                    height: 95,
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 12,
                          offset: const Offset(3, 4),
                        ),
                      ],
                    ),
                    child: Image.asset(
                      sticker.assetPath,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stack) => Text(
                        sticker.emoji,
                        style: const TextStyle(fontSize: 65),
                      ),
                    ),
                  ),
                  // Count badge if more than 1
                  if (stickerCount > 1)
                    Positioned(
                      right: -4,
                      bottom: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          'x$stickerCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return widgets;
  }

  void _showComments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentsSheet(
        activityId: widget.activity.id,
        filmTitle: widget.activity.filmTitle,
        activityOwnerId: widget.activity.userId,
        filmPosterPath: widget.activity.filmPosterPath,
      ),
    );
  }

  Widget _buildBackCard() {
    final currentUser = ref.watch(currentUserProvider);
    final isOwnActivity = currentUser?.uid == widget.activity.userId;
    final isLiked = currentUser != null && widget.activity.isLikedBy(currentUser.uid);
    final userReaction = currentUser != null
        ? widget.activity.getReactionFrom(currentUser.uid)
        : null;

    return Container(
      width: 280,
      height: 420,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        // Flat neutral grey, not a purple gradient. A card sitting on true
        // black needs a hairline to read as a separate surface — the gradient
        // was doing that job with colour, which is what made it look cheap.
        color: AppColors.surface,
        border: Border.all(color: AppColors.separator, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Film title
            Text(
              widget.activity.filmTitle,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (widget.activity.filmYear != null) ...[
              const SizedBox(height: 4),
              Text(
                widget.activity.filmYear!,
                style: TextStyle(
                  color: AppColors.inkSecondary,
                  fontSize: 14,
                ),
              ),
            ],
            const SizedBox(height: 24),

            // Star rating
            if (widget.activity.hasRating) ...[
              _StarRating(rating: widget.activity.rating!),
              const SizedBox(height: 24),
            ],

            // Review text
            if (widget.activity.hasReview)
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    widget.activity.reviewText!,
                    style: TextStyle(
                      color: AppColors.ink,
                      fontSize: 14,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else if (!widget.activity.hasRating)
              Expanded(
                child: Center(
                  child: Text(
                    '${widget.activity.username} watched this',
                    style: TextStyle(
                      color: AppColors.inkSecondary,
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),

            // View Film button for others' posts
            if (!isOwnActivity) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _navigateToFilmDetail,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.canvas,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                  ),
                  child: const Text(
                    'View Film',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],

            // Interaction bar
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppColors.separator, width: 0.5),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // React button
                  _InteractionButton(
                    icon: userReaction != null
                        ? null
                        : Icons.add_reaction_outlined,
                    stickerAsset: userReaction != null
                        ? StickerRegistry.getStickerById(userReaction)?.assetPath
                        : null,
                    label: 'React',
                    count: widget.activity.reactionCount,
                    isActive: userReaction != null,
                    onTap: () => showStickerPicker(
                      context: context,
                      activityId: widget.activity.id,
                      currentStickerId: userReaction,
                      activityOwnerId: widget.activity.userId,
                      filmTitle: widget.activity.filmTitle,
                      filmPosterPath: widget.activity.filmPosterPath,
                    ),
                  ),
                  // Comment button
                  _InteractionButton(
                    icon: Icons.chat_bubble_outline,
                    label: 'Comment',
                    count: widget.activity.commentCount,
                    onTap: _showComments,
                  ),
                  // Like button
                  _InteractionButton(
                    icon: isLiked ? Icons.favorite : Icons.favorite_border,
                    label: 'Like',
                    count: widget.activity.likeCount,
                    isActive: isLiked,
                    activeColor: Colors.red,
                    onTap: () {
                      ref.read(likeNotifierProvider.notifier).toggleLike(
                        widget.activity.id,
                        isLiked,
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPosterPlaceholder() {
    return Container(
      width: 280,
      height: 420,
      color: Colors.grey[900],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.movie, size: 48, color: Colors.grey[700]),
          const SizedBox(height: 8),
          Text(
            widget.activity.filmTitle,
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Star rating display widget
class _StarRating extends StatelessWidget {
  final double rating;

  const _StarRating({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        final starValue = index + 1;
        if (rating >= starValue) {
          return const Icon(Icons.star, color: Colors.amber, size: 32);
        } else if (rating >= starValue - 0.5) {
          return const Icon(Icons.star_half, color: Colors.amber, size: 32);
        } else {
          return Icon(Icons.star_border, color: Colors.grey[600], size: 32);
        }
      }),
    );
  }
}

/// Interaction button for the back of the card
class _InteractionButton extends StatelessWidget {
  final IconData? icon;
  final String? stickerAsset;
  final String label;
  final int count;
  final bool isActive;
  final Color? activeColor;
  final VoidCallback onTap;

  const _InteractionButton({
    this.icon,
    this.stickerAsset,
    required this.label,
    this.count = 0,
    this.isActive = false,
    this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive
        ? (activeColor ?? Colors.white)
        : Colors.grey[400];

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (stickerAsset != null)
            SizedBox(
              width: 26,
              height: 26,
              child: Image.asset(
                stickerAsset!,
                fit: BoxFit.contain,
              ),
            )
          else if (icon != null)
            Icon(
              icon,
              color: color,
              size: 22,
            ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 4),
                Text(
                  '$count',
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Loading shimmer placeholder
class _LoadingShimmer extends StatelessWidget {
  const _LoadingShimmer();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Shimmer.fromColors(
        baseColor: Colors.grey[900]!,
        highlightColor: Colors.grey[800]!,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircleAvatar(radius: 20),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 100,
                      height: 14,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 150,
                      height: 12,
                      color: Colors.white,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: 280,
              height: 420,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Empty feed view
class _EmptyFeedView extends StatelessWidget {
  final VoidCallback? onRefresh;

  const _EmptyFeedView({this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.movie_filter_outlined,
              size: 80,
              color: Colors.grey[700],
            ),
            const SizedBox(height: 24),
            Text(
              'Your feed is empty',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Add some friends or post your first watch to get started!',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                context.push('/search');
              },
              icon: const Icon(Icons.search),
              label: const Text('Search Films'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Error view
class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback? onRetry;

  const _ErrorView({required this.error, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The 35mm wordmark.
///
/// San Francisco Display at nav-bar weight. The old version was 24px bold
/// Roboto, which is why it read as 2014 Android — the fix is the typeface,
/// not decoration around it.
class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    return Text(
      '35mm',
      style: AppText.title.copyWith(fontSize: 20),
    );
  }
}
