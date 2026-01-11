import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/badge_model.dart';

/// Section displaying user's earned badges as horizontal scroll
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Stylized section header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFFFCD34D), Color(0xFFF59E0B)],
                ).createShader(bounds),
                child: const Text(
                  'badges',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    fontStyle: FontStyle.italic,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const Spacer(),
              if (isOwnProfile)
                GestureDetector(
                  onTap: () => _showAllBadges(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Badges horizontal scroll
        if (earnedBadges.isNotEmpty)
          SizedBox(
            height: 110,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: earnedBadges.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _BadgeCard(
                    badge: earnedBadges[index],
                    isEarned: true,
                  ),
                );
              },
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              width: double.infinity,
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFCD34D).withOpacity(0.1),
                    const Color(0xFFF59E0B).withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.emoji_events_outlined,
                    color: Colors.white.withOpacity(0.3),
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isOwnProfile ? 'Post reviews to earn badges!' : 'No badges earned yet',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 28),
      ],
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
                color: isEarned ? null : Colors.white.withOpacity(0.05),
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
              child: Center(
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
      builder: (context) => Dialog(
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
                width: 80,
                height: 80,
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
                    style: const TextStyle(fontSize: 40),
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
      ),
    );
  }
}

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
