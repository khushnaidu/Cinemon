import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/badge_model.dart';

// =============================================================================
// FILM REEL CONSTANTS
// =============================================================================

const double _kFilmStripHeight = 180.0;
const double _kFrameWidth = 130.0;
const double _kSprocketHeight = 12.0;
const double _kSprocketWidth = 8.0;
const double _kSprocketSpacing = 20.0;
const Color _kFilmColor = Color(0xFF1a1a1a);
const Color _kFilmBorderColor = Color(0xFF2a2a2a);
const Color _kSprocketColor = Color(0xFF0a0a0a);

// =============================================================================
// FILM REEL SCROLL PHYSICS - Gives reel-like momentum
// =============================================================================

class FilmReelScrollPhysics extends ClampingScrollPhysics {
  const FilmReelScrollPhysics({super.parent});

  @override
  FilmReelScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return FilmReelScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  Simulation? createBallisticSimulation(
      ScrollMetrics position, double velocity) {
    // Respect scroll bounds
    if (position.outOfRange) {
      return super.createBallisticSimulation(position, velocity);
    }

    // Add extra momentum for reel feel, but clamp to bounds
    final double adjustedVelocity = velocity * 1.2;

    // Calculate the target position with friction
    if (adjustedVelocity.abs() > toleranceFor(position).velocity) {
      // Use friction simulation but clamp the result
      final frictionSim = FrictionSimulation(
        0.12, // Lower = more momentum (reel keeps spinning)
        position.pixels,
        adjustedVelocity,
      );

      // Get where friction would take us
      final double finalPosition = frictionSim.finalX;

      // Clamp to bounds
      if (finalPosition < position.minScrollExtent) {
        return ScrollSpringSimulation(
          spring,
          position.pixels,
          position.minScrollExtent,
          velocity,
        );
      } else if (finalPosition > position.maxScrollExtent) {
        return ScrollSpringSimulation(
          spring,
          position.pixels,
          position.maxScrollExtent,
          velocity,
        );
      }

      return frictionSim;
    }
    return null;
  }
}

// =============================================================================
// FILM STRIP PAINTER - Draws sprocket holes
// =============================================================================

class _FilmStripPainter extends CustomPainter {
  final double scrollOffset;
  final double contentWidth; // Total width of content for proper bounds
  final Color filmColor;
  final Color sprocketColor;

  _FilmStripPainter({
    required this.scrollOffset,
    required this.contentWidth,
    this.filmColor = _kFilmColor,
    this.sprocketColor = _kSprocketColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Clip to prevent overflow
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final filmPaint = Paint()..color = filmColor;
    final sprocketPaint = Paint()..color = sprocketColor;
    final borderPaint = Paint()
      ..color = _kFilmBorderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Draw film strip background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      filmPaint,
    );

    // Draw film strip border for more contrast
    final filmBorderPaint = Paint()
      ..color = const Color(0xFF3a3a3a)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      filmBorderPaint,
    );

    // Calculate sprocket offset based on scroll
    final sprocketOffset = scrollOffset % _kSprocketSpacing;

    // Draw top sprocket holes (with padding from edges)
    for (double x = _kSprocketSpacing - sprocketOffset;
        x < size.width - _kSprocketWidth;
        x += _kSprocketSpacing) {
      if (x < _kSprocketSpacing / 2) continue; // Skip if too close to left edge
      final sprocketRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          x,
          4,
          _kSprocketWidth,
          _kSprocketHeight,
        ),
        const Radius.circular(2),
      );
      canvas.drawRRect(sprocketRect, sprocketPaint);
      canvas.drawRRect(sprocketRect, borderPaint);
    }

    // Draw bottom sprocket holes (with padding from edges)
    for (double x = _kSprocketSpacing - sprocketOffset;
        x < size.width - _kSprocketWidth;
        x += _kSprocketSpacing) {
      if (x < _kSprocketSpacing / 2) continue; // Skip if too close to left edge
      final sprocketRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          x,
          size.height - _kSprocketHeight - 4,
          _kSprocketWidth,
          _kSprocketHeight,
        ),
        const Radius.circular(2),
      );
      canvas.drawRRect(sprocketRect, sprocketPaint);
      canvas.drawRRect(sprocketRect, borderPaint);
    }

    // Draw frame borders (vertical lines between frames)
    final frameBorderPaint = Paint()
      ..color = _kFilmBorderColor.withOpacity(0.5)
      ..strokeWidth = 1;

    final frameOffset = scrollOffset % _kFrameWidth;
    for (double x = -frameOffset;
        x < size.width + _kFrameWidth;
        x += _kFrameWidth) {
      if (x > 0 && x < size.width) {
        canvas.drawLine(
          Offset(x, _kSprocketHeight + 8),
          Offset(x, size.height - _kSprocketHeight - 8),
          frameBorderPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FilmStripPainter oldDelegate) {
    return oldDelegate.scrollOffset != scrollOffset ||
        oldDelegate.contentWidth != contentWidth;
  }
}

// =============================================================================
// FILM REEL BADGE WIDGET
// =============================================================================

class _FilmReelBadges extends StatefulWidget {
  final List<BadgeModel> badges;
  final bool isOwnProfile;
  final VoidCallback onSeeAll;

  const _FilmReelBadges({
    required this.badges,
    required this.isOwnProfile,
    required this.onSeeAll,
  });

  @override
  State<_FilmReelBadges> createState() => _FilmReelBadgesState();
}

class _FilmReelBadgesState extends State<_FilmReelBadges> {
  late ScrollController _scrollController;
  double _scrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    setState(() {
      _scrollOffset = _scrollController.offset;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Calculate content width based on number of badges
    final contentWidth = widget.badges.length * _kFrameWidth + 32; // 32 for padding

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        const Padding(
          padding: EdgeInsets.only(left: 20, top: 16, bottom: 12),
          child: Text(
            'My Badges',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        // Film reel with glow
        Container(
          height: _kFilmStripHeight,
          decoration: BoxDecoration(
            // Subtle glow behind the film strip
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4a4a6a).withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 10,
                spreadRadius: -2,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              children: [
                // Film strip background with animated sprockets
                Positioned.fill(
                  child: CustomPaint(
                    painter: _FilmStripPainter(
                      scrollOffset: _scrollOffset,
                      contentWidth: contentWidth,
                    ),
                  ),
                ),
                // Badges in frames
                widget.badges.isNotEmpty
                    ? ListView.builder(
                        controller: _scrollController,
                        scrollDirection: Axis.horizontal,
                        physics: const FilmReelScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: widget.badges.length,
                        itemBuilder: (context, index) {
                          return _FilmFrameBadge(
                            badge: widget.badges[index],
                            isEarned: true,
                            scrollOffset: _scrollOffset,
                            index: index,
                          );
                        },
                      )
                    : Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: Text(
                            widget.isOwnProfile
                                ? 'Post reviews to earn badges!'
                                : 'No badges earned yet',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                // Subtle vignette effect on edges
                Positioned.fill(
                  child: IgnorePointer(
                    child: Row(
                      children: [
                        Container(
                          width: 20,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                _kFilmColor,
                                _kFilmColor.withOpacity(0),
                              ],
                            ),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          width: 20,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                _kFilmColor.withOpacity(0),
                                _kFilmColor,
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // See all button
        if (widget.isOwnProfile)
          Padding(
            padding: const EdgeInsets.only(right: 20, top: 12, bottom: 8),
            child: Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: widget.onSeeAll,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'see all',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// =============================================================================
// FILM FRAME BADGE - Badge inside a film frame with subtle animation
// =============================================================================

class _FilmFrameBadge extends StatelessWidget {
  final BadgeModel badge;
  final bool isEarned;
  final double scrollOffset;
  final int index;

  const _FilmFrameBadge({
    required this.badge,
    required this.isEarned,
    required this.scrollOffset,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate subtle rotation based on scroll velocity feel
    final itemPosition = index * _kFrameWidth;
    final relativeOffset = (scrollOffset - itemPosition) / 500;
    final rotation = (relativeOffset * 0.05).clamp(-0.1, 0.1);

    return Transform(
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.001) // Perspective
        ..rotateY(rotation),
      alignment: Alignment.center,
      child: SizedBox(
        width: _kFrameWidth,
        height: _kFilmStripHeight,
        child: GestureDetector(
          onTap: () => _showBadgeDetails(context),
          child: Padding(
            // Account for sprocket areas - center badge in the "frame" area
            padding: EdgeInsets.only(
              top: _kSprocketHeight + 8,
              bottom: _kSprocketHeight + 8,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Badge image/icon - 2x size, no glow (PNGs have their own)
                SizedBox(
                  width: 100,
                  height: 100,
                  child: badge.imagePath != null
                      ? Image.asset(
                          badge.imagePath!,
                          width: 100,
                          height: 100,
                          fit: BoxFit.contain,
                        )
                      : Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: isEarned
                                ? LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      _getBadgeColor(badge.type),
                                      _getBadgeColor(badge.type).withOpacity(0.6),
                                    ],
                                  )
                                : null,
                            color: isEarned ? null : Colors.white.withOpacity(0.1),
                          ),
                          child: Center(
                            child: Text(
                              badge.emoji,
                              style: const TextStyle(fontSize: 44),
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: 4),
                // Badge name
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    badge.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getBadgeColor(BadgeType type) {
    switch (type) {
      case BadgeType.reviews:
        return const Color(0xFFFCD34D);
      case BadgeType.genres:
        return const Color(0xFFA78BFA);
      case BadgeType.special:
        return const Color(0xFF34D399);
    }
  }

  void _showBadgeDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) =>
          _BadgeDetailDialog(badge: badge, isEarned: isEarned),
    );
  }
}

// =============================================================================
// BADGE DETAIL DIALOG
// =============================================================================

class _BadgeDetailDialog extends StatelessWidget {
  final BadgeModel badge;
  final bool isEarned;

  const _BadgeDetailDialog({
    required this.badge,
    required this.isEarned,
  });

  Color _getBadgeColor(BadgeType type) {
    switch (type) {
      case BadgeType.reviews:
        return const Color(0xFFFCD34D);
      case BadgeType.genres:
        return const Color(0xFFA78BFA);
      case BadgeType.special:
        return const Color(0xFF34D399);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0a0a14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: (isEarned && badge.imagePath == null)
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          _getBadgeColor(badge.type),
                          _getBadgeColor(badge.type).withOpacity(0.6),
                        ],
                      )
                    : null,
                color: (isEarned || badge.imagePath != null)
                    ? null
                    : Colors.white.withOpacity(0.1),
                boxShadow: isEarned
                    ? [
                        BoxShadow(
                          color: _getBadgeColor(badge.type).withOpacity(0.4),
                          blurRadius: 20,
                        ),
                      ]
                    : null,
              ),
              child: badge.imagePath != null
                  ? ClipOval(
                      child: ColorFiltered(
                        colorFilter: isEarned
                            ? const ColorFilter.mode(
                                Colors.transparent, BlendMode.multiply)
                            : const ColorFilter.matrix(<double>[
                                0.2126, 0.7152, 0.0722, 0, 0,
                                0.2126, 0.7152, 0.0722, 0, 0,
                                0.2126, 0.7152, 0.0722, 0, 0,
                                0, 0, 0, 0.3, 0,
                              ]),
                        child: Image.asset(
                          badge.imagePath!,
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                        ),
                      ),
                    )
                  : Center(
                      child: Text(
                        badge.emoji,
                        style: const TextStyle(fontSize: 50),
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            Text(
              badge.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              badge.description,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            if (isEarned) ...[
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF34D399).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, color: Color(0xFF34D399), size: 18),
                    SizedBox(width: 6),
                    Text(
                      'Earned',
                      style: TextStyle(
                        color: Color(0xFF34D399),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Close',
                style: TextStyle(color: Colors.white60),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// BADGE SECTION - Main widget
// =============================================================================

/// Section displaying user's earned badges as a film reel
class BadgeSection extends ConsumerWidget {
  final List<String> badgeIds;
  final bool isOwnProfile;

  const BadgeSection({
    super.key,
    required this.badgeIds,
    required this.isOwnProfile,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get earned badges
    final earnedBadges = badgeIds
        .map((id) => BadgeRegistry.getBadgeById(id))
        .whereType<BadgeModel>()
        .toList();

    if (earnedBadges.isEmpty && !isOwnProfile) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _FilmReelBadges(
        badges: earnedBadges,
        isOwnProfile: isOwnProfile,
        onSeeAll: () => _showAllBadges(context),
      ),
    );
  }

  void _showAllBadges(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AllBadgesSheet(earnedBadgeIds: badgeIds),
    );
  }
}

// =============================================================================
// BADGE CARD - Used in AllBadgesSheet
// =============================================================================

class _BadgeCard extends StatelessWidget {
  final BadgeModel badge;
  final bool isEarned;

  const _BadgeCard({
    required this.badge,
    required this.isEarned,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showBadgeDetails(context),
      child: SizedBox(
        width: 80,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Badge icon with glow effect
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: (isEarned && badge.imagePath == null)
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          _getBadgeColor(badge.type),
                          _getBadgeColor(badge.type).withOpacity(0.6),
                        ],
                      )
                    : null,
                color: (isEarned || badge.imagePath != null)
                    ? null
                    : Colors.white.withOpacity(0.05),
                boxShadow: isEarned
                    ? [
                        BoxShadow(
                          color: _getBadgeColor(badge.type).withOpacity(0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: badge.imagePath != null
                  ? ClipOval(
                      child: ColorFiltered(
                        colorFilter: isEarned
                            ? const ColorFilter.mode(
                                Colors.transparent, BlendMode.multiply)
                            : const ColorFilter.matrix(<double>[
                                0.2126, 0.7152, 0.0722, 0, 0,
                                0.2126, 0.7152, 0.0722, 0, 0,
                                0.2126, 0.7152, 0.0722, 0, 0,
                                0, 0, 0, 0.3, 0,
                              ]),
                        child: Image.asset(
                          badge.imagePath!,
                          width: 70,
                          height: 70,
                          fit: BoxFit.cover,
                        ),
                      ),
                    )
                  : Center(
                      child: Text(
                        badge.emoji,
                        style: TextStyle(
                          fontSize: isEarned ? 32 : 24,
                          color: isEarned ? null : Colors.white.withOpacity(0.2),
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 8),
            // Badge name
            Text(
              badge.name,
              style: TextStyle(
                color: isEarned ? Colors.white : Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Color _getBadgeColor(BadgeType type) {
    switch (type) {
      case BadgeType.reviews:
        return const Color(0xFFFCD34D);
      case BadgeType.genres:
        return const Color(0xFFA78BFA);
      case BadgeType.special:
        return const Color(0xFF34D399);
    }
  }

  void _showBadgeDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) =>
          _BadgeDetailDialog(badge: badge, isEarned: isEarned),
    );
  }
}

// =============================================================================
// ALL BADGES SHEET
// =============================================================================

/// Sheet showing all available badges
class AllBadgesSheet extends StatelessWidget {
  final List<String> earnedBadgeIds;

  const AllBadgesSheet({
    super.key,
    required this.earnedBadgeIds,
  });

  @override
  Widget build(BuildContext context) {
    final allBadges = BadgeRegistry.allBadges;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Color(0xFF0a0a14),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle bar
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          // Title
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFFFCD34D), Color(0xFFF59E0B)],
            ).createShader(bounds),
            child: const Text(
              'all badges',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${earnedBadgeIds.length}/${allBadges.length} earned',
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 24),
          // Badges by category
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                // Review Milestones
                _buildSection(
                  'Review Milestones',
                  const Color(0xFFFCD34D),
                  BadgeRegistry.reviewBadges,
                ),
                const SizedBox(height: 28),
                // Genre Badges
                _buildSection(
                  'Genre Achievements',
                  const Color(0xFFA78BFA),
                  BadgeRegistry.genreBadges,
                ),
                const SizedBox(height: 28),
                // Special Badges
                _buildSection(
                  'Special Badges',
                  const Color(0xFF34D399),
                  BadgeRegistry.specialBadges,
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, Color color, List<BadgeModel> badges) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 110,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: badges.length,
            itemBuilder: (context, index) {
              final badge = badges[index];
              final isEarned = earnedBadgeIds.contains(badge.id);
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _BadgeCard(badge: badge, isEarned: isEarned),
              );
            },
          ),
        ),
      ],
    );
  }
}
