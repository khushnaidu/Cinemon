import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../models/film_model.dart';
import '../../providers/feed/feed_provider.dart'
    show currentUserProfileProvider;
import '../../providers/user/favorites_provider.dart';
import '../../share/share_sheet.dart';
import '../../share/share_subject.dart';
import '../widgets/glass_panel.dart';
import 'favorite_films_picker.dart';

/// Badge position for film cards
enum BadgePosition { left, right, bottom }

/// Top 3 — two pages under one "TOP 3" backdrop: films, then shows.
///
/// Swipe between them, or tap the Films / Shows switch. The podium layout is
/// the same on both pages (large centre card for 1st, smaller flanks for 2nd
/// and 3rd, badges half on and half off the poster), so the swipe reads as
/// the same shelf turning over rather than a different section.
class Top3Section extends ConsumerStatefulWidget {
  final List<int> filmIds;
  final List<int> showIds;
  final bool isOwnProfile;

  const Top3Section({
    super.key,
    required this.filmIds,
    required this.showIds,
    required this.isOwnProfile,
  });

  @override
  ConsumerState<Top3Section> createState() => _Top3SectionState();
}

class _Top3SectionState extends ConsumerState<Top3Section> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Someone else's profile shows only the pages they've filled in.
  List<MediaType> get _pages {
    if (widget.isOwnProfile) return const [MediaType.movie, MediaType.tv];
    return [
      if (widget.filmIds.isNotEmpty) MediaType.movie,
      if (widget.showIds.isNotEmpty) MediaType.tv,
    ];
  }

  List<int> _idsFor(MediaType type) =>
      type == MediaType.tv ? widget.showIds : widget.filmIds;

  void _goTo(int index) {
    _controller.animateToPage(
      index,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  /// Your Top 3 as a story (ADR 0003, T1 and T2).
  Future<void> _share(MediaType type) async {
    final ids = _idsFor(type).take(3).toList();
    final key = favoriteFilmsKey(ids);
    try {
      final films = await (type == MediaType.tv
          ? ref.read(favoriteShowsDataProvider(key).future)
          : ref.read(favoriteFilmsDataProvider(key).future));
      final me = await ref.read(currentUserProfileProvider.future);
      if (!mounted || films.isEmpty || me == null) return;
      await showShareSheet(
        context,
        Top3Share(
          username: me.username,
          userPhotoUrl: me.photoUrl,
          films: films,
          isTv: type == MediaType.tv,
        ),
      );
    } catch (_) {
      if (mounted) {
        showGlassToast(context, "Couldn't load your Top 3. Try again.",
            destructive: true);
      }
    }
  }

  void _showPicker(MediaType type) {
    showGlassPanel(
      context,
      tall: true,
      builder: (_) => FavoriteFilmsPickerSheet(
        currentFilmIds: _idsFor(type),
        mediaType: type,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = _pages;
    if (pages.isEmpty) return const SizedBox.shrink();

    final page = _page.clamp(0, pages.length - 1);
    final current = pages[page];
    final currentIds = _idsFor(current);
    final screenWidth = MediaQuery.of(context).size.width;

    return SizedBox(
      height: 300,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          // The "TOP 3" art stays put; only the shelf underneath turns.
          Positioned(
            top: 0,
            child: Image.asset(
              'assets/top3elements/133.png',
              width: screenWidth * 0.95,
              fit: BoxFit.fitWidth,
            ),
          ),

          Positioned.fill(
            child: PageView(
              controller: _controller,
              clipBehavior: Clip.none,
              physics: pages.length > 1
                  ? const PageScrollPhysics()
                  : const NeverScrollableScrollPhysics(),
              onPageChanged: (i) => setState(() => _page = i),
              children: [
                for (final type in pages)
                  _Top3Page(
                    key: ValueKey(type),
                    ids: _idsFor(type),
                    mediaType: type,
                    isOwnProfile: widget.isOwnProfile,
                    onAdd: () => _showPicker(type),
                  ),
              ],
            ),
          ),

          if (pages.length > 1)
            Positioned(
              top: AppSpace.sm,
              left: AppSpace.xl,
              child: SizedBox(
                width: 132,
                child: GlassSegmentedControl(
                  labels: const ['Films', 'Shows'],
                  index: page,
                  onChanged: _goTo,
                ),
              ),
            ),

          if (widget.isOwnProfile)
            Positioned(
              top: AppSpace.sm,
              right: AppSpace.xl,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (currentIds.isNotEmpty) ...[
                    GlassPillButton(
                      label: 'Share',
                      icon: CupertinoIcons.square_arrow_up,
                      compact: true,
                      onTap: () => _share(current),
                    ),
                    const SizedBox(width: AppSpace.sm),
                  ],
                  GlassPillButton(
                    label: currentIds.isEmpty ? 'Add' : 'Edit',
                    icon: currentIds.isEmpty
                        ? CupertinoIcons.plus
                        : CupertinoIcons.pencil,
                    compact: true,
                    onTap: () => _showPicker(current),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// One shelf: the three cards, or the empty / loading stand-ins.
class _Top3Page extends ConsumerWidget {
  const _Top3Page({
    super.key,
    required this.ids,
    required this.mediaType,
    required this.isOwnProfile,
    required this.onAdd,
  });

  final List<int> ids;
  final MediaType mediaType;
  final bool isOwnProfile;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final top3 = ids.take(3).toList();
    final key = favoriteFilmsKey(top3);
    final filmsAsync = top3.isEmpty
        ? const AsyncValue<List<FilmModel>>.data([])
        : mediaType == MediaType.tv
            ? ref.watch(favoriteShowsDataProvider(key))
            : ref.watch(favoriteFilmsDataProvider(key));

    return filmsAsync.when(
      data: (films) => films.isEmpty
          ? _buildEmptyState(context)
          : _buildCards(context, films),
      loading: () => _buildLoadingState(context),
      error: (_, __) => _buildEmptyState(context),
    );
  }

  Widget _buildCards(BuildContext context, List<FilmModel> films) {
    final screenWidth = MediaQuery.of(context).size.width;

    // Cards container - below the title, overlapping circle
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
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

  Widget _buildEmptyState(BuildContext context) {
    final isTv = mediaType == MediaType.tv;
    return Stack(
      alignment: Alignment.topCenter,
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: 160,
          child: GestureDetector(
            onTap: isOwnProfile ? onAdd : null,
            child: Container(
              width: 280,
              height: 160,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.10),
                  width: 0.8,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isTv ? CupertinoIcons.tv : CupertinoIcons.film,
                    color: AppColors.inkTertiary,
                    size: 30,
                  ),
                  const SizedBox(height: AppSpace.sm),
                  Text(
                    isOwnProfile
                        ? 'Add your top 3 ${isTv ? 'shows' : 'films'}'
                        : 'No top ${isTv ? 'shows' : 'films'} yet',
                    style:
                        AppText.caption.copyWith(color: AppColors.inkSecondary),
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

    Widget slab(double w, double h, {EdgeInsets margin = EdgeInsets.zero}) {
      return Container(
        width: w,
        height: h,
        margin: margin,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
        ),
      );
    }

    return Stack(
      alignment: Alignment.topCenter,
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: 150,
          child: SizedBox(
            width: screenWidth,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                slab(105, 155, margin: const EdgeInsets.only(right: 12)),
                slab(130, 195, margin: const EdgeInsets.only(top: 20)),
                slab(105, 155, margin: const EdgeInsets.only(left: 12)),
              ],
            ),
          ),
        ),
      ],
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
                        color: Colors.black
                            .withValues(alpha: widget.isFirst ? 0.6 : 0.5),
                        blurRadius: widget.isFirst ? 24 : 16,
                        offset: const Offset(0, 6),
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
                              color: AppColors.surface,
                            ),
                            errorWidget: (_, __, ___) => Container(
                              color: AppColors.surface,
                              child: const Icon(CupertinoIcons.film,
                                  color: AppColors.inkTertiary),
                            ),
                          )
                        : Container(
                            color: AppColors.surface,
                            child: const Icon(CupertinoIcons.film,
                                color: AppColors.inkTertiary),
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
