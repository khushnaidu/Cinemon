import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../models/film_model.dart';
import '../../providers/user/favorites_provider.dart';
import 'favorite_films_picker.dart';

/// Badge position for film cards
enum BadgePosition { left, right, bottom }

/// Top 3 Films section - centered card layout with large middle card
/// Cards overlap on top of the TOP 3 title backdrop
class Top3FilmsSection extends ConsumerWidget {
  final List<int> filmIds;
  final bool isOwnProfile;

  const Top3FilmsSection({
    super.key,
    required this.filmIds,
    required this.isOwnProfile,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Take only first 3 films and create stable key for provider
    final top3Ids = filmIds.take(3).toList();
    final filmsAsync =
        ref.watch(favoriteFilmsDataProvider(favoriteFilmsKey(top3Ids)));

    // Don't show section if empty and not own profile
    if (filmIds.isEmpty && !isOwnProfile) {
      return const SizedBox.shrink();
    }

    // Cards at top:150 + height ~240 = need ~390 total height
    return SizedBox(
      height: 300,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Main content
          filmsAsync.when(
            data: (films) => films.isEmpty
                ? _buildEmptyState(context, ref)
                : _buildCardsWithBackdrop(context, films),
            loading: () => _buildLoadingState(context),
            error: (_, __) => _buildEmptyState(context, ref),
          ),

          // Edit button overlaid on top right
          if (isOwnProfile)
            Positioned(
              top: 8,
              right: 24,
              child: GestureDetector(
                onTap: () => _showFilmPicker(context, ref),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    filmIds.isEmpty ? 'add' : 'edit',
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCardsWithBackdrop(BuildContext context, List<FilmModel> films) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Stack(
      alignment: Alignment.topCenter,
      clipBehavior: Clip.none,
      children: [
        // Combined circle + TOP 3 title backdrop (animated GIF)
        _AnimatedGifBackdrop(
          width: screenWidth * 0.95,
          top: 0,
        ),

        // Cards container - below the title, overlapping circle
        Positioned(
          top: 150,
          child: SizedBox(
            width: screenWidth,
            height: 240,
            child: Stack(
              alignment: Alignment.topCenter,
              clipBehavior: Clip.none,
              children: [
                // 2nd place - left side, badge on LEFT edge (half on/half off)
                if (films.length > 1)
                  Positioned(
                    left: screenWidth * 0.02,
                    top: 0,
                    child: _AnimatedFilmCard(
                      film: films[1],
                      rankBadge: 'assets/top3elements/15.png',
                      width: 105,
                      height: 155,
                      badgePosition: BadgePosition.left,
                      animationDelay: 0.2,
                    ),
                  ),

                // 3rd place - right side, badge on RIGHT edge (half on/half off)
                if (films.length > 2)
                  Positioned(
                    right: screenWidth * 0.02,
                    top: 0,
                    child: _AnimatedFilmCard(
                      film: films[2],
                      rankBadge: 'assets/top3elements/16.png',
                      width: 105,
                      height: 155,
                      badgePosition: BadgePosition.right,
                      animationDelay: 0.4,
                    ),
                  ),

                // 1st place - center, larger, badge at BOTTOM
                if (films.isNotEmpty)
                  Positioned(
                    top: 20,
                    child: _AnimatedFilmCard(
                      film: films[0],
                      rankBadge: 'assets/top3elements/14.png',
                      width: 130,
                      height: 195,
                      badgePosition: BadgePosition.bottom,
                      isFirst: true,
                      animationDelay: 0.0,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Stack(
      alignment: Alignment.topCenter,
      children: [
        // Combined circle + TOP 3 title backdrop (animated GIF)
        _AnimatedGifBackdrop(
          width: screenWidth * 0.95,
          top: -20,
        ),
        // Empty state card
        Positioned(
          top: 160,
          child: GestureDetector(
            onTap: isOwnProfile ? () => _showFilmPicker(context, ref) : null,
            child: Container(
              width: 280,
              height: 160,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF9B8BF4).withValues(alpha: 0.1),
                    const Color(0xFFE879F9).withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.movie_outlined,
                    color: Colors.white.withValues(alpha: 0.3),
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isOwnProfile ? 'Add your top 3 films' : 'No top films yet',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Stack(
      alignment: Alignment.topCenter,
      children: [
        // Combined circle + TOP 3 title backdrop (animated GIF)
        _AnimatedGifBackdrop(
          width: screenWidth * 0.95,
          top: -20,
        ),
        // Loading placeholders
        Positioned(
          top: 120,
          child: SizedBox(
            width: screenWidth,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 2nd place placeholder
                Container(
                  width: 105,
                  height: 155,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                // 1st place placeholder
                Container(
                  width: 130,
                  height: 195,
                  margin: const EdgeInsets.only(top: 20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                // 3rd place placeholder
                Container(
                  width: 105,
                  height: 155,
                  margin: const EdgeInsets.only(left: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showFilmPicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FavoriteFilmsPickerSheet(currentFilmIds: filmIds),
    );
  }
}

/// Animated film card with floating effect
class _AnimatedFilmCard extends StatefulWidget {
  final FilmModel film;
  final String rankBadge;
  final double width;
  final double height;
  final BadgePosition badgePosition;
  final bool isFirst;
  final double animationDelay;

  const _AnimatedFilmCard({
    required this.film,
    required this.rankBadge,
    required this.width,
    required this.height,
    required this.badgePosition,
    this.isFirst = false,
    this.animationDelay = 0.0,
  });

  @override
  State<_AnimatedFilmCard> createState() => _AnimatedFilmCardState();
}

class _AnimatedFilmCardState extends State<_AnimatedFilmCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );

    _floatAnimation = Tween<double>(begin: 0, end: 8).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    // Start animation with delay for staggered effect
    Future.delayed(
        Duration(milliseconds: (widget.animationDelay * 1000).toInt()), () {
      if (mounted) {
        _controller.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Bigger badges: 70 for 1st place, 60 for others
    final badgeSize = widget.isFirst ? 70.0 : 60.0;

    return AnimatedBuilder(
      animation: _floatAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, -_floatAnimation.value),
          child: child,
        );
      },
      child: GestureDetector(
        onTap: () {
          final mediaType = widget.film.isMovie ? 'movie' : 'tv';
          context.push('/film/${widget.film.id}/$mediaType');
        },
        child: SizedBox(
          // Extra width for side badges
          width: widget.width +
              (widget.badgePosition != BadgePosition.bottom
                  ? badgeSize * 0.5
                  : 0),
          height: widget.height +
              (widget.badgePosition == BadgePosition.bottom ? 25 : 0),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Poster with shadow
              Positioned(
                // Offset poster to make room for badge on the side
                left: widget.badgePosition == BadgePosition.left
                    ? badgeSize * 0.5
                    : 0,
                right: widget.badgePosition == BadgePosition.right
                    ? badgeSize * 0.5
                    : 0,
                top: 0,
                child: Container(
                  width: widget.width,
                  height: widget.height,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: widget.isFirst
                            ? const Color(0xFFFF9800).withValues(alpha: 0.4)
                            : const Color(0xFF9B8BF4).withValues(alpha: 0.3),
                        blurRadius: widget.isFirst ? 24 : 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: widget.film.posterPath != null
                        ? CachedNetworkImage(
                            imageUrl:
                                'https://image.tmdb.org/t/p/w300${widget.film.posterPath}',
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              color: const Color(0xFF1a1a2e),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              color: const Color(0xFF1a1a2e),
                              child: const Icon(Icons.movie,
                                  color: Colors.white24),
                            ),
                          )
                        : Container(
                            color: const Color(0xFF1a1a2e),
                            child:
                                const Icon(Icons.movie, color: Colors.white24),
                          ),
                  ),
                ),
              ),

              // Rank badge - positioned based on badgePosition
              _buildBadge(badgeSize),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(double badgeSize) {
    switch (widget.badgePosition) {
      case BadgePosition.left:
        // Badge on left side of poster, half on/half off
        return Positioned(
          left: 0,
          top: widget.height * 0.4,
          child: Image.asset(
            widget.rankBadge,
            width: badgeSize,
            height: badgeSize,
            fit: BoxFit.contain,
          ),
        );
      case BadgePosition.right:
        // Badge on right side of poster, half on/half off
        return Positioned(
          right: 0,
          top: widget.height * 0.4,
          child: Image.asset(
            widget.rankBadge,
            width: badgeSize,
            height: badgeSize,
            fit: BoxFit.contain,
          ),
        );
      case BadgePosition.bottom:
        // Badge at bottom center
        return Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Center(
            child: Image.asset(
              widget.rankBadge,
              width: badgeSize,
              height: badgeSize,
              fit: BoxFit.contain,
            ),
          ),
        );
    }
  }
}

/// Backdrop widget (using PNG for now - GIFs too large for memory)
class _AnimatedGifBackdrop extends StatelessWidget {
  final double width;
  final double top;

  const _AnimatedGifBackdrop({
    required this.width,
    this.top = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      child: Image.asset(
        'assets/top3elements/133.png',
        width: width,
        fit: BoxFit.fitWidth,
      ),
    );
  }
}
